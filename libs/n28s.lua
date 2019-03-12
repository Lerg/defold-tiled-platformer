local hashed = require('libs.hashed')

local _M = {}

local scripts = {}

-- NoMoreGlobalFunctionsInScripts

function _M.new()
	local script = {
		is_script = true,
		messages = {}
	}
	return script
end

--[[init(self)
final(self)
update(self, dt)
on_message(self, message_id, message, sender)
on_input(self, action_id, action)
on_reload(self)]]

local defold_methods = {'update', 'on_input', 'on_reload'}
function _M.register(script)
	_G['init'] = function(self, ...)
		local s = {}
		for k, v in pairs(script) do
			s[k] = v
		end
		scripts[self] = s
		s.instance = self
		if s.init then
			s:init(...)
		end
	end
	_G['final'] = function(self, ...)
		local s = scripts[self]
		if s.final then
			s:final(...)
		end
		scripts[self] = nil
	end
	for i = 1, #defold_methods do
		local method = defold_methods[i]
		if script[method] then
			_G[method] = function(self, ...)
				local s = scripts[self]
				s[method](s, ...)
			end
		end
	end
	local has_messages = false
	for method, f in pairs(script) do
		if type(f) == 'function' and method:len() > 8 and method:sub(1, 8) == 'message_' then
			has_messages = true
			local message_id = method:sub(9)
			script.messages[hashed[message_id]] = f
		end
	end
	if has_messages then
		_G.on_message = function(self, message_id, message, sender)
			local s = scripts[self]
			local f = s.messages[message_id]
			if f then
				f(s, message, sender)
				return true
			end
		end
	end
end

return _M