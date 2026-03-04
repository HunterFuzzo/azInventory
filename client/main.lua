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

-- Receive data from server on load
RegisterNetEvent('esx_inventory:loadCustomData')
AddEventHandler('esx_inventory:loadCustomData', function(container, shortkeys)
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

-- ─── Close Inventory ──────────────────────────────────────
function CloseInventory()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
end

-- ─── Key Binding (TAB) ───────────────────────────────────
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        -- Disable weapon wheel (TAB=37, 192), (L1/LB = 157, 158, 159, 160)
        DisableControlAction(0, 37, true)
        DisableControlAction(0, 192, true)
        DisableControlAction(0, 204, true)
        DisableControlAction(0, 211, true)
        DisableControlAction(0, 349, true)
        DisableControlAction(0, 157, true)
        DisableControlAction(0, 158, true)
        DisableControlAction(0, 159, true)
        DisableControlAction(0, 160, true)
        
        -- Override TAB key to toggle inventory manually
        if IsDisabledControlJustReleased(0, 37) then -- TAB key
            if isOpen then
                CloseInventory()
                SendNUIMessage({ action = 'closeInventory' })
            else
                OpenInventory()
            end
        end

        -- Disable controls while inventory is open
        if isOpen then
            DisableControlAction(0, 1, true)   -- LookLeftRight
            DisableControlAction(0, 2, true)   -- LookUpDown
            DisableControlAction(0, 24, true)  -- Attack
            DisableControlAction(0, 25, true)  -- Aim
            DisableControlAction(0, 30, true)  -- MoveLeftRight
            DisableControlAction(0, 31, true)  -- MoveUpDown
            DisableControlAction(0, 36, true)  -- Duck
            DisableControlAction(0, 44, true)  -- Cover
            DisableControlAction(0, 47, true)  -- Detonate
            DisableControlAction(0, 58, true)  -- Throw Grenade
            DisableControlAction(0, 140, true) -- Melee Light
            DisableControlAction(0, 141, true) -- Melee Heavy
            DisableControlAction(0, 142, true) -- Melee Alternate
            DisableControlAction(0, 143, true) -- Melee Block
            DisableControlAction(0, 257, true) -- Attack2
            DisableControlAction(0, 263, true) -- Melee Attack1
        end
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
    ESX.TriggerServerCallback('esx_inventory:moveItem', function(success, updatedContainer)
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
    ESX.TriggerServerCallback('esx_inventory:useItem', function(success)
        if success then
            TriggerEvent('esx:onPlayerData', ESX.GetPlayerData())
        end
        cb({ success = success })
    end, data.item, data.slot)
end)

-- Drop item
RegisterNUICallback('dropItem', function(data, cb)
    ESX.TriggerServerCallback('esx_inventory:dropItem', function(success)
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
    ESX.TriggerServerCallback('esx_inventory:giveItem', function(success)
        cb({ success = success })
    end, data.item, data.count)
end)

-- Set shortkey
RegisterNUICallback('setShortkey', function(data, cb)
    -- data is { slot: Number, item: String|null }
    if data.item == nil then
        CustomShortkeys[data.slot + 1] = false
    else
        CustomShortkeys[data.slot + 1] = data.item
    end
    
    TriggerServerEvent('esx_inventory:setShortkey', data.slot, data.item)
    cb('ok')
end)

-- ─── Weapon & Shortkey Usage (1-5 keys) ───────────────────
local currentWeapon = nil -- Track the currently equipped weapon from shortkey

-- Reçu du serveur : donner physiquement l'arme au ped et l'équiper
RegisterNetEvent('esx_inventory:giveWeaponToPed')
AddEventHandler('esx_inventory:giveWeaponToPed', function(weaponName)
    local playerPed = PlayerPedId()
    local weaponHash = GetHashKey(weaponName)

    -- Donner l'arme avec munitions par défaut si non possédée
    if not HasPedGotWeapon(playerPed, weaponHash, false) then
        GiveWeaponToPed(playerPed, weaponHash, 30, false, true)
    end

    SetCurrentPedWeapon(playerPed, weaponHash, true)
    currentWeapon = weaponName
    print('[esx_inventory] Weapon given to ped and equipped: ' .. weaponName)
end)

-- Reçu du serveur : retirer physiquement l'arme du ped
RegisterNetEvent('esx_inventory:removeWeaponFromPed')
AddEventHandler('esx_inventory:removeWeaponFromPed', function(weaponName)
    local playerPed = PlayerPedId()
    local weaponHash = GetHashKey(weaponName)
    RemoveWeaponFromPed(playerPed, weaponHash)
    if currentWeapon == weaponName then
        currentWeapon = nil
    end
    print('[esx_inventory] Weapon removed from ped: ' .. weaponName)
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if not isOpen then
            -- Keys 1-5 for shortkeys
            for i = 1, 5 do
                if IsControlJustReleased(0, 156 + i) then -- Keys 1-5
                    local itemName = CustomShortkeys[i]
                    if itemName and type(itemName) == 'string' then
                        if string.sub(string.upper(itemName), 1, 7) == "WEAPON_" then
                            -- Handle weapon equip/unequip
                            local playerPed = PlayerPedId()
                            local weaponHash = GetHashKey(itemName)

                            if currentWeapon == itemName then
                                -- Dé-équiper : remettre les poings
                                SetCurrentPedWeapon(playerPed, GetHashKey("WEAPON_UNARMED"), true)
                                currentWeapon = nil
                            elseif HasPedGotWeapon(playerPed, weaponHash, false) then
                                -- L'arme est déjà sur le ped : équiper directement
                                SetCurrentPedWeapon(playerPed, weaponHash, true)
                                currentWeapon = itemName
                            else
                                -- L'arme existe seulement en tant qu'item : appeler useItem
                                -- Le serveur vérifie la possession et envoie giveWeaponToPed
                                ESX.TriggerServerCallback('esx_inventory:useItem', function(success)
                                    if not success then
                                        print('[esx_inventory] useItem failed for weapon: ' .. tostring(itemName))
                                    end
                                    -- L'équipement est géré par l'event giveWeaponToPed reçu du serveur
                                end, itemName, i - 1)
                            end
                        else
                            -- Item normal
                            ESX.TriggerServerCallback('esx_inventory:useItem', function(success)
                                if not success then
                                    print('[esx_inventory] useItem failed for item: ' .. tostring(itemName))
                                end
                            end, itemName, i - 1)
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

RegisterNetEvent('esx_inventory:spawnVehicle')
AddEventHandler('esx_inventory:spawnVehicle', function(model)
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
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if IsControlJustReleased(0, 311) then -- K key
            if spawnedVehicle and DoesEntityExist(spawnedVehicle) then
                local playerPed = PlayerPedId()
                
                -- Check if player is near or inside the vehicle to store it
                local dist = #(GetEntityCoords(playerPed) - GetEntityCoords(spawnedVehicle))
                if dist < 5.0 or GetVehiclePedIsIn(playerPed, false) == spawnedVehicle then
                    
                    ESX.Game.DeleteVehicle(spawnedVehicle)
                    spawnedVehicle = nil
                    
                    if spawnedVehicleModel then
                        TriggerServerEvent('esx_inventory:returnVehicleItem', spawnedVehicleModel)
                        spawnedVehicleModel = nil
                    else
                        TriggerServerEvent('esx_inventory:returnVehicleItem', 'deluxo') -- fallback
                    end
                    ESX.ShowNotification('~g~Véhicule rangé dans votre inventaire !')
                else
                    ESX.ShowNotification('~r~Vous êtes trop loin de votre véhicule.')
                end
            end
        end
    end
end)
