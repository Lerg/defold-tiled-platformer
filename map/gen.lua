local function anim(i)
	local str = [[
animations {
  id: "]] .. i .. [["
  start_tile: ]] .. i .. [[
  end_tile: ]] .. i .. [[
  playback: PLAYBACK_NONE
  fps: 30
  flip_horizontal: 0
  flip_vertical: 0
}]]
	print(str)
end

print([[
image: "/map/siberia.png"
tile_width: 32
tile_height: 32
tile_margin: 0
tile_spacing: 0
collision: ""
material_tag: "tile"
collision_groups: "default"
extrude_borders: 1
inner_padding: 0
]])

for i = 1, 176 do
	anim(i)
end