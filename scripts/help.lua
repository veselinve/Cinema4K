-- MPV-Made-Easy Help & Shortcut Keys Overlay
-- Provides English explanations for all keyboard and mouse shortcuts

local mp = require 'mp'
local utils = require 'mp.utils'

local active = false
local current_tab = 1
local overlay = mp.create_osd_overlay("ass-events")

local TABS = {
    { id = "all", title = "Overview / Quick Reference" },
    { id = "playback", title = "Playback & Navigation" },
    { id = "audiosub", title = "Audio & Subtitles" },
    { id = "video", title = "Video, Shaders & Display" },
    { id = "window", title = "Window, Menu & General" }
}

local SHORTCUTS = {
    playback = {
        { key = "Left Click", desc = "Play / Pause playback (Single click on video)" },
        { key = "Double Left Click", desc = "Toggle Fullscreen mode (Big / Small screen)" },
        { key = "Right Click / [ ⚙ ]", desc = "Open / Close Settings & Options Menu (Toggle)" },
        { key = "Space", desc = "Play / Pause playback" },
        { key = "Period ( . )", desc = "Stop playback" },
        { key = "Right / Left", desc = "Seek forward / backward 5 seconds" },
        { key = "Up / Down", desc = "Seek forward / backward 30 seconds" },
        { key = "Ctrl+Right / Left", desc = "Seek forward / backward 5 minutes" },
        { key = ". / ,", desc = "Frame step forward / backward (1 frame)" },
        { key = "[ / ]", desc = "Decrease / Increase playback speed by 10%" },
        { key = "{ / }", desc = "Half speed (0.5x) / Double speed (2.0x)" },
        { key = "Backspace", desc = "Reset playback speed to 1.0x" },
        { key = "Enter", desc = "Play next file in current playlist" },
        { key = "Ctrl+Enter", desc = "Play previous file in current playlist" },
        { key = "Mouse Btn 7 / 8", desc = "Skip to previous / next chapter" },
        { key = "PgUp / PgDown", desc = "Previous / Next chapter" },
        { key = "Ctrl+G", desc = "Jump to specific timestamp (Go-To dialog)" },
        { key = "L", desc = "Set / Clear A-B repeat loop points" },
        { key = "Shift+L", desc = "Toggle infinite file looping" },
    },
    audiosub = {
        { key = "A", desc = "Cycle through available audio tracks" },
        { key = "Ctrl+D / Ctrl+Shift+D", desc = "Adjust audio delay (+0.1s / -0.1s)" },
        { key = "Up / Down / Wheel", desc = "Increase / Decrease volume by 5%" },
        { key = "M", desc = "Toggle audio mute on / off" },
        { key = "N / Ctrl+B", desc = "Cycle Audio Boost & Speech Normalizer (Clarity / MPC 400% / Night)" },
        { key = "Ctrl+E", desc = "Toggle 15-band graphic equalizer" },
        { key = "C", desc = "Cycle audio visualizer modes" },
        { key = "-------------------", desc = "----------------------------------------" },
        { key = "s", desc = "Next subtitle track" },
        { key = "Shift+S", desc = "Previous subtitle track" },
        { key = "W / V", desc = "Toggle primary subtitle visibility on / off" },
        { key = "Shift+G / Shift+F", desc = "Increase / Decrease subtitle size (+10% / -10%)" },
        { key = "Ctrl+Shift+Up / Down", desc = "Increase / Decrease subtitle size (+10% / -10%)" },
        { key = "Settings (Gear) > Subtitles", desc = "Font size picker, font families, and color settings" },
        { key = "Z / Shift+Z", desc = "Adjust subtitle delay (-0.1s / +0.1s)" },
        { key = "R / Shift+R", desc = "Move subtitle position up / down" },
        { key = "Alt+S", desc = "Cycle secondary subtitle track from video" },
        { key = "Ctrl+Shift+S", desc = "Open on-screen Secondary Subtitle Selector & Position" },
        { key = "Alt+W", desc = "Swap Primary and Secondary Subtitles" },
        { key = "Alt+T", desc = "Switch Secondary Subtitle Position (Top / Below Primary / Above)" },
        { key = "Alt+V", desc = "Toggle secondary subtitle visibility" },
        { key = "Settings Menu (Gear)", desc = "Select Subtitle Tracks, Font Family & Font Size" },
    },
    video = {
        { key = "Enter / F11 / F", desc = "Toggle fullscreen mode" },
        { key = "Alt+0 / 1 / 2 / 3", desc = "Set window zoom: 50% / 100% / 200% / 300%" },
        { key = "Alt+Plus / Minus", desc = "Enlarge / Shrink player window" },
        { key = "Ctrl+R", desc = "Rotate video 90 degrees clockwise" },
        { key = "Ctrl+Plus / Minus", desc = "Pan & Scan: Zoom video in / out" },
        { key = "Ctrl+Numpad / Arrows", desc = "Pan video position (left, right, up, down)" },
        { key = "Ctrl+Backspace", desc = "Reset video zoom and pan to default" },
        { key = "D / Shift+D", desc = "Toggle deinterlacing / debanding" },
        { key = "Ctrl+H", desc = "Toggle Hardware Decoding (auto-safe / no)" },
        { key = "Ctrl+S", desc = "Take screenshot with subtitles" },
        { key = "Ctrl+Alt+S", desc = "Take screenshot without subtitles (clean)" },
        { key = "F5", desc = "Cinema4K 3-Band Master (Pure LUMA Optical Engine)" },
        { key = "Alt+F5", desc = "Cinema4K Master V4 (Intelligent Coring for YTS/Compression)" },
        { key = "Ctrl+F5", desc = "Cinema4K Master Clarity V1" },
        { key = "F4", desc = "Cinema4K FaceSR Ultra (Legacy Best)" },
        { key = "F7 / Ctrl+0", desc = "Clear all active GLSL shaders (Shaders OFF)" },
        { key = "Ctrl+1 .. Ctrl+6", desc = "Activate Anime4K shaders (Modes A, B, C, A+A, B+B, C+A)" },
        { key = "F10", desc = "Show currently active shaders on screen" },
        { key = "Settings (Gear) > Color", desc = "Adjust contrast, brightness, gamma, saturation" },
    },
    window = {
        { key = "Right Click (Video) / [ ⚙ ]", desc = "Open and close (toggle) Settings & Options Menu" },
        { key = "Menu (Keyboard)", desc = "Open full Settings & Options Menu" },
        { key = "Ctrl+O", desc = "Open File (Native Windows Dialog)" },
        { key = "Ctrl+Shift+O", desc = "Open Folder (Native Windows Dialog)" },
        { key = "Ctrl+V", desc = "Open video or stream URL from Clipboard" },
        { key = "Ctrl+T", desc = "Toggle Always on Top (Disabled by default)" },
        { key = "B", desc = "Toggle window borders and title bar" },
        { key = "Ctrl+P", desc = "Show interactive Playlist Manager overlay" },
        { key = "P", desc = "Peek at current playlist" },
        { key = "Shift+I / T", desc = "Toggle media & performance statistics" },
        { key = "Del", desc = "Toggle On-Screen Controller (OSC) visibility" },
        { key = "` (Grave / Tilde)", desc = "Toggle interactive MPV console" },
        { key = "F1 / H", desc = "Toggle this Help & Shortcuts screen" },
        { key = "Esc", desc = "Close Help overlay / Exit fullscreen" },
        { key = "Alt+X / Q", desc = "Quit MPV" },
    }
}

