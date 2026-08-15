package.preload['serialize_lua_graph'] =
  function(...)
    require('workshop.base')
    return request('!.convert.table_to_str')
  end
package.preload['workshop.base'] =
  function(...)
    local split_name =
      function(qualified_name)
        local prefix_name_pattern = '^(.+%.)([^%.]+)$'
        local prefix, name =
          string.match(qualified_name, prefix_name_pattern)
        if not prefix then
          prefix = ''
          if string.find(qualified_name, '%.') then
            name = ''
          else
            name = qualified_name
          end
        end
        return prefix, name
      end
    local unite_prefixes =
      function(base_prefix, rel_prefix)
        local uplevel_capture = '(.+%.)[^%.]-%.$'
        while (string.sub(rel_prefix, 1, 2) == '^.') do
          if (base_prefix == '') then
            error("Link is outside of caller's prefix.")
          end
          base_prefix = string.match(base_prefix, uplevel_capture) or ''
          rel_prefix = string.sub(rel_prefix, 3)
        end
        return base_prefix .. rel_prefix
      end
    local Names = {}
    local depth = 1
    local get_caller_prefix =
      function()
        local NameRec = Names[depth]
        if not NameRec then
          return ''
        end
        return NameRec.prefix
      end
    local get_caller_name =
      function()
        local NameRec = Names[depth]
        if not NameRec then
          return 'anonymous'
        end
        return NameRec.prefix .. NameRec.name
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
        local is_absolute_name =
          (string.sub(qualified_name, 1, 2) == '!.')
        if is_absolute_name then
          qualified_name = string.sub(qualified_name, 3)
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
package.preload['workshop.system.install_is_functions'] =
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
package.preload['workshop.system.install_assert_functions'] =
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
package.preload['workshop.mechs.name_giver'] =
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
package.preload['workshop.mechs.graph.dfs'] =
  function(...)
    local dfs_class = request('dfs.interface')
    return
      function(graph, options)
        local dfs = new(dfs_class, options)
        dfs:run(graph)
        return dfs.nodes_status
      end
  end
package.preload['workshop.mechs.graph.assembly_order'] =
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
package.preload['workshop.mechs.graph.dfs.get_children'] =
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
package.preload['workshop.mechs.graph.dfs.dfs'] =
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
package.preload['workshop.mechs.graph.dfs.interface'] =
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
package.preload['workshop.number.is_neg_inf'] =
  function(...)
    local is_neg_inf =
      function(n)
        return (n == -1 / 0)
      end
    return is_neg_inf
  end
package.preload['workshop.number.get_bits'] =
  function(...)
    local assert_bit_offs = request('assert_bit_offs')
    local get_bits =
      function(n, start_offs, end_offs)
        assert_integer(n)
        assert_bit_offs(start_offs)
        assert_bit_offs(end_offs)
        assert(start_offs <= end_offs)
        local mask
        mask = (1 << (end_offs + 1)) - 1
        mask = mask & ~((1 << start_offs) - 1)
        return (n & mask) >> start_offs
      end
    return get_bits
  end
package.preload['workshop.number.is_pos_inf'] =
  function(...)
    local is_pos_inf =
      function(n)
        return (n == 1 / 0)
      end
    return is_pos_inf
  end
package.preload['workshop.number.is_nan'] =
  function(...)
    local is_nan =
      function(n)
        return (n ~= n)
      end
    return is_nan
  end
package.preload['workshop.number.assert_byte'] =
  function(...)
    local is_byte = request('is_byte')
    return
      function(v)
        assert(is_byte(v))
      end
  end
package.preload['workshop.number.is_byte'] =
  function(...)
    local get_bits = request('get_bits')
    local is_byte =
      function(value)
        if not is_integer(value) then
          return false
        end
        return (value == get_bits(value, 0, 7))
      end
    return is_byte
  end
package.preload['workshop.number.assert_bit_offs'] =
  function(...)
    return
      function(offs)
        assert_integer(offs)
        assert((offs >= 0) and (offs <= 63))
      end
  end
package.preload['workshop.table.clone'] =
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
package.preload['workshop.table.new'] =
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
package.preload['workshop.table.patch'] =
  function(...)
    local apply_table = request('apply_table')
    local Rules = { { has_a = true, has_b = true, action = 'replace' } }
    local patch =
      function(Result, Additions)
        apply_table(Result, Additions, Rules)
      end
    return patch
  end
package.preload['workshop.table.invert'] =
  function(...)
    return
      function(Table)
        assert_table(Table)
        local Result = {}
        for Key, Value in pairs(Table) do
          Result[Value] = Key
        end
        return Result
      end
  end
