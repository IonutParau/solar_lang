print("Warning: May require admin priviliges")
print("Also needs LuaRocks to be installed")

local dependencies = {
  "luafilesystem",
}

for _, dependency in ipairs(dependencies) do
  os.execute("luarocks install " .. dependency)
end
