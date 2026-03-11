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

    local targetContainer = containerType == 'stash' and customData.stash or customData.container
    local dbColumn = containerType == 'stash' and 'container' or 'protected'

    if fromZone == 'bag' and toZone == 'container' then
        if containerType == 'protected' then
            if not CanContainerCarryWeight(targetContainer, GetItemWeight(itemName) * count) then
                TriggerClientEvent('az_notify:showNotification', source, '~r~The protected container is full!')
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
            local ammo = item.ammo or 0
            if not found then
                table.insert(targetContainer, {
                    name = itemName, 
                    label = item.label, 
                    count = count, 
                    weight = GetItemWeight(itemName),
                    ammo = ammo -- Save ammo in the container
                })
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
                local ammo = item.ammo or 0
                item.count = item.count - count
                if item.count <= 0 then table.remove(targetContainer, foundIndex) end

                xPlayer.addInventoryItem(itemName, count)

                -- Appliquer la metadata au nouveau item de l'inventaire ESX
                local newInv = xPlayer.getInventoryItem(itemName)
                if newInv then
                    newInv.ammo = ammo
                end

                MySQL.update('UPDATE users SET ' .. dbColumn .. ' = ? WHERE identifier = ?', {json.encode(targetContainer), xPlayer.identifier})
                unlockPlayer(source)
                SyncPlayerInventory(source)
                cb(true, targetContainer)
            else
                TriggerClientEvent('az_notify:showNotification', source, '~r~Your bag is too heavy!')
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
AddEventHandler('az_inventory:dropBagOnDeath', function(killerServerId)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)

    if not xPlayer then 
        return 
    end

    MySQL.update('UPDATE users SET deaths = deaths + 1 WHERE identifier = ?', {xPlayer.identifier})

    local killerIdentifier = nil
    if killerServerId and killerServerId ~= -1 and killerServerId ~= _source then
        local xKiller = ESX.GetPlayerFromId(killerServerId)
        if xKiller then
            killerIdentifier = xKiller.identifier
            MySQL.update('UPDATE users SET kills = kills + 1 WHERE identifier = ?', {killerIdentifier})
        end
    end

    local ped = GetPlayerPed(_source)
    if not ped or ped == 0 then return end
    local coords = GetEntityCoords(ped)

    local inventory = xPlayer.getInventory()
    local itemsToDrop = {}

    for i=1, #inventory do
        local item = inventory[i]
        if item and item.count > 0 then
            table.insert(itemsToDrop, {
                name = item.name,
                count = item.count,
                label = item.label or item.name,
                ammo = item.ammo or 0
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
            owner = xPlayer.identifier,
            killer = killerIdentifier -- Store who killed the owner
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

            -- Kill Confirmed Check
            if bag.killer == xPlayer.identifier then
                MySQL.update('UPDATE users SET kill_confirmed = kill_confirmed + 1 WHERE identifier = ?', {xPlayer.identifier})
            end

            -- 2. On distribue les items et on envoie les notifs colorées
            for _, item in ipairs(bag.items) do
                xPlayer.addInventoryItem(item.name, item.count)
                
                if item.ammo then
                    local newInv = xPlayer.getInventoryItem(item.name)
                    if newInv then newInv.ammo = item.ammo end
                end

                -- On récupère la couleur dans le dictionnaire
                local rarityColor = ItemRarity[item.name] or ItemRarity['default']
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
            TriggerClientEvent('az_notify:showNotification', _source, "~r~Your inventory is too heavy!", 6)
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
        cb(false) 
        return 
    end

    local item = xPlayer.getInventoryItem(itemName)
    if item and item.count > 0 then

        -- --- 1. LOGIQUE Gilet ---
        -- Dans ton callback az_inventory:useItem :
        if itemName == nil then 
            cb(false) 
            return 
        end

        -- On s'assure que c'est bien du texte
        local name = tostring(itemName)

        -- DETECTION DES CONSOMMABLES (Correction du string.find)
        if string.find(name, "CONSUMABLE") or string.find(name, "EQUIPMENT") then
            TriggerClientEvent('az_inventory:useConsumable', source, name)
            cb(true)
            return
        end
    
        -- --- 2. LOGIQUE VÉHICULE (AJOUTÉE) ---
        if Config and Config.VehicleItems and Config.VehicleItems[itemName] then
            local vehicleModel = Config.VehicleItems[itemName]
            
            xPlayer.removeInventoryItem(itemName, 1)
            
            -- Fetch global preset for this model
            MySQL.scalar('SELECT vehicle_presets FROM users WHERE identifier = ?', {xPlayer.identifier}, function(result)
                local mods = item.mods or nil
                
                if result and result ~= "" and result ~= "{}" then
                    local presets = json.decode(result) or {}
                    if presets[vehicleModel] then
                        mods = presets[vehicleModel]
                    else
                    end
                end
                
                TriggerClientEvent('az_inventory:spawnVehicle', source, vehicleModel, mods)
                SyncPlayerInventory(source)
            end)
            
            cb(true)
            return
        end

        -- --- 3. LOGIQUE ARMES CUSTOM ---
        if Config and Config.WeaponItems and Config.WeaponItems[itemName] then
            local weaponAmmo = item.ammo or 0
            if Config.AutoReloadOnEquip then 
                weaponAmmo = 250 
            end
            TriggerClientEvent('az_inventory:giveWeaponToPed', source, itemName, Config.WeaponItems[itemName], weaponAmmo)
            cb(true)
            return
        end

        -- --- 4. LOGIQUE ARMES NATIVES ---
        if string.sub(string.upper(itemName), 1, 7) == "WEAPON_" then
            local weaponAmmo = item.ammo or 0
            if Config.AutoReloadOnEquip then 
                weaponAmmo = 250 
            end
            TriggerClientEvent('az_inventory:giveWeaponToPed', source, itemName, itemName, weaponAmmo)
            cb(true)
            return
        end

        -- --- 5. UTILISATION ITEMS CLASSIQUES ---
        if xPlayer.useItem then
            xPlayer.useItem(itemName)
        else
            ESX.UseItem(source, itemName)
        end
        cb(true)
    else
        cb(false)
    end
end)

RegisterNetEvent('az_inventory:returnVehicleItem')
AddEventHandler('az_inventory:returnVehicleItem', function(modelName, mods)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end

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
        xPlayer.addInventoryItem(itemToGive, 1, mods)
        
        -- Also update the global preset for this model
        MySQL.prepare('SELECT vehicle_presets FROM users WHERE identifier = ?', {xPlayer.identifier}, function(result)
            local presets = {}
            if result and result.vehicle_presets then
                presets = json.decode(result.vehicle_presets) or {}
            end
            
            presets[modelName] = mods
            
            MySQL.update('UPDATE users SET vehicle_presets = ? WHERE identifier = ?', {
                json.encode(presets),
                xPlayer.identifier
            })
        end)
        
        SyncPlayerInventory(_source)
    end
end)

RegisterNetEvent('az_inventory:saveItemMetadata')
AddEventHandler('az_inventory:saveItemMetadata', function(itemName, metadata, targetSource)
    local _source = targetSource or source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end

    local invItem = xPlayer.getInventoryItem(itemName)
    if invItem and invItem.count > 0 then
        for k, v in pairs(metadata) do
            invItem[k] = v
        end
        SyncPlayerInventory(_source)
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
        
        unlockPlayer(source)
        SyncPlayerInventory(source)
        cb(true)
    else
        unlockPlayer(source)
        cb(false)
    end
end)

-- ─── Give Item Callback ──────────────────────────────────
ESX.RegisterServerCallback('az_inventory:giveItem', function(source, cb, itemName, count, targetId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then cb(false) return end

    local xTarget = ESX.GetPlayerFromId(targetId)
    if not xTarget then
        TriggerClientEvent('az_notify:showNotification', source, '~r~Player not found.')
        cb(false)
        return
    end

    if not lockPlayer(source) then cb(false) return end

    count = count or 1
    local item = xPlayer.getInventoryItem(itemName)

    if not item or item.count < count then
        unlockPlayer(source)
        cb(false)
        return
    end

    -- Security: distance check on server too
    local s = tonumber(source)
    local t = tonumber(targetId)
    local playerPed = s and GetPlayerPed(s)
    local targetPed = t and GetPlayerPed(t)

    if not playerPed or playerPed == 0 or not targetPed or targetPed == 0 then
        TriggerClientEvent('az_notify:showNotification', source, '~r~Technical error (Ped not found).')
        unlockPlayer(source)
        cb(false)
        return
    end

    local dist = #(GetEntityCoords(playerPed) - GetEntityCoords(targetPed))

    if dist > 5.0 then
        TriggerClientEvent('az_notify:showNotification', source, '~r~The player is too far.')
        unlockPlayer(source)
        cb(false)
        return
    end

    -- Check target can carry the weight
    if not CanCarryWeight(xTarget, GetItemWeight(itemName) * count) then
        TriggerClientEvent('az_notify:showNotification', source, "~r~The player's inventory is too heavy.")
        unlockPlayer(source)
        cb(false)
        return
    end

    xPlayer.removeInventoryItem(itemName, count)
    xTarget.addInventoryItem(itemName, count)

    TriggerClientEvent('az_notify:showNotification', source, ('~g~You gave %dx %s'):format(count, item.label or itemName))
    TriggerClientEvent('az_notify:showNotification', targetId, ('~g~You received %dx %s'):format(count, item.label or itemName))

    -- Refresh both players' UI with full data
    SyncPlayerInventory(source)
    SyncPlayerInventory(targetId)

    unlockPlayer(source)
    cb(true)
end)

RegisterNetEvent('az_inventory:removeItemAfterUse')
AddEventHandler('az_inventory:removeItemAfterUse', function(itemName)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)

    if xPlayer then
        local item = xPlayer.getInventoryItem(itemName)
        
        if item and item.count > 0 then
            xPlayer.removeInventoryItem(itemName, 1)
            SyncPlayerInventory(_source) 
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
        TriggerClientEvent('az_inventory:useAmmo', source, ammoName, data.count, data.label)
    end)
end

RegisterNetEvent('az_inventory:removeAmmoItem')
AddEventHandler('az_inventory:removeAmmoItem', function(itemName)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)

    if xPlayer then
        xPlayer.removeInventoryItem(itemName, 1)
        
        SyncPlayerInventory(_source) 
    end
end)

