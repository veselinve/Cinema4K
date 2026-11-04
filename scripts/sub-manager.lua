-- MPV-Made-Easy - Subtitle & Secondary Subtitle Manager
-- Interactive OSD selector for secondary subtitles, font styling, and font size

local mp = require 'mp'
local utils = require 'mp.utils'

local active_mode = nil -- nil, 'secondary_sub', 'font', 'size'
local overlay = mp.create_osd_overlay("ass-events")

local FONTS = {
    { name = "Source Sans (Default)", font = "Source Sans Variable Roman" },
    { name = "Noto Sans", font = "Noto Sans" },
    { name = "Arial", font = "Arial" },
    { name = "Segoe UI", font = "Segoe UI" },
    { name = "Tahoma", font = "Tahoma" },
    { name = "Verdana", font = "Verdana" },
    { name = "Trebuchet MS", font = "Trebuchet MS" },
    { name = "Calibri", font = "Calibri" },
    { name = "Consolas", font = "Consolas" },
    { name = "Impact", font = "Impact" },
    { name = "Times New Roman", font = "Times New Roman" },
    { name = "Comic Sans MS", font = "Comic Sans MS" },
    { name = "Yu Gothic (Japanese)", font = "Yu Gothic" },
    { name = "Meiryo (Japanese)", font = "Meiryo" },
    { name = "Microsoft YaHei (Chinese)", font = "Microsoft YaHei" }
}

local SIZES = {
    { label = "28 (Very Small)", size = 28, scale = 0.55 },
    { label = "36 (Small)", size = 36, scale = 0.70 },
    { label = "44 (Medium)", size = 44, scale = 0.85 },
    { label = "52 (Default / Large)", size = 52, scale = 1.00 },
    { label = "60 (Extra Large)", size = 60, scale = 1.15 },
    { label = "72 (Huge)", size = 72, scale = 1.40 }
}

-- ---------------------------------------------------------------------------
-- Per-script subtitle styling (Latin / Cyrillic / Japanese / Chinese).
-- Each writing system keeps its own font and size, persisted across
-- sessions, and is applied automatically when the active subtitle's script
-- changes. Only scripts the user has explicitly styled are forced;
-- embedded ASS styling stays untouched otherwise.
-- ---------------------------------------------------------------------------
local SCRIPT_LABELS = {
    latin    = "Latin",
    cyrillic = "Cyrillic",
    japanese = "Japanese",
    chinese  = "Chinese",
}
local style = {
    latin    = { font = "Source Sans Variable Roman", size = 52, active = false },
    cyrillic = { font = "Source Sans Variable Roman", size = 52, active = false },
    japanese = { font = "Yu Gothic",                  size = 52, active = false },
    chinese  = { font = "Microsoft YaHei",            size = 52, active = false },
}
local current_script = nil

local function script_opts_dir()
    local dir = mp.find_config_file("script-opts")
    if not dir or dir == "" then
        dir = mp.command_native({ "expand-path", "~~/script-opts" })
    end
    return dir
end

local function save_style()
    local dir = script_opts_dir()
    if not dir or dir == "" then return end
    local fp = io.open(dir .. "/sub-manager-style.conf", "w")
    if not fp then return end
    for name, s in pairs(style) do
        fp:write(string.format("%s_font=%s\n", name, s.font))
        fp:write(string.format("%s_size=%d\n", name, s.size))
        fp:write(string.format("%s_active=%s\n", name, tostring(s.active)))
    end
    fp:close()
end

local function load_style()
    local dir = script_opts_dir()
    if not dir or dir == "" then return end
    local fp = io.open(dir .. "/sub-manager-style.conf", "r")
    if not fp then return end
    for line in fp:lines() do
        local key, value = line:match("^([%w_]+)=(.*)$")
        if key and value ~= "" then
            local script, field = key:match("^(%w+)_(font|size|active)$")
            if script and style[script] then
                if field == "font" then
                    style[script].font = value
                elseif field == "size" then
                    style[script].size = tonumber(value) or 52
                elseif field == "active" then
                    style[script].active = (value == "true")
                end
            end
        end
    end
    fp:close()
end

