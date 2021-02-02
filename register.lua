
-- Load support for MT game translation.
local S = minetest.get_translator("doors")

local function do_not_move(node_name)
	if not (minetest.global_exists("mesecon") and mesecon.register_mvps_stopper) then return end
	mesecon.register_mvps_stopper(node_name)
end

local door_sizes = {}
local hidden_sizes = {}
local replacement_doors = {}

local function craft_size(s)
	if s == 1.5 then
		return 3, 2
	end
	return s, 1
end

local function numstr(num)
	return string.sub("00"..tostring(math.floor(num*10)),-2)
end

local function size_to_string(size)
	local width_string = numstr(size.width)
	local height_string = numstr(size.height)
	return width_string..height_string
end

local function string_to_size(str)
	return {
		height = tonumber(string.sub(str, -2))/10,
		width = tonumber(string.sub(str, 0, -3))/10,
	}
end

local function new_hitbox(size, rev)
	local normalbox = {-1/2,-1/2,-1/2,1/2,3/2,-6/16}
	normalbox[5] = normalbox[2]+size.height
	if rev then
		normalbox[1] = normalbox[4]-size.width
	else
		normalbox[4] = normalbox[1]+size.width
	end
	return normalbox
end

local max_width = 0


for _w,w in ipairs(bigdoors.door_widths) do
	if w >= 100 or w < 1 then
		local allowed = ", please set value "..tostring(_w).." of bigdoors.door_widths between 1 and 99 inclusive."
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
		for _h,h in ipairs(bigdoors.door_heights) do
			if h >= 100 or h < 1 then
				local allowed = ", please set value "..tostring(_h).." of bigdoors.door_heights between 1 and 99 inclusive."
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
				hidden_sizes[size_to_string(hidden_size)] = hidden_size
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
					ad=new_hitbox(size),
					bc=new_hitbox(size, true)
				}
				local size_string = size_to_string(size)
				door_sizes[size_string] = size
			end
		end
	end
end
local max_pair_distance = (max_width*2)-1

local param2_to_vector = {
	{x = -1, y = 0, z = 0},
	{x = 0, y = 0, z = 1},
	{x = 1, y = 0, z = 0},
	{x = 0, y = 0, z = -1},
}

local reverse_rotation = {
	[0]=20,23,22,21
}

local function doorientation(param2, dir_str)
	if dir_str == 'a' then
		return param2, 0
	end
	if dir_str == 'b' then
		return param2, 2
	end
	if dir_str == 'c' then
		return (param2-1)%4, 0
	end
	if dir_str == 'd' then
		return (param2+1)%4, 2
	end
end

local function parse_door_name(name)
	local sep = string.sub(name, -2,-2)
	if sep == '_' then -- mode & size
		local size_string = string.sub(name, -6, -3)
		local clean_name = string.sub(name, 0, -8)
		local mode = string.sub(name, -1)
		return {
			mode = mode,
			size_string = size_string,
			size = string_to_size(size_string),
			name = clean_name,
			closed = mode == 'a' or mode == 'b'
		}
	else -- just size
		local size_string = string.sub(name, -4)
		local clean_name = string.sub(name, 0, -6)
		return {
			mode = false,
			size_string = size_string,
			size = string_to_size(size_string),
			name = clean_name,
			closed = nil
		}
	end
end

local function parse_door(pos, node)
	if not node then
		node = minetest.get_node(pos)
	end
	local name_parse = parse_door_name(node.name)
	local dir, state = doorientation(node.param2, name_parse.mode)
	name_parse.dir = dir
	name_parse.state = state
	return name_parse
end

