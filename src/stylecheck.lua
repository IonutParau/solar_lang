StyleChecker = {}

---@param name string
---@return boolean
function StyleChecker:goodVariableName(name)
  return string.lower(name) == name
end

---@param name string
---@return boolean
function StyleChecker:goodTypeName(name)
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