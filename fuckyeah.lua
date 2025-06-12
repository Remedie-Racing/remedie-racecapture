setTickRate(100)

can_channel = 0
can_ext = 0
ecu_id = 0x7e0
our_id = 0x7e8
awaiting_fuel_reply = false
timeout_ms = 100

IPW_addr = {0x80, 0xA7, 0x0A}
THROTTLE_addr = {0x80, 0xA9, 0x36}


function onTick()
  if not awaiting_fuel_reply then
 print(">")
    --  7E0#052380A70A020000
    -- local data = {0x05, 0x23, 0x80, 0xA7, 0x0A, 0x02, 0x00, 0x00}
    local data = {0x05, 0x23, 0x80, 0xA9, 0x36, 0x02, 0x00, 0x00}
    local success = txCAN(can_channel, ecu_id, can_ext, data)
 if success == 0 then
  return
 end
    awaiting_fuel_reply = true

    print("SENT? " .. tostring(success) .. "\n")
  else
 print(".")
    local id, ext, data = rxCAN(can_channel, 100) --100ms timeout

    if id ~= nil then

      --if id == response_id then
        -- awaiting_fuel_reply = false
        local hex_str = ""
        for i,v in ipairs(data) do
          hex_str = hex_str .. string.format("0x%X ", v)
        end
        print(string.format("\nGOT %4x (%d) %s\n", id, ext, hex_str))
      if id == our_id then
        awaiting_fuel_reply = false
        local x = data[3]*0x100 + data[4]
        print(string.format("X %d\n", x))
        print(string.format("MATHS %f\n", 0.0305157156*(x - 409.6)))
      end
    end
  end
end

local init_success = initCAN(can_channel, 500000)
print("INIT SUdCCESS? " .. tostring(init_success))