local function door_occupies(pos, door, pair_pos)
	-- TODO: cache for each size and then run through adding pos?

	-- Generate list of nodes this door will occupy, to be checked and blocked with hidden nodes
	local nextward = param2_to_vector[((door.dir+2+door.state)%4)+1]
	local behindward = param2_to_vector[((door.dir+1)%4)+1]
	local upward = {x=0,y=1,z=0}

	local check_nodes = {}
	local base_pos = table.copy(pos)
	local pair_closed = false
	local pair_height = 0
	if pair_pos and door.size.width ~= math.ceil(door.size.width) then
		local pair_name = parse_door_name(minetest.get_node(pair_pos).name)
		if pair_name.closed then
			pair_closed = true
			pair_height = pair_name.size.height
		end
	end
	for y=0,math.ceil(door.size.height)-1,1 do
		-- Check place it will be positioned
		if y ~= 0 then -- Ignore the fist one, already checked and has node
			table.insert(check_nodes, {
				pos=base_pos,
				dir="spine",
				edge=false
			})
		end
		local mx = math.ceil(door.size.width)-1
		for x=1,mx,1 do
			local edge = x==mx
			table.insert(check_nodes, {
				pos=vector.add(base_pos, nextward),
				dir="next",
				edge=edge,
				overlap=edge and pair_closed and y < pair_height
			})
		end
		-- Check place it will open into
		local mz = math.ceil(door.size.width)-1
		for z=1,mz,1 do
			table.insert(check_nodes, {
				pos=vector.add(base_pos, behindward),
				dir="back",
				edge=z==mz
			})
		end
		base_pos = vector.add(base_pos, upward)
	end

	return check_nodes
end

local function get_pair_pos(pos, pair)
	if not pair then
		local meta = minetest.get_meta(pos)
		pair = meta:get_string('pair')
	end
	if pair and pair ~= '' then
		return minetest.string_to_pos(pair)
	end
end

local function unpair(pos, pair)
	local pair_pos = get_pair_pos(pos, pair)
	if pair_pos then
		local pair_meta = minetest.get_meta(pair_pos)
		pair_meta:set_string('pair', nil)
		return pair_pos
	end
end

local function pairing_on_left (pos, door)
	local leftward = param2_to_vector[door.dir + 1]
	local left_side = pos
	local pair = nil
	for l=1,max_pair_distance,1 do
		left_side = vector.add(left_side, leftward)
		local left_node = minetest.get_node(left_side)
		local left_node_name = left_node.name
		local size_string = string.sub(left_node_name,-6,-3)
		if minetest.get_item_group(left_node_name, "door") == 1 and not string.match(size_string, "%D") then
			local dir_str = string.sub(left_node_name,-1)
			local pair_width = door.size.width + door_sizes[size_string].width
			if (
				(dir_str == 'a' and door.dir == left_node.param2)       -- If closed and same
			 or (dir_str == 'c' and (door.dir+1)%4 == left_node.param2) -- If open and same when closed
			)                     -- If normal door and same rotation, on the same plane (when closed)
			and pair_width == l+1 -- If doors match perfectly, filling the width
			then
				pair = left_side
			end
			break
		end
	end
	return pair
end

local function pairing_on_right (pos, door)
	local rightward = param2_to_vector[((door.dir + 2)%4)+1]
	local right_side = pos
	local pair = nil
	for r=1,max_pair_distance,1 do
		right_side = vector.add(right_side, rightward)
		local right_node = minetest.get_node(right_side)
		local right_node_name = right_node.name
		local size_string = string.sub(right_node_name,-6,-3)
		if minetest.get_item_group(right_node_name, "door") == 1 and not string.match(size_string, "%D") then
			local dir_str = string.sub(right_node_name,-1)
			local pair_width = door.size.width + door_sizes[size_string].width
			if (
				(dir_str == 'b' and door.dir == right_node.param2)       -- If closed and same
			 or (dir_str == 'd' and (door.dir-1)%4 == right_node.param2) -- If open and same when closed
			)                     -- If normal door and same rotation, on the same plane (when closed)
			and pair_width == r+1 -- If doors match perfectly, filling the width
			then
				pair = right_side
			end
			break
		end
	end
	return pair
end

local function swap_pair_edge(pos, door)
	local width = 1-(door.size.width%1)

	local size_str = size_to_string({ width=width, height=1 })

	local param2 = door.dir
	if door.state == 0 then
		param2 = reverse_rotation[param2]
	end
	minetest.set_node(pos, {
		name = bigdoors.modname..":hidden_section_"..size_str,
		param2 = param2
	})
