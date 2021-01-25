
-- Load support for MT game translation.
local S = minetest.get_translator("doors")

local bigdoors = {}

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

local function on_place_node(place_to, newnode,
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


local function can_dig_door(pos, digger)
	replace_old_owner_information(pos)
	return default.can_interact_with_node(digger, pos)
end

local door_widths = {10,15,20}
local door_heights = {20,30,40}
local door_sizes = {}

local function craft_size(s)
	if s == 1.5 then
		return 3, 2
	end
	return s, 1
end
for _,w in ipairs(door_widths) do
	local width_string = tostring(w)
	for _,h in ipairs(door_heights) do
		local height_string = tostring(h)
		local size_string = width_string..height_string
		local wr, mw = craft_size(w/10)
		local hr, mh = craft_size(h/20)
		door_sizes[size_string] = {
			width = w/10,
			height = h/10,
			recipe = {width=wr,height=hr,output = mw*mh},
		}
	end
end

local param2_to_vector = {
	{x = -1, y = 0, z = 0},
	{x = 0, y = 0, z = 1},
	{x = 1, y = 0, z = 0},
	{x = 0, y = 0, z = -1},
}

local function door_occupies(pos, dir, state, size, pair_pos)
	-- Generate list of nodes this door will occupy, to be checked and blocked with hidden nodes
	local nextward = param2_to_vector[((dir+2+state)%4)+1]
	local behindward = param2_to_vector[((dir+1)%4)+1]
	local upward = {x=0,y=1,z=0}

	local check_nodes = {}
	local base_pos = table.copy(pos)
	local pair_adjust = 0
	if pair_pos and size.width ~= math.ceil(size.width) then
		pair_adjust = 1
	end
	for y=0,math.ceil(size.height)-1,1 do
		-- Check place it will be positioned
		if y ~= 0 then -- Ignore the fist one, already checked and has node
			table.insert(check_nodes, base_pos)
		end
		for x=1,math.ceil(size.width-pair_adjust)-1,1 do
			table.insert(check_nodes, vector.add(base_pos, nextward))
		end
		-- Check place it will open into
		for z=1,math.ceil(size.width)-1,1 do
			table.insert(check_nodes, vector.add(base_pos, behindward))
		end
		base_pos = vector.add(base_pos, upward)
	end

	return check_nodes
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

local function remove_door_surroundings(pos, size, pair_pos, node)
	if not node then
		node = minetest.get_node(pos)
	end
	local dir_str = string.sub(node.name,-1)
	local dir, state = doorientation(node.param2, dir_str)
	local check_nodes = door_occupies(pos, dir, state, size, pair_pos)
	local top_nodes = {}
	for _,check_pos in ipairs(check_nodes) do
		if check_pos.y == pos.y+size.height-1 then
			table.insert(top_nodes, check_pos)
		end
		minetest.remove_node(check_pos)
	end
	for _,top_pos in ipairs(top_nodes) do
		minetest.check_for_falling(top_pos)
	end
end



local function on_rightclick(pos, node, clicker, itemstack, pointed_thing)
	-- Toggle door open/close on right click
	doors.door_toggle(pos, node, clicker)
	return itemstack
end

local function on_rotate(pos, node, user, mode, new_param2)
	-- Deny rotation
	return false
end

-- TODO: determine size from name
local function after_dig_node_size (size)
	return function (pos, node, meta, digger)
		local pair = meta.fields.pair
		local pair_pos
		if pair then
			pair_pos = minetest.string_to_pos(pair)
			local pair_meta = minetest.get_meta(pair_pos)
			pair_meta:set_string('pair', nil)
		end
		remove_door_surroundings(pos, size, pair_pos, node)
	end
end

local function on_blast_unprotected_size (size)
	return function(pos, intensity)
		local meta = minetest.get_meta(pos)
		local node = minetest.get_node(pos)
		local pair = meta:get_string('pair')
		local pair_pos
		if pair and pair ~= '' then
			pair_pos = minetest.string_to_pos(pair)
			local pair_meta = minetest.get_meta(pair_pos)
			pair_meta:set_string('pair', nil)
		end
		remove_door_surroundings(pos, size, pair_pos, node)
		minetest.remove_node(pos)
		return {node.name}
	end
end
local function on_blast_protected() end

local function on_destruct_size (size)
	return function(pos)
		local meta = minetest.get_meta(pos)
		local pair = meta:get_string('pair')
		local pair_pos
		if pair and pair ~= '' then
			pair_pos = minetest.string_to_pos(pair)
			local pair_meta = minetest.get_meta(pair_pos)
			pair_meta:set_string('pair', nil)
		end
		remove_door_surroundings(pos, size, pair_pos)
	end
end

local function on_key_use(pos, player)
	local door = doors.get(pos)
	door:toggle(player)
end
local function on_skeleton_key_use(pos, player, newsecret)
	replace_old_owner_information(pos)
	local meta = minetest.get_meta(pos)
	local owner = meta:get_string("owner")
	local pname = player:get_player_name()

	-- verify placer is owner of lockable door
	if owner ~= pname then
		minetest.record_protection_violation(pos, pname)
		minetest.chat_send_player(pname, S("You do not own this locked door."))
		return nil
	end

	local secret = meta:get_string("key_lock_secret")
	if secret == "" then
		secret = newsecret
		meta:set_string("key_lock_secret", secret)
	end

	return secret, S("a locked door"), owner
end

local function on_place_size(name, size, def)
	return function (itemstack, placer, pointed_thing)
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

		local dir = placer and minetest.dir_to_facedir(placer:get_look_dir()) or 0


		-- Flip the door if we find a matching one to the left

		local leftward = param2_to_vector[dir + 1]
		local left_side = pos
		local state = 0
		local pair = nil
		for l=1,3,1 do -- TODO: find limit from available range, not hardcoded (replace 3 with (max_width*2)-1)
			left_side = vector.add(left_side, leftward)
			local left_node = minetest.get_node(left_side)
			local left_node_name = left_node.name
			if minetest.get_item_group(left_node_name, "door") == 1 then
				local dir_str = string.sub(left_node_name,-1)
				local pair_width = size.width + door_sizes[string.sub(left_node_name,-6,-3)].width
				if (
					(dir_str == 'a' and dir == left_node.param2)       -- If closed and same
				 or (dir_str == 'c' and (dir+1)%4 == left_node.param2) -- If open and same when closed
				)                     -- If normal door and same rotation, on the same plane (when closed)
				and pair_width == l+1 -- If doors match perfectly, filling the width
				then
					state = 2
					pair = left_side
				end
				break
			end
		end

		if not pair then
			local rightward = param2_to_vector[((dir + 2)%4)+1]
			local right_side = pos
			for r=1,3,1 do -- TODO: find limit from available range, not hardcoded (replace 3 with (max_width*2)-1)
				right_side = vector.add(right_side, rightward)
				local right_node = minetest.get_node(right_side)
				local right_node_name = right_node.name
				if minetest.get_item_group(right_node_name, "door") == 1 then
					local dir_str = string.sub(right_node_name,-1)
					local pair_width = size.width + door_sizes[string.sub(right_node_name,-6,-3)].width
					if (
						(dir_str == 'b' and dir == right_node.param2)       -- If closed and same
					 or (dir_str == 'd' and (dir-1)%4 == right_node.param2) -- If open and same when closed
					)                     -- If normal door and same rotation, on the same plane (when closed)
					and pair_width == r+1 -- If doors match perfectly, filling the width
					then
						pair = right_side
					end
					break
				end
			end
		end

		local check_nodes = door_occupies(pos, dir, state, size, pair)

		-- Check surroundings for validity of placement

		for _,check_pos in ipairs(check_nodes) do
			local check_node = minetest.get_node_or_nil(check_pos)
			local check_def = check_node and minetest.registered_nodes[check_node.name]

			-- If this and that are halfers, allow ends to overlap

			if not check_def or not check_def.buildable_to then
				return itemstack
			end

			if minetest.is_protected(check_pos, player_name) then
				return itemstack
			end
		end


		-- Create node

		if state == 2 then
			minetest.set_node(pos, {name = name .. "_b", param2 = dir})
		else
			minetest.set_node(pos, {name = name .. "_a", param2 = dir})
		end

		-- Set metadata
		local meta = minetest.get_meta(pos)
		meta:set_int("state", state)
		if pair then
			local pair_pos = minetest.pos_to_string(pair)
			local this_pos = minetest.pos_to_string(pos)

			meta:set_string("pair", pair_pos)
			local pair_meta = minetest.get_meta(pair)
			pair_meta:set_string("pair", this_pos)
		end


		-- Create hidden nodes to prevent obstructing placement

		local hidden_param2 = dir
		if state == 2 then
			hidden_param2 = (dir + 3) % 4
		end

		for _,check_pos in ipairs(check_nodes) do
			minetest.set_node(check_pos, {name = "doors:hidden", param2 = hidden_param2})
		end


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
end

function bigdoors.register(basename, basedef)
	if not basename:find(":") then
		basename = "bigdoors:" .. basename
	end

	basedef.drawtype = "mesh"
	basedef.paramtype = "light"
	basedef.paramtype2 = "facedir"
	basedef.sunlight_propagates = true
	basedef.walkable = true
	basedef.is_ground_content = false
	basedef.buildable_to = false
	basedef.groups.not_in_creative_inventory = 1
	basedef.groups.door = 1


	if not basedef.sounds then
		basedef.sounds = default.node_sound_wood_defaults()
	end
	if not basedef.sound_open then
		basedef.sound_open = "doors_door_open"
	end
	if not basedef.sound_close then
		basedef.sound_close = "doors_door_close"
	end
	basedef.door = {
		sounds = { basedef.sound_close, basedef.sound_open },
	}

	if not basedef.on_rightclick then
		basedef.on_rightclick = on_rightclick
	end
	basedef.on_rotate = on_rotate



	for size_string, size in pairs(door_sizes) do

		local def = table.copy(basedef)
		-- Name
		local name = basename..size_string
		def.drop = name
		def.door.name = name

		-- Use inventory image for item, and remove from def
		minetest.register_craftitem(":" .. name, {
			description = def.description .. ' (' .. tostring(size.width) .. ' x ' .. tostring(size.height) .. ')',
			inventory_image = def.inventory_image,
			groups = table.copy(def.groups),
			on_place = on_place
		})
		def.inventory_image = nil

		-- Use recipe to create crafts, and remove from def
		if def.recipe then

			local recipe = {}
			local recipe_row = {}
			for i=1,size.recipe.width,1 do
				table.insert(recipe_row, def.recipe)
			end
			for i=1,size.recipe.height,1 do
				table.insert(recipe, recipe_row)
			end
			minetest.register_craft({
				output = name..' '..tostring(size.recipe.output),
				recipe = recipe,
			})
		end
		def.recipe = nil

		-- Callbacks
		local after_dig_node = after_dig_node_size(size)
		local on_blast_unprotected = on_blast_unprotected_size(size)
		local on_destruct = on_destruct_size(size)
		local on_place = on_place_size(name, size, def)

		def.after_dig_node = after_dig_node
		def.on_destruct = on_destruct

		if def.protected then
			def.can_dig = can_dig_door
			def.on_blast = on_blast_protected
			def.on_key_use = on_key_use
			def.on_skeleton_key_use = on_skeleton_key_use
			def.node_dig_prediction = ""
		else
			def.on_blast = on_blast_unprotected
		end


		-- Model and hitbox

		local normalbox = {-1/2,-1/2,-1/2,1/2,3/2,-6/16}
		normalbox[5] = normalbox[2]+size.height
		local defa = by_value(def)
		local defb = by_value(def)
		local defc = by_value(def)
		local defd = by_value(def)

		local adbox = by_value(normalbox)
		local bcbox = by_value(normalbox)

		adbox[4] = adbox[1]+size.width
		bcbox[1] = bcbox[4]-size.width

		defa.selection_box = {type = "fixed", fixed = adbox}
		defa.collision_box = {type = "fixed", fixed = adbox}

		defb.selection_box = {type = "fixed", fixed = bcbox}
		defb.collision_box = {type = "fixed", fixed = bcbox}

		defc.selection_box = {type = "fixed", fixed = bcbox}
		defc.collision_box = {type = "fixed", fixed = bcbox}

		defd.selection_box = {type = "fixed", fixed = adbox}
		defd.collision_box = {type = "fixed", fixed = adbox}

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
	end
end



if minetest.get_modpath("doors") ~= nil then
	bigdoors.register("big_door_test", {
			tiles = {{ name = "doors_door_wood.png", backface_culling = true }},
			description = S("Big Door Test"),
			inventory_image = "doors_item_wood.png",
			groups = {node = 1, choppy = 2, oddly_breakable_by_hand = 2, flammable = 2},
			recipe = "doors:door_wood",
	})
end