_G.package.preload['serialize_lua_graph'] =
  function(...)
    require('workshop.base')
    return request('!.convert.table_to_str')
  end
_G.package.preload['workshop.base'] =
  function(...)
    local split_name =
      function(qualified_name)
        local prefix_name_pattern = '^(.+%.)([^%.]+)$'
        local prefix, name = qualified_name:match(prefix_name_pattern)
        if not prefix then
          prefix = ''
          name = qualified_name
          if not name:find('^([^%.]+)$') then
            name = ''
          end
        end
        return prefix, name
      end
    local unite_prefixes =
      function(base_prefix, rel_prefix)
        local init_base_prefix, init_rel_prefix =
          base_prefix, rel_prefix
        local list_without_tail_pattern = '(.+%.)[^%.]-%.$'
        local list_without_head_pattern = '[^%.]+%.(.+)$'
        while rel_prefix:find('^%^%.') do
          if (base_prefix == '') then
            error(
              ([[Link "%s" is outside of caller's prefix "%s".]]):format(
                init_rel_prefix, init_base_prefix
              )
            )
          end
          base_prefix =
            base_prefix:match(list_without_tail_pattern) or ''
          rel_prefix = rel_prefix:match(list_without_head_pattern) or ''
        end
        return base_prefix .. rel_prefix
      end
    local Names = {}
    local depth = 1
    local get_caller_prefix =
      function()
        local result = ''
        if Names[depth] then
          result = Names[depth].prefix
        end
        return result
      end
    local get_caller_name =
      function()
        local result = 'anonymous'
        if Names[depth] then
          result = Names[depth].prefix .. Names[depth].name
        end
        return result
      end
    local push =
      function(prefix, name)
        depth = depth + 1
        Names[depth] = { prefix = prefix, name = name }
      end
    local pop =
      function()
        depth = depth - 1
      end
    local Dependencies_Map = {}
    local add_dependency =
      function(src_name, dest_name)
        Dependencies_Map[src_name] = Dependencies_Map[src_name] or {}
        Dependencies_Map[src_name][dest_name] = true
      end
    local base_prefix = split_name((...))
    local get_require_name =
      function(qualified_name)
        local caller_prefix
        local is_absolute_name = (qualified_name:sub(1, 2) == '!.')
        if is_absolute_name then
          qualified_name = qualified_name:sub(3)
          caller_prefix = base_prefix
        else
          caller_prefix = get_caller_prefix()
        end
        local prefix, name = split_name(qualified_name)
        prefix = unite_prefixes(caller_prefix, prefix)
        return prefix .. name, prefix, name
      end
    local request =
      function(qualified_name)
        local src_name = get_caller_name()
        local require_name, prefix, name =
          get_require_name(qualified_name)
        push(prefix, name)
        local dest_name = get_caller_name()
        add_dependency(src_name, dest_name)
        local Results = table.pack(require(require_name))
        pop()
        return table.unpack(Results)
      end
    local is_first_run = (_G.request == nil)
    if is_first_run then
      _G.request = request
      _G.get_dependencies =
        function()
          return Dependencies_Map
        end
      _G.get_base_prefix =
        function()
          return base_prefix
        end
      _G.get_require_name = get_require_name
      local our_require_name = (...)
      push('', our_require_name)
      request('!.system.install_is_functions')()
      request('!.system.install_assert_functions')()
      _G.new = request('!.table.new')
      pop()
    end
  end
_G.package.preload['workshop.system.install_is_functions'] =
  function(...)
    local TypeNames = request('!.concepts.lua.TypeNames')
    local NumberTypeNames = request('!.concepts.lua.NumberTypeNames')
    local type_is =
      function(type_name)
        return
          function(val)
            return (type(val) == type_name)
          end
      end
    local number_is =
      function(type_name)
        return
          function(val)
            if not is_number(val) then
              return false
            end
            return (math.type(val) == type_name)
          end
      end
    local install_is_functions =
      function()
        for _, type_name in ipairs(TypeNames) do
          _G['is_' .. type_name] = type_is(type_name)
        end
        for _, math_type_name in ipairs(NumberTypeNames) do
          _G['is_' .. math_type_name] = number_is(math_type_name)
        end
      end
    return install_is_functions
  end
_G.package.preload['workshop.system.install_assert_functions'] =
  function(...)
    local TypeNames = request('!.concepts.lua.TypeNames')
    local NumberTypeNames = request('!.concepts.lua.NumberTypeNames')
    local spawn_assert_func =
      function(type_name)
        local checker = _G['is_' .. type_name]
        assert(checker)
        return
          function(val)
            if not checker(val) then
              local err_msg =
                string.format('assert_%s(%s)', type_name, tostring(val))
              error(err_msg)
            end
          end
      end
    local install_assert_funcs =
      function()
        for _, type_name in ipairs(TypeNames) do
          _G['assert_' .. type_name] = spawn_assert_func(type_name)
        end
        for _, number_type_name in ipairs(NumberTypeNames) do
          _G['assert_' .. number_type_name] =
            spawn_assert_func(number_type_name)
        end
      end
    return install_assert_funcs
  end
_G.package.preload['workshop.mechs.name_giver'] =
  function(...)
    local Interface =
      {
        names = {},
        counters =
          { ['function'] = 0, table = 0, thread = 0, userdata = 0 },
        templates =
          {
            ['function'] = 'f_%d',
            table = 'T_%d',
            thread = 'th_%d',
            userdata = 'u_%d',
          },
        give_name =
          function(self, obj)
            if not self.names[obj] then
              local obj_type = type(obj)
              if not self.counters[obj_type] then
                error(
                  ('Argument type "%s" is not supported for counting.'):format(
                    obj_type
                  ),
                  2
                )
              end
              self.counters[obj_type] = self.counters[obj_type] + 1
              self.names[obj] =
                (self.templates[obj_type]):format(
                  self.counters[obj_type]
                )
            end
            return self.names[obj]
          end,
      }
    return Interface
  end
_G.package.preload['workshop.mechs.graph.dfs'] =
  function(...)
    local dfs_class = request('dfs.interface')
    return
      function(graph, options)
        local dfs = new(dfs_class, options)
        dfs:run(graph)
        return dfs.nodes_status
      end
  end
_G.package.preload['workshop.mechs.graph.assembly_order'] =
  function(...)
    local dfs = request('dfs')
    return
      function(graph, options)
        options = options or {}
        local assembly_order_seq = {}
        options.handle_leave =
          function(node, node_rec, deep)
            assembly_order_seq[#assembly_order_seq + 1] = node
          end
        local node_recs = dfs(graph, options)
        return node_recs, assembly_order_seq
      end
  end
_G.package.preload['workshop.mechs.graph.dfs.get_children'] =
  function(...)
    local get_key_vals = request('!.table.get_key_vals')
    local compare_keys = request('!.table.ordered_pass.compare_keys')
    local get_children =
      function(self, node)
        local result = {}
        local key_vals = get_key_vals(node)
        local also_visit_keys = self.also_visit_keys
        for _, rec in ipairs(key_vals) do
          if is_table(rec.value) then
            result[#result + 1] = rec
          end
          if also_visit_keys and is_table(rec.key) then
            result[#result + 1] = { key = rec.key, value = rec.key }
          end
        end
        table.sort(result, compare_keys)
        return result
      end
    return get_children
  end
_G.package.preload['workshop.mechs.graph.dfs.dfs'] =
  function(...)
    return
      function(self, graph)
        self.nodes_status = {}
        local handle_discovery = self.handle_discovery
        local handle_leave = self.handle_leave
        local nodes_status = self.nodes_status
        local get_children = self.get_children
        local init_node_rec =
          function(node)
            nodes_status[node] = nodes_status[node] or { node = node }
          end
        local time = 0
        local dfs_visit
        local process =
          function(parent, parent_key, node, depth)
            init_node_rec(node)
            local node_rec = nodes_status[node]
            node_rec.refs = node_rec.refs or {}
            node_rec.refs[parent] = node_rec.refs[parent] or {}
            node_rec.refs[parent][parent_key] = true
            if not node_rec.color then
              node_rec.parent = parent
              node_rec.parent_key = parent_key
              dfs_visit(node, depth + 1)
            elseif (node_rec.color == 'gray') then
              node_rec.part_of_cycle = true
              nodes_status[parent].part_of_cycle = true
            end
          end
        dfs_visit =
          function(node, depth)
            time = time + 1
            local node_rec = nodes_status[node]
            node_rec.discovery_time = time
            node_rec.color = 'gray'
            handle_discovery(node, node_rec, depth)
            for _, child in ipairs(self:get_children(node)) do
              process(node, child.key, child.value, depth)
            end
            time = time + 1
            node_rec.color = 'black'
            node_rec.finish_time = time
            handle_leave(node, node_rec, depth)
          end
        init_node_rec(graph)
        dfs_visit(graph, 0)
      end
  end
_G.package.preload['workshop.mechs.graph.dfs.interface'] =
  function(...)
    local empty_func =
      function()
      end
    return
      {
        get_children = request('get_children'),
        handle_discovery = empty_func,
        handle_leave = empty_func,
        also_visit_keys = false,
        table_iterator = request('!.table.ordered_pass'),
        run = request('dfs'),
        nodes_status = {},
      }
  end
_G.package.preload['workshop.number.is_neg_inf'] =
  function(...)
    local is_neg_inf =
      function(n)
        return (n == -1 / 0)
      end
    return is_neg_inf
  end
_G.package.preload['workshop.number.is_pos_inf'] =
  function(...)
    local is_pos_inf =
      function(n)
        return (n == 1 / 0)
      end
    return is_pos_inf
  end
_G.package.preload['workshop.number.is_nan'] =
  function(...)
    local is_nan =
      function(n)
        return (n ~= n)
      end
    return is_nan
  end
_G.package.preload['workshop.table.clone'] =
  function(...)
    local cloned = {}
    local clone
    clone =
      function(node)
        if (type(node) == 'table') then
          if cloned[node] then
            return cloned[node]
          else
            local result = {}
            cloned[node] = result
            for k, v in pairs(node) do
              result[clone(k)] = clone(v)
            end
            setmetatable(result, getmetatable(node))
            return result
          end
        else
          return node
        end
      end
    return
      function(node)
        cloned = {}
        return clone(node)
      end
  end
_G.package.preload['workshop.table.new'] =
  function(...)
    local clone = request('clone')
    local patch = request('patch')
    return
      function(base_obj, overriden_params)
        assert_table(base_obj)
        local result = clone(base_obj)
        if is_table(overriden_params) then
          patch(result, overriden_params)
        end
        return result
      end
  end
_G.package.preload['workshop.table.patch'] =
  function(...)
    local apply_table = request('apply_table')
    local patch =
      function(Result, Additions)
        assert_table(Result)
        if is_nil(Additions) then
          return
        end
        assert_table(Additions)
        local Rules =
          {
            { HasA = true, HasB = true, Action = 'use_b' },
            { HasA = false, HasB = true, Action = 'use_a' },
          }
        apply_table(Result, Additions, Rules)
      end
    return patch
  end
_G.package.preload['workshop.table.map_values'] =
  function(...)
    local map_values =
      function(List)
        assert_table(List)
        local Result = {}
        for _, value in pairs(List) do
          Result[value] = true
        end
        return Result
      end
    return map_values
  end
_G.package.preload['workshop.table.create_instance'] =
  function(...)
    local clone = request('clone')
    local attach_methods = request('attach_methods')
    local create_instance =
      function(Data, Methods)
        assert_table(Data)
        assert_table(Methods)
        local Result
        Result = clone(Data)
        attach_methods(Result, Methods)
        return Result
      end
    return create_instance
  end
_G.package.preload['workshop.table.get_key_vals'] =
  function(...)
    return
      function(t)
        assert_table(t)
        local result = {}
        for k, v in pairs(t) do
          result[#result + 1] = { key = k, value = v }
        end
        return result
      end
  end
_G.package.preload['workshop.table.apply_table'] =
  function(...)
    local use_a_str = 'use_a'
    local use_b_str = 'use_b'
    local get_action =
      function(has_a, has_b, Rules)
        for _, Rule in ipairs(Rules) do
          local is_same_signature =
            (Rule.HasA == has_a) and (Rule.HasB == has_b)
          if is_same_signature then
            return Rule.Action
          end
        end
        return use_a_str
      end
    local apply_table
    apply_table =
      function(A, B, Rules)
        local a_type = type(A)
        local b_type = type(B)
        local Keys = {}
        do
          for a_key in pairs(A) do
            Keys[a_key] = true
          end
          for b_key in pairs(B) do
            Keys[b_key] = true
          end
        end
        for key in pairs(Keys) do
          local has_a = not is_nil(A[key])
          local has_b = not is_nil(B[key])
          local a_is_table = has_a and is_table(A[key])
          local b_is_table = has_b and is_table(B[key])
          if a_is_table and b_is_table then
            apply_table(A[key], B[key], Rules)
          else
            local action = get_action(has_a, has_b, Rules)
            if (action == use_a_str) then
            elseif (action == use_b_str) then
              A[key] = B[key]
            end
          end
        end
      end
    local check_rule =
      function(Rule)
        local has_a = is_boolean(Rule.HasA)
        local has_b = is_boolean(Rule.HasB)
        local action = Rule.Action
        local is_known_action =
          (action == use_a_str) or (action == use_b_str)
        return has_a, has_b, is_known_action
      end
    local apply_table_root =
      function(A, B, Rules)
        assert_table(A)
        assert_table(B)
        assert_table(Rules)
        for index, Rule in ipairs(Rules) do
          local has_a, has_b, is_known_action = check_rule(Rule)
          if not (has_a and has_b and is_known_action) then
            local err_msg =
              'Unsupported rule at index ' .. tostring(index)
            error(err_msg, 2)
          end
        end
        apply_table(A, B, Rules)
      end
    return apply_table_root
  end
_G.package.preload['workshop.table.ordered_pass'] =
  function(...)
    local get_key_vals = request('get_key_vals')
    local compare_keys = request('ordered_pass.compare_keys')
    local ordered_pass =
      function(t, comparator)
        assert_table(t)
        comparator = comparator or compare_keys
        assert_function(comparator)
        local key_vals = get_key_vals(t)
        table.sort(key_vals, comparator)
        local i = 0
        local sorted_next =
          function()
            i = i + 1
            if key_vals[i] then
              return key_vals[i].key, key_vals[i].value
            end
          end
        return sorted_next, t
      end
    return ordered_pass
  end
_G.package.preload['workshop.table.attach_methods'] =
  function(...)
    local attach_methods =
      function(Object, Methods)
        assert_table(Object)
        assert_table(Methods)
        local Metatable =
          {
            __index = Methods,
            __newindex =
              function()
                error('Table is locked for additions.')
              end,
          }
        setmetatable(Object, Metatable)
      end
    return attach_methods
  end
_G.package.preload['workshop.table.ordered_pass.compare_values'] =
  function(...)
    local TypeRank_Map = { ['number'] = 1, ['string'] = 2, other = 3 }
    local ComparableTypes_Map = { ['number'] = true, ['string'] = true }
    local compare_values =
      function(a, b)
        local type_a = type(a)
        local rank_a = TypeRank_Map[type_a] or TypeRank_Map.other
        local type_b = type(b)
        local rank_b = TypeRank_Map[type_b] or TypeRank_Map.other
        if (rank_a ~= rank_b) then
          return (rank_a < rank_b)
        end
        if
          ComparableTypes_Map[type_a] and ComparableTypes_Map[type_b]
        then
          return (a < b)
        end
        return (tostring(a) < tostring(b))
      end
    return compare_values
  end
_G.package.preload['workshop.table.ordered_pass.compare_keys'] =
  function(...)
    local compare_values = request('compare_values')
    local compare_keys =
      function(a, b)
        return compare_values(a.key, b.key)
      end
    return compare_keys
  end
_G.package.preload['workshop.string.content_attributes'] =
  function(...)
    local has_control_chars =
      function(s)
        return s:find('%c') and true
      end
    local has_backslashes =
      function(s)
        return s:find([[%\]]) and true
      end
    local has_single_quotes =
      function(s)
        return s:find([[%']]) and true
      end
    local has_double_quotes =
      function(s)
        return s:find([[%"]]) and true
      end
    local is_nonascii =
      function(s)
        return s:find('[^%w%s_%p]')
      end
    local has_newlines =
      function(s)
        return s:find('[\n\r]')
      end
    return
      {
        has_control_chars = has_control_chars,
        has_backslashes = has_backslashes,
        has_single_quotes = has_single_quotes,
        has_double_quotes = has_double_quotes,
        is_nonascii = is_nonascii,
        has_newlines = has_newlines,
      }
  end
_G.package.preload['workshop.convert.table_to_str'] =
  function(...)
    local StringOutputStream =
      request('!.concepts.StreamIo.Output.String')
    local graph_to_str = request('!.concepts.codec_lua_graph.compile')
    local table_to_str =
      function(Graph, Options)
        local StringStream = new(StringOutputStream)
        graph_to_str(Graph, StringStream, Options)
        return StringStream:GetString()
      end
    return table_to_str
  end
_G.package.preload['workshop.concepts.Indent'] =
  function(...)
    local create_instance = request('!.table.create_instance')
    local RangePoint = request('!.concepts.RangePoint')
    local RangePoint = RangePoint.create()
    RangePoint:SetMinValue(0)
    RangePoint:SetMaxValue(60)
    RangePoint:SetValue(RangePoint:GetMinValue())
    local Core = { '  ', RangePoint }
    local Interface
    Interface =
      {
        GetIndentChunk =
          function(Me)
            return Me[1]
          end,
        SetIndentChunk =
          function(Me, str)
            assert_string(str)
            Me[1] = str
          end,
        GetRangePoint =
          function(Me)
            return Me[2]
          end,
        ToString =
          function(Me)
            local indent_chunk = Me:GetIndentChunk()
            local indent_level = Me:GetRangePoint():GetValue()
            return string.rep(indent_chunk, indent_level)
          end,
        Inc =
          function(Me)
            Me:GetRangePoint():Inc()
          end,
        Dec =
          function(Me)
            Me:GetRangePoint():Dec()
          end,
        create =
          function(OptCore)
            return create_instance(OptCore or Core, Interface)
          end,
      }
    return Interface
  end
_G.package.preload['workshop.concepts.RangePoint'] =
  function(...)
    local create_instance = request('!.table.create_instance')
    local min = math.min
    local max = math.max
    local Core = { 0, 0, 5 }
    local Interface
    Interface =
      {
        GetCurValue =
          function(Me)
            return Me[1]
          end,
        SetCurValue =
          function(Me, val)
            Me[1] = val
          end,
        GetMinValue =
          function(Me)
            return Me[2]
          end,
        SetMinValue =
          function(Me, val)
            Me[2] = val
          end,
        GetMaxValue =
          function(Me)
            return Me[3]
          end,
        SetMaxValue =
          function(Me, val)
            Me[3] = val
          end,
        GetValue =
          function(Me)
            local cur_value = Me:GetCurValue()
            local min_value = Me:GetMinValue()
            local max_value = Me:GetMaxValue()
            return max(min(cur_value, max_value), min_value)
          end,
        SetValue =
          function(Me, arg_value)
            local cur_value
            local min_value = Me:GetMinValue()
            local max_value = Me:GetMaxValue()
            cur_value = max(min(arg_value, max_value), min_value)
            Me:SetCurValue(cur_value)
          end,
        IncBy =
          function(Me, value)
            Me:SetCurValue(Me:GetCurValue() + value)
          end,
        DecBy =
          function(Me, value)
            Me:SetCurValue(Me:GetCurValue() - value)
          end,
        Inc =
          function(Me)
            Me:IncBy(1)
          end,
        Dec =
          function(Me)
            Me:DecBy(1)
          end,
        create =
          function(OptCore)
            return create_instance(OptCore or Core, Interface)
          end,
      }
    return Interface
  end
_G.package.preload['workshop.concepts.lua.NumberTypeNames'] =
  function(...)
    local NumberTypeNames = { 'integer', 'float' }
    return NumberTypeNames
  end
_G.package.preload['workshop.concepts.lua.TypeNames'] =
  function(...)
    local TypeNames =
      {
        'nil',
        'boolean',
        'number',
        'string',
        'function',
        'thread',
        'userdata',
        'table',
      }
    return TypeNames
  end
_G.package.preload['workshop.concepts.lua.Keywords'] =
  function(...)
    local Keywords =
      {
        'nil',
        'true',
        'false',
        'not',
        'and',
        'or',
        'local',
        'do',
        'end',
        'goto',
        'if',
        'then',
        'elseif',
        'else',
        'while',
        'repeat',
        'until',
        'for',
        'in',
        'break',
        'function',
        'return',
      }
    return Keywords
  end
_G.package.preload['workshop.concepts.lua.is_identifier'] =
  function(...)
    local Keywords_Map
    do
      local Keywords = request('Keywords')
      local map_values = request('!.table.map_values')
      Keywords_Map = map_values(Keywords)
    end
    local is_identifier =
      function(str)
        return
          is_string(str) and
          string.match(str, '^[%a_][%w_]*$') and
          not Keywords_Map[str]
      end
    return is_identifier
  end
_G.package.preload['workshop.concepts.lua.serialize_terminal_value'] =
  function(...)
    local is_nan = request('!.number.is_nan')
    local is_pos_inf = request('!.number.is_pos_inf')
    local is_neg_inf = request('!.number.is_neg_inf')
    local lua_quote_str = request('!.concepts.lua.quote_string')
    local encode_bool =
      function(val)
        if (val == false) then
          return 'false'
        end
        if (val == true) then
          return 'true'
        end
      end
    local encode_number =
      function(val)
        if is_nan(val) then
          return '0/0'
        end
        if is_pos_inf(val) then
          return '1/0'
        end
        if is_neg_inf(val) then
          return '-1/0'
        end
        return _G.tostring(val)
      end
    local encode_string =
      function(val)
        return lua_quote_str(val)
      end
    local serialize_terminal_value =
      function(val)
        if is_nil(val) then
          return 'nil'
        elseif is_boolean(val) then
          return encode_bool(val)
        elseif is_number(val) then
          return encode_number(val)
        elseif is_string(val) then
          return encode_string(val)
        end
      end
    return serialize_terminal_value
  end
_G.package.preload['workshop.concepts.lua.quote_string'] =
  function(...)
    local quote_escaped = request('quote_string.linear')
    local quote_intact = request('quote_string.intact')
    local quote_aggressive = request('quote_string.dump')
    local content_funcs = request('!.string.content_attributes')
    local has_control_chars = content_funcs.has_control_chars
    local has_backslashes = content_funcs.has_backslashes
    local has_single_quotes = content_funcs.has_single_quotes
    local has_double_quotes = content_funcs.has_double_quotes
    local has_newlines = content_funcs.has_newlines
    local binary_entities_lengths =
      { [1] = true, [2] = true, [4] = true, [8] = true, [16] = true }
    return
      function(s)
        assert_string(s)
        local quote_func = quote_escaped
        if binary_entities_lengths[#s] and has_control_chars(s) then
          quote_func = quote_aggressive
        elseif
          has_backslashes(s) or
          has_newlines(s) or
          (has_single_quotes(s) and has_double_quotes(s))
        then
          quote_func = quote_intact
        end
        local result = quote_func(s)
        return result
      end
  end
_G.package.preload['workshop.concepts.lua.quote_string.intact'] =
  function(...)
    local has_newlines =
      request('!.string.content_attributes').has_newlines
    return
      function(s)
        assert_string(s)
        s = s .. ']'
        local eq_chunk = ''
        local postfix
        while true do
          postfix = ']' .. eq_chunk .. ']'
          if not s:find(postfix, 1, true) then
            break
          end
          eq_chunk = eq_chunk .. '='
        end
        local prefix = '[' .. eq_chunk .. '['
        local first_char = s:sub(1, 1)
        if (first_char == '\x0D') or (first_char == '\x0A') then
          prefix = prefix .. first_char
        end
        if has_newlines(s) then
          prefix = prefix .. '\x0A'
        end
        return prefix .. s .. eq_chunk .. ']'
      end
  end
_G.package.preload['workshop.concepts.lua.quote_string.linear'] =
  function(...)
    local quote_char = request('quote_char')
    local custom_quotes = request('custom_quotes')
    return
      function(s)
        local result = s
        result = result:gsub([[\]], quote_char)
        result = result:gsub('[%c]', quote_char)
        local cnt_q1 = 0
        for i in result:gmatch("'") do
          cnt_q1 = cnt_q1 + 1
        end
        local cnt_q2 = 0
        for i in result:gmatch('"') do
          cnt_q2 = cnt_q2 + 1
        end
        if (cnt_q1 <= cnt_q2) then
          result = "'" .. result:gsub("'", custom_quotes["'"]) .. "'"
        else
          result = '"' .. result:gsub('"', custom_quotes['"']) .. '"'
        end
        return result
      end
  end
_G.package.preload['workshop.concepts.lua.quote_string.dump'] =
  function(...)
    local quote_char = request('quote_char')
    return
      function(s)
        assert_string(s)
        return "'" .. s:gsub('.', quote_char) .. "'"
      end
  end
_G.package.preload['workshop.concepts.lua.quote_string.quote_char'] =
  function(...)
    return
      function(c)
        return ([[\x%02X]]):format(c:byte(1, 1))
      end
  end
_G.package.preload['workshop.concepts.lua.quote_string.custom_quotes'] =
  function(...)
    return
      {
        ['\x07'] = [[\a]],
        ['\x08'] = [[\b]],
        ['\x09'] = [[\t]],
        ['\x0a'] = [[\n]],
        ['\x0b'] = [[\v]],
        ['\x0c'] = [[\f]],
        ['\x0d'] = [[\r]],
        ['"'] = [[\"]],
        ["'"] = [[\']],
        ['\\'] = [[\\]],
      }
  end
_G.package.preload['workshop.concepts.list.to_string'] =
  function(...)
    local to_string =
      function(List, separator_str)
        assert_table(List)
        separator_str = separator_str or ''
        assert_string(separator_str)
        return table.concat(List, separator_str)
      end
    return to_string
  end
_G.package.preload['workshop.concepts.list.add_item'] =
  function(...)
    local add_item =
      function(OurList, item)
        table.insert(OurList, item)
      end
    return add_item
  end
_G.package.preload['workshop.concepts.codec_lua_graph.compile'] =
  function(...)
    local ordered_pass = request('!.table.ordered_pass')
    local get_ast = request('compile.get_ast')
    local GraphSerializer = request('compile.GraphSerializer')
    local formatter_minimal = request('compile.Formatters.minimal')
    local formatter_readable_short =
      request('compile.Formatters.readable_short')
    local formatter_readable_long =
      request('compile.Formatters.readable_long')
    local set_style =
      function(style_str, GraphSerializer)
        local Formaters_Map =
          {
            ['minimal'] = formatter_minimal,
            ['readable_short'] = formatter_readable_short,
            ['readable_long'] = formatter_readable_long,
          }
        local formatter = Formaters_Map[style_str]
        if not is_function(formatter) then
          error('No formatter for given style.')
        end
        formatter(GraphSerializer.Config)
      end
    local original_stream_write
    local last_char = ''
    local write_avoiding_syntax_clash =
      function(Output, str)
        local next_char = string.sub(str, 1, 1)
        if (last_char == '[') and (next_char == '[') then
          original_stream_write(Output, ' ')
        end
        original_stream_write(Output, str)
        last_char = string.sub(str, -1)
      end
    local DefaultOptions =
      { style = 'readable_long', table_iterator = ordered_pass }
    local set_field =
      function(BaseTable, OptTable, field_name)
        if not is_table(OptTable) then
          return
        end
        if is_nil(OptTable[field_name]) then
          return
        end
        BaseTable[field_name] = OptTable[field_name]
      end
    local compile =
      function(Graph, Output, ArgOptions)
        assert_table(Graph)
        local Options = new(DefaultOptions, ArgOptions)
        local style = Options.style
        local table_iterator = Options.table_iterator
        local Ast = get_ast(Graph, table_iterator)
        original_stream_write = Output.Write
        Output.Write = write_avoiding_syntax_clash
        do
          local GraphSerializer = new(GraphSerializer)
          local Config = GraphSerializer.Config
          Config.Output = Output
          set_style(style, GraphSerializer)
          set_field(Config, ArgOptions, 'use_compact_indices')
          set_field(Config, ArgOptions, 'use_compact_sequences')
          set_field(Config, ArgOptions, 'omit_tail_delimiter')
          GraphSerializer:SerializeGraph(Ast, Output)
        end
        Output.Write = original_stream_write
      end
    return compile
  end
_G.package.preload['workshop.concepts.codec_lua_graph.compile.get_ast'] =
  function(...)
    local NameGiver = request('!.mechs.name_giver')
    local get_assembly_order = request('!.mechs.graph.assembly_order')
    local add_to_list = request('!.concepts.list.add_item')
    local create_name_rec =
      function(name)
        return { 'name', name }
      end
    local create_terminal_type_rec =
      function(data)
        return { type(data), data }
      end
    local create_table_rec =
      function()
        return { 'table', {} }
      end
    local create_local_def_rec =
      function(name, Value)
        return { 'local_definition', name, Value }
      end
    local create_assignment_rec =
      function(dest, index, value)
        return { 'assignment', dest, index, value }
      end
    local create_return_rec =
      function(Value)
        return { 'return_statement', Value }
      end
    local tree_get_ast =
      function(Data, table_iterator, NamedNodes_Map)
        local create_ast
        create_ast =
          function(Data)
            if NamedNodes_Map[Data] then
              return create_name_rec(NamedNodes_Map[Data])
            end
            if not is_table(Data) then
              return create_terminal_type_rec(Data)
            end
            local Result = create_table_rec()
            local KeyVals = Result[2]
            for Key, Value in table_iterator(Data) do
              add_to_list(
                KeyVals, { create_ast(Key), create_ast(Value) }
              )
            end
            return Result
          end
        return create_ast(Data)
      end
    local get_num_refs =
      function(NodeRec)
        local num_refs = 0
        if NodeRec.refs then
          local Node = NodeRec.Node
          for parent, parent_keys in pairs(NodeRec.refs) do
            if (parent == Node) then
              num_refs = num_refs + 1
            end
            for key in pairs(parent_keys) do
              if (parent[key] == Node) then
                num_refs = num_refs + 1
              end
              if (key == Node) then
                num_refs = num_refs + 1
              end
            end
          end
        end
        return num_refs
      end
    local may_print_inline =
      function(NodeRec)
        return
          not NodeRec or
          ((get_num_refs(NodeRec) <= 1) and not NodeRec.part_of_cycle)
      end
    local get_ast =
      function(Data, table_iterator)
        local NameGiver = new(NameGiver)
        local NodeRecs, OrderedNodes =
          get_assembly_order(
            Data,
            { also_visit_keys = true, table_iterator = table_iterator }
          )
        local Result = {}
        local ProcessedTables = {}
        local ValueNames = {}
        for _, Node in ipairs(OrderedNodes) do
          local NodeRec = NodeRecs[Node]
          if not may_print_inline(NodeRec) or (Node == Data) then
            local TableRec
            if NodeRec.part_of_cycle then
              TableRec = create_table_rec()
              local KeyVals = TableRec[2]
              for k, v in table_iterator(Node) do
                local key_is_ok = not is_table(k) or ProcessedTables[k]
                local value_is_ok =
                  not is_table(v) or ProcessedTables[v]
                if key_is_ok and value_is_ok then
                  add_to_list(
                    KeyVals,
                    {
                      tree_get_ast(k, table_iterator, ValueNames),
                      tree_get_ast(v, table_iterator, ValueNames),
                    }
                  )
                end
              end
            else
              TableRec = tree_get_ast(Node, table_iterator, ValueNames)
            end
            local node_name = NameGiver:give_name(Node)
            ValueNames[Node] = node_name
            add_to_list(
              Result, create_local_def_rec(node_name, TableRec)
            )
          end
          ProcessedTables[Node] = true
          if NodeRec.part_of_cycle then
            for Parent, ParentKeys in pairs(NodeRec.refs) do
              if ProcessedTables[Parent] then
                for parent_key in pairs(ParentKeys) do
                  local key_slot =
                    tree_get_ast(parent_key, table_iterator, ValueNames)
                  add_to_list(
                    Result,
                    create_assignment_rec(
                      ValueNames[Parent], key_slot, ValueNames[Node]
                    )
                  )
                end
              end
            end
          end
        end
        add_to_list(
          Result, create_return_rec(create_name_rec(ValueNames[Data]))
        )
        local prelast_type = Result[#Result - 1][1]
        if (prelast_type == 'local_definition') then
          local prelast_value = Result[#Result - 1][3]
          table.remove(Result)
          table.remove(Result)
          add_to_list(Result, create_return_rec(prelast_value))
        end
        return Result
      end
    return get_ast
  end
_G.package.preload[
  'workshop.concepts.codec_lua_graph.compile.GraphSerializer'
] =
  function(...)
    local serialize_terminal_value =
      request('!.concepts.lua.serialize_terminal_value')
    local is_identifier = request('!.concepts.lua.is_identifier')
    local SerializeValue =
      function(Me, Node, Output)
        local node_type = Node[1]
        local node_value = Node[2]
        if (node_type == 'name') then
          Output:Write(node_value)
        elseif (node_type == 'table') then
          Me:SerializeTree(Node, Output)
        else
          local val_str = serialize_terminal_value(node_value)
          if is_nil(val_str) then
            val_str = serialize_terminal_value(_G.tostring(node_value))
          end
          Output:Write(val_str)
        end
      end
    local SerializeTree =
      function(Me, TableAst, Output)
        local empty_table_str = Me.Config.empty_table_str
        local opening_table_str = Me.Config.opening_table_str
        local closing_table_str = Me.Config.closing_table_str
        local equal_str = Me.Config.equal_str
        local delimiter_str = Me.Config.delimiter_str
        local use_compact_sequences = Me.Config.use_compact_sequences
        local use_compact_indices = Me.Config.use_compact_indices
        local omit_tail_delimiter = Me.Config.omit_tail_delimiter
        local notify = Me.Config.notify
        local KeyVals = TableAst[2]
        if (#KeyVals == 0) then
          Output:Write(empty_table_str)
          return
        end
        notify('start_table', Output)
        Output:Write(opening_table_str)
        local last_integer_key = 0
        for index, KeyVal_Rec in ipairs(KeyVals) do
          local is_first_rec = (index == 1)
          if not is_first_rec then
            notify('items_delimiter', Output)
            Output:Write(delimiter_str)
          end
          notify('processing_item', Output)
          local Key = KeyVal_Rec[1]
          local Value = KeyVal_Rec[2]
          local key_type = Key[1]
          local key_value = Key[2]
          local brackets_not_required
          local skip_key_serialization =
            use_compact_sequences and
            (
              (key_type == 'number') and
              (key_value == last_integer_key + 1)
            )
          if skip_key_serialization then
            last_integer_key = key_value
            goto serialize_value
          end
          brackets_not_required =
            use_compact_indices and
            ((key_type == 'string') and is_identifier(key_value))
          if brackets_not_required then
            Output:Write(key_value)
          else
            Output:Write('[')
            Me:SerializeValue(Key, Output)
            Output:Write(']')
          end
          Output:Write(equal_str)
          ::serialize_value::
          Me:SerializeValue(Value, Output)
        end
        if not omit_tail_delimiter then
          notify('items_delimiter', Output)
          Output:Write(delimiter_str)
        end
        notify('end_table', Output)
        Output:Write(closing_table_str)
      end
    local SerializeGraph =
      function(Me, GraphAst, Output)
        local Output = Me.Config.Output
        local use_compact_indices = Me.Config.use_compact_indices
        local equal_str = Me.Config.equal_str
        for index, Rec in ipairs(GraphAst) do
          local rec_type = Rec[1]
          if (rec_type == 'local_definition') then
            local name = Rec[2]
            local Value = Rec[3]
            Output:Write('local')
            Output:Write(' ')
            Output:Write(name)
            Output:Write(equal_str)
            Me:SerializeValue(Value, Output)
            Output:Write('\n')
          elseif (rec_type == 'assignment') then
            local dest_name = Rec[2]
            local Key = Rec[3]
            local src_name = Rec[4]
            local key_type = Key[1]
            local key_value = Key[2]
            local brackets_not_required =
              use_compact_indices and
              ((key_type == 'string') and is_identifier(key_value))
            Output:Write(dest_name)
            if brackets_not_required then
              Output:Write('.')
              Output:Write(key_value)
            else
              Output:Write('[')
              Me:SerializeValue(Key, Output)
              Output:Write(']')
            end
            Output:Write(equal_str)
            Output:Write(src_name)
            Output:Write('\n')
          elseif (rec_type == 'return_statement') then
            local Value = Rec[2]
            Output:Write('return')
            Output:Write(' ')
            Me:SerializeValue(Value, Output)
            Output:Write('\n')
          end
        end
      end
    local Interface =
      {
        SerializeGraph = SerializeGraph,
        Config =
          {
            use_compact_indices = true,
            use_compact_sequences = true,
            omit_tail_delimiter = true,
            empty_table_str = '{}',
            opening_table_str = '{',
            closing_table_str = '}',
            delimiter_str = ',',
            equal_str = '=',
            notify =
              function(event_name, Output)
              end,
          },
        SerializeValue = SerializeValue,
        SerializeTree = SerializeTree,
      }
    return Interface
  end
_G.package.preload[
  'workshop.concepts.codec_lua_graph.compile.Formatters.readable_long'
] =
  function(...)
    local Indent = request('!.concepts.Indent')
    local patch_table = request('!.table.patch')
    Indent = Indent.create()
    local emit_indent =
      function(Output)
        Output:Write('\n')
        if (Indent:GetRangePoint():GetValue() == 0) then
          return
        end
        Output:Write(Indent:ToString())
      end
    local prev_event_name = 'nothing'
    local on_notify =
      function(next_event_name, Output)
        if (next_event_name == 'start_table') then
          Indent:Inc()
        elseif (next_event_name == 'end_table') then
          Indent:Dec()
        end
        if
          (
            (prev_event_name == 'start_table') and
            (next_event_name ~= 'end_table')
          ) or
          (prev_event_name == 'items_delimiter') or
          (
            (prev_event_name ~= 'start_table') and
            (next_event_name == 'end_table')
          )
        then
          emit_indent(Output)
        end
        prev_event_name = next_event_name
      end
    local install =
      function(Config)
        patch_table(
          Config,
          {
            use_compact_indices = true,
            use_compact_sequences = false,
            omit_tail_delimiter = false,
            empty_table_str = '{ }',
            opening_table_str = '{',
            closing_table_str = '}',
            delimiter_str = ',',
            equal_str = ' = ',
            notify = on_notify,
          }
        )
      end
    return install
  end
_G.package.preload[
  'workshop.concepts.codec_lua_graph.compile.Formatters.readable_short'
] =
  function(...)
    local patch_table = request('!.table.patch')
    local install =
      function(Config)
        patch_table(
          Config,
          {
            use_compact_indices = true,
            use_compact_sequences = true,
            omit_tail_delimiter = true,
            empty_table_str = '{ }',
            opening_table_str = '{ ',
            closing_table_str = ' }',
            delimiter_str = ', ',
            equal_str = ' = ',
          }
        )
      end
    return install
  end
_G.package.preload[
  'workshop.concepts.codec_lua_graph.compile.Formatters.minimal'
] =
  function(...)
    local patch_table = request('!.table.patch')
    local install =
      function(Config)
        patch_table(
          Config,
          {
            use_compact_indices = true,
            use_compact_sequences = true,
            omit_tail_delimiter = true,
            empty_table_str = '{}',
            opening_table_str = '{',
            closing_table_str = '}',
            delimiter_str = ',',
            equal_str = '=',
          }
        )
      end
    return install
  end
_G.package.preload['workshop.concepts.StreamIo.Output.String'] =
  function(...)
    local list_add_item = request('!.concepts.list.add_item')
    local list_to_string = request('!.concepts.list.to_string')
    local Interface =
      {
        Write =
          function(Me, data_str)
            assert_string(data_str)
            assert(data_str ~= '')
            list_add_item(Me.Chunks, data_str)
          end,
        GetString =
          function(Me)
            return list_to_string(Me.Chunks)
          end,
        Chunks = {},
      }
    return Interface
  end
return require('serialize_lua_graph')