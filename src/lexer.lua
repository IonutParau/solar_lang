---@class Lexer
---@field file string
---@field content string
---@field ch string
---@field idx integer
Lexer = {}

---@param file string
---@param content string
---@return Lexer
function Lexer:new(file, content)
  ---@type Lexer
  local lexer = setmetatable({}, { __index = self })

  lexer:setState(file, content)

  return lexer
end

---@param file string
---@param content string
function Lexer:setState(file, content)
  self.file = file
  self.content = content
  self.idx = 1
  self.ch = content:sub(self.idx, self.idx)
  self.source = Source(1, 1, file)
end

---@return string
function Lexer:nextChar()
  self.ch = self.content:sub(self.idx, self.idx)
  self.idx = self.idx + 1
  return self.ch
end

---@return string
function Lexer:skipChar()
  self.idx = self.idx + 1
  self.ch = self.content:sub(self.idx, self.idx)
  return self.ch
end

---@return string
function Lexer:peekChar()
  self.ch = self.content:sub(self.idx, self.idx)
  return self.ch
end

function Lexer:skipWhitespace()
  while true do
    local ch = self:peekChar()

    if ch ~= "\n" and ch ~= "\r" and ch ~= "\t" and ch ~= " " then
      break
    end

    self:skipChar()
  end
end

---@param amount integer
function Lexer:peekString(amount)
  return self.content:sub(self.idx, self.idx + amount - 1)
end

---@param ch string
---@return boolean
function Lexer:isNumber(ch)
  local n = ch:byte(1, 1)
  local n0 = string.byte('0', 1, 1)
  local n9 = string.byte('9', 1, 1)

  return n >= n0 and n <= n9
end

---@param ch string
---@return boolean
function Lexer:isAlphabetic(ch)
  local n = ch:byte(1, 1)
  local a = string.byte('a', 1, 1)
  local z = string.byte('z', 1, 1)
  local A = string.byte('A', 1, 1)
  local Z = string.byte('Z', 1, 1)

  return (n >= a and n <= z) or (n >= A and n <= Z)
end

---@param ch string
---@return boolean
function Lexer:isAlphanumeric(ch)
  return self:isAlphabetic(ch) or self:isNumber(ch)
end

---@param ch string
---@return boolean
function Lexer:isLiteralChar(ch)
  return self:isAlphanumeric(ch) or ch == "_"
end

