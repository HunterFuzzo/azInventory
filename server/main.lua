-- ============================================================
-- ESX Inventory – Server Script (Version Unifiée : Table Users)
-- ============================================================

ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

local playerCustomData = {} -- Mémoire vive : [identifier] = { container = {}, shortkeys = {} }
local isProcessing = {}     -- Mutex anti-spam

-- ─── Weight Helpers ───────────────────────────────────────
local ItemWeights = {
    bread          = 0.3,
    water          = 0.5,
    VEHICLE_DELUXO = 2.0,
    -- Ajoute tes autres items ici...
}

function GetItemWeight(itemName)
    return ItemWeights[itemName] or 0.1
end

function CanCarryWeight(xPlayer, additionalWeight)
    local currentWeight = 0
    for _, item in ipairs(xPlayer.getInventory()) do
        if item.count > 0 then
            currentWeight = currentWeight + (GetItemWeight(item.name) * item.count)
        end
    end
    return (currentWeight + additionalWeight) <= (Config.MaxWeight or 30.0)
end

-- ─── DB & Persistence (Centralisé sur table USERS) ──────────

-- Chargement à la connexion
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(source, xPlayer)
    MySQL.query('SELECT protected, inventory_shortkeys FROM users WHERE identifier = ?', {
        xPlayer.identifier
    }, function(result)
        local container = {}
        local shortkeys = {false, false, false, false, false, false}

        if result and result[1] then
            if result[1].protected then container = json.decode(result[1].protected) or {} end
            if result[1].inventory_shortkeys then shortkeys = json.decode(result[1].inventory_shortkeys) or shortkeys end
        end

        playerCustomData[xPlayer.identifier] = {
            container = container,
            shortkeys = shortkeys
        }

        TriggerClientEvent('az_inventory:loadCustomData', source, container, shortkeys)
    end)
end)

-- Initialisation au Start du script (si déjà connecté)
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Citizen.Wait(1000)
    local players = ESX.GetPlayers()
    for i=1, #players do
        local xPlayer = ESX.GetPlayerFromId(players[i])
        if xPlayer then
            MySQL.query('SELECT protected, inventory_shortkeys FROM users WHERE identifier = ?', {xPlayer.identifier}, function(result)
                local container = {}
                local shortkeys = {false, false, false, false, false, false}
                if result and result[1] then
                    container = json.decode(result[1].protected) or {}
                    shortkeys = json.decode(result[1].inventory_shortkeys) or shortkeys
                end
                playerCustomData[xPlayer.identifier] = { container = container, shortkeys = shortkeys }
                TriggerClientEvent('az_inventory:loadCustomData', players[i], container, shortkeys)
            end)
        end
    end
end)

-- ─── Callbacks Mouvements ──────────────────────────────────

local function lockPlayer(source)
    if isProcessing[source] then return false end
    isProcessing[source] = true
    return true
end

local function unlockPlayer(source)
    isProcessing[source] = nil
end

ESX.RegisterServerCallback('az_inventory:moveItem', function(source, cb, fromZone, toZone, itemName, count)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not playerCustomData[xPlayer.identifier] then return cb(false) end
    if not lockPlayer(source) then return cb(false) end

    local customData = playerCustomData[xPlayer.identifier]
    count = count or 1

    -- BAG (ESX) -> PROTECTED (Users.protected)
    if fromZone == 'bag' and toZone == 'container' then
        local item = xPlayer.getInventoryItem(itemName)
        if item and item.count >= count then
            xPlayer.removeInventoryItem(itemName, count)
            
            local found = false
            for _, cItem in ipairs(customData.container) do
                if cItem.name == itemName then
                    cItem.count = cItem.count + count
                    found = true; break
                end
            end
            if not found then
                table.insert(customData.container, {name = itemName, label = item.label, count = count, weight = GetItemWeight(itemName)})
            end

            MySQL.update('UPDATE users SET protected = ? WHERE identifier = ?', {json.encode(customData.container), xPlayer.identifier})
            unlockPlayer(source)
            cb(true, customData.container)
        else
            unlockPlayer(source)
            cb(false)
        end

    -- PROTECTED (Users.protected) -> BAG (ESX)
    elseif fromZone == 'container' and toZone == 'bag' then
        local foundIndex = nil
        for i, item in ipairs(customData.container) do
            if item.name == itemName and item.count >= count then
                foundIndex = i; break
            end
        end

        if foundIndex then
            if CanCarryWeight(xPlayer, GetItemWeight(itemName) * count) then
                local item = customData.container[foundIndex]
                item.count = item.count - count
                if item.count <= 0 then table.remove(customData.container, foundIndex) end

                xPlayer.addInventoryItem(itemName, count)
                MySQL.update('UPDATE users SET protected = ? WHERE identifier = ?', {json.encode(customData.container), xPlayer.identifier})
                unlockPlayer(source)
                cb(true, customData.container)
            else
                xPlayer.showNotification('~r~Ton sac est trop lourd !')
                unlockPlayer(source)
                cb(false)
            end
        else
            unlockPlayer(source)
            cb(false)
        end
    else
        unlockPlayer(source)
        cb(true)
    end
end)