RegisterNetEvent('az_inventory:updateWeaponAmmo')
AddEventHandler('az_inventory:updateWeaponAmmo', function(itemName, ammoCount)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)

    if not xPlayer or not playerCustomData[xPlayer.identifier] then return end

    -- Normalement l'item est dans le sac classique (ESX getInventoryItem ne gère pas l'extended data comme l'ammo direct)
    -- Mais on peut le sauvegarder dans la DB locale d'ESX ou un système custom.
    -- L'inventaire ESX standard utilise "metadata". Mais az_inventory semble juste utiliser ESX "addInventoryItem".
    -- Comme on veut sauvegarder pour l'inventaire principal on va chercher dans l'inventaire du joueur:
    
    local inventory = xPlayer.getInventory(false)
    for k,v in ipairs(inventory) do
        if v.name == itemName then
            v.ammo = ammoCount
            break
        end
    end
    
    -- Pour les stash/containers protégés on peut aussi parcourir pour trouver l'item s'il est dedant.
    -- S'il est dans le sac, mais déplacé ensuite, le "moveItem" transférera cette data si on l'ajoute plus haut.
end)

-- ─── Shop Logic ───────────────────────────────────────────

function RefreshShopForAll()
    MySQL.query('SELECT id, identifier, item as name, label, quantity as count, price FROM shop', {}, function(results)
        if results then
            for _, it in ipairs(results) do
                it.weight = GetItemWeight(it.name)
                -- We remove it.isMine calculation here as it depends on the receiving client
            end
            TriggerClientEvent('az_inventory:updateShop', -1, results)
        end
    end)
