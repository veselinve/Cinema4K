-- ==============================================================================
-- MPV-Made-Easy - Universal Physical Keyboard & Any-Alphabet Layout Translator
-- ==============================================================================
-- Provides layout-independent hotkey functionality for non-Latin alphabets:
-- Bulgarian (Phonetic, BDS), Russian (ЙЦУКЕН), Ukrainian, Greek, Hebrew, Arabic.
--
-- How it works:
-- 1. All primary hotkeys (subtitles, audio, playback, fullscreen, sizing) are
--    bound directly in input.conf for both Latin and Cyrillic/Greek characters.
--    This script does NOT duplicate those bindings - input.conf is the single
--    source of truth.
-- 2. For any remaining UNBOUND single character key (e.g. a Cyrillic letter
--    with no direct binding in input.conf), the character is translated to its
--    underlying physical QWERTY key with the dynamic Win32 VkKeyScanExW engine
--    (LuaJIT FFI), which interrogates the ACTIVE Windows keyboard layout first
--    and the installed layouts afterwards. No static per-language table is used:
--    the same Cyrillic letter sits on different physical keys in Bulgarian
--    Phonetic, BDS and Russian layouts, so only the active layout knows the
--    right answer.
-- 3. The resolved physical key is re-injected through mp.commandv("keypress").
--
-- Safety rules:
--   - Mouse events (MOUSE_MOVE, MBTN_*, WHEEL_*) are NEVER translated, and
--     named keys (ESC, SPACE, F5, PGUP, ...) never match (only a single
--     non-ASCII character is a translation candidate). Without this, every
--     mouse move was translated to "m" (mute toggle), flooding the input
--     queue and stuttering playback.
--   - Modifier combinations (Shift+..., Ctrl+..., Alt+...) of a single
--     non-ASCII character ARE translated to the same physical key, so e.g.
--     Shift+S / Ctrl+S / Alt+S typed on a Cyrillic layout work like their
--     Latin counterparts.
-- ==============================================================================

local mp = require 'mp'
local msg = require 'mp.msg'

-- ------------------------------------------------------------------------------
-- 1. Dynamic Win32 VkKeyScanExW Engine (LuaJIT FFI)
-- ------------------------------------------------------------------------------
local ffi_ok, ffi = pcall(require, "ffi")
local user32 = nil
local installed_layouts = {}

if ffi_ok then
    pcall(function()
        ffi.cdef[[
            typedef unsigned long DWORD;
            typedef void* HWND;
            typedef void* HKL;
            typedef short SHORT;
            typedef int BOOL;

            HWND GetForegroundWindow(void);
            DWORD GetWindowThreadProcessId(HWND hWnd, DWORD *lpdwProcessId);
            HKL GetKeyboardLayout(DWORD idThread);
            SHORT VkKeyScanExW(wchar_t ch, HKL dwhkl);
            int GetKeyboardLayoutList(int nBuff, HKL *lpList);
        ]]
        user32 = ffi.load("user32")
        local count = user32.GetKeyboardLayoutList(0, nil)
        if count > 0 then
            local list = ffi.new("HKL[?]", count)
            user32.GetKeyboardLayoutList(count, list)
            for i = 0, count - 1 do
                table.insert(installed_layouts, list[i])
            end
        end
    end)
end

local function utf8_codepoint(str)
    if not str or #str == 0 then return 0 end
    local b1 = string.byte(str, 1)
    if b1 < 0x80 then return b1 end
    local b2 = string.byte(str, 2)
    if b1 >= 0xC0 and b1 < 0xE0 then
        return bit.bor(bit.lshift(bit.band(b1, 0x1F), 6), bit.band(b2, 0x3F))
    end
    local b3 = string.byte(str, 3)
    if b1 >= 0xE0 and b1 < 0xF0 then
        return bit.bor(bit.lshift(bit.band(b1, 0x0F), 12), bit.lshift(bit.band(b2, 0x3F), 6), bit.band(b3, 0x3F))
    end
    return b1
end

-- Returns the codepoint if str is exactly one UTF-8 character, otherwise nil.
local function single_char_codepoint(str)
    if not str or #str == 0 then return nil end
    local b1 = string.byte(str, 1)
    local len
    if b1 < 0x80 then
        len = 1
    elseif b1 >= 0xC2 and b1 <= 0xDF then
        len = 2
    elseif b1 >= 0xE0 and b1 <= 0xEF then
        len = 3
    elseif b1 >= 0xF0 and b1 <= 0xF4 then
        len = 4
    else
        return nil
    end
    if #str ~= len then return nil end
    for i = 2, len do
        local b = string.byte(str, i)
        if bit.band(b, 0xC0) ~= 0x80 then return nil end
    end
    return utf8_codepoint(str)
end

