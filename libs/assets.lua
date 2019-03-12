local camera = require('libs.camera')
local hashed = require('libs.hashed')
local utils = require('libs.utils')

local _M = {}

local property_hashes = {
	position = hashed.position,
	position_x = hashed['position.x'],
	position_y = hashed['position.y'],
	position_z = hashed['position.z'],
	scale = hashed.scale,
	scale_x = hashed['scale.x'],
	scale_y = hashed['scale.y'],
	scale_z = hashed['scale.z'],
	euler = hashed.euler,
	euler_x = hashed['euler.x'],
	euler_y = hashed['euler.y'],
	euler_z = hashed['euler.z'],
	rotation = hashed.rotation
}

local function asset_init(self)
	self.component_url = msg.url(nil, self.subinstance, 'component')
end

local function asset_animate(self, properties, params)
	local on_complete = params.on_complete
	for property, value in pairs(properties) do
		property = property_hashes[property] or property
		go.animate(self.instance, property, params.playback or go.PLAYBACK_ONCE_FORWARD, value, params.easing or go.EASING_LINEAR, params.duration or 1, params.delay or 0, on_complete)
		on_complete = nil
	end
end

local function asset_set(self, properties)
	for property, value in pairs(properties) do
		property = property_hashes[property] or property
		go.set(self.instance, property, value)
	end
end

local function asset_cancel_animation(self, properties)
	if type(properties) == 'table' then
		for i = 1, #properties do
			go.cancel_animations(self.instance, properties[i])
		end
	else
		go.cancel_animations(self.instance, properties)
	end
end

local function asset_apply_pivot(self)
	local position = vmath.vector3(math.floor(self.width * (0.5 - self.pivot_x)), math.floor(self.height * (0.5 - self.pivot_y)), 0)
	local scale = self.is_label and go.get_scale(self.subinstance) or vmath.vector3(1, 1, 1)
	go.set_position(vmath.mul_per_elem(scale, position), self.subinstance)
end

local function asset_is_inside_bounding_box(self, screen_x, screen_y)
	local x, y = camera.screen_to_world(screen_x, screen_y, self.is_ui)
	local position = go.get_world_position(self.subinstance)
	local hw, hh = self.width / 2, self.height / 2
	return x > position.x - hw and x < position.x + hw and y > position.y - hh and y < position.y + hh
end

local function asset_enable(self)
	if self.is_group then
		for i = 1, #self.children do
			self.children[i]:enable()
		end
	else
		self.is_enabled = true
		msg.post(self.component_url, hashed.enable)
	end
end

local function asset_disable(self)
	if self.is_group then
		for i = 1, #self.children do
			self.children[i]:disable()
		end
	else
		self.is_enabled = false
		msg.post(self.component_url, hashed.disable)
	end
end

local function asset_delete(self)
	if self.is_group then
		for i = #self.children, 1, -1 do
			self.children[i]:delete()
			self.children[i] = nil
		end
	else
		go.delete(self.instance, true)
	end
end

local function new_asset(params)
	local position = params.position or vmath.vector3(0, 0, 0)
	if params.x then
		position.x = math.floor(params.x)
	end
	if params.y then
		position.y = math.floor(params.y)
	end
	local scale = vmath.vector3(1, 1, 1)
	if params.width then
		scale.x = params.scale.x * params.width / 2
	end
	if params.height then
		scale.y = params.scale.y * params.height / 2
	end
	local instance = factory.create('assets#group', position)
	local factory_url = 'assets#' .. params.type
	if params.texture_id then
		factory_url = factory_url .. '_' .. tostring(texture_slot_by_id(params.texture_id))
	end	
	local subinstance = factory.create(factory_url, nil, vmath.quat_rotation_z(params.rotation), nil, scale)
	msg.post(subinstance, 'set_parent', {parent_id = instance, keep_world_transform = 0})
	local asset = {
		instance = instance,
		subinstance = subinstance,
		width = params.width or 0,
		height = params.height or 0,
		fill_color = params.fill_color or vmath.vector4(1, 1, 1, 1),
		pivot_x = params.pivot_x or 0.5,
		pivot_y = params.pivot_y or 0.5,
		is_ui = params.is_ui
	}
	if params.parent then
		params.parent:insert(asset)
	end
	asset.init = asset_init
	asset.set_fill_color = asset_set_fill_color
	asset.set_fill = asset_set_fill
	asset.animate = asset_animate
	asset.set = asset_set
	asset.cancel_animation = asset_cancel_animation
	asset.apply_pivot = asset_apply_pivot
	asset.is_inside_bounding_box = asset_is_inside_bounding_box
	asset.enable = asset_enable
	asset.disable = asset_disable
	asset.delete = asset_delete
	asset['is_' .. params.type] = true
	asset:init()
	asset:apply_pivot()
	return asset
end

function _M.new_tile(params)
	params.type = 'tile'
	params.y = -params.y
	params.x = params.x
	local tile = new_asset(params)
	sprite.play_flipbook(tile.component_url, tostring(params.index))
	return tile
end

local function group_insert(self, child)
	msg.post(child.instance, 'set_parent', {parent_id = self.instance, keep_world_transform = 0})
	go.set(child.instance, 'position.z', #self.children)
	table.insert(self.children, child)
	child.parent = self
end

function _M.new_group(params)
	params = params or {}
	local position = params.position or vmath.vector3(0, 0, 0)
	if params.x then
		position.x = math.floor(params.x)
	end
	if params.y then
		position.y = math.floor(params.y)
	end
	local instance = factory.create('assets#group', position, nil, nil, scale)
	local group = {instance = instance, children = {}, is_group = true}
	if params.parent then
		params.parent:insert(group)
	end
	group.insert = group_insert
	group.animate = asset_animate
	group.set = asset_set
	group.cancel_animation = asset_cancel_animation
	group.enable = asset_enable
	group.disable = asset_disable
	group.delete = asset_delete
	return group
end
	
return _M