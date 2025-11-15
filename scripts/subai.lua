package.path = package.path .. ";" .. mp.command_native({ "expand-path", "~~/script-modules/?.lua" })


local mp = require "mp"
local options = require "mp.options"
local utils = require "mp.utils"

local function read_prompt_file()
    local path = mp.command_native({ "expand-path", "~~/script-opts/subai.prompt.txt" })
    local f, err = io.open(path, "r")
    if not f then
        return nil
    end

    local content = f:read("*a")
    f:close()
    if not content or content = "" then
        return nil
    end

    return content
end

local default_prompt = [[
You translate movie or video subtitles from an original language into {target_lang} and provide linguistic explanations
to help a user speaking {target_lang} learn the language the subtitle is written in.
The user sends a single subtitle line from the video titled "{media_title}".
The user's native language is {target_lang}.
Respond in {target_lang}.
Output format must always be:

«<natural, accurate translation>»
<list of expressions, words, or forms from the original phrase that require clarification. Skip if no explanation required.>

For each expression or word you explain:
- Give its meaning and register. Skip if meaning and register is obvious from the translation you already provided.
- Add cultural or contextual notes if they are lesser known for people speaking {target_lang}.
    For example, explain references to brands, famous people, historical events and its importance, etc.
- Add brief etymology of the word in origin language for less common or polysemous words.
- Provide 1-2 example sentences if useful.

Rules:
- Keep explanations concise but informative.
- Do not ask any questions; the user cannot reply.
- Do not use markdown.
- Do not guess character intentions, emotional subtext, or plot context unless absolutely certain.
- Avoid spoilers.
- Do not explain simple, obvious phrases that any native speaker of {target_lang} understands.
- Do not explain basic linguistic forms (tense, voices, etc) unless it can cause misunderstanding or it is especially difficult.
]]

local system_prompt = read_prompt_file() or default_prompt

local script_options = {
    openrouter_key = "",
    openrouter_url = "https://openrouter.ai/api/v1/chat/completions",
    model = "anthropic/claude-sonnet-4.5",
    target_language = "",
    osd_duration = 8,
    verbose = true,

    font_size = 36,
    line_scale = 90,
}

options.read_options(script_options)

local overlay = mp.create_osd_overlay('ass-events')
local overlay_visible = false

local loading_overlay = mp.create_osd_overlay('ass-events')
local loading_visible = false
local loading_timer = nil

local function log(level, ...)
    if script_options.verbose then
        mp.msg[level](...)
    end
end

local function get_current_subtitle()
    local sub_text = mp.get_property("sub-text")
    if sub_text and sub_text ~= "" then
        return sub_text
    else
        return nil
    end
end

local function build_payload(subtitle_text)
    local media_title = mp.get_property("force-media-title") or mp.get_property("media-title") or ""
    local lang = script_options.target_language

    local function _escape_for_gsub(s)
        return tostring(s or ""):gsub("%%", "%%%%")
    end

    local system_msg = system_prompt
        :gsub("{media_title}", _escape_for_gsub(media_title))
        :gsub("{target_lang}", _escape_for_gsub(lang))

    local body = {
        messages = {
            { role = "system", content = system_msg },
            { role = "user",   content = subtitle_text },
        },
    }

    if script_options.model and script_options.model ~= "" then
        body.model = script_options.model
    end

    return body
end

local function extract_text_from_response(resp)
    if not resp or not resp.choices or not resp.choices[1] or not resp.choices[1].message then
        return nil
    end
    return resp.choices[1].message.content
end

