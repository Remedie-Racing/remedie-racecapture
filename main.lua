setTickRate(100) --100Hz
tick = 0
tick_time = getTickCount()
start_time = tick_time
last_calc_time = tick_time
debug = true


function rem_log(...)
    local log_str = "[REM] " .. tostring(tick_time) .. ": "
    for i,v in ipairs(arg) do
        log_str = log_str .. tostring(v) .. " "
    end
    log_str = log_str .. "\n"
    print(log_str)
end

---@param current_time_ms number
local function get_fuel_use(current_time_ms)
    local ECU_REQUEST_ID = 0x7E0
    local ECU_RESPONSE_ID = 0x7E8
    local IPW_REQUEST_DATA = { 0x05, 0x23, 0x80, 0xA7, 0x0A, 0x02, 0x00, 0x00 }
    local IPW_SCALING = 0.001
    local IDC_CALC_CONSTANT = 0.00083333333
    local INJECTOR_SIZE_CC_PER_MIN = 305
    local NUMBER_OF_INJECTORS = 4

    addChannel("IPW", 10, 32, false)
    addChannel("IDC", 10, 32, false)
    addChannel("Fuel_LPH", 10, 32, false)
    addChannel("Fuel_Total", 10, 32, false)

    if (current_time_ms - last_calc_time) >= 0.05 then
        local current_rpm_from_obd = getChannel("RPM") or 0

        if current_ipw_ms > 0.001 and current_rpm_from_obd > 50 then
            local current_idc = current_ipw_ms * current_rpm_from_obd * IDC_CALC_CONSTANT
            setChannel("IDC", current_idc)

            local fuel_flow_cc_per_min = INJECTOR_SIZE_CC_PER_MIN * (current_idc / 100) * NUMBER_OF_INJECTORS
            local current_fuel_flow_lph = (fuel_flow_cc_per_min / 1000) * 60
            setChannel("Fuel_LPH", current_fuel_flow_lph)

            local fuel_burned_this_delta = (current_fuel_flow_lph / 3600) * 0.05
            total_fuel_consumed_liters = total_fuel_consumed_liters + fuel_burned_this_delta
            setChannel("Fuel_Total", total_fuel_consumed_liters)
        else
            setChannel("IDC", 0)
            setChannel("Fuel_LPH", 0)
        end

        last_calc_time = current_time_ms
    end
end

can_channel = 0

awaiting_fuel_reply = false
ecu_id = 0x7E0

function send_fuel_can_message()
    --  7E0#052380A70A020000
    local ext = 0
    local data = {0x05, 0x23, 0x80, 0xA7, 0x0A, 0x02, 0x00, 0x00}
    local res = txCAN(can_channel, ecu_id, ext, data)
    if res == 0 then println("Failed to send CAN") end
    awaiting_fuel_reply = res == 1
    return res
end

---@param timeout_ms number
function check_for_fuel_message(timeout_ms)
    id, ext, data = rxCAN(0, timeout_ms) --100ms timeout
    if debug and id ~= nil then
        print("CAN rx: " ..id .." ")
        for i,v in next,data do
            print(string.format("%x ", v))
        end
        print("\n")
    end
    if id == response_id then
        awaiting_fuel_reply = false
        fuel_reply_time = getTickCount()
        return data
    else
        return nil
    end
end

function init()
    rem_log("Init CAN...")
    local success = initCAN(can_channel, 500000)
    rem_log("Init CAN Done: ", success)
end


function onTick()
    tick_time = getTickCount()
    if tick % 2 == 0 then --50Hz
    end

    if tick % 5 == 0 then --20Hz
        collectgarbage()
    end

    if tick % 10 == 0 then --10Hz
        if not awaiting_fuel_reply then
            send_fuel_can_message()
        end
        -- get_fuel_use(current_time_ms)
    end
    if awaiting_fuel_reply then
        check_for_fuel_message(5)
    end

    if tick % 20 == 0 then --5Hz
    end

    tick = tick + 1
    if tick > 99 then tick = 0 end
end

init()