setTickRate(100) --100Hz
tick = 0
tick_time = getTickCount()
start_time = tick_time
last_calc_time = -1.0
rem_debug = false
current_ipw_ms = 0.0

total_fuel_consumed_liters = 0.0


function rem_log(...)
    local log_str = string.format("[REM] (%2.4f): ", tick_time)
    for i,v in ipairs(arg) do
        log_str = log_str .. tostring(v) .. " "
    end
    log_str = log_str .. "\n"
    print(log_str)
end

---@param current_time_ms number
function get_fuel_use(current_time_ms, current_ipw_ms)
    local ECU_REQUEST_ID = 0x7E0
    local ECU_RESPONSE_ID = 0x7E8
    local IPW_REQUEST_DATA = { 0x05, 0x23, 0x80, 0xA7, 0x0A, 0x02, 0x00, 0x00 }
    local IPW_SCALING = 0.001
    local IDC_CALC_CONSTANT = 0.00083333333
    local INJECTOR_SIZE_CC_PER_MIN = 305
    local NUMBER_OF_INJECTORS = 4

    if (last_calc_time < 0) then
        last_calc_time = current_time_ms
    end

    t_delta = current_time_ms - last_calc_time

    if t_delta >= 0.05 then
        local current_rpm_from_obd = getChannel("RPM") or 0

        if current_ipw_ms > 0.001 and current_rpm_from_obd > 50 then
            local current_idc = current_ipw_ms * current_rpm_from_obd * IDC_CALC_CONSTANT
            setChannel(REM_IPW_C, current_idc)

            local fuel_flow_cc_per_min = INJECTOR_SIZE_CC_PER_MIN * (current_idc / 100) * NUMBER_OF_INJECTORS
            local current_fuel_flow_lph = (fuel_flow_cc_per_min / 1000) * 60
            setChannel(REM_Fuel_L_C, current_fuel_flow_lph)

            local fuel_burned_this_delta = (current_fuel_flow_lph / 3600) * t_delta * 0.001
            total_fuel_consumed_liters = total_fuel_consumed_liters + fuel_burned_this_delta
            setChannel(REM_Fuel_T_C, total_fuel_consumed_liters)
            if rem_debug then rem_log("IDC       ", current_idc) end
            if rem_debug then rem_log("Fuel_LPH  ", current_fuel_flow_lph) end
            if rem_debug then rem_log("Fuel_Total", total_fuel_consumed_liters) end
        else
            setChannel(REM_Fuel_L_C, 0)
            setChannel(REM_Fuel_L_C, 0)
            if rem_debug then rem_log("IDC     ", 0) end
            if rem_debug then rem_log("Fuel_LPH", 0) end
        end


        last_calc_time = current_time_ms
    end
end

can_channel = 0
can_ext = 0
awaiting_fuel_reply = false
ecu_id = 0x7E0
our_id = 0x7E8
fuel_reply_time = 0

IPW_addr      = {0x80, 0xA7, 0x0A}
THROTTLE_addr = {0x80, 0xA9, 0x36}

function send_fuel_can_message()
    --  7E0#052380A70A020000
    -- local data = {0x05, 0x23, 0x80, 0xA7, 0x0A, 0x02, 0x00, 0x00}
    local data = {0x05, 0x23, 0x80, 0xA7, 0x0A, 0x02, 0x00, 0x00}
    local res = txCAN(can_channel, ecu_id, can_ext, data)
    if rem_debug then rem_log("Sent") end
    if rem_debug and res == 0 then rem_log("Failed to send CAN") end
    awaiting_fuel_reply = res == 1
    return res
end

---@param timeout_ms number
function check_for_fuel_message(timeout_ms)
    local id, ext, data = rxCAN(can_channel, timeout_ms) --100ms timeout
    if rem_debug and id ~= nil then
        print("CAN rx: " ..id .." ")
        for i,v in next,data do
            print(string.format("%x ", v))
        end
        print("\n")
    end
    if id == our_id then
        fuel_reply_time = getTickCount()
        awaiting_fuel_reply = false
        local x = data[3]*0x100 + data[4]
        local actual = x * 0.001
        if rem_debug then
            local hex_str = ""
            -- for i,v in ipairs(data) do
            --     hex_str = hex_str .. string.format("0x%X ", v)
            -- end
            -- rem_log("Received fuel response:", hex_str)

            if rem_debug then print(string.format("RAW    %d\n", x)) end
            if rem_debug then print(string.format("ACTUAL %fms\n", actual)) end
        end
        return actual
    else
        return nil
    end
end



function init()
    rem_log("Init CAN...")
    local success = initCAN(can_channel, 500000)
    rem_log("Init CAN Done: ", success)
    REM_IPW_C    = addChannel("REM_IPW", 10, 32, false)
    REM_IDC_C    = addChannel("REM_IDC", 10, 32, false)
    REM_Fuel_L_C = addChannel("REM_Fuel_L", 10, 32, false)
    REM_Fuel_T_C = addChannel("REM_Fuel_T", 10, 32, false)
    rem_log("addChannel(REM_IPW) =",    REM_IPW_C)
    rem_log("addChannel(REM_IDC) =",    REM_IDC_C)
    rem_log("addChannel(REM_Fuel_L) =", REM_Fuel_L_C)
    rem_log("addChannel(REM_Fuel_T) =", REM_Fuel_T_C)
    rem_log("Channels setup")
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
        local current_ipw_ms = check_for_fuel_message(5)
        get_fuel_use(getTickCount(), current_ipw_ms)
    end

    if tick % 20 == 0 then --5Hz
        -- get_fuel_use(tick_time)

    end

    tick = tick + 1
    if tick > 99 then tick = 0 end
end

init()