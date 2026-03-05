-- ============================================================
-- ESX Inventory – Server Script
-- Validates item movements, manages weight, handles actions
-- ============================================================

ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

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
    return (current + additionalWeight) <= Config.MaxWeight
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

-- Initialisation pour les joueurs déjà connectés lors du start/restart du script
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        Citizen.Wait(2000) -- Attente pour que ESX soit bien initialisé
        local players = ESX.GetPlayers()
        for i=1, #players do
            local xPlayer = ESX.GetPlayerFromId(players[i])
            if xPlayer then
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
                    TriggerClientEvent('esx_inventory:loadCustomData', players[i], container, shortkeys)
                end)
            end
        end
    end
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
                cb(true, customData.container)
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
            cb(true, customData.container)
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
        print(('[esx_inventory] %s tried to use %s but is locked'):format(xPlayer.getName(), itemName))
        cb(false)
        return
    end

    -- Le serveur vérifie lui-même la possession réelle de l'item
    local item = xPlayer.getInventoryItem(itemName)
    if item and item.count > 0 then
        print(('[esx_inventory] %s using item %s via esx_inventory:useItem'):format(xPlayer.getName(), itemName))
        
        -- Bypass pour les armes custom : on gère directement au lieu de dépendre du dispatch ESX
        if Config and Config.WeaponItems and Config.WeaponItems[itemName] then
            print(('[esx_inventory] Custom weapon detected in useItem bypass: %s'):format(itemName))
            TriggerClientEvent('esx_inventory:giveWeaponToPed', source, itemName, Config.WeaponItems[itemName])
            unlockPlayer(source)
            cb(true)
            return
        end

        -- Bypass pour les véhicules custom
        if Config and Config.VehicleItems and Config.VehicleItems[itemName] then
            print(('[esx_inventory] Custom vehicle detected in useItem bypass: %s'):format(itemName))
            xPlayer.removeInventoryItem(itemName, 1)
            TriggerClientEvent('esx_inventory:spawnVehicle', source, Config.VehicleItems[itemName], itemName)
            unlockPlayer(source)
            cb(true)
            return
        end

        xPlayer.useItem(itemName)
        unlockPlayer(source)
        cb(true)
    else
        print(('[esx_inventory] %s failed to use item %s (not enough count or not found)'):format(xPlayer.getName(), itemName))
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

-- ─── Vehicle & Weapon Items ───────────────────────────────
-- ─── Vehicle & Weapon Items ───────────────────────────────
-- Utilisation des véhicules configurés
if Config and Config.VehicleItems then
    for vehicleItemName, vehicleModel in pairs(Config.VehicleItems) do
        ESX.RegisterUsableItem(vehicleItemName, function(source)
            print(('[esx_inventory] Usable item triggered for vehicle: %s (source: %s)'):format(vehicleItemName, source))
            
            local xPlayer = ESX.GetPlayerFromId(source)
            -- Vérification serveur : le joueur possède-t-il vraiment l'item ?
            local item = xPlayer.getInventoryItem(vehicleItemName)
            if not item or item.count < 1 then
                print('[esx_inventory] Failed to spawn vehicle: player does not have item ' .. vehicleItemName)
                return
            end

            xPlayer.removeInventoryItem(vehicleItemName, 1)
            TriggerClientEvent('esx_inventory:spawnVehicle', source, vehicleModel, vehicleItemName)
            print('[esx_inventory] Vehicle spawned successfully: ' .. vehicleModel)
        end)
    end
end

RegisterNetEvent('esx_inventory:returnVehicleItem')
AddEventHandler('esx_inventory:returnVehicleItem', function(model)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end

    -- 1. Sécurité anti-spam (si tu utilises lockPlayer)
    if lockPlayer then 
        if not lockPlayer(_source) then return end 
    end

    -- 2. Vérification de sécurité (Whitelist du modèle)
    -- On vérifie soit dans ta table allowedVehicleItems, soit dans ta Config
    local isAllowed = false
    if allowedVehicleItems and allowedVehicleItems[model] then
        isAllowed = true
    elseif Config and Config.VehicleItems and Config.VehicleItems[model] then
        isAllowed = true
    end

    if isAllowed then
        -- 3. Gestion du poids (Optionnel mais propre)
        local itemWeight = 0
        if GetItemWeight then itemWeight = GetItemWeight(model) end

        -- On ajoute l'item
        xPlayer.addInventoryItem(model, 1)

        -- 4. Synchronisation forcée
        -- On prévient le client que son inventaire a changé pour qu'il rafraîchisse la Hotbar
        local updatedInventory = xPlayer.getInventory()
        TriggerClientEvent('esx_inventory:updateInventory', _source, updatedInventory)
        
        print(('[esx_inventory] Joueur %s a rangé son véhicule : %s'):format(xPlayer.identifier, model))
    else
        print(('[esx_inventory] Tentative de rangement de véhicule non autorisé par ID %s : %s'):format(_source, model))
    end

    -- 5. Débloquer le joueur
    if unlockPlayer then unlockPlayer(_source) end
end)

