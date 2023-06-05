print("Warning: Solar is still WIP")

require("src.token")
require("src.ast")
require("src.lexer")
require("src.parser")

Lexer:setState("shit.solar", [[
module Test;
module Test.Submodule;

fun Test.Submodule.Method(a, b) = a + b;
]])

Parser:grabTokenStream(Lexer)

local code = Parser:parseCode()
for i = 1, #code do
  DumpAST(code[i])
end
