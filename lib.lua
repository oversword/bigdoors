
-- Load support for MT game translation.
local S = minetest.get_translator("doors")

local param2_to_vector = {
	{x = -1, y = 0, z = 0},
	{x = 0, y = 0, z = 1},
	{x = 1, y = 0, z = 0},
	{x = 0, y = 0, z = -1},
}

local reverse_rotation = {
	[0]=20,23,22,21
}

local function do_not_move(node_name)
	if not (minetest.global_exists("mesecon") and mesecon.register_mvps_stopper) then return end
	mesecon.register_mvps_stopper(node_name)
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
	for l=1,bigdoors.data.max_pair_distance,1 do
		left_side = vector.add(left_side, leftward)
		local left_node = minetest.get_node(left_side)
		local left_node_name = left_node.name
		local size_string = string.sub(left_node_name,-6,-3)
		if minetest.get_item_group(left_node_name, "door") == 1 and not string.match(size_string, "%D") then
			local dir_str = string.sub(left_node_name,-1)
			local pair_width = door.size.width + bigdoors.data.door_sizes[size_string].width
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
	for r=1,bigdoors.data.max_pair_distance,1 do
		right_side = vector.add(right_side, rightward)
		local right_node = minetest.get_node(right_side)
		local right_node_name = right_node.name
		local size_string = string.sub(right_node_name,-6,-3)
		if minetest.get_item_group(right_node_name, "door") == 1 and not string.match(size_string, "%D") then
			local dir_str = string.sub(right_node_name,-1)
			local pair_width = door.size.width + bigdoors.data.door_sizes[size_string].width
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


-- Callbacks / Actions

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

local function mesecon_toggle(pos,node,signal_pos)
	on_rightclick(pos,node)
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
	if bigdoors.data.replacement_doors[name] then
		name = bigdoors.data.replacement_doors[name]
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
				local dir = "around"
				if check_pos.dir == "next" then
					dir = "beside"
				elseif check_pos.dir == "back" then
					dir = "behind"
				elseif check_pos.dir == "spine" then
					dir = "above"
				end
				bigdoors.notify(placer, "Door cannot be placed here\nMake sure there is room "..dir.." this position")
				return itemstack
			end

			if minetest.is_protected(check_pos, player_name) then
				local dir = "around"
				if check_pos.dir == "next" then
					dir = "beside"
				elseif check_pos.dir == "back" then
					dir = "behind"
				elseif check_pos.dir == "spine" then
					dir = "above"
				end
				bigdoors.notify(placer, "Door cannot be placed here\nThe area "..dir.." the door is protected")
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



-- Register Helpers

local function new_recipe(size, item)
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

local function user_size_to_sys(sizes)
	if not sizes then return end
	local sys_sizes = {}
	for _,size in ipairs(sizes) do
		table.insert(sys_sizes, math.floor(size*10))
	end
	return sys_sizes
end

local function size_variations(variations)
	if not variations then return bigdoors.data.door_sizes end
	local valid_sizes = {}

	-- Generate list of all width-height combinations
	local whcombos = {}
	local heights = user_size_to_sys(variations.heights) or bigdoors.config.door_heights
	local widths = user_size_to_sys(variations.widths) or bigdoors.config.door_widths
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
		if bigdoors.data.door_sizes[size_string] then
			valid_sizes[size_string] = bigdoors.data.door_sizes[size_string]
		end
	end
	return valid_sizes
end



bigdoors.actions = {
	on_rightclick = on_rightclick,
	mesecon_toggle = mesecon_toggle,
	after_dig_node = after_dig_node,
	on_blast_unprotected = on_blast_unprotected,
	on_destruct = on_destruct,
	on_place = on_place
}

bigdoors.api = {
	do_not_move = do_not_move,
	size_to_string = size_to_string,
	string_to_size = string_to_size,
	new_hitbox = new_hitbox,
	size_variations = size_variations,
	new_recipe = new_recipe
}