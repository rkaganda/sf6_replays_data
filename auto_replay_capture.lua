local sf6_replay_format = require("sf6_replay_format")
local paths = require("paths")
local util_functions = require("util_functions")

local gBattle

local uiDataManager
local _replayList
local gameStateFormat = {}

local key_status = {}
local last_key_status = {}
local flagTriggerValue = 11
local updateFrameCount 
local current_action_key_frame = 0
local action_key_frame_max = 120
local wait_delay = 30

local all_keys = {"S","F"}
local action_key_sequences = {
    replay_done = {"", "S", "", "F",""}, 
    replay_start = {"", "F", ""},
    replay_next = {"", "S", "", "F",""}
}

local p1 = {}
local p2 = {}
p1.absolute_range = 0
p1.relative_range = 0
p2.absolute_range = 0
p2.relative_range = 0

local replay_table = {}
local round_number = 0
local round_timer = 0
local stage_timer = 0
local replay_saved = false
local data_reset = false
local display_capture_info

local filename_changed
local replay_filename = "replay.json"
local capture_status = "waiting for game..."

local replay_state
local last_replay_state
local ui_state
local last_ui_state

local flow_name
local last_flow_name

local keyboardKeys = util_functions.generate_enum("via.hid.KeyboardKey")
local inputDigitalFlags = util_functions.generate_enum("app.InputDigitalFlag")

print(sf6_replay_format.gameStateFormatString)
for value in string.gmatch(sf6_replay_format.gameStateFormatString, "[^,]+") do
    table.insert(gameStateFormat, value)
end

function findMissingKeys(t)
    local minKey, maxKey = math.huge, -math.huge
    minKey = 0

    for k, v in pairs(t) do
        if type(k) ~= "number" then
            return nil, "Non-integer key detected"
        end
        if k > maxKey then maxKey = k end
    end

    local missingKeys = {}

    for i = minKey, maxKey do
        if not t[i] then
            table.insert(missingKeys, i)
        end
    end

    return missingKeys
end


local function writeReplayToFile()
    local player0_name = sf6_replay_format.characterMapping[tostring(replay_table['player_data']['player_0_id'])]
    local player1_name = sf6_replay_format.characterMapping[tostring(replay_table['player_data']['player_1_id'])]
    local replay_filename = tostring(replay_table['replay_id']).."_"..player0_name.."_"..player1_name..".json"

    if not json.load_file(paths['replay_path']..replay_filename) then
        json.dump_file(paths['replay_path'].."recent_replay.json", replay_table)
        json.dump_file(paths['replay_path']..replay_filename, replay_table)
    end
end




local function writeFrameToTable()
    if replay_table[round_number] == nil then
        replay_table[round_number] = {}
    end
    if replay_table[round_number][stage_timer] == nil then
        replay_table[round_number][stage_timer] = {}
    end
    if replay_table[round_number][stage_timer]['round_stats'] == nil then
        replay_table[round_number][stage_timer]['round_stats'] = {}
    end
    
    replay_table[round_number][stage_timer]["round_stats"]["round_timer"] = round_timer
    replay_table[round_number][stage_timer]["p1"] = {}
    replay_table[round_number][stage_timer]["p2"] = {}

    for p_num=1, 2 do           
        for i, gameEnvValue in ipairs(gameStateFormat) do
            if p_num == 1 then
                replay_table[round_number][stage_timer]["p1"][gameEnvValue] = p1[gameEnvValue]
            else
                replay_table[round_number][stage_timer]["p2"][gameEnvValue] = p2[gameEnvValue]
            end
        end
    end
end


local function updateActionKeys()
    inputManager = sdk.get_managed_singleton("app.InputManager")

    inputManagerState = inputManager._State

    if inputManagerState then
        inputDeviceStateKeyboard = inputManagerState._Keyboard
        if inputDeviceStateKeyboard then
            inputDeviceStateKeyboardKeys = inputDeviceStateKeyboard._Keys
            if inputDeviceStateKeyboardKeys then
                for i, key in pairs(inputDeviceStateKeyboardKeys) do
                    if key then
                        local action_key = key_status[keyboardKeys[key.Value]]
                        if action_key then -- if there is action mapping for this key
                            if action_key == 1 then
                                log.debug("keyboardKeys[key.Value]="..keyboardKeys[key.Value])
                                key.Flags = flagTriggerValue -- set the flag to the action status
                                key.TriggerFrame = updateFrameCount
                            end
                        end
                    end
                end
            end
        end
    end
end

re.on_script_reset(function()
end)


re.on_draw_ui(function()
    if imgui.tree_node("Capture Match") then
        changed, display_capture_info = imgui.checkbox("Display Capture Info", display_capture_info)
        imgui.tree_pop()
    end
end)

