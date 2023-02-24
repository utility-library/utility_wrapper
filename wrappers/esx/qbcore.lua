-- DONE LIST | the following list is based on the ESX Legacy documentation
--[[
    Client {
        ✔ PlayerData
        ✔ Events
        Functions {
            ✔ GetPlayerData
        }
    }
    Common {
        ✔ Events
        Functions
    }
    Server {
        Functions {
            ✔ GetPlayerFromId
        }
        Onesync
        ✔ Events
        ✔ xPlayer
    }
]]



if Config.Framework == "qbcore" then
    local QBCore = exports[Config.FrameworkResourceName]:GetCoreObject()

    local weaponTints = {
        [0] = "weapontint_black",
        [1] = "weapontint_green",
        [2] = "weapontint_gold",
        [3] = "weapontint_pink",
        [4] = "weapontint_army",
        [5] = "weapontint_lspd",
        [6] = "weapontint_orange",
        [7] = "weapontint_plat",
    }

    local Math = {
        Round = function(value, numDecimalPlaces)
            if numDecimalPlaces then
                local power = 10^numDecimalPlaces
                return math.floor((value * power) + 0.5) / (power)
            else
                return math.floor(value + 0.5)
            end
        end,
        
        -- credit http://richard.warburton.it
        GroupDigits = function(value)
            local left,num,right = string.match(value,'^([^%d]*%d)(%d*)(.-)$')
        
            return left..(num:reverse():gsub('(%d%d%d)','%1' .. TranslateCap('locale_digit_grouping_symbol')):reverse())..right
        end,
        
        Trim = function(value)
            if value then
                return (string.gsub(value, "^%s*(.-)%s*$", "%1"))
            else
                return nil
            end
        end
    }

    local ConvertItem = function(Player, slot)
        local item = nil
        if type(slot) == "number" then
            item = Player.Functions.GetItemBySlot(slot)
        else
            item = slot
        end

        return {
            slot = item.slot,
            count = item.amount,
            weight = item.weight,
            close = item.shouldClose,
            name = item.name,
            stack = item.unique,
            label = item.label,
            metadata = item.info
        }
    end

    local ConvertJob = function(job)
        return  {
            name = job.name,
            label = job.label,

            grade = job.grade.level,
            grade_name = job.grade.name,
            grade_label = job.grade.name,
            grade_salary = job.payment,
        }
    end

    -- even though it is only 1 conversion it is defined as a function for possible future updates
    local ConvertAccount = function(account)
        if account == "money" then
            return "cash"
        end

        return account
    end

    local GetMaxWeightFromConfig = function()
        -- Get max weight from the qb-inventory config
        if GetResourceState("qb-inventory") ~= "missing" then
            local configInventory = LoadResourceFile("qb-inventory", "config.lua")
            return tonumber(configInventory:match("Config.MaxInventoryWeight = (%d+)"))
        end
    end

    Wrappers["esx"]["qbcore"] = function()
        if IsDuplicityVersion() then
            return {
                events = {
                    ["esx:onPlayerDeath"] = "utility_wrapper:esx:onPlayerDeath",
                    ["esx:playerLoaded"] = {
                        name = "QBCore:Server:PlayerLoaded",
                        hook = function(cb, Player)
                            --                                not implemented
                            cb(Player.PlayerData.source, Player, false)
                        end
                    },
                    ["esx:setAccountMoney"] = "QBCore:Server:OnMoneyChange",
                    ["esx:enteredVehicle"] = {
                        name = "baseevents:enteredVehicle",
                        hook = function(cb, clientVehicle, seat, displayName, netId)
                            local vehicle = NetworkGetEntityFromNetworkId(netId)

                            cb(GetVehicleNumberPlateText(vehicle), seat, displayName, netId)
                        end
                    },
                    ["esx:enteringVehicle"] = {
                        name = "baseevents:enteringVehicle",
                        hook = function(cb, clientVehicle, seat, displayName, netId)
                            local vehicle = NetworkGetEntityFromNetworkId(netId)

                            cb(GetVehicleNumberPlateText(vehicle), seat, netId)
                        end
                    },
                    ["esx:enteringVehicleAborted"] = {
                        name = "baseevents:enteringAborted",
                        hook = function(cb)
                            cb()
                        end
                    },
                    ["esx:exitedVehicle"] = {
                        name = "baseevents:leftVehicle",
                        hook = function(cb, clientVehicle, seat, displayName, netId)
                            local vehicle = NetworkGetEntityFromNetworkId(netId)

                            cb(GetVehicleNumberPlateText(vehicle), seat, displayName, netId)
                        end
                    },
                    ["esx:setJob"] = {
                        name = "QBCore:Server:OnJobUpdate",
                        hook = function(cb, source, job)
                            cb(source, ConvertJob(job), {})      
                        end
                    },
                },
                object = {
                    Math = Math,
        
                    RegisterServerCallback = QBCore.Functions.CreateCallback,
                    RegisterUsableItem = QBCore.Functions.CreateUseableItem,
                    UseItem = QBCore.Functions.UseItem,
        
                    GetPlayerFromId = function(source)
                        local Player = QBCore.Functions.GetPlayer(source)
                        local items = {}
                        local weight = QBCore.Player.GetTotalWeight(Player.PlayerData.items)
                        local maxWeight = GetMaxWeightFromConfig()
        
                        for k,v in pairs(Player.PlayerData.items) do
                            items[k] = ConvertItem(Player, v.slot)
                        end
        
                        return {
                            identifier = Player.PlayerData.citizenid,
                            group = QBCore.Functions.GetPermission(source),
                            job = ConvertJob(Player.PlayerData.job),
                            inventory = items,
                            name = Player.PlayerData.name,
                            license = Player.PlayerData.license,
                            coords = Player.PlayerData.position,
                            weight = weight,
                            maxWeight = maxWeight,
                            playerId = Player.PlayerData.source,
                            source = Player.PlayerData.source,
                            loadout = {},
                            variables = Player.PlayerData.metadata,
                            accounts = {
                                {
                                    label = "money",
                                    index = 1,
                                    name = "money",
                                    round = true,
                                    money = Player.Functions.GetMoney("money")
                                },
                                {
                                    label = "bank",
                                    index = 2,
                                    name = "bank",
                                    round = true,
                                    money = Player.Functions.GetMoney("bank")
                                },
                                {
                                    label = "black_money",
                                    index = 3,
                                    name = "black_money",
                                    round = true,
                                    money = 0
                                },
                            },
        
                            kick = function(reason)
                                DropPlayer(source, reason)
                            end,
                            removeInventoryItem = Player.Functions.RemoveItem,
                            addInventoryItem = Player.Functions.AddItem,
                            setInventoryItem = function(name, value)
                                local item = Player.Functions.GetItemByName(name)
        
                                Player.Functions.RemoveItem(name, item.amount)
                                Player.Functions.AddItem(name, value)
                            end,
                            getInventoryItem = function(name)
                                local item = Player.Functions.GetItemByName(name)
        
                                return ConvertItem(Player, item)
                            end,
                            canCarryItem = function(name, count)
                                local item = Player.Functions.GetItemByName(name)
                                local newWeight = weight + (item.weight * count)
        
                                return newWeight <= maxWeight
                            end,
                            canSwapItem = function(firstItem, firstItemCount, testItem, testItemCount)
                                local firstItemObject = Player.Functions.GetItemByName(firstItem)
                                local testItemObject = Player.Functions.GetItemByName(testItem)
        
                                if firstItemObject.amount >= firstItemCount then
                                    local weightWithoutFirstItem = math.floor(self.weight - (firstItemObject.weight * firstItemCount))
                                    local weightWithTestItem = math.floor(weightWithoutFirstItem + (testItemObject.weight * testItemCount))
        
                                    return weightWithTestItem <= maxWeight
                                end
        
                                return false
                            end,
                            hasItem = function(item, metadata) -- we can't check the metadata since i couldn't find any function to get the filtered item with the metadata
                                return Player.Functions.GetItemByName(name) ~= nil
                            end,
        
        
                            removeWeapon = function(name)
                                Player.Functions.RemoveItem(name, 1)
                            end,
                            addWeapon = function(name, ammo)
                                Player.Functions.AddItem(name, 1, nil, {ammo = ammo})
                                SetPedAmmo(GetPlayerPed(source), GetHashKey(name), ammo)
                            end,
        
                            hasWeapon = function(name)
                                return Player.Functions.GetItemByName(name) ~= nil
                            end,
        
                            setWeaponTint = function(weaponName, weaponTintIndex)
                                -- qb-weapons does not allow to set the tint of a weapon that is not selected (doesnt have any exports), so i simply give the item
                                Player.Functions.AddItem(weaponTints[weaponTintIndex], 1)
                            end,
        
                            addWeaponAmmo = function(weaponName, ammo)
                                local item = Player.Functions.GetItemByName(name)
        
                                if Player.PlayerData.items[item.slot] then
                                    Player.PlayerData.items[item.slot].info.ammo = item.info.ammo + ammo
                                end
                                Player.Functions.SetInventory(Player.PlayerData.items, true)
        
                                local player = GetPlayerPed(source)
                                local totalAmmo = GetAmmoInPedWeapon(player, GetHashKey(name))
                                SetPedAmmo(player, GetHashKey(name), totalAmmo + ammo)
                            end,
                            removeWeaponAmmo = function(weaponName, ammo)
                                local item = Player.Functions.GetItemByName(name)
        
                                if Player.PlayerData.items[item.slot] then
                                    Player.PlayerData.items[item.slot].info.ammo = item.info.ammo - ammo
                                end
                                Player.Functions.SetInventory(Player.PlayerData.items, true)
        
                                local player = GetPlayerPed(source)
                                local totalAmmo = GetAmmoInPedWeapon(player, GetHashKey(name))
                                SetPedAmmo(player, GetHashKey(name), totalAmmo - ammo)
                            end,
        
                            set = Player.Functions.SetMetaData,
                            get = Player.Functions.GetMetaData,
        
                            addAccountMoney = function(account, value)
                                Player.Functions.AddMoney(ConvertAccount(account), value)
                            end,
                            removeAccountMoney = function(account, value)
                                Player.Functions.RemoveMoney(ConvertAccount(account), value)
                            end,
                            setAccountMoney = function(account, value)
                                Player.Functions.SetMoney(ConvertAccount(account), value)
                            end,
                            getAccount = function(account, value)
                                return {
                                    name = account,
                                    label = account,
                                    money = Player.Functions.GetMoney(ConvertAccount(account))
                                }
                            end,
                            getAccounts = function(account, value)
                                return {
                                    {
                                        name = "money",
                                        label = "money",
                                        money = Player.Functions.GetMoney("cash")
                                    },
                                    {
                                        name = "bank",
                                        label = "bank",
                                        money = Player.Functions.GetMoney("bank")
                                    },
                                    {
                                        name = "black_money",
                                        label = "black_money",
                                        money = 0
                                    },
                                }
                            end,
        
                            addMoney = function(value)
                                Player.Functions.AddMoney("cash", value)
                            end,
                            removeMoney = function(value)
                                Player.Functions.RemoveMoney("cash", value)
                            end,
                            setMoney = function(value)
                                Player.Functions.SetMoney("cash", value)
                            end,
                            getMoney = function()
                                return Player.Functions.GetMoney("cash")
                            end,
        
                            setCoords = function(coords)
                                local player = GetPlayerPed(id)
        
                                if type(coords) == "vector3" then
                                    SetEntityCoords(player, coords)
                                else
                                    SetEntityCoords(player, coords.x, coords.y, coords.z)
                                    SetEntityHeading(player, coords.heading)
                                end
                            end,
                            setName = function(newName)
                                Player.Functions.SetPlayerData("name", newName)
                            end,
                            getWeight = function()
                                return weight
                            end,
                            getMaxWeight = function()
                                return maxWeight
                            end,
                            getInventory = function()
                                return inventory
                            end,
                            getName = function()
                                return Player.PlayerData.name
                            end,
                            getIdentifier = function()
                                return Player.PlayerData.citizenid
                            end,
                            showNotification = function(msg)
                                TriggerClientEvent('QBCore:Notify', source, msg, "primary")
                            end,
                            showHelpNotification = function(msg)
                                TriggerClientEvent('QBCore:Notify', source, msg, "primary")
                            end,
        
                            getGroup = function(msg)
                                for k,v in ipairs(QBCore.Config.Server.Permissions) do
                                    if IsPlayerAceAllowed(source, v) then
                                        return v
                                    end
                                end
                            end,
        
                            getCoords = function(vector)
                                if vector then
                                    return vector3(Player.PlayerData.position.x, Player.PlayerData.position.y, Player.PlayerData.position.z)
                                else
                                    return Player.PlayerData.position
                                end
                            end,
        
                            setJob = Player.Functions.SetJob,
                            getJob = function()
                                return ConvertJob(Player.PlayerData.job)
                            end,
        
                            -- not implemented
                            setMaxWeight = function() -- it seems that in qbcore there is no method to set the maximum weight, also because there is also no method to obtain it
                                error("[Utility Wrapper] the method 'setMaxWeight' is not yet implemented")
                                return false
                            end,
                            
                            getLoadout = function()
                                error("[Utility Wrapper] the method 'getLoadout' is not yet implemented")
                                return false
                            end,
        
                            triggerEvent = function(eventName, ...)
                                TriggerClientEvent(eventName, source, ...)
                            end,
        
                            -- it seems that the qb-weapons resource has 0 api for developers, i haven't seen even one export, so for now they are not implemented
                            getWeaponTint = function()
                                error("[Utility Wrapper] the method 'getWeaponTint' is not yet implemented")
                                return false
                            end,
                            removeWeaponComponent = function(weaponName, weaponTintIndex)
                                error("[Utility Wrapper] the method 'removeWeaponComponent' is not yet implemented")
                                -- to do
                                return "todo"    
                            end,
                            addWeaponComponent = function(weaponName, weaponTintIndex)
                                error("[Utility Wrapper] the method 'addWeaponComponent' is not yet implemented")
                                -- to do
                                return "todo"
                            end,
                            hasWeaponComponent = function(weaponName, weaponTintIndex)
                                error("[Utility Wrapper] the method 'hasWeaponComponent' is not yet implemented")
                                -- to do
                                return "todo"
                            end,
                        }
                    end,
                }
            }
        else
            local oldItems = {}
            local vehicleCheckerActive = false
            local activeChecks = {
                enteredVehicle = {},
                enteringVehicle = {},
                enteringVehicleAborted = {},
                exitedVehicle = {},
            }
        
            local VehicleChecker = function()
                local GetPedVehicleSeat = function(player)
                    local vehicle = GetVehiclePedIsIn(player)
            
                    for i=-1, GetVehicleMaxNumberOfPassengers(vehicle) do
                        if GetPedInVehicleSeat(vehicle, i) == player then 
                            return i
                        end
                    end
                end
                
                -- run the loop only if it is not already started, to avoid multiple loops running at the same time
                if not vehicleCheckerActive then
                    vehicleCheckerActive = true
            
                    -- loop to simulate the events
                    Citizen.CreateThread(function()
                        local inVehicle = false
                        local isEnteringVehicle = false
                        local currentVehicle = 0
                        local currentSeat = 0
            
                        while true do
                            local player = PlayerPedId()
            
                            if IsPedInAnyVehicle(player, false) and not IsPlayerDead(PlayerId()) then
                                if not inVehicle then
                                    currentVehicle = GetVehiclePedIsIn(player)
                                    currentSeat = GetPedVehicleSeat(player)

                                    local plate = GetVehicleNumberPlateText(currentVehicle)
                                    local model = GetEntityModel(currentVehicle)
                                    local name = GetDisplayNameFromVehicleModel(model)
                                    local netId = NetworkGetNetworkIdFromEntity(currentVehicle)

                                    -- empty table check must be here because otherwise would not work for only "exited event" or for "only entered" event 
                                    if next(activeChecks.enteredVehicle) ~= nil then
                                        for k,cb in ipairs(activeChecks.enteredVehicle) do
                                            cb(
                                                currentVehicle, 
                                                plate, 
                                                currentSeat, 
                                                name, 
                                                netId
                                            )
                                        end
                                    end
            
                                    inVehicle = true
                                    isEnteringVehicle = false
                                end
                            else
                                if inVehicle then
                                    local plate = GetVehicleNumberPlateText(currentVehicle)
                                    local model = GetEntityModel(currentVehicle)
                                    local name = GetDisplayNameFromVehicleModel(model)
                                    local netId = NetworkGetNetworkIdFromEntity(currentVehicle)

                                    -- empty table check must be here because otherwise would not work for only "exited event" or for "only entered" event 
                                    if next(activeChecks.exitedVehicle) ~= nil then
                                        for k,cb in ipairs(activeChecks.exitedVehicle) do
                                            cb(
                                                currentVehicle, 
                                                plate, 
                                                currentSeat, 
                                                name, 
                                                netId
                                            )
                                        end
                                    end
                                    TriggerServerEvent('esx:exitedVehicle', currentVehicle, plate, currentSeat, name, netId)

                                    currentVehicle = 0
                                    currentSeat = 0
                                    inVehicle = false
                                end
                            end
            
                            if next(activeChecks.enteringVehicle) ~= nil then
                                if not isEnteringVehicle and not inVehicle then
                                    local vehicle = GetVehiclePedIsTryingToEnter(player)
        
                                    if DoesEntityExist(vehicle) then
                                        local seat = GetSeatPedIsTryingToEnter(ped)
                                        isEnteringVehicle = true
        
                                        for k,cb in ipairs(activeChecks.enteringVehicle) do
                                            cb(
                                                vehicle, 
                                                GetVehicleNumberPlateText(vehicle), 
                                                seat, 
                                                NetworkGetNetworkIdFromEntity(vehicle)
                                            )
                                        end
                                    end
                                end
                            end
        
                            if isEnteringVehicle and not inVehicle then
                                local vehicle = GetVehiclePedIsTryingToEnter(player)
        
                                if not DoesEntityExist(vehicle) and not IsPedInAnyVehicle(ped, true) then
                                    isEnteringVehicle = false
        
                                    -- control must be here because otherwise the variable would not reset if it is aborted
                                    if next(activeChecks.enteringVehicleAborted) ~= nil then
                                        for k,cb in ipairs(activeChecks.enteringVehicleAborted) do
                                            cb()
                                        end
                                    end
                                end
                            end
        
                            Citizen.Wait(100)
                        end
                    end)
                end
            end
            
            return {
                events = {
                    -- not implemented
                    -- ["esx:playerPedChanged"]
                    -- ["esx:playerJumping"]
                    ["esx:onPlayerDeath"] = "utility_wrapper:esx:onPlayerDeath",
                    ["esx:addInventoryItem"] = {
                        name = "QBCore:Player:SetPlayerData",
                        hook = function(cb, PlayerData)
                            if next(oldItems) == nil then
                                for k,v in pairs(PlayerData.items) do
                                    oldItems[v.name] = v.amount
                                end
                            else
                                for k,v in pairs(PlayerData.items) do
                                    if not oldItems[v.name] then -- new
                                        oldItems[v.name] = v.amount
                                        cb(v.name, v.amount)
        
                                    elseif oldItems[v.name] < v.amount then -- added
                                        oldItems[v.name] = v.amount
                                        cb(v.name, v.amount)
        
                                    elseif oldItems[v.name] > v.amount then -- removed (dont log)
                                        oldItems[v.name] = v.amount
                                    end
                                end
                            end
                        end
                    },
                    ["esx:playerLoaded"] = {
                        name = "QBCore:Client:OnPlayerLoaded",
                        hook = function(cb)
                            local player = QBCore.Functions.GetPlayerData()
        
                            cb(player, false, {})
                        end
                                
                    },
                    ["esx:pauseMenuActive"] = {
                        faker = function(cb)
                            Citizen.CreateThread(function()
                                local inPauseMenu = false
        
                                while true do
                                    if IsPauseMenuActive() and not inPauseMenu then
                                        inPauseMenu = true
                                        cb(inPauseMenu)
                                    elseif not IsPauseMenuActive() and inPauseMenu then
                                        inPauseMenu = false
                                        cb(inPauseMenu)
                                    end
                                    Citizen.Wait(2000)
                                end
                            end)
                        end
                    },
                    ["esx:setAccountMoney"] = {
                        name = "QBCore:Client:OnMoneyChange",
                        hook = function(cb, account, ammount, action, reason)
                            cb({
                                name = account,
                                label = account,
                                money = amount,
                            })
                        end
                    },
                    ["esx:enteredVehicle"] = {
                        faker = function(cb)
                            table.insert(activeChecks.enteredVehicle, cb)
                            VehicleChecker()
                        end
                    },
                    ["esx:enteringVehicle"] = {
                        faker = function(cb)
                            table.insert(activeChecks.enteringVehicle, cb)
                            VehicleChecker()
                        end
                    },
                    ["esx:enteringVehicleAborted"] = {
                        faker = function(cb)
                            table.insert(activeChecks.enteringVehicleAborted, cb)
                            VehicleChecker()
                        end
                    },
                    ["esx:exitedVehicle"] = {
                        faker = function(cb)
                            table.insert(activeChecks.exitedVehicle, cb)
                            VehicleChecker()
                        end
                    },
                    ["esx:setJob"] = {
                        name = "QBCore:Client:OnJobUpdate",
                        hook = function(cb, job)
                            cb(ConvertJob(job), {})      
                        end
                    },
                },
                object = {
                    Math = Math,
                    TriggerServerCallback = QBCore.Functions.TriggerCallback,
                    GetPlayerData = function()
                        local Player = QBCore.Functions.GetPlayerData()
                        local weight = 0
                        local items = {}
        
                        for k,v in pairs(Player.items) do
                            items[k] = ConvertItem(Player, v)
                            weight = weight + (v.weight * v.amount)
                        end
        
                        return {
                            ped = PlayerPedId(),
                            identifier = Player.citizenid,
                            weight = weight,
                            maxWeight = GetMaxWeightFromConfig(),
                            dead = Player.metadata.isdead,
                            firstName = Player.charinfo.firstname,
                            lastName = Player.charinfo.lastname,
                            sex = Player.charinfo.gender == 0 and "m" or "f",
                            dateofbirth = Player.charinfo.birthdate,
                            money = Player.money.cash,
                            coords = Player.position,
                            inventory = items,
                            job = ConvertJob(Player.job),
                            accounts = {
                                {
                                    name = "money",
                                    label = "money",
                                    money = Player.money.cash
                                },
                                {
                                    name = "bank",
                                    label = "bank",
                                    money = Player.money.bank
                                },
                                {
                                    name = "black_money",
                                    label = "black_money",
                                    money = 0
                                },
                            },
        
                            -- not implemented
                            height = 0,
                            loadout = {},
                        }
                    end
                }
            }
        end
    end
end