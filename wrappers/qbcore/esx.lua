local ESX = _exports[Config.FrameworkResourceName]:getSharedObject()
local ESXConfig = ESX.GetConfig().Config

local ConvertItem = function(xPlayer, name, metadata)
    local item = xPlayer.getInventoryItem(name)
    
    if ESXConfig.OxInventory then
        local oxItem = nil
        
        if metadata.weight then -- metadata its an item
            oxItem = metadata
        else
            oxItem = xPlayer.getInventoryItem(name, metadata)
        end
    
        return {
            name = item.name,
            label = item.label,
            type = "item",
            useable = item.usable,
            weight = oxItem.weight,
            amount = item.count,
            slot = item.slot,
            info = item.metadata,
            unique = oxItem.stack,
            shouldClose = oxItem.close,
            
            wrapped = true -- traces
        }
    else
        return {
            name = name,
            label = ESX.GetItemLabel(name),
            type = "item",
            useable = item.usable,
            weight = item.weight,
            amount = item.count,
            --
            slot = -1,
            info = {},
            unique = false,
            
            wrapped = true -- traces
        }
    end
end

-- even though it is only 1 conversion it is defined as a function for possible future updates
local ConvertAccount = function(account)
    if account == "cash" then
        return "money"
    end

    return account
end

local TriggerSyncEvent = function(eventName, ...)
    local value = promise:new()

    TriggerEvent(eventName, ..., function(retval)
        value:resolve(retval)
    end)

    return Citizen.Await(value)
end

local GetStatusValue = function(type)
    local status = TriggerSyncEvent('esx_status:getStatus', type)

    return status.getPercent()
end

