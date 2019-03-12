local utils = require('libs.utils')

local _M = {
	position = vmath.vector3(0, 0, 0),
	width = 0,
	height = 0,
	time = 0,
	dt = 0,
	zoom = 1,
	pan = vmath.vector3(0, 0, 0),
	pan_limit = {x = {min = 0, max = 0}, y = {min = 0, max = 0}},
	zoom_limit = {min = 0.2, max = 2}
}

function _M.zoom_step(value)
	_M.zoom_to(_M.zoom + value / 5, _M.width / 2, _M.height / 2)
end

function _M.zoom_to(value, x, y)
	local old_x, old_y = _M.screen_to_world(x, y)
	_M.zoom = utils.clamp(value, _M.zoom_limit.min, _M.zoom_limit.max)
	local new_x, new_y = _M.screen_to_world(x, y)
	local px = utils.clamp(_M.pan.x + new_x - old_x, _M.pan_limit.x.min, _M.pan_limit.x.max)
	local py = utils.clamp(_M.pan.y - (new_y - old_y), _M.pan_limit.y.min, _M.pan_limit.y.max)
	_M.pan = vmath.vector3(px, py, 0)
end

function _M.pan_by(start, px, py)
	px = utils.clamp(start.x + px / _M.zoom, _M.pan_limit.x.min, _M.pan_limit.x.max)
	py = utils.clamp(start.y - py / _M.zoom, _M.pan_limit.y.min, _M.pan_limit.y.max)
	_M.pan = vmath.vector3(px, py, 0)
end

function _M.pan_to(px, py)
	px = utils.clamp(px / _M.zoom, _M.pan_limit.x.min, _M.pan_limit.x.max)
	py = utils.clamp(py / _M.zoom, _M.pan_limit.y.min, _M.pan_limit.y.max)
	_M.pan = vmath.vector3(px, py, 0)
end

function _M.screen_to_world(x, y, no_pan_zoom)
	x, y = x - _M.width / 2, y - _M.height / 2
	if no_pan_zoom then
		return x, y
	else
		return x / _M.zoom - _M.pan.x, y / _M.zoom + _M.pan.y
	end
end

return _M