package.preload['workshop.table.map_values'] =
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
package.preload['workshop.table.create_instance'] =
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
package.preload['workshop.table.get_key_vals'] =
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
package.preload['workshop.table.apply_table'] =
  function(...)
    local keep_str = 'keep'
    local replace_str = 'replace'
    local remove_str = 'remove'
    local get_action =
      function(has_a, has_b, Rules)
        for _, Rule in ipairs(Rules) do
          if (Rule.has_a == has_a) and (Rule.has_b == has_b) then
            return Rule.action
          end
        end
        return keep_str
      end
    local apply_table
    apply_table =
      function(A, B, Rules)
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
          local a_key = A[key]
          local b_key = B[key]
          if is_table(a_key) and is_table(b_key) then
            apply_table(a_key, b_key, Rules)
          else
            local has_a = not is_nil(a_key)
            local has_b = not is_nil(b_key)
            local action = get_action(has_a, has_b, Rules)
            if (action == keep_str) then
              ;
            elseif (action == replace_str) then
              A[key] = B[key]
            elseif (action == remove_str) then
              A[key] = nil
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
          (action == keep_str) or
          (action == replace_str) or
          (action == remove_str)
        return has_a and has_b and is_known_action
      end
    local apply_table_root =
      function(A, B, Rules)
        assert_table(A)
        assert_table(B)
        assert_table(Rules)
        assert(A ~= B)
        for index, Rule in ipairs(Rules) do
          if not check_rule(Rule) then
            error('Unsupported rule.')
          end
        end
        apply_table(A, B, Rules)
      end
    return apply_table_root
  end
package.preload['workshop.table.ordered_pass'] =
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
package.preload['workshop.table.attach_methods'] =
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
                error('Table is locked for additions/removals.')
              end,
          }
        setmetatable(Object, Metatable)
      end
    return attach_methods
  end
package.preload['workshop.table.ordered_pass.compare_values'] =
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
package.preload['workshop.table.ordered_pass.compare_keys'] =
  function(...)
    local compare_values = request('compare_values')
    local compare_keys =
      function(a, b)
        return compare_values(a.key, b.key)
      end
    return compare_keys
  end
package.preload['workshop.string.get_chars_count'] =
  function(...)
    local str_sub = string.sub
    local str_byte = string.byte
    local get_chars_count =
      function(str)
        local UsedChars_Map = {}
        for index = 1, #str do
          local char = str_sub(str, index, index)
          local code = str_byte(char)
          if is_nil(UsedChars_Map[code]) then
            UsedChars_Map[code] = 0
          end
          UsedChars_Map[code] = UsedChars_Map[code] + 1
        end
        return UsedChars_Map
      end
    return get_chars_count
  end
package.preload['workshop.convert.table_to_str'] =
  function(...)
    local StringOutputStream =
      request('!.concepts.StreamIo.Output.String')
    local compile_graph =
      request('!.concepts.codec_lua_graph.compile_graph')
    local table_to_str =
      function(Graph, Options)
        local StringStream = new(StringOutputStream)
        compile_graph(Graph, StringStream, Options)
        return StringStream:GetString()
      end
    return table_to_str
  end
package.preload['workshop.concepts.Indent'] =
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
package.preload['workshop.concepts.RangePoint'] =
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
package.preload['workshop.concepts.lua.NumberTypeNames'] =
  function(...)
    local NumberTypeNames = { 'integer', 'float' }
    return NumberTypeNames
  end
package.preload['workshop.concepts.lua.TypeNames'] =
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
package.preload['workshop.concepts.lua.Keywords'] =
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
package.preload['workshop.concepts.lua.is_identifier'] =
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
package.preload['workshop.concepts.lua.serialize_terminal_value'] =
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
package.preload['workshop.concepts.lua.QuoteChars'] =
  function(...)
    local QuoteChars
    do
      local AsciiCodes = request('!.concepts.Ascii.Codes')
      local AsciiChars = request('!.concepts.Ascii.Chars')
      QuoteChars =
        {
          single_quote_code = AsciiCodes.single_quote,
          double_quote_code = AsciiCodes.double_quote,
          backslash_code = AsciiCodes.backslash,
          single_quote = AsciiChars.single_quote,
          double_quote = AsciiChars.double_quote,
          backslash = AsciiChars.backslash,
        }
    end
    return QuoteChars
  end
