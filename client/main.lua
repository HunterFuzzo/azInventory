-- ============================================================
-- ESX Inventory – Client Script
-- Handles NUI toggle, controls, and item actions
-- ============================================================

ESX = nil
local isOpen = false

-- ─── ESX Init ─────────────────────────────────────────────
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(100)
    end
end)

local CustomContainer = {}
local CustomShortkeys = {}
local currentWeapon = nil -- Track the currently equipped weapon from shortkey

-- Receive data from server on load
RegisterNetEvent('az_inventory:loadCustomData')
AddEventHandler('az_inventory:loadCustomData', function(container, shortkeys)
    CustomContainer = container or {}
    CustomShortkeys = shortkeys or {}
end)

-- ─── Open Inventory ───────────────────────────────────────
function OpenInventory()
    if isOpen then return end

    local playerData = ESX.GetPlayerData()
    if not playerData or not playerData.inventory then return end

    isOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    -- Build inventory data with weights
    local inventory = {}
    for _, item in ipairs(playerData.inventory) do
        if item.count > 0 then
            table.insert(inventory, {
                name = item.name,
                label = item.label,
                count = item.count,
                weight = item.weight or 0.1,
                description = item.description or ''
            })
        end
    end

    SendNUIMessage({
        action = 'openInventory',
        inventory = inventory,
        container = CustomContainer,
        shortkeys = CustomShortkeys,
        maxWeight = 1000,
        playerName = GetPlayerName(PlayerId()),
        playerId = GetPlayerServerId(PlayerId())
    })
end

-- ─── Refresh UI Function ───────────────────────────────────
function RefreshInventoryNUI()
    if not isOpen then return end
    local playerData = ESX.GetPlayerData()
    if not playerData or not playerData.inventory then return end

    local inventory = {}
    for _, item in ipairs(playerData.inventory) do
        if item.count > 0 then
            table.insert(inventory, {
                name = item.name,
                label = item.label,
                count = item.count,
                weight = item.weight or 0.1,
                description = item.description or ''
            })
        end
    end

    SendNUIMessage({
        action = 'updateInventory',
        inventory = inventory,
        container = CustomContainer
    })
    
    -- Pour forcer également le reset visuel des touches :
    SendNUIMessage({
        action = 'openInventory',
        inventory = inventory,
        container = CustomContainer,
        shortkeys = CustomShortkeys,
        maxWeight = 1000,
        playerName = GetPlayerName(PlayerId()),
        playerId = GetPlayerServerId(PlayerId())
    })
end

-- ─── Close Inventory ──────────────────────────────────────
function CloseInventory()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end

-- ─── Key Binding (TAB) ───────────────────────────────────
Citizen.CreateThread(function()
    while true do
        local sleep = 0
        
        -- Bloque la roue des armes native (TAB) même si l'inventaire est fermé
        DisableControlAction(0, 37, true) 

        if IsDisabledControlJustPressed(0, 37) then -- On utilise JUST PRESSED pour le Toggle
            if isOpen then
                CloseInventory()
                SendNUIMessage({ action = 'closeInventory' })
            else
                OpenInventory()
            end
        end

        if isOpen then
            -- On bloque la souris pour pas que la caméra tourne
            DisableControlAction(0, 1, true) 
            DisableControlAction(0, 2, true)
            -- On bloque les actions de combat
            DisableControlAction(0, 24, true) 
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true)
            
            -- /!\ IMPORTANT : On bloque la touche TAB (37) en boucle quand c'est ouvert
            -- pour éviter que le jeu ne l'interprète comme "maintenir la roue des armes"
            DisableControlAction(0, 37, true) 
        end
        
        Citizen.Wait(sleep)
    end
end)

-- ─── NUI Callbacks ────────────────────────────────────────

-- Close inventory
RegisterNUICallback('closeInventory', function(data, cb)
    CloseInventory()
    cb('ok')
end)

