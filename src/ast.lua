---@class AST
---@field type string
---@field data any
---@field subnodes AST[]

---@param type string
---@param data any
---@param subnodes AST[]
---@param source Source
---@return AST
function AST(type, data, subnodes, source)
  return {
    type = type,
    data = data,
    subnodes = subnodes,
    source = source,
  }
end

---@param ast AST
function DumpAST(ast, indentation)
  indentation = indentation or 0

  local indent = ''

  for i = 1, indentation do
    indent = indent .. ' '
  end

  print(indent .. '[')
  print(indent .. '  type: ' .. ast.type)
  print(indent .. '  data: ' .. tostring(ast.data))
  if #ast.subnodes == 0 then
    print(indent .. '  subnodes: none')
  else
    print(indent .. '  subnodes:')
    for i = 1, #ast.subnodes do
      local subnode = ast.subnodes[i]
      DumpAST(subnode, indentation + 4)
    end
  end
  print(indent .. ']')
end
