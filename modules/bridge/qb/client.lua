local function getGradeLevel(grade)
    if type(grade) == 'table' then
        return grade.level or grade.grade or 0
    end

    return grade or 0
end

local function getGroups(data)
    local groups = {}

    if data.job?.name then
        groups[data.job.name] = getGradeLevel(data.job.grade)
    end

    if data.gang?.name then
        groups[data.gang.name] = getGradeLevel(data.gang.grade)
    end

    return groups
end

RegisterNetEvent('QBCore:Client:OnPlayerUnload', client.onLogout)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    PlayerData.job = job
    client.setPlayerData('groups', getGroups(PlayerData))
end)

RegisterNetEvent('QBCore:Client:OnGangUpdate', function(gang)
    PlayerData.gang = gang
    client.setPlayerData('groups', getGroups(PlayerData))
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    if not PlayerData.loaded then return end

    PlayerData.job = data.job
    PlayerData.gang = data.gang
    PlayerData.dead = data.metadata and data.metadata.isdead or false

    client.setPlayerData('groups', getGroups(PlayerData))
end)

---@diagnostic disable-next-line: duplicate-set-field
function client.setPlayerStatus(values)
    local playerState = LocalPlayer.state

    for name, value in pairs(values) do
        if value > 100 or value < -100 then
            value = value * 0.0001
        end

        playerState:set(name, lib.math.clamp(playerState[name] + value, 0, 100), true)
    end
end
