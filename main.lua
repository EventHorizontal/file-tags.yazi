local M = {}

-- TODO: Hardcoded path for now
local defaultLocation = "/home/cipher/Desktop/"

-- Plugins seem to have to be a single file so I'm dividing this
-- into regions for organisation

-- Saving and Loading ######################################################3

function M.saveTable(t, filename, location)
	local loc = location
	if not location then
		loc = defaultLocation
	end

	-- Open the file handle
	local file, errorString = io.open(loc .. filename, "w")

	if not file then
		-- Error occurred; output the cause
		ya.dbg("File error: " .. errorString)
		return false
	else
		local serialised, err = ya.json_encode(t)
		-- Write encoded JSON data to file
		file:write(serialised)
		-- Close the file handle
		io.close(file)
		return true
	end
end

function M.loadTable(filename, location)
	local loc = location
	if not location then
		loc = defaultLocation
	end

	-- Open the file handle
	local file, errorString = io.open(loc .. filename, "r")

	if not file then
		-- Error occurred; output the cause
		ya.dbg("File error: " .. errorString)
	else
		-- Read data from file
		local contents = file:read("*a")
		-- Decode JSON data into Lua table
		local t = ya.json_decode(contents)
		-- Close the file handle
		io.close(file)
		-- Return table
		return t
	end
end

-- Helper Functions ####################################################

function table.copy(t)
	local u = {}
	for k, v in pairs(t) do
		u[k] = v
	end
	return setmetatable(u, getmetatable(t))
end

local function arrayRemove(table, fnKeep)
	local j, n = 1, #table

	for i = 1, n do
		if fnKeep(table, i, j) then
			-- Move i's kept value to j's position, if it's not already there.
			if i ~= j then
				table[j] = table[i]
				table[i] = nil
			end
			j = j + 1 -- Increment position of where we'll place the next kept value.
		else
			table[i] = nil
		end
	end

	return table
end

local selected_or_hovered = ya.sync(function()
	local tab, urls = cx.active, {}
	for _, url in pairs(tab.selected) do
		urls[#urls + 1] = url.parent .. "/" .. url.name
	end
	if #urls == 0 and tab.current.hovered then
		local url = tab.current.hovered.url
		urls[1] = url.parent .. "/" .. url.name
	end
	return urls
end)

local hovered = ya.sync(function()
	local url = cx.active.current.hovered.url
	return url.parent .. "/" .. url.name
end)

local toggle_ui = ya.sync(function(self)
	if self.children then
		Modal:children_remove(self.children)
		self.children = nil
	else
		self.children = Modal:children_add(self, 10)
	end
	ya.render()
end)

local update_cursor = ya.sync(function(self, cursor)
	local tag_database = M.loadTable("tags.json")
	local file = hovered()
	local num_files = 0
	if tag_database[file] then
		num_files = #tag_database[file]
	end
	if num_files == 0 then
		self.cursor = 0
	else
		self.cursor = ya.clamp(0, self.cursor + cursor, num_files - 1)
	end
	ya.render()
end)

-- Plugin Methods ##########################################
-- credit to yazi-rs/plugins/mount.yazi for the modal viewing code

M.keys = {
	{ on = "q", run = "quit" },
	{ on = "<C-n>", run = "down" },
	{ on = "j", run = "file_down" },
	{ on = "<C-p>", run = "up" },
	{ on = "k", run = "file_up" },
	{ on = "d", run = "delete" },
	{ on = "c", run = "change" },
}

M.cursor = 0

function M:new(area)
	self:layout(area)
	return self
end

function M:layout(area)
	local chunks = ui.Layout()
		:constraints({
			ui.Constraint.Percentage(30),
			ui.Constraint.Percentage(40),
			ui.Constraint.Percentage(30),
		})
		:split(area)

	local chunks = ui.Layout()
		:direction(ui.Layout.HORIZONTAL)
		:constraints({
			ui.Constraint.Percentage(30),
			ui.Constraint.Percentage(40),
			ui.Constraint.Percentage(30),
		})
		:split(chunks[2])

	self._area = chunks[2]
end

function M:reflow()
	return { self }
end

function M:redraw()
	local tag_database = M.loadTable("tags.json")
	local file = hovered()
	local rows = {}
	for _, tag in ipairs(tag_database[file] or {}) do
		rows[#rows + 1] = ui.Row({ tag })
	end
	return {
		ui.Clear(self._area),
		ui.Border(ui.Border.ALL)
			:area(self._area)
			:type(ui.Border.ROUNDED)
			:style(ui.Style():fg("blue"))
			:title(ui.Line("File Tags"):align(ui.Line.CENTER)),
		ui.Table(rows)
			:area(self._area:pad(ui.Pad(1, 2, 1, 2)))
			:header(ui.Row({ "Tags" }):style(ui.Style():bold()))
			:row(self.cursor)
			:row_style(ui.Style():fg("blue"):underline()),
	}
end

function M:click() end

function M:scroll() end

function M:touch() end

function M:entry(job)
	local action = job.args[1]

	if not action then
		return
	end

	if action == "add" then
		local tag_name, event = ya.input({
			title = "Input tag",
			position = {
				"center",
				w = 30,
			},
		})

		if event ~= 1 then
			return
		end

		local tag_database = M.loadTable("tags.json")
		local files = selected_or_hovered()
		for _, file in ipairs(files) do
			-- TODO: What if the file already exists in the array?
			if tag_database[file] == nil then
				tag_database[file] = { tag_name }
			else
				table.insert(tag_database[file], tag_name)
			end
		end

		M.saveTable(tag_database, "tags.json")
	elseif action == "delete" then
		local tag_name, event = ya.input({
			title = "Input tag",
			position = {
				"center",
				w = 30,
			},
		})

		if event ~= 1 then
			return
		end

		local files = selected_or_hovered()
		local tag_database = M.loadTable("tags.json")
		for _, file in ipairs(files) do
			if tag_database[file] ~= nil then
				arrayRemove(tag_database[file], function(t, i, _)
					return t[i] ~= tag_name
				end)
			end
		end

		M.saveTable(tag_database, "tags.json")
	elseif action == "delete_all" then
		local files = selected_or_hovered()
		local tag_database = M.loadTable("tags.json")
		for _, file in ipairs(files) do
			tag_database[file] = nil
		end

		M.saveTable(tag_database, "tags.json")
	elseif action == "list" then
		toggle_ui()
		self.cursor = 0
		local tx, rx = ya.chan("mpsc")

		function producer()
			while true do
				local idx = ya.which({ cands = self.keys, silent = true })
				local cand = M.keys[idx] or { run = {} }
				for _, r in ipairs(type(cand.run) == "table" and cand.run or { cand.run }) do
					tx:send(r)
					if r == "quit" then
						toggle_ui()
						return
					end
				end
			end
		end

		function consumer()
			repeat
				local run = rx:recv()
				if run == "quit" then
					break
				elseif run == "up" then
					update_cursor(-1)
				elseif run == "down" then
					update_cursor(1)
				elseif run == "file_up" then
					ya.mgr_emit("arrow", { -1 })
				elseif run == "file_down" then
					ya.mgr_emit("arrow", { 1 })
				elseif run == "delete" then
					local file = hovered()
					local tag_database = M.loadTable("tags.json")
					arrayRemove(tag_database[file], function(_, i, _)
						return i ~= self.cursor + 1
					end)
					M.saveTable(tag_database, "tags.json")
					ya.render()
				end
			until not run
		end

		ya.join(producer, consumer)
	end
end

M.setup = function(state, opts) end

return M
