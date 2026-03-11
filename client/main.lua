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
local isUsingItem = false

local weaponConfig = {
    ['AMMO_12'] = {
        "WEAPON_PUMPSHOTGUN", "WEAPON_SAWNOFFSHOTGUN", "WEAPON_BULLPUPSHOTGUN", 
        "WEAPON_ASSAULTSHOTGUN", "WEAPON_HEAVYSHOTGUN", 
        "WEAPON_DBLSHOTGUN", "WEAPON_AUTOSHOTGUN", "WEAPON_COMBATSHOTGUN", 
        "WEAPON_PUMPSHOTGUN_MK2"
    },

    ['AMMO_45'] = {
        "WEAPON_PISTOL", "WEAPON_COMBATPISTOL", "WEAPON_APPISTOL", 
        "WEAPON_SNSPISTOL", "WEAPON_VINTAGEPISTOL", "WEAPON_DOUBLEACTION", 
        "WEAPON_CERAMICPISTOL", "WEAPON_GADGETPISTOL", "WEAPON_PISTOL_MK2", 
        "WEAPON_SNSPISTOL_MK2", "WEAPON_MICROSMG", "WEAPON_SMG", 
        "WEAPON_ASSAULTSMG", "WEAPON_COMBATPDW", "WEAPON_MACHINEPISTOL", 
        "WEAPON_MINISMG", "WEAPON_SMG_MK2"
    },

    ['AMMO_50'] = {
        "WEAPON_PISTOL50", "WEAPON_HEAVYPISTOL", "WEAPON_MARKSMANPISTOL", 
        "WEAPON_REVOLVER", "WEAPON_REVOLVER_MK2", "WEAPON_SNIPERRIFLE", 
        "WEAPON_HEAVYSNIPER", "WEAPON_MARKSMANRIFLE", "WEAPON_PRECISIONRIFLE", 
        "WEAPON_HEAVYSNIPER_MK2", "WEAPON_MARKSMANRIFLE_MK2", "WEAPON_MUSKET"
    },

    ['AMMO_556'] = {
        "WEAPON_CARBINERIFLE", "WEAPON_ADVANCEDRIFLE", "WEAPON_SPECIALCARBINE", 
        "WEAPON_BULLPUPRIFLE", "WEAPON_MILITARYRIFLE", "WEAPON_TACTICALRIFLE", 
        "WEAPON_CARBINERIFLE_MK2", "WEAPON_SPECIALCARBINE_MK2", "WEAPON_BULLPUPRIFLE_MK2"
    },

    ['AMMO_762'] = {
        "WEAPON_ASSAULTRIFLE", "WEAPON_COMPACTRIFLE", "WEAPON_HEAVYRIFLE", 
        "WEAPON_ASSAULTRIFLE_MK2", "WEAPON_MG", "WEAPON_COMBATMG", 
        "WEAPON_COMBATMG_MK2"
    },

    ['AMMO_ROCKET'] = {
        "WEAPON_RPG", "WEAPON_HOMINGLAUNCHER", "WEAPON_COMPACTLAUNCHER", 
        "WEAPON_GRENADELAUNCHER","WEAPON_FLAREGUN"
    },
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
        money = GetPlayerCash(),
        autoReload = Config.AutoReloadOnEquip
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
        money = GetPlayerCash(),
        autoReload = Config.AutoReloadOnEquip
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

        -- Permanent Infinite Stamina
        RestorePlayerStamina(PlayerId(), 1.0)
        
        -- Disable Carkill
        SetWeaponDamageModifier(GetHashKey("VEHICLE_HIT"), 0.0)
        
        -- 0. DÉSACTIVER COUP DE CROSSE (MELEE) SI ARMÉ
        if IsPedArmed(playerPed, 6) then
            DisableControlAction(0, 140, true) 
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)
        end

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
                                local weaponToUnload = isCustomWeapon and Config.WeaponItems[itemName] or itemName
                                local weaponHashToUnload = GetHashKey(weaponToUnload)
                                local currentAmmo = GetAmmoInPedWeapon(playerPed, weaponHashToUnload)
                                TriggerServerEvent('az_inventory:updateWeaponAmmo', itemName, currentAmmo)

                                SetCurrentPedWeapon(playerPed, GetHashKey("WEAPON_UNARMED"), true)
                                currentWeapon = nil
                            else
                                if HasPedGotWeapon(playerPed, weaponHash, false) and not Config.AutoReloadOnEquip then
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
                            if isUsingItem then
                                exports['az_notify']:ShowNotification('~r~You are already using an item')
                            else
                                ESX.TriggerServerCallback('az_inventory:useItem', function(success)
                                    -- On ne fait rien de spécial ici, le serveur va trigger useConsumable
                                end, itemName, i - 1)
                            end
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
                    -- NEW: Restrictions (must be stationary and on ground)
                    local speed = GetEntitySpeed(spawnedVehicle) * 3.6 -- km/h
                    local IsOnGround = GetEntityHeightAboveGround(spawnedVehicle) < 5.0
                    
                    if speed > 5.0 then
                        exports['az_notify']:ShowNotification('~r~You must be stationary to store the vehicle !')
                    elseif not IsOnGround then
                        exports['az_notify']:ShowNotification('~r~Your vehicle must be on the ground to be stored !')
                    else
                        local modelToReturn = spawnedVehicleModel or "deluxo"
                        local mods = ESX.Game.GetVehicleProperties(spawnedVehicle)
                        ESX.Game.DeleteVehicle(spawnedVehicle)
                        spawnedVehicle = nil
                        spawnedVehicleModel = nil
                        TriggerServerEvent('az_inventory:returnVehicleItem', modelToReturn, mods)
                        exports['az_notify']:ShowNotification('~g~Vehicle stored')

                        Citizen.SetTimeout(500, function()
                            if isOpen then RefreshInventoryNUI() end
                        end)
                    end
                else
                    exports['az_notify']:ShowNotification('~r~You are too far of your vehicle')
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
                AddTextComponentSubstringPlayerName("Press ~INPUT_CONTEXT~ ~w~to claim the bag")
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
        local currentAmmo = GetAmmoInPedWeapon(playerPed, weaponHash)
        TriggerServerEvent('az_inventory:updateWeaponAmmo', data.item, currentAmmo)
        TriggerEvent('az_inventory:removeWeaponFromPed', data.item)
        exports['az_notify']:ShowNotification('You stored your weapon')
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
    if isUsingItem then
        exports['az_notify']:ShowNotification('~r~You are already using an item')
        cb({ success = false })
        return
    end

    if data.isAmmo then
        local ped = PlayerPedId()
        local weaponHash = GetSelectedPedWeapon(ped)
        local canUseAmmo = false

        if weaponHash ~= GetHashKey("WEAPON_UNARMED") then
            for _, weaponName in ipairs(weaponConfig[data.item] or {}) do
                if weaponHash == GetHashKey(weaponName) then
                    canUseAmmo = true
                    break
                end
            end
        end

        if not canUseAmmo then
            exports['az_notify']:ShowNotification("~r~You must have the corresponding weapon in hand to use this ammo.")
            cb({ success = false })
            return
        end
    end

    ESX.TriggerServerCallback('az_inventory:useItem', function(success)
        if success then
            TriggerEvent('esx:onPlayerData', ESX.GetPlayerData())
        end
        cb({ success = success })
    end, data.item, data.slot)