-- Weapons as items: register usable items for all WEAPON_* items
-- When used, trigger a client event to give the weapon to the ped physically
MySQL.ready(function()
    MySQL.query('SELECT name FROM items WHERE name LIKE "WEAPON_%"', {}, function(result)
        for i=1, #result do
            local weaponName = result[i].name
            ESX.RegisterUsableItem(weaponName, function(source)
                local xPlayer = ESX.GetPlayerFromId(source)
                if not xPlayer then return end

                -- Vérification serveur : le joueur possède bien l'arme en item
                local item = xPlayer.getInventoryItem(weaponName)
                if not item or item.count < 1 then
                    return
                end

                -- Donner l'arme physiquement au ped côté client
                TriggerClientEvent('esx_inventory:giveWeaponToPed', source, weaponName)
            end)
        end
    end)
end)

-- Enregistrer également les armes personnalisées (items) depuis la config (statique)
if Config and Config.WeaponItems then
    for customItemName, weaponHashName in pairs(Config.WeaponItems) do
        ESX.RegisterUsableItem(customItemName, function(source)
            local xPlayer = ESX.GetPlayerFromId(source)
            if not xPlayer then return end

            -- Vérification serveur : le joueur possède bien l'item custom
            local item = xPlayer.getInventoryItem(customItemName)
            if not item or item.count < 1 then
                print(('[esx_inventory] %s tried to use custom weapon %s but does not have it'):format(xPlayer.getName(), customItemName))
                return
            end

            -- Donner l'arme physiquement au ped côté client
            print(('[esx_inventory] Equip custom weapon: %s -> %s for %s'):format(customItemName, weaponHashName, xPlayer.getName()))
            TriggerClientEvent('esx_inventory:giveWeaponToPed', source, customItemName, weaponHashName)
        end)
    end
end

RegisterNetEvent('esx_inventory:removeWeaponFromPed')
AddEventHandler('esx_inventory:removeWeaponFromPed', function(itemName)
    -- Validation : vérifier si c'est une arme native ("WEAPON_...") ou une arme custom conf
    local isCustom = (Config and Config.WeaponItems and Config.WeaponItems[itemName])
    if not isCustom and (type(itemName) ~= 'string' or string.sub(string.upper(itemName), 1, 7) ~= 'WEAPON_') then 
        return 
    end
    TriggerClientEvent('esx_inventory:removeWeaponFromPed', source, itemName)
end)

print('[esx_inventory] Server script loaded successfully')

-- Table pour stocker les sacs au sol temporairement
local groundBags = {}

RegisterNetEvent('esx:onPlayerDeath')
AddEventHandler('esx:onPlayerDeath', function(data)
    local xPlayer = ESX.GetPlayerFromId(source)
    local coords = GetEntityCoords(GetPlayerPed(source))
    local inventory = xPlayer.getInventory()
    local itemsToDrop = {}

    -- On récupère tout ce qui est dans l'inventaire
    for i=1, #inventory do
        if inventory[i].count > 0 then
            table.insert(itemsToDrop, {
                name = inventory[i].name,
                count = inventory[i].count,
                label = inventory[i].label
            })
            -- On retire l'item du joueur
            xPlayer.removeInventoryItem(inventory[i].name, inventory[i].count)
        end
    end

    if #itemsToDrop > 0 then
        local bagId = math.random(1000, 9999)
        groundBags[bagId] = itemsToDrop
        
        -- On prévient les clients qu'un sac est apparu
        TriggerClientEvent('esx_inventory:spawnBagProp', -1, bagId, coords)
    end
end)

RegisterNetEvent('esx_inventory:pickupBag')
AddEventHandler('esx_inventory:pickupBag', function(bagId)
    local xPlayer = ESX.GetPlayerFromId(source)
    local items = groundBags[bagId]

    if items then
        local summary = "Vous avez ramassé : "
        
        for i, item in ipairs(items) do
            -- On ajoute l'item au joueur
            xPlayer.addInventoryItem(item.name, item.count)
            
            -- On construit le message de notification
            summary = summary .. "\n- " .. item.count .. "x " .. item.label
        end
        
        -- On supprime les données du serveur pour éviter le double ramassage
        groundBags[bagId] = nil
        
        -- On envoie la notification détaillée
        xPlayer.showNotification(summary)
        
        -- On ordonne à TOUS les clients de supprimer le prop visuel
        TriggerClientEvent('esx_inventory:removeBagProp', -1, bagId)
    end
end)