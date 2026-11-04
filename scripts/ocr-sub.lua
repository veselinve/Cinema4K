-- MPV-Made-Easy - Real-time OCR display for bitmap subtitles
-- Old DVD/Blu-ray subtitles (dvd_subtitle / hdmv_pgs_subtitle / dvb_subtitle /
-- vobsub) are rendered IMAGES: their font cannot be changed directly. This
-- script activates automatically when such a track is selected, captures the
-- rendered subtitle band from the frame, recognizes the text with the
-- Windows built-in OCR engine (no external install; language packs for the
-- subtitle language must be present in Windows settings), and displays it as
-- clean text over the bitmap. Repeated lines are cached and shown instantly.

local mp = require 'mp'
local msg = require 'mp.msg'
local opt = require 'mp.options'

local o = {
    band = 24,          -- percent of frame height used as the subtitle band
    force = "no",       -- yes: OCR even text subtitle tracks (debugging)
}
opt.read_options(o)

local overlay = mp.create_osd_overlay("ass-events")

local function helper_candidates()
    local list = {}
    local dir = mp.find_config_file("script-opts")
    if dir and dir ~= "" then list[#list + 1] = dir .. "/ocr-helper.ps1" end
    local script_dir = mp.get_script_directory()
    if script_dir and script_dir ~= "" then
        list[#list + 1] = script_dir .. "/ocr-helper.ps1"
    end
    return list
end

local function find_helper()
    for _, cand in ipairs(helper_candidates()) do
        local fp = io.open(cand, "r")
        if fp then fp:close(); return cand end
    end
    return nil
end

local BITMAP_CODECS = {
    hdmv_pgs_subtitle = true,
    dvd_subtitle = true,
    dvb_subtitle = true,
    vobsub = true,
}

local LANG_MAP = {
    bg = "bg", en = "en-US", ja = "ja", jp = "ja", zh = "zh-Hans",
    ru = "ru", de = "de", fr = "fr", es = "es", it = "it", tr = "tr",
}

local state = {
    user_off = false,
    busy = false,
    seq = 0,
    last_hash = nil,
    cache = {},       -- hash -> text
    cache_order = {}, -- hash insertion order for eviction
}

local function active_sub_track()
    local sid = mp.get_property("sid")
    if not sid or sid == "no" or sid == "0" then return nil end
    for _, t in ipairs(mp.get_property_native("track-list") or {}) do
        if t.type == "sub" and tostring(t.id) == tostring(sid) then
            return t
        end
    end
    return nil
end

local function bitmap_active()
    if state.user_off or mp.get_property_bool("pause") then
        msg.info(("bitmap_active=false (user_off=%s pause=%s)"):format(tostring(state.user_off), tostring(mp.get_property("pause"))))
        return false
    end
    if o.force == "yes" then return active_sub_track() ~= nil end
    local t = active_sub_track()
    return t ~= nil and BITMAP_CODECS[t.codec or ""] == true
end

local function ocr_language(t)
    local lang = (t and t.lang or ""):lower()
    return LANG_MAP[lang] or lang
end

-- ---------------------------------------------------------------------------
-- Band capture: screenshot-raw returns RAW top-down BGR0 pixels
-- {data, stride, width, height, format}. Build a bottom-up 32bpp BMP of the
-- bottom band for the OCR helper.
-- ---------------------------------------------------------------------------
local function capture_band()
    local res = mp.command_native({ "screenshot-raw" })
    if type(res) ~= "table" or not res.data or not res.w or not res.h then
        msg.warn("ocr-capture: no frame data")
        return nil
    end
    if (res.format or "") ~= "bgr0" then
        msg.warn("ocr-capture: unexpected format " .. tostring(res.format))
        return nil
    end
    local data = res.data
    local w = res.w or res.width
    local h = res.h or res.height
    local stride = res.stride or (w * 4)
    if h <= 0 or w <= 0 or stride < w * 4 or #data < stride * h then
        msg.warn(("ocr-capture: bad dims w=%d h=%d stride=%s datalen=%d"):format(w, h, tostring(stride), #data))
        return nil
    end

    local band_rows = math.max(1, math.floor(h * o.band / 100))
    -- top-down pixel data: the bottom band is the LAST band_rows rows
    local band = data:sub(#data - stride * band_rows + 1)
    -- BMP (bottom-up) wants the bottom row first: reverse the band rows
    local rows = {}
    for i = band_rows, 1, -1 do
        rows[#rows + 1] = band:sub((i - 1) * stride + 1, (i - 1) * stride + w * 4)
    end
    local pixel = table.concat(rows)

    local filesize = 54 + #pixel
    local header = "BM"
        .. string.char(filesize % 256, math.floor(filesize / 256) % 256,
                       math.floor(filesize / 65536) % 256, math.floor(filesize / 16777216) % 256)
        .. "\0\0\0\0"
        .. "\54\0\0\0"
        .. "\40\0\0\0"
        .. string.char(w % 256, math.floor(w / 256) % 256, 0, 0)
        .. string.char(band_rows % 256, math.floor(band_rows / 256) % 256, 0, 0)
        .. "\1\0"
        .. "\32\0"
        .. "\0\0\0\0"
        .. string.char(#pixel % 256, math.floor(#pixel / 256) % 256, 0, 0)
        .. ("\0"):rep(16)
        .. ("\0"):rep(8)
    return header .. pixel
end

local function bmp_hash(bmp)
    local len = #bmp
    local h = 5381
    local step = math.max(1, math.floor(len / 2048))
    for i = 55, len, step do
        h = (h * 33 + bmp:byte(i)) % 4294967296
    end
    return string.format("%d:%d", h, len)
end

local function cache_put(hash, text)
    if state.cache[hash] == nil then
        state.cache_order[#state.cache_order + 1] = hash
        if #state.cache_order > 600 then
            local old = table.remove(state.cache_order, 1)
            state.cache[old] = nil
        end
    end
    state.cache[hash] = text
end

local function ass_escape(str)
    return tostring(str):gsub('\\', '\\\\'):gsub('{', '\\{'):gsub('}', '\\}')
end

local function show_text(text)
    local w, h = mp.get_osd_size()
    if not w or w <= 0 then w, h = 1280, 720 end
    local band_px = math.floor(h * o.band / 100)
    local fs = math.max(18, math.floor(band_px * 0.42))
    local font = mp.get_property("sub-font") or "Segoe UI"
    local parts = {
        string.format("{\\pos(0,%d)\\an7\\bord0\\shad0\\1c&H000000&\\1a&H70&\\p1}m 0 0 l %d 0 l %d %d l 0 %d{\\p0}",
            h - band_px, w, w, band_px, band_px),
        string.format("{\\pos(%d,%d)\\an2\\fn%s\\fs%d\\b1\\1c&HFFFFFF&\\3c&H000000&\\bord2}%s",
            math.floor(w / 2), h - math.floor(band_px * 0.3), font, fs, ass_escape(text)),
    }
    overlay.data = table.concat(parts, "\n")
    overlay:update()
end

local function clear_overlay()
    overlay.data = ""
    overlay:update()
end

-- ---------------------------------------------------------------------------
local function run_ocr(bmp, lang)
    local hash = bmp_hash(bmp)
    state.last_hash = hash
    local cached = state.cache[hash]
    if cached then
        show_text(cached)
        return
    end

    state.seq = state.seq + 1
    local tmp = os.getenv("TEMP") .. "\\ocr_sub_" .. tostring(state.seq) .. ".bmp"
    local fp = io.open(tmp, "wb")
    if not fp then return end
    fp:write(bmp)
    fp:close()

    local helper = find_helper()
    if not helper then
        msg.warn("ocr-helper.ps1 not found (script-opts or scripts folder)")
        return
    end

    mp.command_native_async({
        name = "subprocess",
        args = {
            "powershell", "-NoProfile", "-STA", "-ExecutionPolicy", "Bypass",
            "-File", helper, "-Image", tmp, "-Lang", lang,
        },
        playback_only = false,
        capture_stdout = true,
    }, function(success, result)
        os.remove(tmp)
        local text = ""
        if result and result.stdout then
            text = result.stdout:match("OCR_TEXT:(.*)") or ""
            text = text:gsub("\r", ""):gsub("%s+$", "")
        end
        if text == "" then
            if state.last_hash == hash then
                clear_overlay()
            end
            return
        end
        cache_put(hash, text)
        msg.info(("OCR [%s]: %s"):format(lang, text))
        if state.last_hash == hash then
            show_text(text)
        end
    end)
end

local function ocr_current()
    if not bitmap_active() then return end
    if state.busy then return end
    local t = active_sub_track()
    local lang = ocr_language(t)
    local bmp = capture_band()
    if not bmp then return end
    state.busy = true
    run_ocr(bmp, lang)
    state.busy = false
end

local function schedule_ocr(delay)
    mp.add_timeout(math.max(0.02, delay / 1000), ocr_current)
end

local function toggle()
    state.user_off = not state.user_off
    if state.user_off then
        clear_overlay()
        mp.osd_message("Bitmap Subtitle OCR: OFF", 2)
    else
        mp.osd_message("Bitmap Subtitle OCR: AUTO", 2)
        schedule_ocr(60)
    end
end

mp.register_script_message("toggle", toggle)
mp.register_script_message("ocr-now", function() ocr_current() end)

local poll_timer = nil
local function set_poll(on)
    if poll_timer then
        poll_timer:kill()
        poll_timer = nil
    end
    if on then
        poll_timer = mp.add_periodic_timer(0.15, function()
            if bitmap_active() then ocr_current() end
        end)
    end
end

-- auto-activation: poll only while a bitmap subtitle track is active
local function update_poll()
    set_poll(bitmap_active() and not state.user_off)
    if not (bitmap_active() and not state.user_off) then
        clear_overlay()
    end
end

-- immediate refresh when the displayed subtitle line changes (bitmap tracks
-- push new lines at distinct timestamps); the poll is the fallback
mp.observe_property("sub-start", "native", function(_, val)
    if bitmap_active() and val then
        clear_overlay()
        ocr_current()
    end
end)
mp.observe_property("sub-end", "native", function(_, val)
    if val and bitmap_active() then clear_overlay() end
end)

mp.observe_property("track-list", "native", update_poll)
mp.observe_property("sid", "native", update_poll)
mp.observe_property("sub-visibility", "native", update_poll)
mp.observe_property("pause", "native", update_poll)
mp.register_event("shutdown", function()
    set_poll(false)
    clear_overlay()
end)

update_poll()
msg.info("Bitmap subtitle OCR ready (Windows OCR engine)")

msg.info("Bitmap subtitle OCR ready (Windows OCR engine)")
