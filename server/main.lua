-- ============================================================
-- ESX Inventory – Server Script (Version Unifiée : Table Users)
-- ============================================================

ESX = exports['es_extended']:getSharedObject()

local playerCustomData = {} -- Mémoire vive : [identifier] = { container = {}, stash = {}, shortkeys = {} }
local isProcessing = {}     -- Mutex anti-spam

-- ─── Weight Helpers ───────────────────────────────────────
local ItemWeights = {} -- Populated from DB on resource start

local ItemRarity = {
    -- [NOM DE L'ITEM] = COLOR_INDEX (6: Rouge, 18: Vert, 190: Jaune, 2: Bleu, 140: Noir)

    ['WEAPON_HEAVYSNIPER_MK2'] = 190,
    ['WEAPON_GRENADALAUNCHER'] = 190,
    ['VEHICLE_DELUXO'] = 190,

    ['EQUIPMENT_KEVLAR'] = 6,
    ['CONSUMABLE_MEDKIT'] = 2,
    
    ['default'] = 140 
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
    return (currentWeight + additionalWeight) <= Config.MaxWeightBag
end

function CanContainerCarryWeight(containerItems, additionalWeight)
    local currentWeight = 0
    for _, item in ipairs(containerItems) do
        -- On calcule le poids actuel de ce qu'il y a déjà dans le coffre
        currentWeight = currentWeight + (GetItemWeight(item.name) * (item.count or 1))
    end
    -- LA VRAIE LIMITE EST ICI : 30.0 (doit être la même que dans ton JS)
    return (currentWeight + additionalWeight) <= Config.MaxWeightContainer
end

-- ─── Full-Data Inventory Helpers ──────────────────────────────
-- Transforms raw ESX inventory into the same rich format as protected container
function GetFullInventory(xPlayer)
    local items = xPlayer.getInventory()
    local fullInventory = {}

    for _, item in ipairs(items) do
        if item.count > 0 then
            table.insert(fullInventory, {
                name   = item.name,
                label  = item.label,
                count  = item.count,
                weight = GetItemWeight(item.name)
            })
        end
    end
    return fullInventory
end

function SyncPlayerInventory(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not playerCustomData[xPlayer.identifier] then return end

    local fullBag = GetFullInventory(xPlayer)
    local protected = playerCustomData[xPlayer.identifier].container
    local stash = playerCustomData[xPlayer.identifier].stash

    TriggerClientEvent('az_inventory:updateInventory', source, fullBag, protected, stash)
end

-- ─── DB & Persistence (Centralisé sur table USERS) ────────────

-- Shared loader — used by both esx:playerLoaded and onResourceStart
function LoadPlayerCustomData(xPlayer, targetSource)
    MySQL.query('SELECT protected, inventory_shortkeys, container FROM users WHERE identifier = ?', {
        xPlayer.identifier
    }, function(result)
        local container = {}
        local stash = {}
        local shortkeys = {false, false, false, false, false, false}

        if result and result[1] then
            if result[1].protected then container = json.decode(result[1].protected) or {} end
            if result[1].container then stash = json.decode(result[1].container) or {} end
            if result[1].inventory_shortkeys then shortkeys = json.decode(result[1].inventory_shortkeys) or shortkeys end
        end

        playerCustomData[xPlayer.identifier] = {
            container = container,
            stash = stash,
            shortkeys = shortkeys
        }

        local fullBag = GetFullInventory(xPlayer)
        TriggerClientEvent('az_inventory:loadCustomData', targetSource, container, shortkeys, fullBag, stash)
    end)
end

-- Chargement à la connexion
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(source, xPlayer)
    LoadPlayerCustomData(xPlayer, source)
end)

-- Initialisation au Start du script (si déjà connecté)
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Citizen.Wait(1000)

    -- Load item weights from DB once
    MySQL.query('SELECT name, weight FROM items', {}, function(result)
        if result then
            for _, row in ipairs(result) do
                ItemWeights[row.name] = tonumber(row.weight) or 0.1
            end
            print(('[az_inventory] Loaded %d item weights from DB'):format(#result))
        end
    end)

    -- Reload custom data for already-connected players
    local players = ESX.GetPlayers()
    for i = 1, #players do
        local xPlayer = ESX.GetPlayerFromId(players[i])
        if xPlayer then
            LoadPlayerCustomData(xPlayer, players[i])
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

ESX.RegisterServerCallback('az_inventory:moveItem', function(source, cb, fromZone, toZone, itemName, count, containerType)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not playerCustomData[xPlayer.identifier] then return cb(false) end
    if not lockPlayer(source) then return cb(false) end

    local customData = playerCustomData[xPlayer.identifier]
    count = count or 1

    print("[DEBUG az_inventory:moveItem] Player: " .. xPlayer.identifier .. " | fromZone: " .. tostring(fromZone) .. " | toZone: " .. tostring(toZone) .. " | itemName: " .. tostring(itemName) .. " | count: " .. tostring(count) .. " | containerType: " .. tostring(containerType))
    
    local targetContainer = containerType == 'stash' and customData.stash or customData.container
    local dbColumn = containerType == 'stash' and 'container' or 'protected'

    print("[DEBUG] Using dbColumn: " .. tostring(dbColumn) .. " with targetContainer count: " .. tostring(#targetContainer))

    -- BAG (ESX) -> CONTAINER/STASH
    if fromZone == 'bag' and toZone == 'container' then
        -- Handle weight limit check for protected container only.
        -- We removed CanContainerCarryWeight here entirely because it was buggy before.
        -- Ideally, we'd calculate weight if it's 'protected', but since we just
        -- add the item and then check 'limit' client side or check it here:
        if containerType == 'protected' then
            if not CanContainerCarryWeight(targetContainer, GetItemWeight(itemName) * count) then
                TriggerClientEvent('az_notify:showNotification', source, '~r~Le conteneur protégé est plein !')
                unlockPlayer(source)
                return cb(false)
            end
        end

        local item = xPlayer.getInventoryItem(itemName)
        if item and item.count >= count then
            xPlayer.removeInventoryItem(itemName, count)
            
            local found = false
            for _, cItem in ipairs(targetContainer) do
                if cItem.name == itemName then
                    cItem.count = cItem.count + count
                    found = true; break
                end
            end
            if not found then
                table.insert(targetContainer, {name = itemName, label = item.label, count = count, weight = GetItemWeight(itemName)})
            end

            MySQL.update('UPDATE users SET ' .. dbColumn .. ' = ? WHERE identifier = ?', {json.encode(targetContainer), xPlayer.identifier})
            unlockPlayer(source)
            SyncPlayerInventory(source)
            cb(true, targetContainer)
        else
            unlockPlayer(source)
            cb(false)
        end

    -- CONTAINER/STASH -> BAG (ESX)
    elseif fromZone == 'container' and toZone == 'bag' then
        local foundIndex = nil
        for i, item in ipairs(targetContainer) do
            if item.name == itemName and item.count >= count then
                foundIndex = i; break
            end
        end

        if foundIndex then
            if CanCarryWeight(xPlayer, GetItemWeight(itemName) * count) then
                local item = targetContainer[foundIndex]
                item.count = item.count - count
                if item.count <= 0 then table.remove(targetContainer, foundIndex) end

                xPlayer.addInventoryItem(itemName, count)
                MySQL.update('UPDATE users SET ' .. dbColumn .. ' = ? WHERE identifier = ?', {json.encode(targetContainer), xPlayer.identifier})
                unlockPlayer(source)
                SyncPlayerInventory(source)
                cb(true, targetContainer)
            else
                TriggerClientEvent('az_notify:showNotification', source, '~r~Ton sac est trop lourd !')
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

-- Sync le client quand ESX ajoute un item au bag
AddEventHandler('esx:onAddInventoryItem', function(source, item, count)
    SyncPlayerInventory(source)
end)

local groundBags = {}

RegisterNetEvent('az_inventory:dropBagOnDeath')
AddEventHandler('az_inventory:dropBagOnDeath', function(playerId)
    local _source = playerId or source
    local xPlayer = ESX.GetPlayerFromId(_source)

    if not xPlayer then 
        return 
    end

    local ped = GetPlayerPed(_source)
    local coords = GetEntityCoords(ped)

    local inventory = xPlayer.getInventory()
    local itemsToDrop = {}

    for i=1, #inventory do
        local item = inventory[i]
        if item and item.count > 0 then
            table.insert(itemsToDrop, {
                name = item.name,
                count = item.count,
                label = item.label or item.name
            })
            
            -- Suppression de l'item
            xPlayer.removeInventoryItem(item.name, item.count)
        end
    end

    if #itemsToDrop > 0 then
        local bagId = math.random(1000, 9999) .. "_" .. os.time()
    
        groundBags[bagId] = {
            items = itemsToDrop,
            coords = coords,
            owner = xPlayer.identifier
        }

        TriggerClientEvent('az_inventory:spawnBagProp', -1, bagId, coords)
        SyncPlayerInventory(_source)
    end
end)

ESX.RegisterServerCallback('az_inventory:pickupBag', function(source, cb, bagId)
    -- On fixe la source immédiatement
    local _source = source 
    local xPlayer = ESX.GetPlayerFromId(_source)
    local bag = groundBags[bagId]

    if bag and xPlayer then
        -- Calcul du poids total du sac
        local totalWeight = 0
        for _, item in ipairs(bag.items) do
            totalWeight = totalWeight + (GetItemWeight(item.name) * item.count)
        end

        -- Vérification si le joueur peut porter le poids
        if CanCarryWeight(xPlayer, totalWeight) then
            -- 1. On supprime le sac du monde immédiatement (Sécurité Anti-Dupli)
            groundBags[bagId] = nil
            TriggerClientEvent('az_inventory:removeBagProp', -1, bagId)

            -- 2. On distribue les items et on envoie les notifs colorées
            for _, item in ipairs(bag.items) do
                xPlayer.addInventoryItem(item.name, item.count)

                -- On récupère la couleur dans le dictionnaire
                local rarityColor = ItemRarity[item.name] or ItemRarity['default']
                print(item.name, rarityColor)
                local label = item.label or item.name
                
                -- Notification personnalisée par item
                TriggerClientEvent('az_notify:showNotification', _source, "~g~" .. item.count .. "x ~s~" .. label, rarityColor)
                
                -- Petit délai optionnel si le joueur ramasse beaucoup d'items d'un coup
                Citizen.Wait(100)
            end

            SyncPlayerInventory(_source)
            cb(true)
        else
            -- Notification d'erreur de poids (Rouge)
            TriggerClientEvent('az_notify:showNotification', _source, "~r~Votre inventaire est trop lourd !", 6)
            cb(false)
        end
    else
        -- Le sac n'existe plus ou joueur non trouvé
        cb(false)
    end
end)

ESX.RegisterServerCallback('az_inventory:useItem', function(source, cb, itemName, slot)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then 
        print("[az_inventory] Erreur : Joueur introuvable pour la source " .. tostring(source))
        cb(false) 
        return 
    end

    print("[az_inventory] Tentative d'utilisation de l'item : " .. tostring(itemName))

    local item = xPlayer.getInventoryItem(itemName)
    if item and item.count > 0 then

        -- --- 1. LOGIQUE Gilet ---
        -- Dans ton callback az_inventory:useItem :
        if itemName == nil then 
            print("^1[az_inventory] ERREUR : Le client a envoyé un item vide (nil) !^7")
            cb(false) 
            return 
        end

        -- On s'assure que c'est bien du texte
        local name = tostring(itemName)
        print("[az_inventory] Tentative d'utilisation de : " .. name)

        -- DETECTION DES CONSOMMABLES (Correction du string.find)
        if string.find(name, "CONSUMABLE") or string.find(name, "EQUIPMENT") then
            print("^2[az_inventory] Item reconnu ! Envoi vers le client.^7")
            TriggerClientEvent('az_inventory:useConsumable', source, name)
            cb(true)
            return
        end
    
        -- --- 2. LOGIQUE VÉHICULE (AJOUTÉE) ---
        if Config and Config.VehicleItems and Config.VehicleItems[itemName] then
            local vehicleModel = Config.VehicleItems[itemName]
            print("[az_inventory] Véhicule détecté ! Modèle : " .. tostring(vehicleModel))
            
            xPlayer.removeInventoryItem(itemName, 1)
            TriggerClientEvent('az_inventory:spawnVehicle', source, vehicleModel)
            SyncPlayerInventory(source)
            
            cb(true)
            return
        end

        -- --- 3. LOGIQUE ARMES CUSTOM ---
        if Config and Config.WeaponItems and Config.WeaponItems[itemName] then
            print("[az_inventory] Arme custom détectée : " .. tostring(itemName))
            TriggerClientEvent('az_inventory:giveWeaponToPed', source, itemName, Config.WeaponItems[itemName])
            cb(true)
            return
        end

        -- --- 4. LOGIQUE ARMES NATIVES ---
        if string.sub(string.upper(itemName), 1, 7) == "WEAPON_" then
            print("[az_inventory] Arme native détectée : " .. tostring(itemName))
            TriggerClientEvent('az_inventory:giveWeaponToPed', source, itemName)
            cb(true)
            return
        end

        -- --- 5. UTILISATION ITEMS CLASSIQUES ---
        print("[az_inventory] Utilisation d'un item standard ou consommable.")
        if xPlayer.useItem then
            xPlayer.useItem(itemName)
        else
            ESX.UseItem(source, itemName)
        end
        cb(true)
    else
        print("[az_inventory] Échec : Le joueur n'a pas l'item " .. tostring(itemName) .. " dans son inventaire.")
        cb(false)
    end
end)

RegisterNetEvent('az_inventory:returnVehicleItem')
AddEventHandler('az_inventory:returnVehicleItem', function(modelName)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end

    print("[az_inventory] Tentative de rangement du véhicule. Modèle reçu : " .. tostring(modelName))

    -- On cherche l'item qui correspond à ce modèle dans la config
    local itemToGive = nil
    
    if Config and Config.VehicleItems then
        for itemName, vModel in pairs(Config.VehicleItems) do
            if vModel == modelName or itemName == modelName then
                itemToGive = itemName
                break
            end
        end
    end

    if itemToGive then
        print("[az_inventory] Correspondance trouvée ! Ajout de l'item : " .. itemToGive)
        xPlayer.addInventoryItem(itemToGive, 1)
        SyncPlayerInventory(_source)
    else
        print("[az_inventory] ERREUR : Le modèle " .. tostring(modelName) .. " n'est pas reconnu dans Config.VehicleItems")
    end
end)

-- Register the Drop Item Callback
ESX.RegisterServerCallback('az_inventory:dropItem', function(source, cb, itemName, count)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then
        cb(false)
        return
    end

    -- Protection anti-spam/dupe
    if not lockPlayer(source) then
        cb(false)
        return
    end

    -- On vérifie que le joueur possède bien l'item
    local item = xPlayer.getInventoryItem(itemName)
    if item and item.count >= count then
        -- Suppression de l'item de l'inventaire
        xPlayer.removeInventoryItem(itemName, count)
        
        -- Log console pour le suivi
        print(('[az_inventory] %s a jeté %dx %s'):format(xPlayer.getName(), count, itemName))
        
        unlockPlayer(source)
        SyncPlayerInventory(source)
        cb(true)
    else
        print(('[az_inventory] %s a tenté de jeter %s mais ne l\'a pas'):format(xPlayer.getName(), itemName))
        unlockPlayer(source)
        cb(false)
    end
end)

-- ─── Give Item Callback ──────────────────────────────────
ESX.RegisterServerCallback('az_inventory:giveItem', function(source, cb, itemName, count)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then cb(false) return end
    if not lockPlayer(source) then cb(false) return end

    count = count or 1
    local item = xPlayer.getInventoryItem(itemName)

    if not item or item.count < count then
        print(('[az_inventory] %s tried to give %s but doesn\'t have enough'):format(xPlayer.getName(), itemName))
        unlockPlayer(source)
        cb(false)
        return
    end

    -- Find closest player within 3.0 meters
    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)
    local closestPlayer = nil
    local closestDist = 3.0

    local players = ESX.GetPlayers()
    for _, playerId in ipairs(players) do
        if playerId ~= source then
            local targetPed = GetPlayerPed(playerId)
            local targetCoords = GetEntityCoords(targetPed)
            local dist = #(playerCoords - targetCoords)
            if dist < closestDist then
                closestDist = dist
                closestPlayer = playerId
            end
        end
    end

    if not closestPlayer then
        TriggerClientEvent('az_notify:showNotification', source, '~r~Aucun joueur à proximité.')
        unlockPlayer(source)
        cb(false)
        return
    end

    local xTarget = ESX.GetPlayerFromId(closestPlayer)
    if not xTarget then
        unlockPlayer(source)
        cb(false)
        return
    end

    -- Check target can carry the weight
    if not CanCarryWeight(xTarget, GetItemWeight(itemName) * count) then
        TriggerClientEvent('az_notify:showNotification', source, '~r~L\'inventaire du joueur est trop lourd.')
        unlockPlayer(source)
        cb(false)
        return
    end

    xPlayer.removeInventoryItem(itemName, count)
    xTarget.addInventoryItem(itemName, count)

    TriggerClientEvent('az_notify:showNotification', source, ('~g~Vous avez donné %dx %s'):format(count, item.label or itemName))
    TriggerClientEvent('az_notify:showNotification', closestPlayer, ('~g~Vous avez reçu %dx %s'):format(count, item.label or itemName))

    -- Refresh both players' UI with full data
    SyncPlayerInventory(source)
    SyncPlayerInventory(closestPlayer)

    print(('[az_inventory] %s gave %dx %s to %s'):format(xPlayer.getName(), count, itemName, xTarget.getName()))
    unlockPlayer(source)
    cb(true)
end)

RegisterNetEvent('az_inventory:removeItemAfterUse')
AddEventHandler('az_inventory:removeItemAfterUse', function(itemName)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)

    if xPlayer then
        -- On vérifie quand même si le joueur a bien l'item avant de l'enlever
        local item = xPlayer.getInventoryItem(itemName)
        
        if item and item.count > 0 then
            xPlayer.removeInventoryItem(itemName, 1)
            
            -- TRÈS IMPORTANT : On rafraîchit l'inventaire pour le joueur
            -- pour que l'item disparaisse de son écran immédiatement
            SyncPlayerInventory(_source) 
            
            print(("[az_inventory] Consommable utilisé et retiré : %s pour le joueur %s"):format(itemName, xPlayer.getName()))
        end
    end
end)

local ammoMapping = {
    ['AMMO_12']     = { count = 8,  label = "Calibre 12" },
    ['AMMO_45']     = { count = 12, label = ".45 ACP" },
    ['AMMO_50']     = { count = 5,  label = ".50 BMG" },
    ['AMMO_556']    = { count = 30, label = "5.56mm" },
    ['AMMO_762']    = { count = 30, label = "7.62mm" },
    ['AMMO_ROCKET'] = { count = 1,  label = "Roquette" },
}

for ammoName, data in pairs(ammoMapping) do
    ESX.RegisterUsableItem(ammoName, function(source)
        -- On envoie l'ordre au client
        TriggerClientEvent('az_inventory:useAmmo', source, ammoName, data.count, data.label)
    end)
end

-- Event pour retirer l'item après utilisation réussie
RegisterNetEvent('az_inventory:removeAmmoItem')
AddEventHandler('az_inventory:removeAmmoItem', function(itemName)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)

    if xPlayer then
        xPlayer.removeInventoryItem(itemName, 1)
        print("DEBUG: Item " .. itemName .. " retiré de l'inventaire de " .. _source)
        
        -- AJOUTE CETTE LIGNE ICI pour rafraîchir l'affichage du joueur
        SyncPlayerInventory(_source) 
    end
end)