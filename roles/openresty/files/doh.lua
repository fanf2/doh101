local inspect = require "inspect"
local r = ngx.req

require "base64url"

ngx.HTTP_UNSUPPORTED_MEDIA_TYPE = 415
ngx.HTTP_TEAPOT = 418

local ct_doh = 'application/dns-udpwireformat'

local function err(n)
   return ngx.throw_error(ngx[n])
end

local function dodoh(q)
   return ngx.say(q)
end

local function doh_get()
   local q = r.get_query_args()
   if q.ct ~= true -- present but no value
   and q.ct ~= ct_doh then
      return err 'HTTP_UNSUPPORTED_MEDIA_TYPE'
   end
   if not q.dns then
      ngx.log(ngx.ERR, "bar")
      -- what error to return in this case?
      return err 'HTTP_TEAPOT'
   end
   return dodoh(ngx.decode_base64url(q.dns))
end

local function doh_post()
   local h = r.get_headers()
   if h['content-type'] ~= ct_doh then
      return err 'HTTP_UNSUPPORTED_MEDIA_TYPE'
   end
   r.read_body()
   return dodoh(r.get_body_data())
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
