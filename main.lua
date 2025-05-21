return {
	entry = function(_, job)
		local action = job.args[1]

		local value, event = ya.input({
			title = "tag name",
			position = {
				"center",
				w = 30,
			},
		})

		ya.notify({
			title = "File Tag",
			content = "Registered tag '" .. value .. "'",
			timeout = 6.5,
			-- level = "info",
		})
	end,
	setup = function(state, args) end,
}
