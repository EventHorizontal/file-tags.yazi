return {
	entry = function(_, job)
		ya.notify({
			title = "Hello, World!",
			content = "This is a notification from Lua!",
			timeout = 6.5,
			-- level = "info",
		})
	end,
	setup = function(state, args) end,
}
