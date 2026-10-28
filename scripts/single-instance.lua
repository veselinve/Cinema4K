-- single-instance.lua
-- Ensures only ONE instance of MPV runs.
-- Opening another file forwards it to the existing instance and focuses the window.

local mp = require 'mp'
local msg = require 'mp.msg'
local utils = require 'mp.utils'

local is_windows = package.config:sub(1,1) == "\\"
local ipc_path = is_windows and "\\\\.\\pipe\\mpvsocket" or ((os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/mpvsocket")

local my_pid = tonumber(mp.get_property("pid"))

-- Allow isolated secondary/testing instances if custom pipe specified
local custom_ipc = mp.get_property("input-ipc-server")
if custom_ipc and custom_ipc ~= "" and not custom_ipc:find("mpvsocket") then
    return
end

local function escape_json_str(str)
    if not str then return "" end
    return (str:gsub("\\", "\\\\"):gsub("\"", "\\\""))
end

local function get_remote_pid()
    local mode = is_windows and "r+" or "r"
    local f = io.open(ipc_path, mode)
    if not f then return nil end

    f:write('{"command": ["get_property", "pid"]}\n')
    f:flush()
    local resp = f:read('*l')
    f:close()

    if resp then
        local pid_str = resp:match('"data"%s*:%s*(%d+)')
        return tonumber(pid_str)
    end
    return nil
end

local function send_file_and_focus(filepath)
    local mode = is_windows and "r+" or "w"
    local f = io.open(ipc_path, mode)
    if not f then return false end

    if filepath and filepath ~= "" then
        local escaped = escape_json_str(filepath)
        f:write(string.format('{"command": ["loadfile", "%s", "replace"]}\n', escaped))
    end
    f:write('{"command": ["set_property", "window-minimized", false]}\n')
    f:write('{"command": ["focus"]}\n')
    f:flush()
    f:close()
    return true
end

local remote_pid = get_remote_pid()

if remote_pid and remote_pid ~= my_pid then
    msg.info(string.format("Existing MPV instance detected (PID %d). Acting as client.", remote_pid))

    local handled = false
    local function forward_and_exit()
        if handled then return end
        handled = true
        local filepath = mp.get_property("path")
        if filepath and filepath ~= "" then
            local full_path = mp.command_native({"expand-path", filepath}) or filepath
            send_file_and_focus(full_path)
            msg.info("Forwarded file to main MPV instance: " .. full_path)
        else
            send_file_and_focus(nil)
            msg.info("Focused main MPV instance.")
        end
        mp.commandv("quit")
    end

    mp.register_event("start-file", forward_and_exit)
    mp.add_timeout(0.15, forward_and_exit)
else
    msg.info(string.format("Master MPV instance started (PID %s).", tostring(my_pid)))
end
