local M = {}

M._Config = {
	-- File where bd are stored
	bd_file = "",
	-- number of ppl (lines to display in alpha)
	lines = 3,
	-- pattern to detect lines with birthday and name
	pattern = "",
	-- date format
	dateFormat = "mm-dd",
	-- max_cols = 30
	max_cols = 30,
}

local function loadFile()
	if M._Config.bd_file == "" then
		print("Path to file not defined")
		return nil
	end
	local file = io.open(M._Config.bd_file, "r")
	if file == nil then
		print("File not found")
		return nil
	end
	local people = {}
	local i = 1
	local parentID = 1
	while true do
		local line = file:read()
		if line == nil then
			break
		end
		local mPerson, mDate = string.match(line, "^## (.*)(`[0-9x][0-9x][0-9x][0-9x]%-[0-9][0-9]%-[0-9][0-9]`)")
		if mPerson then
			mPerson = string.match(mPerson, "^%s*(.-)%s*$")
			mDate = string.match(mDate, "`(.*)`")
			parentID = i
			table.insert(people, { mPerson, mDate, parentID, 0 })
			i = i + 1
		else
			local mSubPerson, mSubDate =
				string.match(line, "^ *[%-#]*(.*)`([0-9x][0-9x][0-9x][0-9x]%-[0-9][0-9]%-[0-9][0-9])`")
			if mSubPerson then
				mSubPerson = string.match(mSubPerson, "^%s*(.-)%s*$")
				table.insert(people, { mSubPerson, mSubDate, i, parentID })
				i = i + 1
			end
		end
	end
	file:close()
	return people
end

local function shiftPeople(people)
	local before = {}
	local after = {}
	local current_date = string.sub(tostring(os.date("%Y-%m-%d")), 6)
	for i, t in ipairs(people) do
		local tMonth = string.sub(t[2], 6)
		if tMonth < current_date then
			table.insert(before, t)
		else
			table.insert(after, t)
		end
	end
	for _, v in ipairs(before) do
		table.insert(after, v)
	end
	return after
end

local function utf8len(str)
	local len = 0
	for _ in string.gmatch(str, "[%z\1-\127\194-\244][\128-\191]*") do
		len = len + 1
	end
	return len
end

local function align_left(text, max_length)
	local text_length = utf8len(text)
	if text_length < max_length then
		return text .. string.rep(" ", max_length - text_length)
	else
		return text
	end
end

local function sortPeople(people)
	table.sort(people, M.SortByDate)
	return people
end

function M.SortByDate(a, b)
	local aPart = string.sub(a[2], 5)
	local bPart = string.sub(b[2], 5)
	return aPart < bPart
end

local function cliptext(text, width)
	if not text then
		return ""
	end
	local len = utf8len(text)
	if len > width then
		return text:sub(1, width - 3) .. "..."
	else
		return text
	end
end

local function transformPeople(people, lines, spacer)
	lines = lines or -1
	local transformers = {}
	local col3width = 5
	local col2width = math.floor((M._Config.max_cols - col3width) / 2)
	local col1width = M._Config.max_cols - col3width - col2width
	for i, v in ipairs(people) do
		if i <= lines or lines == -1 then
			local person = v[1]
			local oParent = M.findParent(people, v[4])
			local parent = ""
			if oParent then
				parent = "~" .. oParent[1]
			end
			local date = string.sub(v[2], 6)
			local alPerson = align_left(cliptext(person, col1width), col1width)
			local alParent = align_left(cliptext(parent, col2width), col2width)
			table.insert(transformers, string.format("%s %s %" .. col3width .. "s", alPerson, alParent, date))
			if spacer == "yes" then
				table.insert(transformers, string.format("%25s", " "))
			end
		end
	end
	return transformers
end

function M.findParent(people, parentID)
	for i, v in ipairs(people) do
		if v[3] == parentID then
			return v
		end
	end
	return nil
end

local function print_r(arr, indent)
	indent = indent or 0
	local str = ""

	for k, v in pairs(arr) do
		if type(k) ~= "number" then
			k = '"' .. k .. '"'
		end
		local innerIndent = string.rep(" ", indent + 2)
		str = str .. innerIndent .. "[" .. k .. "] = "

		if type(v) == "table" then
			str = str .. "{\n"
			str = str .. print_r(v, indent + 2)
			str = str .. innerIndent .. "},\n"
		elseif type(v) == "string" then
			str = str .. '"' .. v .. '",\n'
		else
			str = str .. tostring(v) .. ",\n"
		end
	end

	return str
end

local function display_people(people, method)
	method = method or "printr"

	-- Create a new buffer for the output
	local output_buf = vim.api.nvim_create_buf(false, true)

	-- Get the formatted output as a string
	local formatted_output = people
	if method == "printr" then
		formatted_output = vim.split(print_r(people), "\n")
	end

	-- Set the contents of the output buffer
	vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, formatted_output)
	--
	local lines_displayed = vim.api.nvim_win_get_height(0)
	local row = math.floor(lines_displayed * 0.1) + 1
	local col = math.floor(vim.o.columns * 0.1)

	-- Set the options for the new window
	local opts = {
		relative = "editor",
		row = row,
		col = col,
		width = math.floor(vim.o.columns * 0.8),
		height = math.floor(lines_displayed * 0.8),
		style = "minimal",
		border = "rounded",
		title = "Birthdays",
		title_pos = "center",
	}

	-- Open a new floating window with the output buffer
	vim.api.nvim_open_win(output_buf, true, opts)

	-- Switch back to the original buffer
	-- vim.api.nvim_set_current_buf(current_buf)
end

function M.birthdays(spacer)
	local results = loadFile()
	if results == nil then
		return
	end
	results = sortPeople(results)
	results = shiftPeople(results)
	results = transformPeople(results, M._Config.lines, spacer)
	return results
end

function M.displayBirthdays()
	local results = loadFile()
	if results == nil then
		return
	end
	results = sortPeople(results)
	results = shiftPeople(results)
	results = transformPeople(results, -1, "yes")
	display_people(results, "normal")
end

-- this is a strange
function M.setup(opts)
	if opts ~= nil then
		M._Config.bd_file = opts.bd_file or M._Config.bd_file
		M._Config.lines = opts.lines or M._Config.lines
		M._Config.pattern = opts.pattern or M._Config.pattern
		M._Config.dateFormat = opts.dateFormat or M._Config.dateFormat
	end
	vim.cmd([[command! Birthdays lua require('next-birthday').displayBirthdays()]])
	-- Add keymaps to Telescope Tags and Note Tags
end

-- Export's public function (instead of it, can be added list od method to export)
return setmetatable({}, {
	__index = function(_, k)
		if M[k] then
			return M[k]
		else
			error("Invalid method " .. k)
		end
	end,
})
-- M.displayBirthdays()
