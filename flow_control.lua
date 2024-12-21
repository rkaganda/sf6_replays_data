local paths = require("paths")

local last_error_msg = ""
local ui_interact_log = {}
local fresh_start = true
local cfn_replay_id = ""

-- FLOW STUFF
local b_flow_mgr
local m_flow
local work

-- DELETE
local function tableToString(t)
    local str = "{ "
    for i, v in ipairs(t) do
        str = str .. '"' .. v .. '"'
        if i < #t then
            str = str .. ", "
        end
    end
    return str .. " }"
end

-- generates table from enum
local function generate_enum(typename)
    local t = sdk.find_type_definition(typename)
    if not t then return {} end

    local fields = t:get_fields()
    local enum = {}

    for i, field in ipairs(fields) do
        if field:is_static() then
            local name = field:get_name()
            local raw_value = field:get_data(nil)
            enum[raw_value] = name
        end
    end

    return enum
end

local function print_fields(object)
    local fields = object:get_type_definition():get_fields()
    print("object:get_type_definition()="..object:get_type_definition():get_full_name())

    for i, field in ipairs(fields) do
        print(field:get_name())
    end
end


-- checks if table contains
local function contains(table, val)
    for _, v in ipairs(table) do
        if v == val then
            return true
        end
    end
    return false
end


-- REPLAY STUFF
local gBattle
local replay_state = ""

local function get_cfn_replay_id()
    battleReplayDataManager = sdk.get_managed_singleton("app.BattleReplayDataManager")
    if battleReplayDataManager._ReplayList then
        _replayList = battleReplayDataManager._ReplayList
        _replayListItems = battleReplayDataManager._ReplayList._items
        if _replayListItems then
            _replayData = _replayListItems[0]

            if _replayData.ReplayID then
                cfn_replay_id = _replayData.ReplayID
            else 
                cfn_replay_id = ""
            end
        end
    end
end

local function get_replay_state()
    if gBattle then
        local sGame = gBattle:get_field("Game"):get_data(nil) -- get game timer
        if sGame.fight_st ~=0 then
            if sGame.fight_st == 7 then
                replay_state = "finished"
            else
                replay_state = "running"
            end
        end
    else
        replay_state = "none"
    end
end

-- INPUT AUTOMANTION
local keyboardKeys = generate_enum("via.hid.KeyboardKey")
local inputDigitalFlags = generate_enum("app.InputDigitalFlag")


local key_status = {}
local last_key_status = {}
local flagTriggerValue = 11
local updateFrameCount 
local current_action_key_frame = 0
local current_action_sequence = {}
local action_key_frame_max = 120
local currently_transitioning = false
local unreachable_target = false
local wait_delay = 30
--local all_keys = {"Q","D","F","Tab","E"}
local current_action_key = ""
local all_keys = {}
for _, value in pairs(keyboardKeys) do
    table.insert(all_keys, value)
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

-- UI FLOW STATES
local requestTypes = generate_enum("app.UITextInputDialog.RequestType")
local state_flows = json.load_file("flow_map.json")

local current_ui_state_name
local last_ui_state_name
local target_ui_state_name
local last_target_ui_state_name

local current_top_flow_name
local last_top_flow_name

local last_flows_table = {}
local current_flows_table = {}


-- SEARCH TEXT
local search_text


-- Get flow by name
local function get_flow_by_name(flow_name, flow_items)
    for f_key = 0, #flow_items - 1 do  -- interate over flows starting from 0
        if flow_items[f_key] == nil then
            return
        end
        local f_value = flow_items[f_key] -- possible flow
        if f_value then -- if the flow isn't nil
            -- get the fiend name for the flow
            local field_name = f_value:get_field("<Param>k__BackingField"):get_type_definition():get_full_name()
            current_flows_table[f_key] = field_name -- get the flow name from current flows table
            if field_name == flow_name then -- if the flow name matches the flow we are looking for
                return f_value:get_field("<Param>k__BackingField") -- return the matching flow
            end
        end
    end
end

-- Get flow by name
local function get_flow_element_by_name(flow_name, flow_items)
    for f_key = 0, #flow_items - 1 do  -- interate over flows starting from 0
        if flow_items[f_key] == nil then
            return
        end
        local f_value = flow_items[f_key] -- possible flow
        if f_value then -- if the flow isn't nil
            -- get the fiend name for the flow
            local field_name = f_value:get_field("<Param>k__BackingField"):get_type_definition():get_full_name()
            current_flows_table[f_key] = field_name -- get the flow name from current flows table
            if field_name == flow_name then -- if the flow name matches the flow we are looking for
                return f_value:get_field("<Element>k__BackingField") -- return the matching flow
            end
        end
    end
end


-- current state is "unknown", search for DialogWidget to identify the flow
local function identify_dialog_flow(uiFlowHandlesItems)
    -- named object for replay search flows
    wanted_flow = "app.UICFNReplayTopTabSearchChildSearchId.FlowParam"  
    the_flow = get_flow_by_name(wanted_flow, uiFlowHandlesItems)  -- get the search flow if it exists
    if the_flow ~= nil then -- if the search flow exists
        text_field = the_flow:get_field("<TextInputDialogWidget>k__BackingField") -- get the text field widget
        if text_field~= nil then
            field_type = text_field:get_field("CurrentRequestType") -- get the type of the text field widget
            return requestTypes[field_type]
        end 
    end
