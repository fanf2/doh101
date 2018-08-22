local r = ngx.req
local band = bit.band
local rshift = bit.rshift
local char = string.char

require "base64url"

ngx.HTTP_UNSUPPORTED_MEDIA_TYPE = 415

local ct_doh = 'application/dns-message'

local DNS_EOH = 13

local FORMERR = 1
local NOTIMP = 4
local REFUSED = 5

local RRTYPE_SOA = 6
local RRCLASS_IN = 1

local maxttl = 7 * 24 * 3600

local function moan(msg)
   ngx.log(ngx.ERR, msg)
end

local function err(status, message)
   ngx.status = ngx[status]
   moan(message)
   ngx.print(message,"\n")
end

local function die(msg)
   moan(msg)
   return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

local function check(what, ok, msg)
   if not ok then
      return die(what..": "..msg)
   else
      return ok
   end
end

local function get16(q, start)
   if start == nil then return end
   local hi, lo = q:byte(start, start + 1)
   if lo == nil then return end
   return 256 * hi + lo
end

local function get32(q, start)
   if start == nil then return end
   local b3, b2, b1, b0 = q:byte(start, start + 3)
   if b0 == nil then return end
   return 16777216 * b3 + 65536 * b2 + 256 * b1 + b0
end

local function put16(n)
   return char(band(0xff, rshift(n, 8)), band(0xff, n))
end

local function skipname(q, start)
   if start == nil then return end
   local namelen = 0
   local done = false
   repeat
      local label = q:byte(start + namelen)
      if label == nil then
	 return
      elseif label == 0 then
	 namelen = namelen + 1
	 done = true
      elseif band(label, 0xc0) ~= 0 then
	 namelen = namelen + 2
	 done = true
      else
	 namelen = namelen + label + 1
      end
      if namelen > 255 then
	 return
      end
   until done
   return start + namelen
end

local function skiprr(q, start)
   local middle = skipname(q, start)
   if middle == nil then return end
   local rdlength = get16(q, middle + 8)
   if rdlength == nil then return end
   return middle, middle + 10 + rdlength
end

local function get_ttl(q)
   local qdcount = get16(q, 5)
   local ancount = get16(q, 7)
   local nscount = get16(q, 9)
   if qdcount ~= 1 then return end
   local pos = skipname(q, DNS_EOH)
   if pos == nil then return end
   pos = pos + 4
   local ttl = maxttl
   local mid
   for i = 1, ancount do
      mid, pos = skiprr(q, pos)
      if pos == nil then return end
      local rrttl = get32(q, mid + 4)
      if ttl > rrttl then ttl = rrttl end
   end
   for i = 1, nscount do
      mid, pos = skiprr(q, pos)
      if pos == nil then return end
      if get16(q, mid) == RRTYPE_SOA
      and get16(q, mid+2) == RRCLASS_IN then
	 local rrttl = get32(q, mid + 4)
	 if ttl > rrttl then ttl = rrttl end
	 mid = skipname(q, skipname(q, mid + 10))
	 if mid == nil then return end
	 rrttl = get32(q, mid + 16)
	 if rrttl == nil then return end
	 if ttl > rrttl then ttl = rrttl end
      end
   end
   return ttl
end

local function reply(r)
   local ttl = get_ttl(r)
   if ttl ~= nil then
      ngx.header.Cache_Control = ("max-age=%d"):format(ttl)
   else
      ngx.header.Cache_Control = "no-cache, no-store"
   end
   ngx.header.Content_Type = ct_doh
   ngx.header.Content_Length = tostring(#r)
   return ngx.print(r)
end

local function dnserr(rcode, q, qn_end)
   local id = get16(q, 1)
   local flags = get16(q, 3)
   -- qr=1 aa=0 tc=0 ra=1; copy opcode and rd
   flags = band(flags, 0x7900) + 0x8080 + rcode
   local qdcount, qsect = 0, ""
   if qn_end then
      qdcount = 1
      qsect = q:sub(DNS_EOH, qn_end + 3)
   end
   return reply(put16(id) ..
		put16(flags) ..
		put16(qdcount) ..
		put16(0) .. -- ancount
		put16(0) .. -- nscount
		put16(0) .. -- arcount
		qsect)
end

local function dodoh(q)
   if type(q) ~= 'string' then
      return err('HTTP_BAD_REQUEST',
		 'could not get query from request')
   end
   local qlen = #q
   if qlen < 17 or qlen > 65535 then
      return err('HTTP_BAD_REQUEST',
		 'bad query length')
   end
   local qn_end = skipname(q, DNS_EOH)
   if qn_end == nil or qlen < qn_end + 3 then
      return dnserr(FORMERR, q)
   end
   -- check QR == 0 and opcode == query
   local opcode = q:byte(3)
   if band(opcode, 0xf8) ~= 0 then
      return dnserr(NOTIMP, q, qn_end)
   end
   -- no metaqueries
   local qt = get16(q, qn_end)
   if qt >= 128 and qt <= 254 then
      return dnserr(NOTIMP, q, qn_end)
   end
   -- DNS-over-TCP query length
   q = put16(qlen)..q
   local addr = ngx.var.server_addr
   if addr:find(':') then
      addr = '['..addr..']'
   end
   local s = ngx.socket.tcp()
   s:settimeout(10000) -- milliseconds
   check('connect', s:connect(addr, 53))
   check('sent', s:send(q))
   local rlen = check('receive 2', s:receive(2))
   local r = check('receive N', s:receive(get16(rlen, 1)))
   return reply(r)
end

local function doh_get()
   local q = r.get_query_args()
   if not q.dns then
      -- informative errors for misdirected browsers
      moan('missing ?dns= parameter')
      return ngx.exec '@doh_no_dns'
   else
      return dodoh(ngx.decode_base64url(q.dns))
   end
end

local function doh_post()
   local h = r.get_headers()
   if h['content-type'] ~= ct_doh then
      return err('HTTP_UNSUPPORTED_MEDIA_TYPE',
		 'POST body must be application/dns-message')
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
   ngx.header.Allow = "GET, HEAD, POST"
   return err('HTTP_NOT_ALLOWED',
	      'method not allowed')
end
