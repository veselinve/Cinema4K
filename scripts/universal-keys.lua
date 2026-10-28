-- ==============================================================================
-- MPV-Made-Easy - Universal Physical Keyboard & Any-Alphabet Layout Translator
-- ==============================================================================
-- Provides 100% layout-independent hotkey functionality across ANY alphabet:
-- Bulgarian (Phonetic Traditional, Phonetic New, BDS), Russian (ЙЦУКЕН),
-- Ukrainian, Greek (Ελληνικά), Hebrew, Arabic, German (QWERTZ), French (AZERTY), etc.
--
-- How it works:
-- 1. Direct high-priority bindings for primary controls (Subtitles, Audio, Playback, Fullscreen, Sizing).
-- 2. Comprehensive pre-computed translation maps for non-Latin alphabets.
-- 3. Dynamic Win32 VkKeyScanExW fallback via LuaJIT FFI that interrogates the
--    active Windows keyboard layout to resolve any foreign character to its
--    underlying physical QWERTY hardware key.
-- 4. Re-injects the resolved physical key into MPV via mp.commandv("keypress", key).
-- ==============================================================================

local mp = require 'mp'
local msg = require 'mp.msg'
local utils = require 'mp.utils'

-- ------------------------------------------------------------------------------
-- 1. Primary Action Functions
-- ------------------------------------------------------------------------------
local function sub_next()
    mp.commandv("osd-msg", "cycle", "sub")
end

local function sub_prev()
    mp.commandv("osd-msg", "cycle", "sub", "down")
end

local function sub_toggle_visibility()
    mp.commandv("osd-msg", "cycle", "sub-visibility")
end

local function toggle_fullscreen()
    mp.commandv("cycle", "fullscreen")
end

local function toggle_pause()
    mp.commandv("cycle", "pause")
end

local function toggle_mute()
    mp.commandv("osd-msg", "cycle", "mute")
end

local function cycle_audio()
    mp.commandv("cycle", "audio")
end

local function cycle_audio_boost()
    mp.commandv("script-binding", "audio_boost/cycle-audio-boost")
end

local function sub_size_up()
    mp.commandv("script-message-to", "sub_manager", "size-up")
end

local function sub_size_down()
    mp.commandv("script-message-to", "sub_manager", "size-down")
end

local function sub_size_reset()
    mp.commandv("script-message-to", "sub_manager", "size-reset")
end