-- iterate the unicode codepoints of a UTF-8 string
local function utf8_codepoints(s)
    local i = 1
    return function()
        if i > #s then return nil end
        local b1 = s:byte(i)
        local base, len
        if b1 < 0x80 then base, len = b1, 1
        elseif b1 >= 0xC2 and b1 <= 0xDF then base, len = (b1 - 0xC0) * 64, 2
        elseif b1 >= 0xE0 and b1 <= 0xEF then base, len = (b1 - 0xE0) * 4096, 3
        elseif b1 >= 0xF0 and b1 <= 0xF4 then base, len = (b1 - 0xF0) * 262144, 4
        else i = i + 1; return nil end
        local acc = base
        for j = 1, len - 1 do
            local b = s:byte(i + j)
            if not b or b < 0x80 or b >= 0xC0 then i = i + len; return nil end
            acc = acc + (b - 0x80) * (2 ^ ((len - 1 - j) * 6))
        end
        i = i + len
        return acc
    end
end

-- classify the writing system of a subtitle line
local function detect_script(text)
    if not text or text == "" then return nil end
    local has_cjk, has_cyr, has_latin = false, false, false
    for cp in utf8_codepoints(text) do
        if cp == nil then break end
        -- kana means the line is Japanese regardless of kanji
        if (cp >= 0x3040 and cp <= 0x30FF) or (cp >= 0x31F0 and cp <= 0x31FF)
            or (cp >= 0xFF66 and cp <= 0xFF9D) then
            return "japanese"
        elseif cp >= 0x4E00 and cp <= 0x9FFF then
            has_cjk = true
        elseif cp >= 0x0400 and cp <= 0x04FF then
            has_cyr = true
        elseif (cp >= 0x41 and cp <= 0x5A) or (cp >= 0x61 and cp <= 0x7A) then
            has_latin = true
        end
    end
    if has_cjk then return "chinese" end
    if has_cyr then return "cyrillic" end
    if has_latin then return "latin" end
    return nil
end

local function apply_script_style(script, quiet)
    local s = style[script]
    if not s then return end
    mp.set_property("sub-font", s.font)
    mp.set_property_number("sub-font-size", s.size)
    mp.set_property_number("sub-scale", s.size / 52)
    mp.set_property("sub-ass-override", "force")
    pcall(function() mp.set_property("secondary-sub-ass-override", "force") end)
    if not quiet then
        mp.osd_message(string.format("Subtitle Style [%s]: %s @ %dpx",
            SCRIPT_LABELS[script] or script, s.font, s.size), 2)
    end
    if active_mode then render_ui() end
end

local function current_script_name()
    return current_script or "latin"
end

local function set_font_current(font)
    local sc = current_script_name()
    style[sc].font = font
    style[sc].active = true
    save_style()
    apply_script_style(sc)
end

local function set_size_current(size)
    local sc = current_script_name()
    size = math.max(20, math.min(100, math.floor(size + 0.5)))
    style[sc].size = size
    style[sc].active = true
    save_style()
    apply_script_style(sc)
end

local POSITION_MODES = {
    {
        id = "top",
        name = "Top of Screen (Default)",
        short = "Top",
        sub_pos = 100,
        secondary_sub_pos = 0
    },
    {
        id = "below_primary",
        name = "Below Primary Subtitles (Bottom)",
        short = "Below Primary",
        sub_pos = 86,
        secondary_sub_pos = 100
    },
    {
        id = "above_primary",
        name = "Above Primary Subtitles (Bottom)",
        short = "Above Primary",
        sub_pos = 100,
        secondary_sub_pos = 86
    }
}

local current_pos_index = 1

local function ass_escape(str)
    return tostring(str):gsub('\\', '\\\\'):gsub('{', '\\{'):gsub('}', '\\}')
end

local function disable_dialog_keys()
    mp.remove_key_binding("sub_dialog_esc")
    mp.remove_key_binding("sub_dialog_mbtn")
    for i = 0, 9 do
        mp.remove_key_binding("sub_dialog_" .. tostring(i))
    end
end

local function close_overlay()
    if active_mode then
        active_mode = nil
        disable_dialog_keys()
        overlay.data = ""
        overlay:update()
    end
end

