local TcpServer = require(_G.libDir .. "middleclass")("TcpServer")
local socket = require("socket")

function TcpServer:initialize()
	-- 'Initialize' our variables
	-- Some more initialization.
	self.clients = {}
	self.handshake = "00000"
	self.callbacks = {
		recv = nil,
		connect = nil,
		disconnect = nil,
	}
	self.ping = nil
	self.port = nil
end

function TcpServer:setPing(enabled, time, msg)
	-- Set self.ping if enabled with time and msg,
	-- otherwise set it to nil.
	if enabled then
		self.ping = {
			time = time,
			msg = msg
		}
	else
		self.ping = nil
	end
end

function TcpServer:listen(port)
	-- Create a socket, set the port and listen.
	self:createSocket()
	self.port = tonumber(port)
	self:_listen()
end

function TcpServer:update(dt)
	assert(dt, "Update needs a dt!")
	-- Accept all waiting clients.
	self:accept()
	-- Start handling messages.
	local data, clientid = self:receive()
	while data do
		local hs, conn = data:match("^(.+)([%+%-])\n?$")
		if hs == self.handshake and conn == "+" then
			-- If we already knew the client, ignore.
			if not self.clients[clientid] then
				self.clients[clientid] = {ping = -dt}
				if self.callbacks.connect then
					self.callbacks.connect(clientid)
				end
			end
		elseif hs == self.handshake and conn == "-" then
			-- Ignore unknown clients (perhaps they timed out before?).
			if self.clients[clientid] then
				self.clients[clientid] = nil
				if self.callbacks.disconnect then
					self.callbacks.disconnect(clientid)
				end
			end
		elseif not self.ping or data ~= self.ping.msg then
			-- Filter out ping messages and call the recv callback.
			if self.callbacks.recv then
				self.callbacks.recv(data, clientid)
			end
		end
		-- Mark as 'ping receive', -dt because dt is added after.
		-- (Which means a net result of 0.)
		if self.clients[clientid] then
			self.clients[clientid].ping = -dt
		end
		data, clientid = self:receive()
	end
	if self.ping then
		-- If we ping then up all the counters.
		-- If it exceeds the limit we set, disconnect the client.
		for i, v in pairs(self.clients) do
			v.ping = v.ping + dt
			if v.ping > self.ping.time then
				self.clients[i] = nil
				if self.callbacks.disconnect then
					self.callbacks.disconnect(i)
				end
			end
		end
	end
end


function TcpServer:createSocket()
	self._socks = {}
	self.socket = socket.tcp()
	self.socket:settimeout(0)
	self.socket:setoption("reuseaddr", true)
end

function TcpServer:_listen()
	local status, err = self.socket:bind("*", self.port)
	print("bind", status, err)	
	local status, err = self.socket:listen(5)
	print("listen", status, err)
end

function TcpServer:send(data, clientid)
	-- This time, the clientip is the client socket.
	if clientid then
		self.socket:settimeout(0)
		clientid:settimeout(0)
		clientid:send(data)
		clientid:settimeout(0)
		self.socket:settimeout(0)
	else
		for sock, _ in pairs(self.clients) do
		self.socket:settimeout(0)
		sock:settimeout(0)
			sock:send(data)
			sock:settimeout(0)
		self.socket:settimeout(0)
		end
	end
end

function TcpServer:receive()
	for sock, _ in pairs(self.clients) do
		local packet = ""
		local data, _, partial = sock:receive(8192)
		while data do
			packet = packet .. data
			data, _, partial = sock:receive(8192)
		end
		if not data and partial then
			packet = packet .. partial
		end
		if packet ~= "" then
			return packet, sock
		end
	end
	for i, sock in pairs(self._socks) do
		local data = sock:receive()
		if data then
			local hs, conn = data:match("^(.+)([%+%-])\n?$")
			if hs == self.handshake and conn ==  "+" then
				self._socks[i] = nil
				return data, sock
			end
		end
	end
	return nil, "No messages."
end

function TcpServer:close()
	self.socket:close()
end

function TcpServer:accept()
	local sock = self.socket:accept()
	while sock do
		sock:settimeout(0)
		self._socks[#self._socks+1] = sock
		sock = self.socket:accept()
	end
end

return TcpServer