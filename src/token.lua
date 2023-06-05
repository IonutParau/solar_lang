---@class Source
---@field ch integer
---@field ln integer
---@field file string

---@param ch integer
---@param ln integer
---@param file string
---@return Source
function Source(ch, ln, file)
  return {
    ch = ch,
    ln = ln,
    file = file,
  }
end

---@class Token
---@field type string
---@field content string
---@field source Source

---@param type string
---@param content string
---@param source Source
---@return Token
function Token(type, content, source)
  return {
    type = type,
    content = content,
    source = source,
  }
end
