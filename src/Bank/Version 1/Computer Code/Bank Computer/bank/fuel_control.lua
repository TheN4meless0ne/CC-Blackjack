
-- Controller script: Handles fuel requests from turtle by pulsing Redstone via Redrouter's back face

local MODEM_SIDE = "bottom"
local REDROUTER_NAME = "left"  -- Use the real name of your redrouter

if not rednet.isOpen(MODEM_SIDE) then
    rednet.open(MODEM_SIDE)
end

local redrouter = peripheral.wrap(REDROUTER_NAME)
if not redrouter then
    error("Redrouter peripheral not found! Check connection and name.")
end

print("Fuel controller (Redrouter BACK) listening for fuel requests...")

while true do
    local senderID, msg, protocol = rednet.receive()
    if type(msg) == "table" and msg.result == "fuel_request" then
        print(string.format("Fuel requested by turtle %d, fuel level: %d", senderID, msg.level))
        -- Activate redstone output on REDROUTER's back
        redrouter.setOutput("back", true)
        print("Redstone ON (back of Redrouter), waiting 4 seconds...")
        sleep(4)
        redrouter.setOutput("back", false)
        print("Redstone OFF (back of Redrouter).")
    end
end
