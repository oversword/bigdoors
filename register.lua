
function bigdoors.register(originalname, config)

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


		-- Model and hitbox

		for _,variation in ipairs(bigdoors.data.variants) do
			local variation_name = name .. "_" .. variation

			local basedef = minetest.registered_nodes[originalname .. '_' .. variation]

			local def = table.copy(basedef)

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

			def.drop = name
			def.door.name = name

			if size_string ~= base_size_string then
				def.selection_box = {type = "fixed", fixed = size.hitbox[variation]}
				def.mesh = "bigdoor_"..variation..size_string..".obj"
			end

			-- Register nodes
			minetest.register_node(":" .. variation_name, def)

			doors.registered_doors[variation_name] = true
			
			bigdoors.api.do_not_move(variation_name)
		end
	end

	if config.replace_original then
		-- Make sure to register aliases AFTER copying their info from registered_nodes
		minetest.register_alias_force(originalname..'_a', bigdoor_base_name..'_a')
		minetest.register_alias_force(originalname..'_b', bigdoor_base_name..'_b')
		minetest.register_alias_force(originalname..'_c', bigdoor_base_name..'_c')
		minetest.register_alias_force(originalname..'_d', bigdoor_base_name..'_d')
	end
end

