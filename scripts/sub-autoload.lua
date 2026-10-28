-- MPV-Made-Easy - Universal MPC-HC Style Subtitle Autoloader
-- Full multi-language recognition for 60+ world languages and dialects,
-- recursive deep directory scanning, episode/part fuzzy matching,
-- uchardet auto-encoding (CP1251, UTF-8, etc.), and dynamic hot-reloading on window focus.

local mp = require 'mp'
local utils = require 'mp.utils'
local msg = require 'mp.msg'

local SUB_EXTS = {
    srt = true, ass = true, ssa = true, sub = true,
    vtt = true, idx = true, sup = true, smi = true, lrc = true
}

local VID_EXTS = {
    mp4 = true, mkv = true, avi = true, webm = true,
    mov = true, m4v = true, wmv = true, flv = true,
    ts = true, m2ts = true, vob = true, ogv = true, ["3gp"] = true
}

-- Comprehensive Universal Language Database (60+ languages & dialects)
local LANG_DATABASE = {
    { "bg", "Bulgarian",   { "bul", "bulgarian", "български", "Български", "БЪЛГАРСКИ", "бг", "БГ" } },
    { "en", "English",     { "eng", "english", "en-us", "en-gb", "en-ca", "en-au" } },
    { "es", "Spanish",     { "spa", "spanish", "español", "Español", "ESPAÑOL", "espanol", "castellano", "Castellano", "latino", "lat", "es-es", "es-419", "es-mx" } },
    { "fr", "French",      { "fra", "fre", "french", "français", "Français", "FRANÇAIS", "francais", "fr-ca", "fr-fr" } },
    { "de", "German",      { "deu", "ger", "german", "deutsch", "Deutsch", "DEUTSCH", "de-de", "de-at", "de-ch" } },
    { "it", "Italian",     { "ita", "italian", "italiano", "Italiano", "ITALIANO", "it-it" } },
    { "pt", "Portuguese",  { "por", "portuguese", "português", "Português", "PORTUGUÊS", "portugues", "pob", "pt-br", "pt-pt", "brazilian" } },
    { "ru", "Russian",     { "rus", "russian", "русский", "Русский", "РУССКИЙ", "ру", "РУ", "ru-ru" } },
    { "uk", "Ukrainian",   { "ukr", "ukrainian", "українська", "Українська", "УКРАЇНСЬКА", "укр", "УКР" } },
    { "ja", "Japanese",    { "jpn", "jp", "japanese", "日本語", "nihongo", "ja-jp" } },
    { "zh", "Chinese",     { "zho", "chi", "chinese", "中文", "mandarin", "cantonese", "chs", "cht", "hans", "hant", "zh-cn", "zh-tw", "zh-hans", "zh-hant" } },
    { "ko", "Korean",      { "kor", "korean", "한국어", "조선말", "ko-kr" } },
    { "ar", "Arabic",      { "ara", "arabic", "العربية", "عربي", "ar-sa", "ar-eg" } },
    { "hi", "Hindi",       { "hin", "hindi", "हिन्दी", "hi-in" } },
    { "tr", "Turkish",     { "tur", "turkish", "türkçe", "Türkçe", "TÜRKÇE", "turkce", "tr-tr" } },
    { "pl", "Polish",      { "pol", "polish", "polski", "Polski", "POLSKI", "pl-pl" } },
    { "ro", "Romanian",    { "ron", "rum", "romanian", "română", "Română", "ROMÂNĂ", "romana", "ro-ro" } },
    { "nl", "Dutch",       { "nld", "dut", "dutch", "nederlands", "Nederlands", "flemish", "vlaams", "nl-nl", "nl-be" } },
    { "el", "Greek",       { "ell", "gre", "greek", "ελληνικά", "Ελληνικά", "ΕΛΛΗНИКА", "el-gr" } },
    { "sv", "Swedish",     { "swe", "swedish", "svenska", "Svenska", "sv-se" } },
    { "no", "Norwegian",   { "nor", "nob", "nno", "norwegian", "norsk", "Norsk", "bokmål", "nynorsk", "nb", "nn", "no-no" } },
    { "da", "Danish",      { "dan", "danish", "dansk", "Dansk", "da-dk" } },
    { "fi", "Finnish",     { "fin", "finnish", "suomi", "Suomi", "fi-fi" } },
    { "cs", "Czech",       { "ces", "cze", "czech", "čeština", "Čeština", "ČEŠTINA", "cestina", "cs-cz" } },
    { "sk", "Slovak",      { "slk", "slo", "slovak", "slovenčina", "Slovenčina", "SLOVENČINA", "slovencina", "sk-sk" } },
    { "hu", "Hungarian",   { "hun", "hungarian", "magyar", "Magyar", "hu-hu" } },
    { "sr", "Serbian",     { "srp", "scc", "serbian", "српски", "Српски", "СРПСКИ", "srpski", "sr-rs" } },
    { "hr", "Croatian",    { "hrv", "scr", "croatian", "hrvatski", "Hrvatski", "HRVATSKI", "hr-hr" } },
    { "bs", "Bosnian",     { "bos", "bosnian", "bosanski", "Bosanski", "bs-ba" } },
    { "sl", "Slovenian",   { "slv", "slovenian", "slovenščina", "Slovenščina", "slovenscina", "sl-si" } },
    { "mk", "Macedonian",  { "mkd", "mac", "macedonian", "македонски", "Македонски", "МАКЕДОНСКИ", "mk-mk" } },
    { "sq", "Albanian",    { "sqi", "alb", "albanian", "shqip", "Shqip", "sq-al" } },
    { "he", "Hebrew",      { "heb", "hebrew", "עברית", "ivrit", "he-il" } },
    { "fa", "Persian",     { "fas", "per", "persian", "farsi", "فارسی", "fa-ir" } },
    { "id", "Indonesian",  { "ind", "indonesian", "bahasa indonesia", "id-id" } },
    { "ms", "Malay",       { "msa", "may", "malay", "bahasa melayu", "ms-my" } },
    { "th", "Thai",        { "tha", "thai", "ไทย", "th-th" } },
    { "vi", "Vietnamese",  { "vie", "vietnamese", "tiếng việt", "Tiếng Việt", "tieng viet", "vi-vn" } },
    { "tl", "Filipino",    { "tgl", "fil", "filipino", "tagalog", "Tagalog", "tl-ph" } },
    { "bn", "Bengali",     { "ben", "bengali", "বাংলা", "bn-bd", "bn-in" } },
    { "ta", "Tamil",       { "tam", "tamil", "தமிழ்", "ta-in" } },
    { "te", "Telugu",      { "tel", "telugu", "తెలుగు", "te-in" } },
    { "mr", "Marathi",     { "mar", "marathi", "मराठी", "mr-in" } },
    { "ur", "Urdu",        { "urd", "urdu", "اردو", "ur-pk" } },
    { "ca", "Catalan",     { "cat", "catalan", "català", "Català", "catala", "ca-es" } },
    { "eu", "Basque",      { "eus", "baq", "basque", "euskara", "Euskara", "eu-es" } },
    { "gl", "Galician",    { "glg", "galician", "galego", "Galego", "gl-es" } },
    { "is", "Icelandic",   { "isl", "ice", "icelandic", "íslenska", "Íslenska", "islenska", "is-is" } },
    { "ga", "Irish",       { "gle", "irish", "gaeilge", "Gaeilge", "ga-ie" } },
    { "et", "Estonian",    { "est", "estonian", "eesti", "Eesti", "et-ee" } },
    { "lv", "Latvian",     { "lav", "latvian", "latviešu", "Latviešu", "latviesu", "lv-lv" } },
    { "lt", "Lithuanian",  { "lit", "lithuanian", "lietuvių", "Lietuvių", "lietuviu", "lt-lt" } },
    { "ka", "Georgian",    { "kat", "geo", "georgian", "ქართული", "ka-ge" } },
    { "hy", "Armenian",    { "hye", "arm", "armenian", "հայերեն", "hy-am" } },
    { "az", "Azerbaijani", { "aze", "azerbaijani", "azərbaycan", "Azərbaycan", "azerbaycan", "az-az" } },
    { "kk", "Kazakh",      { "kaz", "kazakh", "қазақша", "Қазақша", "kk-kz" } },
    { "uz", "Uzbek",       { "uzb", "uzbek", "oʻzbek", "Oʻzbek", "ozbek", "uz-uz" } },
    { "mn", "Mongolian",   { "mon", "mongolian", "монгол", "Монгол", "mn-mn" } },
    { "af", "Afrikaans",   { "afr", "afrikaans", "af-za" } },
    { "be", "Belarusian",  { "bel", "belarusian", "беларуская", "Беларуская", "be-by" } },
    { "la", "Latin",       { "lat", "latin", "latina" } },
    { "eo", "Esperanto",   { "epo", "esperanto" } }
}

