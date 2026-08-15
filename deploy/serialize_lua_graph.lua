package.preload['serialize_lua_graph'] =
  function(...)
    require('workshop.base')
    return request('!.convert.table_to_str')
  end
package.preload['workshop.base'] =
  function(...)
    local str_match = string.match
    local str_find = string.find
    local str_sub = string.sub
    local tbl_pack = table.pack
    local tbl_unpack = table.unpack
    local require = require
    local empty = ''
    local stack_init
    local stack_get
    local stack_add
    local stack_remove
    do
      local Names
      local depth
      stack_init =
        function()
          Names = {}
          depth = 1
        end
      stack_get =
        function()
          return Names[depth]
        end
      stack_add =
        function(prefix, name)
          depth = depth + 1
          Names[depth] = { prefix = prefix, name = name }
        end
      stack_remove =
        function()
          depth = depth - 1
        end
    end
    local get_caller_prefix =
      function()
        local NameRec = stack_get()
        if not NameRec then
          return empty
        end
        return NameRec.prefix
      end
    local get_caller_name =
      function()
        local NameRec = stack_get()
        if not NameRec then
          return empty
        end
        return NameRec.prefix .. NameRec.name
      end
    local split_name
    do
      local prefix_name_capture = '^(.+%.)([^%.]+)$'
      split_name =
        function(qualified_name)
          local prefix, name =
            str_match(qualified_name, prefix_name_capture)
          if not prefix then
            prefix = empty
            if str_find(qualified_name, '%.') then
              name = empty
            else
              name = qualified_name
            end
          end
          return prefix, name
        end
    end
    local apply_rel_prefix
    do
      local uplevel_capture = '(.+%.)[^%.]-%.$'
      apply_rel_prefix =
        function(base_prefix, rel_prefix)
          while (str_sub(rel_prefix, 1, 2) == '^.') do
            if (base_prefix == empty) then
              error("Link is outside of caller's prefix.")
            end
            base_prefix =
              str_match(base_prefix, uplevel_capture) or empty
            rel_prefix = str_sub(rel_prefix, 3)
          end
          return base_prefix .. rel_prefix
        end
    end
    local set_base_prefix
    local get_base_prefix
    do
      local base_prefix
      set_base_prefix =
        function(arg_base_prefix)
          base_prefix = arg_base_prefix
        end
      get_base_prefix =
        function()
          return base_prefix
        end
    end
    local get_require_name =
      function(qualified_name)
        local caller_prefix
        local is_absolute_name = (str_sub(qualified_name, 1, 2) == '!.')
        if is_absolute_name then
          qualified_name = str_sub(qualified_name, 3)
          caller_prefix = get_base_prefix()
        else
          caller_prefix = get_caller_prefix()
        end
        local prefix, name = split_name(qualified_name)
        prefix = apply_rel_prefix(caller_prefix, prefix)
        return prefix .. name
      end
    local init_dependencies
    local get_dependencies
    local add_dependency
    do
      local Dependencies_Map
      init_dependencies =
        function()
          Dependencies_Map = {}
        end
      get_dependencies =
        function()
          return Dependencies_Map
        end
      add_dependency =
        function(src_name, dest_name)
          Dependencies_Map[src_name] = Dependencies_Map[src_name] or {}
          Dependencies_Map[src_name][dest_name] = true
        end
    end
    local request =
      function(qualified_name)
        local require_name = get_require_name(qualified_name)
        local src_name = get_caller_name()
        stack_add(split_name(require_name))
        local dest_name = get_caller_name()
        add_dependency(src_name, dest_name)
        local Results = tbl_pack(require(require_name))
        stack_remove()
        return tbl_unpack(Results)
      end
    do
      if (_G.request == nil) then
        local our_require_name = (...)
        set_base_prefix(split_name(our_require_name))
        init_dependencies()
        _G.request = request
        _G.get_require_name = get_require_name
        _G.get_base_prefix = get_base_prefix
        _G.get_dependencies = get_dependencies
        stack_init()
        stack_add(empty, our_require_name)
        request('!.system.install_is_functions')()
        request('!.system.install_assert_functions')()
        _G.new = request('!.table.new')
        stack_remove()
      end
    end
  end