end


local function swap_nodes(check_nodes, door, open)
	-- local check_nodes = door_occupies(pos, dir, state, size, pair_pos)

	local hidden_param2 = door.dir
	if door.state == 2 then
		hidden_param2 = (door.dir + 3) % 4
	end

	if open then
		for _,check_node in ipairs(check_nodes) do
			if check_node.dir == 'next' then
				if check_node.overlap then
					swap_pair_edge(check_node.pos, door)
				else
					minetest.set_node(check_node.pos, {
						name = bigdoors.modname..":hidden",
						param2 = hidden_param2
					})
				end
			else
				local width = 1
				if check_node.edge then
					local remainder = door.size.width%1
					if remainder ~= 0 then
						width = remainder
					end
				end
				local size_str = size_to_string({ width=width, height=1})

				local param2 = (door.dir + 1 + door.state) % 4
				if door.state == 0 then
					param2 = reverse_rotation[param2]
				end
				minetest.set_node(check_node.pos, {
					name = bigdoors.modname..":hidden_section_"..size_str,
					param2 = param2
				})
			end
		end
	else
		for _,check_node in ipairs(check_nodes) do
			if check_node.dir == 'back' then
				minetest.set_node(check_node.pos, {
					name = bigdoors.modname..":hidden",
					param2 = hidden_param2
				})
			else
				local width = 1
				if check_node.edge and not check_node.overlap then
					local remainder = door.size.width%1
					if remainder ~= 0 then
						width = remainder
					end
				end
				local size_str = size_to_string({ width=width, height=1})

				local param2 = door.dir
				if door.state == 2 then
					param2 = reverse_rotation[param2]
				end
				minetest.set_node(check_node.pos, {
					name = bigdoors.modname..":hidden_section_"..size_str,
					param2 = param2
				})
			end
		end
	end
end

local function remove_door_surroundings(pos, pair_pos, node)
	local door = parse_door(pos, node)
	local check_nodes = door_occupies(pos, door, pair_pos)
	local top_nodes = {}
	for _,check_pos in ipairs(check_nodes) do
		if check_pos.pos.y == pos.y+door.size.height-1 then
			table.insert(top_nodes, check_pos)
		end
		if check_pos.overlap then
			swap_pair_edge(check_pos.pos, door)
		else
			minetest.remove_node(check_pos.pos)
		end
	end
	for _,top_pos in ipairs(top_nodes) do
		minetest.check_for_falling(top_pos.pos)
	end
end

local function on_rightclick(pos, node, clicker, itemstack, pointed_thing)
	-- Toggle door open/close on right click

	local toggled = doors.door_toggle(pos, node, clicker)
	if not toggled then
		return itemstack
	end

	local door = parse_door(pos, node)

	local pair_pos = get_pair_pos(pos)
	local nodes = door_occupies(pos, door, pair_pos)

	swap_nodes(nodes, door, door.closed)

	return itemstack
end

local function after_dig_node (pos, node, meta, digger)
	local pair_pos = unpair(pos, meta.fields.pair)

	remove_door_surroundings(pos, pair_pos, node)
end

local function on_blast_unprotected (pos, intensity)
	local pair_pos = unpair(pos)

	local node = minetest.get_node(pos)
	remove_door_surroundings(pos, pair_pos, node)
	minetest.remove_node(pos)
	return {node.name}
end

local function on_destruct (pos)
	local pair_pos = unpair(pos)

	remove_door_surroundings(pos, pair_pos)
end

local function on_place_node (place_to, newnode,
	placer, oldnode, itemstack, pointed_thing)
	-- Run script hook
	for _, callback in ipairs(minetest.registered_on_placenodes) do
		-- Deepcopy pos, node and pointed_thing because callback can modify them
		local place_to_copy = {x = place_to.x, y = place_to.y, z = place_to.z}
		local newnode_copy =
			{name = newnode.name, param1 = newnode.param1, param2 = newnode.param2}
		local oldnode_copy =
			{name = oldnode.name, param1 = oldnode.param1, param2 = oldnode.param2}
		local pointed_thing_copy = {
			type  = pointed_thing.type,
			above = vector.new(pointed_thing.above),
			under = vector.new(pointed_thing.under),
			ref   = pointed_thing.ref,
		}
		callback(place_to_copy, newnode_copy, placer,
			oldnode_copy, itemstack, pointed_thing_copy)
	end
