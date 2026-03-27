local api = require("fossil.api")

describe("fossil.api", function()
	it("exec should return error code when running invalid command", function()
		local out, code = api.exec({ "this_is_invalid" })
		assert.are.not_equal(0, code)
	end)

	it("exec_async should callback with exit code", function()
		local done = false
		api.exec_async({ "this_is_invalid" }, nil, function(out, code)
			assert.are.not_equal(0, code)
			done = true
		end)
		vim.wait(1000, function()
			return done
		end)
		assert.is_true(done)
	end)
end)
