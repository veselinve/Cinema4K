-- save-position.lua
-- Automatically saves and resumes playback position reliably.
-- Saves on pause, periodically every 20 seconds, and on file switch/quit.

local mp = require 'mp'
local last_save_time = 0

local function format_time(seconds)
    if not seconds or seconds < 0 then return "00:00" end
    local s = math.floor(seconds)
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local sec = s % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, sec)
    else
        return string.format("%02d:%02d", m, sec)
    end
end

local function save_position()
    local path = mp.get_property("path")
    if not path or path == "" then return end

    local time_pos = mp.get_property_number("time-pos")
    local duration = mp.get_property_number("duration")

    -- Don't save if within first 2 seconds or within last 5 seconds of the video
    if time_pos and time_pos > 2 then
        if not duration or (duration - time_pos > 5) then
            pcall(function() mp.command("write-watch-later-config") end)
            last_save_time = time_pos
        end
    end
end

-- Save when paused
mp.observe_property("pause", "bool", function(name, paused)
    if paused then
        save_position()
    end
end)

-- Save periodically every 20 seconds during active playback
mp.observe_property("time-pos", "number", function(name, time_pos)
    if time_pos and math.abs(time_pos - last_save_time) >= 20 then
        save_position()
    end
end)

-- Save before closing or switching file
mp.register_event("end-file", function(event)
    -- If file ended because of EOF, let mpv clean it up; otherwise save position
    if event and event.reason ~= "eof" then
        save_position()
    end
end)

-- Notify user when resumed from a saved position
local announced_resume = false
mp.register_event("file-loaded", function()
    announced_resume = false
    mp.add_timeout(0.3, function()
        local time_pos = mp.get_property_number("time-pos")
        if time_pos and time_pos > 5 and not announced_resume then
            announced_resume = true
            mp.osd_message(string.format("Resumed from %s", format_time(time_pos)), 2.5)
        end
    end)
end)
