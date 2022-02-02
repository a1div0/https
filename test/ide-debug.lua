package.cpath = package.cpath .. ';/home/alex/.local/share/JetBrains/WebStorm2021.2/EmmyLua/classes/debugger/emmy/linux/?.so'
local dbg = require('emmy_core')
dbg.tcpListen('localhost', 9999)
dbg.waitIDE()
--dbg.breakHere()

return dbg