package.preload['workshop.system.install_is_functions'] =
  function(...)
    local type_is =
      function(type_name)
        return
          function(val)
            return (type(val) == type_name)
          end
      end
    local number_is
    do
      local math_type = math.type
      number_is =
        function(type_name)
          return
            function(val)
              if not is_number(val) then
                return false
              end
              return (math_type(val) == type_name)
            end
        end
    end
    local TypeNames = request('!.concepts.lua.TypeNames')
    local NumberTypeNames = request('!.concepts.lua.NumberTypeNames')
    return
      function()
        for _, type_name in ipairs(TypeNames) do
          _G['is_' .. type_name] = type_is(type_name)
        end
        for _, number_type_name in ipairs(NumberTypeNames) do
          _G['is_' .. number_type_name] = number_is(number_type_name)
        end
      end
  end
package.preload['workshop.system.install_assert_functions'] =
  function(...)
    local spawn_assert_func
    do
      local str_format = string.format
      spawn_assert_func =
        function(type_name)
          local checker = _G['is_' .. type_name]
          assert(checker)
          return
            function(val)
              if not checker(val) then
                local err_msg =
                  str_format('assert_%s(%s)', type_name, tostring(val))
                error(err_msg)
              end
            end
        end
    end
    local TypeNames = request('!.concepts.lua.TypeNames')
    local NumberTypeNames = request('!.concepts.lua.NumberTypeNames')
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
    local Templates =
      {
        ['function'] = 'f_%d',
        ['table'] = 'T_%d',
        ['thread'] = 'th_%d',
        ['userdata'] = 'u_%d',
      }
    local str_format = string.format
    return
      {
        Names = {},
        Counters =
          {
            ['function'] = 0,
            ['table'] = 0,
            ['thread'] = 0,
            ['userdata'] = 0,
          },
        give_name =
          function(Me, obj)
            if not Me.Names[obj] then
              local obj_type = type(obj)
              local counter = Me.Counters[obj_type]
              assert_integer(counter)
              counter = counter + 1
              Me.Names[obj] = str_format(Templates[obj_type], counter)
              Me.Counters[obj_type] = counter
            end
            return Me.Names[obj]
          end,
      }
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
    local add_to_list = request('!.concepts.list.add_item')
    local compare_keys = request('!.table.ordered_pass.compare_keys')
    local tbl_sort = table.sort
    return
      function(Me, Node)
        local also_visit_keys = Me.also_visit_keys
        local KeyVals = get_key_vals(Node)
        local Result = {}
        for _, Rec in ipairs(KeyVals) do
          if is_table(Rec.value) then
            add_to_list(Result, Rec)
          end
          if also_visit_keys and is_table(Rec.key) then
            add_to_list(Result, { key = Rec.key, value = Rec.key })
          end
        end
        tbl_sort(Result, compare_keys)
        return Result
      end
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
    return
      function(n)
        return (n == -1 / 0)
      end
  end
package.preload['workshop.number.is_pos_inf'] =
  function(...)
    return
      function(n)
        return (n == 1 / 0)
      end
  end
package.preload['workshop.number.is_nan'] =
  function(...)
    return
      function(n)
        return (n ~= n)
      end
  end
package.preload['workshop.table.clone'] =
  function(...)
    return
      function(Node)
        local clone
        do
          local Cloned = {}
          clone =
            function(Node)
              if (type(Node) ~= 'table') then
                return Node
              end
              if Cloned[Node] then
                return Cloned[Node]
              end
              local Result = {}
              Cloned[Node] = Result
              for key, value in pairs(Node) do
                Result[clone(key)] = clone(value)
              end
              setmetatable(Result, getmetatable(Node))
              return Result
            end
        end
        return clone(Node)
      end
  end
package.preload['workshop.table.new'] =
  function(...)
    local clone = request('clone')
    local patch = request('patch')
    return
      function(Base, Overrides)
        assert_table(Base)
        local Result = clone(Base)
        if is_table(Overrides) then
          patch(Result, Overrides)
        end
        return Result
      end
  end
package.preload['workshop.table.patch'] =
  function(...)
    local Rules = { { has_a = true, has_b = true, action = 'replace' } }
    local apply_table = request('apply_table')
    return
      function(Result, Additions)
        apply_table(Result, Additions, Rules)
      end
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
    return
      function(List)
        assert_table(List)
        local Result = {}
        for _, value in pairs(List) do
          Result[value] = true
        end
        return Result
      end
  end