---@param str string
---@return boolean
function Lexer:followedBy(str)
  return self:peekString(#str) == str
end

---@type {[string]: string}
Lexer.keywords = {
  ["fun"] = "fun",
  ["local"] = "local",
  ["module"] = "module",
  ["return"] = "return",
  ["do"] = "do",
  ["end"] = "end",
  ["while"] = "while",
  ["if"] = "if",
  ["then"] = "then",
  ["else"] = "else",
  ["where"] = "where",
  ["link"] = "link",
  ["import"] = "import",
  ["as"] = "as",
  ["extern"] = "extern",
  ["loop"] = "loop",
  ["true"] = "true",
  ["false"] = "false",
  ["not"] = "not",
  ["mut"] = "mut",
  ["struct"] = "struct",
  ["interface"] = "interface",
}

function Lexer:nextToken()
  if self.idx == #self.content then
    return Token("eof", "", self.source)
  end

  self:skipWhitespace()

  if self.idx == #self.content then
    return Token("eof", "", self.source)
  end

  local ch = self.ch

  if self:isAlphabetic(ch) or ch == "_" then
    local str = ch
    self:skipChar()
    while self:isLiteralChar(self:peekChar()) do
      str = str .. self:peekChar()
      self:skipChar()
    end
    if self.keywords[str] ~= nil then
      return Token(self.keywords[str], str, self.source)
    end
    return Token("identifier", str, self.source)
  end

  if ch == '"' then
    local str = ''
    self:skipChar()
    while self.ch ~= '"' do
      if self.ch == '\\' then
        str = str .. '\\'
        self:skipChar()
      end
      str = str .. self.ch
      self:skipChar()
    end
    self:skipChar()
    return Token("string-literal", str, self.source)
  end

  if ch == "'" then
    local str = ''
    self:skipChar()
    while self.ch ~= "'" do
      if self.ch == '\\' then
        str = str .. '\\'
        self:skipChar()
      end
      str = str .. self.ch
      self:skipChar()
    end
    self:skipChar()
    return Token("string-literal", str, self.source)
  end

  if self:followedBy("$") then
    self:skipChar()
    return Token("$", "", self.source)
  end

  if self:followedBy("&&") then
    self:skipChar()
    self:skipChar()
    return Token("&&", "", self.source)
  end

  if self:followedBy(">>") then
    self:skipChar()
    self:skipChar()
    return Token(">>", "", self.source)
  end

  if self:followedBy("<<") then
    self:skipChar()
    self:skipChar()
    return Token("<<", "", self.source)
  end

  if self:followedBy("+") then
    self:skipChar()
    return Token("+", "", self.source)
  end

  if self:followedBy("->") then
    self:skipChar()
    self:skipChar()
    return Token("->", "", self.source)
  end

  if self:followedBy("-") then
    self:skipChar()
    return Token("-", "", self.source)
  end

  if self:followedBy("*") then
    self:skipChar()
    return Token("*", "", self.source)
  end

  if self:followedBy("/") then
    self:skipChar()
    return Token("/", "", self.source)
  end

  if self:followedBy("..") then
    self:skipChar()
    self:skipChar()
    return Token("..", "", self.source)
  end

  if self:followedBy(".") then
    self:skipChar()
    return Token(".", "", self.source)
  end

  if self:followedBy(":") then
    self:skipChar()
    return Token(":", "", self.source)
  end

  if self:followedBy("^") then
    self:skipChar()
    return Token("^", "", self.source)
  end

  if self:followedBy("#") then
    self:skipChar()
    return Token("#", "", self.source)
  end

  if self:followedBy("==") then
    self:skipChar()
    self:skipChar()
    return Token("==", "", self.source)
  end

  if self:followedBy("~=") then
    self:skipChar()
    self:skipChar()
    return Token("~=", "", self.source)
  end

  if self:followedBy(">=") then
    self:skipChar()
    self:skipChar()
    return Token(">=", "", self.source)
  end

  if self:followedBy("<=") then
    self:skipChar()
    self:skipChar()
    return Token("<=", "", self.source)
  end

  if self:followedBy(">") then
    self:skipChar()
    return Token(">", "", self.source)
  end

  if self:followedBy("<") then
    self:skipChar()
    return Token("<", "", self.source)
  end

  if self:followedBy("(") then
    self:skipChar()
    return Token("(", "", self.source)
  end

  if self:followedBy(")") then
    self:skipChar()
    return Token(")", "", self.source)
  end

  if self:followedBy("[") then
    self:skipChar()
    return Token("[", "", self.source)
  end

  if self:followedBy("]") then
    self:skipChar()
    return Token("]", "", self.source)
  end

  if self:followedBy("=") then
    self:skipChar()
    return Token("=", "", self.source)
  end

  if self:followedBy("{") then
    self:skipChar()
    return Token("{", "", self.source)
  end

  if self:followedBy("}") then
    self:skipChar()
    return Token("}", "", self.source)
  end

  if self:followedBy("~") then
    self:skipChar()
    return Token("~", "", self.source)
  end

  if self:followedBy(",") then
    self:skipChar()
    return Token(",", "", self.source)
  end

  if self:followedBy(";") then
    self:skipChar()
    return Token(";", "", self.source)
  end

  self:skipChar()
  return Token("illegal", ch, self.source)
end

function Lexer:printTokens()
  ---@type Token[]
  local tokens = {}

  while true do
    local token = self:nextToken()

    if token.type == "eof" then
      break
    end

    table.insert(tokens, token)
  end

  local function ensureLength(str, len)
    while #str < len do
      str = str .. ' '
    end
    return str
  end

  local typeRowLength = 0

  for _, token in ipairs(tokens) do
    typeRowLength = math.max(typeRowLength, #token.type)
  end

  for _, token in ipairs(tokens) do
    print(ensureLength(token.type, typeRowLength), token.content)
  end
end