-- Move item between zones
RegisterNUICallback('moveItem', function(data, cb)
    if currentWeapon and data.item == currentWeapon and data.fromZone == 'bag' then
        TriggerEvent('az_inventory:removeWeaponFromPed', currentWeapon)
        ESX.ShowNotification('~y~Arme déséquipée automatiquement.')
    end

    ESX.TriggerServerCallback('az_inventory:moveItem', function(success, updatedContainer)
        if success then
            if updatedContainer then 
                CustomContainer = updatedContainer 
            end
            
            -- Refresh inventory display
            local playerData = ESX.GetPlayerData()
            local inventory = {}
            for _, item in ipairs(playerData.inventory) do
                if item.count > 0 then
                    table.insert(inventory, {
                        name = item.name,
                        label = item.label,
                        count = item.count,
                        weight = item.weight or 0.1,
                        description = item.description or ''
                    })
                end
            end
            
            SendNUIMessage({
                action = 'updateInventory',
                inventory = inventory,
                container = CustomContainer
            })
        end
        cb({ success = success })
    end, data.fromZone, data.toZone, data.item, data.count)
end)

-- Use item
RegisterNUICallback('useItem', function(data, cb)
    ESX.TriggerServerCallback('az_inventory:useItem', function(success)
        if success then
            TriggerEvent('esx:onPlayerData', ESX.GetPlayerData())
        end
        cb({ success = success })
    end, data.item, data.slot)
end)

-- Drop item
RegisterNUICallback('dropItem', function(data, cb)
    if currentWeapon and data.item == currentWeapon then
        TriggerEvent('az_inventory:removeWeaponFromPed', currentWeapon)
        ESX.ShowNotification('~y~Arme déséquipée automatiquement.')
    end

    ESX.TriggerServerCallback('az_inventory:dropItem', function(success)
        if success then
            local playerData = ESX.GetPlayerData()
            local inventory = {}
            for _, item in ipairs(playerData.inventory) do
                if item.count > 0 then
                    table.insert(inventory, {
                        name = item.name,
                        label = item.label,
                        count = item.count,
                        weight = item.weight or 0.1,
                        description = item.description or ''
                    })
                end
            end
            SendNUIMessage({
                action = 'updateInventory',
                inventory = inventory
            })
        end
        cb({ success = success })
    end, data.item, data.count)
end)

-- Give item
RegisterNUICallback('giveItem', function(data, cb)
    if currentWeapon and data.item == currentWeapon then
        TriggerEvent('az_inventory:removeWeaponFromPed', currentWeapon)
        ESX.ShowNotification('~y~Arme déséquipée automatiquement.')
    end

    ESX.TriggerServerCallback('az_inventory:giveItem', function(success)
        cb({ success = success })
    end, data.item, data.count)
end)

-- Set shortkey
RegisterNUICallback('setShortkey', function(data, cb)
    local slotIndex = data.slot + 1
    local oldItem = CustomShortkeys[slotIndex]
    
    -- Si l'item qui sort du slot est celui qu'on pense avoir en main
    if oldItem ~= nil and oldItem ~= false and oldItem == currentWeapon then
        local playerPed = PlayerPedId()
        
        -- On force le désarmement immédiat
        SetCurrentPedWeapon(playerPed, GetHashKey("WEAPON_UNARMED"), true)
        
        -- On retire l'arme physiquement (si c'est ton système)
        local weaponHash = GetHashKey(oldItem)
        if Config and Config.WeaponItems and Config.WeaponItems[oldItem] then
            weaponHash = GetHashKey(Config.WeaponItems[oldItem])
        end
        RemoveWeaponFromPed(playerPed, weaponHash)
        
        currentWeapon = nil -- On oublie l'arme
        ESX.ShowNotification('~y~Arme retirée de la main.')
    end

    -- Mise à jour habituelle
    if data.item == nil then
        CustomShortkeys[slotIndex] = false
    else
        CustomShortkeys[slotIndex] = data.item
    end
    
    TriggerServerEvent('az_inventory:setShortkey', data.slot, data.item)
    cb('ok')
end)
-- ─── Weapon & Shortkey Usage (1-5 keys) ───────────────────

