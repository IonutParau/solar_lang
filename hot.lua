#!/usr/bin/env lua
print("Warning: Solar is still WIP")

SEP = package.config:sub(1, 1)

require("src.token")
require("src.ast")
require("src.lexer")
require("src.parser")
require("src.compiler")
require("src.stylecheck")

Lexer:setState("shit.hot", [[
module Test
module Test.Submodule

fun Test.Submodule.Method(a, b) = -a + b

fun Test.Submodule.Other(arg) do
  loop
    print("Hello, world!" .. arg)
    arg = arg .. "e"
  end
end
]])

Parser:grabTokenStream(Lexer)

local code = Parser:parseCode("")

DumpAST({ type = "program", subnodes = code })

Emitter:takeASTs(code)
print(Emitter:compile())
