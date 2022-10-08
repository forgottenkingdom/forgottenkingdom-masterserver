return {
    getEmailByToken = function (token)
        local users = _G.RedisClient:hgetall("users")
        local email = nil
        for k, v in pairs(users) do
            local user = _G.Json:decode(v)
            if user.token == token then
                email = user.email
            end
        end

        return email
    end
}