end)

RegisterNUICallback('notifyError', function(data, cb)
    exports['az_notify']:ShowNotification(data.message)
    cb('ok')
end)

RegisterNUICallback('dropItem', function(data, cb)
    if currentWeapon and data.item == currentWeapon then
        local playerPed = PlayerPedId()
        local weaponHash = GetSelectedPedWeapon(playerPed)
        local currentAmmo = GetAmmoInPedWeapon(playerPed, weaponHash)

        TriggerServerEvent('az_inventory:updateWeaponAmmo', data.item, currentAmmo)
        TriggerEvent('az_inventory:removeWeaponFromPed', currentWeapon)
        exports['az_notify']:ShowNotification('~y~Weapon automatically unequipped.')
    end

    ESX.TriggerServerCallback('az_inventory:dropItem', function(success)
        -- Server sends SyncPlayerInventory which will update CachedBag via az_inventory:updateInventory
        cb({ success = success })
    end, data.item, data.count)
end)

RegisterNUICallback('giveItem', function(data, cb)
    if currentWeapon and data.item == currentWeapon then
        local playerPed = PlayerPedId()
        local weaponHash = GetSelectedPedWeapon(playerPed)
        local currentAmmo = GetAmmoInPedWeapon(playerPed, weaponHash)

        TriggerServerEvent('az_inventory:updateWeaponAmmo', data.item, currentAmmo)
        TriggerEvent('az_inventory:removeWeaponFromPed', currentWeapon)
        exports['az_notify']:ShowNotification('You stored your weapon')
    end

    local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()

    if closestPlayer == -1 or closestDistance > 3.0 then
        exports['az_notify']:ShowNotification('~r~No player nearby.')
        cb({ success = false })
        return
    end

    ESX.TriggerServerCallback('az_inventory:giveItem', function(success)
        cb({ success = success })
    end, data.item, data.count, GetPlayerServerId(closestPlayer))
end)

