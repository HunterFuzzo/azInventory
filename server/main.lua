-- ============================================================
-- ESX Inventory – Server Script
-- Validates item movements, manages weight, handles actions
-- ============================================================

ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- ─── Config ───────────────────────────────────────────────
local MAX_WEIGHT = 1000 -- kg

-- ─── Weight Helpers ───────────────────────────────────────

-- Default item weights (can be overridden by database)
local ItemWeights = {
    bread          = 0.3,
    water          = 0.5,
    phone          = 0.2,
    bandage        = 0.1,
    weapon_pistol  = 2.5,
    lockpick       = 0.1,
    armor          = 5.0,
    medkit         = 1.5,
    radio          = 0.8,
    flashlight     = 0.4,
    toolkit        = 2.0,
    rope           = 1.0,
    money_bag      = 3.0,
    gold_bar       = 5.0,
    diamond        = 0.1,
}

function GetItemWeight(itemName)
    return ItemWeights[itemName] or 0.1
end

function GetPlayerCurrentWeight(xPlayer)
    local totalWeight = 0.0
    local inventory = xPlayer.getInventory()

    for _, item in ipairs(inventory) do
        if item.count > 0 then
            local w = GetItemWeight(item.name)
            totalWeight = totalWeight + (w * item.count)
        end
    end

    return totalWeight
end

function CanCarryWeight(xPlayer, additionalWeight)
    local current = GetPlayerCurrentWeight(xPlayer)
    return (current + additionalWeight) <= MAX_WEIGHT
end

-- ─── DB & Persistence ───────────────────────────────────────
local playerCustomData = {}

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer, isNew)
    MySQL.query('SELECT container, shortkeys FROM user_inventory_custom WHERE identifier = ?', {xPlayer.identifier}, function(result)
        local container = {}
        local shortkeys = {}
        if result and result[1] then
            container = json.decode(result[1].container) or {}
            shortkeys = json.decode(result[1].shortkeys) or {}
        else
            MySQL.insert('INSERT INTO user_inventory_custom (identifier, container, shortkeys) VALUES (?, ?, ?)', {xPlayer.identifier, '[]', '[]'})
        end
        playerCustomData[xPlayer.identifier] = { container = container, shortkeys = shortkeys }
        TriggerClientEvent('esx_inventory:loadCustomData', playerId, container, shortkeys)
    end)
end)