-- ─── Raccourcis & Actions ──────────────────────────────────

RegisterNetEvent('az_inventory:setShortkey')
AddEventHandler('az_inventory:setShortkey', function(slot, itemName)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer and playerCustomData[xPlayer.identifier] then
        local shortkeys = playerCustomData[xPlayer.identifier].shortkeys
        shortkeys[slot + 1] = itemName or false
        MySQL.update('UPDATE users SET inventory_shortkeys = ? WHERE identifier = ?', {json.encode(shortkeys), xPlayer.identifier})
    end
end)

-- Drop, Use, Pickup Bag (Gardés tels quels mais avec lockPlayer corrigé)
-- ... (Ici tu peux garder tes fonctions dropItem, giveItem, pickupBag que tu avais déjà)

-- À ajouter dans ton script d'INVENTAIRE (pas admin)
AddEventHandler('esx:onAddInventoryItem', function(source, item, count)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        -- On prévient le menu que le sac (My Bag) a changé
        TriggerClientEvent('az_inventory:updateInventory', source, xPlayer.getInventory())
    end
end)

-- Table pour stocker les sacs au sol côté serveur
local groundBags = {}

RegisterNetEvent('esx:onPlayerDeath')
AddEventHandler('esx:onPlayerDeath', function(data)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end

    local coords = GetEntityCoords(GetPlayerPed(_source))
    local inventory = xPlayer.getInventory()
    local itemsToDrop = {}

    print(("^3[INVENTORY] Début de la procédure de mort pour %s^7"):format(xPlayer.getName()))

    -- 1. On trie ce qui tombe au sol (Uniquement ce qui est dans le 'Bag' ESX)
    for i=1, #inventory do
        local item = inventory[i]
        if item and item.count > 0 then
            -- On prépare la liste pour le sac au sol
            table.insert(itemsToDrop, {
                name = item.name,
                count = item.count,
                label = item.label or item.name
            })
            
            -- 2. On vide le sac ESX (C'est ce qui sera perdu)
            xPlayer.removeInventoryItem(item.name, item.count)
        end
    end

    -- 3. On ne touche PAS à playerCustomData[xPlayer.identifier].container (Le Protected)
    -- Donc les items en Protected resteront sur le joueur au revive.

    -- 4. Création du sac au sol si le joueur avait des choses
    if #itemsToDrop > 0 then
        local bagId = math.random(1000, 9999)
        groundBags[bagId] = {
            items = itemsToDrop,
            coords = coords,
            owner = xPlayer.identifier
        }
        
        -- On demande à tous les clients d'afficher le sac
        TriggerClientEvent('az_inventory:spawnBagProp', -1, bagId, coords)
        
        print(("^2[INVENTORY] Sac n°%s généré avec %d items au sol.^7"):format(bagId, #itemsToDrop))
    else
        print("^1[INVENTORY] Le joueur est mort mais n'avait rien dans son sac.^7")
    end
end)

ESX.RegisterServerCallback('az_inventory:pickupBag', function(source, cb, bagId)
    local xPlayer = ESX.GetPlayerFromId(source)
    local bag = groundBags[bagId]

    if bag then
        local totalWeight = 0
        for _, item in ipairs(bag.items) do
            totalWeight = totalWeight + (GetItemWeight(item.name) * item.count)
        end

        -- Vérification du poids avant de ramasser
        if CanCarryWeight(xPlayer, totalWeight) then
            for _, item in ipairs(bag.items) do
                xPlayer.addInventoryItem(item.name, item.count)
            end

            -- On supprime le sac du serveur et des clients
            groundBags[bagId] = nil
            TriggerClientEvent('az_inventory:removeBagProp', -1, bagId)
            
            xPlayer.showNotification("~g~Vous avez récupéré le contenu du sac.")
            cb(true)
        else
            xPlayer.showNotification("~r~Votre inventaire est trop lourd pour ramasser ce sac.")
            cb(false)
        end
    else
        cb(false)
    end
end)