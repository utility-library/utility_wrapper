-- esx onPlayerDeath reimplementation
if Config.Framework ~= "esx" then
    local PlayerKilledByPlayer = function(killerServerId, killerClientId, deathCause)
        local victimCoords = GetEntityCoords(PlayerPedId())
        local killerCoords = GetEntityCoords(GetPlayerPed(killerClientId))
        local distance = #(victimCoords - killerCoords)
    
        local data = {
            victimCoords = victimCoords,
            killerCoords = killerCoords,
    
            killedByPlayer = true,
            deathCause = deathCause,
            distance = distance,
    
            killerServerId = killerServerId,
            killerClientId = killerClientId
        }
    
        return data
    end
    
    local PlayerKilled = function(deathCause)
        local playerPed = PlayerPedId()
        local victimCoords = GetEntityCoords(playerPed)
    
        local data = {
            victimCoords = victimCoords,
    
            killedByPlayer = false,
            deathCause = deathCause
        }
    
        return data
    end
    
    AddEventHandler("gameEventTriggered", function(event, data)
        --[[
            ESX-legacy - ESX framework for FiveM
    
            Copyright (C) 2015-2023 ESX-Framework
            
            This program Is free software: you can redistribute it And/Or modify it under the terms Of the GNU General Public License As published by the Free Software Foundation, either version 3 Of the License, Or (at your option) any later version.
            
            This program Is distributed In the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty Of MERCHANTABILITY Or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License For more details.
            
            You should have received a copy Of the GNU General Public License along with this program. If Not, see http://www.gnu.org/licenses/.    
        ]]
        if event ~= 'CEventNetworkEntityDamage' then return end
        
        local victim, victimDied = data[1], data[4]
        if not IsPedAPlayer(victim) then return end
        local player = PlayerId()
        local playerPed = PlayerPedId()
        if victimDied and NetworkGetPlayerIndexFromPed(victim) == player and (IsPedDeadOrDying(victim, true) or IsPedFatallyInjured(victim))  then
            local killerEntity, deathCause = GetPedSourceOfDeath(playerPed), GetPedCauseOfDeath(playerPed)
            local killerClientId = NetworkGetPlayerIndexFromPed(killerEntity)
            if killerEntity ~= playerPed and killerClientId and NetworkIsPlayerActive(killerClientId) then
                local data = PlayerKilledByPlayer(GetPlayerServerId(killerClientId), killerClientId, deathCause)
    
                TriggerEvent("utility_wrapper:esx:onPlayerDeath", data)
                TriggerServerEvent("utility_wrapper:esx:onPlayerDeath", data)
            else
                local data = PlayerKilled(deathCause)
    
                TriggerEvent("utility_wrapper:esx:onPlayerDeath", data)
                TriggerServerEvent("utility_wrapper:esx:onPlayerDeath", data)
            end
        end
    end)
end