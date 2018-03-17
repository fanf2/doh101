local inspect = require "inspect"
local r = ngx.req

ngx.HTTP_UNSUPPORTED_MEDIA_TYPE = 415

local ct_doh = 'application/dns-udpwireformat'

local function err(n)
   return ngx.throw_error(ngx[n])
end

local function doh_get()
   ngx.say("get")
end

local function doh_post()
   local h = r.get_headers()
   if h['content-type'] ~= ct_doh then
      return err 'HTTP_UNSUPPORTED_MEDIA_TYPE'
   end
   r.read_body()
   ngx.say(r.get_body_data())
end

local method = r.get_method()
if method == 'HEAD' then
   return
elseif method == 'GET' then
   return doh_get()
elseif method == 'POST' then
   return doh_post()
else
   -- TODO: Allow: header
   return err 'HTTP_NOT_ALLOWED'
end