end

local function on_place (itemstack, placer, pointed_thing)
	-- Find pos, unaffected, same as original
	local pos

	if not pointed_thing.type == "node" then
		return itemstack
	end

	local node = minetest.get_node(pointed_thing.under)
	local pdef = minetest.registered_nodes[node.name]
	if pdef and pdef.on_rightclick and
			not (placer and placer:is_player() and
			placer:get_player_control().sneak) then
		return pdef.on_rightclick(pointed_thing.under,
				node, placer, itemstack, pointed_thing)
	end

	if pdef and pdef.buildable_to then
		pos = pointed_thing.under
	else
		pos = pointed_thing.above
		node = minetest.get_node(pos)
		pdef = minetest.registered_nodes[node.name]
		if not pdef or not pdef.buildable_to then
			return itemstack
		end
	end

	local player_name = placer and placer:get_player_name() or ""
	if minetest.is_protected(pos, player_name) then
		return itemstack
	end


	local name = itemstack:get_name()
	if replacement_doors[name] then
		name = replacement_doors[name]
	end
	local door = parse_door_name(name)
	door.dir = placer and minetest.dir_to_facedir(placer:get_look_dir()) or 0


	-- Flip the door if we find a matching one to the left
	local pair = pairing_on_left(pos, door)
	door.state = 0
	if pair then
		door.state = 2
	else
		pair = pairing_on_right(pos, door)
	end

	local check_nodes = door_occupies(pos, door, pair)

	-- Check surroundings for validity of placement
	for _,check_pos in ipairs(check_nodes) do
		if not check_pos.overlap then
			local check_node = minetest.get_node_or_nil(check_pos.pos)
			local check_def = check_node and minetest.registered_nodes[check_node.name]

			if not check_def or not check_def.buildable_to then
				return itemstack
			end

			if minetest.is_protected(check_pos, player_name) then
				return itemstack
			end
		end
	end

	-- Create node
	local dir_name
	if door.state == 2 then
		dir_name = name .. "_b"
	else
		dir_name = name .. "_a"
	end
	minetest.set_node(pos, {name = dir_name, param2 = door.dir})

	-- Set metadata
	local meta = minetest.get_meta(pos)
	meta:set_int("state", door.state)
	if pair then
		local pair_pos = minetest.pos_to_string(pair)
		local this_pos = minetest.pos_to_string(pos)

		meta:set_string("pair", pair_pos)
		local pair_meta = minetest.get_meta(pair)
		pair_meta:set_string("pair", this_pos)
	end

	-- Create hidden nodes to prevent obstructing placement
	swap_nodes(check_nodes, door, false)

	local def = minetest.registered_nodes[dir_name]
	-- Other stuffs, unaffected, same as original
	if def.protected then
		meta:set_string("owner", player_name)
		meta:set_string("infotext", def.description .. "\n" .. S("Owned by @1", player_name))
	end

	if not (creative and creative.is_enabled_for and creative.is_enabled_for(player_name)) then
		itemstack:take_item()
	end

	minetest.sound_play(def.sounds.place, {pos = pos}, true)

	on_place_node(pos, minetest.get_node(pos),
		placer, node, itemstack, pointed_thing)

	return itemstack
end


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

if bigdoors.debug_hidden_nodes then
	local s = 0.3
	hidden_def.selection_box = {type = "fixed", fixed = {-s,-s,-s,s,s,s}}
	hidden_def.tiles = {{ name = "bigdoors_debug.png" }}
	hidden_def.groups = {}
	hidden_def.pointable = true
	hidden_def.drawtype = 'glasslike'
end

minetest.register_node(bigdoors.modname..":hidden", hidden_def) -- doors:hidden has a hitbox, no thanks
do_not_move(bigdoors.modname..":hidden")

