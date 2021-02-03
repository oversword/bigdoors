# BigDoors #
> 3-wide and 4-wide double doors for minetest

![All new door variations laid out in a three by three grid, with alternating blocks aroud the border to make it clear how big they are](screenshot.png?raw=true "Big Doors")

## What does it do? ##
Provides new models for wider and taller doors, stretching the texture for any existing door into larger sizes.
Doors can be 1 block, 1 and a half blocks, or 2 blocks wide, and can be 2, 3 or 4 blocks tall. This provides the ability to cover larger spaces with double doors, and also provides large doors for grander builds.

## How do I use it? ##
Any existing door can be transformed into big doors by registering it:

`bigdoors.register("doors:door_wood")`

A second argument can also be passed in to configure the door:

`bigdoors.register("doors:door_wood", {})`

All of the following information is also available in `config.lua`

### Here is the full default config table ###
If no config is passed or values are unset, this is what they will be
```
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
```

### Here is the full default config settings ###

You can also provide new defaults for this config by setting them in your `minetest.conf`

If these are unset, this is what the defaults will be
```
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
```

## How does it do it? ##
This mod copies as much as it can from the original door, replacing only the `on_rightclick` and removal callbacks, such as `after_dig_node` and `on_destruct`.

This mod also provides several new hidden nodes that prevent other nodes being placed that would intersect the door, and to provide a larger hitbox for doors that extend past the natural hitbox range.

If a door cannot be placed, the player will be notified via the HUD display which direction is blocked.

If you choose to replace the original 1x2 door by setting `replace_original`, which is beneficial because the original door will not pair with big doors of other sizes, then it will register aliases from the original door to the new big door.


## Why do I want it? ##

Normal doors do not fit every scenario, and on larger builds such as castles and mansions they can seem oddly small - not to mention that a door being exactly the height of the player is unrealistic, even for taller people.

Some of the proportions possible with these doors do not work with every texture, but I believe it is up to the builder's discretion to choose, and it's better to provide as full of a range as possible - these doors will give your builders the freedom to use and combine doors of sizes that were never possible before, but were always desired.
