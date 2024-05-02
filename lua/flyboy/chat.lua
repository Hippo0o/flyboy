local openai = require('flyboy.openai')
local config = require('flyboy.config')

local function open_chat_with_text(text)
    -- create a new empty buffer
    local buffer = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_option(buffer, "filetype", "markdown")
    local lines = vim.split(text, "\n")

    table.insert(lines, "")
    vim.api.nvim_buf_set_lines(buffer, 0, -1, true, lines)

    return buffer
end

local function open_chat_template(template)
    if not (template) then
        template = "blank"
    end
    local final_text = config.options.templates[template].template_fn(config.options.sources)

    return open_chat_with_text(final_text)
end

local function open_chat(template)
    local chat_buffer = open_chat_template(template)

    vim.api.nvim_set_current_buf(chat_buffer)

    if config.options.on_open ~= nil then
        config.options.on_open(template, chat_buffer)
    end

    return chat_buffer
end

local function open_chat_split(template)
    local chat_buffer = open_chat_template(template)
    vim.cmd("sp | b" .. chat_buffer)

    vim.api.nvim_set_current_buf(chat_buffer)

    if config.options.on_open ~= nil then
        config.options.on_open(template, chat_buffer, 'split')
    end

    return chat_buffer
end

local function open_chat_vsplit(template)
    local chat_buffer = open_chat_template(template)
    vim.cmd("vsp | b" .. chat_buffer)

    vim.api.nvim_set_current_buf(chat_buffer)

    if config.options.on_open ~= nil then
        config.options.on_open(template, chat_buffer, 'vsplit')
    end

    return chat_buffer
end

local function parse_markdown()
    local messages = {}
    local currentEntry = nil
    local buffer = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
    for _, line in ipairs(lines) do
        if line:match("^#%s+(.*)%s#$") then
            local role = line:match("^#%s+(.*)%s#$")
            if (currentEntry) then
                table.insert(messages, currentEntry)
            end
            currentEntry = {
                role = string.lower(role),
                content = ""
            }
        elseif currentEntry then
            if (line ~= "") then
                if currentEntry.content == "" then
                    currentEntry.content = line
                else
                    currentEntry.content = currentEntry.content .. "\n" .. line
                end
            end
        end
    end
    if currentEntry then
        table.insert(messages, currentEntry)
    end

    return messages
end

local function send_message()
    local messages = parse_markdown()

    local buffer = vim.api.nvim_get_current_buf()
    local currentLine = vim.api.nvim_buf_line_count(buffer)

    vim.api.nvim_buf_set_lines(buffer, currentLine, currentLine, false, { "", "# Assistant #", "..." })

    currentLine = vim.api.nvim_buf_line_count(buffer) - 1
    local currentLineContents = ""
    local job

    -- maybe expose as function
    vim.keymap.set("n", "<ESC><ESC>", function()
        job:shutdown()
    end, { buffer = buffer })

    local function on_delta(response)
        if config.options.on_delta ~= nil then
            response = config.options.on_delta(buffer, response) or response
        end

        if response then
            local lines = vim.split(response, "\n", {})
            local length = #lines
            for i, line in ipairs(lines) do
                currentLineContents = vim.api.nvim_buf_get_lines(buffer, -2, -1, false)[1]
                if currentLineContents == "..." then
                    currentLineContents = ""
                end
                vim.api.nvim_buf_set_lines(buffer, -2, -1, false, { currentLineContents .. line })

                local last_line_num = vim.api.nvim_buf_line_count(buffer)

                if i < length then
                    -- Add new line
                    vim.api.nvim_buf_set_lines(buffer, -1, -1, false, { "" })
                end

                currentLine = vim.api.nvim_buf_line_count(buffer) - 1
            end
        end
    end

    local function on_error(response)
        if response == "[DONE]" then
            on_delta("\n\n# User #\n")
            if config.options.on_complete ~= nil then
                config.options.on_complete(buffer)
            end
        else
            if config.options.on_error ~= nil then
                config.options.on_error(buffer, response)
            end
        end
    end

    job = openai.get_chatgpt_completion(config.options, messages, on_delta, on_error)
end

local function start_chat(template)
    open_chat(template)
    send_message()
end

local function start_chat_split(template)
    open_chat_split(template)
    send_message()
end

local function start_chat_vsplit(template)
    open_chat_vsplit(template)
    send_message()
end

return {
    send_message = send_message,
    parse_buffer = parse_markdown,
    open_chat = open_chat,
    open_chat_split = open_chat_split,
    open_chat_vsplit = open_chat_vsplit,
    start_chat = start_chat,
    start_chat_split = start_chat_split,
    start_chat_vsplit = start_chat_vsplit,
}