if IsDuplicityVersion() then
    return = {
        Functions = {
            UseItem = ESX.UseItem,
            CreateCallback = ESX.RegisterServerCallback,
            CreateUseableItem = function(name, cb)

                if ESXConfig.OxInventory then
                    ESX.RegisterUsableItem(name, function(source, _, item)
                        local xPlayer = ESX.GetPlayerFromId(source)
                        local oxItem = xPlayer.getInventoryItem(name, item.metadata)

                        cb(source, ConvertItem(xPlayer, name, item.metadata))
                    end)
                else
                    ESX.RegisterUsableItem(name, function(source)
                        local xPlayer = ESX.GetPlayerFromId(source)

                        cb(source, ConvertItem(xPlayer, name))
                    end)
                end
            end,

            GetPlayer = function(source)
                local xPlayer = ESX.GetPlayerFromId(source)
                local items = {}
                local licences = TriggerSyncEvent("esx_license:getLicenses")
                local metadata = {
                    licences = {
                        business = false, -- dont exist in esx
                        driver = licences["dmv"],
                        weapon = licences["weapon"]
                    },
                    isdead = xPlayer.variables.dead,
                    armor = GetPedArmour(GetPlayerPed(xPlayer.source)),

                    -- not implemented
                    ishandcuffed = false,
                    tracker = false,
                    inlaststand = false,
                    inside = {
                        apartment = {}
                    },

                    jobrep = {
                        tow = 0,
                        taxi = 0,
                        hotdog = 0,
                        trucker = 0
                    },

                    criminalrecord = {
                        hasRecord = false
                    },

                    injail = 0,
                    dealerrep = 0,

                    phonedata = {
                        InstalledApps = {},
                        SerialNumber = 0
                    }
                    craftingrep = 0,
                    phone = {},
                    fingerprint = xPlayer.license,
                    bloodtype = "A+",
                    commandbinds = {
                        ["F7"] = {
                            argument = "",
                            command = ""
                        },
                        ["F6"] = {
                            argument = "",
                            command = ""
                        },
                        ["F2"] = {
                            argument = "",
                            command = "inventory"
                        },
                        ["F9"] = {
                            argument = "",
                            command = ""
                        },
                        ["F3"] = {
                            argument = "",
                            command = "phone"
                        },
                        ["F10"] = {
                            argument = "",
                            command = ""
                        },
                        ["F5"] = {
                            argument = "",
                            command = ""
                        }
                    },

                    jailitems = {},
                    callsign = "NO CALLSIGN",
                    walletid = "QB-00000000",
                    fitbit = {},
                    attachmentcraftingrep = 0
                }
                
                -- merge the metadatas
                for k,v in pairs(xPlayer.variables) do
                    if k == "status" then -- unpack status
                        for k,v in pairs(v) do
                            metadata[v.name] = v.percent
                        end
                    else
                        metadata[k] = v
                    end
                end

                for k,v in pairs(xPlayer.inventory) do
                    items[k] = ConvertItem(xPlayer, v.name, v.metadata)
                end

                return {
                    PlayerData = {
                        citizenid = xPlayer.identifier,
                        license = xPlayer.license,
                        cid = tonumber(xPlayer.identifier:match("char(%d+):")),
                        source = xPlayer.source,
                        name = xPlayer.name,
                        items = items,
                        id = xPlayer.source,
                        name = xPlayer.name,

                        metadata = metadata,
                        job = {
                            onduty = true, -- not implemented
                            grade = {
                                level = xPlayer.job.grade,
                                name = xPlayer.job.grade_label
                            },
                            label = xPlayer.job.label,
                            name = xPlayer.job.name,
                            payment = xPlayer.job.grade_salary,
                            isboss = false, -- not implemented
                        },
                        position = xPlayer.coords,
                        money = {
                            cash = xPlayer.getAccount("money").money,
                            bank = xPlayer.getAccount("bank").money,
                            crypto = 0
                        },
                        charinfo = {
                            cid = tonumber(xPlayer.identifier:match("char(%d+):")),
                            nationality = "undefined",
                            birthdate = xPlayer.variables.dateofbirth,
                            firstname = xPlayer.variables.firstName,
                            lastname = xPlayer.variables.lastName,
                            gender = xPlayer.variables.sex == "m" and 0 or 1
                        },
                        
                        -- not implemented
                        gang = {
                            label = "No Gang Affiliation",
                            name = "none",
                            grade = {
                                level = 0,
                                name = "none"
                            },
                            isboss = false
                        },
                
                        last_updated = {},
                        optin = true
                    },
                    Functions = {
                        Logout = function(source)
                            DropPlayer(source, "")
                        end,
                        RemoveItem = removeInventoryItem,
                        AddItem = addInventoryItem,
                        GetItemByName = getInventoryItem,
                        GetItemBySlot = function(slot)
                            if ESXConfig.OxInventory then
                                local item = exports.ox_inventory:GetSlot(xPlayer.source, slot)

                                return ConvertItem(xPlayer, item.name, item)
                            else
                                return {}
                            end
                        end,
                        GetItemsByName = function(name)
                            local items = {}
                            name = tostring(name):lower()

                            if ESXConfig.OxInventory then
                                local slots = exports.ox_inventory:Search("slots", name)

                                for k,v in pairs(slots) do
                                    table.insert(items, ConvertItem(xPlayer, v.name, v.metadata))
                                end
                            else
                                for k,v in pairs(xPlayer.inventory) do
                                    table.insert(items, ConvertItem(xPlayer, v.name, v.metadata))
                                end
                            end

                            return items
                        end,
                        ClearInventory = function()
                            for i=1, #xPlayer.inventory, 1 do
                                if xPlayer.inventory[i].count > 0 then
                                    xPlayer.setInventoryItem(xPlayer.inventory[i].name, 0)
                                end
                            end
                        end,
                        GetMetaData = xPlayer.get,
                        SetMetaData = xPlayer.set,

                        AddMoney = function(account, value)
                            xPlayer.addAccountMoney(ConvertAccount(account), value)
                        end,
                        RemoveMoney = function(account, value)
                            xPlayer.removeAccountMoney(ConvertAccount(account), value)
                        end,
                        GetMoney = function(account)
                            return xPlayer.getAccount(ConvertAccount(account)).money
                        end,
                        SetMoney = function(account, value)
                            xPlayer.setAccountMoney(ConvertAccount(account), value)
                        end,

                        SetJob = xPlayer.setJob,

                        -- not implemented
                        SetCreditCard = function() 
                            error("[Utility Wrapper] the method 'SetCreditCard' is not yet implemented")
                            return false
                        end,
                        GetCardSlot = function() 
                            error("[Utility Wrapper] the method 'GetCardSlot' is not yet implemented")
                            return false
                        end,
                        SetPlayerData = function() 
                            error("[Utility Wrapper] the method 'SetPlayerData' is not yet implemented")
                            return false
                        end,
                        SetJobDuty = function() 
                            error("[Utility Wrapper] the method 'SetJobDuty' is not yet implemented")
                            return false
                        end,
                        SetInventory = function() 
                            error("[Utility Wrapper] the method 'SetInventory' is not yet implemented")
                            return false
                        end,
                        UpdatePlayerData = function() 
                            error("[Utility Wrapper] the method 'UpdatePlayerData' is not yet implemented")
                            return false
                        end,
                        SetGang = function() 
                            error("[Utility Wrapper] the method 'SetGang' is not yet implemented")
                            return false
                        end,
                        AddJobReputation = function() 
                            error("[Utility Wrapper] the method 'AddJobReputation' is not yet implemented")
                            return false
                        end,
                        Save = function() 
                            error("[Utility Wrapper] the method 'Save' is not yet implemented")
                            return false
                        end,
                    },
                    Offline = false
                }
            end
        }
    }
else
    return = {
        Functions = {
            TriggerCallback = ESX.TriggerServerCallback
        }
    }
end