-- ------------------------------------------------------------------------------
-- 2. Direct Primary Bindings (Instant execution, highest priority)
-- ------------------------------------------------------------------------------
local direct_bindings = {
    -- Next Subtitle Track (physical 'S')
    { key = "s", fn = sub_next },
    { key = "с", fn = sub_next }, -- BG Phonetic / Russian 's'
    { key = "я", fn = sub_next }, -- BG BDS 's'
    { key = "ы", fn = sub_next }, -- Russian 's'
    { key = "і", fn = sub_next }, -- Ukrainian 's'
    { key = "σ", fn = sub_next }, -- Greek 's'
    { key = "ד", fn = sub_next }, -- Hebrew 's'
    { key = "س", fn = sub_next }, -- Arabic 's'

    -- Previous Subtitle Track (physical 'Shift+S')
    { key = "S", fn = sub_prev },
    { key = "Shift+s", fn = sub_prev },
    { key = "С", fn = sub_prev },
    { key = "Shift+с", fn = sub_prev },
    { key = "Я", fn = sub_prev },
    { key = "Shift+я", fn = sub_prev },
    { key = "Ы", fn = sub_prev },
    { key = "Shift+ы", fn = sub_prev },
    { key = "І", fn = sub_prev },
    { key = "Shift+і", fn = sub_prev },
    { key = "Σ", fn = sub_prev },
    { key = "Shift+σ", fn = sub_prev },

    -- Toggle Subtitle Visibility (physical 'W' and 'V')
    { key = "w", fn = sub_toggle_visibility },
    { key = "W", fn = sub_toggle_visibility },
    { key = "Shift+w", fn = sub_toggle_visibility },
    { key = "v", fn = sub_toggle_visibility },
    { key = "V", fn = sub_toggle_visibility },
    { key = "Shift+v", fn = sub_toggle_visibility },
    { key = "в", fn = sub_toggle_visibility }, -- BG Phonetic 'w'
    { key = "В", fn = sub_toggle_visibility },
    { key = "Shift+в", fn = sub_toggle_visibility },
    { key = "у", fn = sub_toggle_visibility }, -- BG BDS 'w'
    { key = "У", fn = sub_toggle_visibility },
    { key = "Shift+у", fn = sub_toggle_visibility },
    { key = "ж", fn = sub_toggle_visibility }, -- BG Phonetic 'v'
    { key = "Ж", fn = sub_toggle_visibility },
    { key = "Shift+ж", fn = sub_toggle_visibility },
    { key = "ц", fn = sub_toggle_visibility }, -- Russian 'w'
    { key = "Ц", fn = sub_toggle_visibility },
    { key = "Shift+ц", fn = sub_toggle_visibility },
    { key = "ς", fn = sub_toggle_visibility }, -- Greek 'w'
    { key = "ω", fn = sub_toggle_visibility }, -- Greek 'v'
    { key = "Ω", fn = sub_toggle_visibility },
    { key = "ص", fn = sub_toggle_visibility }, -- Arabic 'w'
    { key = "ר", fn = sub_toggle_visibility }, -- Hebrew 'v'

    -- Fullscreen (physical 'F')
    { key = "ф", fn = toggle_fullscreen }, -- BG Phonetic 'f'
    { key = "Ф", fn = toggle_fullscreen },
    { key = "о", fn = toggle_fullscreen }, -- BG BDS 'f'
    { key = "О", fn = toggle_fullscreen },
    { key = "а", fn = toggle_fullscreen }, -- Russian 'f'
    { key = "А", fn = toggle_fullscreen },
    { key = "φ", fn = toggle_fullscreen }, -- Greek 'f'
    { key = "Φ", fn = toggle_fullscreen },

    -- Pause (physical 'P')
    { key = "п", fn = toggle_pause }, -- BG Phonetic 'p'
    { key = "П", fn = toggle_pause },
    { key = "р", fn = toggle_pause }, -- BG BDS 'p'
    { key = "Р", fn = toggle_pause },
    { key = "з", fn = toggle_pause }, -- Russian 'p'
    { key = "З", fn = toggle_pause },
    { key = "π", fn = toggle_pause }, -- Greek 'p'
    { key = "Π", fn = toggle_pause },

    -- Mute (physical 'M')
    { key = "м", fn = toggle_mute }, -- BG Phonetic 'm'
    { key = "М", fn = toggle_mute },
    { key = "ь", fn = toggle_mute }, -- Russian 'm'
    { key = "Ь", fn = toggle_mute },
    { key = "μ", fn = toggle_mute }, -- Greek 'm'
    { key = "Μ", fn = toggle_mute },

    -- Audio Track (physical 'A')
    { key = "а", fn = cycle_audio }, -- BG Phonetic 'a'
    { key = "А", fn = cycle_audio },
    { key = "α", fn = cycle_audio }, -- Greek 'a'
    { key = "Α", fn = cycle_audio },

    -- Audio Boost (physical 'N')
    { key = "н", fn = cycle_audio_boost }, -- BG Phonetic 'n'
    { key = "Н", fn = cycle_audio_boost },
    { key = "т", fn = cycle_audio_boost }, -- Russian 'n'
    { key = "Т", fn = cycle_audio_boost },
    { key = "ν", fn = cycle_audio_boost }, -- Greek 'n'
    { key = "Ν", fn = cycle_audio_boost },

    -- Subtitle Sizing UP (+10%)
    { key = "Shift+UP", fn = sub_size_up },
    { key = "Shift+Up", fn = sub_size_up },
    { key = "Alt+UP", fn = sub_size_up },
    { key = "Alt+Up", fn = sub_size_up },
    { key = "Ctrl+UP", fn = sub_size_up },
    { key = "Ctrl+Up", fn = sub_size_up },
    { key = "+", fn = sub_size_up },
    { key = "=", fn = sub_size_up },
    { key = "KP_ADD", fn = sub_size_up },
    { key = "Ctrl+KP_ADD", fn = sub_size_up },
    { key = "Ctrl++", fn = sub_size_up },
    { key = "Ctrl+=", fn = sub_size_up },
    { key = "Shift+G", fn = sub_size_up },
    { key = "Shift+g", fn = sub_size_up },
    { key = "Shift+г", fn = sub_size_up },
    { key = "Shift+Г", fn = sub_size_up },
    { key = "Shift+ж", fn = sub_size_up }, -- BG BDS physical G
    { key = "Shift+Ж", fn = sub_size_up },
    { key = "Shift+п", fn = sub_size_up }, -- Russian physical G
    { key = "Shift+П", fn = sub_size_up },
    { key = "Ctrl+WHEEL_UP", fn = sub_size_up },
    { key = "Shift+WHEEL_UP", fn = sub_size_up },

    -- Subtitle Sizing DOWN (-10%)
    { key = "Shift+DOWN", fn = sub_size_down },
    { key = "Shift+Down", fn = sub_size_down },
    { key = "Alt+DOWN", fn = sub_size_down },
    { key = "Alt+Down", fn = sub_size_down },
    { key = "Ctrl+DOWN", fn = sub_size_down },
    { key = "Ctrl+Down", fn = sub_size_down },
    { key = "-", fn = sub_size_down },
    { key = "_", fn = sub_size_down },
    { key = "KP_SUBTRACT", fn = sub_size_down },
    { key = "Ctrl+KP_SUBTRACT", fn = sub_size_down },
    { key = "Ctrl+-", fn = sub_size_down },
    { key = "Ctrl+_", fn = sub_size_down },
    { key = "Shift+F", fn = sub_size_down },
    { key = "Shift+f", fn = sub_size_down },
    { key = "Shift+ф", fn = sub_size_down },
    { key = "Shift+Ф", fn = sub_size_down },
    { key = "Shift+о", fn = sub_size_down }, -- BG BDS physical F
    { key = "Shift+О", fn = sub_size_down },
    { key = "Shift+а", fn = sub_size_down }, -- Russian physical F
    { key = "Shift+А", fn = sub_size_down },
    { key = "Ctrl+WHEEL_DOWN", fn = sub_size_down },
    { key = "Shift+WHEEL_DOWN", fn = sub_size_down },

    -- Subtitle Size Reset (100%)
    { key = "Ctrl+0", fn = sub_size_reset },
    { key = "Ctrl+BS", fn = sub_size_reset },
}

