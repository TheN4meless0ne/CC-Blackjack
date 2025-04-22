
--[[
  bank/account.lua
  Handles reading/writing user account data from floppy disk (card).
  Updated to always use live turtle discovery in deposit logic.
]]

local ui_utils = require "bank.ui_utils"

local M = {}

-- Parse disk label of form "{user}'s Diamond Card - $balance"
function M.parseLabel(label)
    local user, balance = label:match("^(.+)'s Diamond Card %- %$(%d+)$")
    balance = tonumber(balance)
    return user, balance
end

function M.getAccount(disk_drive_name)
    local label = disk.getLabel(disk_drive_name)
    if not label then error("Card not labeled properly.") end
    local user, balance = M.parseLabel(label)
    if not (user and balance) then error("Invalid card label! Expected format: 'Name's Diamond Card - $bal'") end
    return user, balance
end

function M.setBalance(disk_drive_name, user, balance)
    local new_label = ("%s's Diamond Card - $%d"):format(user, balance)
    disk.setLabel(disk_drive_name, new_label)
    -- Optionally also write to a file for logging or recovery
    local mount = disk.getMountPath(disk_drive_name)
    if mount then
        local file = fs.open(mount.."/account.txt", "w")
        file.writeLine(("%s:%d"):format(user, balance))
        file.close()
    end
end



function M.handleDeposit(disk_drive_name, mon, chest_name, diamond_item, turtle_name)
    local ui_utils = require "bank.ui_utils"

    -- If card not present, exit gracefully
    if not disk.isPresent(disk_drive_name) then
        mon.clear()
        ui_utils.centerPrint(mon, 7, "No card detected!")
        ui_utils.centerPrint(mon, 8, "Goodbye!")
        sleep(2)
        return "card_missing"
    end

    mon.clear()
    mon.setCursorPos(1,1)

    -- Draw prompt and buttons
    local function drawDepositScreen()
        mon.clear()
        ui_utils.centerPrint(mon, 5, "Please place your")
        ui_utils.centerPrint(mon, 6, "diamonds in the")
        ui_utils.centerPrint(mon, 7, "chest and confirm")
        ui_utils.centerPrint(mon, 8, "your deposit")
        ui_utils.centerPrint(mon, 12, "[Deposit]")
        ui_utils.centerPrint(mon, 14, "[Go Back]")
        return 12, 14
    end

    local depositY, goBackY = drawDepositScreen()
    while true do
        if not disk.isPresent(disk_drive_name) then
            mon.clear()
            ui_utils.centerPrint(mon, 7, "Card removed!")
            ui_utils.centerPrint(mon, 8, "Goodbye!")
            sleep(2)
            return "card_missing"
        end
        local event, side, x, y = os.pullEvent("monitor_touch")
        if side == peripheral.getName(mon) then
            if y == depositY then break end
            if y == goBackY then
                return "back"
            end
        end
    end

    -- Animated "Counting..." while waiting for the turtle
    local animFrames = {"Counting.  ", "Counting.. ", "Counting..."}
    local frame = 1

    -- Prepare variables for tracking progress
    local user, balance = M.getAccount(disk_drive_name)

    local tc = require("bank.turtle_control")
    tc._lastRequestId = (tc._lastRequestId or 0) + 1
    local requestId = tc._lastRequestId

    local TURTLE_ID = tc.getTurtleId()
    if not TURTLE_ID then error("Could not find Bank Turtle!") end
    rednet.send(TURTLE_ID, {command="depositDiamonds", requestId=requestId}, "bankOp")

    local depositedAmount = nil
    local startTime = os.clock()
    local timeout = 450
    repeat
        if not disk.isPresent(disk_drive_name) then
            mon.clear()
            ui_utils.centerPrint(mon, 7, "Card removed!")
            ui_utils.centerPrint(mon, 8, "Goodbye!")
            sleep(2)
            return "card_missing"
        end
        mon.clear()
        ui_utils.centerPrint(mon, 7, animFrames[frame])
        frame = frame % #animFrames + 1

        local sid, msg = rednet.receive("bankOp", 0.4)
        if msg and type(msg) == "table" and msg.result == "ok" and msg.deposited and msg.requestId == requestId then
            depositedAmount = msg.deposited
        end

        if os.clock() - startTime > timeout then
            depositedAmount = 0
        end
    until depositedAmount ~= nil

    -- Set account balance and show result
    if not disk.isPresent(disk_drive_name) then
        mon.clear()
        ui_utils.centerPrint(mon, 7, "Card removed!")
        ui_utils.centerPrint(mon, 8, "Goodbye!")
        sleep(2)
        return "card_missing"
    end
    balance = balance + depositedAmount
    M.setBalance(disk_drive_name, user, balance)
    mon.clear()
    ui_utils.centerPrint(mon, 7, ("You added $"..tostring(depositedAmount)..""))
    ui_utils.centerPrint(mon, 8, ("New balance: $"..tostring(balance)))
    sleep(2)

    local user, balance = M.getAccount(disk_drive_name)
    return balance