-- Fast lookup hash map: alias/code -> { code, name }
local ALIAS_TO_INFO = {}
for _, item in ipairs(LANG_DATABASE) do
    local code, name, aliases = item[1], item[2], item[3]
    local info = { code = code, name = name }
    ALIAS_TO_INFO[code:lower()] = info
    ALIAS_TO_INFO[name:lower()] = info
    for _, a in ipairs(aliases) do
        ALIAS_TO_INFO[a] = info
        ALIAS_TO_INFO[a:lower()] = info
    end
end

local function get_ext(fn)
    return fn:match("%.([^%.]+)$")
end

local function is_sub(fn)
    local ext = get_ext(fn)
    return ext and SUB_EXTS[ext:lower()] == true
end

local function is_vid(fn)
    local ext = get_ext(fn)
    return ext and VID_EXTS[ext:lower()] == true
end

local function normalize_path(p)
    return p:gsub("\\", "/"):lower()
end

-- Detect language universally across all languages
local function detect_language(rel_dir, fn)
    local rel_norm = (rel_dir or ""):gsub("\\", "/"):lower()
    local fn_norm  = fn:lower()

    -- 1. Check directory path first (e.g. Subs/French, Subs/2_Spanish, Subs/de, Subs/pt-BR)
    if rel_norm ~= "" then
        for part in rel_norm:gmatch("[^/]+") do
            local p = part:gsub("^%s+", ""):gsub("%s+$", "")
            if p ~= "subs" and p ~= "sub" and p ~= "subtitles" and p ~= "metadata" and p ~= "sub-files" then
                -- Strip leading numbers (e.g. "2_Spanish" -> "spanish", "01. French" -> "french")
                local stripped = p:gsub("^%d+[%s_%-%.]*", ""):gsub("^%s+", ""):gsub("%s+$", "")
                if ALIAS_TO_INFO[stripped] then
                    return ALIAS_TO_INFO[stripped].code, ALIAS_TO_INFO[stripped].name
                end
                for word in stripped:gmatch("[^%s%._%-%,%[%]%(/%\\]+") do
                    if #word >= 2 and ALIAS_TO_INFO[word] then
                        return ALIAS_TO_INFO[word].code, ALIAS_TO_INFO[word].name
                    end
                end
            end
        end
    end

    -- 2. Check filename extension-adjacent language code (.eng.srt, .spa.srt, .por-BR.srt)
    local ext_code = fn_norm:match("[._ %-]([a-z0-9%-]+)%.[^%.]+$")
    if ext_code and ALIAS_TO_INFO[ext_code] then
        return ALIAS_TO_INFO[ext_code].code, ALIAS_TO_INFO[ext_code].name
    end

    -- 3. Check bracketed language tokens [eng], (spa), [pt-br], [bg], [ru]
    for b in fn_norm:gmatch("%b[]") do
        local inside = b:sub(2, -2):lower():gsub("^%s+", ""):gsub("%s+$", "")
        if ALIAS_TO_INFO[inside] then
            return ALIAS_TO_INFO[inside].code, ALIAS_TO_INFO[inside].name
        end
    end
    for b in fn_norm:gmatch("%b()") do
        local inside = b:sub(2, -2):lower():gsub("^%s+", ""):gsub("%s+$", "")
        if ALIAS_TO_INFO[inside] then
            return ALIAS_TO_INFO[inside].code, ALIAS_TO_INFO[inside].name
        end
    end

    -- 4. Check all distinct words in filename against all languages
    for word in fn_norm:gmatch("[^%s%._%-%,%[%]%(/%\\]+") do
        if #word >= 2 and ALIAS_TO_INFO[word] then
            return ALIAS_TO_INFO[word].code, ALIAS_TO_INFO[word].name
        end
    end

    return nil, nil