local function hidden_section(size)
	-- Create hidden sections for hit-box purposes
	local size_string = size_to_string(size)
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
			fixed = new_hitbox(size)
		}
	}

	if bigdoors.debug_hidden_nodes then
		local debug_select = new_hitbox(size)
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
	do_not_move(name)
end

for _,hidden_size in pairs(hidden_sizes) do
	hidden_section(hidden_size)
end


-- REGISTER NEW DOOR


function by_value( t1 )
	local t2 = { }
	if #t1 > 0 then
		-- ordered copy of arrays
		t2 = { unpack( t1 ) }
	else
		-- shallow copy of hashes
		for k, v in pairs( t1 ) do
			t2[ k ] = v
		end
	end
	return t2
end


function new_recipe(size, item)
	local recipe = {}
	local recipe_row = {}
	for i=1,size.width,1 do
		table.insert(recipe_row, item)
	end
	for i=1,size.height,1 do
		table.insert(recipe, recipe_row)
	end
	return recipe
end

function user_size_to_sys(sizes)
	if not sizes then return end
	local sys_sizes = {}
	for _,size in ipairs(sizes) do
		table.insert(sys_sizes, math.floor(size*10))
	end
	return sys_sizes
end

function size_variations(variations)
	local valid_sizes = {}

	-- Generate list of all width-height combinations
	local whcombos = {}
	local heights = user_size_to_sys(variations.heights) or bigdoors.door_heights
	local widths = user_size_to_sys(variations.widths) or bigdoors.door_widths
	for _,h in ipairs(heights) do
		for _,w in ipairs(widths) do
			local size = {width=w/10,height=h/10}
			local size_string = size_to_string(size)
			whcombos[size_string] = size
		end
	end

	-- Use only those defined in sizes
	local sizecombos = {}
	if variations.sizes then
		for _,size in ipairs(variations.sizes) do
			local size_string = size_to_string(size)
			if whcombos[size_string] then
				sizecombos[size_string] = size
			end
		end
	else
		sizecombos = whcombos
	end

	-- Use only those that maintain proportions
	local propcombos = {}
	if variations.original_proportions then
		for size_string,size in pairs(sizecombos) do
			if math.abs((size.width*2)-size.height) < 0.1 then
				propcombos[size_string] = size
			end
		end
	else
		propcombos = sizecombos
	end

	-- Use only existing size combinations
	for size_string,_ in pairs(propcombos) do
		if door_sizes[size_string] then
			valid_sizes[size_string] = door_sizes[size_string]
		end
	end
	return valid_sizes
end

