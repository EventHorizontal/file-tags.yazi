local M = {}

-- Plugins seem to have to be a single file so I'm dividing this
-- into regions for organisation

M.database_location = os.getenv("HOME") .. "/.local/state/yazi/file-tags/tag_database.json"

-- Saving and Loading ######################################################3

function M.save_table(t)
	-- Open the file handle
	local file, errorString = io.open(M.database_location, "w")

	if not file then
		-- Error occurred; output the cause
		ya.dbg("File error: " .. errorString)
		return false
	else
		local serialised, err = ya.json_encode(t)
		ya.dbg("saved", serialised, err)
		-- Write encoded JSON data to file
		file:write(serialised)
		-- Close the file handle
		io.close(file)
		return true
	end
end

function M.load_table()
	-- Open the file handle
	local file, errorString = io.open(M.database_location, "r")

	if not file then
		os.execute("mkdir " .. M.database_location)
		local file2, errorString2 = io.open(M.database_location, "w")
		if not file2 then
			ya.dbg("File error: " .. errorString)
		else
			file2:write("{}")
			return {}
		end
	else
		-- Read data from file
		local contents = file:read("*a")
		-- Decode JSON data into Lua table
		local t = ya.json_decode(contents)
		ya.dbg("load: ", t)
		-- Close the file handle
		io.close(file)
		-- Return table
		return t
	end
end

M.tag_database = M.load_table()

-- Helper Functions ####################################################

local function array_contains(table, value)
	for _, tag in ipairs(table) do
		if tag == value then
			return true
		end
	end
	return false
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

