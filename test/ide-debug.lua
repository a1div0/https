package.cpath = package.cpath .. ';test/?.so'
local dbg = require('emmy_core')
dbg.tcpListen('localhost', 9999)
dbg.waitIDE()
--dbg.breakHere()

return dbg