end

-- Detect descriptors like [Forced], [SDH], [CC], [Commentary]
local function detect_flags(fn)
    local s = fn:lower()
    if s:find("forced") then
        return "[Forced]"
    elseif s:find("sdh") or s:find("%bcc%b") or s:find("hearing[._ %-]impaired") or s:find("%[hi%]") then
        return "[SDH]"
    elseif s:find("commentary") or s:find("%bcomm%b") then
        return "[Commentary]"
    elseif s:find("signs") or s:find("songs") then
        return "[Signs]"
    end
    return nil
end

-- Extract episode information (season, start_ep, end_ep)
local function extract_episode(fn)
    local s = fn:lower()
    -- Multi-episode: S01E01-E02, S01E01-02, S01E01_E02
    local s_num, ep1, ep2 = s:match("[sS](%d+)[eE](%d+)[%-%_~]+[eE]?(%d+)")
    if ep1 and ep2 then
        return { season = tonumber(s_num), start_ep = tonumber(ep1), end_ep = tonumber(ep2), is_multi = true }
    end
    -- S01E01E02
    local s_num, ep1, ep2 = s:match("[sS](%d+)[eE](%d+)[eE](%d+)")
    if ep1 and ep2 then
        return { season = tonumber(s_num), start_ep = tonumber(ep1), end_ep = tonumber(ep2), is_multi = true }
    end
    -- S01E04
    local s_num, ep = s:match("[sS](%d+)[eE](%d+)")
    if ep then
        return { season = tonumber(s_num), start_ep = tonumber(ep), end_ep = tonumber(ep), is_multi = false }
    end
    -- 1x04
    local s_num, ep = s:match("(%d+)x(%d+)")
    if ep then
        return { season = tonumber(s_num), start_ep = tonumber(ep), end_ep = tonumber(ep), is_multi = false }
    end
    -- EP04, EP.04, Episode 4
    local ep = s:match("ep%.?%s*(%d+)") or s:match("episode%.?%s*(%d+)")
    if ep then
        return { start_ep = tonumber(ep), end_ep = tonumber(ep), is_multi = false }
    end
    -- E04 (e.g. "Show.E04.mkv" or "Show - E04")
    local ep = s:match("[%s_%-%.]e(%d+)[%s_%-%.]") or s:match("^e(%d+)[%s_%-%.]")
    if ep then
        return { start_ep = tonumber(ep), end_ep = tonumber(ep), is_multi = false }
    end
    -- Anime brackets [04] or (04)
    local ep = s:match("%[(%d%d?)%]") or s:match("%((%d%d?)%)")
    if ep then
        return { start_ep = tonumber(ep), end_ep = tonumber(ep), is_multi = false }
    end
    -- Standalone number surrounded by delimiters: " - 04 ", " .04. ", " _ 04 _ "
    local ep = s:match("[%s_%-%.](%d%d?)[%s_%-%.]")
    if ep then
        return { start_ep = tonumber(ep), end_ep = tonumber(ep), is_multi = false }
    end
    return nil
