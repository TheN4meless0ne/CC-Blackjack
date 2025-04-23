
--[[
  ComputerCraft Bank System - startup.lua
  Uses live (uncached) discovery for animated retry so startup UI will exit when turtle is detected.
]]

local account = require "bank.account"
local turtle_ctrl = require "bank.turtle_control"
local ui_utils = require "bank.ui_utils"

-- CONFIGURATION: Use peripheral names from your network setup!
local MONITOR_NAME      = "right"
local DISK_DRIVE_NAME   = "top"
local TURTLE_NAME       = "turtle_5"
local CHEST_NAME        = "BANK_CHEST"          -- Make sure this is set correctly!
local DIAMOND_ITEM      = "minecraft:diamond"   -- Name used for diamonds in the chest

local function getMonitor()
    local mon = peripheral.wrap(MONITOR_NAME)
    if not mon then error("Advanced monitor not found: "..MONITOR_NAME) end
    mon.setTextScale(1)
    return mon
end

local function drawStartScreen(mon)
    mon.clear()
    mon.setBackgroundColor(colors.green)
    mon.setTextColor(colors.yellow)
    ui_utils.centerPrint(mon, 6, "Welcome to the")
    ui_utils.centerPrint(mon, 7, "Bank of NMLS")
    mon.setTextColor(colors.white)
    ui_utils.centerPrint(mon, 10, "Please insert")
    ui_utils.centerPrint(mon, 11, "your card")
end

local function drawMainScreen(mon, user, balance)
    mon.setBackgroundColor(colors.green)
    mon.clear()
    ui_utils.centerPrint(mon, 3, "Welcome")
    ui_utils.centerPrint(mon, 5, "Card: "..(user or "Insert Card"))
    ui_utils.centerPrint(mon, 6, "Balance: "..(balance ~= nil and "$"..balance or "N/A"))
    ui_utils.centerPrint(mon, 9, "[Deposit]")
    ui_utils.centerPrint(mon, 12, "[Withdraw]")
    ui_utils.centerPrint(mon, 15, "Please remove your")
    ui_utils.centerPrint(mon, 16, "card when done")
end

local function drawExitScreen(mon)
    mon.setBackgroundColor(colors.green)
    mon.clear()
    ui_utils.centerPrint(mon, 9, "Good Bye!")
end

local function drawTurtleNotFound(mon, dotCount)
    mon.setBackgroundColor(colors.green)
    mon.clear()
    ui_utils.centerPrint(mon, 6, "BANK TURTLE")
    ui_utils.centerPrint(mon, 8, "NOT FOUND!")
    ui_utils.centerPrint(mon, 10, "Turn on and run")
    ui_utils.centerPrint(mon, 11, "the worker script")
    local dots = string.rep(".", dotCount)
    ui_utils.centerPrint(mon, 13, "Retrying" .. dots)
end

local function waitForDisk(mon)
    print("Waiting for card insertion...")
    while true do
        local e, side = os.pullEvent("disk")
        if side == DISK_DRIVE_NAME then return end
    end
end

local function waitForCardRemoval()
    while peripheral.isPresent(DISK_DRIVE_NAME) do
        sleep(0.5)
    end
end

local function locateTurtleBlocking(mon)
    local dot = 1
    while true do
        local id = turtle_ctrl.getTurtleId()
        if id then
            print("Bank turtle found: "..tostring(id))
            return id
        else
            drawTurtleNotFound(mon, dot)
            dot = dot + 1
            if dot > 3 then dot = 1 end
            sleep(0.5)
        end
    end
end

local function main()
    local mon = getMonitor()
    locateTurtleBlocking(mon)

    while true do
        drawStartScreen(mon)
        waitForDisk(mon)

        local ok, user, balance
        -- Try to get account, show error and restart if not found
        ok = pcall(function()
            user, balance = account.getAccount(DISK_DRIVE_NAME)
        end)
        if not ok or not user then
            drawStartScreen(mon)
            waitForDisk(mon)
            ok, user, balance = pcall(function()
                return account.getAccount(DISK_DRIVE_NAME)
            end)
        end
        drawMainScreen(mon, user, balance)

        local running = true
        local exitMode = false
        while running do
            local event, p1, x, y = os.pullEvent()
            if event == "monitor_touch" and p1 == MONITOR_NAME and not exitMode then
                if y == 9 and x >= 2 and x <= 9 then -- [Deposit]
                    local result = account.handleDeposit(DISK_DRIVE_NAME, mon, CHEST_NAME, DIAMOND_ITEM, TURTLE_NAME)
                    if result == "card_missing" then
                        drawStartScreen(mon)
                        os.reboot()
                        break
                    elseif result == "back" then
                        -- FIX: get user and balance!
                        user, balance = account.getAccount(DISK_DRIVE_NAME)
                        drawMainScreen(mon, user, balance)
                    else
                        balance = result
                        drawMainScreen(mon, user, balance)
                    end
                elseif y == 12 and x >= 2 and x <= 11 then -- [Withdraw]
                    local result = account.handleWithdraw(DISK_DRIVE_NAME, mon, CHEST_NAME, DIAMOND_ITEM, TURTLE_NAME)
                    if result == "card_missing" then
                        drawStartScreen(mon)
                        os.reboot()
                        break
                    elseif result == "back" then
                        -- FIX: get user and balance!
                        user, balance = account.getAccount(DISK_DRIVE_NAME)
                        drawMainScreen(mon, user, balance)
                    else
                        balance = result
                        drawMainScreen(mon, user, balance)
                    end
                elseif y == 15 and x >= 2 and x <= 7 then -- [Done]
                    drawExitScreen(mon)
                    exitMode = true
                end
                if not exitMode then
                    drawMainScreen(mon, user, balance)
                end
            elseif event == "disk_eject" and p1 == DISK_DRIVE_NAME then
                drawExitScreen(mon)
                os.reboot()
            end
        end
        waitForCardRemoval()
    end
end

main()