AddEventHandler('esx:playerDropped', function(playerId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if xPlayer then
        -- Force sauvegarde en cas de déconnexion brutale
        if playerCustomData[xPlayer.identifier] then
            MySQL.update('UPDATE user_inventory_custom SET container = ?, shortkeys = ? WHERE identifier = ?', {
                json.encode(playerCustomData[xPlayer.identifier].container),
                json.encode(playerCustomData[xPlayer.identifier].shortkeys),
                xPlayer.identifier
            })
            playerCustomData[xPlayer.identifier] = nil
        end
        -- Libération du verrou en cas de déconnexion pendant une transaction
        isProcessing[playerId] = nil
    end
end)

-- ─── Server Callbacks ─────────────────────────────────────
-- Mutex : empêche les requêtes simultanées par joueur
local isProcessing = {}

local function lockPlayer(source)
    if isProcessing[source] then return false end
    isProcessing[source] = true
    return true
end

local function unlockPlayer(source)
    isProcessing[source] = nil
end

-- Move item between zones
ESX.RegisterServerCallback('esx_inventory:moveItem', function(source, cb, fromZone, toZone, itemName, count)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer or not playerCustomData[xPlayer.identifier] then
        cb(false)
        return
    end

    -- Anti-dupe : rejet si une transaction est déjà en cours
    if not lockPlayer(source) then
        cb(false)
        return
    end

    local customData = playerCustomData[xPlayer.identifier]
    count = count or 1 -- Default to 1 if not provided

    if fromZone == 'bag' and toZone == 'bag' then
        unlockPlayer(source)
        cb(true)
        return
    end

    if fromZone == 'container' and toZone == 'bag' then
        if not itemName then cb(true) return end
        
        -- Check if it's in container
        local found = false
        for i, item in ipairs(customData.container) do
            if item.name == itemName and item.count >= count then
                item.count = item.count - count
                if item.count <= 0 then
                    table.remove(customData.container, i)
                end
                found = true
                break
            end
        end

        if found then
            if CanCarryWeight(xPlayer, GetItemWeight(itemName) * count) then
                xPlayer.addInventoryItem(itemName, count)
                MySQL.update('UPDATE user_inventory_custom SET container = ? WHERE identifier = ?', {json.encode(customData.container), xPlayer.identifier})
                unlockPlayer(source)
                cb(true)
            else
                -- Revert if cannot carry
                local reverted = false
                for _, cItem in ipairs(customData.container) do
                    if cItem.name == itemName then
                        cItem.count = cItem.count + count
                        reverted = true
                        break
                    end
                end
                if not reverted then
                    table.insert(customData.container, {name = itemName, count = count, label = itemName, weight = GetItemWeight(itemName)})
                end
                xPlayer.showNotification('~r~Cannot carry this much weight!')
                unlockPlayer(source)
                cb(false)
            end
        else
            unlockPlayer(source)
            cb(false)
        end
        return
    end

    if fromZone == 'bag' and toZone == 'container' then
        if not itemName then cb(true) return end
        
        local item = xPlayer.getInventoryItem(itemName)
        if item and item.count >= count then
            xPlayer.removeInventoryItem(itemName, count)
            
            -- Add to container
            local found = false
            for _, cItem in ipairs(customData.container) do
                if cItem.name == itemName then
                    cItem.count = cItem.count + count
                    found = true
                    break
                end
            end
            if not found then
                table.insert(customData.container, {
                    name = itemName,
                    label = item.label,
                    count = count,
                    weight = GetItemWeight(itemName)
                })
            end
            
            MySQL.update('UPDATE user_inventory_custom SET container = ? WHERE identifier = ?', {json.encode(customData.container), xPlayer.identifier})
            unlockPlayer(source)
            cb(true)
        else
            unlockPlayer(source)
            cb(false)
        end
        return
    end

    -- Default
    unlockPlayer(source)
    cb(true)
end)

-- Set shortkey
RegisterNetEvent('esx_inventory:setShortkey')
AddEventHandler('esx_inventory:setShortkey', function(slot, itemName)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer and playerCustomData[xPlayer.identifier] then
        -- Guarantee array size 6
        local shortkeys = playerCustomData[xPlayer.identifier].shortkeys
        while #shortkeys < 6 do
            table.insert(shortkeys, false)
        end
        
        -- Store the item name or false if null
        -- Note: client slot is 0-indexed (0 to 5), Lua is 1-indexed (1 to 6)
        if itemName == nil then
            shortkeys[slot + 1] = false
        else
            shortkeys[slot + 1] = itemName
        end
        
        MySQL.update('UPDATE user_inventory_custom SET shortkeys = ? WHERE identifier = ?', {json.encode(shortkeys), xPlayer.identifier})
    end
end)

-- Use item
ESX.RegisterServerCallback('esx_inventory:useItem', function(source, cb, itemName, slot)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then
        cb(false)
        return
    end

    -- Anti-dupe : vérifier que le joueur n'est pas en train de faire autre chose
    if not lockPlayer(source) then
        cb(false)
        return
    end

    -- Le serveur vérifie lui-même la possession réelle de l'item
    local item = xPlayer.getInventoryItem(itemName)
    if item and item.count > 0 then
        xPlayer.useItem(itemName)
        unlockPlayer(source)
        cb(true)
    else
        unlockPlayer(source)
        cb(false)
    end
end)

-- Drop item
ESX.RegisterServerCallback('esx_inventory:dropItem', function(source, cb, itemName, count)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then
        cb(false)
        return
    end

    if not lockPlayer(source) then
        cb(false)
        return
    end

    -- Le serveur ignore le count du client et utilise le réel
    local item = xPlayer.getInventoryItem(itemName)
    if item and item.count >= 1 then
        local toDrop = math.min(count or 1, item.count) -- jamais plus que ce qu'il a
        xPlayer.removeInventoryItem(itemName, toDrop)
        print(('[esx_inventory] %s dropped %dx %s'):format(xPlayer.getName(), toDrop, itemName))
        unlockPlayer(source)
        cb(true)
    else
        unlockPlayer(source)
        cb(false)
    end
end)

-- Give item to nearest player
ESX.RegisterServerCallback('esx_inventory:giveItem', function(source, cb, itemName, count)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then
        cb(false)
        return
    end

    if not lockPlayer(source) then
        cb(false)
        return
    end

    -- Vérification entièrement côté serveur
    local item = xPlayer.getInventoryItem(itemName)
    if not item or item.count < 1 then
        unlockPlayer(source)
        cb(false)
        return
    end
    count = math.min(count or 1, item.count) -- jamais plus que ce qu'on possède

    -- Find nearest player
    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)
    local closestPlayer = nil
    local closestDistance = 3.0 -- Max give distance

    local players = ESX.GetPlayers()
    for _, playerId in ipairs(players) do
        if playerId ~= source then
            local targetPed = GetPlayerPed(playerId)
            local targetCoords = GetEntityCoords(targetPed)
            local dist = #(playerCoords - targetCoords)

            if dist < closestDistance then
                closestDistance = dist
                closestPlayer = playerId
            end
        end
    end

    if closestPlayer then
        local xTarget = ESX.GetPlayerFromId(closestPlayer)
        local itemWeight = GetItemWeight(itemName) * count

        if CanCarryWeight(xTarget, itemWeight) then
            xPlayer.removeInventoryItem(itemName, count)
            xTarget.addInventoryItem(itemName, count)
            print(('[esx_inventory] %s gave %dx %s to %s'):format(
                xPlayer.getName(), count, itemName, xTarget.getName()
            ))
            unlockPlayer(source)
            cb(true)
        else
            xPlayer.showNotification('~r~Target inventory is full!')
            unlockPlayer(source)
            cb(false)
        end
    else
        xPlayer.showNotification('~r~No player nearby!')
        unlockPlayer(source)
        cb(false)
    end
end)

