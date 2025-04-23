-- Change this to the side your modem is actually on the turtle.
local MODEM_SIDE = "right"
local PROTOCOL = "bankOp"

print("Opening rednet on side:", MODEM_SIDE)
rednet.open(MODEM_SIDE)
print("rednet.isOpen:", rednet.isOpen(MODEM_SIDE))

print("Waiting to receive a rednet message (timeout: 10 seconds) on protocol '"..PROTOCOL.."'...")
local id, msg, protocol = rednet.receive(PROTOCOL, 10)

if id then
    print("Received message from ID:", id)
    if type(msg) == "table" then
        print("Message:", textutils.serialize(msg))
    else
        print("Message:", tostring(msg))
    end
    print("Protocol:", tostring(protocol))
else
    print("No message received after 10 seconds.")
end
print("Test ended.")