end

ESX.RegisterServerCallback('az_inventory:getShopItems', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end

    MySQL.query('SELECT id, identifier, item as name, label, quantity as count, price FROM shop', {}, function(results)
        if results then
            for _, item in ipairs(results) do
                item.weight = GetItemWeight(item.name)
            end
            cb(results)
        else
            cb({})
        end
    end)
end)

ESX.RegisterServerCallback('az_inventory:buyItem', function(source, cb, id)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false) end

    MySQL.query('SELECT * FROM shop WHERE id = ?', {id}, function(result)
        if result and result[1] then
            local shopItem = result[1]
            local price = shopItem.price
            local itemName = shopItem.item
            local count = shopItem.quantity
            local label = shopItem.label
            local sellerIdentifier = shopItem.identifier

            -- 1. Check Money
            if xPlayer.getMoney() < price then
                TriggerClientEvent('az_notify:showNotification', source, "~r~You don't have enough money.")
                return cb(false)
            end

            -- 2. Check Weight
            if not CanCarryWeight(xPlayer, GetItemWeight(itemName) * count) then
                TriggerClientEvent('az_notify:showNotification', source, "~r~Your inventory is too heavy.")
                return cb(false)
            end

            -- 3. Check if seller is same as buyer
            if sellerIdentifier == xPlayer.identifier then
                TriggerClientEvent('az_notify:showNotification', source, "~r~You cannot buy your own item.")
                return cb(false)
            end

            -- 4. Process Transaction
            xPlayer.removeMoney(price)
            xPlayer.addInventoryItem(itemName, count)

            -- Delete from shop
            MySQL.update('DELETE FROM shop WHERE id = ?', {id}, function(rowsChanged)
                if rowsChanged > 0 then
                    -- Give money to seller (even if offline)
                    MySQL.update('UPDATE users SET accounts = JSON_SET(accounts, "$.money", JSON_EXTRACT(accounts, "$.money") + ?) WHERE identifier = ?', {
    price, 
    sellerIdentifier
})
                    
                    -- Notify seller if online
                    local xSeller = ESX.GetPlayerFromIdentifier(sellerIdentifier)
                    if xSeller then
                        TriggerClientEvent('az_notify:showNotification', xSeller.source, ("~g~Your item (%s) has been sold for %s$ !"):format(label, price))
                    end

                    TriggerClientEvent('az_notify:showNotification', source, ("~g~You purchased %dx %s for %s$ !"):format(count, label, price))
                    
                    SyncPlayerInventory(source)
                    RefreshShopForAll()
                    cb(true)
                else
                    cb(false)
                end
            end)
        else
            TriggerClientEvent('az_notify:showNotification', source, "~r~This item is no longer available.")
            cb(false)
        end
    end)