re.on_frame(function()
    updateActionKeys()
    gBattle = sdk.find_type_definition("gBattle")

    uIFlowManager = sdk.get_managed_singleton("app.UIFlowManager")
    
    uiFlowHandles = uIFlowManager._Handles
    uiFlowHandlesItems = uiFlowHandles._items
    uiFlowHandlesItemsFirst = uiFlowHandlesItems[0]
    itemBackingField = uiFlowHandlesItemsFirst:get_field("<Param>k__BackingField")
    
    flow_name = itemBackingField:get_type_definition():get_full_name()
    if last_flow_name ~= flow_name then
        print(flow_name)
    end
    last_flow_name = flow_name

    replay_playing = {"app.UIEnjoy.FlowParam"}
    replay_list = {"app.UICFNReplayTopTabMyReplay.FlowParam","app.UICFNReplaySearchResult.FlowParam"}
    replay_info = {"app.UICFNReplayInfoOnline.FlowParam"}

    local function contains(table, val)
        for _, v in ipairs(table) do
            if v == val then
                return true
            end
        end
        return false
    end

    if contains(replay_list, flow_name) then
        ui_state = "replay_next"
    elseif contains(replay_info, flow_name) then
        ui_state = "replay_start"
    elseif contains(replay_playing, flow_name) and replay_state == "finished" then
        ui_state = "replay_done"
    else
        ui_state = "other"
    end

    if last_ui_state ~= ui_state then
        print("XXXXXXXXXXXXXXXXX")
        print(ui_state)
        current_action_key_frame = 1
    else
        current_action_key_frame = current_action_key_frame + 1
        if current_action_key_frame > action_key_frame_max+wait_delay then
            current_action_key_frame = 1
        end
    end


    if action_key_sequences[ui_state] and action_key_sequences[ui_state][current_action_key_frame-wait_delay] then
        print("current_action_key_frame="..current_action_key_frame)
        print("ui_state="..ui_state)
        for _, value in pairs(all_keys) do
            last_key_status[value] = key_status[value]
            
            if string.find(action_key_sequences[ui_state][current_action_key_frame-wait_delay], value) then
                key_status[value] = 1
            else
                key_status[value] = nil
            end
        end
    end

    if display_capture_info then
        imgui.begin_window("Match Capture", true, 0)
        imgui.text("Status: "..capture_status)
        imgui.end_window()
    end
    if gBattle then
        local sRound = gBattle:get_field("Round"):get_data(nil) -- get round number
        local sGame = gBattle:get_field("Game"):get_data(nil) -- get game timer
        local fInput = gBattle:get_field("Input"):get_data(nil)
        local bRound = gBattle:get_field("Round"):get_data(nil)

        if sGame.fight_st ~=0 then
            round_number = sRound.RoundNo
            stage_timer = sGame.stage_timer
            round_timer = bRound.play_timer
            local capture_frame = false

            local sPlayer = gBattle:get_field("Player"):get_data(nil)
            local cPlayer = sPlayer.mcPlayer
            local BattleTeam = gBattle:get_field("Team"):get_data(nil)
            local cTeam = BattleTeam.mcTeam
            -- Charge Info
            local storageData = gBattle:get_field("Command"):get_data(nil).StorageData
            local p1ChargeInfo = storageData.UserEngines[0].m_charge_infos
            local p2ChargeInfo = storageData.UserEngines[1].m_charge_infos
            -- Fireball
            local sWork = gBattle:get_field("Work"):get_data(nil)
            local cWork = sWork.Global_work
            -- Action States
            local p1Engine = gBattle:get_field("Rollback"):get_data():GetLatestEngine().ActEngines[0]._Parent._Engine
            local p2Engine = gBattle:get_field("Rollback"):get_data():GetLatestEngine().ActEngines[1]._Parent._Engine

            battleReplayDataManager = sdk.get_managed_singleton("app.BattleReplayDataManager")
        
            -- game done
            if sGame.fight_st == 7 and not replay_saved and data_reset then
                _replayList = battleReplayDataManager._ReplayList

                _replayListItems = battleReplayDataManager._ReplayList._items
                _replayData = _replayListItems[0]

                if _replayData.ReplayID then
                    replay_table['replay_id'] = _replayData.ReplayID
                end
                if _replayData.ReplayInfo.uploaded_at then
                    replay_table['uploaded_at'] = _replayData.ReplayInfo.uploaded_at
                end
                if _replayData.ReplayInfo.replay_battle_type then
                    replay_table['replay_battle_type'] = _replayData.ReplayInfo.replay_battle_type
                end
                if _replayData.ReplayData then
                    if _replayData.ReplayData.InputData then
                        replay_table['input_data'] = _replayData.ReplayData.InputData
                    end
                    if _replayData.ReplayData.ReplayInfo.RoundInfo then
                        replay_table['round_results'] = {}
                        rounds_info = _replayData.ReplayData.ReplayInfo.RoundInfo
                        for i, round_info in pairs(rounds_info) do
                            replay_table['round_results'][i] = {}
                            log.debug("round="..i)
                            --log.debug("round_info="..round_info)
                            log.debug("WinPlayerType="..round_info.WinPlayerType)
                            log.debug("FinishType="..round_info.FinishType)
                            replay_table['round_results'][i]['win_type'] = round_info.WinPlayerType
                            replay_table['round_results'][i]['finish_type'] = round_info.FinishType
                        end
                    end
                end


                writeReplayToFile()
                replay_saved = true
                replay_table = {}
                replay_table['player_data'] = {}
                capture_frame = false
                capture_status = "game captured."
                replay_state = "finished"
            -- game started
            elseif sGame.fight_st == 2 then
                battleReplayDataManager = sdk.get_managed_singleton("app.BattleReplayDataManager")
                --battleReplayDataManager = battleReplayDataManager:get_type_definition()
                --print(battleReplayDataManager:get_full_name())
                -- for i, field in pairs(battleReplayDataManager:get_fields()) do
                --     print(field:get_name())
                -- end
                replay_table = {}

                _replayList = battleReplayDataManager._ReplayList

                _replayListItems = battleReplayDataManager._ReplayList._items
                _replayData = _replayListItems[0]

                replay_table['player_data'] = {}
                replay_table['player_data']['player_1_cfn'] = _replayData.ReplayInfo.player1_info.player.fighter_id
                replay_table['player_data']['player_2_cfn'] = _replayData.ReplayInfo.player2_info.player.fighter_id
                replay_table['player_data']['player_1_cfn_id'] = _replayData.ReplayInfo.player1_info.player.short_id
                replay_table['player_data']['player_2_cfn_id'] = _replayData.ReplayInfo.player2_info.player.short_id
                
                replay_table['player_data']['player_1_input_type'] = p1InputInfo.CommandType
                replay_table['player_data']['player_2_input_type'] = p2InputInfo.CommandType

                replay_saved = false
                data_reset = true
                capture_status = "waiting for game..."
                capture_frame = false
            elseif sGame.fight_st == 3 then
                _replayList = battleReplayDataManager._ReplayList

                _replayListItems = battleReplayDataManager._ReplayList._items
                _replayData = _replayListItems[0]

                if _replayData.ReplayID then
                    replay_table['replay_id'] = _replayData.ReplayID
                end

                replay_table[round_number] = {}
                replay_saved = false
                data_reset = true
                capture_frame = false
                capture_status = "round reset."
            elseif sGame.fight_st == 4 then
                capture_status = "capturing..."
                capture_frame = true
            end

            if not replay_table['player_data'] then
                replay_table['player_data'] = {}
            end

            if sPlayer.mPlayerType[0].mValue then
                replay_table['player_data']['player_0_id'] = sPlayer.mPlayerType[0].mValue
            end
            if sPlayer.mPlayerType[1].mValue then
                replay_table['player_data']['player_1_id'] = sPlayer.mPlayerType[1].mValue
            end
            p1InputInfo = fInput.StorageData.Info[0]
            p2InputInfo = fInput.StorageData.Info[1]
            
            
            p1.input_data = p1InputInfo._InputNew.u32
            p1.input_side = p1InputInfo.InputSide
            p2.input_data = p2InputInfo._InputNew.u32
            p2.input_side = p2InputInfo.InputSide
            
            
            -- p1.mActionId = cPlayer[0].mActionId
            p1.mActionId = p1Engine:get_ActionID()
            p1.mActionFrame = math.floor(util_functions.read_sfix(p1Engine:get_ActionFrame()))
            p1.mEndFrame = math.floor(util_functions.read_sfix(p1Engine:get_ActionFrameNum()))
            p1.mMarginFrame = math.floor(util_functions.read_sfix(p1Engine:get_MarginFrame()))
            p1.HP_cap = cPlayer[0].vital_old
            p1.current_HP = cPlayer[0].vital_new
            p1.HP_cooldown = cPlayer[0].healing_wait
            p1.dir = util_functions.bitand(cPlayer[0].BitValue, 128) == 128
            p1.dir = p1.dir and 1 or 0 -- bool to int conversion
            p1.hitstop = cPlayer[0].hit_stop
            p1.hitstun = cPlayer[0].damage_time
            p1.blockstun = cPlayer[0].guard_time
            p1.stance = cPlayer[0].pose_st
            p1.throw_invuln = cPlayer[0].catch_muteki
            p1.full_invuln = cPlayer[0].muteki_time
            p1.juggle = cPlayer[0].combo_dm_air
            p1.drive = cPlayer[0].focus_new
            p1.drive_cooldown = cPlayer[0].focus_wait
            p1.super = cTeam[0].mSuperGauge
            p1.buff = cPlayer[0].style_timer
            p1.posX = cPlayer[0].pos.x.v / 6553600.0
            p1.posY = cPlayer[0].pos.y.v / 6553600.0
            p1.spdX = cPlayer[0].speed.x.v / 6553600.0
            p1.spdY = cPlayer[0].speed.y.v / 6553600.0
            p1.aclX = cPlayer[0].alpha.x.v / 6553600.0
            p1.aclY = cPlayer[0].alpha.y.v / 6553600.0
            p1.pushback = cPlayer[0].vector_zuri.speed.v / 6553600.0
            p1.act_st = cPlayer[0].act_st
    
            
            p2.mActionId = cPlayer[1].mActionId
            p2.mActionId = p2Engine:get_ActionID()
            p2.mActionFrame = math.floor(util_functions.read_sfix(p2Engine:get_ActionFrame()))
            p2.mEndFrame = math.floor(util_functions.read_sfix(p2Engine:get_ActionFrameNum()))
            p2.mMarginFrame = math.floor(util_functions.read_sfix(p2Engine:get_MarginFrame()))
            p2.HP_cap = cPlayer[1].vital_old
            p2.current_HP = cPlayer[1].vital_new
            p2.HP_cooldown = cPlayer[1].healing_wait
            p2.dir = util_functions.bitand(cPlayer[1].BitValue, 128) == 128
            p2.dir = p2.dir and 1 or 0 -- bool to int conversion
            p2.hitstop = cPlayer[1].hit_stop
            p2.hitstun = cPlayer[1].damage_time
            p2.blockstun = cPlayer[1].guard_time
            p2.stance = cPlayer[1].pose_st
            p2.throw_invuln = cPlayer[1].catch_muteki
            p2.full_invuln = cPlayer[1].muteki_time
            p2.juggle = cPlayer[1].combo_dm_air
            p2.drive = cPlayer[1].focus_new
            p2.drive_cooldown = cPlayer[1].focus_wait
            p2.super = cTeam[1].mSuperGauge
            p2.buff = cPlayer[1].style_timer
            
            p2.posX = cPlayer[1].pos.x.v / 6553600.0
            p2.posY = cPlayer[1].pos.y.v / 6553600.0
            p2.spdX = cPlayer[1].speed.x.v / 6553600.0
            p2.spdY = cPlayer[1].speed.y.v / 6553600.0
            p2.aclX = cPlayer[1].alpha.x.v / 6553600.0
            p2.aclY = cPlayer[1].alpha.y.v / 6553600.0
            p2.pushback = cPlayer[1].vector_zuri.speed.v / 6553600.0
            p2.act_st = cPlayer[1].act_st

            if round_number and stage_timer and capture_frame then 
                writeFrameToTable()
            end
        end
    end
    last_ui_state = ui_state
end)

