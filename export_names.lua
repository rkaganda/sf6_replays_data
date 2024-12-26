local util_functions = require("util_functions")
local nBattle_ACT_ST_ID = sdk.find_type_definition("nBattle.ACT_ST.ID")

local function dump_enum(enum_name, filename)
    print(enum_name)
    local enum = util_functions.generate_enum(enum_name)

    for value, name in pairs(enum) do
        print(string.format("%s = %d", name, value))
    end

    json.dump_file("replay_data_enum/"..filename..".json", enum)
    print("dumped "..filename)
end

local typename = "nBattle.ACT_ST.ID" 

dump_enum(typename,'act_st')

