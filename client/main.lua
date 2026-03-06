-- ============================================================
-- ESX Inventory – Client Script
-- Handles NUI toggle, controls, and item actions
-- ============================================================

ESX = exports['es_extended']:getSharedObject()
local isOpen = false

local CustomContainer = {}
local CustomShortkeys = {}
local CachedBag = {}  -- Full-data inventory from server (same format as protected container)
local CachedStash = {}
local spawnedBags = {}
local currentWeapon = nil
local nearbyBag = nil
local spawnedVehicle = nil
local spawnedVehicleModel = nil
local currentContainerType = 'protected' -- 'protected' or 'stash'

local weaponConfig = {
    ['AMMO_12']     = {"WEAPON_PUMPSHOTGUN", "WEAPON_SAWNOFFSHOTGUN", "WEAPON_BULLPUPSHOTGUN"},
    ['AMMO_45']     = {"WEAPON_PISTOL", "WEAPON_COMBATPISTOL", "WEAPON_APPISTOL", "WEAPON_VINTAGEPISTOL"},
    ['AMMO_50']     = {"WEAPON_SNIPERRIFLE", "WEAPON_HEAVYSNIPER", "WEAPON_MARKSMANRIFLE"},
    ['AMMO_556']    = {"WEAPON_CARBINERIFLE", "WEAPON_ADVANCEDRIFLE", "WEAPON_SPECIALCARBINE"},
    ['AMMO_762']    = {"WEAPON_ASSAULTRIFLE", "WEAPON_BULLPUPRIFLE", "WEAPON_COMBATMG"},
    ['AMMO_ROCKET'] = {"WEAPON_RPG", "WEAPON_HOMINGLAUNCHER", "WEAPON_COMPACTLAUNCHER"}
}

local function GetPlayerCash()
    local playerData = ESX.GetPlayerData()
    if playerData and playerData.accounts then
        for _, account in ipairs(playerData.accounts) do
            if account.name == 'money' then
                return account.money
            end
        end
    end
    return 0
end

function pickupBag(bagId)
    ESX.TriggerServerCallback('az_inventory:pickupBag', function(success)
    end, bagId)
end

function OpenInventory()
    if isOpen then return end
    if #CachedBag == 0 and #CustomContainer == 0 then return end

    isOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    
    local containerLabel = 'PROTECTED CONTAINER'
    if currentContainerType == 'stash' then
        containerLabel = 'MY CONTAINER'
    end

    SendNUIMessage({
        action = 'openInventory',
        inventory = CachedBag,
        container = currentContainerType == 'stash' and CachedStash or CustomContainer,
        shortkeys = CustomShortkeys,
        maxWeight = Config.MaxWeightBag,
        containerType = currentContainerType,
        containerLabel = containerLabel,
        playerName = GetPlayerName(PlayerId()),
        playerId = GetPlayerServerId(PlayerId()),
        money = GetPlayerCash()
    })
end

function RefreshInventoryNUI()
    if not isOpen then return end

    local containerLabel = 'PROTECTED CONTAINER'
    if currentContainerType == 'stash' then
        containerLabel = 'MY CONTAINER'
    end

    SendNUIMessage({
        action = 'openInventory',
        inventory = CachedBag,
        container = currentContainerType == 'stash' and CachedStash or CustomContainer,
        shortkeys = CustomShortkeys,
        maxWeight = Config.MaxWeightBag,
        containerType = currentContainerType,
        containerLabel = containerLabel,
        playerName = GetPlayerName(PlayerId()),
        playerId = GetPlayerServerId(PlayerId()),
        money = GetPlayerCash()
    })
end

function CloseInventory()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end

