-- Hashed string library.
-- Computes hashes at runtime and caches the result.

local _M = {}

setmetatable(_M, {
	__index = function(t, key)
		local h = hash(key)
		rawset(t, key, h)
		return h
	end
})

return _M