-- Load modules to get a list of all required Lua files

--[[
  Author: Martin Eden
  Last mod.: 2026-06-20
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

  At loading via request() module dependencies are stored in
  some global table. create_deploy_script() uses that table to
  write Bash script which copies module files to local directory.
]]

package.path = package.path .. ';../../../?.lua'
require('workshop.base')

local create_deploy_script = request('!.system.create_deploy_script')

local ModulesList =
  {
    'workshop.base',
    'serialize_lua_graph',
  }

create_deploy_script(ModulesList)

--[[
  202?
  2026-01-21
  2026-04-23
  2026-04-25
  2026-06-01
]]
