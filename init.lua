bigdoors = {config={},api={},actions={},data={}}

bigdoors.config.debug_hidden_nodes = false -- true

bigdoors.config.door_widths = {10,15,20}
bigdoors.config.door_heights = {20,30,40}

bigdoors.modname = minetest.get_current_modname()
bigdoors.modpath = minetest.get_modpath(bigdoors.modname)

dofile(bigdoors.modpath .. "/config.lua")
dofile(bigdoors.modpath .. "/lib.lua")
dofile(bigdoors.modpath .. "/setup.lua")
dofile(bigdoors.modpath .. "/register.lua")
dofile(bigdoors.modpath .. "/notify.lua")
-- dofile(bigdoors.modpath .. "/default-doors.lua")