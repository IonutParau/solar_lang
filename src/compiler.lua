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

    if #ast.subnodes == 1 and ast.subnodes[1].type == "body" then
      body = {}

      for i = 1, #ast.subnodes[1].subnodes do
        body[i] = self:compileStatement(ast.subnodes[1].subnodes[i])
      end

      return "function " ..
          compiledName .. "(" .. table.concat(argnames, ",") .. ") " .. table.concat(body, " ") .. " end"
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

  if ast.type == "loop" then
    ---@type string[]
    local subcode = {}

    for i = 1, #ast.subnodes do
      subcode[i] = self:compileStatement(ast.subnodes[i])
    end

    return "while true do " .. table.concat(subcode, " ") .. " end"
  end

  if ast.type == "body" then
    ---@type string[]
    local subcode = {}

    for i = 1, #ast.subnodes do
      subcode[i] = self:compileStatement(ast.subnodes[i])
    end

    return "do " .. table.concat(subcode, " ") .. " end"
  end

  if ast.type == "FuncCall" then
    local args = {}

    for i = 1, #ast.subnodes do
      args[i] = self:compileExpression(ast.subnodes[i])
    end

    return self:compileExpression(ast.data) .. "(" .. table.concat(args, ",") .. ")"
  end

  if ast.type == "MethodCall" then
    local args = {}

    for i = 1, #ast.subnodes do
      args[i] = self:compileExpression(ast.subnodes[i])
    end

    return self:compileExpression(ast.data.value) .. ":" .. ast.data.field .. "(" .. table.concat(args, ",") .. ")"
  end

  if ast.type == "single-assign" then
    local expr = ast.subnodes[1]
    local value = ast.subnodes[2]

    return self:compileExpression(expr) .. " = " .. self:compileExpression(value)
  end

  if ast.type == "multi-assign" then
    ---@type integer
    local toAssignc = ast.data

    ---@type AST[]
    local toAssign = {}
    ---@type AST[]
    local values = {}

    for i=1, #ast.subnodes do
      if i <= toAssignc then
        toAssign[i] = ast.subnodes[i]
      else
        values[#values+1] = ast.subnodes[i]
      end
    end

    ---@type string[]
    local cToAssign = {}
    ---@type string[]
    local cValues = {}

    for i=1, #toAssign do
      cToAssign[i] = self:compileExpression(toAssign[i])
    end

    for i=1, #values do
      cValues[i] = self:compileExpression(values[i])
    end

    return table.concat(cToAssign, ",") .. " = " .. table.concat(cValues, ",")
  end

  if ast.type == "varDef" then
    local name = ast.data.name

    local value = ast.subnodes[1]

    return "local " .. name .. " = " .. self:compileExpression(value)
  end

  error("Malformed AST! Attempt to compile " .. ast.type .. " as a statement")
end

---@param ast AST
---@return string
function Emitter:compileExpression(ast)
  if ast.type == "op_use" then
    return "(" ..
        self:compileExpression(ast.subnodes[1]) ..
        " " .. ast.data .. " " .. self:compileExpression(ast.subnodes[2]) .. ")"
  end

  if ast.type == "prefix-op" then
    return "(" .. ast.data .. self:compileExpression(ast.subnodes[1]) .. ")"
  end

  if ast.type == "." then
    local field = ast.data
    local of = ast.subnodes[1]

    return self:compileExpression(of) .. "." .. field
  end

  if ast.type == "FuncCall" then
    local args = {}

    for i = 1, #ast.subnodes do
      args[i] = self:compileExpression(ast.subnodes[i])
    end

    return self:compileExpression(ast.data) .. "(" .. table.concat(args, ",") .. ")"
  end

  if ast.type == "MethodCall" then
    local args = {}

    for i = 1, #ast.subnodes do
      args[i] = self:compileExpression(ast.subnodes[i])
    end

    return self:compileExpression(ast.data.value) .. ":" .. ast.data.field .. "(" .. table.concat(args, ",") .. ")"
  end

  if ast.type == "var" then
    return ast.data
  end

  if ast.type == "const-string" then
    local str = ""

    ---@type string
    local conststr = ast.data

    for i = 1, #conststr do
      local c = conststr:sub(i, i)

      if c == '\n' then
        str = str .. '\\n'
      elseif c == '\r' then
        str = str .. '\\r'
      elseif c == '\\' then
        str = str .. '\\\\'
      else
        str = str .. c
      end
    end

    return '"' .. str .. '"'
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
