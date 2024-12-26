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
    local gCommand = gBattle:get_field("Command"):get_data()
    local cached_names = {}

    local act_id_enum = util_functions.get_enum("nBattle.ACT_ID")

    local character_index = gPlayer.mPlayerType[player_index - 1].mValue
    local player_name = characters[character_index] or "Unknown"
    local person = gResource.Data[player_index - 1]

    local mot_info = sdk.create_instance("via.motion.MotionInfo"):add_ref()

    if not person then
        print("Error: Person data not found for player index", player_index)
        return
    end

    local motion = gBattle:get_field("PBManager"):get_data().Players[player_index - 1].mpMot
    if not motion then
        print("Error: Motion data not found for player index", player_index)
        return
    end

    local tgroups = {}
    local tgroups_dict = gCommand.mpBCMResource[player_index - 1].pTrgGrp

    local function collect_fab_action(fab_action)
        if not fab_action then
            print("Warning: Null fab_action encountered")
            return nil
        end

        local act_id = fab_action.ActionID
        local name = act_id_enum.reverse_enum[act_id] or "_" .. string.format("%03d", act_id)
        local move = { fab = fab_action, id = act_id, name = name }

        if motion then
            -- local mot_info = {}
            local success, mot_name = pcall(function()
                motion:call("getMotionInfo(System.UInt32, System.UInt32, via.motion.MotionInfo)", fab_action.MotionType, fab_action.MotionID, mot_info)
                return mot_info.get_MotionName and mot_info:get_MotionName() or nil
            end)

            if success and mot_name then
                move.mot_name = mot_name
                mot_name = mot_name:gsub("esf%d%d%d_", "")
                name = util_functions.get_unique_name(mot_name, cached_names)
                move.name = name
            end
        end

        for _, keys_list in pairs(util_functions.lua_get_array(fab_action.Keys)) do
            if keys_list and keys_list._items[0] then
                local keytype_name = keys_list._items[0]:get_type_definition():get_name()
                for _, key in pairs(util_functions.lua_get_array(keys_list, true)) do
                    move[keytype_name] = move[keytype_name] or {}
                    move[keytype_name][#move[keytype_name] + 1] = key

                    if keytype_name == "MotionKey" or keytype_name == "ExtMotionKey" or keytype_name == "FacialAutoKey" or keytype_name == "FacialKey" then
                        local specific_motion = (keytype_name:find("Facial") and motion) or motion
                        -- local mot_info = {}
                        local success, mot_name = pcall(function()
                            specific_motion:call("getMotionInfo(System.UInt32, System.UInt32, via.motion.MotionInfo)", key.MotionType, key.MotionID, mot_info)
                            return mot_info.get_MotionName and mot_info:get_MotionName() or nil
                        end)

                        if success and mot_name then
                            move.mot_name = mot_name
                            mot_name = mot_name:gsub("esf%d%d%d_", "")
                            name = util_functions.get_unique_name(mot_name, cached_names)
                            move.name = name
                        end
                    end
                end
            end
        end

        return move
    end

    local function collect_additional_data(moves_dict)
        if not tgroups_dict then
            print("Warning: tgroups_dict is nil")
            return
        end

        for id, triggergroup in pairs(util_functions.lua_get_dict(tgroups_dict)) do
            local bitarray = triggergroup.Flag:BitArray()
            while not bitarray.get_elements do bitarray = triggergroup.Flag:BitArray() end
        end

        for id, move_obj in pairs(moves_dict.By_ID) do
            for j, act_id in pairs(move_obj.projectiles or {}) do
                local action_obj = moves_dict.By_ID[act_id]
                move_obj.projectiles[j] = action_obj or "NOT_FOUND: " .. act_id
                if action_obj and not action_obj.mot_name then
                    moves_dict.By_Name[action_obj.name] = nil
                    action_obj.name = util_functions.get_unique_name(move_obj.name .. " PROJ", moves_dict.By_Name)
                    moves_dict.By_Name[action_obj.name] = action_obj
                end
            end

            if move_obj.branches and type(move_obj.branches[1]) == "number" then
                for j, act_id in pairs(move_obj.branches) do
                    move_obj.branches[j] = moves_dict.By_ID[act_id] or "NOT_FOUND: " .. act_id
                end
            end

            if move_obj.name:find("A_") == 3 then
                move_obj.guest = moves_dict.By_Name[move_obj.name:gsub("A_", "D_")]
            end

            if move_obj.name:find("D_") == 3 then
                move_obj.owner = moves_dict.By_Name[move_obj.name:gsub("D_", "A_")]
            end
        end
    end

    local function collect_moves_dict()
        local moves_dict = { By_Name = {}, By_ID = {}, By_Index = {} }

        for i = 0, person.FAB.StyleDict:call("get_Count()") - 1 do
            local act_list = util_functions.lua_get_dict(person.FAB.StyleDict[i].ActionList, true, function(a, b) return a.ActionID < b.ActionID end)
            for j = 0, #act_list do
                if act_list[j] then
                    local move = collect_fab_action(act_list[j])
                    if move then
                        moves_dict.By_Name[move.name] = move
                    else
                        print("Warning: Skipped null move in act_list")
                    end
                end
            end
        end

        --collect_additional_data(moves_dict)

        cached_names = {}
        for name, move in pairs(moves_dict.By_Name) do
            cached_names[string.format("%04d", move.id)] = name
        end

        local success, err = pcall(function()
            json.dump_file("replay_data_enum\\" .. player_name .. "_" .. character_index .. "_mactions.json", cached_names)
        end)

        if not success then
            print("Error: Failed to write JSON file - ", err)
        end
    end

    collect_moves_dict()
end

collect_cached_names(1)
collect_cached_names(2)
