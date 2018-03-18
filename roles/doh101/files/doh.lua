local inspect = require "inspect"
local r = ngx.req

require "base64url"

ngx.HTTP_UNSUPPORTED_MEDIA_TYPE = 415
ngx.HTTP_TEAPOT = 418
ngx.HTTP_PAYLOAD_TOO_LARGE = 413

local ct_doh = 'application/dns-udpwireformat'

local function err(n)
   ngx.throw_error(ngx[n])
   error(n)
end

local function moan(msg)
   ngx.log(ngx.ERR, msg)
end

local function die(msg)
   moan(msg)
   return err 'HTTP_INTERNAL_SERVER_ERROR'
end

local function check(what, ok, msg)
   if not ok then
      return die(what..": "..msg)
   else
      return ok
   end
end

local function dodoh(q)
   local ok, msg
   local qlen = #q
   if qlen > 65535 then
      return err 'HTTP_PAYLOAD_TOO_LARGE'
   end
   -- DNS-over-TCP query length
   local ql = string.char((qlen / 256) % 256, qlen % 256)
   q = ql..q
   local s = ngx.socket.tcp()
   s:settimeout(10000) -- milliseconds
   check('connect', s:connect("131.111.57.57", 53))
   check('sent', s:send(q))
   moan('sent')
   local rl = check('receive 2', s:receive(2))
   local hi, lo = string.byte(rl, 1,2)
   local rlen = hi * 256 + lo
   moan('getting '..tostring(rlen))
   local r = check('receive N', s:receive(rlen))
   moan('got '..#r)
   ngx.header.Content_Type = ct_doh;
   ngx.header.Content_Length = tostring(rlen);
   return ngx.print(r)
end

local function doh_get()
   local q = r.get_query_args()
   if q.ct ~= true -- present but no value
   and q.ct ~= ct_doh then
      return err 'HTTP_UNSUPPORTED_MEDIA_TYPE'
   end
   if not q.dns then
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
