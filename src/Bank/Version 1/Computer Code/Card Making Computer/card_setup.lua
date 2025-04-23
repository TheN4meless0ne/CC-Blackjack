
--[[
  card_setup.lua
  Utility for admins to create new Diamond Card floppy disks for players.

  Instructions:
    1. Place a blank floppy disk (or one you wish to rename/re-initialize) into the disk drive.
    2. Run this program; follow the prompts for player name.
    3. The disk will be labeled as "{name}'s Diamond Card - $0" for use by the banking system.
    4. Each name can only be used once.
--]]

local DRIVE_NAME = "right" -- Change this to the correct drive name if needed
local USED_NAMES_FILE = "/used_names.txt"

-- Helper: Read used names into a set
local function loadUsedNames()
    local names = {}
    if fs.exists(USED_NAMES_FILE) then
        local file = fs.open(USED_NAMES_FILE, "r")
        while true do
            local line = file.readLine()
            if not line then break end
            names[line] = true
        end
        file.close()
    end
    return names
end

-- Helper: Append a name to the used names file
local function saveUsedName(name)
    local file = fs.open(USED_NAMES_FILE, "a")
    file.writeLine(name)
    file.close()
end

write("Enter player's name: ")
local playerName = read()
if not playerName or playerName == "" then
    print("No player name entered. Aborting.")
    return
end

local usedNames = loadUsedNames()
if usedNames[playerName] then
    print("This name has already been used. Please choose a different name.")
    return
end

local balance = 0

print("Please insert a floppy disk into '" .. DRIVE_NAME .. "'...")
while not disk.isPresent(DRIVE_NAME) do
    sleep(0.5)
end

local label = ("%s's Diamond Card - $%d"):format(playerName, balance)
disk.setLabel(DRIVE_NAME, label)

local mount = disk.getMountPath(DRIVE_NAME)
if mount then
    local file = fs.open(mount .. "/account.txt", "w")
    file.writeLine(("%s:%d"):format(playerName, balance))
    file.close()
end

saveUsedName(playerName)

print("Card written as: " .. label)
print("You can now remove the floppy disk.")
