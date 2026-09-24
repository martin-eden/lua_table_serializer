[![DeepWiki][DeepWiki_Logo]][DeepWiki_Repo] (sometimes AI explains it better)

<table>
  <tr>
    <th colspan=3>Lua table serializer</th>
  </tr>
  <tr>
    <td>
      <table>
        <tr>
          <th>Updated</th>
          <td>2026-09-24</td>
        </tr>
        <tr>
          <th>Created</th>
          <td>2017-05</td>
        </tr>
        <tr>
          <th>Code size</th>
          <td>&lt; 60 K</td>
        </tr>
        <tr>
          <th>License</th>
          <td>LGPL3</td>
        </tr>
      </table>
    </td>
    <td align=center>
      Function to serialize data in Lua table to string with Lua code
      that recreates this data.
    </td>
    <td>
      <table>
        <tr>
          <th>Input</th>
          <th>Output</th>
        </tr>
        <tr>
          <td>
            table
          </td>
          <td>
            string with Lua code
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>

Lua tables can contain cross-references, so actually it's
graph encoder to Lua source code.


## Scope

Primary objective is serialization graph to source code.
Nice output is secondary objective.


## First run

```lua
t2s = require('serialize_lua_graph')
print(t2s(_G.math))
```

Prints
```lua
return
  {
    huge = 1/0,
    maxinteger = 9223372036854775807,
    mininteger = -9223372036854775808,
    pi = 3.1415926535897931,
  };
```

Note that functions are not mentioned -- they can't be serialized.


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
local t2s = require('serialize_lua_graph')
local s = t2s(_G, { style = 'readable_short', use_compact_sequences = false })
print(s)
```

We'll demonstrate their effects on excerpts of `_G` table printout.

<table>
  <thead>
    <tr>
      <th>Style</th>
      <th>Output</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>minimal</code></td>
      <td><pre><code>local T_1={};local T_2={};</code></pre></td>
    </tr>
    <tr>
      <td><code>readable_short</code></td>
      <td><pre><code>local T_1 = { };
local T_2 = { };</code></pre></td>
    </tr>
    <tr>
      <td><code>readable_long</code></td>
      <td><pre><code>local T_4 =
  {
    huge = 1/0,
    maxinteger = 9223372036854775807,
  };</code></pre></td>
    </tr>
  </tbody>
</table>

<table>
  <thead>
    <tr>
      <th>Behavior flag</th>
      <th>Value</th>
      <th>Output</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td rowspan="2"><code>use_compact_indices</code></td>
      <td>☐</td>
      <td><code>['coroutine'] = T_1,</code></td>
    </tr>
    <tr>
      <td>☑</td>
      <td><code>coroutine = T_1,</code></td>
    </tr>
    <tr>
      <td rowspan="2"><code>use_compact_sequences</code></td>
      <td>☐</td>
      <td><code>[1] = 'nil',</code></td>
    </tr>
    <tr>
      <td>☑</td>
      <td><code>'nil',</code></td>
    </tr>
    <tr>
      <td rowspan="2"><code>omit_tail_delimiter</code></td>
      <td>☐</td>
      <td><code>['utf8'] = T_8, };</code></td>
    </tr>
    <tr>
      <td>☑</td>
      <td><code>['utf8'] = T_8 };</code></td>
    </tr>
  </tbody>
</table>


## Details/limitations

* It does not distinguish between -NaN and NaN

  Our check for NaN is `n ~= n`.

  So both `-(0/0)` and `0/0` are serialized to string `0/0`.

  From our point of view concept "this is not a number, but negative"
  is gibberish.

* You can hit limit of Lua `local`'s

  For common subtables we emit something like `local T_2 = {`.

  Lua implementations have limit on number of locals near 200.

  So when number of common subtables is over 200 your Lua interpreter
  won't be able to load code.

  We think it's not our problem. From our point of view we're exporting
  statement with value capture.

* Functions, threads, userdata and metatables are not serialized

  First, it makes no practical sense to serialize functions.

  C functions can't be serialized.

  For Lua functions you can store their bytecode. But its instructions
  may use upvalues. We see no practical sense in trouble of retrieving
  upvalues (which may end up to something unserializeable).

  Second, threads (coroutines) and userdata are not serializeable.

  Third, metatables.

  Our common pattern is that metatables contain functions. Not serializeable.

  Even if in your case they contain plain strings/tables
  we see no practical need in tracking links between base table
  and metatable and adding AST node to emit `setmetatable`.


## Shipment

  * Combined code in [`deploy/`][deploy_dir]
  * Full source code in [`src/`][src]
  * Build script and tools in [`builder/`][builder]
  * Sample input and output in [`test/`][sample]


## Requirements

  * Lua 5.3 (or 5.4, 5.5)


## Install/remove

  * Save file `serialize_lua_graph.lua` from [`deploy/`][deploy_dir]
  * Place it to your Lua workplace for `require()`


## Modify

  * Clone repo
  * Modify files in [`src/`][src]


## Rebuild

  * Clone [`workshop`][workshop] repo
  * Checkout it to date near "Updated" date from stats plate (at header of this Readme)
  * Modify `package.path` in [`builder/deploy.lua`][deploy_script]
    so it can find your cloned `workshop` repo
  * Run [`builder/rebuild.sh`][rebuild]


## See also

  * [`Ser`][Ser] -- Beautiful trickster-style implementation of same
    thing by `Jasmijn Wellner`

    We've overgrown obsession with regexps and strings long ago.
    Still it's very nice example of that style. Ten times less code!

  * [`workshop`][workshop] -- My personal Lua framework on which this tool is based
  * [My other projects][contents]


[DeepWiki_Logo]: https://deepwiki.com/badge.svg
[DeepWiki_Repo]: https://deepwiki.com/martin-eden/lua_table_serializer

[deploy_dir]: deploy/
[src]: src/
[builder]: builder/
[sample]: test/
[deploy_script]: builder/deploy.lua
[rebuild]: builder/rebuild.sh

[Ser]: https://github.com/gvx/Ser
[workshop]: https://github.com/martin-eden/workshop
[contents]: https://github.com/martin-eden/contents
