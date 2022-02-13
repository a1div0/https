local acme_lib = require('acme-client')
local fio = require('fio')
local http_server_lib = require('http.server')
local https_redirect_lib = require('https.redirect')
local sslsocket = require('sslsocket')

local function update_valid_flags(self)
    local diff = self.cert_valid_to - os.time()
    self.cert_need_reissue = self.options.ssl and (diff < self.time_to_reissue)
    self.cert_is_valid = diff >= 3 * 60
end

local function update_valid_to(self)
    local f = nil

    if self.options.ssl then
        f = fio.open(self.cert_full_name, {"O_RDONLY"})
    end

    if f then
        f:close()
        local ok, valid_to_time = pcall(acme_lib.certValidTo, self.cert_full_name)
        if ok then
            self.cert_valid_to = valid_to_time
            update_valid_flags(self)
        end
    else
        self.cert_need_reissue = self.options.ssl
        self.cert_is_valid = false
    end
end

local function route(self, options, proc)
    table.insert(self.route_table, {options = options, proc = proc})
end

local function ssl_listen(host, port, options)
    local cert = options.http_server.cert_full_name
    if cert == nil then
        error('Must be define `cert_full_name` property!')
    end

    local ctx = sslsocket.ctx(sslsocket.methods.tlsv12)
    local rc = sslsocket.ctx_use_private_key_file(ctx, cert)
    if rc == false then
        error('Private key is invalid: '..cert)
    end

    rc = sslsocket.ctx_use_certificate_file(ctx, cert)
    if rc == false then
        error('Certificate is invalid: '..cert)
    end

    return sslsocket.tcp_server(host, port, options.handler, nil, ctx)
end

local function start_ssl(self)
    if (self.ssl_enable) then
        self.redirect = https_redirect_lib.new()
        self.redirect:start(self.options.host, self.options.port80)

        self.server = http_server_lib.new(self.options.host, self.options.port443)
        self.server.tcp_server_f = ssl_listen
        self.server.cert_full_name = self.cert_full_name

        self.ssl_active = true
    else
        self.server = http_server_lib.new(self.options.host, self.options.port80)
    end

    for _, tuple in ipairs(self.route_table) do
        self.server:route(tuple.options, tuple.proc)
    end

    self.server:start()
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

    if self.ssl_enable then
        update_valid_to(self)

        if self.cert_need_reissue then
            self.server = http_server_lib.new(self.options.host, self.options.port80)
            self.server:start()
            local proc = setup_challenge_proc(self)
            local acme_client = acme_lib.new(self.options, proc)
            acme_client:getCert()
            self.server:stop()
            update_valid_to(self)
        end
    end

    start_ssl(self)
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
            ssl_enable = options.ssl ~= false
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