end

local function invoke_search()
    wanted_flow = "app.UICFNReplayTopTabSearchChildSearchId.FlowParam"
    the_flow = get_flow_by_name(wanted_flow, uiFlowHandlesItems)
    if the_flow ~= nil and search_text ~= nil then
        --the_flow:set_SearchReplayId("SVNBWNVYH")
        text_field = the_flow:get_field("<TextInputDialogWidget>k__BackingField")
        if text_field ~= nil and search_text ~= "" then
            text_field:InvokeResultEvent(search_text)
        end
    end
end

local function safe_chain_get(obj, ...)
    local current = obj
    for _, field_name in ipairs({...}) do
        if current == nil or current.get_field == nil then
            return nil
        end
        current = current:get_field(field_name)
    end
    return current
end

local function get_replay_result_info()
    local flow_name = "app.UICFNReplayInfoOnline.FlowParam"
    local result_flow = get_flow_element_by_name(flow_name, uiFlowHandlesItems)
    if result_flow ~= nil then
        print("flow_name="..flow_name)
        --the_flow:set_SearchReplayId("SVNBWNVYH")
        --local field = result_flow:get_field("<Param>k__BackingField")
        local replay_id = safe_chain_get(
            result_flow._Curt,
            "_Param",
            "_SharingData",
            "replay_id"
        )
        cfn_replay_id = replay_id
    end  
end


local function update_current_ui_state_name()
    uIFlowManager = sdk.get_managed_singleton("app.UIFlowManager")
    uiFlowHandles = uIFlowManager._Handles
    uiFlowHandlesItems = uiFlowHandles._items
    uiFlowHandlesItemsFirst = uiFlowHandlesItems[0]
    itemBackingField = uiFlowHandlesItemsFirst:get_field("<Param>k__BackingField")
    
    current_top_flow_name = itemBackingField:get_type_definition():get_full_name()
    if last_top_flow_name ~= current_top_flow_name then
        print(current_top_flow_name)
        print("-----------")
    end
    last_top_flow_name = current_top_flow_name


    -- FLOW -> STATE
    local flow_exists = false -- Local flow is in state_flows

    for ui_state_name, ui_state in pairs(state_flows) do -- For each ui_state
        if contains(ui_state.flows, current_top_flow_name) then -- If the current flow is in state_flows
            current_ui_state_name = ui_state_name -- Assign current ui_state 
            flow_exists = true -- There exists a flow for this ui state
        end
        if not flow_exists then -- If there is no ui_state for this flow
            current_ui_state_name = "unknown" -- ui_state is unknown
            request_type = identify_dialog_flow(uiFlowHandlesItems)
            if request_type ~= nil then
                current_ui_state_name = request_type
            end
        end
    end
    
    if current_ui_state_name == "unknown" then
        if map:get_type_definition():get_full_name() == "app.battle.ReplayFlowMap"  then
            current_ui_state_name = "ReplayPlaying"
        end
    end
end


local function do_transition_step()
    for _, value in pairs(all_keys) do
        last_key_status[value] = key_status[value]
        -- removed string find
        if current_action_key == value then
            key_status[value] = 1
            break
        else
            key_status[value] = nil
        end
    end
end


local function update_state_action_transition()
    if current_action_key_frame-wait_delay > 0 then
        print("-------")
        print("current_top_flow_name="..tostring(current_top_flow_name))
        print("current_ui_state_name="..tostring(current_ui_state_name))
        print("update_state_action_transition")
        print("currently_transitioning="..tostring(currently_transitioning))
        if target_ui_state_name ~= nil then
            print("current="..current_ui_state_name.." target="..target_ui_state_name)
        end
        print("current_action_key_frame="..current_action_key_frame-wait_delay)
        print("sequence="..tableToString(current_action_sequence))
    end
    -- print("current_ui_state_name="..current_ui_state_name)
    -- print("last_ui_state_name="..last_ui_state_name)
    -- STATE TRANSITION

    if state_flows[current_ui_state_name] == nil then
        if current_ui_state_name then
            print("current_ui_state_name="..current_ui_state_name)
        end        
        print("unknown state")
        return
    end

    -- default is no action key for this step
    current_action_key = ""
    current_action_sequence = {}

    if replay_state == "finished" then
        m_flow:set_field("_NextFlowMap", 10) -- replay
        work:set_field("IsTransitioning", false)
        replay_state = ""
    end

    -- if target_state 
    if target_ui_state_name and not unreachable_target then
        -- if target state is unreachable
        print("current_ui_state_name="..current_ui_state_name)
        if state_flows[current_ui_state_name]["transitions"][target_ui_state_name] == nil then
            print("cant reach state")
            unreachable_target = true
            currently_transitioning = false
            do_transition_step()
            return
        -- if the we have reached the target
        elseif target_ui_state_name == current_ui_state_name then
            if currently_transitioning then
                print("target reached current="..current_ui_state_name.." target="..target_ui_state_name)
            end
            currently_transitioning = false
        -- if there target not reached and we are not transitioning
        elseif target_ui_state_name ~= current_ui_state_name and not currently_transitioning then
            -- if there is a flow for this state
            if state_flows[current_ui_state_name] ~= nil then
                print("new target="..target_ui_state_name)
                current_action_key_frame = 0
                currently_transitioning = true
            end
        end
        current_action_sequence = state_flows[current_ui_state_name]["transitions"][target_ui_state_name]
        
        -- ACTION SEQUENCE TO NEXT STATE
        if current_action_sequence[current_action_key_frame-wait_delay] and currently_transitioning then
            current_action_key = current_action_sequence[current_action_key_frame-wait_delay]
        -- if sequence is finished
        elseif current_action_key_frame-wait_delay > #current_action_sequence+1 then
            currently_transitioning = false
        elseif not currently_transitioning then
        end
    end
    do_transition_step()

    

    if last_ui_state_name ~= current_ui_state_name then
        print("current_ui_state_name="..current_ui_state_name)
    else
        current_action_key_frame = current_action_key_frame < action_key_frame_max and (current_action_key_frame + 1) or 0
    end
    last_ui_state_name = current_ui_state_name
