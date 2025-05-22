local M = {}

-- TODO: Hardcoded path for now
local defaultLocation = os.getenv("HOME") .. "/Desktop/"
-- Plugins seem to have to be a single file so I'm dividing this
-- into regions for organisation

-- Saving and Loading ######################################################3

function M.save_table(t, filename, location)
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

function M.load_table(filename, location)
	local loc = location
	if not location then
		loc = defaultLocation
	end

	-- Open the file handle
	local file, errorString = io.open(loc .. filename, "r")

	if not file then
		local file, errorString = io.open(loc .. filename, "w")
		if not file then
			ya.dbg("File error: " .. errorString)
		else
			file:write("{}")
			return {}
		end
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

local function array_remove(table, fn_should_keep)
	local j, n = 1, #table

	for i = 1, n do
		if fn_should_keep(table, i, j) then
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

local toggle_modal = ya.sync(function(self)
	if self.children then
		Modal:children_remove(self.children)
		self.children = nil
	else
		self.children = Modal:children_add(self, 10)
	end
	ya.render()
end)

local set_menu_state = ya.sync(function(state, _menu_items)
	state.menu_items = _menu_items
end)

local get_menu_state = ya.sync(function(state)
	return state.menu_items
end)

local set_cursor = ya.sync(function(state, _cursor)
	state.cursor = _cursor
end)

local get_cursor = ya.sync(function(state)
	return state.cursor
end)

local update_cursor = ya.sync(function(self, cursor)
	local num_files = 0
	local menu_items = get_menu_state()["items"]
	if menu_items then
		num_files = #menu_items
	end
	if num_files == 0 then
		set_cursor(0)
	else
		set_cursor((get_cursor() + cursor) % num_files)
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
	{ on = "<Enter>", run = "jump" },
}

M.tag_database = M.load_table("tags.json")

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
	local rows = {}
	local title = get_menu_state()["title"]
	local menu_items = get_menu_state()["items"]
	for _, item in ipairs(menu_items or {}) do
		rows[#rows + 1] = ui.Row({ item })
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
			:header(ui.Row({ title }):style(ui.Style():bold()))
			:row(get_cursor())
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

		local files = selected_or_hovered()
		for _, file in ipairs(files) do
			-- TODO: What if the file already exists in the array?
			if M.tag_database[file] == nil then
				M.tag_database[file] = { tag_name }
			else
				table.insert(M.tag_database[file], tag_name)
			end
		end

		M.save_table(M.tag_database, "tags.json")
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
		for _, file in ipairs(files) do
			if M.tag_database[file] ~= nil then
				array_remove(M.tag_database[file], function(t, i, _)
					return t[i] ~= tag_name
				end)
			end
		end

		M.save_table(M.tag_database, "tags.json")
	elseif action == "delete_all" then
		local files = selected_or_hovered()
		for _, file in ipairs(files) do
			M.tag_database[file] = nil
		end

		M.save_table(M.tag_database, "tags.json")
	elseif action == "list" then
		local hovered_file = hovered()
		set_menu_state({ title = "Tags", items = M.tag_database[hovered_file] })
		toggle_modal()
		set_cursor(0)
		local tx, rx = ya.chan("mpsc")

		function producer()
			while true do
				local idx = ya.which({ cands = self.keys, silent = true })
				local cand = M.keys[idx] or { run = {} }
				for _, r in ipairs(type(cand.run) == "table" and cand.run or { cand.run }) do
					tx:send(r)
					if r == "quit" then
						toggle_modal()
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
					local _hovered_file = hovered()
					set_menu_state({ title = "Tags", items = self.tag_database[_hovered_file] })
					ya.render()
				elseif run == "file_down" then
					ya.mgr_emit("arrow", { 1 })
					local _hovered_file = hovered()
					set_menu_state({ title = "Tags", items = self.tag_database[_hovered_file] })
					ya.render()
				elseif run == "delete" then
					local file = hovered()
					array_remove(self.tag_database[file], function(_, i, _)
						return i ~= get_cursor() + 1
					end)
					set_menu_state({ title = "Tags", items = self.tag_database[file] })
					M.save_table(self.tag_database, "tags.json")
					ya.render()
				elseif run == "change" then
					-- TODO: Figure out how to not block special keys while the modal is up
				end
			until not run
		end

		ya.join(producer, consumer)
	elseif action == "search" then
		local tag_to_search, event = ya.input({
			title = "Input tag",
			position = {
				"center",
				w = 30,
			},
		})

		if event ~= 1 then
			return
		end

		local results = {}
		for file, tags in pairs(M.tag_database) do
			for _, tag in ipairs(tags) do
				if tag == tag_to_search then
					results[#results + 1] = file
					break
				end
			end
		end

		set_menu_state({ title = "Search Results", items = results })
		set_cursor(0)
		toggle_modal()

		local tx, rx = ya.chan("mpsc")

		function producer()
			while true do
				local idx = ya.which({ cands = self.keys, silent = true })
				local cand = M.keys[idx] or { run = {} }
				for _, r in ipairs(type(cand.run) == "table" and cand.run or { cand.run }) do
					tx:send(r)
					if r == "quit" or r == "jump" then
						toggle_modal()
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
				elseif run == "jump" then
					local cursor = get_cursor()
					local menu_items = get_menu_state()["items"]
					local file_to_jump_to = menu_items[cursor + 1]
					ya.mgr_emit("reveal", { file_to_jump_to })
					break
				end
			until not run
		end

		ya.join(producer, consumer)
	end
end

M.setup = function(state, opts) end

return M
