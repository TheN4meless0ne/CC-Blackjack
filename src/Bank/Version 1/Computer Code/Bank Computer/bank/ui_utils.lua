local M = {}

-- Print centered text on a given monitor at a specific y row
function M.centerPrint(mon, y, text)
    local w, _ = mon.getSize()
    local x = math.floor((w - #text) / 2) + 1
    mon.setCursorPos(x, y)
    mon.write(text)
end

return M