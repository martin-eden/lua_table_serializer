-- Load modules to get a list of all required Lua files

--[[
  Author: Martin Eden
  Last mod.: 2026-09-24
]]

--[[
  How to use

  * Include root modules in <ModulesList>

  * Do one of

    * Copy this file to root Lua source directory

    * Call this file from Lua source directory:

        $ lua ../builder/create_deploy.lua

  Make sure that main Lua file executes without errors when
  loaded as module. If needed, make changes to it to behave so.
]]

local Modules = { 'serialize_lua_graph' }

--
package.path = package.path .. ';../../../?.lua'
--
local ModulePaths
do
  local observe_modules = require('workshop.system.observe_modules')
  ModulePaths = observe_modules(Modules)
end
--
require('workshop.base')

local FilesList
do
  local add_to = request('!.concepts.list.add_item')
  FilesList = { }
  for _, ModuleLoc in ipairs(ModulePaths) do
    add_to(FilesList, ModuleLoc[2])
  end
end
--
local create_deploy_script = request('!.system.create_deploy_script')
create_deploy_script(FilesList)
--

--[[
  202?
  2026 # # # #
  2026-09-24
]]
