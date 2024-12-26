local util_functions = {}

function util_functions.generate_enum(typename)
    local t = sdk.find_type_definition(typename)
    if not t then return {} end

    local fields = t:get_fields()
    local enum = {}

    for i, field in ipairs(fields) do
        if field:is_static() then
            local name = field:get_name()
            local raw_value = field:get_data(nil)

            --log.debug(name .. " = " .. tostring(raw_value))

            enum[raw_value] = name
        end
    end

    return enum
end

function util_functions.bitand(a, b)
    local result = 0
    local bitval = 1
    while a > 0 and b > 0 do
      if a % 2 == 1 and b % 2 == 1 then -- test the rightmost bits
          result = result + bitval      -- set the current bit
      end
      bitval = bitval * 2 -- shift left
      a = math.floor(a/2) -- shift right
      b = math.floor(b/2)
    end
    return result
end

local abs = function(num)
	if num < 0 then
		return num * -1
	else
		return num
	end
end

function util_functions.convertToTable(byteArray)
    local luaTable = {}
    for i = 0, byteArray.Length - 1 do
        table.insert(luaTable, byteArray[i])
    end
    return luaTable
end

function util_functions.read_sfix(sfix_obj)
    if sfix_obj.w then
        return Vector4f.new(tonumber(sfix_obj.x:call("ToString()")), tonumber(sfix_obj.y:call("ToString()")), tonumber(sfix_obj.z:call("ToString()")), tonumber(sfix_obj.w:call("ToString()")))
    elseif sfix_obj.z then
        return Vector3f.new(tonumber(sfix_obj.x:call("ToString()")), tonumber(sfix_obj.y:call("ToString()")), tonumber(sfix_obj.z:call("ToString()")))
    elseif sfix_obj.y then
        return Vector2f.new(tonumber(sfix_obj.x:call("ToString()")), tonumber(sfix_obj.y:call("ToString()")))
    end
    return tonumber(sfix_obj:call("ToString()"))
end

function util_functions.lua_get_dict(dict, as_array, sort_fn)
	local output = {}
	if not dict._entries then return output end
	if as_array then 
		for i, value_obj in pairs(dict._entries) do
			output[i] = value_obj.value
		end
		if sort_fn then
			table.sort(output, sort_fn)
		end
	else
		for i, value_obj in pairs(dict._entries) do
			if value_obj.value ~= nil then
				output[value_obj.key] = output[value_obj.key] or value_obj.value
			end
		end
	end
	return output
end


function util_functions.get_enum(typename)
    local enums = {}
	if enums[typename] then return enums[typename] end
	local enum, names, reverse_enum = {}, {}, {}
	for i, field in ipairs(sdk.find_type_definition(typename):get_fields()) do
		if field:is_static() and field:get_data() ~= nil then
			enum[field:get_name()] = field:get_data() 
			reverse_enum[field:get_data()] = field:get_name()
			table.insert(names, field:get_name())
		end
	end
	enums[typename] = {enum=enum, names=names, reverse_enum=reverse_enum}
	return enums[typename]
end

return util_functions