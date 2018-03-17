-- base64url.lua
-- written by Tony Finch <dot@dotat.at>
--
-- derived from base64.lua and ngx_http_lua_string.c
-- written by Yichun Zhang (agentzh)


local ffi = require 'ffi'
local base = require "resty.core.base"

local C = ffi.C
local ngx = ngx
local type = type
local error = error
local get_string_buf = base.get_string_buf
local floor = math.floor


ffi.cdef[[
    typedef struct {
	size_t len;
	uint8_t *data;
    } ngx_str_t;

    intptr_t ngx_decode_base64url(ngx_str_t *dst, ngx_str_t *src);
]]

local ngx_str_t = ffi.typeof "ngx_str_t"

local function base64_decoded_length(len)
    return floor((len + 3) / 4) * 3
end


ngx.decode_base64url = function (s)
    if type(s) ~= 'string' then
        return error("string argument only")
    end
    local slen = #s
    local dlen = base64_decoded_length(#s)
    local d = get_string_buf(dlen)
    local src = ngx_str_t(slen, s)
    local dst = ngx_str_t(dlen, d)
    -- print("dlen: ", tonumber(dlen))
    local r = C.ngx_decode_base64url(dst, src)
    if ok ~= 0 then
        return nil
    end
    return ffi_string(dst.data, dst.len)
end


return {
    version = base.version
}