-- Reçu du serveur : donner physiquement l'arme au ped et l'équiper
RegisterNetEvent('az_inventory:giveWeaponToPed')
AddEventHandler('az_inventory:giveWeaponToPed', function(itemName, actualWeaponName)
    local playerPed = PlayerPedId()
    local weaponToGive = actualWeaponName or itemName
    local weaponHash = GetHashKey(weaponToGive)

    -- Donner l'arme avec munitions par défaut si non possédée
    if not HasPedGotWeapon(playerPed, weaponHash, false) then
        GiveWeaponToPed(playerPed, weaponHash, 30, false, true)
    end

    SetCurrentPedWeapon(playerPed, weaponHash, true)
    currentWeapon = itemName
end)

-- Reçu du serveur : retirer physiquement l'arme du ped
RegisterNetEvent('az_inventory:removeWeaponFromPed')
AddEventHandler('az_inventory:removeWeaponFromPed', function(itemName)
    local playerPed = PlayerPedId()
    local actualWeaponName = itemName
    if Config and Config.WeaponItems and Config.WeaponItems[itemName] then
        actualWeaponName = Config.WeaponItems[itemName]
    end
    local weaponHash = GetHashKey(actualWeaponName)
    
    RemoveWeaponFromPed(playerPed, weaponHash)
    if currentWeapon == itemName then
        currentWeapon = nil
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if not isOpen then
            local keys = {157, 158, 160, 164, 165} -- Touches 1, 2, 3, 4, 5
            for i = 1, #keys do
                if IsControlJustReleased(0, keys[i]) or IsDisabledControlJustReleased(0, keys[i]) then
                    local slotIndex = i
                    local itemName = CustomShortkeys[slotIndex]
                    
                    if itemName and type(itemName) == 'string' then
                        local isNativeWeapon = (string.sub(string.upper(itemName), 1, 7) == "WEAPON_")
                        local isCustomWeapon = (Config and Config.WeaponItems and Config.WeaponItems[itemName] ~= nil)

                        if isNativeWeapon or isCustomWeapon then
                            local playerPed = PlayerPedId()
                            local weaponName = isCustomWeapon and Config.WeaponItems[itemName] or itemName
                            local weaponHash = GetHashKey(weaponName)

                            -- --- LOGIQUE DE BASCULE (TOGGLE) ---
                            if currentWeapon == itemName then
                                -- Si on a déjà CETTE arme en main, on la range
                                SetCurrentPedWeapon(playerPed, GetHashKey("WEAPON_UNARMED"), true)
                                currentWeapon = nil
                                print('[az_inventory] Arme rangée (touche réappuyée)')
                            else
                                -- Sinon, on vérifie si le ped a l'arme et on l'équipe
                                if HasPedGotWeapon(playerPed, weaponHash, false) then
                                    SetCurrentPedWeapon(playerPed, weaponHash, true)
                                    currentWeapon = itemName
                                    print('[az_inventory] Arme équipée : ' .. itemName)
                                else
                                    -- Si le ped ne l'a pas physiquement, on demande au serveur via useItem
                                    ESX.TriggerServerCallback('az_inventory:useItem', function(success)
                                        if success then currentWeapon = itemName end
                                    end, itemName, slotIndex - 1)
                                end
                            end
                        else
                            -- Si c'est un item normal (pain, etc.)
                            ESX.TriggerServerCallback('az_inventory:useItem', function(success) end, itemName, slotIndex - 1)
                        end
                    end
                end
            end
        end
    end
end)    

-- ─── Vehicle Item Logic ───────────────────────────────────
local spawnedVehicle = nil
local spawnedVehicleModel = nil -- Track the item name associated with the vehicle

RegisterNetEvent('az_inventory:spawnVehicle')
AddEventHandler('az_inventory:spawnVehicle', function(model)
    if spawnedVehicle and DoesEntityExist(spawnedVehicle) then
        ESX.ShowNotification('~r~Vous avez déjà un véhicule sorti !')
        return
    end

    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)

    -- Note: using ESX.Game.SpawnVehicle to properly handle network entities
    ESX.Game.SpawnVehicle(model, coords, heading, function(vehicle)
        spawnedVehicle = vehicle
        spawnedVehicleModel = model
        TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
        ESX.ShowNotification('~g~Véhicule sorti ! Appuyez sur ~y~K ~g~pour le ranger.')
    end)
