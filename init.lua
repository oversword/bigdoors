
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

for _,w in ipairs(door_widths) do
	for _,h in ipairs(door_heights) do
		local wr, mw = craft_size(w/10)
		local hr, mh = craft_size(h/20)
		local size = {
			width = w/10,
			height = h/10,
			recipe = {
				width = wr,
				height = hr,
				output = mw*mh
			}
		}
		local size_string = size_to_string(size)
		door_sizes[size_string] = size
	end
end

local param2_to_vector = {
	{x = -1, y = 0, z = 0},
	{x = 0, y = 0, z = 1},
	{x = 1, y = 0, z = 0},
	{x = 0, y = 0, z = -1},
}

local reverse_rotation = {
	[0]=20,23,22,21
}

local function parse_door_name(name)
	local sep = string.sub(name, -2,-2)
	if sep == '_' then -- mode & size
		local size_string = string.sub(name, -6, -3)
		return {
			mode = string.sub(name, -1),
			size_string = size_string,
			size = string_to_size(size_string),
			name = string.sub(name, 0, -8)
		}
	else -- just size
		local size_string = string.sub(name, -4)
		return {
			mode = false,
			size_string = size_string,
			size = string_to_size(size_string),
			name = string.sub(name, 0, -6)
		}
	end
	-- minetest.log("error", )
end

local function door_occupies(pos, dir, state, size, pair_pos)
	-- Generate list of nodes this door will occupy, to be checked and blocked with hidden nodes
	local nextward = param2_to_vector[((dir+2+state)%4)+1]
	local behindward = param2_to_vector[((dir+1)%4)+1]
	local upward = {x=0,y=1,z=0}

	local check_nodes = {}
	local base_pos = table.copy(pos)
	local pair_closed = false
	local pair_height = 0
	if pair_pos and size.width ~= math.ceil(size.width) then
		local pair_name = parse_door_name(minetest.get_node(pair_pos).name)
		if pair_name.mode == 'a' or pair_name.mode == 'b' then
			pair_closed = true
			pair_height = pair_name.size.height
		end
	end
	for y=0,math.ceil(size.height)-1,1 do
		-- Check place it will be positioned
		if y ~= 0 then -- Ignore the fist one, already checked and has node
			table.insert(check_nodes, {pos=base_pos,dir="spine",edge=false})
		end
		local mx = math.ceil(size.width)-1
		for x=1,mx,1 do
			local edge = x==mx
			table.insert(check_nodes, {pos=vector.add(base_pos, nextward),dir="next",edge=edge,overlap=edge and pair_closed and y < pair_height})
		end
		-- Check place it will open into
		local mz = math.ceil(size.width)-1
		for z=1,mz,1 do
			table.insert(check_nodes, {pos=vector.add(base_pos, behindward),dir="back",edge=z==mz})
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
		if check_pos.pos.y == pos.y+size.height-1 then
			table.insert(top_nodes, check_pos)
		end
		if check_pos.overlap then
			local width = 1-(size.width%1)

			local size_str = size_to_string({ width=width, height=1})

			local param2 = dir % 4
			if state == 0 then
				param2 = reverse_rotation[param2]
			end
			minetest.set_node(check_pos.pos, {
				name = "bigdoors:hidden_section_"..size_str,
				param2 = param2
			})
		else
			minetest.remove_node(check_pos.pos)
		end
	end
	for _,top_pos in ipairs(top_nodes) do
		minetest.check_for_falling(top_pos.pos)
	end
end



local function on_rightclick_size(size)
	return function (pos, node, clicker, itemstack, pointed_thing)
		-- Toggle door open/close on right click

		local toggled = doors.door_toggle(pos, node, clicker)
		if not toggled then
			return itemstack
		end

		local last_char = string.sub(node.name,-1)
		local opening = last_char == 'a' or last_char == 'b'

		local dir, state = doorientation(node.param2, last_char)
		local meta = minetest.get_meta(pos)
		local pair = meta:get_string('pair')
		local pair_pos
		if pair and pair ~= '' then
			pair_pos = minetest.string_to_pos(pair)
		end
		local nodes = door_occupies(pos, dir, state, size, pair_pos)

		local hidden_param2 = dir
		if state == 2 then
			hidden_param2 = (dir + 3) % 4
		end
		if opening then
			for _,check_node in ipairs(nodes) do
				if check_node.dir == 'next' then
					if check_node.overlap then
						local width = 1-(size.width%1)

						local size_str = size_to_string({ width=width, height=1})

						local param2 = dir % 4
						if state == 0 then
							param2 = reverse_rotation[param2]
						end
						minetest.set_node(check_node.pos, {
							name = "bigdoors:hidden_section_"..size_str,
							param2 = param2
						})

					else
						minetest.set_node(check_node.pos, {
							name = "bigdoors:hidden",
							param2 = hidden_param2
						})
					end
				else
					local width = 1
					if check_node.edge then
						width = size.width%1
					end
					local size_str = size_to_string({ width=width, height=1})

					local param2 = (dir + 1 + state) % 4
					if state == 0 then
						param2 = reverse_rotation[param2]
					end
					minetest.set_node(check_node.pos, {
						name = "bigdoors:hidden_section_"..size_str,
						param2 = param2
					})
				end
			end
		else
			for _,check_node in ipairs(nodes) do
				if check_node.dir == 'back' then
					minetest.set_node(check_node.pos, {
						name = "bigdoors:hidden",
						param2 = hidden_param2
					})
				else
					local width = 1
					if check_node.edge and not check_node.overlap then
						width = size.width%1
					end
					local size_str = size_to_string({ width=width, height=1})

					local param2 = dir
					if state == 2 then
						param2 = reverse_rotation[param2]
					end
					minetest.set_node(check_node.pos, {
						name = "bigdoors:hidden_section_"..size_str,
						param2 = param2
					})
				end
			end
		end
		return itemstack
	end
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