local function ass_escape(str)
    return tostring(str):gsub('\\', '\\\\'):gsub('{', '\\{'):gsub('}', '\\}')
end

local function render_help()
    if not active then
        overlay.data = ""
        overlay:update()
        return
    end

    local w, h = mp.get_osd_size()
    if not w or w <= 0 or not h or h <= 0 then
        w, h = 1280, 720
    end

    overlay.res_x = w
    overlay.res_y = h

    local ass = {}
    local function a(text) ass[#ass + 1] = text end

    -- Background dimming overlay
    a(string.format("{\\pos(0,0)\\an7\\bord0\\shad0\\1c&H0A0B10&\\1a&H30&\\p1}m 0 0 l %d 0 l %d %d l 0 %d{\\p0}", w, w, h, h))

    -- Main dialog container box
    local box_w = math.min(1080, math.floor(w * 0.92))
    local box_h = math.min(680, math.floor(h * 0.90))
    local x0 = math.floor((w - box_w) / 2)
    local y0 = math.floor((h - box_h) / 2)
    local x1 = x0 + box_w
    local y1 = y0 + box_h

    -- Container background and border
    a(string.format("{\\pos(0,0)\\an7\\bord2\\3c&H475569&\\1c&H161923&\\1a&H08&\\p1}m %d %d l %d %d l %d %d l %d %d{\\p0}", x0, y0, x1, y0, x1, y1, x0, y1))

    -- Header background bar
    local header_h = 48
    a(string.format("{\\pos(0,0)\\an7\\bord0\\shad0\\1c&H1E293B&\\1a&H00&\\p1}m %d %d l %d %d l %d %d l %d %d{\\p0}", x0, y0, x1, y0, x1, y0 + header_h, x0, y0 + header_h))

    -- Header Title
    local title_font_size = math.max(16, math.min(22, math.floor(header_h * 0.44)))
    a(string.format("{\\pos(%d,%d)\\an4\\fnSource Sans Pro,Arial,sans-serif\\fs%d\\b1\\1c&H38BDF8&\\shad1\\4c&H000000&}  MPV-Made-Easy  {\\1c&H94A3B8&\\b0}|  {\\1c&HFFFFFF&\\b1}Keyboard Shortcuts & Controls{\\b0}",
        x0 + 16, y0 + math.floor(header_h / 2), title_font_size))

    -- Close prompt in header
    a(string.format("{\\pos(%d,%d)\\an6\\fnSource Sans Pro,Arial,sans-serif\\fs%d\\1c&H94A3B8&}[ Esc / F1 / H to close ]  ",
        x1 - 16, y0 + math.floor(header_h / 2), title_font_size - 4))

    -- Tab Bar below header
    local tab_y = y0 + header_h + 8
    local tab_h = 32
    local cur_x = x0 + 20
    for idx, tab in ipairs(TABS) do
        local is_sel = (idx == current_tab)
        local bg_col = is_sel and "&H0284C7&" or "&H334155&"
        local txt_col = is_sel and "&HFFFFFF&" or "&HCBD5E1&"
        local tw = 180
        if idx == 1 then tw = 210 end

        -- Tab button pill
        a(string.format("{\\pos(0,0)\\an7\\bord1\\3c&H64748B&\\1c%s\\1a&H10&\\p1}m %d %d l %d %d l %d %d l %d %d{\\p0}",
            bg_col, cur_x, tab_y, cur_x + tw, tab_y, cur_x + tw, tab_y + tab_h, cur_x, tab_y + tab_h))
        a(string.format("{\\pos(%d,%d)\\an5\\fnSource Sans Pro,Arial,sans-serif\\fs13\\b%d\\1c%s}[%d] %s",
            cur_x + math.floor(tw / 2), tab_y + math.floor(tab_h / 2), is_sel and 1 or 0, txt_col, idx, tab.title))

        cur_x = cur_x + tw + 10
    end

    -- Content Area
    local content_y = tab_y + tab_h + 16
    local content_h = y1 - content_y - 36
    local font_sz = 13
    local line_spacing = 22

    if current_tab == 1 then
        -- Overview tab: 2 equal columns showing the most important shortcuts
        local col_w = math.floor((box_w - 60) / 2)
        local col1_x = x0 + 25
        local col2_x = col1_x + col_w + 10

        local sections = {
            {
                title = "PLAYBACK & NAVIGATION",
                col = 1,
                items = {
                    { k = "Space", d = "Play / Pause playback" },
                    { k = "Period ( . )", d = "Stop playback" },
                    { k = "Right / Left", d = "Seek 5 seconds forward / backward" },
                    { k = "Up / Down", d = "Seek 30 seconds forward / backward" },
                    { k = "Ctrl+Right / Left", d = "Seek 5 minutes forward / backward" },
                    { k = ".  /  ,", d = "Frame step forward / backward" },
                    { k = "[  /  ]", d = "Speed -10% / +10% (Backspace: Reset)" },
                    { k = "Enter / Ctrl+Enter", d = "Next / Previous file in playlist" },
                    { k = "Ctrl+G", d = "Go to specific timestamp" },
                }
            },
            {
                title = "AUDIO & SUBTITLES",
                col = 1,
                items = {
                    { k = "A", d = "Cycle audio track" },
                    { k = "N / Ctrl+B", d = "Cycle Audio Boost / Speech Clarity (MPC 400%)" },
                    { k = "Ctrl+D / Ctrl+Shift+D", d = "Audio delay (+0.1s / -0.1s)" },
                    { k = "Up / Down / Wheel", d = "Volume up / down (+/- 5%)" },
                    { k = "M", d = "Toggle audio mute" },
                    { k = "S / V", d = "Cycle subtitle track / Toggle visibility" },
                    { k = "Shift+G / Shift+F", d = "Increase / Decrease subtitle size" },
                    { k = "Alt+W", d = "Swap Primary and Secondary Subs" },
                    { k = "Alt+T", d = "Secondary Position: Top / Below Primary" },
                    { k = "Z / Shift+Z", d = "Subtitle delay (-0.1s / +0.1s)" },
                }
            },
            {
                title = "VIDEO, SHADERS & WINDOW",
                col = 2,
                items = {
                    { k = "Enter / F11 / F", d = "Toggle Fullscreen" },
                    { k = "Alt+0 / 1 / 2 / 3", d = "Zoom 50% / 100% / 200% / 300%" },
                    { k = "Ctrl+R", d = "Rotate video 90 degrees" },
                    { k = "Ctrl+H", d = "Toggle Hardware Decoding (auto/off)" },
                    { k = "Shift+S / Ctrl+S", d = "Screenshot with / without subtitles" },
                    { k = "Ctrl+0 / F7", d = "Shaders OFF (Clear shaders)" },
                    { k = "Ctrl+1 .. Ctrl+6", d = "Anime4K Modes (HQ Upscale & Restore)" },
                    { k = "F8 / F9 / F10", d = "AiUpscale Photo / Sharp / Active shaders" },
                    { k = "Ctrl+T", d = "Toggle Always on Top (Off by default)" },
                }
            },
            {
                title = "MOUSE & INTERACTION",
                col = 2,
                items = {
                    { k = "Left Click", d = "Play / Pause playback (Single click on video)" },
                    { k = "Double Left Click", d = "Toggle Fullscreen mode (Big / Small screen)" },
                    { k = "Right Click / [ ⚙ ]", d = "Open / Close Settings & Options Menu (Toggle)" },
                    { k = "Ctrl+O", d = "Open File (Native Windows Dialog)" },
                    { k = "Ctrl+Shift+O", d = "Open Folder (Native Windows Dialog)" },
                    { k = "Ctrl+V", d = "Open URL or Path from Clipboard" },
                    { k = "Ctrl+P", d = "Playlist overlay (Up/Down to browse)" },
                    { k = "F1 / H", d = "Toggle this Help window (Esc to close)" },
                }
            }
        }

        local y_left = content_y
        local y_right = content_y

        for _, sec in ipairs(sections) do
            local sx = (sec.col == 1) and col1_x or col2_x
            local sy = (sec.col == 1) and y_left or y_right

            -- Section Header
            a(string.format("{\\pos(%d,%d)\\an7\\fnSource Sans Pro,Arial,sans-serif\\fs%d\\b1\\1c&HFBBF24&}%s{\\b0}",
                sx, sy, font_sz + 1, sec.title))
            sy = sy + line_spacing

            for _, item in ipairs(sec.items) do
                -- Key badge
                a(string.format("{\\pos(%d,%d)\\an7\\fnSource Sans Pro,Arial,sans-serif\\fs%d\\b1\\1c&H38BDF8&}[ %s ]{\\b0}",
                    sx + 4, sy, font_sz, ass_escape(item.k)))
                -- Description
                a(string.format("{\\pos(%d,%d)\\an7\\fnSource Sans Pro,Arial,sans-serif\\fs%d\\1c&HE2E8F0&}%s",
                    sx + 155, sy, font_sz, ass_escape(item.d)))
                sy = sy + line_spacing
            end

            sy = sy + 6
            if sec.col == 1 then y_left = sy else y_right = sy end
        end

    else
        -- Specific Category Tab
        local tab_keys = { "all", "playback", "audiosub", "video", "window" }
        local cur_key = tab_keys[current_tab] or "playback"
        local list = SHORTCUTS[cur_key] or {}

        local sx = x0 + 40
        local sy = content_y + 10

        -- Table Header
        a(string.format("{\\pos(%d,%d)\\an7\\fnSource Sans Pro,Arial,sans-serif\\fs%d\\b1\\1c&HFBBF24&}KEY / SHORTCUT BUTTON{\\b0}", sx + 10, sy, font_sz + 2))
        a(string.format("{\\pos(%d,%d)\\an7\\fnSource Sans Pro,Arial,sans-serif\\fs%d\\b1\\1c&HFBBF24&}DESCRIPTION & FUNCTION (ENGLISH){\\b0}", sx + 250, sy, font_sz + 2))
        sy = sy + 28

        for _, item in ipairs(list) do
            if item.key:find("^%-+$") then
                -- Divider
                a(string.format("{\\pos(%d,%d)\\an7\\fnSource Sans Pro,Arial,sans-serif\\fs%d\\1c&H475569&}----------------------------------------------------------------------------------------------------------------", sx + 10, sy, font_sz))
                sy = sy + line_spacing - 4
            else
                -- Key pill badge
                a(string.format("{\\pos(%d,%d)\\an7\\fnSource Sans Pro,Arial,sans-serif\\fs%d\\b1\\1c&H38BDF8&}[ %s ]{\\b0}",
                    sx + 10, sy, font_sz + 1, ass_escape(item.key)))
                -- Description
                a(string.format("{\\pos(%d,%d)\\an7\\fnSource Sans Pro,Arial,sans-serif\\fs%d\\1c&HF8FAFC&}%s",
                    sx + 250, sy, font_sz + 1, ass_escape(item.desc)))
                sy = sy + line_spacing + 3
            end
        end
    end

    -- Footer bar with quick navigation help
    local footer_y = y1 - 28
    a(string.format("{\\pos(%d,%d)\\an4\\fnSource Sans Pro,Arial,sans-serif\\fs12\\1c&H94A3B8&}  Press [ 1 ] - [ 5 ] to switch tabs  |  [ Left / Right ] next tab  |  Right-click video / [ ⚙ ] for Settings",
        x0 + 16, footer_y))
    a(string.format("{\\pos(%d,%d)\\an6\\fnSource Sans Pro,Arial,sans-serif\\fs12\\1c&H38BDF8&\\b1}Press Esc, F1 or H to Close  {\\b0}",
        x1 - 16, footer_y))

    overlay.data = table.concat(ass, "\n")
    overlay:update()
end

local function show_tab(tab_idx)
    current_tab = tab_idx or 1
    if not active then
        active = true
        mp.enable_key_bindings("help_bindings")
    end
    render_help()
end

local function toggle_help()
    if active then
        active = false
        mp.disable_key_bindings("help_bindings")
        overlay.data = ""
        overlay:update()
    else
        show_tab(1)
    end
end

-- Key bindings active only while help overlay is visible
mp.set_key_bindings({
    { "ESC", toggle_help },
    { "f1", toggle_help },
    { "h", toggle_help },
    { "H", toggle_help },
    { "1", function() show_tab(1) end },
    { "2", function() show_tab(2) end },
    { "3", function() show_tab(3) end },
    { "4", function() show_tab(4) end },
    { "5", function() show_tab(5) end },
    { "LEFT", function()
        current_tab = (current_tab > 1) and (current_tab - 1) or #TABS
        render_help()
    end },
    { "RIGHT", function()
        current_tab = (current_tab < #TABS) and (current_tab + 1) or 1
        render_help()
    end },
    { "MBTN_LEFT", toggle_help },
}, "help_bindings", "force")

-- Re-render on window resize
mp.observe_property("osd-width", "native", function()
    if active then render_help() end
end)
mp.observe_property("osd-height", "native", function()
    if active then render_help() end
end)

-- Script bindings and messages
mp.add_key_binding("F1", "show-help", toggle_help)
mp.add_key_binding("h", "toggle-help-h", toggle_help)
mp.add_key_binding("H", "toggle-help-H", toggle_help)

mp.register_script_message("show-help", function() show_tab(1) end)
mp.register_script_message("show-playback", function() show_tab(2) end)
mp.register_script_message("show-audio-sub", function() show_tab(3) end)
mp.register_script_message("show-video", function() show_tab(4) end)
mp.register_script_message("show-about", function() show_tab(5) end)

-- Ensure help bindings are strictly disabled on load
mp.disable_key_bindings("help_bindings")
