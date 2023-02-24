local QBCore = _exports[Config.FrameworkResourceName]:GetCoreObject()
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

-- even though it is only 1 conversion it is defined as a function for possible future updates
local ConvertAccount = function(account)
    if account == "money" then
        return "cash"
    end

    return account
end

if IsDuplicityVersion() then
    return {
        Math = {
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
        },

        RegisterServerCallback = QBCore.Functions.CreateCallback,
        RegisterUsableItem = QBCore.Functions.CreateUseableItem,
        UseItem = QBCore.Functions.UseItem,

        GetPlayerFromId = function(source)
            local Player = QBCore.Functions.GetPlayer(source)
            local items = {}
            local weight = QBCore.Player.GetTotalWeight(Player.PlayerData.items)
            local maxWeight = 0

            for k,v in pairs(Player.PlayerData.items) do
                items[k] = ConvertItem(Player, v.slot)
            end

            -- Get max weight from the qb-inventory config
            if GetResourceState("qb-inventory") ~= "missing" then
                local configInventory = LoadResourceFile("qb-inventory", "config.lua")
                maxWeight = tonumber(configInventory:match("Config.MaxInventoryWeight = (%d+)"))
            end

            return {
                identifier = Player.PlayerData.citizenid,
                group = QBCore.Functions.GetPermission(source),
                job = {
                    name = Player.PlayerData.job.name,
                    label = Player.PlayerData.job.label,

                    grade = Player.PlayerData.job.grade.level,
                    grade_name = Player.PlayerData.job.grade.name,
                    grade_label = Player.PlayerData.job.grade.name,
                    grade_salary = Player.PlayerData.job.payment,
                },
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
                    for k, v in ipairs(QBCore.Config.Server.Permissions) do
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
                    return {
                        name = Player.PlayerData.job.name,
                        label = Player.PlayerData.job.label,
    
                        grade = Player.PlayerData.job.grade.level,
                        grade_name = Player.PlayerData.job.grade.name,
                        grade_label = Player.PlayerData.job.grade.name,
                        grade_salary = Player.PlayerData.job.payment,
                    } 
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
        end
    }
else
    return {
        TriggerServerCallback = QBCore.Functions.TriggerCallback
    }
end