end

local function write_state_to_file()
    json.dump_file(paths.out_state_path, {
        current_ui_state_name = current_ui_state_name,
        current_top_flow_name = current_top_flow_name,
        current_action_key_frame = current_action_key_frame,
        currently_transitioning = currently_transitioning,
        unreachable_target = unreachable_target,
        cfn_replay_id = cfn_replay_id
    })
end

local function get_target_state()
    local sf6_state_status_in = json.load_file(paths.in_state_path)
    if sf6_state_status_in then 
        if sf6_state_status_in['target_ui_state_name'] ~= nil then
            target_ui_state_name = sf6_state_status_in['target_ui_state_name']
            -- if this is a new target
            if target_ui_state_name ~= last_target_ui_state_name then
                print("new target state="..target_ui_state_name)
                unreachable_target = false
            end
        else
            target_ui_state_name = nil
        end
        if sf6_state_status_in['search_text'] ~= nil then
            search_text = sf6_state_status_in['search_text']
        else
            search_text = nil
        end
        last_target_ui_state_name = target_ui_state_name
    end
end


re.on_script_reset(function()
end)


re.on_draw_ui(function()
end)

last_flow_names = {}

re.on_frame(function()
    -- init flows
    b_flow_mgr = sdk.get_managed_singleton("app.bFlowManager")
	
	if not b_flow_mgr then return end
	
	if not pcall(function()
		flows = b_flow_mgr:get_field("m_flows")
		work = b_flow_mgr:get_field("m_flow_work")
		m_flow = flows[0]
		save_mgr = sdk.get_managed_singleton("app.SystemSaveManager")
		if flows then
			custom_flow = flows[1]
			map = custom_flow and custom_flow:get_field("_Map")
			map = map or b_flow_mgr:call("get_Map")
		end
        print("flow_map="..map:get_type_definition():get_full_name())
		--b_flow = main and getC(main, "app.battle.bBattleFlow")
	end) or not m_flow then return end

    updateActionKeys()
    gBattle = sdk.find_type_definition("gBattle")
    if gBattle then
        local sGame = gBattle:get_field("Game"):get_data(nil) 
        if sGame then
            if sGame.fight_st == 0 or sGame.fight_st == 7 then
                update_state_action_transition()
                update_current_ui_state_name()
                invoke_search()
                print("writing")
                write_state_to_file()
                get_target_state()
                get_replay_result_info()
                get_replay_state()
            else
                -- clear target and sequence
                target_ui_state_name = ""
                current_action_sequence = {}
                -- do replay stuff
                get_replay_state()
            end
           
        end
    end
end)

--- KEYBOARD HOOKS

local function on_pre_get_digital(args)
    local last_invalid_frame = sdk.to_int64(args[4])
    last_digital_key = keyboardKeys[sdk.to_int64(args[3])]
end
local function on_post_get_digital(retval)
    if retval then
        local retval_address = sdk.to_int64(retval)
        if retval_address ~= 0 then
            --log.debug("************")
            --log.debug("retval="..sdk.to_managed_object(retval):get_type_definition():get_full_name())
            local key = sdk.to_managed_object(retval)
            --log.debug(keyboardKeys[key.Value])
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
            --log.debug("************")
            return sdk.to_ptr(key)
        end
    end
    return retval
end
sdk.hook(sdk.find_type_definition("app.InputDeviceStateKeyboard"):get_method("GetDigital"), on_pre_get_digital, on_post_get_digital)


local function on_pre_update(args)
    -- log.debug("update caller="..sdk.to_managed_object(args[2]):get_type_definition():get_full_name())
    -- log.debug("frame Count="..sdk.to_int64(args[4]))
    updateFrameCount = sdk.to_int64(args[4])
end
local function on_post_update(retval)
    
end
sdk.hook(sdk.find_type_definition("app.InputState"):get_method("Update"), on_pre_update, on_post_update)