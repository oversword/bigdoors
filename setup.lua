
local S = minetest.get_translator("doors")

local door_sizes = {}
local hidden_sizes = {}
local replacement_doors = {}

local max_width = 0



local function craft_size(s)
	if s == 1.5 then
		return 3, 2
	end
	return s, 1
end

for _w,w in ipairs(bigdoors.config.door_widths) do
	if w >= 100 or w < 1 then
		local allowed = ", please set value "..tostring(_w).." of bigdoors.config.door_widths between 1 and 99 inclusive."
		if w >= 100 then
			minetest.log("error", "BigDoors: Door sizes cannot exceed 10 nodes"..allowed)
		else
			minetest.log("error", "BigDoors: Door sizes cannot be less than 0.1 nodes"..allowed)
		end
	else
		local W = w/10
		if W > max_width then
			max_width = W
		end
		local wrem = W%1
		if wrem == 0 then wrem = 1 end
		for _h,h in ipairs(bigdoors.config.door_heights) do
			if h >= 100 or h < 1 then
				local allowed = ", please set value "..tostring(_h).." of bigdoors.config.door_heights between 1 and 99 inclusive."
				if h >= 100 then
					minetest.log("error", "BigDoors: Door sizes cannot exceed 10 nodes"..allowed)
				else
					minetest.log("error", "BigDoors: Door sizes cannot be less than 0.1 nodes"..allowed)
				end
			else
				local H = h/10
				local hrem = H%1
				if hrem == 0 then hrem = 1 end
				local hidden_size = { width=wrem, height=hrem }
				hidden_sizes[bigdoors.api.size_to_string(hidden_size)] = hidden_size
				local wr, mw = craft_size(W)
				local hr, mh = craft_size(H/2)

				local size = {
					width = W,
					height = H,
					recipe = {
						width = wr,
						height = hr,
						output = mw*mh
					},
				}
				size.hitbox = {
					ad=bigdoors.api.new_hitbox(size),
					bc=bigdoors.api.new_hitbox(size, true)
				}
				local size_string = bigdoors.api.size_to_string(size)
				door_sizes[size_string] = size
			end
		end
	end
end
local max_pair_distance = (max_width*2)-1


-- CUSTOM HIDDEN NODES

local hidden_def = {
	description = S("Hidden Door Segment"),
	drawtype = "airlike",
	paramtype = "light",
	paramtype2 = "facedir",
	sunlight_propagates = true,
	-- has to be walkable for falling nodes to stop falling.
	walkable = true,
	pointable = false,
	diggable = false,
	buildable_to = false,
	floodable = false,
	drop = "",
	groups = {not_in_creative_inventory = 1},
	on_blast = function() end,
	collision_box = {
		type = "fixed",
		fixed = {0,0,0,0,0,0},
	},
}

if bigdoors.config.debug_hidden_nodes then
	local s = 0.3
	hidden_def.selection_box = {type = "fixed", fixed = {-s,-s,-s,s,s,s}}
	hidden_def.tiles = {{ name = "bigdoors_debug.png" }}
	hidden_def.groups = {}
	hidden_def.pointable = true
	hidden_def.drawtype = 'glasslike'
end

minetest.register_node(bigdoors.modname..":hidden", hidden_def) -- doors:hidden has a hitbox, no thanks
bigdoors.api.do_not_move(bigdoors.modname..":hidden")

local function hidden_section(size)
	-- Create hidden sections for hit-box purposes
	local size_string = bigdoors.api.size_to_string(size)
	local name = bigdoors.modname..":hidden_section_"..size_string

	local def = {
		description = S("Hidden Door Section - "..size_string),
		drawtype = "airlike",
		paramtype = "light",
		paramtype2 = "facedir",
		sunlight_propagates = true,
		-- has to be walkable for falling nodes to stop falling.
		walkable = true,
		is_ground_content = false,
		pointable = false,
		diggable = false,
		buildable_to = false,
		floodable = false,
		drop = "",
		groups = {not_in_creative_inventory = 1},
		on_blast = function() end,
		selection_box = {
			type = "fixed",
			fixed = {0,0,0,0,0,0},
		},
		collision_box = {
			type = "fixed",
			fixed = bigdoors.api.new_hitbox(size)
		}
	}

	if bigdoors.config.debug_hidden_nodes then
		local debug_select = bigdoors.api.new_hitbox(size)
		debug_select[6] = -0.3
		debug_select[3] = -0.7
		def.selection_box = {type = "fixed", fixed = debug_select}
		def.tiles = {{ name = "bigdoors_debug.png" }}
		def.groups = {}
		def.pointable = true
		def.drawtype = 'glasslike'
	end

	-- Register nodes

	minetest.register_node(name, def)
	bigdoors.api.do_not_move(name)
end

for _,hidden_size in pairs(hidden_sizes) do
	hidden_section(hidden_size)
end

bigdoors.data = {
	max_pair_distance = max_pair_distance,
	replacement_doors = replacement_doors,
	door_sizes = door_sizes
}