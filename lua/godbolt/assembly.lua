local api = vim["api"]
local cmd = vim["cmd"]
local fun = vim.fn
local fmt = string.format
local term_escapes = "[\27\155][][()#;?%d]*[A-PRZcf-ntqry=><~]"
local wo_set = api.nvim_win_set_option
local map = {}
local nsid_static = vim.api.nvim_create_namespace("godbolt_highlight")
local nsid = vim.api.nvim_create_namespace("godbolt_cursor")
local function get_highlight(field)
	local highlight = require("godbolt").config.highlight
	if type(highlight) == "table" then
		return highlight[field]
	else
		return nil
	end
end
local function set_highlight_group(group_name, highlight)
	if type(highlight) ~= "string" then
		return nil
	elseif string.sub(highlight, 1, 1) == "#" then
		api.nvim_set_hl(0, group_name, { bg = highlight })
		return group_name
	elseif not vim.tbl_isempty(api.nvim_get_hl(0, { name = highlight })) then
		api.nvim_set_hl(0, group_name, { link = highlight })
		return group_name
	else
		return nil
	end
end
local function get_highlight_groups(highlights)
	local tbl_21_auto = {}
	local i_22_auto = 0
	for i, hl in ipairs(highlights) do
		local val_23_auto = set_highlight_group(("Godbolt" .. i), hl)
		if nil ~= val_23_auto then
			i_22_auto = (i_22_auto + 1)
			tbl_21_auto[i_22_auto] = val_23_auto
		else
		end
	end
	return tbl_21_auto
end
local function prepare_buf(text, name, reuse_3f, source_buf)
	local buf
	if reuse_3f and ("table" == type(map[source_buf])) then
		buf = table.maxn(map[source_buf])
	else
		buf = api.nvim_create_buf(false, true)
	end
	vim.bo[buf]["modifiable"] = true
	api.nvim_buf_set_lines(buf, 0, -1, true, vim.split(text, "\n", { trimempty = true }))
	api.nvim_buf_set_name(buf, name)
	do
		local tmp_9_auto = vim.bo[buf]
		tmp_9_auto["filetype"] = (vim.b.asmsyntax or vim.g.asmsyntax or "asm")
		tmp_9_auto["bufhidden"] = "unload"
		tmp_9_auto["modifiable"] = false
	end
	return buf
end
local function get_current_line()
	return api.nvim_win_get_cursor(0)[1]
end
local function get_entry_source_line(entry, asm_line)
	local source
	do
		local t_5_ = entry
		if nil ~= t_5_ then
			t_5_ = t_5_.asm
		else
		end
		if nil ~= t_5_ then
			t_5_ = t_5_[asm_line]
		else
		end
		if nil ~= t_5_ then
			t_5_ = t_5_.source
		else
		end
		source = t_5_
	end
	if source and (type(source) == "table") and (source.file == vim.NIL) then
		return (source.line + (entry.offset - 1))
	else
		return nil
	end
end
local function get_source_line(source_buffer, asm_buffer, asm_line)
	local _11_
	do
		local t_10_ = map
		if nil ~= t_10_ then
			t_10_ = t_10_[source_buffer]
		else
		end
		if nil ~= t_10_ then
			t_10_ = t_10_[asm_buffer]
		else
		end
		_11_ = t_10_
	end
	return get_entry_source_line(_11_, asm_line)
