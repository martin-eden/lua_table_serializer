#!/bin/sh

# Pack function into one Lua code file

#
# Author: Martin Eden
# Last mod.: 2026-08-21
#

#
# Results are placed in "deploy/"
#
# We will create file "serialize_lua_graph.lua" there.
# It's combined Lua code of this function without comments.
# It's ready to copy somewhere and load from Lua code as
#
#   local t2s = require('serialize_lua_graph')
#
# Toolchain uses my "lua code melder" tool to combine files into one:
#
#   https://github.com/martin-eden/lua_code_melder
#
# Toolchain uses my "lua code formatter" tool to strip comments:
#
#   https://github.com/martin-eden/lua_code_formatter
#

set -e -u

#
# src/
#

cd ../src

rm -rf workshop/

lua ../builder/create_deploy.lua

bash deploy.sh
rm deploy.sh

mv deploy/workshop/ .
rm -rf deploy/

#
# builder/
#

cd ../builder

# Combine all Lua code
./meld ../src/ serialize_lua_graph > ../deploy/serialize_lua_graph.melded.lua

# Reformat code and strip comments
./reformat_lua \
  ../deploy/serialize_lua_graph.melded.lua \
  ../deploy/serialize_lua_graph.melded.stripped.lua \
  --~keep-comments \
  --right-margin=72
rm ../deploy/serialize_lua_graph.melded.lua

mv \
  ../deploy/serialize_lua_graph.melded.stripped.lua \
  ../deploy/serialize_lua_graph.lua

#
# test/
#

cd ../test

# Call test script
lua run.lua > output/graph.lua

# 2026 # # # #
# 2026-08-21
