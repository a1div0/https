<a href="http://tarantool.org">
   <img src="https://avatars2.githubusercontent.com/u/2344919?v=2&s=250"
align="right">
</a>

# HTTPS-server for Tarantool
## Table of contents
* [General information](#general-information)
* [Installation](#installation)
* [API](#api)
* [An example of using the module](#an-example-of-using-the-module)

## General information
Link to [GitHub](https://github.com/a1div0/https "GitHub").
Used extern libs:
* [ACME-client](https://github.com/a1div0/acme-client)
* [SSL-socket](https://github.com/tarantool/sslsocket)
* [HTTP-server](https://github.com/tarantool/http)

## Installation
You can:
* clone the repository:
``` shell
git clone https://github.com/a1div0/https.git
```
* install the `https` module using `tarantoolctl`:
```shell
tarantoolctl rocks install https://raw.githubusercontent.com/a1div0/https/main/https-1.0.3-1.rockspec
```

## API
* `local https = require('https.server')` - acquire a library handle
* `local server = https.new(options)` - create new server-object
* `server:route(options, proc)` - binds address and handler
* `server:start()` - starts the server
* `server:stop()` - stop the server
* `server:schedule()` - procedure to run on schedule - reissue the certificate
when its expiration date comes up

### new
```
new(options)
```
This procedure create a new server object with the specified parameters.
The `options` parameter, which is a table with fields:
* `host` - the host to bind to
* `port80` - the port 80 to bind to
* `port443` - the port 443 to bind to
* `dns_name` - site name for certificate
* `cert_path` - path to the folder for storing the certificate and for creating
temporary files in the process of obtaining a certificate
* `cert_name` - file name of the prepared certificate, or, how to name the
certificate when receiving it

For more options see [acme-client](https://github.com/a1div0/acme-client).

### serverObject:route
It is possible to automatically route requests between different handlers,
depending on the request path. For more information see
[http-server](https://github.com/tarantool/http).

### serverObject:start and serverObject:stop
Starts and stop the server.

### serverObject:schedule
Checks if the deadline has passed, and if so, starts the process of obtaining a
new certificate and restarts the server with a new certificate.

## An example of using the module
``` lua
    local https = require('https.server')
    
    local function echo_proc(request)
        local response = request:render{ text = request.body }
        response.headers['x-test-header'] = request.method..' '..request.path;
        response.status = 200
        return response
    end
    
    local options = {
        host = '0.0.0.0',
        port80 = 80,
        port443 = 443,
        dns_name = 'mysite.me',
        cert_path = 'cert/',
        cert_name = 'ssl.pem',
    }
    
    local server = https.new(options)
    server:route({ path = '/echo' }, echo_proc)
    server:start()
```