end)

ESX.RegisterServerCallback('az_inventory:getProfileData', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end

    -- 1. Fetch current player stats
    MySQL.query('SELECT kills, deaths, assists, kill_confirmed FROM users WHERE identifier = ?', {
        xPlayer.identifier
    }, function(userResult)
        local userData = {
            name = GetPlayerName(source),
            id = source,
            kills = (userResult and userResult[1] and userResult[1].kills) or 0,
            deaths = (userResult and userResult[1] and userResult[1].deaths) or 0,
            assists = (userResult and userResult[1] and userResult[1].assists) or 0,
            kill_confirmed = (userResult and userResult[1] and userResult[1].kill_confirmed) or 0,
            leaderboard = {}
        }

        -- 2. Fetch Top 10 Leaderboard
        -- Selecting identifier since name is missing
        MySQL.query('SELECT identifier, kills, deaths FROM users ORDER BY kills DESC LIMIT 10', {}, function(lbResult)
            if lbResult then
                for i=1, #lbResult do
                    local playerName = "Player " .. i
                    -- Try to get name if player is online
                    local targetPlayer = ESX.GetPlayerFromIdentifier(lbResult[i].identifier)
                    if targetPlayer then
                        playerName = GetPlayerName(targetPlayer.source)
                    end

                    table.insert(userData.leaderboard, {
                        name = playerName,
                        kills = lbResult[i].kills or 0,
                        deaths = lbResult[i].deaths or 0
                    })
                end
            end
            cb(userData)
        end)
    end)
end)

RegisterNetEvent('az_inventory:sellItem')
AddEventHandler('az_inventory:sellItem', function(itemName, label, count, price)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end

    if price > 999999999 then
        TriggerClientEvent('az_notify:showNotification', _source, "~r~Price too high (max 999,999,999$).")
        return
    end

    local item = xPlayer.getInventoryItem(itemName)
    if item and item.count >= count then
        xPlayer.removeInventoryItem(itemName, count)
        
        MySQL.insert('INSERT INTO shop (identifier, item, label, quantity, price) VALUES (?, ?, ?, ?, ?)', {
            xPlayer.identifier, itemName, label, count, price
        }, function(id)
            if id then
                TriggerClientEvent('az_notify:showNotification', _source, "~g~Item put up for sale !")
                
                SyncPlayerInventory(_source)
                RefreshShopForAll() -- Broadcast update after sale
            end
        end)
    else
        TriggerClientEvent('az_notify:showNotification', _source, "~r~Insufficient quantity.")
    end
end)

ESX.RegisterServerCallback('az_inventory:removeItem', function(source, cb, id)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false) end

    MySQL.query('SELECT * FROM shop WHERE id = ?', {id}, function(result)
        if result and result[1] then
            local shopItem = result[1]
            local itemName = shopItem.item
            local count = shopItem.quantity
            local label = shopItem.label
            local sellerIdentifier = shopItem.identifier

            -- 1. Check Ownership
            if sellerIdentifier ~= xPlayer.identifier then
                TriggerClientEvent('az_notify:showNotification', source, "~r~This item does not belong to you.")
                return cb(false)
            end

            -- 2. Check Weight
            if not CanCarryWeight(xPlayer, GetItemWeight(itemName) * count) then
                TriggerClientEvent('az_notify:showNotification', source, "~r~You don't have enough space to take this item back.")
                return cb(false)
            end

            -- 3. Process Removal
            MySQL.update('DELETE FROM shop WHERE id = ?', {id}, function(rowsChanged)
                if rowsChanged > 0 then
                    xPlayer.addInventoryItem(itemName, count)
                    TriggerClientEvent('az_notify:showNotification', source, ("~g~You removed %dx %s from the marketplace."):format(count, label))
                    
                    SyncPlayerInventory(source)
                    RefreshShopForAll() -- Broadcast update after removal
                    
                    cb(true)
                else
                    cb(false)
                end
            end)
        else
            TriggerClientEvent('az_notify:showNotification', source, "~r~This item is no longer available.")
            cb(false)
        end
    end)
end)