end)

-- Listener for K key (311) to return vehicle
-- Listener for K key (311) to return vehicle
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        -- On vérifie si la touche K est relâchée ET si l'inventaire n'est pas ouvert
        if IsControlJustReleased(0, 311) and not isOpen then 
            if spawnedVehicle ~= nil and DoesEntityExist(spawnedVehicle) then
                local playerPed = PlayerPedId()
                local vehCoords = GetEntityCoords(spawnedVehicle)
                local playerCoords = GetEntityCoords(playerPed)
                
                -- Calcul de la distance
                local dist = #(playerCoords - vehCoords)
                
                -- Check si proche ou à l'intérieur
                if dist < 10.0 or GetVehiclePedIsIn(playerPed, false) == spawnedVehicle then
                    
                    -- 1. Sauvegarde du modèle avant suppression
                    local modelToReturn = spawnedVehicleModel or "deluxo"
                    
                    -- 2. Suppression propre du véhicule
                    ESX.Game.DeleteVehicle(spawnedVehicle)
                    
                    -- 3. RESET IMMÉDIAT des variables locales (Crucial pour pouvoir respawn)
                    spawnedVehicle = nil
                    spawnedVehicleModel = nil
                    
                    -- 4. Notification Serveur pour rendre l'item
                    TriggerServerEvent('az_inventory:returnVehicleItem', modelToReturn)
                    
                    ESX.ShowNotification('~g~Véhicule rangé dans votre inventaire !')

                    -- 5. SYNCHRONISATION NUI : 
                    -- On attend un court instant que le serveur traite l'ajout de l'item
                    -- puis on demande un rafraîchissement complet
                    Citizen.SetTimeout(500, function()
                        local playerData = ESX.GetPlayerData()
                        if playerData and playerData.inventory then
                            local inventory = {}
                            for _, item in ipairs(playerData.inventory) do
                                if item.count > 0 then
                                    table.insert(inventory, {
                                        name = item.name,
                                        label = item.label,
                                        count = item.count,
                                        weight = item.weight or 0.1,
                                        description = item.description or ''
                                    })
                                end
                            end

                            -- On renvoie l'inventaire frais au JS pour éviter que 
                            -- l'item ne disparaisse visuellement de la hotbar
                            SendNUIMessage({
                                action = 'updateInventory',
                                inventory = inventory,
                                container = CustomContainer
                            })
                        end
                    end)
                else
                    ESX.ShowNotification('~r~Vous êtes trop loin de votre véhicule.')
                end
            end
        end
    end
end)

local bagsOnGround = {}

RegisterNetEvent('az_inventory:spawnBagProp')
AddEventHandler('az_inventory:spawnBagProp', function(bagId, coords)
    local model = `prop_big_bag_01`
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    local obj = CreateObject(model, coords.x, coords.y, coords.z - 1.0, false, false, false)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)

    bagsOnGround[bagId] = obj
end)

-- Boucle de détection de la touche E
Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        local playerCoords = GetEntityCoords(PlayerPedId())

        for bagId, entity in pairs(bagsOnGround) do
            local bagCoords = GetEntityCoords(entity)
            local dist = #(playerCoords - bagCoords)

            if dist < 2.0 then
                sleep = 0
                ESX.ShowHelpNotification("Appuyez sur ~INPUT_CONTEXT~ pour ramasser le sac")
                if IsControlJustReleased(0, 38) then -- Touche E
                    TriggerServerEvent('az_inventory:pickupBag', bagId)
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('az_inventory:removeBagProp')
AddEventHandler('az_inventory:removeBagProp', function(bagId)
    if bagsOnGround[bagId] then
        -- Supprime l'objet physiquement
        DeleteEntity(bagsOnGround[bagId])
        -- Enlève la référence de la liste
        bagsOnGround[bagId] = nil
    end
end)