Citizen.CreateThread(function()
    while true do
        local sleep = 0
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        -- 1. GESTION DE L'INVENTAIRE (TAB)
        DisableControlAction(0, 37, true)
        
        if IsDisabledControlJustPressed(0, 37) then
            sleep = 0
            if isOpen then
                CloseInventory()
                SendNUIMessage({ action = 'closeInventory' })
                currentContainerType = 'protected'
            else
                if currentContainerType ~= 'stash' then
                    OpenInventory()
                end
            end
        end

        -- 2. LOGIQUE SI L'INVENTAIRE EST OUVERT
        if isOpen then
            sleep = 0
            -- Blocage des contrôles de combat/caméra
            DisableControlAction(0, 1, true) 
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true) 
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 47, true)
            DisableControlAction(0, 58, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)
            -- Autorise E et K même avec le focus
            EnableControlAction(0, 38, true)
            EnableControlAction(0, 311, true)
        else
            -- 3. LOGIQUE DES RACCOURCIS (1-5) - SEULEMENT SI FERMÉ
            local keys = {157, 158, 160, 164, 165}
            for i = 1, #keys do
                if IsControlJustReleased(0, keys[i]) or IsDisabledControlJustReleased(0, keys[i]) then
                    sleep = 0
                    local itemName = CustomShortkeys[i]
                    
                    if itemName and type(itemName) == 'string' then
                        local isNativeWeapon = (string.sub(string.upper(itemName), 1, 7) == "WEAPON_")
                        local isCustomWeapon = (Config and Config.WeaponItems and Config.WeaponItems[itemName] ~= nil)

                        if isNativeWeapon or isCustomWeapon then
                            -- Logique Armes (Ton code actuel est bon ici)
                            local weaponName = isCustomWeapon and Config.WeaponItems[itemName] or itemName
                            local weaponHash = GetHashKey(weaponName)
                            if currentWeapon == itemName then
                                SetCurrentPedWeapon(playerPed, GetHashKey("WEAPON_UNARMED"), true)
                                currentWeapon = nil
                            else
                                if HasPedGotWeapon(playerPed, weaponHash, false) then
                                    SetCurrentPedWeapon(playerPed, weaponHash, true)
                                    currentWeapon = itemName
                                    TriggerEvent('az_container:refreshWeaponComponents')
                                else
                                    ESX.TriggerServerCallback('az_inventory:useItem', function(success)
                                        if success then 
                                            currentWeapon = itemName 
                                            Citizen.Wait(500) -- Wait for weapon to be actually given
                                            TriggerEvent('az_container:refreshWeaponComponents')
                                        end
                                    end, itemName, i - 1)
                                end
                            end
                        else
                            -- --- CORRECTION POUR LES CONSOMMABLES ---
                            -- On demande directement au serveur d'utiliser l'item du slot
                            ESX.TriggerServerCallback('az_inventory:useItem', function(success)
                                -- On ne fait rien de spécial ici, le serveur va trigger useConsumable
                            end, itemName, i - 1)
                        end
                    end
                end
            end
        end

        -- 4. TOUCHE K (VÉHICULE) - OUVERT OU FERMÉ
        if (IsControlJustReleased(0, 311) or IsDisabledControlJustReleased(0, 311)) then
            if spawnedVehicle ~= nil and DoesEntityExist(spawnedVehicle) then
                sleep = 0
                local vehCoords = GetEntityCoords(spawnedVehicle)
                local dist = #(playerCoords - vehCoords)
                
                if dist < 10.0 or GetVehiclePedIsIn(playerPed, false) == spawnedVehicle then
                    local modelToReturn = spawnedVehicleModel or "deluxo"
                    ESX.Game.DeleteVehicle(spawnedVehicle)
                    spawnedVehicle = nil
                    spawnedVehicleModel = nil
                    TriggerServerEvent('az_inventory:returnVehicleItem', modelToReturn)
                    exports['az_notify']:ShowNotification('~g~Véhicule rangé dans votre inventaire !')

                    Citizen.SetTimeout(500, function()
                        if isOpen then RefreshInventoryNUI() end
                    end)
                else
                    exports['az_notify']:ShowNotification('~r~Vous êtes trop loin de votre véhicule.')
                end
            end
        end

        -- 5. DÉTECTION DES SACS
        local playerCoords2D = vector2(playerCoords.x, playerCoords.y) 
        
        for bagId, data in pairs(spawnedBags) do
            local bagCoords2D = vector2(data.coords.x, data.coords.y)
            local dist = #(playerCoords2D - bagCoords2D)
            
            if dist < 3.0 and not IsPedDeadOrDying(playerPed, true) then
                sleep = 0
                nearbyBag = bagId
                BeginTextCommandDisplayHelp("STRING")
                AddTextComponentSubstringPlayerName("Appuyez sur ~INPUT_CONTEXT~ ~w~pour ramasser le sac")
                EndTextCommandDisplayHelp(0, false, true, -1)

                if IsControlJustReleased(0, 38) then 
                    pickupBag(bagId)
                end
                
                break 
            end
        end

        Citizen.Wait(sleep)
    end
end)

RegisterNetEvent('az_inventory:spawnBagProp')
AddEventHandler('az_inventory:spawnBagProp', function(bagId, coords)
    local model = `prop_big_bag_01`
    
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    local obj = CreateObject(model, coords.x, coords.y, coords.z - 0.98, false, false, false)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityAsMissionEntity(obj, true, true)

    spawnedBags[bagId] = {obj = obj, coords = coords}
end)

