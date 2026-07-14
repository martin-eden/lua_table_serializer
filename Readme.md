[![DeepWiki][DeepWiki_Logo]][DeepWiki_Repo] (sometimes AI explains it better)

| Created |  Updated   |  Size   | License |
|:-------:|:----------:|:-------:|:-------:|
| 2017-05 | 2026-08-21 | < 70 K  |  LGPL3  |


## What

Function to serialize data in Lua table to string with Lua code
that recreates this data.

Lua tables can contain cross-references, so actually it's graph encoder
to Lua source code.


## Scope

Primary objective is serialization graph to source code.
Nice output is secondary objective.


## Usage scenarios

I'm using it as data exploration tool. Also it's very handy at debugging
Lua code.


## First run

```lua
t2s = require('serialize_lua_graph')
print(t2s(_G))
```


## Encoding options

Encoding options is optional table that can be passed as second argument.

Serializer function supports three _encoding styles_: `minimal`,
`readable_short` and `readable_long`. Encoding style governs whitespaces
and determines general text layout. Style lives in `style` string field.

Serializer function supports three _behavior flags_: `use_compact_indices`,
`use_compact_sequences` and `omit_tail_delimiter`. Behavior flags
govern optional lexical elements emission. They determine what
syntax elements will be present. Behavior flags are boolean fields.

Example:

```lua
local g2s = require('serialize_lua_graph')
local Options = { style = 'readable_short', use_compact_sequences = false }
local str = g2s(_G, Options)
print(str)
```

We'll demonstrate their effects on excerpt of `_G` table printout.


| Style            | Output                                                          |
|:-----------------|:----------------------------------------------------------------|
| `minimal`        | `local T_1={bit32={arshift='function: 0x557703aab060',`         |
| `readable_short` | `local T_1 = { bit32 = { arshift = 'function: 0x55da5d825060',` |
| `readable_long`  | `local T_1 = {`                                                 |
|                  | `  bit32 = {`                                                   |
|                  | `    arshift = 'function: 0x5595744ae060',`                     |


| Behavior flag           | Output                                           | Value |
|:------------------------|:-------------------------------------------------|:-----:|
| `use_compact_indices`   | `['package'] = T_2,`                             |   ☐   |
|                         | `package = T_2,`                                 |   ☑   |
| `use_compact_sequences` | `searchers = { [1] = 'function: 0x5580fdeb8a20'` |   ☐   |
|                         | `searchers = { 'function: 0x56089fbeba20'`       |   ☑   |
| `omit_tail_delimiter`   | `xpcall = 'function: 0x55b2598d9e90',  }`        |   ☐   |
|                         | `xpcall = 'function: 0x5612c12e1e90' }`          |   ☑   |


## Requirements

  * Lua 5.3 (or 5.4, 5.5)


## Install/remove

  * Save file `serialize_lua_graph.lua` from [`deploy/`][deploy]
  * Place it to your Lua workplace for `require()`


## Modify

  * Clone repo
  * Modify files in [`src/`][src]


## Rebuild

  * Clone [`workshop`][workshop] repo
  * Checkout it to date near "Updated" date from stats plate (at header of this Readme)
  * Modify `package.path` in [`builder/create_deploy.lua`][create_deploy]
    so it can find your cloned `workshop` repo
  * Run [`builder/rebuild.sh`][builder]


## See also

  * [`workshop`][workshop] -- My personal Lua framework on which this tool is based
  * [My other projects][contents]


[DeepWiki_Logo]: https://deepwiki.com/badge.svg
[DeepWiki_Repo]: https://deepwiki.com/martin-eden/lua_table_serializer

[deploy]: deploy/
[src]: src/
[create_deploy]: builder/create_deploy.lua
[builder]: builder/

[workshop]: https://github.com/martin-eden/workshop
[contents]: https://github.com/martin-eden/contents
