package = 'https'
version = '1.0.2-1'
source  = {
    url    = 'git+https://github.com/a1div0/https.git';
    branch = 'main';
    tag = '1.0.2'
}
description = {
    summary  = "Lua module HTTPS-server for Tarantool";
    homepage = 'https://github.com/a1div0/https';
    maintainer = "Alexander Klenov <a.a.klenov@ya.ru>";
    license  = 'BSD2';
}
dependencies = {
    'lua >= 5.1';
}
build = {
    type = 'builtin';
    modules = {
        ['https.server'] = 'https/server.lua';
        ['https.redirect'] = 'https/redirect.lua';
    }
}
