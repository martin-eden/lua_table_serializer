-- Decision-making function how to represent data in Lua string syntax

--[[
  Author: Martin Eden
  Last mod.: 2026-07-11
]]

--[[
  "Fixed-quote mode" is when we're using "'" or " for quoting.
  They allow fancy \-backslash codes.

  There are "variable-quote mode" (also called "intact") when
  we're using directed fancy quotes "[===[" and "]===]" with
  amount of "="'s determined in situ.
]]

-- Imports:
local quote_variable = request('quote_string.intact')
local content_funcs = request('!.string.content_attributes')

local str_gmatch = string.gmatch
local str_gsub = string.gsub
local str_format = string.format
local str_byte = string.byte

local has_control_chars = content_funcs.has_control_chars
local has_backslashes = content_funcs.has_backslashes
local has_single_quotes = content_funcs.has_single_quotes
local has_double_quotes = content_funcs.has_double_quotes
local has_newlines = content_funcs.has_newlines

local binary_entities_lengths =
  {
    [1 << 0] = true,
    [1 << 1] = true,
    [1 << 2] = true,
    [1 << 3] = true,
  }

local determine_fixed_quote_char =
  function(str)
    local quote_char

    local single_quote = "'"
    local double_quote = '"'

    local num_single_quotes = 0
    local num_double_quotes = 0

    for _ in str_gmatch(str, single_quote) do
      num_single_quotes = num_single_quotes + 1
    end

    for _ in str_gmatch(str, double_quote) do
      num_double_quotes = num_double_quotes + 1
    end

    if (num_single_quotes <= num_double_quotes) then
      quote_char = single_quote
    else
      quote_char = double_quote
    end

    return quote_char
  end

local quote_char_func =
  function(char)
    return str_format([[\%03d]], str_byte(char, 1, 1))
  end

local quote_string =
  function(str)
    local str_has_control_chars = has_control_chars(str)

    local use_variable_quotes =
      (
        has_backslashes(str) or
        has_newlines(str) or
        (has_single_quotes(str) and has_double_quotes(str))
      ) and
      not str_has_control_chars

    if use_variable_quotes then
      return quote_variable(str)
    else
      local quote_char = determine_fixed_quote_char(str)

      local quote_all = false
      local quote_control = false

      if str_has_control_chars then
        if binary_entities_lengths[#str] then
          quote_all = true
        else
          quote_control = true
        end
      end

      if quote_all then
        str = str_gsub(str, '.', quote_char_func)
      else
        local backslash = [[\]]

        str = str_gsub(str, backslash, backslash .. backslash)
        str = str_gsub(str, quote_char, backslash .. quote_char)

        if quote_control then
          str = str_gsub(str, '[%c]', quote_char_func)
        end
      end

      return quote_char .. str .. quote_char
    end
  end

-- Export:
return quote_string

--[[
  2016 #
  2017 #
  2024 #
  2026 #
  2026-07-11
]]