local get_selected_or_hovered_files = ya.sync(function()
	local tab, urls = cx.active, {}
	for _, url in pairs(tab.selected) do
		urls[#urls + 1] = { full_path = url.parent .. "/" .. url.name, filename = url.name }
	end
	if #urls == 0 and tab.current.hovered then
		local url = tab.current.hovered.url
		urls[1] = { full_path = url.parent .. "/" .. url.name, filename = url.name }
	end
	return urls
end)

local get_hovered_file = ya.sync(function()
	local url = cx.active.current.hovered.url
	return { full_path = url.parent .. "/" .. url.name, filename = url.name }
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

local set_cut_files = ya.sync(function(state, _cut_files)
	state.cut_files = _cut_files
end)

local get_cut_files = ya.sync(function(state)
	return state.cut_files
end)

local get_cwd = ya.sync(function(state)
	return cx.active.current.cwd
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

local function url_to_absolute_path(url)
	return url.parent .. "/" .. url.name
end

function split(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end

-- Plugin Methods ##########################################
-- credit to yazi-rs/plugins/mount.yazi for the modal viewing code

M.keys = {
	{ on = "q", run = "quit" },
	{ on = "j", run = "file_down" },
	{ on = "<C-j>", run = "down" },
	{ on = "h", run = "directory_up" },
	{ on = "l", run = "directory_down" },
	{ on = "k", run = "file_up" },
	{ on = "<C-k>", run = "up" },
	{ on = "a", run = "add" },
	{ on = "d", run = "delete" },
	{ on = "c", run = "change" },
	{ on = "<Enter>", run = "jump" },
}

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
			ui.Constraint.Percentage(10),
			ui.Constraint.Percentage(80),
			ui.Constraint.Percentage(10),
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
		rows[#rows + 1] = ui.Row({ string.sub(item, math.max(#item - self._area.w + 6, 0)) })
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
	M.tag_database = M.load_table()

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

		local files = get_selected_or_hovered_files()
		for _, file in ipairs(files) do
			local full_path = file.full_path
			if M.tag_database[full_path] == nil then
				M.tag_database[full_path] = { tag_name }
			else
				if not array_contains(M.tag_database[full_path], tag_name) then
					table.insert(M.tag_database[full_path], tag_name)
				end
			end
			table.sort(M.tag_database[full_path])
		end
		M.save_table(M.tag_database)
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

		local files = get_selected_or_hovered_files()
		for _, file in ipairs(files) do
			if M.tag_database[file.full_path] ~= nil then
				array_remove(M.tag_database[file.full_path], function(t, i, _)
					return t[i] ~= tag_name
				end)
			end
		end

		M.save_table(M.tag_database)
	elseif action == "delete_all" then
		local files = get_selected_or_hovered_files()
		for _, file in ipairs(files) do
			M.tag_database[file.full_path] = nil
		end

		M.save_table(M.tag_database)
	elseif action == "list" then
		local hovered_file = get_hovered_file().full_path
		set_menu_state({ title = "Tags", items = M.tag_database[hovered_file] })
		toggle_modal()
		set_cursor(0)
		local tx, rx = ya.chan("mpsc")
		local tx2, rx2 = ya.chan("mpsc")

		function producer()
			while true do
				local idx = ya.which({ cands = self.keys, silent = true })
				local cand = M.keys[idx] or { run = {} }
				for _, r in ipairs(type(cand.run) == "table" and cand.run or { cand.run }) do
					tx:send(r)
					if r == "quit" then
						toggle_modal()
						return
					elseif r == "change" or r == "add" then
						local done = false
						while not done do
							done = rx2:recv() or false
						end
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
				elseif run == "directory_up" then
					ya.mgr_emit("leave", {})
				elseif run == "directory_down" then
					ya.mgr_emit("enter", {})
				elseif run == "file_up" then
					ya.mgr_emit("arrow", { -1 })
					local _hovered_file = get_hovered_file().full_path
					set_menu_state({ title = "Tags", items = self.tag_database[_hovered_file] })
					ya.render()
				elseif run == "file_down" then
					ya.mgr_emit("arrow", { 1 })
					local _hovered_file = get_hovered_file().full_path
					set_menu_state({ title = "Tags", items = self.tag_database[_hovered_file] })
					ya.render()
				elseif run == "add" then
					local file = get_hovered_file().full_path
					local tag_name, event = ya.input({
						title = "Input new tag",
						position = {
							"center",
							w = 30,
						},
					})

					if event ~= 1 then
						return
					end
					if M.tag_database[file] == nil then
						M.tag_database[file] = { tag_name }
					else
						if not array_contains(M.tag_database[file], tag_name) then
							table.insert(M.tag_database[file], tag_name)
						end
					end

					table.sort(M.tag_database[file])

					set_menu_state({ title = "Tags", items = self.tag_database[file] })
					M.save_table(self.tag_database)
					ya.render()
					tx2:send(true)
				elseif run == "delete" then
					local file = get_hovered_file().full_path
					array_remove(self.tag_database[file], function(_, i, _)
						return i ~= get_cursor() + 1
					end)
					set_menu_state({ title = "Tags", items = self.tag_database[file] })
					M.save_table(self.tag_database)
					ya.render()
				elseif run == "change" then
					local cursor = get_cursor()
					local menu_items = get_menu_state()["items"]
					local old_tag_name = menu_items[cursor + 1]
					local new_tag_name, event = ya.input({
						title = "Input new tag",
						value = old_tag_name,
						position = {
							"center",
							w = 30,
						},
					})

					if event ~= 1 then
						return
					end

					-- Remove old tag
					local file = get_hovered_file().full_path
					array_remove(M.tag_database[file], function(t, i, _)
						return t[i] ~= old_tag_name
					end)
					-- Add new tag
					if M.tag_database[file] == nil then
						M.tag_database[file] = { new_tag_name }
					else
						if not array_contains(M.tag_database[file], new_tag_name) then
							table.insert(M.tag_database[file], new_tag_name)
						end
					end

					table.sort(M.tag_database[file])

					set_menu_state({ title = "Tags", items = self.tag_database[file] })
					M.save_table(self.tag_database)
					ya.render()

					tx2:send(true)
				end
			until not run
		end

		ya.join(producer, consumer)
	elseif action == "search" then
		local input, event = ya.input({
			title = "Input tag",
			position = {
				"center",
				w = 30,
			},
		})

		if event ~= 1 then
			return
		end

		local tags_to_search = split(input, ",")
		ya.dbg(tags_to_search)

		local results = {}
		for file, tags in pairs(M.tag_database) do
			local passes_filter = true
			for _, tag in ipairs(tags_to_search) do
				if not array_contains(tags, tag) then
					ya.dbg(file, tag)
					passes_filter = false
				end
			end
			if passes_filter then
				results[#results + 1] = file
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

M.setup = function(state, opts)
	M.should_notify = opts.notify or true

	-- Update database whenever a files are renamed
	ps.sub("rename", function(body)
		local old_filename = url_to_absolute_path(body.from)
		local new_filename = url_to_absolute_path(body.to)
		if M.tag_database[old_filename] then
			M.tag_database[new_filename] = M.tag_database[old_filename]
			M.tag_database[old_filename] = nil
		end
		M.save_table(M.tag_database)
		if M.should_notify then
			ya.notify({
				title = "File-Tags",
				content = "Detected renamed files",
				timeout = 2.0,
				debounce = 0.3,
			})
		end
	end)

	ps.sub("bulk", function(body)
		for old_file, new_file in pairs(body) do
			local old_filename = url_to_absolute_path(old_file)
			local new_filename = url_to_absolute_path(new_file)
			if M.tag_database[old_filename] then
				M.tag_database[new_filename] = M.tag_database[old_filename]
				M.tag_database[old_filename] = nil
			end
			M.save_table(M.tag_database)
			if M.should_notify then
				ya.notify({
					title = "File-Tags",
					content = "Detected bulk renamed files",
					timeout = 2.0,
					debounce = 0.3,
				})
			end
		end
	end)

	-- Update database whenever a files are moved
	ps.sub("move", function(body)
		for _, file in ipairs(body.items) do
			local old_filename = url_to_absolute_path(file.from)
			local new_filename = url_to_absolute_path(file.to)
			if M.tag_database[old_filename] then
				M.tag_database[new_filename] = M.tag_database[old_filename]
				M.tag_database[old_filename] = nil
			end
			M.save_table(M.tag_database)
			if M.should_notify then
				ya.notify({
					title = "File-Tags",
					content = "Detected moved files",
					timeout = 2.0,
					debounce = 0.3,
				})
			end
		end
	end)

	-- Update database whenever files are deleted
	ps.sub("delete", function(body)
		for _, file in ipairs(body.urls) do
			local filename = url_to_absolute_path(file)
			ya.dbg(file)
			if M.tag_database[filename] then
				M.tag_database[filename] = nil
			end
			M.save_table(M.tag_database)
			if M.should_notify then
				ya.notify({
					title = "File-Tags",
					content = "Detected deleted files",
					timeout = 2.0,
					debounce = 0.3,
				})
			end
		end
	end)

	ps.sub("trash", function(body)
		for _, file in ipairs(body.urls) do
			local filename = url_to_absolute_path(file)
			ya.dbg(file)
			if M.tag_database[filename] then
				M.tag_database[filename] = nil
			end
			M.save_table(M.tag_database)
			if M.should_notify then
				ya.notify({
					title = "File-Tags",
					content = "Detected trashed files",
					timeout = 2.0,
					debounce = 0.3,
				})
			end
		end
	end)
end

return M