end

-- Extract part information (CD1, CD2, Part 1, Part 2)
local function extract_part(fn)
    local s = fn:lower()
    local pt = s:match("cd[%s_%-%.]*(%d+)") or
               s:match("part[%s_%-%.]*(%d+)") or
               s:match("pt[%s_%-%.]*(%d+)")
    if pt then return tonumber(pt) end
    return nil
end

-- Clean string into words for title overlap matching
local function get_words(str)
    local words = {}
    local s = str:lower()
    s = s:gsub("%b[]", " ")
    s = s:gsub("%b()", " ")
    s = s:gsub("[._%-]", " ")
    s = s:gsub("1080p", " "):gsub("720p", " "):gsub("2160p", " "):gsub("4k", " ")
    s = s:gsub("webrip", " "):gsub("web%-dl", " "):gsub("bluray", " "):gsub("amzn", " ")
    s = s:gsub("x264", " "):gsub("x265", " "):gsub("h264", " "):gsub("hevc", " "):gsub("av1", " ")
    s = s:gsub("aac%d*", " "):gsub("ac3%d*", " "):gsub("eac3%d*", " "):gsub("dts", " ")
    for w in s:gmatch("%w+") do
        if #w >= 3 then words[w] = true end
    end
    return words
end

local function calculate_overlap(words1, words2)
    local total = 0
    local match = 0
    for w, _ in pairs(words1) do
        total = total + 1
        if words2[w] then match = match + 1 end
    end
    if total == 0 then return 0 end
    return match / total
end

