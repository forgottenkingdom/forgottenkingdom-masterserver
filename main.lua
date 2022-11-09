_G.baseDir      = (...):match("(.-)[^%.]+$")
_G.libDir       = _G.baseDir .. "lib."

_G.Json = require(_G.libDir .. "json")
local TcpServer = require(_G.libDir .. "tcp_server"):new()
local Redis = require(_G.libDir .. "redis")
_G.bitser = require(_G.libDir .. "bitser")
local Utils = require(_G.libDir .. "utils")

_G.uuid = function ()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and love.math.random(0, 0xf) or love.math.random(8, 0xb)
        return string.format('%x', v)
    end)
end


_G.RedisClient = Redis.connect("192.168.31.15", 6379)

RedisClient:hset("users:baw.developpement@gmail.com", "email", "baw.developpement@gmail.com")
RedisClient:hset("users:baw.developpement@gmail.com", "password", "123")
RedisClient:hset("users:baw.developpement@gmail.com", "token", "")
RedisClient:hset("characters:hello", "name", "hello")
RedisClient:hset("characters:hello", "owner", "baw.developpement@gmail.com")
RedisClient:hset("characters:yeah", "name", "yeah")
RedisClient:hset("characters:yeah", "owner", "baw.developpement@gmail.com")
RedisClient:hset("users:baw.developpement@gmail.com", "characters", Json:encode({ "yeah", "hello" }))

RedisClient:hset("worlds:nexus", "ip", "127.0.0.1")
RedisClient:hset("worlds:nexus", "port", "8082")

RedisClient:hset("worlds:realm_pvp", "ip", "127.0.0.1")
RedisClient:hset("worlds:realm_pvp", "port", "8083")

RedisClient:hset("worlds:realm_pve", "ip", "127.0.0.1")
RedisClient:hset("worlds:realm_pve", "port", "8084")

RedisClient:hset("worlds:guild", "ip", "127.0.0.1")
RedisClient:hset("worlds:guild", "port", "8085")

local users = RedisClient:hget("users:baw.developpement@gmail.com", "characters")
local characters = RedisClient:hgetall("characters:yeah")
function isFound ( t )
    local l = 0

    for k, v in pairs(t) do
        l = l + 1
    end

    return l > 0
end
print(isFound(characters))

TcpServer.handshake = "00000"

TcpServer:listen(8080)

TcpServer.callbacks.recv = function (data, clientid)
    local packet = bitser.loads(data)
    print(packet.id)
    if packet.id == "connect_with_password" then
        local user = RedisClient:hgetall("users:"..packet.data.email)
    
        local userFound = isFound(user)

        if userFound ~= false then
            if user.email == packet.data.email then
                if  user.password == packet.data.password then
                    if user.token ~= "" then
                        TcpServer:send(bitser.dumps({
                            id = "connection",
                            data = {
                                type = "success",
                                payload = {
                                    email = user.email,
                                    token = user.token
                                }
                            }
                        }), clientid)
                    else
                        local newToken = uuid()
                        RedisClient:hset("users:"..user.email, "token", newToken)
                        TcpServer:send(bitser.dumps({
                            id = "connection",
                            data = {
                                type = "success",
                                payload = {
                                    email = user.email,
                                    token = newToken
                                }
                            }
                        }), clientid)
                    end
                else
                    TcpServer:send(bitser.dumps({
                        id = "connection",
                        data = {
                            type = "error",
                            payload = "invalid_password"
                        }
                    }), clientid)
                end
            end
        end
    elseif packet.id == "create_character" then
        print("token", packet.data.token)
        print("email", packet.data.email)
        print("characterName", packet.data.characterName)
        local character = _G.RedisClient:hgetall("characters:"..packet.data.characterName)
        -- Character already exist ?
            -- YES : Send character data
            -- NO : Create character
        if isFound(character) then
            TcpServer:send(_G.bitser.dumps({
                id = "create_character",
                data = {
                    type = "error",
                    payload = "character_with_same_name_already_exist"
                }
            }), clientid)
        else
            local newCharacter = {
                name = packet.data.characterName,
                clan = packet.data.clan or "",
                force = 1,
                intelligence = 1,
                speed = 1,
                agility = 1,
                life = 100,
                wallet = 100
            }
            _G.RedisClient:hset("characters:"..packet.data.characterName, "name", packet.data.characterName)
            _G.RedisClient:hset("characters:"..packet.data.characterName, "owner", packet.data.email)
            _G.RedisClient:hset("characters:"..packet.data.characterName, "data", Json:encode(newCharacter))
            local characters = Json:decode(_G.RedisClient:hget("users:"..packet.data.email, "characters"))
            table.insert(characters, #characters + 1, packet.data.characterName)
            _G.RedisClient:hset("users:"..packet.data.email, "characters", Json:encode(characters))
            TcpServer:send(_G.bitser.dumps({
                id = "create_character",
                data = {
                    type = "success",
                    payload = newCharacter
                }
            }), clientid)
        end
    elseif packet.id == "list_character" then
        local email = packet.data.email
        if email then
            local characters = _G.RedisClient:hget("users:"..email, "characters")

            local charactersTable = {}
            local decoded = Json:decode(characters)
            for i, v in ipairs(decoded) do
                local targetCharacter = _G.RedisClient:hget("characters:"..v, "data")

                local data = Json:decode(targetCharacter)
                charactersTable[i] = data
            end
            
            TcpServer:send(_G.bitser.dumps({
                id = "list_character",
                data = {
                    type = "success",
                    payload = charactersTable
                }
            }), clientid)
        end
    elseif packet.id == "play" then
        local lastWorld = _G.RedisClient:hget("characters:"..packet.data.characterName, "lastWorld")
        local worldInfo = _G.RedisClient:hgetall("worlds:"..lastWorld)

            
        TcpServer:send(_G.bitser.dumps({
            id = "play",
            data = {
                type = "success",
                payload = {
                    characterName = packet.data.characterName,
                    world = {
                        name = lastWorld,
                        ip = worldInfo.ip,
                        port = worldInfo.port
                    }
                }
            }
        }), clientid)

    end
end

TcpServer.callbacks.connect = function (clientid)
    print("[TCP][".. tostring(clientid) .. "]: connected")
    TcpServer:send(bitser.dumps({
        id = "request_identity"
    }), clientid)
end

TcpServer.callbacks.disconnect = function (clientid)
    print("[TCP][".. tostring(clientid) .. "]: disconnected")
end

function love.update(dt)
    TcpServer:update(dt)
end