-- input hijack
local function on_pre_get_digital(args)
    local last_invalid_frame = sdk.to_int64(args[4])
    last_digital_key = keyboardKeys[sdk.to_int64(args[3])]
end
local function on_post_get_digital(retval)
    if retval then
        local retval_address = sdk.to_int64(retval)
        if retval_address ~= 0 then
            log.debug("************")
            log.debug("retval="..sdk.to_managed_object(retval):get_type_definition():get_full_name())
            local key = sdk.to_managed_object(retval)
            log.debug(keyboardKeys[key.Value])
            local action_key = last_key_status[keyboardKeys[key.Value]]
            for key, value in pairs(last_key_status) do
                log.debug("post digital "..key.." "..value)
            end
            if action_key then -- if there is action mapping for this key
                print("action key!!")
                if action_key == 1 then
                    key.Flags = flagTriggerValue -- set the flag to the action status
                    --key.TriggerFrame = key.MinTriggerFrame + 1
                    -- log.debug("Value="..keyboardKeys[key.Value])
                    -- log.debug("flag="..key.Flags)
                    -- log.debug("TriggerFrame="..key.TriggerFrame)
                end
            end
            return sdk.to_ptr(key)
        end
    end
    return retval
end
sdk.hook(sdk.find_type_definition("app.InputDeviceStateKeyboard"):get_method("GetDigital"), on_pre_get_digital, on_post_get_digital)


local function on_pre_update(args)
    updateFrameCount = sdk.to_int64(args[4])
end
local function on_post_update(retval)
    
end
sdk.hook(sdk.find_type_definition("app.InputState"):get_method("Update"), on_pre_update, on_post_update)