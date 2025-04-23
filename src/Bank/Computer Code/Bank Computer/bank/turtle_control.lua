
--[[
  bank/turtle_control.lua
  Handles the turtle logic for depositing and withdrawing diamonds.
  Now: Never caches turtle ID; always performs a live rednet search for every operation.
]]

local M = {}

-- Set as appropriate
local MODEM_SIDE = "bottom"
local PROTOCOL = "bankOp"

if not rednet.isOpen(MODEM_SIDE) then
    rednet.open(MODEM_SIDE)
end

local function findTurtle()
    local id = nil
    print("Looking for bank turtle...")
    rednet.broadcast({hello="bankTurtle"}, PROTOCOL)
    local sid, msg = rednet.receive(PROTOCOL, 2)
    if msg and msg.hello == "bankTurtle" then
        id = sid
        print("Bank turtle found: "..id)
    else
        print("Bank turtle NOT found. Is the turtle worker script running?")
    end
    return id
end

-- Non-caching live check for every operation
function M.getTurtleId()
    return findTurtle()
end

function M.sendDepositRequest(chest_name, diamond_item, turtle_name, requestId)
    local tid = M.getTurtleId()
    if not tid then
        print("ERROR: No bank turtle found! Is it powered on and running the worker script?")
        error("Could not find Bank Turtle!")
    end
    rednet.send(tid, {
        command = "depositDiamonds",
        chest = chest_name,
        item = diamond_item,
        turtle = turtle_name,
        requestId = requestId
    }, PROTOCOL)
end

function M.sendWithdrawRequest(chest_name, diamond_item, turtle_name, amount, requestId)
    local tid = M.getTurtleId()
    if not tid then
        print("ERROR: No bank turtle found! Is it powered on and running the worker script?")
        error("Could not find Bank Turtle!")
    end
    rednet.send(tid, {
        command = "withdrawDiamonds",
        amount = amount,
        chest = chest_name,
        item = diamond_item,
        turtle = turtle_name,
        requestId = requestId
    }, PROTOCOL)
end

return M
