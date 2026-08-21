-- Test of Lua graph serializer

--[[
  Author: Martin Eden
  Last mod.: 2026-08-21
]]

package.path = package.path .. ';../deploy/?.lua'

-- Print graph as Lua code
local test
do
  local g2s = require('serialize_lua_graph')
  test =
    function(Graph)
      io.stdout:write(g2s(Graph))
    end
end

-- Print graph with self-links in keys and values
do
  local Graph = { }
  Graph[{ Graph }] = { Graph }

  test(Graph)
end

--[[
  2026 # #
  2026-08-21
]]
