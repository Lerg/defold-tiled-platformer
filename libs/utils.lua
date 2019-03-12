local base64 = require('libs.base64')

local _M = {}

if sys then
	local sysinfo = sys.get_sys_info()
	_M.is_android = sysinfo.system_name == 'Android'
	_M.is_ios = sysinfo.system_name == 'iPhone OS'
	_M.is_mobile = _M.is_android or _M.is_ios
end

function _M.clamp(value, min, max)
	if value < min then
		return min
	elseif value > max then
		return max
	else
		return value
	end	
end

function _M.round(value)
	return math.floor(value + 0.5)	
end

function _M.table_copy(t)
	local result = {}
	for i = 1, #t do
		result[i] = t[i]
	end
	return result
end

function _M.table_index_of(t, e)
	for i = 1, #t do
		if e == t[i] then
			return i
		end
	end
end

function _M.table_shuffle(t)
	for i = #t, 2, -1 do
		local j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

function _M.next_frame(f)
	timer.delay(0.2, false, f)
end

function _M.download(params)
	local file = io.open(params.filename, 'rb')
	if file then
		file:close()
		if params.on_complete then
			params.on_complete()
		end
	else
		http.request(params.url, params.method or 'GET', function(self, id, response)
			local content = response.response
			local file = io.open(params.filename, 'wb')
			if file then
				file:write(content)
				file:close()
				if params.on_complete then
					params.on_complete()
				end
			else
				print('Failed to open file:', params.filename)
			end
		end)
	end
end

function _M.filename_parts(filename)
	local basename = filename
	local extension = ''
	for i = filename:len(), 1, -1 do
		local char = filename:sub(i, i)
		if char == '.' then
			extension = filename:sub(i, filename:len())
			basename = filename:sub(1, i - 1)
			break
		elseif char == '/' then
			break
		end
	end
	return {name = basename, extension = extension:lower()}
end

function _M.filename_to_cache(filename)
	local parts = _M.filename_parts(filename)
	return base64.encode(parts.name) .. parts.extension
end

return _M