RegisterNetEvent('az_inventory:removeBagProp')
AddEventHandler('az_inventory:removeBagProp', function(bagId)
    if spawnedBags[bagId] then
        DeleteEntity(spawnedBags[bagId].obj)
        spawnedBags[bagId] = nil
    end
end)

RegisterNetEvent('az_inventory:refreshInventoryUI')
AddEventHandler('az_inventory:refreshInventoryUI', function()
    if isOpen then
        RefreshInventoryNUI()
    end
end)

RegisterNetEvent('az_inventory:loadCustomData')
AddEventHandler('az_inventory:loadCustomData', function(container, shortkeys, fullBag, stash)
    CustomContainer = container or {}
    CustomShortkeys = shortkeys or {}
    CachedBag = fullBag or {}
    CachedStash = stash or {}
end)

RegisterNetEvent('az_inventory:updateInventory')
AddEventHandler('az_inventory:updateInventory', function(fullBag, protected, stash)
    if fullBag then CachedBag = fullBag end
    if protected then CustomContainer = protected end
    if stash then CachedStash = stash end
    if isOpen then RefreshInventoryNUI() end
end)

RegisterNetEvent('az_inventory:openStash')
AddEventHandler('az_inventory:openStash', function()
    if not isOpen then
        currentContainerType = 'stash'
        OpenInventory()
    end
end)

RegisterNUICallback('closeInventory', function(data, cb)
    CloseInventory()
    currentContainerType = 'protected'
    cb('ok')
end)

RegisterNUICallback('moveItem', function(data, cb)
    local playerPed = PlayerPedId()
    local selectedWeapon = GetSelectedPedWeapon(playerPed)
    
    -- Check if item being moved is the one in hand
    local actualWeaponName = data.item
    if Config and Config.WeaponItems and Config.WeaponItems[data.item] then
        actualWeaponName = Config.WeaponItems[data.item]
    end
    local weaponHash = GetHashKey(actualWeaponName)

    local isMovingFromPlayer = (data.fromZone == 'bag' or data.fromZone == 'shortkey')
    local isMovingToContainer = (data.toZone == 'container')

    if selectedWeapon == weaponHash and isMovingFromPlayer and isMovingToContainer then
        TriggerEvent('az_inventory:removeWeaponFromPed', data.item)
        exports['az_notify']:ShowNotification('Vous avez rangé votre arme')
    end

    ESX.TriggerServerCallback('az_inventory:moveItem', function(success, updatedContainer)
        if success then
            if updatedContainer then 
                if data.containerType == 'stash' then
                    CachedStash = updatedContainer
                else
                    CustomContainer = updatedContainer
                end
            end
            -- Le serveur va ensuite envoyer SyncPlayerInventory
        end
        cb({ success = success })
    end, data.fromZone, data.toZone, data.item, data.count, data.containerType)
end)

RegisterNUICallback('useItem', function(data, cb)
    ESX.TriggerServerCallback('az_inventory:useItem', function(success)
        if success then
            TriggerEvent('esx:onPlayerData', ESX.GetPlayerData())
        end
        cb({ success = success })
    end, data.item, data.slot)
end)

RegisterNUICallback('dropItem', function(data, cb)
    if currentWeapon and data.item == currentWeapon then
        TriggerEvent('az_inventory:removeWeaponFromPed', currentWeapon)
        exports['az_notify']:ShowNotification('~y~Arme déséquipée automatiquement.')
    end

    ESX.TriggerServerCallback('az_inventory:dropItem', function(success)
        -- Server sends SyncPlayerInventory which will update CachedBag via az_inventory:updateInventory
        cb({ success = success })
    end, data.item, data.count)
end)

RegisterNUICallback('giveItem', function(data, cb)
    if currentWeapon and data.item == currentWeapon then
        TriggerEvent('az_inventory:removeWeaponFromPed', currentWeapon)
        exports['az_notify']:ShowNotification('Vous avez rangé votre arme')
    end

    ESX.TriggerServerCallback('az_inventory:giveItem', function(success)
        cb({ success = success })
    end, data.item, data.count)
end)

RegisterNUICallback('setShortkey', function(data, cb)
    local slotIndex = data.slot + 1
    local oldItem = CustomShortkeys[slotIndex]
    
    if oldItem ~= nil and oldItem ~= false and oldItem == currentWeapon then
        local playerPed = PlayerPedId()
        
        SetCurrentPedWeapon(playerPed, GetHashKey("WEAPON_UNARMED"), true)
        
        local weaponHash = GetHashKey(oldItem)
        if Config and Config.WeaponItems and Config.WeaponItems[oldItem] then
            weaponHash = GetHashKey(Config.WeaponItems[oldItem])
        end
        RemoveWeaponFromPed(playerPed, weaponHash)
        
        currentWeapon = nil
        exports['az_notify']:ShowNotification('Vous avez rangé votre arme')    
    end

    if data.item == nil then
        CustomShortkeys[slotIndex] = false
    else
        CustomShortkeys[slotIndex] = data.item
    end
    
    TriggerServerEvent('az_inventory:setShortkey', data.slot, data.item)
    cb('ok')
end)

