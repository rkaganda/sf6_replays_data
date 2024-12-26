local util_functions = require("util_functions")

local characters = { 
    [1] = "Ryu", 
    [2] = "Luke", 
    [3] = "Kimberly", 
    [4] = "Chun-Li", 
    [5] = "Manon", 
    [6] = "Zangief", 
    [7] = "JP", 
    [8] = "Dhalsim", 
    [9] = "Cammy", 
    [10] = "Ken", 
    [11] = "Dee Jay", 
    [12] = "Lily", 
    [13] = "AKI", 
    [14] = "Rashid", 
    [15] = "Blanka", 
    [16] = "Juri", 
    [17] = "Marisa", 
    [18] = "Guile", 
    [19] = "Ed",
    [20] = "E Honda", 
    [21] = "Jamie", 
    [22] = "Akuma", 
    [26] = "M Bison", 
    [27] = "Terry", 
}

local function collect_cached_names(player_index)
    local gBattle = sdk.find_type_definition("gBattle")
    local gPlayer = gBattle:get_field("Player"):get_data()
    local gResource = gBattle:get_field("Resource"):get_data()
    local cached_names = {}

    local act_id_enum = util_functions.get_enum("nBattle.ACT_ID")
    print(gPlayer)
    print(gPlayer.mPlayerType)
    print(gPlayer.mPlayerType)

    local character_index = gPlayer.mPlayerType[player_index - 1].mValue
    local player_name = characters[character_index]
    local person = gResource.Data[player_index - 1]
    local motion = gBattle:get_field("PBManager"):get_data().Players[player_index - 1].mpMot

    local function collect_fab_action(fab_action)
        local act_id = fab_action.ActionID
        local name = act_id_enum.reverse_enum[act_id] or "_" .. string.format("%03d", act_id)
        local move = { fab = fab_action, id = act_id, name = name }

        if motion then
            local mot_info = {}
            motion:call("getMotionInfo(System.UInt32, System.UInt32, via.motion.MotionInfo)", fab_action.MotionType, fab_action.MotionID, mot_info)
            local try, mot_name = pcall(mot_info.get_MotionName, mot_info)
            if try and mot_name then
                move.mot_name = mot_name
                name = get_unique_name(mot_name, cached_names)
                move.name = name
            end
        end

        return move
    end

    local function collect_moves_dict()
        local moves_dict = { By_Name = {}, By_ID = {}, By_Index = {} }

        for i = 0, person.FAB.StyleDict:call("get_Count()") - 1 do
            local act_list = util_functions.lua_get_dict(person.FAB.StyleDict[i].ActionList, true, function(a, b) return a.ActionID < b.ActionID end)
            for j = 0, #act_list do
                if act_list[j] then
                    local move = collect_fab_action(act_list[j])
                    moves_dict.By_Name[move.name] = move
                end
            end
        end

        cached_names = {}
        for name, move in pairs(moves_dict.By_Name) do
            cached_names[string.format("%04d", move.id)] = name
        end

        json.dump_file("replay_data_enum\\" .. player_name .."_".. character_index .. "_mactions.json", cached_names)
    end

    collect_moves_dict()
end

collect_cached_names(1)
collect_cached_names(2)