function bigdoors.register(originalname, config)

	local basedef = minetest.registered_nodes[originalname..'_a']
	local baseitem = minetest.registered_craftitems[originalname]
	
	if not config then
		config = {}
	end

	if config.replace_original and not config.original_recipe then
		minetest.log("error", "BigDoors: Cannot replace original door ("..originalname..") if original_recipe is not defined. (Recipes cannot be retrieved from the minetest API)")
		return
	end

	local base_name = originalname
	if config.name then
		base_name = config.name
	end
	if not base_name:find(":") then
		base_name = bigdoors.modname..":" .. base_name
	end

	local base_size_string = "1020"
	local bigdoor_base_name = base_name.."_"..base_size_string

	local recipe_name = originalname
	if config.replace_original then
		recipe_name = bigdoor_base_name
	end
	if config.replace_original then
		replacement_doors[originalname] = bigdoor_base_name
	end

	local valid_sizes = door_sizes
	if config.variations then
		valid_sizes = size_variations(config.variations)
	end

	if config.replace_original and not valid_sizes[base_size_string] then
		minetest.log("error", "BigDoors: Cannot replace original door ("..originalname..") if 1x2 size variation is disallowed")
		return
	end

	for size_string, size in pairs(valid_sizes) do

		-- Name
		local name = base_name..'_'..size_string

		-- Create item
		minetest.register_craftitem(":" .. name, {
			description = baseitem.description .. ' (' .. tostring(size.width) .. ' x ' .. tostring(size.height) .. ')',
			inventory_image = baseitem.inventory_image,
			groups = table.copy(baseitem.groups),
			on_place = on_place
		})

		-- Use recipe to create crafts
		if size_string == base_size_string and config.replace_original then
			minetest.register_craft({
				output = name,
				recipe = config.original_recipe,
			})
		elseif config.recipe then
			-- TODO: multiple recipes for each size?
			local recipe = config.recipe[size_string]
			if recipe then
				local output = name
				if recipe.output then
					output = output..' '..tostring(recipe.output)
				end
				local recipe_obj = recipe
				if recipe.recipe then
					recipe_obj = recipe.recipe
				end
				minetest.register_craft({
					output = output,
					recipe = recipe_obj,
				})
			end
		else
			-- TODO: more complex crafts for breaking apart & making from other components? e.g. (1x3)+(1x3)=(2x3)
			minetest.register_craft({
				output = name..' '..tostring(size.recipe.output),
				recipe = new_recipe(size.recipe, recipe_name),
			})
			if not (config.replace_original or size_string == base_size_string) then
				minetest.register_craft({
					output = name..' '..tostring(size.recipe.output),
					recipe = new_recipe(size.recipe, bigdoor_base_name),
				})
			end
		end

		local def = table.copy(basedef)
		def.drop = name
		def.door.name = name


		-- Callbacks
		def.on_rightclick = on_rightclick

		def.after_dig_node = after_dig_node
		def.on_destruct = on_destruct
		if not def.protected then
			def.on_blast = on_blast_unprotected
		end

		-- Model and hitbox

		-- TODO: replace by_value
		local defa = by_value(def)
		local defb = by_value(def)
		local defc = by_value(def)
		local defd = by_value(def)

		defa.selection_box = {type = "fixed", fixed = size.hitbox.ad}
		defb.selection_box = {type = "fixed", fixed = size.hitbox.bc}
		defc.selection_box = {type = "fixed", fixed = size.hitbox.bc}
		defd.selection_box = {type = "fixed", fixed = size.hitbox.ad}

		defa.mesh = "bigdoor_a"..size_string..".obj"
		defb.mesh = "bigdoor_b"..size_string..".obj"
		defc.mesh = "bigdoor_c"..size_string..".obj"
		defd.mesh = "bigdoor_d"..size_string..".obj"

		-- Register nodes
		minetest.register_node(":" .. name .. "_a", defa)
		minetest.register_node(":" .. name .. "_b", defb)
		minetest.register_node(":" .. name .. "_c", defc)
		minetest.register_node(":" .. name .. "_d", defd)

		doors.registered_doors[name .. "_a"] = true
		doors.registered_doors[name .. "_b"] = true
		doors.registered_doors[name .. "_c"] = true
		doors.registered_doors[name .. "_d"] = true
		
		do_not_move(":" .. name .. "_a")
		do_not_move(":" .. name .. "_b")
		do_not_move(":" .. name .. "_c")
		do_not_move(":" .. name .. "_d")
	end

	if config.replace_original then
		-- disable original items
		minetest.registered_craftitems[originalname] = table.copy(minetest.registered_craftitems[bigdoor_base_name])
		minetest.registered_items[originalname] = table.copy(minetest.registered_items[bigdoor_base_name])
		minetest.registered_craftitems[originalname].groups.not_in_creative_inventory = 1
		minetest.registered_items[originalname].groups.not_in_creative_inventory = 1
		-- replace old doors of this type automatically
		minetest.register_lbm({
			name = ":"..bigdoors.modname..":replace_" .. originalname:gsub(":", "_"),
			nodenames = {originalname.."_a", originalname.."_b", originalname.."_c", originalname.."_d"},
			action = function(new_pos, node)
				local new_door = bigdoor_base_name..string.sub(node.name,-2)
				local new_node = {name = new_door, param2 = node.param2}
				minetest.swap_node(new_pos, new_node)
				local door = parse_door(nil, new_node)
				local check_nodes = door_occupies(new_pos, door)
				swap_nodes(check_nodes, door, not door.closed)
			end
		})
	end

end

