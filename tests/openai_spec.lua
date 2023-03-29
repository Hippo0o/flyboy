local mock = require('luassert.mock')
local match = require('luassert.match')

local eq = assert.are.same

local completion_response = {
	id = "chatcmpl-123",
	object = "chat.completion",
	created = 1677652288,
	choices = { {
		index = 0,
		message = {
			role = "assistant",
			content = "\n\nHello there, how may I assist you today?",
		},
		finish_reason = "stop"
	} },
	usage = {
		prompt_tokens = 9,
		completion_tokens = 12,
		total_tokens = 21
	}
}

describe('ChatGPT call', function()
	local testCurl = require('plenary.curl')
	it('returns the completion response from curl call', function()
		local curl = mock(testCurl, true)
		local env = mock(vim.env, true)

		env.OPENAI_API_KEY = "test"

		curl.post.returns({ body = vim.fn.json_encode(completion_response) })

		local openai = require('flyboy.openai')
		local completion = openai.get_chatgpt_completion({ { role = "system", content = "Say hello!" } })

		eq(completion, completion_response)
	end)
	it('uses the correct API key and body', function()
		local curl = mock(testCurl, true)
		local env = mock(vim.env, true)

		env.OPENAI_API_KEY = "test"

		curl.post.returns({ body = vim.fn.json_encode(completion_response) })

		local openai = require('flyboy.openai')
		openai.get_chatgpt_completion({ { role = "system", content = "Say hello!" } })

		assert.stub(curl.post).was_called_with("https://api.openai.com/v1/chat/completions", match.table({
			headers = {
				['Content-Type'] = 'application/json',
				['Authorization'] = 'Bearer test'
			},
			body = vim.fn.json_encode({
				messages = { { role = "system", content = "Say hello!" } },
				model = "gpt-3.5-turbo"
			})
		}))
	end)

end)
