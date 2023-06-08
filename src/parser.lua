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

    if self:peekToken().type == "=" then
      self:nextToken()

      -- Initialized

      local value = self:expression()

      return AST("varDef", {name = nameToken.content, mutable = mutable}, {value}, token.source)
    else
      -- Uninitialized

      return AST("varDef", {name = nameToken.content, mutable = mutable}, {}, token.source)
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

      statements[#statements+1] = self:statement()
    end
    self:nextToken()

    return AST("loop", nil, statements, token.source)
  end
  self.idx = self.idx - 1 -- time travel

  ---@type AST
  local expr = self:expression()

  if expr.type == "FuncCall" then
    return expr -- function call can also be statement
  elseif expr.type == "MethodCall" then
    return expr
  else
    if self:peekToken().type == "=" then
      -- assignment
      local source = self:nextToken().source

      local rhs = self:expression()

      return AST("single-assign", nil, {expr, rhs}, source)
    elseif self:peekToken().type == "," then
      -- multi-assignment
      --TODO: multi-assignment
      error("TODO: multi-assignment")
    else
      error("unexpected <expression>")
    end
  end
end

---@param op Token
---@return boolean, number, number
function Parser:infix_bindig_power(op)
  if op.type == "+" or op.type == "-" then
    return true, 95, 96
  end

  if op.type == "*" or op.type == "/" then
    return true, 97, 98
  end

  if op.type == "^" then
    return true, 100, 101
  end

  if op.type == ".." then
    return true, 93, 94
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
        lhs = AST("index", field.content, {lhs}, field.source)
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
        lhs = AST("MethodCall", {value = lhs, field = field.content}, params, field.source)
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
              error(", or ) expected")
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

    ---@type {name: string, definition: TypeDefinition}[]
    local args = {}

    while true do
      if self:peekToken().type == ")" then
        self:nextToken()
        break
      elseif self:peekToken().type == "," then
        self:nextToken()
        local name = self:nextToken()
        assert(name.type == "identifier", "<identifier> expected")

        --TODO: Add support for types once parser can parse types.
        table.insert(args, { name = name.content, definition = {} })
      elseif #args == 0 and self:peekToken().type == "identifier" then
        local name = self:nextToken()
        table.insert(args, { name = name.content, definition = {} })
      else
        error(", or ) expected")
      end
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

      return AST("body", nil, statements, token.source)
    end

    assert(body ~= nil, "Unable to determine body-type of function from " .. stuff.content)

    return AST("functionDefinition", { path = path, arguments = args, returnType = {} }, { body }, token.source)
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
