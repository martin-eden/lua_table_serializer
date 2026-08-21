-- Test of Lua graph serializer

--[[
  Author: Martin Eden
  Last mod.: 2026-08-30
]]

package.path = package.path .. ';../deploy/?.lua'

-- Print graph as Lua code
local test
do
  local g2s = require('serialize_lua_graph')
  local Options =
    {
      -- style = 'minimal',
      style = 'readable_short',
      -- style = 'readable_long',
      -- use_compact_indices = not true,
      -- use_compact_sequences = true,
      -- omit_tail_delimiter = not true,
    }
  test =
    function(Graph)
      io.stdout:write(g2s(Graph, Options))
      io.stdout:write('\n')
    end
end

-- Print graph with self-links in keys and values
do
  local Graph

  do
    Graph = { }
    Graph[{ Graph }] = { Graph }
  end

  -- Graph = _G

  test(Graph)
end

--[[
  2026 # # #
  2026-08-30
]]
