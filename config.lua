--[[

-- Default config
-- if no config is passed or values are unset, this is what they will be
{
	-- Name will override the original name of the door that is transformed
	-- type: string
	name = <original name>,

	-- Should the original 1x2 door be replaced by the 1x2 bigdoor?
	-- type: boolean
	replace_original = false,

	-- Allowed size variations, specifications can only be removed / filtered out
	-- no additional sizes can be added through this setting
	-- type: keyed table
	variations = {

		-- Allowed widths
		-- type: unkeyed table (list)
		widths  = {1, 1.5, 2},

		-- Allowed heights
		-- type: unkeyed table (list)
		heights = {2, 3,   4},

		-- Allowed sizes
		-- type: unkeyed table (list) of width-height pairs
		sizes = {
			{width=1,   height=2},
			{width=1.5, height=2},
			{width=2,   height=2},

			{width=1,   height=3},
			{width=1.5, height=3},
			{width=2,   height=3},

			{width=1,   height=4},
			{width=1.5, height=4},
			{width=2,   height=4},
		},

		-- Only allow doors that maintain the original 1x2 proportion, allows: 1x2, 1.5x3, 2x4
		-- type: boolean
		original_proportions = false,
	}
}

## Default settings, for minetest.conf
## If these are unset, this is what the defaults will be

# Should the original 1x2 door be replaced by the 1x2 bigdoor?
bigdoors.replace_original = false

# Only allow doors that maintain the original 1x2 proportion, allows: 1x2, 1.5x3, 2x4
bigdoors.variations.original_proportions = false

# Allowed widths
bigdoors.variations.widths = ( 1, 1.5, 2 )

# Allowed heights
bigdoors.variations.heights = ( 2, 3, 4 )

# Allowed size variations, this is a list of ( width, height ) pairs
bigdoors.variations.sizes = ( ( 1, 2 ), ( 1.5, 2 ), ( 2, 2 ), ( 1, 3 ), ( 1.5, 3 ), ( 2, 3 ), ( 1, 4 ), ( 1.5, 4 ), ( 2, 4 ) )


]]

local function parse_table(str)
	if not str then return end
	str = string.gsub(str, '%(', '{')
	str = string.gsub(str, '%)', '}')
	return minetest.deserialize('return '..str)
end

local function transform_sizes(sizes)
	if not sizes then return end
	local ret = {}
	for _,size in ipairs(sizes) do
		if #size >= 2 then
			table.insert(ret, {width=size[1],height=size[2]})
		end
	end
	return ret
end

local replace_original = minetest.settings:get_bool(bigdoors.modname..".replace_original", false)
local widths = parse_table(minetest.settings:get(bigdoors.modname..".variations.widths"))
local heights = parse_table(minetest.settings:get(bigdoors.modname..".variations.heights"))
local sizes = transform_sizes(parse_table(minetest.settings:get(bigdoors.modname..".variations.sizes")))
local original_proportions = minetest.settings:get_bool(bigdoors.modname..".variations.original_proportions", false)

local variations
if widths or heights or sizes or original_proportions then
	variations = {
		widths = widths,
		heights = heights,
		sizes = sizes,
		original_proportions = original_proportions,
	}
end

local default = {
	replace_original=replace_original,
	variations = variations
}
local function merge_table(def, new)
	for k,v in pairs(new) do
		-- If key-value table, recurse
		if type(v) == 'table' and #v == 0 and type(def[k]) == 'table' and #def[k] == 0 then
			def[k] = merge_table(def[k], v)
		else -- else just overwrite
			def[k] = v
		end
	end
	return def
end

bigdoors.merge_config = function (config)
	local ret = merge_table(table.copy(default), config)
	minetest.log("error", minetest.serialize(ret))
	return ret
end