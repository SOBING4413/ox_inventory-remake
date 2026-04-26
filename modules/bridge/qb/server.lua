if GetResourceState('qb-core') ~= 'started' then
    return error('qb-core is not started. Ensure qb-core starts before ox_inventory.')
end

local QBCore = exports['qb-core']:GetCoreObject()
local Inventory = require 'modules.inventory.server'
local Items = require 'modules.items.server'

local function getGradeLevel(grade)
    if type(grade) == 'table' then
        return grade.level or grade.grade or 0
    end

    return grade or 0
end

local function getGroups(playerData)
    local groups = {}
    local job = playerData.job
    local gang = playerData.gang

    if job?.name then
        groups[job.name] = getGradeLevel(job.grade)
    end

    if gang?.name then
        groups[gang.name] = getGradeLevel(gang.grade)
    end

    return groups
end

local function setupPlayer(source)
    local player = QBCore.Functions.GetPlayer(source)

    if not player then return end

    local playerData = player.PlayerData
    playerData.source = source
    playerData.identifier = playerData.citizenid
    playerData.name = ('%s %s'):format(playerData.charinfo.firstname, playerData.charinfo.lastname)
    playerData.groups = getGroups(playerData)

    server.setPlayerInventory(playerData, playerData.items)
    Inventory.SetItem(source, 'money', playerData.money?.cash or 0)
end

AddEventHandler('QBCore:Server:OnPlayerLoaded', setupPlayer)
AddEventHandler('QBCore:Server:OnPlayerUnload', server.playerDropped)

AddEventHandler('QBCore:Server:OnJobUpdate', function(source, job)
    local inventory = Inventory(source)

    if not inventory then return end

    local groups = inventory.player.groups
    local oldName = inventory.player.job?.name

    if oldName then
        groups[oldName] = nil
    end

    inventory.player.job = job

    if job?.name then
        groups[job.name] = getGradeLevel(job.grade)
    end
end)

AddEventHandler('QBCore:Server:OnGangUpdate', function(source, gang)
    local inventory = Inventory(source)

    if not inventory then return end

    local groups = inventory.player.groups
    local oldName = inventory.player.gang?.name

    if oldName then
        groups[oldName] = nil
    end

    inventory.player.gang = gang

    if gang?.name then
        groups[gang.name] = getGradeLevel(gang.grade)
    end
end)

SetTimeout(500, function()
    local players = QBCore.Functions.GetQBPlayers()

    for source in pairs(players) do
        setupPlayer(source)
    end
end)


--- Takes QBCore item data and updates it to support ox_inventory.
---@diagnostic disable-next-line: duplicate-set-field
function server.convertInventory(playerId, items)
    if type(items) ~= 'table' then return end

    local returnData, totalWeight = {}, 0
    local slot = 0

    for _, itemData in pairs(items) do
        local name = itemData?.name
        local count = itemData?.count or itemData?.amount

        if name and count and count > 0 then
            local item = Items(name)

            if item then
                slot += 1
                local metadata = itemData.metadata or itemData.info or {}
                local weight = Inventory.SlotWeight(item, { count = count, metadata = metadata })
                totalWeight = totalWeight + weight

                returnData[slot] = {
                    name = item.name,
                    label = item.label,
                    weight = weight,
                    slot = itemData.slot or slot,
                    count = count,
                    description = item.description,
                    metadata = metadata,
                    stack = item.stack,
                    close = item.close,
                }
            end
        end
    end

    return returnData, totalWeight
end

function server.UseItem(source, itemName, data)
    local cb = QBCore.Functions.CanUseItem(itemName)
    return cb and cb(source, data)
end

---@diagnostic disable-next-line: duplicate-set-field
function server.setPlayerData(player)
    return {
        source = player.source,
        name = ('%s %s'):format(player.charinfo.firstname, player.charinfo.lastname),
        groups = getGroups(player),
        sex = player.charinfo.gender,
        dateofbirth = player.charinfo.birthdate,
    }
end

---@diagnostic disable-next-line: duplicate-set-field
function server.syncInventory(inv)
    local accounts = Inventory.GetAccountItemCounts(inv)

    if not accounts then return end

    local player = QBCore.Functions.GetPlayer(inv.id)

    if not player then return end

    player.Functions.SetPlayerData('items', inv.items)

    for account, amount in pairs(accounts) do
        account = account == 'money' and 'cash' or account

        if player.PlayerData.money[account] ~= amount then
            player.Functions.SetMoney(account, amount, ('Sync %s with inventory'):format(account))
        end
    end
end

---@diagnostic disable-next-line: duplicate-set-field
function server.hasLicense(inv, license)
    local player = QBCore.Functions.GetPlayer(inv.id)
    return player and player.PlayerData.metadata.licences and player.PlayerData.metadata.licences[license]
end

---@diagnostic disable-next-line: duplicate-set-field
function server.buyLicense(inv, license)
    local player = QBCore.Functions.GetPlayer(inv.id)

    if not player then return end

    local licences = player.PlayerData.metadata.licences or {}

    if licences[license.name] then
        return false, 'already_have'
    elseif Inventory.GetItem(inv, 'money', false, true) < license.price then
        return false, 'can_not_afford'
    end

    Inventory.RemoveItem(inv, 'money', license.price)
    licences[license.name] = true
    player.Functions.SetMetaData('licences', licences)

    return true, 'have_purchased'
end

---@diagnostic disable-next-line: duplicate-set-field
function server.isPlayerBoss(playerId, group)
    local player = QBCore.Functions.GetPlayer(playerId)

    if not player then return end

    local job = player.PlayerData.job
    local gang = player.PlayerData.gang

    return (job?.name == group and job.isboss) or (gang?.name == group and gang.isboss)
end

---@param entityId number
---@return number | string
---@diagnostic disable-next-line: duplicate-set-field
function server.getOwnedVehicleId(entityId)
    return string.strtrim(GetVehicleNumberPlateText(entityId))
end