for i, b in ipairs(direct_bindings) do
    mp.add_key_binding(b.key, "univ_direct_" .. i, b.fn)
end

-- ------------------------------------------------------------------------------
-- 3. Comprehensive Character Translation Table (Non-Latin to Physical QWERTY)
-- ------------------------------------------------------------------------------
local char_map = {
    -- Russian (ЙЦУКЕН)
    ["й"] = "q", ["Й"] = "Q", ["ц"] = "w", ["Ц"] = "W", ["у"] = "e", ["У"] = "E",
    ["к"] = "r", ["К"] = "R", ["е"] = "t", ["Е"] = "T", ["н"] = "y", ["Н"] = "Y",
    ["г"] = "u", ["Г"] = "U", ["ш"] = "i", ["Ш"] = "I", ["щ"] = "o", ["Щ"] = "O",
    ["з"] = "p", ["З"] = "P", ["х"] = "[", ["Х"] = "{", ["ъ"] = "]", ["Ъ"] = "}",
    ["ф"] = "a", ["Ф"] = "A", ["ы"] = "s", ["Ы"] = "S", ["в"] = "d", ["В"] = "D",
    ["а"] = "f", ["А"] = "F", ["п"] = "g", ["П"] = "G", ["р"] = "h", ["Р"] = "H",
    ["о"] = "j", ["О"] = "J", ["л"] = "k", ["Л"] = "K", ["д"] = "l", ["Д"] = "L",
    ["ж"] = ";", ["Ж"] = ":", ["э"] = "'", ["Э"] = '"', ["я"] = "z", ["Я"] = "Z",
    ["ч"] = "x", ["Ч"] = "X", ["с"] = "c", ["С"] = "C", ["м"] = "v", ["М"] = "V",
    ["и"] = "b", ["И"] = "B", ["т"] = "n", ["Т"] = "N", ["ь"] = "m", ["Ь"] = "M",
    ["б"] = ",", ["Б"] = "<", ["ю"] = ".", ["Ю"] = ">", ["ё"] = "`", ["Ё"] = "~",

    -- Bulgarian Phonetic Traditional (ЯВЕРТЪ)
    -- Where it differs from standard Russian or provides direct mapping:
    -- 'с' -> 's', 'С' -> 'S', 'в' -> 'w', 'В' -> 'W', 'ж' -> 'v', 'Ж' -> 'V'
    -- 'ф' -> 'f', 'Ф' -> 'F', 'п' -> 'p', 'П' -> 'P', 'м' -> 'm', 'М' -> 'M'
    -- 'а' -> 'a', 'А' -> 'A', 'н' -> 'n', 'Н' -> 'N', 'г' -> 'g', 'Г' -> 'G'
    -- (Covered by direct_bindings and fallback)

    -- Greek (Ελληνικά)
    [";"] = "q", [":"] = "Q", ["ς"] = "w", ["Ϊ"] = "W", ["ε"] = "e", ["Ε"] = "E",
    ["ρ"] = "r", ["Ρ"] = "R", ["τ"] = "t", ["Τ"] = "T", ["υ"] = "y", ["Υ"] = "Y",
    ["θ"] = "u", ["Θ"] = "U", ["ι"] = "i", ["Ι"] = "I", ["ο"] = "o", ["Ο"] = "O",
    ["π"] = "p", ["Π"] = "P", ["α"] = "a", ["Α"] = "A", ["σ"] = "s", ["Σ"] = "S",
    ["δ"] = "d", ["Δ"] = "D", ["φ"] = "f", ["Φ"] = "F", ["γ"] = "g", ["Γ"] = "G",
    ["η"] = "h", ["Η"] = "H", ["ξ"] = "j", ["Ξ"] = "J", ["κ"] = "k", ["Κ"] = "K",
    ["λ"] = "l", ["Λ"] = "L", ["ζ"] = "z", ["Ζ"] = "Z", ["χ"] = "x", ["Χ"] = "X",
    ["ψ"] = "c", ["Ψ"] = "C", ["ω"] = "v", ["Ω"] = "V", ["β"] = "b", ["Β"] = "B",
    ["ν"] = "n", ["Ν"] = "N", ["μ"] = "m", ["Μ"] = "M",

    -- Hebrew
    ["/"] = "q", ["'"] = "w", ["ק"] = "e", ["ר"] = "r", ["א"] = "t", ["ט"] = "y",
    ["ו"] = "u", ["ן"] = "i", ["ם"] = "o", ["פ"] = "p", ["ש"] = "a", ["ד"] = "s",
    ["ג"] = "d", ["כ"] = "f", ["ע"] = "g", ["י"] = "h", ["ח"] = "j", ["ל"] = "k",
    ["ך"] = "l", ["ז"] = "z", ["ס"] = "x", ["ב"] = "c", ["ה"] = "v", ["נ"] = "b",
    ["מ"] = "n", ["צ"] = "m", ["ת"] = ",", ["ץ"] = ".",

    -- Arabic
    ["ض"] = "q", ["ص"] = "w", ["ث"] = "e", ["ق"] = "r", ["ف"] = "t", ["غ"] = "y",
    ["ع"] = "u", ["ه"] = "i", ["خ"] = "o", ["ح"] = "p", ["ج"] = "[", ["د"] = "]",
    ["ش"] = "a", ["س"] = "s", ["ي"] = "d", ["ب"] = "f", ["ل"] = "g", ["ا"] = "h",
    ["ت"] = "j", ["ن"] = "k", ["م"] = "l", ["ك"] = ";", ["ط"] = "'", ["ئ"] = "z",
    ["ء"] = "x", ["ؤ"] = "c", ["ر"] = "v", ["لا"] = "b", ["ى"] = "n", ["ة"] = "m",
    ["و"] = ",", ["ز"] = ".", ["ظ"] = "/",
}