end


function M.handleWithdraw(disk_drive_name, mon, chest_name, diamond_item, turtle_name)
    local ui_utils = require "bank.ui_utils"

    if not disk.isPresent(disk_drive_name) then
        mon.clear()
        ui_utils.centerPrint(mon, 7, "No card detected!")
        ui_utils.centerPrint(mon, 8, "Goodbye!")
        sleep(2)
        return "card_missing"
    end

    local user, balance = M.getAccount(disk_drive_name)

    -- Utility for ceiling division for odd numbers, always payout higher half
    local function ceilDiv(num, div)
        local q = math.floor(num / div)
        if num % div ~= 0 then
            q = q + 1
        end
        return q
    end

    -- Figure out available payout options
    local payoutOptions = {}
    if balance > 256 then
        payoutOptions = {
            {label = "[Payout 256]", amount = 256},
            {label = "[Payout 128]", amount = 128},
        }
    elseif balance > 8 then
        payoutOptions = {
            {label = "[Full]", amount = balance},
            {label = "[Half]", amount = ceilDiv(balance, 2)},
        }
    elseif balance >= 8 then
        payoutOptions = {
            {label = "[Full]", amount = balance},
            {label = "[Half]", amount = ceilDiv(balance, 2)},
        }
    else
        payoutOptions = {
            {label = "[Full]", amount = balance},
        }
    end

    local function drawPayoutPage(options)
        mon.clear()
        ui_utils.centerPrint(mon, 2, "Payout")
        ui_utils.centerPrint(mon, 4, ("Balance: $"..tostring(balance)))
        for i, opt in ipairs(options) do
            ui_utils.centerPrint(mon, 6 + 2*i, opt.label)
        end
        local goBackY = 6 + 2*#options + 2
        ui_utils.centerPrint(mon, goBackY, "[Go Back]")
        return goBackY
    end

    local goBackLine = drawPayoutPage(payoutOptions)
    local payoutButtonLines = {}
    for i = 1, #payoutOptions do
        payoutButtonLines[6 + 2 * i] = i
    end

    local selection = nil
    while not selection do
        if not disk.isPresent(disk_drive_name) then
            mon.clear()
            ui_utils.centerPrint(mon, 7, "Card removed!")
            ui_utils.centerPrint(mon, 8, "Goodbye!")
            sleep(2)
            return "card_missing"
        end
        local event, side, x, y = os.pullEvent()
        if event == "monitor_touch" and side == peripheral.getName(mon) then
            if payoutButtonLines[y] then
                selection = payoutOptions[payoutButtonLines[y]]
            elseif y == goBackLine then
                return "back"
            end
            if not selection and #payoutOptions == 1 and y ~= goBackLine then
                selection = payoutOptions[1]
            end
        end
    end

    local chosen = selection.amount
    local _, latestBalance = M.getAccount(disk_drive_name)
    if chosen > latestBalance then
        mon.clear()
        mon.setCursorPos(1,2)
        mon.write("Insufficient funds!")
        sleep(2)
        return latestBalance
    end

    local tc = require("bank.turtle_control")
    tc._lastRequestId = (tc._lastRequestId or 0) + 1
    local requestId = tc._lastRequestId

    tc.sendWithdrawRequest(chest_name, diamond_item, turtle_name, chosen, requestId)

    local animFrames = {"Dispensing.  ", "Dispensing.. ", "Dispensing..."}
    local frame = 1
    local timeout = 450
    local dispensedAmount = nil
    local startTime = os.clock()
    repeat
        if not disk.isPresent(disk_drive_name) then
            mon.clear()
            ui_utils.centerPrint(mon, 7, "Card removed!")
            ui_utils.centerPrint(mon, 8, "Goodbye!")
            sleep(2)
            return "card_missing"
        end
        mon.clear()
        ui_utils.centerPrint(mon, 7, animFrames[frame])
        frame = frame % #animFrames + 1

        local sid, msg = rednet.receive("bankOp", 0.4)
        if msg and type(msg) == "table" and msg.result == "ok" and msg.withdrawn and msg.requestId == requestId then
            dispensedAmount = msg.withdrawn
        end

        if os.clock() - startTime > timeout then
            dispensedAmount = 0
        end
    until dispensedAmount ~= nil

    if not disk.isPresent(disk_drive_name) then
        mon.clear()
        ui_utils.centerPrint(mon, 7, "Card removed!")
        ui_utils.centerPrint(mon, 8, "Goodbye!")
        sleep(2)
        return "card_missing"
    end

    local finalBalance = latestBalance - dispensedAmount
    if finalBalance < 0 then finalBalance = 0 end
    M.setBalance(disk_drive_name, user, finalBalance)
    mon.clear()
    ui_utils.centerPrint(mon, 7, "Paid out $"..tostring(dispensedAmount))
    ui_utils.centerPrint(mon, 8, "New balance: $"..tostring(finalBalance))
    sleep(2)

    return finalBalance
end




return M