package.preload['workshop.concepts.lua.quote_string'] =
  function(...)
    local newline_code
    do
      local AsciiCodes = request('!.concepts.Ascii.Codes')
      newline_code = AsciiCodes.newline
    end
    local BinaryEntitiesLengths_Map =
      {
        [1 << 0] = true,
        [1 << 1] = true,
        [1 << 2] = true,
        [1 << 3] = true,
      }
    local single_quote_code
    local double_quote_code
    local backslash_code
    local single_quote
    local double_quote
    local backslash
    do
      local QuoteChars = request('QuoteChars')
      single_quote_code = QuoteChars.single_quote_code
      double_quote_code = QuoteChars.double_quote_code
      backslash_code = QuoteChars.backslash_code
      single_quote = QuoteChars.single_quote
      double_quote = QuoteChars.double_quote
      backslash = QuoteChars.backslash
    end
    local has_messy_control_chars
    do
      local is_control_code =
        request('!.concepts.Ascii.is_control_code')
      has_messy_control_chars =
        function(UsedChars)
          for code in pairs(UsedChars) do
            if is_control_code(code) and (code ~= newline_code) then
              return true
            end
          end
          return false
        end
    end
    local determine_fixed_quote_char =
      function(UsedChars)
        local num_single_quotes = UsedChars[single_quote_code] or 0
        local num_double_quotes = UsedChars[double_quote_code] or 0
        if (num_single_quotes <= num_double_quotes) then
          return single_quote
        else
          return double_quote
        end
      end
    local get_chars_count = request('!.string.get_chars_count')
    local quote_variable = request('quote_string.intact')
    local quote_char_func = request('quote_string.quote_char')
    local str_gsub = string.gsub
    return
      function(str)
        local UsedChars_Map = get_chars_count(str)
        local str_has_messy_control_chars =
          has_messy_control_chars(UsedChars_Map)
        local str_has_messy_printable_chars =
          UsedChars_Map[newline_code] or
          UsedChars_Map[backslash_code] or
          (
            UsedChars_Map[single_quote_code] and
            UsedChars_Map[double_quote_code]
          )
        local use_variable_quotes =
          str_has_messy_printable_chars and
          not str_has_messy_control_chars
        if use_variable_quotes then
          return quote_variable(str)
        else
          local quote_char = determine_fixed_quote_char(UsedChars_Map)
          local quote_all = false
          local quote_control = false
          if str_has_messy_control_chars then
            if BinaryEntitiesLengths_Map[#str] then
              quote_all = true
            else
              quote_control = true
            end
          end
          if quote_all then
            str = str_gsub(str, '.', quote_char_func)
          else
            str = str_gsub(str, backslash, backslash .. backslash)
            str = str_gsub(str, quote_char, backslash .. quote_char)
            if quote_control then
              str = str_gsub(str, '[%c]', quote_char_func)
            end
          end
          return quote_char .. str .. quote_char
        end
      end
  end
package.preload['workshop.concepts.lua.quote_string.intact'] =
  function(...)
    local opening_bracket
    local closing_bracket
    local filler_char
    local newline_char
    local return_char
    do
      local AsciiChars = request('!.concepts.Ascii.Chars')
      opening_bracket = AsciiChars.opening_bracket
      closing_bracket = AsciiChars.closing_bracket
      filler_char = AsciiChars.equals
      newline_char = AsciiChars.newline
      return_char = AsciiChars.carriage_return
    end
    local str_find = string.find
    local str_sub = string.sub
    return
      function(str)
        str = str .. closing_bracket
        local filler_chunk = ''
        do
          while true do
            local postfix =
              closing_bracket .. filler_chunk .. closing_bracket
            if not str_find(str, postfix) then
              break
            end
            filler_chunk = filler_chunk .. filler_char
          end
        end
        local prefix =
          opening_bracket .. filler_chunk .. opening_bracket
        local first_char = str_sub(str, 1, 1)
        local first_char_is_newline =
          (first_char == newline_char) or (first_char == return_char)
        if first_char_is_newline then
          prefix = prefix .. first_char
        end
        local has_newlines = not is_nil(str_find(str, newline_char))
        if has_newlines and not first_char_is_newline then
          prefix = prefix .. newline_char
        end
        return prefix .. str .. filler_chunk .. closing_bracket
      end
  end
package.preload['workshop.concepts.lua.quote_string.quote_char'] =
  function(...)
    local quote_char_fmt = [[\%03d]]
    local str_byte = string.byte
    local str_format = string.format
    return
      function(char)
        return str_format(quote_char_fmt, str_byte(char))
      end
  end
package.preload['workshop.concepts.list.to_string'] =
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
package.preload['workshop.concepts.list.add_item'] =
  function(...)
    local add_item =
      function(OurList, item)
        table.insert(OurList, item)
      end
    return add_item
  end
package.preload['workshop.concepts.codec_lua_graph.compile_graph'] =
  function(...)
    local wrap_output
    local unwrap_output
    local configure_style
    do
      local Initializer = request('compile.Initializer')
      wrap_output = Initializer.wrap_output
      unwrap_output = Initializer.unwrap_output
      configure_style = Initializer.configure_style
    end
    local get_ast = request('compile.get_graph_ast')
    local serialize_ast = request('compile.serialize_graph_ast')
    local compile_graph =
      function(Graph, Output, Options)
        assert_table(Graph)
        Options = Options or {}
        local original_write = wrap_output(Output)
        do
          local Settings = {}
          configure_style(Settings, Output, Options)
          serialize_ast(Settings, get_ast(Graph))
        end
        unwrap_output(Output, original_write)
      end
    return compile_graph
  end
package.preload[
  'workshop.concepts.codec_lua_graph.compile.serialize_tree_ast'
] =
  function(...)
    local type_name
    local type_table
    local type_number
    local type_string
    do
      local TypeNames = request('Ast.TypeNames')
      type_name = TypeNames.type_name
      type_table = TypeNames.type_table
      type_number = TypeNames.type_number
      type_string = TypeNames.type_string
    end
    local serialize_value
    local serialize_tree
    do
      local serialize_terminal_value =
        request('!.concepts.lua.serialize_terminal_value')
      serialize_value =
        function(Settings, Ast)
          local Output = Settings.Output
          local type = Ast[1]
          local value = Ast[2]
          if (type == type_name) then
            Output:Write(value)
          elseif (type == type_table) then
            serialize_tree(Settings, Ast)
          else
            local val_str = serialize_terminal_value(value)
            if is_nil(val_str) then
              val_str = serialize_terminal_value(tostring(value))
            end
            Output:Write(val_str)
          end
        end
    end
    do
      local is_identifier = request('!.concepts.lua.is_identifier')
      serialize_tree =
        function(Settings, TableAst)
          local Output = Settings.Output
          local Write = Settings.Writer
          local use_compact_sequences = Settings.use_compact_sequences
          local use_compact_indices = Settings.use_compact_indices
          local omit_tail_delimiter = Settings.omit_tail_delimiter
          local notify = Settings.notify
          local KeyVals = TableAst[2]
          if (#KeyVals == 0) then
            Write:EmptyTable()
            return
          end
          notify('start_table', Output)
          Write:StartTable()
          local last_integer_key = 0
          for index, KeyVal_Rec in ipairs(KeyVals) do
            local is_first_rec = (index == 1)
            if not is_first_rec then
              notify('items_delimiter', Output)
              Write:SeparateItem()
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
                (key_type == type_number) and
                (key_value == last_integer_key + 1)
              )
            if skip_key_serialization then
              last_integer_key = key_value
              goto serialize_value
            end
            brackets_not_required =
              use_compact_indices and
              ((key_type == type_string) and is_identifier(key_value))
            if brackets_not_required then
              Output:Write(key_value)
            else
              Write:StartIndex()
              serialize_value(Settings, Key)
              Write:EndIndex()
            end
            Write:Assign()
            ::serialize_value::
            serialize_value(Settings, Value)
          end
          if not omit_tail_delimiter then
            notify('items_delimiter', Output)
            Write:SeparateItem()
          end
          notify('end_table', Output)
          Write:EndTable()
        end
    end
    return serialize_value
  end
package.preload['workshop.concepts.codec_lua_graph.compile.Initializer'] =
  function(...)
    local configure_style
    do
      local KnownStyles =
        {
          [1] = 'minimal',
          [2] = 'readable_short',
          [3] = 'readable_long',
        }
      local default_style = KnownStyles[3]
      local Styles
      do
        local invert_table = request('!.table.invert')
        Styles = invert_table(KnownStyles)
      end
      local KnownBehaviors =
        {
          [1] = 'use_compact_indices',
          [2] = 'use_compact_sequences',
          [3] = 'omit_tail_delimiter',
        }
      local Behaviors
      do
        local invert_table = request('!.table.invert')
        Behaviors = invert_table(KnownBehaviors)
      end
      local StyleToBehavior =
        {
          [Styles.minimal] =
            {
              [Behaviors.use_compact_indices] = true,
              [Behaviors.use_compact_sequences] = true,
              [Behaviors.omit_tail_delimiter] = true,
            },
          [Styles.readable_short] =
            {
              [Behaviors.use_compact_indices] = true,
              [Behaviors.use_compact_sequences] = true,
              [Behaviors.omit_tail_delimiter] = true,
            },
          [Styles.readable_long] =
            {
              [Behaviors.use_compact_indices] = true,
              [Behaviors.use_compact_sequences] = false,
              [Behaviors.omit_tail_delimiter] = false,
            },
        }
      local Writers_Map =
        {
          [Styles.minimal] = request('Writers.Minimal'),
          [Styles.readable_short] = request('Writers.Readable_Short'),
          [Styles.readable_long] = request('Writers.Readable_Long'),
        }
      local Notify_Map
      do
        local notify_default =
          function(event_name, Output)
          end
        Notify_Map =
          {
            [Styles.minimal] = notify_default,
            [Styles.readable_short] = notify_default,
            [Styles.readable_long] = request('Formatters.readable_long'),
          }
      end
      configure_style =
        function(Settings, Output, Options)
          assert_table(Options)
          local style_idx
          do
            local style_str = Options.style or default_style
            style_idx = Styles[style_str]
          end
          if not style_idx then
            error('Unknown style.')
          end
          local Writer_Module = Writers_Map[style_idx]
          Settings.Output = Output
          Settings.Writer = Writer_Module.create(Output)
          do
            local Behavior = StyleToBehavior[style_idx]
            for behavior_idx, flag_value in ipairs(Behavior) do
              Settings[KnownBehaviors[behavior_idx]] = flag_value
            end
          end
          for
            behavior_idx, behavior_flag_name in ipairs(KnownBehaviors)
          do
            if is_boolean(Options[behavior_flag_name]) then
              Settings[behavior_flag_name] = Options[behavior_flag_name]
            end
          end
          Settings.notify = Notify_Map[style_idx]
        end
    end
    local wrap_output =
      function(Output)
        local original_write
        local wrapped_write
        do
          local opening_bracket
          local space
          do
            local Ascii = request('!.concepts.Ascii.Chars')
            opening_bracket = Ascii.opening_bracket
            space = Ascii.space
          end
          local str_sub = string.sub
          local last_char = ''
          wrapped_write =
            function(Output, str)
              local next_char = str_sub(str, 1, 1)
              if
                (last_char == opening_bracket) and
                (next_char == opening_bracket)
              then
                original_write(Output, space)
              end
              original_write(Output, str)
              last_char = str_sub(str, -1)
            end
        end
        original_write = Output.Write
        Output.Write = wrapped_write
        return original_write
      end
    local unwrap_output =
      function(Output, original_write)
        Output.Write = original_write
      end
    local Interface =
      {
        configure_style = configure_style,
        wrap_output = wrap_output,
        unwrap_output = unwrap_output,
      }
    return Interface
  end
package.preload[
  'workshop.concepts.codec_lua_graph.compile.get_graph_ast'
] =
  function(...)
    local get_graph_ast
    do
      local get_tree_ast = request('get_tree_ast')
      local create_table_rec
      local create_name_rec
      local create_local_def_rec
      local create_assignment_rec
      local create_return_rec
      do
        local Methods = request('Ast.Methods')
        create_table_rec = Methods.create_table_rec
        create_name_rec = Methods.create_name_rec
        create_local_def_rec = Methods.create_local_def_rec
        create_assignment_rec = Methods.create_assignment_rec
        create_return_rec = Methods.create_return_rec
      end
      local may_print_inline
      do
        local get_num_refs =
          function(NodeRec)
            local Node = NodeRec.node
            local Refs = NodeRec.refs
            local num_refs = 0
            for Parent, ParentKeys in pairs(Refs) do
              if (Parent == Node) then
                num_refs = num_refs + 1
              end
              for Key in pairs(ParentKeys) do
                if (Key == Node) then
                  num_refs = num_refs + 1
                end
                if (Parent[Key] == Node) then
                  num_refs = num_refs + 1
                end
              end
            end
            return num_refs
          end
        may_print_inline =
          function(NodeRec)
            if not NodeRec then
              return true
            end
            return
              (
                (get_num_refs(NodeRec) <= 1) and
                not NodeRec.part_of_cycle
              )
          end
      end
      local table_iterator = request('!.table.ordered_pass')
      local get_assembly_order = request('!.mechs.graph.assembly_order')
      local NameGiver = request('!.mechs.name_giver')
      local add_to_list = request('!.concepts.list.add_item')
      local tbl_remove = table.remove
      get_graph_ast =
        function(Root)
          local NamedValues = {}
          local NameGiver = new(NameGiver)
          local NodeRecs, OrderedNodes =
            get_assembly_order(
              Root,
              {
                also_visit_keys = true,
                table_iterator = table_iterator,
              }
            )
          local Result = {}
          local ProcessedTables = {}
          for _, Node in ipairs(OrderedNodes) do
            local NodeRec = NodeRecs[Node]
            if (Node == Root) or not may_print_inline(NodeRec) then
              local TableRec
              if NodeRec.part_of_cycle then
                TableRec = create_table_rec()
                local KeyVals = TableRec[2]
                for k, v in table_iterator(Node) do
                  local key_is_ok =
                    not is_table(k) or ProcessedTables[k]
                  local value_is_ok =
                    not is_table(v) or ProcessedTables[v]
                  if not (key_is_ok and value_is_ok) then
                    goto next
                  end
                  add_to_list(
                    KeyVals,
                    {
                      get_tree_ast(k, NamedValues),
                      get_tree_ast(v, NamedValues),
                    }
                  )
                  ::next::
                end
              else
                TableRec = get_tree_ast(Node, NamedValues)
              end
              local node_name = NameGiver:give_name(Node)
              NamedValues[Node] = node_name
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
                      get_tree_ast(parent_key, NamedValues)
                    add_to_list(
                      Result,
                      create_assignment_rec(
                        NamedValues[Parent], key_slot, NamedValues[Node]
                      )
                    )
                  end
                end
              end
            end
          end
          add_to_list(
            Result,
            create_return_rec(create_name_rec(NamedValues[Root]))
          )
          do
            local PrelastNode = Result[#Result - 1]
            local prelast_type = PrelastNode[1]
            if (prelast_type == 'local_definition') then
              local prelast_value = PrelastNode[3]
              tbl_remove(Result)
              tbl_remove(Result)
              add_to_list(Result, create_return_rec(prelast_value))
            end
          end
          return Result
        end
    end
    return get_graph_ast
  end
package.preload[
  'workshop.concepts.codec_lua_graph.compile.serialize_graph_ast'
] =
  function(...)
    local serialize_graph
    do
      local type_local
      local type_assignment
      local type_return
      local type_string
      do
        local TypeNames = request('Ast.TypeNames')
        type_local = TypeNames.type_local
        type_assignment = TypeNames.type_assignment
        type_return = TypeNames.type_return
        type_string = TypeNames.type_string
      end
      local serialize_value = request('serialize_tree_ast')
      local is_identifier = request('!.concepts.lua.is_identifier')
      serialize_graph =
        function(Settings, GraphAst)
          local Output = Settings.Output
          local Write = Settings.Writer
          local use_compact_indices = Settings.use_compact_indices
          for index, Rec in ipairs(GraphAst) do
            local rec_type = Rec[1]
            if (rec_type == type_local) then
              local name = Rec[2]
              local Value = Rec[3]
              Write:Keyword_Local()
              Output:Write(name)
              Write:Assign()
              serialize_value(Settings, Value)
              Write:EndStatement()
            elseif (rec_type == type_assignment) then
              local dest_name = Rec[2]
              local Key = Rec[3]
              local src_name = Rec[4]
              local key_type = Key[1]
              local key_value = Key[2]
              local brackets_not_required =
                use_compact_indices and
                ((key_type == type_string) and is_identifier(key_value))
              Output:Write(dest_name)
              if brackets_not_required then
                Write:SeparateName()
                Output:Write(key_value)
              else
                Write:StartIndex()
                serialize_value(Settings, Key)
                Write:EndIndex()
              end
              Write:Assign()
              Output:Write(src_name)
              Write:EndStatement()
            elseif (rec_type == type_return) then
              local Value = Rec[2]
              Write:Keyword_Return()
              serialize_value(Settings, Value)
              Write:EndStatement()
            end
          end
        end
    end
    return serialize_graph
  end
package.preload[
  'workshop.concepts.codec_lua_graph.compile.get_tree_ast'
] =
  function(...)
    local get_tree_ast
    do
      local create_name_rec
      local create_terminal_type_rec
      local create_table_rec
      do
        local Methods = request('Ast.Methods')
        create_name_rec = Methods.create_name_rec
        create_terminal_type_rec = Methods.create_terminal_type_rec
        create_table_rec = Methods.create_table_rec
      end
      local table_iterator = request('!.table.ordered_pass')
      local add_to_list = request('!.concepts.list.add_item')
      get_tree_ast =
        function(Data, NamedValues)
          NamedValues = NamedValues or {}
          if NamedValues[Data] then
            return create_name_rec(NamedValues[Data])
          end
          if not is_table(Data) then
            return create_terminal_type_rec(Data)
          end
          local Result = create_table_rec()
          local KeyVals = Result[2]
          for Key, Value in table_iterator(Data) do
            add_to_list(
              KeyVals,
              {
                get_tree_ast(Key, NamedValues),
                get_tree_ast(Value, NamedValues),
              }
            )
          end
          return Result
        end
    end
    return get_tree_ast
  end
package.preload[
  'workshop.concepts.codec_lua_graph.compile.Writers.Readable_Long'
] =
  function(...)
    local Assign =
      function(Me)
        Me:Write(' = ')
      end
    local EmptyTable =
      function(Me)
        Me:Write('{ }')
      end
    local Interface
    local create =
      function(OutputStream)
        return Interface.internal_create(OutputStream, Interface)
      end
    do
      local BaseInterface = request('Minimal')
      local patch = request('!.table.patch')
      Interface = new(BaseInterface)
      patch(
        Interface,
        { create = create, Assign = Assign, EmptyTable = EmptyTable }
      )
    end
    return Interface
  end
package.preload[
  'workshop.concepts.codec_lua_graph.compile.Writers.Minimal'
] =
  function(...)
    local space = ' '
    local newline = '\n'
    local Keyword_Local =
      function(Stream)
        Stream:Write('local' .. space)
      end
    local Keyword_Return =
      function(Stream)
        Stream:Write('return' .. space)
      end
    local EndStatement =
      function(Stream)
        Stream:Write(newline)
      end
    local SeparateName =
      function(Stream)
        Stream:Write('.')
      end
    local Assign =
      function(Stream)
        Stream:Write('=')
      end
    local SeparateItem =
      function(Stream)
        Stream:Write(',')
      end
    local StartTable =
      function(Stream)
        Stream:Write('{')
      end
    local EndTable =
      function(Stream)
        Stream:Write('}')
      end
    local EmptyTable =
      function(Stream)
        Stream:Write('{}')
      end
    local StartIndex =
      function(Stream)
        Stream:Write('[')
      end
    local EndIndex =
      function(Stream)
        Stream:Write(']')
      end
    local Interface
    local create =
      function(OutputStream)
        return Interface.internal_create(OutputStream, Interface)
      end
    do
      local BaseInterface = request('Interface')
      local patch = request('!.table.patch')
      Interface = new(BaseInterface)
      patch(
        Interface,
        {
          create = create,
          Keyword_Local = Keyword_Local,
          SeparateName = SeparateName,
          EndStatement = EndStatement,
          Keyword_Return = Keyword_Return,
          Assign = Assign,
          SeparateItem = SeparateItem,
          StartTable = StartTable,
          EndTable = EndTable,
          EmptyTable = EmptyTable,
          StartIndex = StartIndex,
          EndIndex = EndIndex,
        }
      )
    end
    return Interface
  end
package.preload[
  'workshop.concepts.codec_lua_graph.compile.Writers.Readable_Short'
] =
  function(...)
    local Assign =
      function(Me)
        Me:Write(' = ')
      end
    local SeparateItem =
      function(Me)
        Me:Write(', ')
      end
    local StartTable =
      function(Me)
        Me:Write('{ ')
      end
    local EndTable =
      function(Me)
        Me:Write(' }')
      end
    local EmptyTable =
      function(Me)
        Me:Write('{ }')
      end
    local Interface
    local create =
      function(OutputStream)
        return Interface.internal_create(OutputStream, Interface)
      end
    do
      local BaseInterface = request('Minimal')
      local patch = request('!.table.patch')
      Interface = new(BaseInterface)
      patch(
        Interface,
        {
          create = create,
          Assign = Assign,
          SeparateItem = SeparateItem,
          StartTable = StartTable,
          EndTable = EndTable,
          EmptyTable = EmptyTable,
        }
      )
    end
    return Interface
  end
package.preload[
  'workshop.concepts.codec_lua_graph.compile.Writers.Interface'
] =
  function(...)
    local internal_create
    do
      local attach_methods = request('!.table.attach_methods')
      internal_create =
        function(OutputStream, Interface)
          local State = { OutputStream }
          attach_methods(State, Interface)
          return State
        end
    end
    local get_output_stream =
      function(Me)
        return Me[1]
      end
    local write =
      function(Me, str)
        get_output_stream(Me):Write(str)
      end
    local writer_method =
      function(Me)
      end
    local Interface
    local create =
      function(OutputStream)
        return internal_create(OutputStream, Interface)
      end
    Interface =
      {
        internal_create = internal_create,
        Write = write,
        create = create,
        Keyword_Local = writer_method,
        SeparateName = writer_method,
        EndStatement = writer_method,
        Keyword_Return = writer_method,
        Assign = writer_method,
        SeparateItem = writer_method,
        StartTable = writer_method,
        EndTable = writer_method,
        EmptyTable = writer_method,
        StartIndex = writer_method,
        EndIndex = writer_method,
      }
    return Interface
  end
package.preload[
  'workshop.concepts.codec_lua_graph.compile.Ast.TypeNames'
] =
  function(...)
    local TypeNames =
      {
        type_name = 'name',
        type_number = 'number',
        type_string = 'string',
        type_table = 'table',
        type_local = 'definition',
        type_assignment = 'assignment',
        type_return = 'emit',
      }
    return TypeNames
  end
package.preload['workshop.concepts.codec_lua_graph.compile.Ast.Methods'] =
  function(...)
    local type_name
    local type_table
    local type_local
    local type_assignment
    local type_return
    do
      local TypeNames = request('TypeNames')
      type_name = TypeNames.type_name
      type_table = TypeNames.type_table
      type_local = TypeNames.type_local
      type_assignment = TypeNames.type_assignment
      type_return = TypeNames.type_return
    end
    local create_terminal_type_rec =
      function(data)
        return { type(data), data }
      end
    local create_name_rec =
      function(name)
        return { type_name, name }
      end
    local create_table_rec =
      function()
        return { type_table, {} }
      end
    local create_local_def_rec =
      function(name, Value)
        return { type_local, name, Value }
      end
    local create_assignment_rec =
      function(dest, index, value)
        return { type_assignment, dest, index, value }
      end
    local create_return_rec =
      function(Value)
        return { type_return, Value }
      end
    local Methods =
      {
        create_terminal_type_rec = create_terminal_type_rec,
        create_name_rec = create_name_rec,
        create_table_rec = create_table_rec,
        create_local_def_rec = create_local_def_rec,
        create_assignment_rec = create_assignment_rec,
        create_return_rec = create_return_rec,
      }
    return Methods
  end
package.preload[
  'workshop.concepts.codec_lua_graph.compile.Formatters.readable_long'
] =
  function(...)
    local Indent = request('!.concepts.Indent')
    Indent = Indent.create()
    local emit_indent =
      function(Output)
        Output:Write('\n')
        local indent_str = Indent:ToString()
        if (indent_str == '') then
          return
        end
        Output:Write(indent_str)
      end
    local prev_event_name = 'nothing'
    local notify =
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
    return notify
  end
package.preload['workshop.concepts.Ascii.Chars'] =
  function(...)
    local Chars
    do
      local Codes = request('Codes')
      local str_char = string.char
      Chars = {}
      for name, code in pairs(Codes) do
        Chars[name] = str_char(code)
      end
    end
    return Chars
  end
package.preload['workshop.concepts.Ascii.Codes'] =
  function(...)
    local Codes =
      {
        bell = 7,
        backspace = 8,
        tab = 9,
        newline = 10,
        vertical_tab = 11,
        form_feed = 12,
        carriage_return = 13,
        space = 32,
        delete = 127,
        plus = 43,
        minus = 45,
        asterisk = 42,
        slash = 47,
        less_than = 60,
        equals = 61,
        greater_than = 62,
        dot = 46,
        comma = 44,
        colon = 58,
        semicolon = 59,
        single_quote = 39,
        double_quote = 34,
        backtick = 96,
        backslash = 92,
        number_sign = 35,
        question_mark = 63,
        bang = 33,
        percent = 37,
        ampersand = 38,
        dollar_sign = 36,
        at_sign = 64,
        caret = 94,
        underscore = 95,
        pipe = 124,
        tilde = 126,
        opening_paren = 40,
        closing_paren = 41,
        opening_bracket = 91,
        closing_bracket = 93,
        opening_brace = 123,
        closing_brace = 125,
      }
    return Codes
  end
package.preload['workshop.concepts.Ascii.is_control_code'] =
  function(...)
    local assert_byte = request('!.number.assert_byte')
    local is_control_code =
      function(code)
        assert_byte(code)
        return (code <= 31) or (code == 127)
      end
    return is_control_code
  end
package.preload['workshop.concepts.StreamIo.Output.String'] =
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