bigdoors = {}

bigdoors.debug_hidden_nodes = false -- true

bigdoors.door_widths = {10,15,20}
bigdoors.door_heights = {20,30,40}

bigdoors.modname = minetest.get_current_modname()
bigdoors.modpath = minetest.get_modpath(bigdoors.modname)

dofile(bigdoors.modpath .. "/register.lua")
dofile(bigdoors.modpath .. "/default-doors.lua")