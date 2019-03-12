-- Tiled maps loading library

local assets = require('libs.assets')

local FlippedHorizontallyFlag   = 0x80000000
local FlippedVerticallyFlag     = 0x40000000
local FlippedDiagonallyFlag     = 0x20000000
local ClearFlag                 = 0x1FFFFFFF

-- Break full path string into path and filename
local function extract_path(p)
	local c
	for i = p:len(), 1, -1 do
		c = p:sub(i, i)
		if c == '/' then
			return p:sub(1, i - 1), p:sub(i + 1)
		end
	end
end

-- Keep a value in boundaries
local function clamp(value, low, high)
	if value < low then value = low
	elseif high and value > high then value = high end
	return value
end

local function load(self, params)
	self.map = require(params.filename) -- Actual Tiled data
	self.specs = params.specs or {}

	self:prepare_tilesets()

	self.group = assets.new_group()

	self.layers = {} -- Each Tiled layer has it's own group and they are stored here
	self.collision_objects = {}

	-- A set of properties for the camera
	self.width = self.map.tilewidth * self.map.width
	self.height = self.map.tilewidth * self.map.height
end

-- Load all spritesheers into memory
local function prepare_tilesets(self)
	self.tilesets = {}
	self.tileProperties = {}
	local map = self.map
	for i = 1, #map.tilesets do
		local t = map.tilesets[i]
		if t.image then
			local dir, filename = extract_path(t.image:sub(4))
			local spritesheet = {
				width = t.imagewidth,
				height = t.imageheight,
				spacing = t.spacing,
				tile = {
					width = t.tilewidth,
					height = t.tileheight
				},
				count = (t.imagewidth / (t.tilewidth + t.spacing)) * (t.imageheight / (t.tileheight + t.spacing)),
				width_count = t.imagewidth / (t.tilewidth + t.spacing),
				height_count = t.imageheight / (t.tileheight + t.spacing),
			}
			table.insert(self.tilesets, spritesheet)
		end

		if t.tiles then
			self.tileProperties[t.name] = {}
			for j = 1, #t.tiles do
				local p = t.tiles[j]
				if p.properties then
					self.tileProperties[t.name][p.id + 1] = p.properties
				else
					self.tileProperties[t.name][p.id + 1] = {image = p.image:sub(4, p.image:len()), width = p.width, height = p.height}
				end
			end
		end
	end
end

local function get_spritesheet_by_gid(self, gid)
	local map_tilesets = self.map.tilesets
	for i = #map_tilesets, 1, -1 do
		if map_tilesets[i].firstgid <= gid then
			return map_tilesets[i].name, self.tilesets[i], gid - map_tilesets[i].firstgid + 1
		end
	end
end

local function new_tile(self, params)
	local map = self.map
	local gid = params.gid
	local flip = {}
	if gid > 1000 or gid < -1000 then
		flip.x = bit.band(gid, FlippedHorizontallyFlag) ~= 0
		flip.y = bit.band(gid, FlippedVerticallyFlag) ~= 0
		flip.xy = bit.band(gid, FlippedDiagonallyFlag) ~= 0
		gid = bit.band(gid, ClearFlag)
	end
	local sheetName, sheet, frameIndex = self:get_spritesheet_by_gid(gid)
	local properties = self.tileProperties[sheetName] and self.tileProperties[sheetName][frameIndex] or {}
	local tile
	local scale = {x = 1, y = 1}
	local rotation = 0
	if sheet then
		local flip_x, flip_y = flip.x, flip.y
		if flip.xy then
			rotation = math.pi * 1.5
			flip_x, flip_y = flip.y, flip.x
		end
		tile = assets.new_tile{
			parent = params.g,
			sheet = sheet,
			index = frameIndex,
			x = (params.x + 0.5) * map.tilewidth,
			y = (params.y + 0.5) * map.tileheight,
			scale = scale,
			rotation = rotation
		}
		if flip_x then
			sprite.set_hflip(tile.component_url, true)
		end
		if flip_y then
			sprite.set_vflip(tile.component_url, true)
		end
	end
	return tile
end

-- Objects are rectangles and other polygons from Tiled
local function new_object(self, params)
	if params.shape == 'rectangle' then
		table.insert(self.collision_objects, {x = params.x, y = -params.y - params.height, width = params.width, height = params.height})
	end
end

-- Iterate each Tiled layer and create all tiles and objects
local function draw(self)
	local map = self.map
	local w, h = map.width, map.height
	for i = 1, #map.layers do
		local l = map.layers[i]
		if l.type == 'tilelayer' then
			local groupLayer = assets.new_group()
			self.group:insert(groupLayer)
			table.insert(self.layers, groupLayer)
			if l.properties.ratio then
				groupLayer.ratio = tonumber(l.properties.ratio)
			end
			if l.properties.speed then
				groupLayer.speed = tonumber(l.properties.speed)
				groupLayer.xOffset = 0
			end
			if l.properties.yFactor then
				groupLayer.yFactor = tonumber(l.properties.yFactor)
			end
			local tint
			if l.properties.tintR and l.properties.tintG and l.properties.tintB then
				tint = {tonumber(l.properties.tintR), tonumber(l.properties.tintG), tonumber(l.properties.tintB)}
			end
			local d = l.data
			local gid
			for y = 0, h - 1 do
				for x = 0, w - 1 do
					gid = d[x + y * w + 1]
					if gid > 0 then
						self:new_tile{
							gid = gid,
							g = groupLayer,
							x = x, y = y,
							tint = tint
						}
					end
				end
			end
		elseif l.type == 'objectgroup' then
			for j = 1, #l.objects do
				local o = l.objects[j]
				self:new_object{g = self.physicsGroup,
					shape = o.shape,
					x = o.x, y = o.y,
					width = o.width, height = o.height,
					polygon = o.polygon
				}
			end
		end
	end
end

local function map_xy_to_pixels(self, x, y)
	return x * self.map.tilewidth, y * self.map.tileheight
end

local _M = {}

function _M.new(params)
	local map = {
		load = load,
		prepare_tilesets = prepare_tilesets,
		get_spritesheet_by_gid = get_spritesheet_by_gid,
		new_tile = new_tile,
		new_object = new_object,
		draw = draw,
		map_xy_to_pixels = map_xy_to_pixels
	}
	map:load(params)
	return map
end

return _M
