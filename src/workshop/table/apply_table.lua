-- Apply values from another table to our table

--[[
  Author: Martin Eden
  Last mod.: 2026-07-11
]]

--[[
  Rules structure

    List of records with following structure

    {
      has_a [b] -- value A is present
      has_b [b] -- value B is present
      action [s] -- string with one of following values
        use_a -- keep value in A
        use_b -- replace value in A
    }
]]

local use_a_str = 'use_a'
local use_b_str = 'use_b'

--[[
  Return action name considering given inputs and set of rules

  If there is no rule for given condition then keep current value.
--]]
local get_action =
  function(has_a, has_b, Rules)
    for _, Rule in ipairs(Rules) do
      if (Rule.has_a == has_a) and (Rule.has_b == has_b) then
        return Rule.action
      end
    end

    return use_a_str
  end

-- Apply values to table A from table B following list of rules
local apply_table
apply_table =
  function(A, B, Rules)
    local Keys = { }
    do
      for a_key in pairs(A) do
        Keys[a_key] = true
      end

      for b_key in pairs(B) do
        Keys[b_key] = true
      end
    end

    for key in pairs(Keys) do
      local a_key = A[key]
      local b_key = B[key]

      local a_is_table = is_table(a_key)
      local b_is_table = is_table(b_key)

      if a_is_table and b_is_table then
        apply_table(a_key, b_key, Rules)
      else
        local has_a = not is_nil(a_key)
        local has_b = not is_nil(b_key)

        local action = get_action(has_a, has_b, Rules)

        if (action == use_b_str) then
          A[key] = B[key]
        end
      end
    end
  end

local check_rule =
  function(Rule)
    local has_a = is_boolean(Rule.has_a)
    local has_b = is_boolean(Rule.has_b)

    local action = Rule.action
    local is_known_action =
      (action == use_a_str) or (action == use_b_str)

    return has_a and has_b and is_known_action
  end

local apply_table_root =
  function(A, B, Rules)
    assert_table(A)
    assert_table(B)
    assert_table(Rules)

    -- Assert rules
    for index, Rule in ipairs(Rules) do
      if not check_rule(Rule) then
        error('Unsupported rule.')
      end
    end

    apply_table(A, B, Rules)
  end

-- Export:
return apply_table_root

--[[
  2026-04-30
  2026-07-11
]]
