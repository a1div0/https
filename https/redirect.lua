local socket = require('socket')

local function get_new_url(sock)
    local line1 = sock:read("\n")
    local method, url, version = line1:match("(.+) (.+) (.+)\n")

    local findPhrase = "Host: "
    local loop = true
    while loop do
        local line = sock:read("\n")
        if line == nil then
            break
        else
            local pos = line:find(findPhrase, 1, true)
            if pos == 1 then
                local host = line:sub(pos + string.len(findPhrase), -2)
                return "https://"..host..url
            end
        end
    end
end

local function handler(sock)
    local ok, result = pcall(get_new_url, sock)
    if ok and result ~= nil and type(result) == "string" then
        sock:write("HTTP/1.1 301 Found\r\n")
        sock:write("Location: "..result.."\r\n")
    else
        sock:write("HTTP/1.1 500 Internal Server Error\r\n")
        sock:write("Content-Length: 10\r\n")
        sock:write("Content-Type: text/plain\r\n")
        sock:write("\r\n")
        if (result ~= nil) then
            sock:write(""..result)
        else
            sock:write("Bad request")
        end
    end
end

local function start(self, host, port80)
    self.s = socket.tcp_server(host, port80, handler)
end

local function stop(self)
    if self.s ~= nil then
        self.s:close()
    end
end

local exports = {
    new = function()
        local self = {
            start = start,
            stop = stop,
        }

        return self
    end
}

return exports