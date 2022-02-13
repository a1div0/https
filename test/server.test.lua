require('test.ide-debug')
local tap = require('tap')
local https_lib = require('https.server')
local http_client = require('http.client')
local acme_lib = require("acme-client")
local test = tap.test('https.redirect tests')

local function test_main(test)

    test:plan(12)

    local function echo_proc(request)
        local body = request:read()
        local response = request:render{ text = body }
        response.headers['x-test-header'] = request.method..' '..request.path;
        response.status = 200
        return response
    end

    local options = {
        host = '127.0.0.1',
        port80 = 8080,
        port443 = 443,
        dns_name = 'vpoint.me',
        cert_path = '/srv/sftp/sftp-user/https/test/cert/',
        cert_name = 'ssl-test.pem',
        ssl = false,
    }
    local cert_full_name = options.cert_path..options.cert_name
    local echo_path = '/echo'
    local echo_url = ''
    local server = nil

    os.remove(cert_full_name)

    if options.port80 == 80 then
        echo_url = 'http://'..options.host..echo_path
    else
        echo_url = string.format('http://%s:%d%s', options.host, options.port80, echo_path)
    end

    server = https_lib.new(options)
    server:route({ path = echo_path }, echo_proc)
    server:start()

    local r = http_client.post(echo_url, 'TEST0', {timeout=3})
    test:is(r.status, 200, 'Check easy mode (no SSL) - status 200')
    test:is(r.body, 'TEST0', 'Check easy mode (no SSL) - body echo')

    server:stop()

    if options.port443 == 443 then
        echo_url = 'https://'..options.dns_name..echo_path
    else
        echo_url = string.format('https://%s:%d%s', options.dns_name, options.port443, echo_path)
    end

    local server = https_lib.new(options)
    test:isnt(server, nil, 'HTTPS-server create without cert-file')

    server:route({ path = echo_path }, echo_proc)
    server:start()

    local cert_time1 = acme_lib.certValidTo(cert_full_name)
    test:isnt(cert_time1, nil, 'Check first SSL-certificate')
    require("fiber").sleep(1)
    
    local r = http_client.post(echo_url, 'TEST1', {timeout=3})
    test:is(r.status, 200, 'Status response 1')
    test:is(r.body, 'TEST1', 'Body response 1')

    server.time_to_reissue = 2*(cert_time1 - os.time())
    server:schedule()

    local cert_time2 = acme_lib.certValidTo(cert_full_name)
    test:isnt(cert_time2, nil, 'Check second SSL-certificate')
    test:ok(cert_time1 < cert_time2, 'Check reissue SSL-certificate over active SSL-channel')

    r = http_client.post(echo_url, 'TEST2', {timeout=3})
    test:is(r.status, 200, 'Status response 2')
    test:is(r.body, 'TEST2', 'Body response 2')

    server:stop()

    local r = http_client.post(echo_url, 'TEST3', {timeout=3})
    test:isnt(r.status, 200, 'Status response 3')
    local reason = string.lower(r.reason)
    local timeout_pos = reason:find("timeout", 1, true)
    test:isnt(timeout_pos, nil, 'Reason response 3')

end

test:plan(1)
test:test('https.redirect main test', test_main)

os.exit(test:check() == true and 0 or -1)