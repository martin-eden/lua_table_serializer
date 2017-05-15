--[[
  United test of
    * indexing
      * in tables
      * in direct assignments
    * self-links, common links
      * in keys
      * in values
]]

-- [[
local a = {name = 'a'}
local b = {name = 'b'}
local c = {name = 'c'}
local d = {name = 'd'}
local e = {name = 'e'}

a.next_b = b
b.next_c = c
c.next_a = a
c.next_d = d
d.next_e = e
e.next_c = c

local func = function()end
e[func] = func
e.self = e
e['s e \\ l f'] = e
e[1] = e
e['1'] = e
e[e] = e

local x = {}
local y =
  {
    [{}] = {_ = '_'},
    y = 'y',
    ['@'] = '@',
    [x] = x,
  }
y.names = {y = y}
y[y] = y
a.y = y

return a
--]]
