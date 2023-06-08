#!/usr/bin/env lua
print("Warning: Solar is still WIP")

SEP = package.config:sub(1, 1)

require("src.token")
require("src.ast")
require("src.lexer")
require("src.parser")
require("src.compiler")

Lexer:setState("shit.solar", [[
module Test;
module Test.Submodule;

fun Test.Submodule.Method(a, b) = -a + b;

fun Test.Submodule.Other() do
  loop
    print("Hello, world!")
  end
end
]])

Parser:grabTokenStream(Lexer)

local code = Parser:parseCode("")

Emitter:takeASTs(code)
print(Emitter:compile())