end
local function cyclic_lookup(array, index)
	return array[(1 + (index % #array))]
end
local function get_source_highlights(source_buffer, namespace_id)
	local extmarks = api.nvim_buf_get_extmarks(
		source_buffer,
		namespace_id,
		0,
		-1,
		{ type = "highlight", details = false, hl_name = false, overlap = false }
	)
	local tbl_21_auto = {}
	local i_22_auto = 0
	for _, _14_ in ipairs(extmarks) do
		local _0 = _14_[1]
		local line = _14_[2]
		local _1 = _14_[3]
		local val_23_auto = line
		if nil ~= val_23_auto then
			i_22_auto = (i_22_auto + 1)
			tbl_21_auto[i_22_auto] = val_23_auto
		else
		end
	end
	return tbl_21_auto
end
local function update_cursor(source_buffer, cursor_line)
	api.nvim_buf_clear_namespace(source_buffer, nsid, 0, -1)
	local source_highlights = get_source_highlights(source_buffer, nsid)
	local group = set_highlight_group("GodboltCursor", get_highlight("cursor"))
	for asm_buffer, entry in pairs(map[source_buffer]) do
		api.nvim_buf_clear_namespace(asm_buffer, nsid, 0, -1)
		for asm_line, _ in ipairs(entry.asm) do
			local source_line = get_entry_source_line(entry, asm_line)
			if source_line and (cursor_line == source_line) then
				api.nvim_buf_add_highlight(asm_buffer, nsid, group, (asm_line - 1), 0, -1)
				if not vim.tbl_contains(source_highlights, (source_line - 1)) then
					api.nvim_buf_add_highlight(source_buffer, nsid, group, (source_line - 1), 0, -1)
					table.insert(source_highlights, (source_line - 1))
				else
				end
			else
			end
		end
	end
	return nil
end
local function update_source(source_buf)
	return update_cursor(source_buf, get_current_line())
end
local function init_highlight(source_buffer, asm_buffer)
	if not (api.nvim_buf_is_valid(source_buffer) and api.nvim_buf_is_valid(asm_buffer)) then
		return nil
	end

	api.nvim_buf_clear_namespace(asm_buffer, nsid_static, 0, -1)
	local source_highlights = get_source_highlights(source_buffer, nsid_static)
	local highlights = get_highlight_groups(get_highlight("static"))
	if vim.tbl_isempty(highlights) then
		return nil
	end

	local entry = map[source_buffer][asm_buffer]
	if not entry then
		return nil
	end

	local source_line_count = api.nvim_buf_line_count(source_buffer)
	local asm_line_count = api.nvim_buf_line_count(asm_buffer)

	for asm_line, _ in ipairs(entry.asm) do
		local source_line = get_entry_source_line(entry, asm_line)
		if
			source_line
			and source_line > 0
			and source_line <= source_line_count
			and asm_line > 0
			and asm_line <= asm_line_count
		then
			local group = cyclic_lookup(highlights, source_line)
			-- Ensure line numbers are valid before adding highlights
			pcall(api.nvim_buf_add_highlight, asm_buffer, nsid_static, group, (asm_line - 1), 0, -1)

			if not vim.tbl_contains(source_highlights, (source_line - 1)) then
				pcall(api.nvim_buf_add_highlight, source_buffer, nsid_static, group, (source_line - 1), 0, -1)
				table.insert(source_highlights, (source_line - 1))
			end
		end
	end
	return nil
end
local function remove_source(source_buffer)
	-- Ensure buffer exists before trying to clear namespaces
	if api.nvim_buf_is_valid(source_buffer) then
		api.nvim_buf_clear_namespace(source_buffer, nsid_static, 0, -1)
		api.nvim_buf_clear_namespace(source_buffer, nsid, 0, -1)
		api.nvim_clear_autocmds({ group = "Godbolt", buffer = source_buffer })
	end

	if require("godbolt").config.auto_cleanup and map[source_buffer] then
		for asm_buffer, entry in pairs(map[source_buffer]) do
			if api.nvim_buf_is_valid(asm_buffer) then
				api.nvim_buf_delete(asm_buffer, {})
			end
		end
	end
	map[source_buffer] = nil
	return nil
end
local function remove_asm(source_buffer, asm_buffer)
	if api.nvim_buf_is_valid(asm_buffer) then
		api.nvim_buf_clear_namespace(asm_buffer, nsid_static, 0, -1)
		api.nvim_buf_clear_namespace(asm_buffer, nsid, 0, -1)
	end

	if map[source_buffer] then
		map[source_buffer][asm_buffer] = nil
	end
	return nil
end
local function update_asm(source_buffer, asm_buffer)
	local asm_line = get_current_line()
	local source_line = get_source_line(source_buffer, asm_buffer, asm_line)
	return update_cursor(source_buffer, source_line)
end
local function clear_asm(source_buffer, asm_buffer)
	-- Remove the entry from map first before trying any window operations
	if map[source_buffer] then
		if map[source_buffer][asm_buffer] then
			-- Store window id before removing the entry
			local winid = map[source_buffer][asm_buffer].winid
			-- Remove the entry
			map[source_buffer][asm_buffer] = nil

			-- Try to close window if it's still valid
			if winid and api.nvim_win_is_valid(winid) then
				pcall(api.nvim_win_close, winid, true)
			end
		end

		-- Clean up source if no more asm buffers
		if require("godbolt").config.auto_cleanup and vim.tbl_isempty(map[source_buffer]) then
			remove_source(source_buffer)
			map[source_buffer] = nil
		end
	end

	-- Clean up buffer highlights if buffer still exists
	if api.nvim_buf_is_valid(asm_buffer) then
		api.nvim_buf_clear_namespace(asm_buffer, nsid_static, 0, -1)
		api.nvim_buf_clear_namespace(asm_buffer, nsid, 0, -1)
	end

	return nil
end
local function setup_aucmd(source_buf, asm_buf)
	local group = api.nvim_create_augroup("Godbolt", { clear = false })
	local cursor = set_highlight_group("GodboltCursor", get_highlight("cursor"))

	if 0 == #api.nvim_get_autocmds({ group = group, buffer = source_buf }) then
		if cursor then
			local function _22_()
				return update_source(source_buf)
			end
			api.nvim_create_autocmd(
				{ "CursorMoved", "BufEnter" },
				{ group = group, callback = _22_, buffer = source_buf }
			)
		end

		local function _24_()
			return remove_source(source_buf)
		end
		api.nvim_create_autocmd(
			{ "BufUnload", "BufDelete", "BufWipeout" },
			{ group = group, callback = _24_, buffer = source_buf }
		)
	end

	if cursor then
		local function _26_()
			return update_asm(source_buf, asm_buf)
		end
		api.nvim_create_autocmd({ "CursorMoved", "BufEnter" }, { group = group, callback = _26_, buffer = asm_buf })
	end

	local function _28_()
		return clear_asm(source_buf, asm_buf)
	end

	-- Set up window close detection for assembly buffer
	local function on_win_closed()
		if map[source_buf] and map[source_buf][asm_buf] then
			-- Just call clear_asm which will handle all cleanup
			clear_asm(source_buf, asm_buf)
		end
	end

	api.nvim_create_autocmd(
		{ "BufUnload", "BufDelete", "BufWipeout", "WinClosed" },
		{ group = group, callback = _28_, buffer = asm_buf }
	)

	-- Add WinClosed handler specifically for the assembly window
	api.nvim_create_autocmd({ "WinClosed" }, {
		group = group,
		callback = on_win_closed,
		buffer = asm_buf,
	})
end
local function make_qflist(err, bufnr)
	if next(err) then
		local tbl_21_auto = {}
		local i_22_auto = 0
		for _, v in ipairs(err) do
			local val_23_auto
			do
				local entry = { text = string.gsub(v.text, term_escapes, ""), bufnr = bufnr }
				if v.tag then
					entry["col"] = v.tag.column
					entry["lnum"] = v.tag.line
				else
				end
				val_23_auto = entry
			end
			if nil ~= val_23_auto then
				i_22_auto = (i_22_auto + 1)
				tbl_21_auto[i_22_auto] = val_23_auto
			else
			end
		end
		return tbl_21_auto
	else
		return nil
	end
end
local function display(response, begin, name, reuse_3f)
	local asm
	if vim.tbl_isempty(response.asm) then
		asm = fmt("No assembly to display (~%d lines filtered)", response.filteredCount)
	else
		local str = ""
		for _, v in pairs(response.asm) do
			if v.text then
				str = (str .. "\n" .. v.text)
			else
				str = str
			end
		end
		asm = str
	end
	local config = require("godbolt").config
	local source_winid = fun.win_getid()
	local source_buf = fun.bufnr()
	local qflist = make_qflist(response.stderr, source_buf)
	local asm_buf = prepare_buf(asm, name, reuse_3f, source_buf)
	local qf_winid = nil
	if qflist and config.quickfix.enable then
		fun.setqflist(qflist)
		if config.quickfix.auto_open then
			vim.cmd.copen()
			qf_winid = fun.win_getid()
		else
		end
	else
	end
	if not vim.tbl_isempty(response.asm) and ("<Compilation failed>" == response.asm[1].text) then
		return vim.notify("godbolt.nvim: Compilation failed")
	else
		api.nvim_set_current_win(source_winid)
		local asm_winid
		if reuse_3f and map[source_buf] then
			asm_winid = map[source_buf][asm_buf].winid
		else
			cmd("vsplit")
			asm_winid = api.nvim_get_current_win()
		end
		api.nvim_set_current_win(asm_winid)
		api.nvim_win_set_buf(asm_winid, asm_buf)
		wo_set(asm_winid, "number", false)
		wo_set(asm_winid, "relativenumber", false)
		wo_set(asm_winid, "spell", false)
		wo_set(asm_winid, "cursorline", false)
		if qf_winid then
			api.nvim_set_current_win(qf_winid)
		else
			api.nvim_set_current_win(source_winid)
		end
		if not map[source_buf] then
			map[source_buf] = {}
		else
		end
		map[source_buf][asm_buf] = { asm = response.asm, offset = begin, winid = asm_winid }
		if not vim.tbl_isempty(response.asm) then
			if get_highlight("static") then
				init_highlight(source_buf, asm_buf)
			else
			end
			return setup_aucmd(source_buf, asm_buf)
		else
			return nil
		end
	end
end
local function pre_display(begin, _end, compiler, options, reuse_3f)
	local lines = api.nvim_buf_get_lines(0, (begin - 1), _end, true)
	local text = fun.join(lines, "\n")
	local curl_cmd = require("godbolt.cmd")["build-cmd"](compiler, text, options, "asm")
	local time = os.date("*t")
	local hour = time.hour
	local min = time.min
	local sec = time.sec
	local function _42_(_, _0, _1)
		local file = io.open("godbolt_response_asm.json", "r")
		local response = file:read("*all")
		file:close()
		os.remove("godbolt_request_asm.json")
		os.remove("godbolt_response_asm.json")
		return display(vim.json.decode(response), begin, fmt("%s %02d:%02d:%02d", compiler, hour, min, sec), reuse_3f)
	end
	return fun.jobstart({
		"sh",
		"-c",
		curl_cmd,
	}, {
		on_exit = _42_,
	})
end
return { ["pre-display"] = pre_display }