package.preload['workshop.table.create_instance'] =
  function(...)
    local clone = request('clone')
    local attach_methods = request('attach_methods')
    return
      function(Data, Methods)
        assert_table(Data)
        assert_table(Methods)
        local Result
        Result = clone(Data)
        attach_methods(Result, Methods)
        return Result
      end
  end
package.preload['workshop.table.get_key_vals'] =
  function(...)
    local add_to_list = request('!.concepts.list.add_item')
    return
      function(Table)
        assert_table(Table)
        local KeyVals = {}
        for key, value in pairs(Table) do
          add_to_list(KeyVals, { key = key, value = value })
        end
        return KeyVals
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
    return
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
  end
package.preload['workshop.table.ordered_pass'] =
  function(...)
    local keys_comparator = request('ordered_pass.compare_keys')
    local get_key_vals = request('get_key_vals')
    local tbl_sort = table.sort
    return
      function(Table, comparator)
        assert_table(Table)
        comparator = comparator or keys_comparator
        assert_function(comparator)
        local KeyVals = get_key_vals(Table)
        tbl_sort(KeyVals, comparator)
        local i = 0
        local get_next =
          function()
            i = i + 1
            if KeyVals[i] then
              return KeyVals[i].key, KeyVals[i].value
            end
          end
        return get_next, Table
      end
  end
package.preload['workshop.table.attach_methods'] =
  function(...)
    return
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
  end
package.preload['workshop.table.ordered_pass.compare_values'] =
  function(...)
    local TypeRank_Map = { ['number'] = 1, ['string'] = 2, other = 3 }
    local ComparableTypes_Map = { ['number'] = true, ['string'] = true }
    return
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
  end
package.preload['workshop.table.ordered_pass.compare_keys'] =
  function(...)
    local compare_values = request('compare_values')
    return
      function(A, B)
        return compare_values(A.key, B.key)
      end
  end
