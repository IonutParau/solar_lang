#!/usr/bin/env lua
print("Warning: Solar is still WIP")

SEP = package.config:sub(1, 1)

require("src.token")
require("src.ast")
require("src.lexer")
require("src.parser")
require("src.compiler")
require("src.stylecheck")

Lexer:setState("shit.solar", [[
module Test
module Test.Submodule

fun Test.Submodule.Method(a, b) = -a + b

fun Test.Submodule.Other(arg) do
  loop
    print("Hello, world!" .. arg)
    arg = arg .. "e"
    local mut a = "there"
    local mut b = "hello"
    a, b = b, a
    print(a, b)
  end
end
]])

Parser:grabTokenStream(Lexer)

local code = Parser:parseCode("")

DumpAST({ type = "program", subnodes = code })

Emitter:takeASTs(code)
print(Emitter:compile())
