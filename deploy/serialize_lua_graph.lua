_G.package.preload['test'] =
  function(...)
    require('workshop.base')
    return request('!.formats.lua_table_code.save')
  end
_G.package.preload['workshop.base'] =
  function(...)
    do
      local data_types =
        {'boolean', 'function', 'nil', 'number', 'string', 'table', 'thread', 'userdata'}
      for k, type_name in ipairs(data_types) do
        _G['is_' .. type_name] =
          function(a)
            return (type(a) == type_name)
          end
        _G['assert_' .. type_name] =
          function(a, responsibility_level)
            local responsibility_level = (responsibility_level or 1)
            if (type(a) ~= type_name) then
              error(
                ('Argument must have a type "%s", not "%s".'):format(type_name, type(a)),
                responsibility_level + 1
              )
            end
          end
      end
      _G.is_integer =
        function(n)
          return (math.type(n) == 'integer')
        end
      _G.assert_integer =
        function(a, responsibility_level)
          local responsibility_level = (responsibility_level or 1)
          if (math.type(a) ~= 'integer') then
            error(
              ('Argument must be integer, not %s.'):format(type(a)), responsibility_level + 1
            )
          end
        end
    end
    do
      _G.table.pack = _G.table.pack or _G.pack
      _G.table.unpack =
        _G.table.unpack or
        _G.unpack or
        function(...)
          return {n = select('#', ...), ...}
        end
    end
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
        local init_base_prefix, init_rel_prefix = base_prefix, rel_prefix
        local list_without_tail_pattern = '(.+%.)[^%.]-%.$'
        local list_without_head_pattern = '[^%.]+%.(.+)$'
        while rel_prefix:find('^%^%.') do
          if (base_prefix == '') then
            error(
              ([[Link "%s" is outside caller's prefix "%s".]]):format(
                init_rel_prefix, init_base_prefix
              )
            )
          end
          base_prefix = base_prefix:match(list_without_tail_pattern) or ''
          rel_prefix = rel_prefix:match(list_without_head_pattern) or ''
        end
        return base_prefix .. rel_prefix
      end
    local names = {}
    local deep = 1
    local get_caller_prefix =
      function()
        local result = ''
        if names[deep] then
          result = names[deep].prefix
        end
        return result
      end
    local get_caller_name =
      function()
        local result = 'anonymous'
        if names[deep] then
          result = names[deep].prefix .. names[deep].name
        end
        return result
      end
    local push =
      function(prefix, name)
        deep = deep + 1
        names[deep] = {prefix = prefix, name = name}
      end
    local pop =
      function()
        deep = deep - 1
      end
    local dependencies = {}
    local add_dependency =
      function(src_name, dest_name)
        dependencies[src_name] = dependencies[src_name] or {}
        dependencies[src_name][dest_name] = true
      end
    local base_prefix = split_name((...))
    local request =
      function(qualified_name)
        local is_absolute_name = (qualified_name:sub(1, 2) == '!.')
        if is_absolute_name then
          qualified_name = qualified_name:sub(3)
        end
        local prefix, name = split_name(qualified_name)
        local src_name = get_caller_name()
        local caller_prefix = is_absolute_name and base_prefix or get_caller_prefix()
        prefix = unite_prefixes(caller_prefix, prefix)
        push(prefix, name)
        local dest_name = get_caller_name()
        add_dependency(src_name, dest_name)
        local require_name = prefix .. name
        local results = table.pack(require(require_name))
        pop()
        return table.unpack(results)
      end
    if not _G.request then
      _G.request = request
      _G.dependencies = dependencies
    end
    _G.new = request(base_prefix .. 'table.new')
  end
_G.package.preload['workshop.system.get_loaded_module_files'] =
  function(...)
    local split_string = request('^.string.split')
    local get_paths =
      function()
        local result = split_string(package.path, ';')
        return result
      end
    local get_module_names =
      function()
        local result = {}
        for k in pairs(package.loaded) do
          result[#result + 1] = k
        end
        return result
      end
    local file_exists = request('^.file.exists')
    return
      function()
        local result = {}
        local paths = get_paths()
        local modules = get_module_names()
        for i = 1, #modules do
          local aligned_module_name = modules[i]:gsub('%.', '/')
          for j = 1, #paths do
            local possible_script_name = paths[j]:gsub('%?', aligned_module_name)
            if file_exists(possible_script_name) then
              result[#result + 1] = possible_script_name
            end
          end
        end
        return result
      end
  end
_G.package.preload['workshop.file.exists'] =
  function(...)
    return
      function(file_name)
        local file_handle = io.open(file_name, 'r')
        local result = (file_handle ~= nil)
        if result then
          io.close(file_handle)
        end
        return result
      end
  end
_G.package.preload['workshop.mechs.compile'] =
  function(...)
    local unfold = request('^.table.unfold')
    return
      function(t, node_handlers)
        if is_string(t) then
          return t
        end
        assert_table(t)
        node_handlers = node_handlers or {}
        assert_table(node_handlers)
        local result = {}
        local compile
        compile =
          function(node)
            if is_string(node) then
              result[#result + 1] = node
            elseif is_table(node) then
              if node.type then
                local node_handler = node_handlers[node.type]
                assert(node_handler, ('No handler found for type "%s".'):format(node.type))
                result[#result + 1] = node_handler(node)
              else
                for i = 1, #node do
                  compile(node[i])
                end
              end
            end
          end
        compile(t)
        result = unfold(result)
        return table.concat(result)
      end
  end
_G.package.preload['workshop.mechs.indents_table'] =
  function(...)
    local init =
      function(self)
        setmetatable(
          self.indents,
          {
            __index =
              function(t, key)
                if is_integer(key) then
                  local value = self.indent_chunk:rep(key)
                  t[key] = value
                  return value
                end
              end,
          }
        )
      end
    return {indents = {}, init = init, indent_chunk = '  '}
  end
_G.package.preload['workshop.mechs.name_giver'] =
  function(...)
    return
      {
        names = {},
        counters = {['function'] = 0, ['thread'] = 0, ['userdata'] = 0, ['table'] = 0},
        templates =
          {
            ['function'] = 'f_%d',
            ['thread'] = 'th_%d',
            ['userdata'] = 'u_%d',
            ['table'] = 't_%d',
          },
        give_name =
          function(self, obj)
            if not self.names[obj] then
              local obj_type = type(obj)
              if not self.counters[obj_type] then
                error(('Argument type "%s" not supported for counting.'):format(obj_type), 2)
              end
              self.counters[obj_type] = self.counters[obj_type] + 1
              self.names[obj] = (self.templates[obj_type]):format(self.counters[obj_type])
            end
            return self.names[obj]
          end,
      }
  end
_G.package.preload['workshop.mechs.text_block.dec_indent'] =
  function(...)
    return
      function(self)
        self.next_line_indent = self.next_line_indent - 1
      end
  end
_G.package.preload['workshop.mechs.text_block.inc_indent'] =
  function(...)
    return
      function(self)
        self.next_line_indent = self.next_line_indent + 1
      end
  end
_G.package.preload['workshop.mechs.text_block.interface'] =
  function(...)
    return
      {
        line_with_text = request('line.interface'),
        processed_text = {},
        num_line_feeds = 0,
        store_textline = request('text.store_textline'),
        add_textline = request('text.add_textline'),
        add_curline = request('text.add_curline'),
        new_line = request('text.new_line'),
        request_clean_line = request('text.request_clean_line'),
        request_empty_line = request('text.request_empty_line'),
        on_clean_line = request('text.on_clean_line'),
        include = request('text.include'),
        get_text = request('text.get_text'),
        indent_chunk = '  ',
        next_line_indent = 0,
        inc_indent = request('inc_indent'),
        dec_indent = request('dec_indent'),
        max_text_width = 0,
        max_block_width = 0,
        get_text_width = request('text.get_text_width'),
        get_block_width = request('text.get_block_width'),
        init = request('init'),
      }
  end
_G.package.preload['workshop.mechs.text_block.init'] =
  function(...)
    return
      function(self)
        self.processed_text = {}
        self.line_with_text.indents_obj.indent_chunk = self.indent_chunk
        self.line_with_text:init()
        self.line_with_text.indent = self.next_line_indent
        self.num_line_feeds = 0
      end
  end
_G.package.preload['workshop.mechs.text_block.text.request_clean_line'] =
  function(...)
    return
      function(self)
        if not self:on_clean_line() then
          self:new_line()
        end
      end
  end
_G.package.preload['workshop.mechs.text_block.text.on_clean_line'] =
  function(...)
    return
      function(self)
        return
          (self.num_line_feeds > 0) or
          ((self.num_line_feeds == 0) and (self.line_with_text.text == ''))
      end
  end
_G.package.preload['workshop.mechs.text_block.text.get_text_width'] =
  function(...)
    return
      function(self)
        return math.max(self.max_text_width, self.line_with_text:get_text_length())
      end
  end
_G.package.preload['workshop.mechs.text_block.text.get_text'] =
  function(...)
    return
      function(self)
        self:store_textline()
        local result = table.concat(self.processed_text)
        return result
      end
  end
_G.package.preload['workshop.mechs.text_block.text.get_block_width'] =
  function(...)
    return
      function(self)
        return math.max(self.max_block_width, self.line_with_text:get_line_length())
      end
  end
_G.package.preload['workshop.mechs.text_block.text.new_line'] =
  function(...)
    return
      function(self)
        self.num_line_feeds = self.num_line_feeds + 1
      end
  end
_G.package.preload['workshop.mechs.text_block.text.add_textline'] =
  function(...)
    return
      function(self, s)
        self.line_with_text:add(s)
      end
  end
_G.package.preload['workshop.mechs.text_block.text.add_curline'] =
  function(...)
    return
      function(self, s)
        if (self.num_line_feeds > 0) and (s ~= '') then
          self:store_textline()
        end
        if (self.line_with_text.text == '') then
          self.line_with_text.indent = self.next_line_indent
        end
        self.line_with_text:add(s)
      end
  end
_G.package.preload['workshop.mechs.text_block.text.request_empty_line'] =
  function(...)
    return
      function(self)
        if not self:on_clean_line() then
          self:new_line()
        end
        if (self.num_line_feeds == 1) then
          self:new_line()
        end
      end
  end
_G.package.preload['workshop.mechs.text_block.text.include'] =
  function(...)
    return
      function(self, block, do_glue_border_lines)
        if not do_glue_border_lines then
          self:new_line()
        end
        self:store_textline()
        table.move(
          block.processed_text,
          1,
          #block.processed_text,
          #self.processed_text + 1,
          self.processed_text
        )
        self.line_with_text = block.line_with_text
      end
  end
_G.package.preload['workshop.mechs.text_block.text.store_textline'] =
  function(...)
    local trim_head_spaces = request('^.^.^.string.trim_head_spaces')
    local trim_tail_spaces = request('^.^.^.string.trim_tail_spaces')
    return
      function(self)
        local line_with_text = self.line_with_text
        line_with_text.text = trim_head_spaces(line_with_text.text)
        line_with_text.text = trim_tail_spaces(line_with_text.text)
        self.max_block_width = self:get_block_width()
        self.max_text_width = self:get_text_width()
        self.processed_text[#self.processed_text + 1] = line_with_text:get_line()
        for i = 1, self.num_line_feeds do
          self.processed_text[#self.processed_text + 1] = '\n'
        end
        self.num_line_feeds = 0
        line_with_text.text = ''
        line_with_text.indent = self.next_line_indent
      end
  end
_G.package.preload['workshop.mechs.text_block.line.get_text_length'] =
  function(...)
    return
      function(self)
        return utf8.len(self.text) or #self.text
      end
  end
_G.package.preload['workshop.mechs.text_block.line.add'] =
  function(...)
    return
      function(self, s)
        self.text = self.text .. s
      end
  end
_G.package.preload['workshop.mechs.text_block.line.get_line'] =
  function(...)
    return
      function(self)
        if (self.text == '') then
          return ''
        else
          return self.indents_obj.indents[self.indent] .. self.text
        end
      end
  end
_G.package.preload['workshop.mechs.text_block.line.interface'] =
  function(...)
    return
      {
        text = '',
        indent = 0,
        indents_obj = request('^.^.indents_table'),
        chunk_length = 0,
        init = request('init'),
        get_line_length = request('get_line_length'),
        get_text_length = request('get_text_length'),
        get_line = request('get_line'),
        add = request('add'),
      }
  end
_G.package.preload['workshop.mechs.text_block.line.get_line_length'] =
  function(...)
    return
      function(self)
        return self.indent * self.chunk_length + self:get_text_length()
      end
  end
_G.package.preload['workshop.mechs.text_block.line.init'] =
  function(...)
    return
      function(self)
        self.indents_obj:init()
        self.chunk_length = utf8.len(self.indents_obj.indent_chunk)
      end
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
_G.package.preload['workshop.mechs.graph.dfs.dfs'] =
  function(...)
    return
      function(self, graph)
        assert_table(graph)
        self.nodes_status = {}
        local handle_discovery = self.handle_discovery
        local handle_leave = self.handle_leave
        local table_iterator = self.table_iterator
        local iterate_table_keys = self.also_visit_keys
        local nodes_status = self.nodes_status
        local init_node_rec =
          function(node)
            nodes_status[node] = nodes_status[node] or {node = node}
          end
        local time = 0
        local dfs_visit
        local process =
          function(parent, parent_key, node, deep)
            init_node_rec(node)
            local node_rec = nodes_status[node]
            node_rec.refs = node_rec.refs or {}
            node_rec.refs[parent] = node_rec.refs[parent] or {}
            node_rec.refs[parent][parent_key] = true
            if not node_rec.color then
              node_rec.parent = parent
              node_rec.parent_key = parent_key
              dfs_visit(node, deep + 1)
            elseif (node_rec.color == 'gray') then
              node_rec.part_of_cycle = true
              nodes_status[parent].part_of_cycle = true
            end
          end
        dfs_visit =
          function(node, deep)
            time = time + 1
            local node_rec = nodes_status[node]
            node_rec.discovery_time = time
            node_rec.color = 'gray'
            handle_discovery(node, node_rec, deep)
            for k, v in table_iterator(node) do
              if is_table(v) then
                process(node, k, v, deep)
              end
              if is_table(k) and iterate_table_keys then
                process(node, k, k, deep)
              end
            end
            time = time + 1
            node_rec.color = 'black'
            node_rec.finish_time = time
            handle_leave(node, node_rec, deep)
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
        also_visit_keys = false,
        nodes_status = {},
        table_iterator = request('^.^.^.table.ordered_pass'),
        handle_discovery = empty_func,
        handle_leave = empty_func,
        run = request('dfs'),
      }
  end
_G.package.preload['workshop.formats.lua.load.keywords'] =
  function(...)
    local map_values = request('!.table.map_values')
    return
      map_values(
        {
          'nil',
          'true',
          'false',
          'not',
          'and',
          'or',
          'do',
          'end',
          'local',
          'function',
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
          'return',
        }
      )
  end
_G.package.preload['workshop.formats.lua.load.is_identifier'] =
  function(...)
    local keywords = request('keywords')
    return
      function(s)
        return is_string(s) and s:match('^[%a_][%w_]*$') and not keywords[s]
      end
  end
_G.package.preload['workshop.formats.lua.save.quote_string'] =
  function(...)
    local quote_linear = request('quote_string.linear')
    local quote_intact = request('quote_string.intact')
    local content_funcs = request('^.^.^.string.content_attributes')
    local has_control_chars = content_funcs.has_control_chars
    local has_backslashes = content_funcs.has_backslashes
    local has_single_quotes = content_funcs.has_single_quotes
    local has_double_quotes = content_funcs.has_double_quotes
    return
      function(s)
        assert_string(s)
        local quote_func
        if has_control_chars(s) then
          quote_func = quote_linear
        elseif has_backslashes(s) or (has_single_quotes(s) and has_double_quotes(s)) then
          quote_func = quote_intact
        else
          quote_func = quote_linear
        end
        local result = quote_func(s)
        return result
      end
  end
_G.package.preload['workshop.formats.lua.save.quote_string.intact'] =
  function(...)
    return
      function(s)
        assert_string(s)
        local min_needed_quotes = 0
        if (s:sub(-1) == ']') then
          min_needed_quotes = 1
        end
        local postfix, eq_chunk
        while true do
          eq_chunk = ('='):rep(min_needed_quotes)
          postfix = ']' .. eq_chunk .. ']'
          if not s:find(postfix, 1, true) then
            break
          end
          min_needed_quotes = min_needed_quotes + 1
        end
        local prefix = '[' .. eq_chunk .. '['
        if (s:sub(1, 2) == '\x0d\x0a') or (s:sub(1, 1) == '\x0a') then
          prefix = prefix .. '\n'
        end
        return prefix .. s .. postfix
      end
  end
_G.package.preload['workshop.formats.lua.save.quote_string.linear'] =
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
_G.package.preload['workshop.formats.lua.save.quote_string.quote_char'] =
  function(...)
    return
      function(c)
        return ([[\x%02x]]):format(c:byte(1, 1))
      end
  end
_G.package.preload['workshop.formats.lua.save.quote_string.custom_quotes'] =
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
_G.package.preload['workshop.formats.lua_table.save.get_ast'] =
  function(...)
    return
      function(self, data)
        local result
        local data_type = type(data)
        if (data_type == 'table') then
          if self.value_names[data] then
            result = {type = 'name', value = self.value_names[data]}
          else
            result = {}
            result.type = 'table'
            for key, value in self.table_iterator(data) do
              local key_slot = self:get_ast(key)
              local value_slot = self:get_ast(value)
              result[#result + 1] = {key = key_slot, value = value_slot}
            end
          end
        else
          result = {type = data_type, value = data}
        end
        return result
      end
  end
_G.package.preload['workshop.formats.lua_table.save.interface'] =
  function(...)
    return
      {
        init = request('init'),
        get_ast = request('get_ast'),
        serialize_ast = request('serialize_ast'),
        node_handlers = {},
        c_text_block = request('!.mechs.text_block.interface'),
        text_block = nil,
        value_names = {},
        table_iterator = request('!.table.ordered_pass'),
        install_node_handlers = request('install_node_handlers.readable'),
      }
  end
_G.package.preload['workshop.formats.lua_table.save.serialize_ast'] =
  function(...)
    local compile = request('!.mechs.compile')
    return
      function(self, ast)
        compile(ast, self.node_handlers)
        return self.text_block:get_text()
      end
  end
_G.package.preload['workshop.formats.lua_table.save.init'] =
  function(...)
    return
      function(self)
        self.text_block = new(self.c_text_block)
        self.text_block:init()
        self.install_node_handlers(self.node_handlers, self.text_block)
      end
  end
_G.package.preload['workshop.formats.lua_table.save.install_node_handlers.readable'] =
  function(...)
    local text_block
    local add =
      function(s)
        text_block:add_curline(s)
      end
    local request_clean_line =
      function()
        text_block:request_clean_line()
      end
    local inc_indent =
      function()
        text_block:inc_indent()
      end
    local dec_indent =
      function()
        text_block:dec_indent()
      end
    local node_handlers = {}
    local raw_compile = request('!.mechs.compile')
    local compile =
      function(t)
        add(raw_compile(t, node_handlers))
      end
    local is_identifier = request('!.formats.lua.load.is_identifier')
    local compact_sequences = true
    node_handlers.table =
      function(node)
        if (#node == 0) then
          add('{}')
          return
        end
        local last_integer_key = 0
        add('{')
        inc_indent()
        for i = 1, #node do
          local key, value = node[i].key, node[i].value
          request_clean_line()
          if
            compact_sequences and
            (key.type == 'number') and
            is_integer(key.value) and
            (key.value == last_integer_key + 1)
          then
            last_integer_key = key.value
          else
            if (key.type == 'string') and is_identifier(key.value) then
              add(key.value)
            else
              add('[')
              compile(key)
              add(']')
            end
            add(' = ')
          end
          compile(value)
          add(',')
        end
        dec_indent()
        request_clean_line()
        add('}')
      end
    local merge = request('!.table.merge')
    local install_minimal_handlers = request('minimal')
    return
      function(a_node_handlers, a_text_block, options)
        install_minimal_handlers(a_node_handlers, a_text_block, options)
        node_handlers = merge(a_node_handlers, node_handlers)
        text_block = a_text_block
        if options and is_boolean(options.compact_sequences) then
          compact_sequences = options.compact_sequences
        end
      end
  end
_G.package.preload['workshop.formats.lua_table.save.install_node_handlers.minimal'] =
  function(...)
    local text_block
    local add =
      function(s)
        text_block:add_curline(s)
      end
    local node_handlers = {}
    local raw_compile = request('!.mechs.compile')
    local compile =
      function(t)
        add(raw_compile(t, node_handlers))
      end
    local is_identifier = request('!.formats.lua.load.is_identifier')
    local compact_sequences = true
    node_handlers.table =
      function(node)
        if (#node == 0) then
          add('{}')
          return
        end
        local last_integer_key = 0
        add('{')
        for i = 1, #node do
          if (i > 1) then
            add(',')
          end
          local key, value = node[i].key, node[i].value
          if
            compact_sequences and
            (key.type == 'number') and
            is_integer(key.value) and
            (key.value == last_integer_key + 1)
          then
            last_integer_key = key.value
          else
            if (key.type == 'string') and is_identifier(key.value) then
              add(key.value)
            else
              add('[')
              compile(key)
              add(']')
            end
            add('=')
          end
          compile(value)
        end
        add('}')
      end
    do
      local serialize_tostring =
        function(node)
          add(tostring(node.value))
        end
      local tostring_datatypes = {'number', 'boolean', 'nil'}
      for i = 1, #tostring_datatypes do
        node_handlers[tostring_datatypes[i]] = serialize_tostring
      end
    end
    do
      local quote_string = request('!.formats.lua.save.quote_string')
      local serialize_quoted =
        function(node)
          local quoted_string = quote_string(tostring(node.value))
          if not text_block:on_clean_line() then
            local text_line = text_block.line_with_text:get_line()
            if (text_line:sub(-1) == '[') and (quoted_string:sub(1, 1) == '[') then
              add(' ')
            end
          end
          add(quoted_string)
        end
      local quoted_datatypes = {'string', 'function', 'thread', 'userdata'}
      for i = 1, #quoted_datatypes do
        node_handlers[quoted_datatypes[i]] = serialize_quoted
      end
    end
    node_handlers.name =
      function(node)
        compile(node.value)
      end
    local merge = request('!.table.merge')
    return
      function(a_node_handlers, a_text_block, options)
        node_handlers = merge(a_node_handlers, node_handlers)
        text_block = a_text_block
        if options and is_boolean(options.compact_sequences) then
          compact_sequences = options.compact_sequences
        end
      end
  end
_G.package.preload['workshop.formats.lua_table_code.save'] =
  function(...)
    local c_table_serializer = request('save.interface')
    return
      function(t, options)
        assert_table(t)
        local table_serializer = new(c_table_serializer, options)
        table_serializer:init()
        local ast = table_serializer:get_ast(t)
        local result = table_serializer:serialize_ast(ast)
        return result
      end
  end
_G.package.preload['workshop.formats.lua_table_code.save.get_ast'] =
  function(...)
    local get_num_refs =
      function(node_rec)
        local result = 0
        if node_rec.refs then
          local node = node_rec.node
          for parent, parent_keys in pairs(node_rec.refs) do
            if (parent == node) then
              result = result + 1
            end
            for key in pairs(parent_keys) do
              if (parent[key] == node) then
                result = result + 1
              end
              if (key == node) then
                result = result + 1
              end
            end
          end
        end
        return result
      end
    local may_print_inline =
      function(node_rec)
        return not node_rec or ((get_num_refs(node_rec) <= 1) and not node_rec.part_of_cycle)
      end
    local get_assembly_order = request('!.mechs.graph.assembly_order')
    local name_giver = request('!.mechs.name_giver')
    return
      function(self, data)
        local table_serializer = self.table_serializer
        local table_iterator = table_serializer.table_iterator
        local node_recs, nodes_ordered =
          get_assembly_order(data, {also_visit_keys = true, table_iterator = table_iterator})
        local result = {}
        local processed_tables = {}
        for i = 1, #nodes_ordered do
          local node = nodes_ordered[i]
          local node_rec = node_recs[node]
          if not may_print_inline(node_rec) or (node == data) then
            local table_rec
            if node_rec.part_of_cycle then
              table_rec = {type = 'table'}
              for k, v in table_serializer.table_iterator(node) do
                local key_is_ok = not is_table(k) or processed_tables[k]
                local value_is_ok = not is_table(v) or processed_tables[v]
                if key_is_ok and value_is_ok then
                  table_rec[#table_rec + 1] =
                    {key = table_serializer:get_ast(k), value = table_serializer:get_ast(v)}
                end
              end
            else
              table_rec = table_serializer:get_ast(node)
            end
            local node_name = name_giver:give_name(node)
            result[#result + 1] =
              {type = 'local_definition', name = node_name, value = table_rec}
            table_serializer.value_names[node] = node_name
          end
          processed_tables[node] = true
          if node_rec.part_of_cycle then
            for parent, parent_keys in pairs(node_rec.refs) do
              if processed_tables[parent] then
                for parent_key in pairs(parent_keys) do
                  local key_slot
                  local key_name = table_serializer.value_names[parent_key]
                  if key_name then
                    key_slot = {type = 'name', value = key_name}
                  else
                    key_slot = {type = type(parent_key), value = parent_key}
                  end
                  result[#result + 1] =
                    {
                      type = 'assignment',
                      name = table_serializer.value_names[parent],
                      index = {type = 'index', value = key_slot},
                      value = table_serializer.value_names[node],
                    }
                end
              end
            end
          end
        end
        result[#result + 1] =
          {type = 'return_statement', value = table_serializer.value_names[data]}
        return result
      end
  end
_G.package.preload['workshop.formats.lua_table_code.save.interface'] =
  function(...)
    return
      {
        init = request('init'),
        get_ast = request('get_ast'),
        serialize_ast = request('serialize_ast'),
        c_table_serializer = request('!.formats.lua_table.save.interface'),
        table_serializer = nil,
        install_node_handlers = request('install_node_handlers'),
      }
  end
_G.package.preload['workshop.formats.lua_table_code.save.serialize_ast'] =
  function(...)
    return
      function(self, ast)
        return self.table_serializer:serialize_ast(ast)
      end
  end
_G.package.preload['workshop.formats.lua_table_code.save.install_node_handlers'] =
  function(...)
    local text_block
    local node_handlers = {}
    local add =
      function(s)
        text_block:add_curline(s)
      end
    local request_clean_line =
      function()
        text_block:request_clean_line()
      end
    local raw_compile = request('!.mechs.compile')
    local compile =
      function(t)
        add(raw_compile(t, node_handlers))
      end
    node_handlers.local_definition =
      function(node)
        request_clean_line()
        add('local ')
        compile(node.name)
        add(' = ')
        compile(node.value)
      end
    local quote_string = request('!.formats.lua.save.quote_string')
    local is_identifier = request('!.formats.lua.load.is_identifier')
    node_handlers.index =
      function(node)
        if (node.value.type == 'string') and is_identifier(node.value.value) then
          add('.')
          add(node.value.value)
        else
          add('[')
          compile(node.value)
          add(']')
        end
      end
    node_handlers.assignment =
      function(node)
        request_clean_line()
        add(node.name)
        compile(node.index)
        add(' = ')
        compile(node.value)
      end
    node_handlers.return_statement =
      function(node)
        request_clean_line()
        add('return ')
        compile(node.value)
      end
    local merge = request('!.table.merge')
    return
      function(a_node_handlers, a_text_block)
        node_handlers = merge(a_node_handlers, node_handlers)
        text_block = a_text_block
      end
  end
_G.package.preload['workshop.formats.lua_table_code.save.init'] =
  function(...)
    return
      function(self)
        self.table_serializer = new(self.c_table_serializer)
        self.table_serializer:init()
        self.install_node_handlers(
          self.table_serializer.node_handlers, self.table_serializer.text_block
        )
      end
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
    local clone = request('^.table.clone')
    local patch = request('^.table.patch')
    return
      function(default_params, a_params)
        assert_table(default_params)
        local result = clone(default_params)
        if is_table(a_params) then
          patch(result, a_params)
        end
        return result
      end
  end
_G.package.preload['workshop.table.patch'] =
  function(...)
    local patch
    patch =
      function(t_src, t_patch)
        for k, v in pairs(t_patch) do
          if (t_src[k] == nil) then
            local err_msg = ('Destination table dont have key "%s".'):format(tostring(k))
            error(err_msg, 2)
          end
          if is_table(t_src[k]) and is_table(v) then
            patch(t_src[k], v)
          else
            t_src[k] = v
          end
        end
      end
    return patch
  end
_G.package.preload['workshop.table.map_values'] =
  function(...)
    return
      function(t)
        assert_table(t)
        local result = {}
        for k, v in pairs(t) do
          result[v] = true
        end
        return result
      end
  end
_G.package.preload['workshop.table.to_key_val'] =
  function(...)
    return
      function(t)
        assert_table(t)
        local result = {}
        for k, v in pairs(t) do
          result[#result + 1] = {key = k, value = v}
        end
        return result
      end
  end
_G.package.preload['workshop.table.merge'] =
  function(...)
    return
      function(t_dest, t_src)
        assert_table(t_src)
        assert_table(t_dest)
        for k, v in pairs(t_src) do
          t_dest[k] = v
        end
        return t_dest
      end
  end
_G.package.preload['workshop.table.unfold'] =
  function(...)
    return
      function(t)
        assert_table(t)
        local result = {}
        local unfold
        unfold =
          function(node)
            for i = 1, #node do
              if is_table(node[i]) then
                unfold(node[i])
              else
                result[#result + 1] = node[i]
              end
            end
          end
        unfold(t)
        return result
      end
  end
_G.package.preload['workshop.table.ordered_pass'] =
  function(...)
    local default_comparator = request('ordered_pass.default_comparator')
    local extract_keys = request('extract_keys')
    local to_key_val = request('to_key_val')
    return
      function(t, comparator)
        assert_table(t)
        comparator = comparator or default_comparator
        assert_function(comparator)
        local key_vals = to_key_val(t)
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
  end
_G.package.preload['workshop.table.extract_keys'] =
  function(...)
    return
      function(t)
        assert_table(t)
        local result = {}
        for k, v in pairs(t) do
          result[#result + 1] = k
        end
        return result
      end
  end
_G.package.preload['workshop.table.ordered_pass.default_comparator'] =
  function(...)
    local val_rank = {string = 1, number = 2, other = 3}
    local comparable_types = {number = true, string = true}
    return
      function(a, b)
        local result
        local a_key = a.key
        local a_key_type = type(a_key)
        local rank_a = val_rank[a_key_type] or val_rank.other
        local b_key = b.key
        local b_key_type = type(b_key)
        local rank_b = val_rank[b_key_type] or val_rank.other
        if (rank_a ~= rank_b) then
          return (rank_a < rank_b)
        else
          if comparable_types[a_key_type] and comparable_types[b_key_type] then
            return (a_key < b_key)
          else
            return (tostring(a_key) < tostring(b_key))
          end
        end
      end
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
    return
      {
        has_control_chars = has_control_chars,
        has_backslashes = has_backslashes,
        has_single_quotes = has_single_quotes,
        has_double_quotes = has_double_quotes,
      }
  end
_G.package.preload['workshop.string.split'] =
  function(...)
    return
      function(s, delim)
        assert_string(s)
        local delim = delim or '\n'
        local result = {}
        local last_pos = 1
        for line, _last_pos in string.gmatch(s, '(.-)' .. delim .. '()') do
          result[#result + 1] = line
          last_pos = _last_pos
        end
        result[#result + 1] = s:sub(last_pos)
        return result
      end
  end
_G.package.preload['workshop.string.trim_tail_spaces'] =
  function(...)
    return
      function(s)
        local result
        if (s:sub(-1, -1) == ' ') then
          local finish_pos = #s - 1
          while (s:sub(finish_pos, finish_pos) == ' ') do
            finish_pos = finish_pos - 1
          end
          result = s:sub(1, finish_pos)
        else
          result = s
        end
        return result
      end
  end
_G.package.preload['workshop.string.trim_head_spaces'] =
  function(...)
    return
      function(s)
        local result
        if (s:sub(1, 1) == ' ') then
          local start_pos = 2
          while (s:sub(start_pos, start_pos) == ' ') do
            start_pos = start_pos + 1
          end
          result = s:sub(start_pos)
        else
          result = s
        end
        return result
      end
  end
return require('test')