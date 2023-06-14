---@class Parser
---@field tokenStream Token[]
---@field idx integer
Parser = {}

---@param lexer Lexer
---@return Parser
function Parser:newFromLexer(lexer)
  ---@type Parser
  local parser = setmetatable({}, { __index = self })

  parser:grabTokenStream(lexer)

  return parser
end

---@param lexer Lexer
function Parser:grabTokenStream(lexer)
  local tokens = {}

  while true do
    local token = lexer:nextToken()
    table.insert(tokens, token)

    if token.type == "eof" then
      break
    end
  end

  self.tokenStream = tokens
  self.idx = 1
end

---@param off integer|nil
---@return Token
function Parser:peekToken(off)
  off = off or 0

  return self.tokenStream[self.idx + off] or self.tokenStream[#self.tokenStream]
end

---@return Token
function Parser:nextToken()
  local token = self.tokenStream[self.idx]
  self.idx = self.idx + 1
  return token or self.tokenStream[#self.tokenStream]
end

---@param curdir string
---@return AST[]
function Parser:parseCode(curdir)
  ---@type AST[]
  local asts = {}

  while self:peekToken().type ~= "eof" do
    if self:peekToken().type == ";" then
      self:nextToken()
    else
      table.insert(asts, self:topLevelStatement(curdir))
    end
  end

  return asts
end

---@param min_bp number|nil
---@return AST
function Parser:type(min_bp, noGenerics)
  min_bp = min_bp or 0

  local token = self:nextToken()
  local lhs = AST("invalid", nil, {}, token.source)

  if token.type == "$" then
    if noGenerics then
      error("Can't have generics in this type expression")
    end
    -- GENERIC!!!!!

    local name = self:nextToken()
    assert(name.type == "identifier", "<identifier> expected")

    if self:peekToken().type == "where" then
      ---@type AST[]
      local needToBeValid = {}

      needToBeValid[#needToBeValid+1] = self:type(nil, true)

      while true do
        if self:peekToken().type == "&&" then
          self:nextToken()
          needToBeValid[#needToBeValid+1] = self:type(nil, true)
        else
          break
        end
      end
      return AST("generic-def", name.content, needToBeValid, token.source)
    else
      return AST("generic-def", name.content, {}, token.source)
    end
  end

  if token.type == "identifier" then
    -- TODO: named types
  end

  if token.type == "[" then
    local type = self:type()
    assert(self:nextToken().type == "]", "] expected")

    lhs = AST("list-type", nil, { type }, token.source)
  end

  if token.type == "{" then
    local key = self:type()
    assert(self:nextToken().type == "->", "-> expected")
    local value = self:type()
    assert(self:nextToken().type == "}", "} expected")

    lhs = AST("table-kv-type", nil, { key, value }, token.source)
  end

  if token.type == "interface" then
    assert(self:nextToken().type == "{")

    ---@type string[]
    local fields = {}
    ---@type AST[]
    local values = {}

    if self:peekToken().type == "}" then
      lhs = AST("interface-type", fields, values, token.source)
    else
      local field = self:nextToken()
      assert(field.type == "identifier", "<identifier> expected")

      assert(self:nextToken().type == "=", "= expected")

      local value = self:type()

      fields[#fields + 1] = field.content
      values[#values + 1] = value

      while true do
        if self:peekToken().type == "}" then
          self:nextToken()
          break
        elseif self:peekToken().type == "," then
          self:nextToken()
          local field = self:nextToken()
          assert(field.type == "identifier", "<identifier> expected")

          assert(self:nextToken().type == "=", "= expected")

          local value = self:type()

          fields[#fields + 1] = field.content
          values[#values + 1] = value
        else
          error("} or , expected")
        end
      end

      lhs = AST("interface-type", fields, values, token.source)
    end
  end


  -- Prefix operators
  local is_prefix, prefix_binding_power = self:prefix_binding_power(token)

  if is_prefix then
    lhs = AST("type_prefix_op", token.content, { self:type(prefix_binding_power) }, token.source)
  end

  assert(lhs.type ~= "invalid", "expected <identifier>, [, { or interface")

  while true do
    local op = self:peekToken()

    if op.type == "eof" then
      break
    end

    local is_infix, lbp, rbp = self:infix_bindig_power(op)

    if is_infix then
      if lbp < min_bp then
        break
      end

      self:nextToken()
      local rhs = self:type(rbp)

      return AST("type_infix_op", op.content, { lhs, rhs }, op.source)
    else
      break
    end
  end

  return lhs
end

---@return AST
function Parser:statement()
  local token = self:nextToken()

  if token.type == "local" then
    -- Local definition
    local mutable = false

    if self:peekToken().type == "mut" then
      self:nextToken()
      mutable = true
    end

    local nameToken = self:nextToken()
    assert(nameToken.type == "identifier", "<identifier> expected")
    StyleChecker:assertGoodVariableName(nameToken)

    if self:peekToken().type == "=" then
      self:nextToken()

      -- Initialized

      local value = self:expression()

      return AST("varDef", { name = nameToken.content, mutable = mutable }, { value }, token.source)
    else
      -- Uninitialized

      return AST("varDef", { name = nameToken.content, mutable = mutable }, {}, token.source)
    end
  end

  if token.type == "while" then
    local condition = self:expression()

    assert(self:nextToken().type == "do", "do expected")
    local body = {}
    while self:peekToken() ~= "end" do
      table.insert(body, self:statement())
    end
    return AST("while", condition, body, token.source)
  end

  if token.type == "loop" then
    ---@type AST[]
    local statements = {}

    while self:peekToken().type ~= "end" do
      if self:peekToken().type == "eof" then
        error("end expected, got <eof>")
      end

      statements[#statements + 1] = self:statement()
    end
    self:nextToken()

    return AST("loop", nil, statements, token.source)
  end
  self.idx = self.idx - 1 -- time travel

  ---@type AST
  local expr = self:expression()

  if self:can_assign(expr) then
    if self:peekToken().type == "=" then
      print("assign")
      -- assignment
      local source = self:nextToken().source

      local rhs = self:expression()

      return AST("single-assign", nil, { expr, rhs }, source)
    elseif self:peekToken().type == "," then
      -- multi-assignment

      local source = self:nextToken().source

      local other = self:expression()
      assert(self:can_assign(other), "expression is not assignable")

      ---@type AST[]
      local toAssign = { expr, other }
      ---@type AST[]
      local values = {}

      local lookingAtValues = false

      while true do
        if self:peekToken().type == "," then
          self:nextToken()
          local next_expr = self:expression()

          if lookingAtValues then
            values[#values + 1] = next_expr
          else
            toAssign[#toAssign + 1] = next_expr
          end
        elseif self:peekToken().type == "=" and not lookingAtValues then
          self:nextToken()
          local next_expr = self:expression()

          lookingAtValues = true

          -- assuming some random goofy-ahh radiation from the sun didn't corrupt this table, this table is empty
          -- so, this should be perfectly safe
          values[1] = next_expr
        else
          if not lookingAtValues then
            error("Expected to reach =")
          end
          break
        end
      end

      return AST("multi-assign", #toAssign, { table.unpack(toAssign), table.unpack(values) }, source)
    else
      error("unexpected <expression>")
    end
  elseif expr.type == "MethodCall" or expr.type == "FuncCall" then
    return expr
  else
    error("unexpected <expression>")
  end
end

---@param expr AST
---@return boolean
function Parser:can_assign(expr)
  if expr.type == "." then
    return true
  end

  if expr.type == "var" then
    return true
  end

  return false
end

---@param op Token
---@return boolean, number, number
function Parser:infix_bindig_power(op)
  if op.type == "+" or op.type == "-" then
    return true, 95, 96
  end

  if op.type == "*" or op.type == "/" then
    return true, 98, 97
  end

  if op.type == "^" then
    return true, 101, 100
  end

  if op.type == ".." then
    return true, 94, 93
  end

  if op.type == "<" then
    return true, 91, 92
  end

  if op.type == ">" then
    return true, 89, 90
  end

  if op.type == "<=" then
    return true, 89, 90
  end

  if op.type == ">=" then
    return true, 89, 90
  end

  if op.type == "~=" then
    return true, 89, 90
  end

  if op.type == "==" then
    return true, 89, 90
  end

  if op.type == "and" then
    return true, 87, 88
  end

  if op.type == "or" then
    return true, 85, 86
  end

  return false, 0, 0
end

---@param op Token
---@return boolean, number
function Parser:prefix_binding_power(op)
  if op.type == "-" then
    return true, 99
  end

  if op.type == "not" then
    return true, 99
  end

  if op.type == "#" then
    return true, 99
  end

  return false, 0
end

---@param str string
---@return number
function Parser:parse_number(str)
  local n = 0
  local a = 1
  local fraction = false

  for i = 1, #str do
    local c = str:sub(i, i)

    if c == "." then
      fraction = true
    else
      local digit = c:byte() - string.byte('0')
      if fraction then
        a = a / 10
        n = n + digit * a
      else
        n = n * 10
        n = n + digit
      end
    end
  end

  return n
end

---@param min_bp integer|nil
---@return AST
function Parser:expression(min_bp)
  min_bp = min_bp or 0
  local token = self:nextToken()

  ---@type AST
  local lhs

  if token.type == "string-literal" then
    lhs = AST("const-string", token.content, {}, token.source)
  end

  if token.type == "number-literal" then
    lhs = AST("const-number", self:parse_number(token.content), {}, token.source)
  end

  if token.type == "true" then
    lhs = AST("const-bool", true, {}, token.source)
  end

  if token.type == "false" then
    lhs = AST("const-bool", false, {}, token.source)
  end

  if token.type == "identifier" then
    lhs = AST("var", token.content, {}, token.source)
    -- Index, Self-Index and Function Calls

    while true do
      if self:peekToken().type == "." then
        self:nextToken()
        local field = self:nextToken()
        assert(field.type == "identifier", "<identifier> expected")
        lhs = AST(".", field.content, { lhs }, field.source)
      elseif self:peekToken().type == ":" then
        self:nextToken()
        local field = self:nextToken()
        assert(field.type == "identifier", "<identifier> expected")
        assert(self:nextToken().type == "(", "( expected")
        local params = {}
        if self:peekToken().type ~= ")" then
          table.insert(params, self:expression())
          while true do
            if self:peekToken().type == ")" then
              self:nextToken()
              break
            elseif self:peekToken().type == "," then
              self:nextToken()
              table.insert(params, self:expression())
            else
              error(", or ) expected")
            end
          end
        else
          self:nextToken()
        end
        lhs = AST("MethodCall", { value = lhs, field = field.content }, params, field.source)
      elseif self:peekToken().type == "(" then
        local source = self:nextToken().source
        local params = {}
        if self:peekToken().type ~= ")" then
          table.insert(params, self:expression())
          while true do
            if self:peekToken().type == ")" then
              self:nextToken()
              break
            elseif self:peekToken().type == "," then
              self:nextToken()
              table.insert(params, self:expression())
            else
              error(", or ) expected, got internal token type: " .. self:peekToken().type)
            end
          end
        else
          self:nextToken()
        end
        lhs = AST("FuncCall", lhs, params, source)
      else
        break
      end
    end
  end

  -- Prefix Operators
  local is_prefix_op, op_power = self:prefix_binding_power(token)
  if is_prefix_op then
    local rhs = self:expression(op_power)
    lhs = AST("prefix-op", token.type, { rhs }, token.source)
  end

  if not lhs then
    return AST("invalid", token, {}, token.source)
  end

  -- Other Operators

  while true do
    local op = self:peekToken()
    if op.type == "eof" then
      break
    end

    -- infix
    local is_infix, l_bp, r_bp = self:infix_bindig_power(op)
    if is_infix then
      if l_bp < min_bp then
        break
      end

      self:nextToken()
      local rhs = self:expression(r_bp)

      lhs = AST("op_use", op.type, { lhs, rhs }, op.source)
    else
      break
    end
  end

  return lhs
end

---@param curdir string
---@param path string
---@return string, string
function Parser:resolve_comptime_paths(curdir, path)
  local nextdir = ""
  local nextpath = path

  if #curdir == 0 then
    nextpath = path
  end

  for i = 1, #nextpath do
    if nextpath:sub(i, i) == "/" then
      nextdir = nextpath:sub(1, i - 1)
    end
  end

  return nextdir, nextpath
end

---@class TypeInfo
---@field path string[]
---@field generics TypeDefinition[]

---@class GenericDefinition
---@field name string
---@field constraints AST[]

---@class TypeDefinition
---@field generic GenericDefinition|nil
---@field typeInfo TypeInfo|nil

---@class FunctionDefinition
---@field path string[]
---@field arguments {name: string, definition: TypeDefinition}[]
---@field returnType TypeDefinition

---@param curdir string
---@return AST
function Parser:topLevelStatement(curdir)
  local token = self:nextToken()

  if token.type == "module" then
    ---@type string[]
    local path = {}
    local nameToken = self:nextToken()
    assert(nameToken.type == "identifier", "<identifier> expected")
    table.insert(path, nameToken.content)

    while self:peekToken().type == "." do
      self:nextToken()
      local subnameToken = self:nextToken()
      table.insert(path, subnameToken.content)
    end

    return AST("moduleDefinition", path, {}, token.source)
  end

  if token.type == "fun" then
    ---@type string[]
    local path = {}
    local nameToken = self:nextToken()
    table.insert(path, nameToken.content)

    while self:peekToken().type == "." do
      self:nextToken()
      local subnameToken = self:nextToken()
      assert(subnameToken.type == "identifier", "<identifier> expected")
      table.insert(path, subnameToken.content)
    end

    assert(self:nextToken().type == "(", "( expected")

    local args = {}

    while true do
      if self:peekToken().type == ")" then
        self:nextToken()
        break
      elseif self:peekToken().type == "," then
        self:nextToken()
        local name = self:nextToken()
        assert(name.type == "identifier", "<identifier> expected")
        local type
        if self:peekToken().type == ":" then
          self:nextToken()
          type = self:type()
        end
        table.insert(args, { name = name.content, type = type })
      elseif #args == 0 and self:peekToken().type == "identifier" then
        local name = self:nextToken()
        assert(name.type == "identifier", "<identifier> expected")
        StyleChecker:assertGoodVariableName(name)
        local type
        if self:peekToken().type == ":" then
          self:nextToken()
          type = self:type()
        end
        table.insert(args, { name = name.content, type = type })
      else
        error(", or ) expected")
      end
    end

    local returnType
    if self:peekToken().type == "->" then
      self:nextToken()
      local type = self:type()
      if type.type == "generic-def" then
        error("Return type can not be generic")
      end

      returnType = type
    end

    local stuff = self:nextToken()
    local body

    if stuff.type == "=" then
      body = AST("return", nil, { self:expression() }, token.source)
    end

    if stuff.type == "=>" then
      body = self:statement()
    end

    if stuff.type == "do" then
      local statements = {}

      while self:peekToken().type ~= "end" do
        table.insert(statements, self:statement())
      end

      self:nextToken()

      body = AST("body", nil, statements, token.source)
    end

    assert(body ~= nil, "Unable to determine body-type of function from " .. stuff.content)

    return AST("functionDefinition", { path = path, arguments = args, returnType = returnType }, { body }, token.source)
  end

  if token.type == "do" then
    local statements = {}

    while self:peekToken().type ~= "end" do
      table.insert(statements, Parser:statement())
    end

    self:nextToken()

    return AST("body", nil, statements, token.source)
  end

  if token.type == "link" then
    local path = self:nextToken()
    assert(path.content == "string-literal", "Expected string literal")

    local _, fullPath = self:resolve_comptime_paths(curdir, path.content)

    return AST("linkLua", fullPath, {}, token.source)
  end

  if token.type == "import" then
    local path = self:nextToken()
    assert(path.content == "string-literal", "Expected string literal")

    local dir, fullPath = self:resolve_comptime_paths(curdir, path.content)

    local file = io.open(fullPath, "r")
    if not file then
      error("Unable to open file " .. fullPath)
    end

    local src = file:read("*all")

    local subparser = self:newFromLexer(Lexer:new(fullPath, dir))

    local code = self:parseCode(dir)

    file:close()

    return AST("importSolar", { dir = curdir, path = fullPath }, code, token.source)
  end

  if token.type == ";" then
    return self:topLevelStatement(curdir)
  end

  return AST("invalid", token.content, {}, token.source)
end
