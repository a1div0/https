--require("test.ide-debug")
local lib = require("https.redirect")
local socket = require("socket")
local tap = require('tap')
local test = tap.test('https.redirect tests')

local host = "127.0.0.1"
local port80 = 8080

local client_data = [[POST /api/catalog_items-get-new? HTTP/1.1
Accept: */*
Host: vpoint.me
Sec-fetch-dest: empty
Sec-fetch-site: same-origin
Accept-language: ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7

Hello!
]]

local check_server_data = [[HTTP/1.1 301 Found
Location: https://vpoint.me/api/catalog_items-get-new?
]]

test:plan(1)

test:test('https.redirect main test', function(test)
    test:plan(3)

    local r = lib.new()
    r:start(host, port80)

    local test_socket, err = socket.tcp_connect(host, port80)
    test:isnt(test_socket, nil, "Client socket create")
    if test_socket == nil then
        print("ERROR: "..err)
    end

    test_socket:send(client_data)
    test_socket:wait()
    local server_data = test_socket:recv()
    test_socket:close()

    server_data = server_data:gsub("\r\n", "\n")
    test:is(server_data, check_server_data, "Check receive data")

    r:stop()

    test_socket, err = socket.tcp_connect(host, port80)
    test:is(test_socket, nil, "Check stopped module")
end)

os.exit(test:check() == true and 0 or -1)