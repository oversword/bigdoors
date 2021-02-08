
local function by_value( t1 )
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

function bigdoors.register(originalname, config)

	local basedef = minetest.registered_nodes[originalname..'_a']
	local baseitem = minetest.registered_craftitems[originalname]
	
	if not config then
		config = {}
	end

	config = bigdoors.merge_config(config)

	local base_name = originalname
	if config.name then
		base_name = config.name
	end
	if not base_name:find(":") then
		base_name = bigdoors.modname..":" .. base_name
	end

	local base_size_string = "1020"
	local bigdoor_base_name = base_name.."_"..base_size_string

	local valid_sizes = bigdoors.api.size_variations(config.variations)

	if config.replace_original and not valid_sizes[base_size_string] then
		minetest.log("error", "BigDoors: Cannot replace original door ("..originalname..") if 1x2 size variation is disallowed")
		return
	end

	local recipe_name = originalname
	if config.replace_original then
		recipe_name = bigdoor_base_name
		bigdoors.data.replacement_doors[originalname] = bigdoor_base_name
		minetest.register_alias_force(originalname, bigdoor_base_name)
		minetest.register_alias_force(originalname..'_a', bigdoor_base_name..'_a')
		minetest.register_alias_force(originalname..'_b', bigdoor_base_name..'_b')
		minetest.register_alias_force(originalname..'_c', bigdoor_base_name..'_c')
		minetest.register_alias_force(originalname..'_d', bigdoor_base_name..'_d')
	end

	for size_string, size in pairs(valid_sizes) do

		-- Name
		local name = base_name..'_'..size_string

		-- Create item
		minetest.register_craftitem(":" .. name, {
			description = baseitem.description .. ' (' .. tostring(size.width) .. ' x ' .. tostring(size.height) .. ')',
			inventory_image = baseitem.inventory_image.."^bigdoors_item_"..size_string.."_overlay.png",
			groups = table.copy(baseitem.groups),
			on_place = bigdoors.actions.on_place
		})

		-- Use recipe to create crafts
		if config.recipe then
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
			-- TODO: more complex crafts for making from other components? e.g. (1x3)+(1x3)=(2x3)
			minetest.register_craft({
				output = name..' '..tostring(size.recipe.output),
				recipe = bigdoors.api.new_recipe(size.recipe, recipe_name),
			})
			minetest.register_craft({
				type = "shapeless",
				output = recipe_name..' '..tostring(size.recipe.width*size.recipe.height),
				recipe = bigdoors.api.new_recipe({width=size.recipe.output,height=1},name)[1]
			})
			if not (config.replace_original or size_string == base_size_string) then
				minetest.register_craft({
					output = name..' '..tostring(size.recipe.output),
					recipe = bigdoors.api.new_recipe(size.recipe, bigdoor_base_name),
				})
			end
		end

		local def = table.copy(basedef)
		def.drop = name
		def.door.name = name


		-- Callbacks
		def.on_rightclick = bigdoors.actions.on_rightclick

		def.after_dig_node = bigdoors.actions.after_dig_node
		def.on_destruct = bigdoors.actions.on_destruct
		if not def.protected then
			def.on_blast = bigdoors.actions.on_blast_unprotected
		end

		if minetest.global_exists("mesecon") then
			def.mesecons = {effector = {
				action_on = bigdoors.actions.mesecon_toggle,
				action_off = bigdoors.actions.mesecon_toggle,
				rules = mesecon.rules.pplate
			}}
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
		
		bigdoors.api.do_not_move(name .. "_a")
		bigdoors.api.do_not_move(name .. "_b")
		bigdoors.api.do_not_move(name .. "_c")
		bigdoors.api.do_not_move(name .. "_d")
	end
end

