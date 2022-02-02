local acme_lib = require('acme-client')
local fio = require('fio')
local http_server_lib = require('http.server')
local https_redirect_lib = require('https.redirect')
local sslsocket = require('sslsocket')

local function update_valid_flags(self)
    local diff = self.cert_valid_to - os.time()
    self.cert_need_reissue = diff < self.time_to_reissue
    self.cert_is_valid = diff >= 3 * 60
end

local function update_valid_to(self)
    local f = fio.open(self.cert_full_name, {"O_RDONLY"})
    if f then
        f:close()
        local ok, valid_to_time = pcall(acme_lib.certValidTo, self.cert_full_name)
        if ok then
            self.cert_valid_to = valid_to_time
            update_valid_flags(self)
        end
    else
        self.cert_need_reissue = true
        self.cert_is_valid = false
    end
end

local function route(self, options, proc)
    table.insert(self.route_table, {options = options, proc = proc})
end

local function ssl_listen(self, handle_function)
    local function wrapper_handle(...)
        handle_function(self, ...)
    end

    local ctx = sslsocket.ctx(sslsocket.methods.tlsv12)

    print("Open private key file: "..self.csrName)
    local rc = sslsocket.ctx_use_private_key_file(ctx, self.csrName)
    if rc == false then
        error('Private key is invalid')
    end

    print("Open certificate file: "..self.certName)
    rc = sslsocket.ctx_use_certificate_file(ctx, self.certName)
    if rc == false then
        error('Certificate is invalid')
    end

    return sslsocket.tcp_server(self.host, self.port, wrapper_handle,nil, ctx)
end

local function start_ssl(self)
    self.server = http_server_lib.new(self.options.host, self.options.port443)

    for _, tuple in ipairs(self.route_table) do
        self.server:route(tuple.options, tuple.proc)
    end

    self.server.tcp_server_f = ssl_listen
    self.server:start()
    self.redirect = https_redirect_lib.new()
    self.redirect:start(self.options.host, self.options.port80)
    self.ssl_active = true
end

local function stop_ssl(self)
    self.ssl_active = false
    self.redirect:stop()
    self.server:stop()
end

local function setup_challenge_proc(self)
    local server_handle = self.server
    local function setup_challenge_http01(url, body)
        local proc = nil
        if body ~= nil then
            proc = function (request)
                return request:render{status = 200, text = body}
            end
        else
            proc = function (request)
                return request:render{status = 404}
            end
        end
        server_handle:route({ path = url }, proc)
    end
    return setup_challenge_http01
end

local function start(self)
    update_valid_to(self)

    self.ssl_active = false
    if self.cert_is_valid then
        start_ssl(self)
    else
        self.server = http_server_lib.new(self.options.host, self.options.port80)
        self.server:start()
    end

    if self.cert_need_reissue then
        local proc = setup_challenge_proc(self)
        local acme_client = acme_lib.new(self.options, proc)
        acme_client:getCert()
        update_valid_to(self)
    end

    if not self.ssl_active then
        self.server:stop()
        start_ssl(self)
    end
end

local function stop(self)
    if self.ssl_active then
        stop_ssl(self)
    else
        self.server:stop()
    end
end

local function schedule(self)
    update_valid_flags(self)
    if self.cert_need_reissue then
        self:stop()
        self:start()
    end
end

local exports = {
    new = function(options)
        local self = {
            time_to_reissue = 24 * 3600,
            options = options,
            route_table = {},
            route = route,
            start = start,
            stop = stop,
            schedule = schedule,
        }

        self.options.internalIP4 = options.host or options.internalIP4
        self.options.dnsName = options.dns_name or options.dnsName
        self.options.certPath = options.cert_path or options.certPath
        self.options.certName = options.cert_name or options.certName
        self.cert_full_name = self.options.certPath..self.options.certName

        return self
    end
}

return exports