-- ------------------------------------------------------------------------------
-- 4. Dynamic Win32 VkKeyScanExW Engine (LuaJIT FFI)
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
-- 5. Universal "unmapped" Key Re-Injection Interceptor
-- ------------------------------------------------------------------------------
local in_replay = false

local function split_modifiers(key_name)
    local mods = {}
    local key = key_name
    while true do
        local m = key:match("^(%a+)%+(.*)$")
        if m and (m == "Ctrl" or m == "Alt" or m == "Shift" or m == "Meta") then
            table.insert(mods, m)
            key = key:match("^%a+%+(.*)$")
        else
            break
        end
    end
    return mods, key
end

mp.add_key_binding("unmapped", "universal_unmapped_handler", function(ev)
    if in_replay then return end
    if not ev or (ev.event ~= "press" and ev.event ~= "repeat") then return end

    local raw_name = ev.key_name or ""
    if raw_name == "" then return end

    local mods, base_key = split_modifiers(raw_name)

    -- 1. Check pre-computed translation table
    local target = char_map[base_key]

    -- 2. Check dynamic Win32 VkKeyScanExW
    if not target then
        target = translate_win32(base_key)
    end

    -- If no target resolved or target is the same, do nothing
    if not target or target == base_key then return end

    -- Rebuild target key name with modifiers
    local remapped_key = target
    if #mods > 0 then
        remapped_key = table.concat(mods, "+") .. "+" .. target
    end

    if remapped_key == raw_name then return end

    -- Re-inject resolved physical key
    in_replay = true
    mp.commandv("keypress", remapped_key)
    in_replay = false
end, { complex = true })

msg.info(string.format("Universal Physical Keyboard Translator loaded: %d direct bindings, Win32 FFI=%s.",
    #direct_bindings, tostring(user32 ~= nil)))