local function get_sub_tracks()
    local tracks = mp.get_property_native("track-list") or {}
    local subs = {}
    for _, t in ipairs(tracks) do
        if t.type == "sub" then
            subs[#subs + 1] = t
        end
    end
    return subs
end

local function apply_pos_mode(idx)
    current_pos_index = idx
    local m = POSITION_MODES[current_pos_index]
    local cur_sec = mp.get_property("secondary-sid")
    if cur_sec and cur_sec ~= "no" and cur_sec ~= "0" then
        mp.set_property_number("sub-pos", m.sub_pos)
        mp.set_property_number("secondary-sub-pos", m.secondary_sub_pos)
    end
    mp.osd_message(string.format("Secondary Subtitle Position: %s\n(Primary: %d%%, Secondary: %d%%)",
        m.name, m.sub_pos, m.secondary_sub_pos), 2.5)
    if active_mode then render_ui() end
end

local function cycle_secondary_pos()
    local next_idx = (current_pos_index % #POSITION_MODES) + 1
    apply_pos_mode(next_idx)
end

local function set_secondary_pos_by_id(pos_id)
    for i, m in ipairs(POSITION_MODES) do
        if m.id == pos_id then
            apply_pos_mode(i)
            return
        end
    end
    apply_pos_mode(1)
end

local function set_secondary_sub(track_id)
    if track_id == 0 or track_id == "no" then
        mp.set_property("secondary-sid", "no")
        mp.set_property_number("sub-pos", 100)
        mp.osd_message("Secondary Subtitles: OFF", 2)
    else
        mp.set_property("secondary-sid", track_id)
        local m = POSITION_MODES[current_pos_index]
        mp.set_property_number("sub-pos", m.sub_pos)
        mp.set_property_number("secondary-sub-pos", m.secondary_sub_pos)
        local tracks = get_sub_tracks()
        local name = "Track " .. track_id
        for _, t in ipairs(tracks) do
            if t.id == track_id then
                name = (t.title or t.lang or ("Track " .. t.id))
                break
            end
        end
        mp.osd_message(string.format("Secondary Subtitle: %s\nPosition: %s", name, m.short), 2.5)
    end
    close_overlay()
end

local function swap_subtitles()
    local sid = mp.get_property("sid")
    local sec_sid = mp.get_property("secondary-sid")

    if not sid or sid == "no" then sid = "no" end
    if not sec_sid or sec_sid == "no" then sec_sid = "no" end

    if sid == "no" and sec_sid == "no" then
        mp.osd_message("No subtitles are currently active to swap", 2)
        return
    end

    mp.set_property("sid", sec_sid)
    mp.set_property("secondary-sid", sid)

    local function get_name(id_str)
        if id_str == "no" then return "None" end
        local num = tonumber(id_str)
        local tracks = get_sub_tracks()
        for _, t in ipairs(tracks) do
            if t.id == num then
                return (t.title or t.lang or ("Track " .. t.id))
            end
        end
        return "Track " .. id_str
    end

    local pos_label = POSITION_MODES[current_pos_index].short
    mp.osd_message(string.format("Swapped Subtitles:\n[Primary]: %s\n[Secondary (%s)]: %s",
        get_name(sec_sid), pos_label, get_name(sid)), 3)
    if active_mode then render_ui() end
end

local function adjust_sub_size(delta)
    local sc = current_script_name()
    local new_size = math.max(20, math.min(100, style[sc].size + delta * 4))
    style[sc].size = new_size
    style[sc].active = true
    save_style()
    apply_script_style(sc, true)
    local percent = math.floor(new_size / 52 * 100 + 0.5)
    mp.osd_message(string.format("Subtitle Size [%s]: %d%% (%d px)",
        SCRIPT_LABELS[sc] or sc, percent, new_size), 2)
    if active_mode == 'size' then render_ui() end
end

local function apply_size_preset(idx)
    local item = SIZES[idx]
    if not item then return end
    set_size_current(item.size)
    if active_mode == 'size' then render_ui() end
    close_overlay()
end

function render_ui()
    if not active_mode then
        overlay.data = ""
        overlay:update()
        return
    end

    local w, h = mp.get_osd_size()
    if not w or w <= 0 or not h or h <= 0 then w, h = 1280, 720 end
    overlay.res_x = w
    overlay.res_y = h

    local ass = {}
    local function a(t) ass[#ass + 1] = t end

    -- Dim background
    a(string.format("{\\pos(0,0)\\an7\\bord0\\shad0\\1c&H0A0B10&\\1a&H40&\\p1}m 0 0 l %d 0 l %d %d l 0 %d{\\p0}", w, w, h, h))

    local box_w = math.min(760, math.floor(w * 0.85))
    local box_h = 470
    local x0 = math.floor((w - box_w) / 2)
    local y0 = math.floor((h - box_h) / 2)
    local x1 = x0 + box_w
    local y1 = y0 + box_h

    -- Main card
    a(string.format("{\\pos(0,0)\\an7\\bord2\\3c&H38BDF8&\\1c&H161923&\\1a&H08&\\p1}m %d %d l %d %d l %d %d l %d %d{\\p0}", x0, y0, x1, y0, x1, y1, x0, y1))
    -- Title bar
    a(string.format("{\\pos(0,0)\\an7\\bord0\\shad0\\1c&H1E293B&\\1a&H00&\\p1}m %d %d l %d %d l %d %d l %d %d{\\p0}", x0, y0, x1, y0, x1, y0 + 44, x0, y0 + 44))

    local title = "Subtitle Manager"
    if active_mode == 'secondary_sub' then
        title = "Select Secondary Subtitle & Position (Top vs Below Primary)"
    elseif active_mode == 'font' then
        title = "Select Subtitle Font Family"
    elseif active_mode == 'size' then
        title = "Select Subtitle Font Size"
    end

    a(string.format("{\\pos(%d,%d)\\an4\\fnSource Sans Pro,Arial,sans-serif\\fs17\\b1\\1c&H38BDF8&}  %s{\\b0}",
        x0 + 16, y0 + 22, ass_escape(title)))
    a(string.format("{\\pos(%d,%d)\\an6\\fnSource Sans Pro,Arial,sans-serif\\fs13\\1c&H94A3B8&}[ Esc / Close ]  ",
        x1 - 16, y0 + 22))

    local content_y = y0 + 60
    local line_h = 28

    if active_mode == 'secondary_sub' then
        local subs = get_sub_tracks()
        local cur_sid = tonumber(mp.get_property("sid")) or -1
        local cur_sec = tonumber(mp.get_property("secondary-sid")) or -1

        if #subs == 0 then
            a(string.format("{\\pos(%d,%d)\\an7\\fnSource Sans Pro,Arial,sans-serif\\fs15\\1c&HF8FAFC&}No subtitle tracks found in the current video.",
                x0 + 40, content_y + 30))
        else
            a(string.format("{\\pos(%d,%d)\\an7\\fnSource Sans Pro,Arial,sans-serif\\fs13\\1c&HFBBF24&\\b1}Press number [ 1 ] - [ %d ] to choose track as Secondary Subtitle, or [ 0 ] to turn OFF:{\\b0}",
                x0 + 40, content_y, math.min(9, #subs)))
            content_y = content_y + 24

            for idx, track in ipairs(subs) do
                if idx <= 9 then
                    local is_primary = (track.id == cur_sid)
                    local is_secondary = (track.id == cur_sec)

                    local marker = ""
                    local col = "&HE2E8F0&"
                    if is_secondary then
                        marker = string.format("  {\\1c&H38BDF8&\\b1}[✓ Active Secondary (%s)]{\\b0}", POSITION_MODES[current_pos_index].short)
                        col = "&H38BDF8&"
                    elseif is_primary then
                        marker = "  {\\1c&HFBBF24&}[Active Primary (Bottom)]"
                    end

                    local track_desc = track.title or ""
                    if track.lang then
                        track_desc = track_desc ~= "" and (track_desc .. " (" .. track.lang:upper() .. ")") or track.lang:upper()
                    end
                    if track.codec then
                        track_desc = track_desc .. " [" .. track.codec .. "]"
                    end
                    if track_desc == "" then track_desc = "Track " .. track.id end

                    a(string.format("{\\pos(%d,%d)\\an7\\fnSource Sans Pro,Arial,sans-serif\\fs14\\b1\\1c&H38BDF8&}[ %d ]{\\b0} {\\1c%s\\fs14}%s%s",
                        x0 + 40, content_y, idx, col, ass_escape(track_desc), marker))
                    content_y = content_y + line_h
                end
            end

            -- Option 0: Off
            a(string.format("{\\pos(%d,%d)\\an7\\fnSource Sans Pro,Arial,sans-serif\\fs14\\b1\\1c&H94A3B8&}[ 0 ]{\\b0} {\\1c&H94A3B8&\\fs14}Disable Secondary Subtitle (Turn OFF)%s",
                x0 + 40, content_y, (cur_sec <= 0) and "  {\\1c&H94A3B8&}[Currently Off]" or ""))
            content_y = content_y + line_h + 8

            -- Quick action keys
            a(string.format("{\\pos(%d,%d)\\an7\\fnSource Sans Pro,Arial,sans-serif\\fs13\\1c&H38BDF8&\\b1}[ S ]{\\b0} {\\1c&HE2E8F0&}Swap Subs   {\\1c&H38BDF8&\\b1}[ V ]{\\b0} {\\1c&HE2E8F0&}Toggle Visibility   {\\1c&HFBBF24&\\b1}[ T / P ]{\\b0} {\\1c&HE2E8F0&}Position: {\\1c&H38BDF8&\\b1}%s{\\b0}",
                x0 + 40, content_y, POSITION_MODES[current_pos_index].name))
        end

    elseif active_mode == 'font' then
        local sc = current_script_name()
        local cur_font = style[sc].font
        a(string.format("{\\pos(%d,%d)\\an7\\fnSource Sans Pro,Arial,sans-serif\\fs13\\1c&HFBBF24&\\b1}Font for [%s] subtitles — pick [ 1 ] - [ %d ] (forced for ASS):{\\b0}",
            x0 + 40, content_y, SCRIPT_LABELS[sc] or sc, #FONTS))
        content_y = content_y + 24

        for idx, item in ipairs(FONTS) do
            local is_cur = (cur_font:lower():find(item.font:lower(), 1, true) ~= nil)
            local marker = is_cur and "  {\\1c&H38BDF8&\\b1}[✓ Current Font]{\\b0}" or ""
            local col = is_cur and "&H38BDF8&" or "&HE2E8F0&"

            a(string.format("{\\pos(%d,%d)\\an7\\fn%s,Arial\\fs14\\b1\\1c&H38BDF8&}[ %d ]{\\b0} {\\1c%s\\fs14}%s%s",
                item.font, x0 + 40, content_y, idx, col, ass_escape(item.name), marker))
            content_y = content_y + line_h - 2
        end

    elseif active_mode == 'size' then
        local sc = current_script_name()
        local cur_size = style[sc].size
        local percent = math.floor(cur_size / 52 * 100 + 0.5)
        a(string.format("{\\pos(%d,%d)\\an7\\fnSource Sans Pro,Arial,sans-serif\\fs13\\1c&HFBBF24&\\b1}Size for [%s] subtitles — pick [ 1 ] - [ %d ], [ + ] / [ - ] to scale (Current: %d%% / %dpx):{\\b0}",
            x0 + 40, content_y, SCRIPT_LABELS[sc] or sc, #SIZES, percent, cur_size))
        content_y = content_y + 24

        for idx, item in ipairs(SIZES) do
            local is_cur = (math.abs(cur_size - item.size) < 2)
            local marker = is_cur and "  {\\1c&H38BDF8&\\b1}[✓ Current Size]{\\b0}" or ""
            local col = is_cur and "&H38BDF8&" or "&HE2E8F0&"

            a(string.format("{\\pos(%d,%d)\\an7\\fnSource Sans Pro,Arial\\fs14\\b1\\1c&H38BDF8&}[ %d ]{\\b0} {\\1c%s\\fs14}Font Size: %s%s",
                x0 + 40, content_y, idx, col, ass_escape(item.label), marker))
            content_y = content_y + line_h
        end
    end

    -- Bottom instructions
    local foot_y = y1 - 28
    a(string.format("{\\pos(%d,%d)\\an4\\fnSource Sans Pro,Arial,sans-serif\\fs12\\1c&H94A3B8&}  Click or press key to select  |  Right-click context menu also has all subtitle options",
        x0 + 16, foot_y))
    a(string.format("{\\pos(%d,%d)\\an6\\fnSource Sans Pro,Arial,sans-serif\\fs12\\1c&H38BDF8&\\b1}Press Esc to Close  {\\b0}",
        x1 - 16, foot_y))

    overlay.data = table.concat(ass, "\n")
    overlay:update()
end

local function handle_dialog_num_key(num)
    if active_mode == 'secondary_sub' then
        if num == 0 then
            set_secondary_sub(0)
        else
            local subs = get_sub_tracks()
            if subs[num] then set_secondary_sub(subs[num].id) end
        end
    elseif active_mode == 'font' then
        if FONTS[num] then
            set_font_current(FONTS[num].font)
            close_overlay()
        end
    elseif active_mode == 'size' then
        if SIZES[num] then
            apply_size_preset(num)
        end
    end
end

local function enable_dialog_keys()
    mp.add_forced_key_binding("ESC", "sub_dialog_esc", close_overlay)
    mp.add_forced_key_binding("MBTN_LEFT", "sub_dialog_mbtn", close_overlay)
    for i = 0, 9 do
        local num = i
        mp.add_forced_key_binding(tostring(num), "sub_dialog_" .. num, function() handle_dialog_num_key(num) end)
    end
end

local function open_secondary_selector()
    active_mode = 'secondary_sub'
    enable_dialog_keys()
    render_ui()
end

local function open_font_chooser()
    active_mode = 'font'
    enable_dialog_keys()
    render_ui()
end

local function open_size_chooser()
    active_mode = 'size'
    enable_dialog_keys()
    render_ui()
end

local function cycle_sub_track(direction)
    local tracks = mp.get_property_native("track-list") or {}
    local sub_tracks = {}
    for _, t in ipairs(tracks) do
        if t.type == "sub" then
            sub_tracks[#sub_tracks + 1] = t
        end
    end

    if #sub_tracks == 0 then
        mp.osd_message("No subtitles available", 2)
        return
    end

    -- Ensure visibility is on when cycling tracks
    mp.set_property("sub-visibility", "yes")

    local cur_sid = mp.get_property("sid")
    local cur_idx = 0
    if cur_sid and cur_sid ~= "no" and cur_sid ~= "0" then
        for i, t in ipairs(sub_tracks) do
            if tostring(t.id) == tostring(cur_sid) then
                cur_idx = i
                break
            end
        end
    end

    local next_idx
    if direction > 0 then
        if cur_idx >= #sub_tracks then
            next_idx = 0
        else
            next_idx = cur_idx + 1
        end
    else
        if cur_idx <= 0 then
            next_idx = #sub_tracks
        else
            next_idx = cur_idx - 1
        end
    end

    if next_idx == 0 then
        mp.set_property("sid", "no")
        mp.osd_message("Subtitles: OFF", 2)
    else
        local target = sub_tracks[next_idx]
        mp.set_property("sid", tostring(target.id))
        local title = target.title or (target.lang and target.lang:upper()) or ("Track " .. target.id)
        local lang = target.lang and (" [" .. target.lang:upper() .. "]") or ""
        mp.osd_message(string.format("Subtitles [%d/%d]: %s%s", next_idx, #sub_tracks, title, lang), 2.5)
    end
end

local function toggle_sub_visibility()
    local tracks = mp.get_property_native("track-list") or {}
    local has_sub_tracks = false
    for _, t in ipairs(tracks) do
        if t.type == "sub" then has_sub_tracks = true break end
    end

    if not has_sub_tracks then
        mp.osd_message("No subtitles available", 2)
        return
    end

    local cur_sid = mp.get_property("sid")
    if not cur_sid or cur_sid == "no" or cur_sid == "0" then
        mp.set_property("sub-visibility", "yes")
        cycle_sub_track(1)
        return
    end

    local cur_vis = mp.get_property_bool("sub-visibility")
    local new_vis = not cur_vis
    mp.set_property_bool("sub-visibility", new_vis)
    if new_vis then
        mp.osd_message("Subtitles: Visible", 2)
    else
        mp.osd_message("Subtitles: Hidden", 2)
    end
end

mp.register_script_message("select-secondary", open_secondary_selector)
mp.register_script_message("choose-font", open_font_chooser)
mp.register_script_message("choose-size", open_size_chooser)
mp.register_script_message("swap", swap_subtitles)
mp.register_script_message("cycle-pos", cycle_secondary_pos)
mp.register_script_message("set-pos", set_secondary_pos_by_id)
mp.register_script_message("cycle-sub-next", function() cycle_sub_track(1) end)
mp.register_script_message("cycle-sub-prev", function() cycle_sub_track(-1) end)
mp.register_script_message("toggle-sub-visibility", toggle_sub_visibility)
mp.register_script_message("size-up", function() adjust_sub_size(1) end)
mp.register_script_message("size-down", function() adjust_sub_size(-1) end)
mp.register_script_message("size-reset", function()
    set_size_current(52)
    mp.osd_message("Subtitle Size: Reset to 100% (52 px)", 2)
    if active_mode == 'size' then render_ui() end
end)

mp.register_script_message("set-font", function(font)
    if font and font ~= "" then set_font_current(font) end
end)

mp.register_script_message("set-size", function(size)
    local n = tonumber(size)
    if n then set_size_current(n) end
end)

load_style()

-- detect the writing system of the active subtitle and apply the style
-- saved for it (only when the user has styled that script)
mp.observe_property("sub-text", "native", function(_, text)
    local sc = detect_script(text)
    if sc and sc ~= current_script then
        current_script = sc
        if style[sc].active then
            apply_script_style(sc, true)
        end
    end
end)
