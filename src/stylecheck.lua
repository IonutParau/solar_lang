StyleChecker = {}

---@param name string
---@return boolean
function StyleChecker:goodVariableName(name)
  return string.lower(name) == name
end

---@param token Token
function StyleChecker:assertGoodVariableName(token)
  assert(StyleChecker:goodVariableName(token.content), token.content .. " is not a good variable name. Variable name style guide is all lowercase, use _ to seperate words")
end

---@param name string
---@return boolean
function StyleChecker:goodTypeName(name)
  if name:sub(1, 1):lower() == name:sub(1, 1) then
    return false
  end
  
  for i=1, #name do
    if not Lexer:isAlphabetic(name:sub(i, i)) then
      return false
    end
  end

  return true
end

---@param name string
---@return boolean
function StyleChecker:goodFunctionName(name)
  return self:goodTypeName(name)
end

---@param name string
---@return boolean
function StyleChecker:goodModuleName(name)
  return self:goodTypeName(name)
end