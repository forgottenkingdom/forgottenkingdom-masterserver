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

print("HEllo")


_G.RedisClient = Redis.connect("127.0.0.1", 6379)


print("HEllo3")

RedisClient:hset("users:baw.developpement@gmail.com", "email", "baw.developpement@gmail.com")
RedisClient:hset("users:baw.developpement@gmail.com", "password", "123")
RedisClient:hset("users:baw.developpement@gmail.com", "token", "")
if (RedisClient:sismember("users", "baw.developpement@gmail.com") == false) then
    RedisClient:sadd("users", "baw.developpement@gmail.com")
end
RedisClient:hset("character:hello", "name", "hello")
RedisClient:hset("character:hello", "owner", "baw.developpement@gmail.com")
RedisClient:hset("character:yeah", "name", "yeah")
RedisClient:hset("character:yeah", "owner", "baw.developpement@gmail.com")
if (RedisClient:sismember("characters:baw.developpement@gmail.com", "character:hello") == false) then
    RedisClient:sadd("characters:baw.developpement@gmail.com", "character:hello")
end
if (RedisClient:sismember("characters:baw.developpement@gmail.com", "character:yeah") == false) then
    RedisClient:sadd("characters:baw.developpement@gmail.com", "character:yeah")
end
-- Setup worlds
RedisClient:hset("world:nexus", "ip", "127.0.0.1")
RedisClient:hset("world:nexus", "port", "8082")

RedisClient:hset("world:realm_pvp", "ip", "127.0.0.1")
RedisClient:hset("world:realm_pvp", "port", "8083")

RedisClient:hset("world:realm_pve", "ip", "127.0.0.1")
RedisClient:hset("world:realm_pve", "port", "8084")

RedisClient:hset("world:guild", "ip", "127.0.0.1")
RedisClient:hset("world:guild", "port", "8085")
if (RedisClient:sismember("worlds", "world:nexus") == false) then
    RedisClient:sadd("worlds", "world:nexus")
end
if (RedisClient:sismember("worlds", "world:realm_pvp") == false) then
    RedisClient:sadd("worlds", "world:realm_pvp")
end
if (RedisClient:sismember("worlds", "world:realm_pve") == false) then
    RedisClient:sadd("worlds", "world:realm_pve")
end
if (RedisClient:sismember("worlds", "world:realm_guild") == false) then
    RedisClient:sadd("worlds", "world:realm_guild")
end

local users = RedisClient:hget("users:baw.developpement@gmail.com", "characters")
local characters = RedisClient:smembers("characters:baw.developpement@gmail.com")
function isFound ( t )
    local l = 0

    for k, v in pairs(t) do
        l = l + 1
    end

    return l > 0
end
print(#characters)
print(isFound(characters))

TcpServer.handshake = "00000"

TcpServer:listen(8080)

TcpServer.callbacks.recv = function (data, clientid)
    local packet = bitser.loads(data)
    print(packet.id)
    if packet.id == "connect_with_password" then
        local user = RedisClient:hgetall("users:"..packet.data.email)
    
        local userFound = RedisClient:sismember("users", packet.data.email)

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
            -- YES : Send error
            -- NO : Create character
        if _G.RedisClient:sismember("characters:"..packet.data.email, "character:"..packet.data.characterName) then
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
            _G.RedisClient:hset("character:"..packet.data.characterName, "name", packet.data.characterName)
            _G.RedisClient:hset("character:"..packet.data.characterName, "owner", packet.data.email)
            _G.RedisClient:hset("character:"..packet.data.characterName, "data", Json:encode(newCharacter))
            _G.RedisClient.sadd("characters:"..packet.data.email, "character:"..packet.data.characterName)
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
            local characters = _G.RedisClient:smembers("characters:"..email)

            local charactersTable = {}

            for index, characterName in ipairs(characters) do
                local character = _G.RedisClient:hgetall(characterName);

                charactersTable[index] = character;
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
        local lastWorld = _G.RedisClient:hget("character:"..packet.data.characterName, "lastWorld")
        print(lastWorld)
        if (lastWorld ~= nil) then
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
        else
            local worlds = _G.RedisClient:smembers("worlds")
            print("worlds")
            print(worlds)
            print(#worlds)
            for index, worldName in ipairs(worlds) do
                local world = _G.RedisClient:hgetall(worldName);

                if world.default == "true" then
                    TcpServer:send(_G.bitser.dumps({
                        id = "play",
                        data = {
                            type = "success",
                            payload = {
                                characterName = packet.data.characterName,
                                world = {
                                    name = worldName,
                                    ip = world.ip,
                                    port = world.port
                                }
                            }
                        }
                    }), clientid)
                    
                end
            end
        end
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