local function pairing_on_left(pos, dir, width)
	local leftward = param2_to_vector[dir + 1]
	local left_side = pos
	local pair = nil
	for l=1,3,1 do -- TODO: find limit from available range, not hardcoded (replace 3 with (max_width*2)-1)
		left_side = vector.add(left_side, leftward)
		local left_node = minetest.get_node(left_side)
		local left_node_name = left_node.name
		if minetest.get_item_group(left_node_name, "door") == 1 then
			local dir_str = string.sub(left_node_name,-1)
			local pair_width = width + door_sizes[string.sub(left_node_name,-6,-3)].width
			if (
				(dir_str == 'a' and dir == left_node.param2)       -- If closed and same
			 or (dir_str == 'c' and (dir+1)%4 == left_node.param2) -- If open and same when closed
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

local function pairing_on_right(pos, dir, width)
	local rightward = param2_to_vector[((dir + 2)%4)+1]
	local right_side = pos
	local pair = nil
	for r=1,3,1 do -- TODO: find limit from available range, not hardcoded (replace 3 with (max_width*2)-1)
		right_side = vector.add(right_side, rightward)
		local right_node = minetest.get_node(right_side)
		local right_node_name = right_node.name
		if minetest.get_item_group(right_node_name, "door") == 1 then
			local dir_str = string.sub(right_node_name,-1)
			local pair_width = width + door_sizes[string.sub(right_node_name,-6,-3)].width
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
	return pair
end

local function on_place_size(name, size, def, size_string)
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

		local pair = pairing_on_left(pos, dir, size.width)
		local state = 0
		if pair then
			state = 2
		else
			pair = pairing_on_right(pos, dir, size.width)
		end

		local check_nodes = door_occupies(pos, dir, state, size, pair)


		-- Check surroundings for validity of placement

		for _,check_pos in ipairs(check_nodes) do
			if not check_pos.overlap then
				local check_node = minetest.get_node_or_nil(check_pos.pos)
				local check_def = check_node and minetest.registered_nodes[check_node.name]

				-- If this and that are halfers, allow ends to overlap

				if not check_def or not check_def.buildable_to then
					return itemstack
				end

				if minetest.is_protected(check_pos, player_name) then
					return itemstack
				end
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
			if check_pos.dir == 'back' then
				minetest.set_node(check_pos.pos, {
					name = "bigdoors:hidden",
					param2 = hidden_param2
				})
			else
				local width = 1
				if check_pos.edge and not check_pos.overlap then
					width = size.width%1
				end
				local size_str = size_to_string({ width=width, height=1})

				local param2 = dir
				if state == 2 then
					param2 = reverse_rotation[param2]
				end
				minetest.set_node(check_pos.pos, {
					name = "bigdoors:hidden_section_"..size_str,
					param2 = param2
				})
			end
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

minetest.register_node("bigdoors:hidden", {
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
})
local function hidden_section(size)
	local size_string = size_to_string(size)
	local name = "bigdoors:hidden_section_"..size_string
	minetest.log("error", name)

	local def = {
		description = S("Hidden Door Section - "..size_string),
		-- drawtype = "mesh",
		drawtype = "airlike",
		paramtype = "light",
		paramtype2 = "facedir",
		sunlight_propagates = true,
		-- has to be walkable for falling nodes to stop falling.
		walkable = true,
		is_ground_content = false,
		pointable = false,
		pointable = true,
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
	}

	local normalbox = {-1/2,-1/2,-1/2,1/2,3/2,-6/16}
	normalbox[5] = normalbox[2]+size.height
	normalbox[4] = normalbox[1]+size.width

	def.collision_box = {type = "fixed", fixed = normalbox}

	-- local debug_select = table.copy(normalbox)
	-- debug_select[6] = 0
	-- def.selection_box = {type = "fixed", fixed = debug_select}
	-- def.mesh = "bigdoor_a1020.obj"

	-- Register nodes

	minetest.register_node(":" .. name, def)

end

hidden_section({ width=1, height=1 })
hidden_section({ width=0.5, height=1 })

-- for size_string, size in pairs(door_sizes) do
-- 	if size.height > 2 then
-- 		local name = "bigdoors:hidden_section_"..size_string
		--[[
		local name = "bigdoors:hidden_half_"..size_string

		local def = {
			description = S("Hidden Door Top Half - "..size_string),
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

			door = {
				name = name,
				sounds = { "doors_door_close", "doors_door_open" },
			}
		}

		local normalbox = {-1/2,-1/2,-1/2,1/2,3/2,-6/16}
		normalbox[5] = normalbox[2]+(size.height-2)

		local defa = by_value(def)
		local defb = by_value(def)
		local defc = by_value(def)
		local defd = by_value(def)

		local adbox = table.copy(normalbox)
		local bcbox = table.copy(normalbox)

		adbox[4] = adbox[1]+size.width
		bcbox[1] = bcbox[4]-size.width

		defa.collision_box = {type = "fixed", fixed = adbox}
		defb.collision_box = {type = "fixed", fixed = bcbox}
		defc.collision_box = {type = "fixed", fixed = bcbox}
		defd.collision_box = {type = "fixed", fixed = adbox}


		-- Register nodes

		minetest.register_node(":" .. name .. "_a", defa)
		minetest.register_node(":" .. name .. "_b", defb)
		minetest.register_node(":" .. name .. "_c", defc)
		minetest.register_node(":" .. name .. "_d", defd)

		doors.registered_doors[name .. "_a"] = true
		doors.registered_doors[name .. "_b"] = true
		doors.registered_doors[name .. "_c"] = true
		doors.registered_doors[name .. "_d"] = true
		]]
-- 	end
-- end



function bigdoors.register(originalname, config)
	-- basename, basedef

	local basedef = minetest.registered_nodes[originalname..'_a']
	local baseitem = minetest.registered_craftitems[originalname]
	
	if not originalname:find(":") then
		originalname = "bigdoors:" .. originalname
	end

	if not basedef.on_rightclick then
		basedef.on_rightclick = on_rightclick
	end


	for size_string, size in pairs(door_sizes) do

		local def = table.copy(basedef)
		-- Name
		local name = originalname..'_'..size_string
		def.drop = name
		def.door.name = name


		-- Use inventory image for item, and remove from def

		minetest.register_craftitem(":" .. name, {
			description = baseitem.description .. ' (' .. tostring(size.width) .. ' x ' .. tostring(size.height) .. ')',
			inventory_image = baseitem.inventory_image,
			groups = table.copy(baseitem.groups),
			on_place = on_place_size(name, size, def, size_string)
		})


		-- Use recipe to create crafts

		if config.recipe then
			local recipe = config.recipe[size_string]
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
		else
			local recipe = {}
			local recipe_row = {}
			for i=1,size.recipe.width,1 do
				table.insert(recipe_row, originalname)
			end
			for i=1,size.recipe.height,1 do
				table.insert(recipe, recipe_row)
			end
			minetest.register_craft({
				output = name..' '..tostring(size.recipe.output),
				recipe = recipe,
			})
		end


		-- Callbacks

		local after_dig_node = after_dig_node_size(size)
		local on_blast_unprotected = on_blast_unprotected_size(size)
		local on_destruct = on_destruct_size(size)

		def.after_dig_node = after_dig_node
		def.on_destruct = on_destruct

		if not def.protected then
			def.on_blast = on_blast_unprotected
		end

		def.on_rightclick = on_rightclick_size(size)


		-- Model and hitbox

		local normalbox = {-1/2,-1/2,-1/2,1/2,3/2,-6/16}
		normalbox[5] = normalbox[2]+size.height
		local defa = by_value(def)
		local defb = by_value(def)
		local defc = by_value(def)
		local defd = by_value(def)

		local adbox = table.copy(normalbox)
		local bcbox = table.copy(normalbox)

		adbox[4] = adbox[1]+size.width
		bcbox[1] = bcbox[4]-size.width

		defa.selection_box = {type = "fixed", fixed = adbox}
		defb.selection_box = {type = "fixed", fixed = bcbox}
		defc.selection_box = {type = "fixed", fixed = bcbox}
		defd.selection_box = {type = "fixed", fixed = adbox}

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
		--]]
	end
	
end



if minetest.get_modpath("doors") ~= nil then
	bigdoors.register("doors:door_wood", {

	})
	bigdoors.register("doors:door_steel", {

	})
	bigdoors.register("doors:door_glass", {

	})
	bigdoors.register("doors:door_obsidian_glass", {

	})
end