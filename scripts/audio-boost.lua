-- MPV-Made-Easy - Audio Normalization, Boost & Dialogue Clarity Filter
-- Zero-latency, zero-buffering speech enhancement & volume boost
-- Remembers selected mode persistently across sessions without causing stutter or lag

local mp = require 'mp'
local utils = require 'mp.utils'
local msg = require 'mp.msg'

local MODES = {
    {
        id = "off",
        name = "Audio Boost OFF (Original Sound - Pure Playback)",
        short = "Audio Boost: OFF",
        desc_bg = "Оригинален звук без никакви филтри (Максимална производителност)",
        af = ""
    },
    {
        id = "dialogue",
        name = "Dialogue Clarity (Speech Boost / Reduced Background Noise)",
        short = "Dialogue Clarity",
        desc_bg = "Увеличава силата и яснотата на говора (1.8 kHz) и филтрира ниския шум",
        af = "lavfi=[highpass=f=90,equalizer=f=1800:width_type=o:width=1.5:g=6.0,equalizer=f=3000:width_type=o:width=1.2:g=3.0]"
    },
    {
        id = "mpc",
        name = "MPC-HC Normalizer & Boost (Voice Normalizer)",
        short = "MPC-HC Normalizer",
        desc_bg = "Нормализатор в стил K-Lite / MPC-HC: изравнява тихите и силни звуци",
        af = "lavfi=[acompressor=threshold=-18dB:ratio=3:attack=10:release=120:makeup=6dB]"
    },
    {
        id = "high",
        name = "High Voice & Volume Boost (Maximum Speech Clarity)",
        short = "High Speech Boost",
        desc_bg = "Максимално усилен говор за много тихи диалози и шепот (+8.5 dB)",
        af = "lavfi=[highpass=f=100,equalizer=f=1800:width_type=o:width=1.5:g=8.5,equalizer=f=3200:width_type=o:width=1.2:g=4.5]"
    },
    {
        id = "night",
        name = "Night Mode (Compress Loud Effects, Raise Whispering)",
        short = "Night Mode (DRC)",
        desc_bg = "Нощен режим: компресира силните гърмежи и повдига тихия говор",
        af = "lavfi=[acompressor=threshold=-24dB:ratio=4:attack=10:release=150:makeup=6dB]"
    }
}

local current_mode_id = "off"

local function get_mode_by_id(id)
    for _, m in ipairs(MODES) do
        if m.id == id then return m end
    end
    return MODES[1] -- default off
end

local function get_config_paths()
    local paths = {}
    local p1 = mp.command_native({"expand-path", "~~/script-opts/audio_boost.conf"})
    if p1 then paths[#paths + 1] = p1 end
    local roaming = os.getenv("APPDATA")
    if roaming then
        paths[#paths + 1] = roaming:gsub("\\", "/") .. "/mpv/script-opts/audio_boost.conf"
    end
    local exe_dir = mp.command_native({"expand-path", "~~exe_dir/script-opts/audio_boost.conf"})
    if exe_dir and exe_dir ~= p1 then paths[#paths + 1] = exe_dir end
    return paths
end

local function load_saved_mode()
    local paths = get_config_paths()
    for _, path in ipairs(paths) do
        local f = io.open(path, "r")
        if f then
            for line in f:lines() do
                local val = line:match("^%s*mode%s*=%s*([%w_%-]+)")
                if val then
                    f:close()
                    for _, m in ipairs(MODES) do
                        if m.id == val then return val end
                    end
                end
            end
            f:close()
        end
    end
    return "off"
end

local function save_mode_to_disk(mode_id)
    local paths = get_config_paths()
    local done = {}
    for _, path in ipairs(paths) do
        if not done[path] then
            done[path] = true
            local f = io.open(path, "w")
            if f then
                f:write("# MPV-Made-Easy - Audio Boost Persistent Configuration\n")
                f:write("# Modes: off, dialogue, mpc, high, night\n")
                f:write(string.format("mode=%s\n", mode_id))
                f:close()
            end
        end
    end
end

local function has_audio_boost_filter()
    local af_list = mp.get_property_native("af")
    if not af_list then return false end
    for _, f in ipairs(af_list) do
        if f.label == "audio_boost" then return true end
    end
    return false
end

local function apply_filter(mode)
    if has_audio_boost_filter() then
        pcall(function() mp.commandv("af", "remove", "@audio_boost") end)
    end
    if mode.af and mode.af ~= "" then
        pcall(function() mp.commandv("af", "add", "@audio_boost:" .. mode.af) end)
    end
end

local function set_mode(mode_id, show_osd, save)
    local target = get_mode_by_id(mode_id)
    current_mode_id = target.id
    mp.set_property_native("user-data/audio-boost-mode", target.id)
    apply_filter(target)

    if save then
        save_mode_to_disk(target.id)
    end

    if show_osd then
        if target.id == "off" then
            mp.osd_message(string.format("Audio Boost: OFF (Original Sound)\n%s", target.desc_bg), 2.5)
        else
            mp.osd_message(string.format("Audio Boost: %s [SAVED]\n%s", target.short, target.desc_bg), 3.0)
        end
    end
end

local function cycle_mode()
    local cur_idx = 1
    for i, m in ipairs(MODES) do
        if m.id == current_mode_id then
            cur_idx = i
            break
        end
    end
    local next_idx = (cur_idx % #MODES) + 1
    set_mode(MODES[next_idx].id, true, true)
end

-- Load saved mode on startup
current_mode_id = load_saved_mode()
mp.set_property_native("user-data/audio-boost-mode", current_mode_id)

-- Re-apply on file load ONLY if active mode is not off
mp.register_event("file-loaded", function()
    local target = get_mode_by_id(current_mode_id)
    if target.id ~= "off" and target.af ~= "" then
        apply_filter(target)
    end
    mp.set_property_native("user-data/audio-boost-mode", target.id)
end)

-- Script bindings and messages
mp.add_key_binding("n", "cycle-audio-boost", cycle_mode)
mp.add_key_binding("N", "cycle-audio-boost-N", cycle_mode)
mp.add_key_binding("Ctrl+b", "cycle-audio-boost-b", cycle_mode)

mp.register_script_message("set-audio-boost", function(mode_id)
    set_mode(mode_id, true, true)
end)

mp.register_script_message("cycle", cycle_mode)
mp.register_script_message("toggle", cycle_mode)
