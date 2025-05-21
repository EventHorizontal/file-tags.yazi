local M = {}

local selected_or_hovered = ya.sync(function()
	local tab, urls = cx.active, {}
	for _, u in pairs(tab.selected) do
		urls[#urls + 1] = u
	end
	if #urls == 0 and tab.current.hovered then
		urls[1] = tab.current.hovered.url
	end
	return urls
end)
M.entry = function(self, job)
	local action = job.args[1]

	-- local value, event = ya.input({
	-- 	title = "tag name",
	-- 	position = {
	-- 		"center",
	-- 		w = 30,
	-- 	},
	-- })

	local selection = selected_or_hovered()

	for _, url in ipairs(selection) do
		ya.notify({
			title = "File Tag",
			content = "Found file '" .. url .. "'",
			timeout = 6.5,
			-- level = "info",
		})
	end
end

M.setup = function(state, opts) end

return M