-- Dynamically discover all directories and subdirectories up to depth 3
local function discover_all_subdirs(base_dir)
    local dirs_map = { [""] = true }
    local dir_list = { "" }

    local function add_dir(rel_p)
        if not dirs_map[rel_p] then
            dirs_map[rel_p] = true
            dir_list[#dir_list + 1] = rel_p
        end
    end

    -- Pre-add standard folders
    local standard_folders = { "subs", "Subs", "subtitles", "Subtitles", "sub", "Sub", "sub-files", "metadata" }
    for _, sf in ipairs(standard_folders) do add_dir(sf) end

    -- Scan top-level directories in base_dir
    local top_dirs = utils.readdir(base_dir, "dirs") or {}
    for _, td in ipairs(top_dirs) do
        add_dir(td)

        -- Depth 2
        local full_td = (base_dir .. "/" .. td):gsub("\\", "/")
        local second_dirs = utils.readdir(full_td, "dirs") or {}
        for _, sd in ipairs(second_dirs) do
            local rel2 = td .. "/" .. sd
            add_dir(rel2)

            -- Depth 3
            local full_sd = full_td .. "/" .. sd
            local third_dirs = utils.readdir(full_sd, "dirs") or {}
            for _, thr_d in ipairs(third_dirs) do
                add_dir(rel2 .. "/" .. thr_d)
            end
        end
    end

    return dir_list
end

-- Core scan and load routine
local function scan_and_load_subtitles(is_manual, is_focus_event)
    local path = mp.get_property("path")
    if not path or path == "" or path:find("^%a+://") then return end

    local dir, vid_file = utils.split_path(path)
    if not dir or dir == "" then dir = "." end
    dir = dir:gsub("[/\\]$", "")

    local vid_base = vid_file:match("^(.*)%.[^%.]+$") or vid_file
    local vid_ep   = extract_episode(vid_file)
    local vid_part = extract_part(vid_file)
    local vid_words = get_words(vid_base)

    -- Collect already loaded subtitle paths
    local loaded_paths = {}
    local track_list = mp.get_property_native("track-list") or {}
    for _, t in ipairs(track_list) do
        if t.type == "sub" and t["external-filename"] then
            loaded_paths[normalize_path(t["external-filename"])] = true
        end
    end

    -- Determine if folder contains a single video or multiple videos
    local root_files = utils.readdir(dir, "files") or {}
    local vid_count = 0
    for _, f in ipairs(root_files) do
        if is_vid(f) then
            vid_count = vid_count + 1
        end
    end
    local is_single_video = (vid_count <= 1)

    -- Discover all candidate directories
    local search_dirs = discover_all_subdirs(dir)

    -- Collect subtitle candidates from all directories
    local candidates = {}
    local seen_files = {}

    for _, sub_dir_rel in ipairs(search_dirs) do
        local check_dir = (sub_dir_rel == "") and dir or (dir .. "/" .. sub_dir_rel)
        local files = utils.readdir(check_dir, "files")
        if files then
            for _, fn in ipairs(files) do
                if is_sub(fn) then
                    local full_sub_path = (check_dir .. "/" .. fn):gsub("\\", "/")
                    local norm = normalize_path(full_sub_path)
                    if not seen_files[norm] and not loaded_paths[norm] then
                        seen_files[norm] = true
                        candidates[#candidates + 1] = {
                            filename = fn,
                            full_path = full_sub_path,
                            rel_dir = sub_dir_rel
                        }
                    end
                end
            end
        end
    end

    -- Filter and match candidates
    local to_load = {}
    for _, c in ipairs(candidates) do
        local matched = false
        local sub_base = c.filename:match("^(.*)%.[^%.]+$") or c.filename
        local sub_ep   = extract_episode(c.filename)
        local sub_part = extract_part(c.filename)

        local part_mismatch = (vid_part ~= nil and sub_part ~= nil and vid_part ~= sub_part)

        if not part_mismatch then
            if is_single_video then
                -- Single video folder: load all candidate subtitles (MPC-HC style)
                matched = true
            elseif vid_ep ~= nil then
                -- TV Series episode matching
                if sub_ep ~= nil then
                    local season_match = true
                    if vid_ep.season and sub_ep.season and vid_ep.season ~= sub_ep.season then
                        season_match = false
                    end
                    if season_match and (vid_ep.start_ep >= sub_ep.start_ep and vid_ep.start_ep <= sub_ep.end_ep) then
                        matched = true
                    end
                else
                    local sub_words = get_words(sub_base)
                    local overlap = calculate_overlap(sub_words, vid_words)
                    if overlap >= 0.65 then matched = true end
                end
            else
                -- Multiple videos without episode numbers (e.g. multi-movie collection)
                if sub_base:lower():find(vid_base:lower(), 1, true) or vid_base:lower():find(sub_base:lower(), 1, true) then
                    matched = true
                else
                    local sub_words = get_words(sub_base)
                    local overlap = calculate_overlap(sub_words, vid_words)
                    if overlap >= 0.60 then matched = true end
                end
            end
        end

        if matched then
            to_load[#to_load + 1] = c
            loaded_paths[normalize_path(c.full_path)] = true
        end
    end

    if #to_load == 0 then
        if is_manual then
            mp.osd_message("No new external subtitles found in folder", 2.5)
        end
        return
    end

    -- Load matched subtitles with metadata
    local loaded_names = {}
    local bg_sub_loaded = false

    for _, item in ipairs(to_load) do
        local lang_code, lang_name = detect_language(item.rel_dir, item.filename)
        local flags = detect_flags(item.filename)
        local base_title = item.filename:match("^(.*)%.[^%.]+$") or item.filename

        local display_title = ""
        if lang_name then
            display_title = lang_name .. (flags and (" " .. flags) or "")
            if item.rel_dir ~= "" then
                display_title = display_title .. " (" .. item.rel_dir .. "/" .. item.filename .. ")"
            else
                display_title = display_title .. " (" .. item.filename .. ")"
            end
            if lang_code == "bg" then bg_sub_loaded = true end
        else
            if item.rel_dir ~= "" then
                display_title = item.rel_dir .. "/" .. item.filename
            else
                display_title = item.filename
            end
        end

        msg.info(string.format("Auto-loading subtitle: %s [%s: %s]", item.full_path, lang_code or "und", lang_name or "Unknown"))
        if lang_code then
            mp.commandv("sub-add", item.full_path, "auto", display_title, lang_code)
        else
            mp.commandv("sub-add", item.full_path, "auto", display_title)
        end

        loaded_names[#loaded_names + 1] = lang_name or item.filename
    end

    -- Bulgarian subtitle priority selection: if Bulgarian was loaded and current track is not Bulgarian, select it!
    if bg_sub_loaded then
        mp.add_timeout(0.25, function()
            local cur_sid = mp.get_property("sid")
            local tracks = mp.get_property_native("track-list") or {}
            local current_is_bg = false
            if cur_sid and cur_sid ~= "no" and cur_sid ~= "0" then
                for _, t in ipairs(tracks) do
                    if t.type == "sub" and tostring(t.id) == tostring(cur_sid) then
                        if t.lang == "bg" or t.lang == "bul" then
                            current_is_bg = true
                        end
                        break
                    end
                end
            end

            if not current_is_bg then
                for _, t in ipairs(tracks) do
                    if t.type == "sub" and (t.lang == "bg" or t.lang == "bul" or (t.title and t.title:lower():find("bulgarian"))) then
                        mp.set_property("sid", tostring(t.id))
                        msg.info("Auto-selected Bulgarian subtitle track: " .. tostring(t.id))
                        mp.osd_message(string.format("Subtitles (BG): %s", t.title or "Bulgarian"), 2.5)
                        break
                    end
                end
            end
        end)
    end

    -- Notify user
    local summary = table.concat(loaded_names, ", ")
    if #summary > 70 then summary = summary:sub(1, 67) .. "..." end

    if is_focus_event then
        mp.osd_message(string.format("Discovered %d new subtitle(s):\n%s", #to_load, summary), 3.0)
    else
        mp.osd_message(string.format("Found %d external subtitle(s):\n%s", #to_load, summary), 3.0)
    end
end

-- Run on file load
mp.register_event("file-loaded", function()
    mp.add_timeout(0.2, function()
        scan_and_load_subtitles(false, false)
    end)
end)

-- Dynamic monitoring: scan when window gains focus (user dropped or downloaded subtitles)
local last_focus_scan = 0
mp.observe_property("window-focused", "bool", function(_, focused)
    if focused then
        local now = mp.get_time()
        if now - last_focus_scan > 2.0 then
            last_focus_scan = now
            scan_and_load_subtitles(false, true)
        end
    end
end)

-- Script messages for manual rescan
mp.register_script_message("reload-subs", function()
    scan_and_load_subtitles(true, false)
end)
mp.register_script_message("rescan-subs", function()
    scan_and_load_subtitles(true, false)
end)
