require('workshop.base')

--[[ terse mode
local terser = new(request('!.formats.lua_table.save.interface'))
terser.install_node_handlers = request('!.formats.lua_table.save.install_node_handlers.minimal')
local table_to_str_orig = request('!.formats.lua_table_code.save')
local table_to_str =
  function(t)
    return table_to_str_orig(t, {c_table_serializer = terser})
  end
--]]
local table_to_str = request('!.formats.lua_table_code.save')

-- local test_table = request('test_data')
local test_table = _G

print(table_to_str(test_table))
