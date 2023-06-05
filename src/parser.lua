---@class Parser
---@field tokenStream Token[]
---@field idx integer
Parser = {}

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

---@return AST[]
function Parser:parseCode()
  ---@type AST[]
  local asts = {}

  while self:peekToken().type ~= "eof" do
    if self:peekToken().type == ";" then
      self:nextToken()
    else
      print(self:peekToken().type)
      table.insert(asts, self:topLevelStatement())
    end
  end

  return asts
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
---@field body AST

---@return AST
function Parser:topLevelStatement()
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

    return AST("functionDefinition", { path = path, arguments = args, returnType = {}, body = nil }, {}, token.source)
  end

  return AST("invalid", token.content, {}, token.source)
end
