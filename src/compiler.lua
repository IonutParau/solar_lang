Emitter = {}

function Emitter:new()
  return setmetatable({}, { __index = self })
end

---@param asts AST[]
function Emitter:takeASTs(asts)
  self.asts = asts
end

---@param ast AST
---@return string
function Emitter:compileStatement(ast)
  if ast.type == "moduleDefinition" then
    ---@type string[]
    local name = ast.data

    local compiledName = name[1]

    for i = 2, #name do
      compiledName = compiledName .. "." .. name[i]
    end

    return compiledName .. " = {}"
  end

  if ast.type == "functionDefinition" then
    ---@type FunctionDefinition
    local info = ast.data

    ---@type string[]
    local name = info.path

    local compiledName = name[1]

    for i = 2, #name do
      compiledName = compiledName .. "." .. name[i]
    end

    ---@type string[]
    local argnames = {}

    for i = 1, #info.arguments do
      argnames[i] = info.arguments[i].name
    end

    ---@type string[]
    local body = {}

    for i = 1, #ast.subnodes do
      body[i] = self:compileStatement(ast.subnodes[i])
    end

    return "function " ..
        compiledName .. "(" .. table.concat(argnames, ",") .. ") " .. table.concat(body, " ") .. " end"
  end

  if ast.type == "return" then
    ---@type string[]
    local subcode = {}

    for i = 1, #ast.subnodes do
      subcode[i] = self:compileExpression(ast.subnodes[i])
    end

    local exprCode = subcode[1]

    for i = 2, #ast.subnodes do
      exprCode = exprCode .. "," .. subcode[i]
    end

    return "return " .. exprCode
  end

  error("Malformed AST! Attempt to compile " .. ast.type .. " as a statement")
end

---@param ast AST
---@return string
function Emitter:compileExpression(ast)
  if ast.type == "op_use" then
    return self:compileExpression(ast.subnodes[1]) .. " " .. ast.data .. " " .. self:compileExpression(ast.subnodes[2])
  end

  if ast.type == "prefix-op" then
    return ast.data .. self:compileExpression(ast.subnodes[1])
  end

  if ast.type == "var" then
    return ast.data
  end

  error("Malformed AST! Attempt to compile " .. ast.type .. " as an expression")
end

---@return string
function Emitter:compile()
  ---@type string[]
  local code = {}

  for i = 1, #self.asts do
    code[i] = self:compileStatement(self.asts[i])
  end

  return table.concat(code, " ")
end
