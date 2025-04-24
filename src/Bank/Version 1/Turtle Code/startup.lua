
-- Turtle Bank Worker with Vault and Fuel Support and requestId echo

local MODEM_SIDE = "right" -- Change to the side where the modem is attached (left/right) as to not interfere with the turtle's movement
local DIAMOND_ITEM = "minecraft:diamond"
local FUEL_THRESHOLD = 50

rednet.open(MODEM_SIDE)
print("Bank worker turtle listening for rednet commands...")

local function checkFuel(senderID, protocol)
    while turtle.getFuelLevel() < FUEL_THRESHOLD do
        print("Low fuel! Requesting refuel...")
        rednet.send(senderID, {result="fuel_request", level=turtle.getFuelLevel()}, protocol)
        -- Check all slots for potential fuel and try refueling
        for slot = 1, 16 do
            if turtle.getItemCount(slot) > 0 then
                turtle.select(slot)
                if turtle.refuel(0) then
                    local fuelItem = turtle.getItemDetail(slot)
                    if fuelItem and fuelItem.name ~= DIAMOND_ITEM then
                        turtle.refuel(1)
                        print("Used 1 "..fuelItem.name.." to refuel.")
                        break
                    end
                end
            end
        end
        if turtle.getFuelLevel() >= FUEL_THRESHOLD then
            rednet.send(senderID, {result="fueled", level=turtle.getFuelLevel()}, protocol)
            print("Turtle refueled, current fuel:", turtle.getFuelLevel())
            return
        end
        print("Waiting for fuel to be added...")
        os.sleep(5)
    end
end

local function turnRightN(times)
    for i = 1, times do turtle.turnRight() end
end

local function turnAround() turtle.turnRight() turtle.turnRight() end

local function faceChest()
    for i = 1, 4 do
        local ok, typ = pcall(peripheral.getType, "front")
        if ok and typ and typ:find("chest") then return i - 1 end -- If you want to use a barrel instead, change "chest" to "minecraft:barrel"
        end
        turtle.turnRight()
    end
    error("No chest in any direction adjacent to the turtle!")
end

local function faceVault()
    for i = 1, 4 do
        local ok, typ = pcall(peripheral.getType, "front")
        if ok and typ and typ:find("item_vault") then return i - 1 end
        turtle.turnRight()
    end
    error("No item_vault in any direction adjacent to the turtle!")
end

local function tryMove(func)
    if not func() then error("Movement obstructed!") end
end

local function depositToVault(senderID, protocol)
    checkFuel(senderID, protocol)
    local turnsToChest = faceChest()
    local collected = 0
    for i = 1, 1024 do
        if not turtle.suck(1) then break end
        local detail = turtle.getItemDetail()
        if detail and detail.name == DIAMOND_ITEM then
            collected = collected + 1
        end
    end
    tryMove(turtle.down)
    turnAround()
    faceVault()
    local deposited = 0
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and item.name == DIAMOND_ITEM then
            turtle.select(slot)
            deposited = deposited + item.count
            turtle.drop()
        end
    end
    turnAround()
    tryMove(turtle.up)
    turnRightN((4 - faceChest()) % 4)
    return deposited
end

local function withdrawFromVault(senderID, protocol, amount)
    checkFuel(senderID, protocol)
    tryMove(turtle.down)
    turnAround()
    faceVault()
    local withdrawn = 0
    for i = 1, amount do
        if withdrawn >= amount then break end
        if turtle.suck(1) then
            local detail = turtle.getItemDetail()
            if detail and detail.name == DIAMOND_ITEM then withdrawn = withdrawn + 1 end
        else
            break
        end
    end
    turnAround()
    tryMove(turtle.up)
    local turnsToChest = faceChest()
    local delivered = 0
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and item.name == DIAMOND_ITEM then
            turtle.select(slot)
            local toDrop = math.min(item.count, amount - delivered)
            if toDrop > 0 then
                turtle.drop(toDrop)
                delivered = delivered + toDrop
            end
            if delivered >= amount then break end
        end
    end
    turnRightN((4 - turnsToChest) % 4)
    return delivered
end

while true do
    local senderID, msg, protocol = rednet.receive()
    if type(msg) == "table" then
        if msg.hello == "bankTurtle" then
            rednet.send(senderID, {hello="bankTurtle"}, protocol)
        elseif msg.command == "depositDiamonds" then
            local requestId = msg.requestId or 0
            local deposited = depositToVault(senderID, protocol)
            rednet.send(senderID, {
                result = "ok",
                deposited = deposited,
                requestId = requestId
            }, protocol)
        elseif msg.command == "withdrawDiamonds" then
            local amount = msg.amount or 0
            local requestId = msg.requestId or 0
            local withdrawn = withdrawFromVault(senderID, protocol, amount)
            rednet.send(senderID, {
                result = "ok",
                withdrawn = withdrawn,
                requestId = requestId
            }, protocol)
        end
    end
end