local function http_request_async(url, body_table, callback)
    if not url or url == "" then
        callback(nil, "http_request: url is empty")
        return
    end

    if not body_table or type(body_table) ~= "table" then
        callback(nil, "http_request: body_table must be a table")
        return
    end

    if not script_options.openrouter_key or script_options.openrouter_key == "" then
        callback(nil, "http_request: openrouter_key is not configured")
        return
    end

    local json_body = utils.format_json(body_table)

    log("info", "HTTP request: executing curl to " .. url)

    local args = {
        "curl",
        "-sS",
        "-X", "POST",
        "-H", "Content-Type: application/json",
        "-H", "Authorization: Bearer " .. script_options.openrouter_key,
        "-H", "HTTP-Referer: https://github.com/zenwarr/mpv-config",
        "-H", "X-Title: mpv-subai",
        "--data-binary", json_body,
        url
    }

    local function on_done(success, result, error)
        if not success then
            log("error", "Subprocess failed: " .. tostring(error))
            callback(nil, "Subprocess failed: " .. tostring(error))
            return
        end

        if result.status ~= 0 then
            log("error", "Curl returned non-zero status: " .. tostring(result.status))
            callback(nil, "Curl returned status " .. tostring(result.status))
            return
        end

        local raw_response = result.stdout
        if not raw_response or raw_response == "" then
            callback(nil, "Empty response from API")
            return
        end

        log("debug", "Raw response received: " .. raw_response)

        local ok, decoded = pcall(utils.parse_json, raw_response)
        if not ok then
            log("error", "Failed to decode JSON: " .. tostring(decoded))
            callback(nil, "Failed to decode JSON response")
            return
        end

        callback(decoded, nil)
    end

    mp.command_native_async({
        name = "subprocess",
        args = args,
        capture_stdout = true,
        capture_stderr = true,
    }, on_done)
end

local function sanitize_number(n, fallback)
    return tonumber(n) or fallback
end

local function display_result(text)
    if not text then
        return
    end

    local ass_prefix = ""
    local overrides = {}

    local fs = sanitize_number(script_options.font_size, 16, 6, 200)
    table.insert(overrides, string.format("\\fs%d", fs))

    local fscy = sanitize_number(script_options.line_scale, 90, 50, 200)
    table.insert(overrides, string.format("\\fscy%d", fscy))

    ass_prefix = string.format("{%s}", table.concat(overrides, ""))

    local ass_text = tostring(text):gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("\n", "\\N")

    overlay.data = ass_prefix .. ass_text
    overlay:update()
    overlay_visible = true
end

local function show_loading_indicator()
    local loading_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
    local frame_index = 1

    loading_visible = true

    local function update_loading()
        if not loading_visible then
            return
        end

        local loading_text = loading_frames[frame_index] .. " Translating..."
        frame_index = frame_index % #loading_frames + 1

        loading_overlay.data = string.format("{\\an8\\fs28\\b1}%s", loading_text)
        loading_overlay:update()
    end

    update_loading()
    loading_timer = mp.add_periodic_timer(0.1, update_loading)
end

local function hide_loading_indicator()
    loading_visible = false

    if loading_timer then
        loading_timer:kill()
        loading_timer = nil
    end

    loading_overlay:remove()
end

local function call_ai(text)
    if not text or text == "" then
        log("error", "subai: no text provided")
        return
    end

    if not script_options.openrouter_key or script_options.openrouter_key == "" then
        mp.osd_message("subai: openrouter_key is not set. Set it in script-opts.", script_options.osd_duration)
        log("error", "openrouter_key is not configured")
        return
    end

    if not script_options.openrouter_url or script_options.openrouter_url == "" then
        mp.osd_message("subai: openrouter_url is not set. Set it in script-opts.", script_options.osd_duration)
        log("error", "openrouter_url is not configured")
        return
    end

    if not script_options.target_language or script_options.target_language == "" then
        mp.osd_message("subai: target_language is not set. Set it in script-opts.", script_options.osd_duration)
        log("error", "target_language is not configured")
        return
    end

    show_loading_indicator()

    local body_table = build_payload(text)

    http_request_async(script_options.openrouter_url, body_table, function(resp, err)
        hide_loading_indicator()

        if not resp then
            mp.osd_message("subai: error while making HTTP request (see console)", script_options.osd_duration)
            log("error", "subai: HTTP request failed: " .. tostring(err))
            return
        end

        local extracted = extract_text_from_response(resp)

        if not extracted or extracted == "" then
            mp.osd_message("subai: got response but couldn't parse it. See console.", script_options.osd_duration)
            log("info", "subai: Unparsed API response: " .. utils.format_json(resp))
            return
        end

        display_result(extracted)
    end)
end

mp.register_script_message("run", function()
    if overlay_visible then
        overlay:remove()
        overlay_visible = false
        return
    end

    local sub = get_current_subtitle()
    if sub == nil then
        mp.osd_message("subai: no subtitle visible", 3)
        return
    end

    local ok, resp = pcall(call_ai, sub)
    if not ok then
        mp.osd_message("subai: error while calling API (see console)", 5)
        mp.msg.error("call_ai raised error: " .. tostring(resp))
        return
    end
end)
