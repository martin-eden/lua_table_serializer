-- Test of Lua graph serializer

--[[
  Author: Martin Eden
  Last mod.: 2026-06-20
]]

package.path = package.path .. ';../deploy/?.lua'
local t2s = require('serialize_lua_graph')

local test =
  function(val)
    print(t2s(val))
  end

local Graph = { }
Graph[{ Graph }] = { Graph }
test(Graph)

--[[
  2026-06-17
  2026-06-20
]]