RegisterNUICallback('setShortkey', function(data, cb)
    local slotIndex = data.slot + 1
    local oldItem = CustomShortkeys[slotIndex]
    
    if oldItem ~= nil and oldItem ~= false and oldItem == currentWeapon then
        local playerPed = PlayerPedId()
        
        local weaponHash = GetHashKey(oldItem)
        if Config and Config.WeaponItems and Config.WeaponItems[oldItem] then
            weaponHash = GetHashKey(Config.WeaponItems[oldItem])
        end

        local currentAmmo = GetAmmoInPedWeapon(playerPed, weaponHash)
        TriggerServerEvent('az_inventory:updateWeaponAmmo', oldItem, currentAmmo)

        SetCurrentPedWeapon(playerPed, GetHashKey("WEAPON_UNARMED"), true)
        RemoveWeaponFromPed(playerPed, weaponHash)
        
        currentWeapon = nil
        exports['az_notify']:ShowNotification('You stored your weapon')    
    end

    if data.item == nil then
        CustomShortkeys[slotIndex] = false
    else
        CustomShortkeys[slotIndex] = data.item
    end
    
    TriggerServerEvent('az_inventory:setShortkey', data.slot, data.item)
    cb('ok')
end)

RegisterNUICallback('getShopItems', function(data, cb)
    ESX.TriggerServerCallback('az_inventory:getShopItems', function(shopItems)
        local myIdentifier = ESX.GetPlayerData().identifier
        for _, it in ipairs(shopItems) do
            it.isMine = (it.identifier == myIdentifier)
        end
        SendNUIMessage({
            action = 'updateShop',
            shop = shopItems
        })
        cb('ok')
    end)
end)

RegisterNetEvent('az_inventory:updateShop')
AddEventHandler('az_inventory:updateShop', function(shopItems)
    local myIdentifier = ESX.GetPlayerData().identifier
    for _, it in ipairs(shopItems) do
        it.isMine = (it.identifier == myIdentifier)
    end
    SendNUIMessage({
        action = 'updateShop',
        shop = shopItems
    })
end)

RegisterNUICallback('sellItem', function(data, cb)
    TriggerServerEvent('az_inventory:sellItem', data.item, data.label, data.count, data.price)
    cb('ok')
end)

RegisterNUICallback('buyItem', function(data, cb)
    ESX.TriggerServerCallback('az_inventory:buyItem', function(success)
        cb({ success = success })
    end, data.id)
end)

RegisterNUICallback('getProfileData', function(data, cb)
    ESX.TriggerServerCallback('az_inventory:getProfileData', function(profileData)
        SendNUIMessage({
            action = 'updateProfile',
            data = profileData
        })
        cb('ok')
    end)
end)

RegisterNUICallback('removeItem', function(data, cb)
    ESX.TriggerServerCallback('az_inventory:removeItem', function(success)
        cb({ success = success })
    end, data.id)
end)

RegisterNetEvent('az_inventory:giveWeaponToPed')
AddEventHandler('az_inventory:giveWeaponToPed', function(itemName, actualWeaponName, ammoCount)
    local playerPed = PlayerPedId()
    local weaponToGive = actualWeaponName or itemName
    local weaponHash = GetHashKey(weaponToGive)
    local ammo = ammoCount or 0

    if not HasPedGotWeapon(playerPed, weaponHash, false) then
        GiveWeaponToPed(playerPed, weaponHash, ammo, false, true)
    else
        SetPedAmmo(playerPed, weaponHash, ammo)
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
AddEventHandler('az_inventory:spawnVehicle', function(model, mods)
    if spawnedVehicle and DoesEntityExist(spawnedVehicle) then
        exports['az_notify']:ShowNotification('~r~You already have a vehicle out!')
        return
    end

    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)

    ESX.Game.SpawnVehicle(model, coords, heading, function(vehicle)
        spawnedVehicle = vehicle
        spawnedVehicleModel = model
        
        if mods then
            ESX.Game.SetVehicleProperties(vehicle, mods)
        end
        
        TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
        exports['az_notify']:ShowNotification('~g~Vehicle out! Press ~y~K ~g~to store it.')
    end)
end)