-- ─── Vehicle Items ────────────────────────────────────────
-- Whitelist des modèles autorisés comme items
local allowedVehicleItems = { deluxo = true }

ESX.RegisterUsableItem('deluxo', function(source)
    if not lockPlayer(source) then return end

    local xPlayer = ESX.GetPlayerFromId(source)
    -- Vérification serveur : le joueur possède-t-il vraiment l'item ?
    local item = xPlayer.getInventoryItem('deluxo')
    if not item or item.count < 1 then
        unlockPlayer(source)
        return
    end

    xPlayer.removeInventoryItem('deluxo', 1)
    TriggerClientEvent('esx_inventory:spawnVehicle', source, 'deluxo')
    unlockPlayer(source)
end)

RegisterNetEvent('esx_inventory:returnVehicleItem')
AddEventHandler('esx_inventory:returnVehicleItem', function(model)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    if not lockPlayer(source) then return end

    -- Sécurité : refuser tout modèle non whitelisté (anti-injection)
    if not allowedVehicleItems[model] then
        unlockPlayer(source)
        return
    end

    xPlayer.addInventoryItem(model, 1)
    unlockPlayer(source)
end)

-- ─── Weight Info Command ──────────────────────────────────
RegisterCommand('myweight', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        local w = GetPlayerCurrentWeight(xPlayer)
        xPlayer.showNotification(('~b~Weight: %.1f / %d KG'):format(w, MAX_WEIGHT))
    end
end, false)

print('[esx_inventory] Server script loaded successfully')
