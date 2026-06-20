[![DeepWiki][DeepWiki_Logo]][DeepWiki_Repo] (sometimes AI explains it better)

## What

| Created | Updated |  Size   | License |
|:-------:|:-------:|:-------:|:-------:|
| 2017-05 | 2026-06 | < 50 K  |  LGPL3  |

Serialize data in Lua table to string with Lua code that recreates
this data.

Lua tables can contain cross-references, so actually it's graph encoder
to Lua code.


## Usage scenarios

I'm using it as data exploration tool. Also it's very handy at debugging
Lua code.


## First run

```lua
t2s = require('serialize_lua_graph')
print(t2s(_G))
```

## Encoding options

Options is optional table that can be passed as second argument
to function. That's Lua table with values like `{ style = 'readable_short' }`.

We'll demonstrate behavior on excerpt of `_G` table printout.

Serializer function supports three _encoding styles_: `minimal`,
`readable_short` and `readable_long`.


| `style`          | Output                                                          |
|:-----------------|:----------------------------------------------------------------|
| `minimal`        | `local T_1={bit32={arshift='function: 0x557703aab060',`         |
| `readable_short` | `local T_1 = { bit32 = { arshift = 'function: 0x55da5d825060',` |
| `readable_long`  | `local T_1 = {`                                                 |
|                  | `  bit32 = {`                                                   |
|                  | `    arshift = 'function: 0x5595744ae060',`                     |

Serializer function supports three _behavior flags_:

| Behavior flag             | Output                                           |
|:--------------------------|:-------------------------------------------------|
| `☑ use_compact_indices`   | `package = T_2,`                                 |
| `☐ use_compact_indices`   | `['package'] = T_2,`                             |
| `☑ use_compact_sequences` | `searchers = { 'function: 0x56089fbeba20'`       |
| `☐ use_compact_sequences` | `searchers = { [1] = 'function: 0x5580fdeb8a20'` |
| `☑ omit_tail_delimiter`   | `xpcall = 'function: 0x5612c12e1e90' }`          |
| `☐ omit_tail_delimiter`   | `xpcall = 'function: 0x55b2598d9e90',  }`        |


## Install/remove

  * Save file `serialize_lua_graph.lua` from [`deploy/`][deploy]
  * Place it to your Lua workplace for `require()`


## Modify

  * Clone repo
  * Modify files in [`src/`][src]


## Rebuild

  * Clone [`workshop`][workshop] repo
  * Checkout it to date near `2026-06-20`
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