local function vk_to_key(vk, shift)
    if vk >= 0x41 and vk <= 0x5A then
        local c = string.char(vk)
        return shift and c or string.lower(c)
    elseif vk >= 0x30 and vk <= 0x39 then
        return string.char(vk)
    elseif vk == 0x20 then
        return "SPACE"
    elseif vk == 0x0D then
        return "ENTER"
    elseif vk == 0x1B then
        return "ESC"
    elseif vk == 0xBB then
        return shift and "+" or "="
    elseif vk == 0xBD then
        return shift and "_" or "-"
    elseif vk == 0xDB then
        return shift and "{" or "["
    elseif vk == 0xDD then
        return shift and "}" or "]"
    elseif vk == 0xBC then
        return shift and "<" or ","
    elseif vk == 0xBE then
        return shift and ">" or "."
    elseif vk == 0xBA then
        return shift and ":" or ";"
    elseif vk == 0xDE then
        return shift and '"' or "'"
    elseif vk == 0xBF then
        return shift and "?" or "/"
    elseif vk == 0xDC then
        return shift and "|" or "\\"
    elseif vk == 0xC0 then
        return shift and "~" or "`"
    end
    return nil
end

local function translate_win32(char_str)
    if not user32 then return nil end
    local cp = utf8_codepoint(char_str)
    if cp == 0 then return nil end

    -- Query active window layout
    local fg = user32.GetForegroundWindow()
    local tid = user32.GetWindowThreadProcessId(fg, nil)
    local cur_hkl = user32.GetKeyboardLayout(tid)
    if cur_hkl == nil or tonumber(ffi.cast("uintptr_t", cur_hkl)) == 0 then
        cur_hkl = user32.GetKeyboardLayout(0)
    end

    if cur_hkl ~= nil then
        local res = user32.VkKeyScanExW(cp, cur_hkl)
        local vk = bit.band(res, 0xFF)
        if vk ~= 0xFF then
            local shift = (bit.band(bit.rshift(res, 8), 1) == 1)
            return vk_to_key(vk, shift)
        end
    end

    -- Query installed layouts
    for _, l in ipairs(installed_layouts) do
        local res = user32.VkKeyScanExW(cp, l)
        local vk = bit.band(res, 0xFF)
        if vk ~= 0xFF then
            local shift = (bit.band(bit.rshift(res, 8), 1) == 1)
            return vk_to_key(vk, shift)
        end
    end

    return nil
end

-- ------------------------------------------------------------------------------
-- 3. Universal "unmapped" Single-Character Re-Injection Interceptor
-- ------------------------------------------------------------------------------
local in_replay = false

-- Split leading Shift/Ctrl/Alt/Meta modifiers off a key name; returns the
-- modifier list (in original order) and the remaining base name. Lua patterns
-- have no alternation, so plain prefix comparison is used.
local function split_modifiers(name)
    local mods = {}
    local base = name
    while true do
        local matched = false
        for _, m in ipairs({ "Shift+", "Ctrl+", "Alt+", "Meta+" }) do
            if base:sub(1, #m) == m then
                mods[#mods + 1] = m:sub(1, -2)
                base = base:sub(#m + 1)
                matched = true
                break
            end
        end
        if not matched then break end
    end
    return mods, base
end

mp.add_key_binding("unmapped", "universal_unmapped_handler", function(ev)
    if in_replay then return end
    if not ev or (ev.event ~= "press" and ev.event ~= "repeat") then return end

    local raw_name = ev.key_name or ""
    if raw_name == "" then return end

    -- Never touch mouse events (MOUSE_MOVE / MBTN_* / WHEEL_*).
    if ev.is_mouse then return end

    -- Split modifiers; the base must be exactly one non-ASCII character.
    -- This filters out named keys (ESC, SPACE, F5, PGUP, ...) and mouse
    -- names. Modifier combinations are translated too, so Shift+letter /
    -- Ctrl+letter / Alt+letter work with any keyboard layout (mpv delivers
    -- e.g. Shift+ Cyrillic keys with the SHIFT modifier attached when the
    -- key is typed with the shift key held).
    local mods, base = split_modifiers(raw_name)
    local cp = single_char_codepoint(base)
    if not cp then return end
    if cp < 0x80 then return end

    -- Translate with the dynamic Win32 engine (active layout first)
    local target = translate_win32(base)

    -- If no target resolved or target is the same, do nothing
    if not target or target == base then
        msg.warn(("unmapped-skip: raw=%q target=%s"):format(raw_name, tostring(target)))
        return
    end

    -- Rebuild the key name with the original modifiers
    local name = target
    for i = #mods, 1, -1 do
        name = mods[i] .. "+" .. name
    end
    if name == raw_name then return end

    -- Re-inject resolved physical key
    in_replay = true
    mp.commandv("keypress", name)
    in_replay = false
end, { complex = true })

msg.info(string.format("Universal Physical Keyboard Translator loaded (safe mode: single non-ASCII characters only), Win32 FFI=%s.",
    tostring(user32 ~= nil)))
