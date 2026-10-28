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
    { name = "Comic Sans MS", font = "Comic Sans MS" }
}

local SIZES = {
    { label = "28 (Very Small)", size = 28, scale = 0.55 },
    { label = "36 (Small)", size = 36, scale = 0.70 },
    { label = "44 (Medium)", size = 44, scale = 0.85 },
    { label = "52 (Default / Large)", size = 52, scale = 1.00 },
    { label = "60 (Extra Large)", size = 60, scale = 1.15 },
    { label = "72 (Huge)", size = 72, scale = 1.40 }
}

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
    local cur_scale = tonumber(mp.get_property("sub-scale")) or 1.0
    local cur_size = tonumber(mp.get_property("sub-font-size")) or 52

    local new_scale = math.max(0.4, math.min(3.0, cur_scale + delta * 0.1))
    new_scale = math.floor(new_scale * 10 + 0.5) / 10

    local new_size = math.max(20, math.min(100, math.floor(cur_size + delta * 4 + 0.5)))

    mp.set_property_number("sub-scale", new_scale)
    mp.set_property_number("sub-font-size", new_size)
    mp.set_property("sub-ass-override", "force")
    pcall(function() mp.set_property("secondary-sub-ass-override", "force") end)

    local percent = math.floor(new_scale * 100 + 0.5)
    mp.osd_message(string.format("Subtitle Size: %d%% (%d px)", percent, new_size), 2)
    if active_mode == 'size' then render_ui() end
end

local function apply_size_preset(idx)
    local item = SIZES[idx]
    if not item then return end
    mp.set_property_number("sub-font-size", item.size)
    mp.set_property_number("sub-scale", item.scale)
    mp.set_property("sub-ass-override", "force")
    pcall(function() mp.set_property("secondary-sub-ass-override", "force") end)
    mp.osd_message(string.format("Subtitle Size: %s", item.label), 2)
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
        local cur_font = mp.get_property("sub-font") or "Source Sans Variable Roman"
        a(string.format("{\\pos(%d,%d)\\an7\\fnSource Sans Pro,Arial,sans-serif\\fs13\\1c&HFBBF24&\\b1}Press [ 1 ] - [ %d ] to apply font to subtitles (Forces override for ASS):{\\b0}",
            x0 + 40, content_y, #FONTS))
        content_y = content_y + 24

        for idx, item in ipairs(FONTS) do
            local is_cur = (cur_font:lower():find(item.font:lower()) ~= nil)
            local marker = is_cur and "  {\\1c&H38BDF8&\\b1}[✓ Current Font]{\\b0}" or ""
            local col = is_cur and "&H38BDF8&" or "&HE2E8F0&"

            a(string.format("{\\pos(%d,%d)\\an7\\fn%s,Arial\\fs14\\b1\\1c&H38BDF8&}[ %d ]{\\b0} {\\1c%s\\fs14}%s%s",
                item.font, x0 + 40, content_y, idx, col, ass_escape(item.name), marker))
            content_y = content_y + line_h - 2
        end

    elseif active_mode == 'size' then
        local cur_size = tonumber(mp.get_property("sub-font-size")) or 52
        local cur_scale = tonumber(mp.get_property("sub-scale")) or 1.0
        local percent = math.floor(cur_scale * 100 + 0.5)
        a(string.format("{\\pos(%d,%d)\\an7\\fnSource Sans Pro,Arial,sans-serif\\fs13\\1c&HFBBF24&\\b1}Press [ 1 ] - [ %d ] to choose size, or [ + ] / [ - ] / [ Up / Down ] to scale (Current: %d%% / %dpx):{\\b0}",
            x0 + 40, content_y, #SIZES, percent, cur_size))
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
            mp.set_property("sub-font", FONTS[num].font)
            mp.set_property("sub-ass-override", "force")
            mp.osd_message("Subtitle Font: " .. FONTS[num].name, 2)
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
    mp.set_property_number("sub-scale", 1.0)
    mp.set_property_number("sub-font-size", 52)
    mp.osd_message("Subtitle Size: Reset to 100% (52 px)", 2)
    if active_mode == 'size' then render_ui() end
end)