RegisterNetEvent('az_inventory:useConsumable')
AddEventHandler('az_inventory:useConsumable', function(itemName)
    if isUsingItem then return end
    isUsingItem = true

    local playerPed = PlayerPedId()
    
    local animDict = "amb@medic@standing@tendtodead@base"
    local animName = "base"
    local duration = 1000

    exports['az_progressbars']:startUI(duration, "Applying item...")

    if not IsPedInAnyVehicle(playerPed, false) then
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do Wait(10) end
        
        TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, duration, 1, 0, false, false, false)
    end

    Wait(duration)

    if string.find(itemName, "MEDKIT") or string.find(itemName, "BANDAGE") then
        SetEntityHealth(playerPed, 200)
    elseif string.find(itemName, "RED") then
        -- Red Syringe: Heal to full
        SetEntityHealth(playerPed, 200)
    elseif string.find(itemName, "GREEN") then
        -- Green Syringe: Clear Zombies for 5 min
        TriggerEvent('az_zombie:clearZombies', 300000)
    elseif string.find(itemName, "BLUE") then
        -- Blue Syringe: Infinite stamina for 1 min
        TriggerEvent('az_inventory:infiniteStamina', 60000)
    end
    
    exports['az_notify']:ShowNotification("Item applied")
    
    if string.find(itemName, "KEVLAR") then
        SetPedArmour(playerPed, 100)
    end

    if not IsPedInAnyVehicle(playerPed, false) then
        ClearPedTasks(playerPed)
    end
    ClearPedBloodDamage(playerPed)
    
    TriggerServerEvent('az_inventory:removeItemAfterUse', itemName)
    isUsingItem = false
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
            AddAmmoToPed(ped, weaponHash, count)
        
            exports['az_notify']:ShowNotification("~g~Reload complete: ~s~" .. label .. " (+" .. count .. ")")
            
            -- On prévient le serveur de retirer l'item
            TriggerServerEvent('az_inventory:removeAmmoItem', ammoName)
        else
            exports['az_notify']:ShowNotification("~r~These ammos are not compatible with this weapon.")
        end
    else
        exports['az_notify']:ShowNotification("~r~You must have a weapon in hand.")
    end
end)

-- Effect handler for Blue Syringe (Infinite Stamina)
RegisterNetEvent('az_inventory:infiniteStamina')
AddEventHandler('az_inventory:infiniteStamina', function(duration)
    exports['az_notify']:ShowNotification("~b~You feel energized! (1 min)")
    
    local endTime = GetGameTimer() + duration
    
    Citizen.CreateThread(function()
        while GetGameTimer() < endTime do
            Citizen.Wait(0)
            RestorePlayerStamina(PlayerId(), 1.0)
        end
        exports['az_notify']:ShowNotification("~r~The effect of the blue syringe has worn off.")
    end)
end)

RegisterNetEvent('esx:onPlayerDeath')
AddEventHandler('esx:onPlayerDeath', function(data)
    -- data typically contains killerServerId, killerConnectionId, etc.
TriggerServerEvent('az_inventory:dropBagOnDeath', data.killerServerId)
end)

-- Drive-by restriction: Disable shooting and weapon wheel while in a vehicle
Citizen.CreateThread(function()
    while true do
        local sleep = 500
        local playerPed = PlayerPedId()
        
        if IsPedInAnyVehicle(playerPed, false) then
            sleep = 0
            -- Disables attacking/firing
            DisableControlAction(0, 24, true) -- Attack
            DisableControlAction(0, 69, true) -- Attack (Vehicle)
            DisableControlAction(0, 70, true) -- Attack (Vehicle)
            DisableControlAction(0, 92, true) -- Attack (Vehicle)
            DisableControlAction(0, 114, true) -- Aim (Vehicle)
            DisableControlAction(0, 257, true) -- Attack 2
            DisableControlAction(0, 331, true) -- Attack (Vehicle)
            
            -- Disables weapon selection/wheel
            DisableControlAction(0, 37, true)  -- Weapon Wheel (TAB)
            DisableControlAction(0, 81, true)  -- Vehicle Next Weapon
            DisableControlAction(0, 82, true)  -- Vehicle Previous Weapon
            DisableControlAction(0, 99, true)  -- Vehicle Select Next Weapon
            DisableControlAction(0, 100, true) -- Vehicle Select Previous Weapon
            DisableControlAction(0, 261, true) -- Mouse Wheel Next
            DisableControlAction(0, 262, true) -- Mouse Wheel Previous
            
            -- Force unarmed to be sure no weapon is visible
            if GetSelectedPedWeapon(playerPed) ~= `WEAPON_UNARMED` then
                SetCurrentPedWeapon(playerPed, `WEAPON_UNARMED`, true)
            end
        end
        
        Citizen.Wait(sleep)
    end
end)
