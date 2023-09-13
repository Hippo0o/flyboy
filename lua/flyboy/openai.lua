local function recieve_chunk(chunk, on_stdout_chunk, on_chunk_error)
    for line in chunk:gmatch("[^\n]+") do
        local raw_json = string.gsub(line, "^data: ", "")

        local ok, path = pcall(vim.json.decode, raw_json)
        if not ok then
            on_chunk_error(raw_json)
            goto continue
        end

        path = path.choices
        if path == nil then
            goto continue
        end
        path = path[1]
        if path == nil then
            goto continue
        end
        path = path.delta
        if path == nil then
            goto continue
        end
        path = path.content
        if path == nil then
            goto continue
        end

        on_stdout_chunk(path)
        -- append_to_output(path, 0)
        ::continue::
    end
end

local curl = require('plenary.curl')
local function get_chatgpt_completion(options, messages, on_delta, on_error_cb)
    local had_error = false
    local job

    local function on_error(err)
        if on_error_cb and not had_error then
            on_error_cb(err)
        end
        job:shutdown()
        had_error = true
    end

    job = curl.post(options.url,
        {
            headers = options.headers,
            body = vim.fn.json_encode(
                {
                    model = options.model,
                    temperature = options.temperature,
                    messages = messages,
                    stream = true
                }),
            stream = vim.schedule_wrap(function(_, data, _)
                local ok, err = pcall(recieve_chunk, data, on_delta, on_error)
                if not ok then
                    on_error(err)
                end
            end),
            on_error = on_error,
        })

    return job
end


return {
    get_chatgpt_completion = get_chatgpt_completion,
}