package.preload['workshop.string.starts_with'] =
  function(...)
    local str_sub = string.sub
    return
      function(base_str, prefix_str)
        return (str_sub(base_str, 1, #prefix_str) == prefix_str)
      end
  end
package.preload['workshop.string.get_chars_count'] =
  function(...)
    local str_sub = string.sub
    local str_byte = string.byte
    return
      function(str)
        local UsedChars_Map = {}
        for index = 1, #str do
          local code = str_byte(str_sub(str, index, index))
          if is_nil(UsedChars_Map[code]) then
            UsedChars_Map[code] = 0
          end
          UsedChars_Map[code] = UsedChars_Map[code] + 1
        end
        return UsedChars_Map
      end
  end
package.preload['workshop.convert.table_to_str'] =
  function(...)
    local StringOutputStream =
      request('!.concepts.StreamIo.Output.String')
    local compile_graph =
      request('!.concepts.codec_lua_graph.compile_graph')
    return
      function(Graph, Options)
        local StringStream = new(StringOutputStream)
        compile_graph(Graph, StringStream, Options)
        return StringStream:GetString()
      end
  end
package.preload['workshop.concepts.Indent'] =
  function(...)
    local create_instance = request('!.table.create_instance')
    local RangePoint = request('!.concepts.RangePoint')
    local str_rep = string.rep
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
            local indent_level = Me:GetRangePoint():GetValue()
            if (indent_level == 0) then
              return ''
            end
            local indent_chunk = Me:GetIndentChunk()
            return str_rep(indent_chunk, indent_level)
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
    return { 'integer', 'float' }
  end
package.preload['workshop.concepts.lua.TypeNames'] =
  function(...)
    return
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
  end
package.preload['workshop.concepts.lua.Keywords'] =
  function(...)
    return
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
  end
package.preload['workshop.concepts.lua.is_identifier'] =
  function(...)
    local identifier_pattern = '^[%a_][%w_]*$'
    local Keywords_Map
    do
      local Keywords = request('Keywords')
      local map_values = request('!.table.map_values')
      Keywords_Map = map_values(Keywords)
    end
    local str_match = string.match
    return
      function(str)
        if not is_string(str) then
          return false
        end
        return
          str_match(str, identifier_pattern) and not Keywords_Map[str]
      end
  end
package.preload['workshop.concepts.lua.serialize_terminal_value'] =
  function(...)
    local encode_bool =
      function(val)
        if (val == false) then
          return 'false'
        else
          return 'true'
        end
      end
    local encode_number
    do
      local is_nan = request('!.number.is_nan')
      local is_pos_inf = request('!.number.is_pos_inf')
      local is_neg_inf = request('!.number.is_neg_inf')
      encode_number =
        function(val)
          if is_nan(val) then
            return '0/0'
          elseif is_pos_inf(val) then
            return '1/0'
          elseif is_neg_inf(val) then
            return '-1/0'
          end
          return _G.tostring(val)
        end
    end
    local encode_string
    do
      local lua_quote_str = request('!.concepts.lua.quote_string')
      encode_string =
        function(val)
          return lua_quote_str(val)
        end
    end
    return
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
  end
package.preload['workshop.concepts.lua.QuoteChars'] =
  function(...)
    local AsciiCodes = request('!.concepts.Ascii.Codes')
    local AsciiChars = request('!.concepts.Ascii.Chars')
    return
      {
        single_quote_code = AsciiCodes.single_quote,
        single_quote = AsciiChars.single_quote,
        double_quote_code = AsciiCodes.double_quote,
        double_quote = AsciiChars.double_quote,
        backslash_code = AsciiCodes.backslash,
        backslash = AsciiChars.backslash,
      }
  end
package.preload['workshop.concepts.lua.quote_string'] =
  function(...)
    local newline_code = request('!.concepts.Ascii.Codes').newline
    local BinaryEntitiesLengths_Map =
      { [1] = true, [2] = true, [4] = true, [8] = true }
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
    local tbl_concat = table.concat
    return
      function(List, separator_str)
        assert_table(List)
        separator_str = separator_str or ''
        assert_string(separator_str)
        return tbl_concat(List, separator_str)
      end
  end
package.preload['workshop.concepts.list.add_item'] =
  function(...)
    local tbl_insert = table.insert
    return
      function(OurList, item)
        tbl_insert(OurList, item)
      end
  end
package.preload['workshop.concepts.codec_lua_graph.compile_graph'] =
  function(...)
    local initialize = request('compile.initialize')
    local get_ast = request('compile.get_graph_ast')
    local serialize_ast = request('compile.serialize_graph_ast')
    return
      function(Graph, Output, Options)
        assert_table(Graph)
        Options = Options or {}
        local Settings = {}
        initialize(Settings, Output, Options)
        serialize_ast(Settings, get_ast(Graph))
      end
  end
package.preload['workshop.concepts.codec_lua_graph.compile.initialize'] =
  function(...)
    local invert_table = request('!.table.invert')
    local Styles =
      invert_table(
        {
          [1] = 'minimal',
          [2] = 'readable_short',
          [3] = 'readable_long',
        }
      )
    local default_style = 'readable_long'
    local TokensOutputStream = request('TokensOutputStream')
    local KnownBehaviors =
      {
        [1] = 'use_compact_indices',
        [2] = 'use_compact_sequences',
        [3] = 'omit_tail_delimiter',
      }
    local Behaviors = invert_table(KnownBehaviors)
    local StyleToBehavior =
      {
        ['minimal'] =
          {
            ['use_compact_indices'] = true,
            ['use_compact_sequences'] = true,
            ['omit_tail_delimiter'] = true,
          },
        ['readable_short'] =
          {
            ['use_compact_indices'] = true,
            ['use_compact_sequences'] = true,
            ['omit_tail_delimiter'] = true,
          },
        ['readable_long'] =
          {
            ['use_compact_indices'] = true,
            ['use_compact_sequences'] = false,
            ['omit_tail_delimiter'] = false,
          },
      }
    local empty_func =
      function()
      end
    return
      function(Settings, Output, Options)
        assert_table(Options)
        local style = Options.style or default_style
        if not Styles[style] then
          error('Unknown style.')
        end
        Settings.Output = TokensOutputStream.create(Output, style)
        do
          local Behavior = StyleToBehavior[style]
          for behavior_flag_name, flag_value in pairs(Behavior) do
            Settings[behavior_flag_name] = flag_value
          end
        end
        for _, behavior_flag_name in ipairs(KnownBehaviors) do
          if is_boolean(Options[behavior_flag_name]) then
            Settings[behavior_flag_name] = Options[behavior_flag_name]
          end
        end
      end
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
    local Syntels = request('Syntels')
    local is_serializeable =
      function(val_type)
        return
          (val_type ~= 'function') and
          (val_type ~= 'thread') and
          (val_type ~= 'userdata')
      end
    local serialize_value
    local serialize_tree
    do
      local serialize_terminal_value =
        request('!.concepts.lua.serialize_terminal_value')
      serialize_value =
        function(Settings, Node)
          local Output = Settings.Output
          local node_type = Node[1]
          local node_value = Node[2]
          if not is_serializeable(node_type) then
            return
          end
          if (node_type == type_name) then
            Output:Write(node_value)
          elseif (node_type == type_table) then
            serialize_tree(Settings, Node)
          else
            Output:Write(serialize_terminal_value(node_value))
          end
        end
    end
    do
      local serialize_index
      do
        local is_identifier = request('!.concepts.lua.is_identifier')
        local start_index = Syntels.start_index
        local end_index = Syntels.end_index
        serialize_index =
          function(Settings, Index)
            local Output = Settings.Output
            local index_type = Index[1]
            local index_value = Index[2]
            local use_compact_indices = Settings.use_compact_indices
            local brackets_not_required =
              use_compact_indices and
              (
                (index_type == type_string) and
                is_identifier(index_value)
              )
            if brackets_not_required then
              Output:Write(index_value)
            else
              Output:Write(start_index)
              serialize_value(Settings, Index)
              Output:Write(end_index)
            end
          end
      end
      local start_table = Syntels.start_table
      local end_table = Syntels.end_table
      local item_separator = Syntels.item_separator
      local assign = Syntels.assign
      serialize_tree =
        function(Settings, TableAst)
          local Output = Settings.Output
          local use_compact_sequences = Settings.use_compact_sequences
          local omit_tail_delimiter = Settings.omit_tail_delimiter
          local KeyVals = TableAst[2]
          Output:Write(start_table)
          local wrote_something = false
          do
            local next_integer_key = 1
            for index, KeyVal_Rec in ipairs(KeyVals) do
              local Key = KeyVal_Rec[1]
              local Value = KeyVal_Rec[2]
              local key_type = Key[1]
              local key_value = Key[2]
              local val_type = Value[1]
              if
                not (
                  is_serializeable(key_type) and
                  is_serializeable(val_type)
                )
              then
                goto next
              end
              if wrote_something then
                Output:Write(item_separator)
              end
              local skip_key_serialization =
                use_compact_sequences and
                (
                  (key_type == type_number) and
                  (key_value == next_integer_key)
                )
              if skip_key_serialization then
                next_integer_key = key_value + 1
              else
                serialize_index(Settings, Key)
                Output:Write(assign)
              end
              serialize_value(Settings, Value)
              wrote_something = true
              ::next::
            end
          end
          if wrote_something and not omit_tail_delimiter then
            Output:Write(item_separator)
          end
          Output:Write(end_table)
        end
    end
    return serialize_value
  end
package.preload[
  'workshop.concepts.codec_lua_graph.compile.get_graph_ast'
] =
  function(...)
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
            ((get_num_refs(NodeRec) <= 1) and not NodeRec.part_of_cycle)
        end
    end
    local table_iterator = request('!.table.ordered_pass')
    local get_assembly_order = request('!.mechs.graph.assembly_order')
    local NameGiver = request('!.mechs.name_giver')
    local add_to_list = request('!.concepts.list.add_item')
    local tbl_remove = table.remove
    return
      function(Root)
        local NamedValues = {}
        local NameGiver = new(NameGiver)
        local NodeRecs, OrderedNodes =
          get_assembly_order(
            Root,
            { also_visit_keys = true, table_iterator = table_iterator }
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
                local key_is_ok = not is_table(k) or ProcessedTables[k]
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
                  local key_slot = get_tree_ast(parent_key, NamedValues)
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
          Result, create_return_rec(create_name_rec(NamedValues[Root]))
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
package.preload['workshop.concepts.codec_lua_graph.compile.Syntels'] =
  function(...)
    return
      {
        start_table = '{',
        end_table = '}',
        start_index = '[',
        end_index = ']',
        assign = '=',
        item_separator = ',',
        kw_local = 'local',
        name_separator = '.',
        statement_separator = ';',
        kw_return = 'return',
      }
  end
package.preload[
  'workshop.concepts.codec_lua_graph.compile.TokensOutputStream'
] =
  function(...)
    local empty = ''
    local Syntels = request('Syntels')
    local write
    do
      local is_syntax_clash
      do
        local syntel_start_index = Syntels.start_index
        local starts_with = request('!.string.starts_with')
        local str_sub = string.sub
        local str_byte = string.byte
        local is_alnum = request('!.concepts.Ascii.is_alnum')
        is_syntax_clash =
          function(prev_token, next_token)
            if (prev_token == empty) then
              return false
            end
            if
              (prev_token == syntel_start_index) and
              starts_with(next_token, syntel_start_index)
            then
              return true
            end
            do
              local prev_char_code =
                str_byte(str_sub(prev_token, -1, -1))
              local next_char_code = str_byte(str_sub(next_token, 1, 1))
              if
                is_alnum(prev_char_code) and is_alnum(next_char_code)
              then
                return true
              end
            end
            return false
          end
      end
      local syntel_start_table = Syntels.start_table
      local syntel_end_table = Syntels.end_table
      local syntel_assign = Syntels.assign
      local syntel_item_separator = Syntels.item_separator
      local syntel_statement_separator = Syntels.statement_separator
      local space
      local newline
      do
        local AsciiChars = request('!.concepts.Ascii.Chars')
        space = AsciiChars.space
        newline = AsciiChars.newline
      end
      write =
        function(Me, next_token)
          local Output = Me.Output
          local prev_token = Me.prev_token
          local style = Me.style
          local Indent = Me.Indent
          do
            local action_emit_space = false
            local action_emit_newline = false
            do
              action_emit_space =
                action_emit_space or
                is_syntax_clash(prev_token, next_token)
              if (style == 'readable_short') then
                action_emit_space =
                  action_emit_space or
                  (prev_token == syntel_start_table) or
                  (next_token == syntel_end_table) or
                  (prev_token == syntel_assign) or
                  (next_token == syntel_assign) or
                  (prev_token == syntel_item_separator)
                action_emit_newline =
                  action_emit_newline or
                  (prev_token == syntel_statement_separator)
              elseif (style == 'readable_long') then
                if (next_token == syntel_start_table) then
                  Indent:Inc()
                elseif (next_token == syntel_end_table) then
                  Indent:Dec()
                end
                local is_empty_table =
                  (prev_token == syntel_start_table) and
                  (next_token == syntel_end_table)
                action_emit_space =
                  action_emit_space or
                  (prev_token == syntel_assign) or
                  (next_token == syntel_assign) or
                  is_empty_table
                action_emit_newline =
                  action_emit_newline or
                  (
                    (prev_token == syntel_start_table) and
                    not is_empty_table
                  ) or
                  (
                    (next_token == syntel_end_table) and
                    not is_empty_table
                  ) or
                  (prev_token == syntel_item_separator) or
                  (prev_token == syntel_statement_separator)
              end
            end
            if action_emit_space then
              Output:Write(space)
            end
            if action_emit_newline then
              Output:Write(newline)
              Output:Write(Indent:ToString())
            end
          end
          Output:Write(next_token)
          Me.prev_token = next_token
        end
    end
    local Interface
    do
      local create
      do
        local IndentClass = request('!.concepts.Indent')
        local attach_methods = request('!.table.attach_methods')
        create =
          function(BaseOutputStream, style)
            assert_table(BaseOutputStream)
            assert_string(style)
            local Core =
              {
                Output = BaseOutputStream,
                prev_token = empty,
                style = style,
                Indent = IndentClass.create(),
              }
            attach_methods(Core, Interface)
            return Core
          end
      end
      Interface = { create = create, Write = write }
    end
    return Interface
  end
package.preload[
  'workshop.concepts.codec_lua_graph.compile.serialize_graph_ast'
] =
  function(...)
    local Syntels = request('Syntels')
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
      local serialize_index
      do
        local name_separator = Syntels.name_separator
        local start_index = Syntels.start_index
        local end_index = Syntels.end_index
        local is_identifier = request('!.concepts.lua.is_identifier')
        serialize_index =
          function(Settings, Index)
            local Output = Settings.Output
            local index_value = Index[2]
            local brackets_not_required
            do
              local use_compact_indices = Settings.use_compact_indices
              local index_type = Index[1]
              brackets_not_required =
                use_compact_indices and
                (
                  (index_type == type_string) and
                  is_identifier(index_value)
                )
            end
            if brackets_not_required then
              Output:Write(name_separator)
              Output:Write(index_value)
            else
              Output:Write(start_index)
              serialize_value(Settings, Index)
              Output:Write(end_index)
            end
          end
      end
      local kw_local = Syntels.kw_local
      local assign = Syntels.assign
      local statement_separator = Syntels.statement_separator
      local kw_return = Syntels.kw_return
      serialize_graph =
        function(Settings, GraphAst)
          local Output = Settings.Output
          for index, Rec in ipairs(GraphAst) do
            local rec_type = Rec[1]
            if (rec_type == type_local) then
              local name = Rec[2]
              local Value = Rec[3]
              Output:Write(kw_local)
              Output:Write(name)
              Output:Write(assign)
              serialize_value(Settings, Value)
            elseif (rec_type == type_assignment) then
              local dest_name = Rec[2]
              local Index = Rec[3]
              local src_name = Rec[4]
              Output:Write(dest_name)
              serialize_index(Settings, Index)
              Output:Write(assign)
              Output:Write(src_name)
            elseif (rec_type == type_return) then
              local Value = Rec[2]
              Output:Write(kw_return)
              serialize_value(Settings, Value)
            end
            Output:Write(statement_separator)
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
  'workshop.concepts.codec_lua_graph.compile.Ast.TypeNames'
] =
  function(...)
    return
      {
        type_name = 'name',
        type_number = 'number',
        type_string = 'string',
        type_table = 'table',
        type_local = 'definition',
        type_assignment = 'indexed_assignment',
        type_return = 'emit',
      }
  end
package.preload['workshop.concepts.codec_lua_graph.compile.Ast.Methods'] =
  function(...)
    local create_terminal_type_rec
    local create_name_rec
    local create_table_rec
    local create_local_def_rec
    local create_assignment_rec
    local create_return_rec
    do
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
      create_terminal_type_rec =
        function(data)
          return { type(data), data }
        end
      create_name_rec =
        function(name)
          return { type_name, name }
        end
      create_table_rec =
        function()
          return { type_table, {} }
        end
      create_local_def_rec =
        function(name, Value)
          return { type_local, name, Value }
        end
      create_assignment_rec =
        function(dest, index, value)
          return { type_assignment, dest, index, value }
        end
      create_return_rec =
        function(Value)
          return { type_return, Value }
        end
    end
    return
      {
        create_terminal_type_rec = create_terminal_type_rec,
        create_name_rec = create_name_rec,
        create_table_rec = create_table_rec,
        create_local_def_rec = create_local_def_rec,
        create_assignment_rec = create_assignment_rec,
        create_return_rec = create_return_rec,
      }
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
package.preload['workshop.concepts.Ascii.is_alnum'] =
  function(...)
    return
      function(code)
        return
          ((code >= 65) and (code <= 90)) or
          ((code >= 97) and (code <= 122)) or
          ((code >= 48) and (code <= 57))
      end
  end
package.preload['workshop.concepts.Ascii.Codes'] =
  function(...)
    return
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
  end
package.preload['workshop.concepts.Ascii.is_control_code'] =
  function(...)
    return
      function(code)
        return (code <= 31) or (code == 127)
      end
  end
package.preload['workshop.concepts.StreamIo.Output.String'] =
  function(...)
    local list_to_string = request('!.concepts.list.to_string')
    local list_add_item = request('!.concepts.list.add_item')
    return
      {
        GetString =
          function(Me)
            return list_to_string(Me.Chunks)
          end,
        Write =
          function(Me, data_str)
            assert_string(data_str)
            list_add_item(Me.Chunks, data_str)
          end,
        Chunks = {},
      }
  end
return require('serialize_lua_graph')