RegisterNetEvent('az_inventory:giveWeaponToPed')
AddEventHandler('az_inventory:giveWeaponToPed', function(itemName, actualWeaponName)
    local playerPed = PlayerPedId()
    local weaponToGive = actualWeaponName or itemName
    local weaponHash = GetHashKey(weaponToGive)

    if not HasPedGotWeapon(playerPed, weaponHash, false) then
        GiveWeaponToPed(playerPed, weaponHash, 30, false, true)
    end

    SetCurrentPedWeapon(playerPed, weaponHash, true)
    currentWeapon = itemName
end)

RegisterNetEvent('az_inventory:removeWeaponFromPed')
AddEventHandler('az_inventory:removeWeaponFromPed', function(itemName)
    local playerPed = PlayerPedId()
    local actualWeaponName = itemName
    if Config and Config.WeaponItems and Config.WeaponItems[itemName] then
        actualWeaponName = Config.WeaponItems[itemName]
    end
    local weaponHash = GetHashKey(actualWeaponName)
    
    -- Force disarm
    SetCurrentPedWeapon(playerPed, GetHashKey("WEAPON_UNARMED"), true)
    -- Remove weapon object
    RemoveWeaponFromPed(playerPed, weaponHash)
    
    if currentWeapon and itemName and string.upper(currentWeapon) == string.upper(itemName) then
        currentWeapon = nil
    end
end)

 RegisterNetEvent('az_inventory:spawnVehicle')
AddEventHandler('az_inventory:spawnVehicle', function(model)
    if spawnedVehicle and DoesEntityExist(spawnedVehicle) then
        exports['az_notify']:ShowNotification('~r~Vous avez déjà un véhicule sorti !')
        return
    end

    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)

    ESX.Game.SpawnVehicle(model, coords, heading, function(vehicle)
        spawnedVehicle = vehicle
        spawnedVehicleModel = model
        TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
        exports['az_notify']:ShowNotification('~g~Véhicule sorti ! Appuyez sur ~y~K ~g~pour le ranger.')
    end)
end)

RegisterNetEvent('az_inventory:useConsumable')
AddEventHandler('az_inventory:useConsumable', function(itemName)
    local playerPed = PlayerPedId()
    
    local animDict = "amb@medic@standing@tendtodead@idle_a"
    local animName = "idle_a"
    local duration = 1000

    exports['az_progressbars']:startUI(duration, "Applying...")

    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do Wait(10) end
    
    TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, duration, 1, 0, false, false, false)

    Wait(duration)

    if string.find(itemName, "MEDKIT") or string.find(itemName, "BANDAGE") or string.find(itemName, "GREEN") or string.find(itemName, "RED") then
        SetEntityHealth(playerPed, 200)
    end
    
    if string.find(itemName, "KEVLAR") or string.find(itemName, "BLUE") or string.find(itemName, "RED") then
        SetPedArmour(playerPed, 100)
    end

    ClearPedTasks(playerPed)
    ClearPedBloodDamage(playerPed)
    
    TriggerServerEvent('az_inventory:removeItemAfterUse', itemName)
end)

RegisterNetEvent('az_inventory:useAmmo')
AddEventHandler('az_inventory:useAmmo', function(ammoName, count, label)
    local ped = PlayerPedId()
    local weaponHash = GetSelectedPedWeapon(ped)

    if weaponHash ~= `WEAPON_UNARMED` then
        local found = false
        for _, weaponName in ipairs(weaponConfig[ammoName]) do
            if weaponHash == GetHashKey(weaponName) then
                found = true
                break
            end
        end

        if found then
            -- Animation de rechargement (optionnel)
            TaskReloadWeapon(ped, true)
            
            -- Ajout des munitions
            AddAmmoToPed(ped, weaponHash, count)
            
            -- Notification de succès
            exports['az_notify']:ShowNotification("~g~Rechargement effectué : ~s~" .. label .. " (+" .. count .. ")")
            
            -- On prévient le serveur de retirer l'item
            TriggerServerEvent('az_inventory:removeAmmoItem', ammoName)
        else
            exports['az_notify']:ShowNotification("~r~Ces munitions ne sont pas compatibles avec cette arme.")
        end
    else
        exports['az_notify']:ShowNotification("~r~Vous devez avoir une arme en main.")
    end
end)