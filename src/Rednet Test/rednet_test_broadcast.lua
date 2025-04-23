-- Change this to the side your modem is actually attached on the main computer.
local MODEM_SIDE = "bottom"
local PROTOCOL = "bankOp"  -- Must match on receiver

print("Opening rednet on side:", MODEM_SIDE)
rednet.open(MODEM_SIDE)
print("rednet.isOpen:", rednet.isOpen(MODEM_SIDE))

print("Broadcasting test message {test='helloTurtle'} on protocol '"..PROTOCOL.."'")
rednet.broadcast({test="helloTurtle"}, PROTOCOL)
print("Broadcast sent! Now exiting.")