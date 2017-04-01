local ssb = {} -- DONT REMOVE!!!
--[[

   Simple Slot Block - V 1.0

   Put this file in C:/Users/<YOUR USERNAME>/DCS/Scripts for 1.5 or C:/Users/<YOUR USERNAME>/DCS.openalpha/Scripts for 2.0

   This script will use flags to disable and enable slots based on aircraft name and / or player prefix

   By Default all slots are enabled unless you change the ssb.enabledFlagValue to anything other than 0 or add a clan
   tag to the ssb.prefixes list and set an aircraft group name to contain it.

   To set a Flag value in DCS use the DO SCRIPT action and put in:

   trigger.action.setUserFlag("GROUP_NAME",100)

   Where GROUP_NAME is the name of the flag you want to change and 100 the value you want to set the flag too.

   As an example, there are two aircraft groups, HELI1 and HELI2 and the initial flag to turn on SSB

   You have a trigger that runs at the start of the mission with a DO SCRIPT that looks like so:

   trigger.action.setUserFlag("SSB",100)

   trigger.action.setUserFlag("HELI1",0)
   trigger.action.setUserFlag("HELI2",100)

   This will make HEL21 unusable until that flag is changed to 0 (assuming the ssb.enabledFlagValue is 0).
   The SSB flag is required to turn on slot blocking for that mission

   The flags will NOT interfere with mission flags

 ]]

ssb.showEnabledMessage = true -- if set to true, the player will be told that the slot is enabled when switching to it
ssb.controlNonAircraftSlots = false -- if true, only unique DCS Player ids will be allowed for the Commander / GCI / Observer Slots


-- If you set this to 0, all slots are ENABLED
-- by default as every flag starts at 0.
-- If you set this to anything other than 0 all slots
-- will be DISABLED BY DEFAULT!!!
-- Each slot will then have to be manually enabled via
-- trigger.action.setUserFlag("GROUP_NAME",100)
-- where GROUP_NAME is the group name (not pilot name) and 100 is the value you're setting the flag too which must
-- match the enabledFlagValue
ssb.enabledFlagValue = 0  -- what value to look for to enable a slot.


-- any aircraft slot controlled by the GROUP Name (not pilot name!)
-- that contains a prefix below will only allow players with that prefix
-- to join the slot
--
-- NOTE: the player prefix must match exactly including case
-- The examples below can be turned on by removing the -- in front
--
ssb.prefixes = {
     -- "-=104th=-",
    -- "-=VSAAF=-",
    -- "ciribob", -- you could also add in an actual player name instead
    "some_clan_tag",
    "-=AnotherClan=-",
}


-- any NON aircraft slot eg JTAC / GCI / GAME COMMANDER
-- will only allow certain PLAYER IDS
-- PLAYER IDS are unique DCS ids that can't be changed or spoofed
-- This script will output them when a player changes slots so you can copy them out easily :)
-- This will only take effect if: ssb.controlNonAircraftSlots = true
ssb.commanderPlayerUCID = {
    "292d911c1b6f631476795cb80fd93b1f",
    "some_uniqe_player_ucid",
}



ssb.version = "1.0"

-- Logic for determining if player is allowed in a slot
function ssb.shouldAllowAircraftSlot(_playerID, _slotID) -- _slotID == Unit ID unless its multi aircraft in which case slotID is unitId_seatID

    local _groupName = ssb.getGroupName(_slotID)

    if _groupName == nil or _groupName == "" then
        net.log("SSB - Unable to get group name for slot ".._slotID)
        return true
    end

    _groupName = ssb.trimStr(_groupName)

    if not ssb.checkClanSlot(_playerID, _groupName) then
        return false
    end

    -- check flag value
    local _flag = ssb.getFlagValue(_groupName)

    if _flag == ssb.enabledFlagValue then
        return true
    end

    return false

end

function ssb.checkClanSlot(_playerID, _unitName)

    for _,_value in pairs(ssb.prefixes) do

        if string.find(_unitName, _value, 1, true) ~= nil then

            net.log("SSB - ".._unitName.." is clan slot for ".._value)

            local _playerName = net.get_player_info(_playerID, 'name')

            if _playerName ~= nil and string.find(_playerName, _value, 1, true) then

                net.log("SSB - ".._playerName.." is clan member for ".._value.." for ".._unitName.." Allowing so far")
                --passed clan test, carry on!
                return true
            end

            if _playerName ~= nil then
                net.log("SSB - ".._playerName.." is NOT clan member for ".._value.." for ".._unitName.." Rejecting")
            end

            -- clan tag didnt match, quit!
            return false
        end
    end

    return true
end


function ssb.getFlagValue(_flag)

    local _status,_error  = net.dostring_in('server', " return trigger.misc.getUserFlag(\"".._flag.."\"); ")

    if not _status and _error then
        net.log("SSB - error getting flag: ".._error)
        return tonumber(ssb.enabledFlagValue)
    else

        --disabled
        return tonumber(_status)
    end
end

-- _slotID == Unit ID unless its multi aircraft in which case slotID is unitId_seatID
function ssb.getUnitId(_slotID)
    local _unitId = tostring(_slotID)
    if string.find(tostring(_unitId),"_",1,true) then
        --extract substring
        _unitId = string.sub(_unitId,1,string.find(_unitId,"_",1,true))
        net.log("Unit ID Substr ".._unitId)
    end

    return tonumber(_unitId)
end

function ssb.getGroupName(_slotID)

    local _name = DCS.getUnitProperty(_slotID, DCS.UNIT_GROUPNAME)

    return _name

end



--DOC
-- onGameEvent(eventName,arg1,arg2,arg3,arg4)
--"friendly_fire", playerID, weaponName, victimPlayerID
--"mission_end", winner, msg
--"kill", killerPlayerID, killerUnitType, killerSide, victimPlayerID, victimUnitType, victimSide, weaponName
--"self_kill", playerID
--"change_slot", playerID, slotID, prevSide
--"connect", id, name
--"disconnect", ID_, name, playerSide
--"crash", playerID, unit_missionID
--"eject", playerID, unit_missionID
--"takeoff", playerID, unit_missionID, airdromeName
--"landing", playerID, unit_missionID, airdromeName
--"pilot_death", playerID, unit_missionID
--
ssb.onGameEvent = function(eventName,playerID,arg2,arg3,arg4) -- This means if a slot is disabled while the player is flying, they'll be removed

    if DCS.isServer() and DCS.isMultiplayer() then
        if DCS.getModelTime() > 1 and  ssb.slotBlockEnabled() then  -- must check this to prevent a possible CTD by using a_do_script before the game is ready to use a_do_script. -- Source GRIMES :)

            if eventName == "self_kill"
                    or eventName == "crash"
                    or eventName == "eject"
                    or eventName ==  "pilot_death" then

                -- is player still in a valid slot
                local _playerDetails = net.get_player_info(playerID)

                if _playerDetails ~=nil and _playerDetails.side ~= 0 and _playerDetails.slot ~= "" and _playerDetails.slot ~= nil then

                    local _unitRole = DCS.getUnitType(_playerDetails.slot)
                    if _unitRole ~= nil and
                            (_unitRole == "forward_observer"
                                    or _unitRole == "instructor"
                                    or _unitRole == "artillery_commander"
                                    or _unitRole == "observer")
                    then
                        return true
                    end

                    local _allow = ssb.shouldAllowSlot(playerID, _playerDetails.slot)

                    if not _allow then
                        ssb.rejectPlayer(playerID)
                    end

                end
            end
        end
    end
end

ssb.onPlayerTryChangeSlot = function(playerID, side, slotID)

    if  DCS.isServer() and DCS.isMultiplayer() then
        if  (side ~=0 and  slotID ~='' and slotID ~= nil)  and  ssb.slotBlockEnabled() then

            local _ucid = net.get_player_info(playerID, 'ucid')
            local _playerName = net.get_player_info(playerID, 'name')

            if _playerName == nil then
                _playerName = ""
            end

            net.log("SSB - Player Selected slot - player: ".._playerName.." side:"..side.." slot: "..slotID.." ucid: ".._ucid)

            local _unitRole = DCS.getUnitType(slotID)

            if _unitRole ~= nil and
                    (_unitRole == "forward_observer"
                            or _unitRole == "instructor"
                            or _unitRole == "artillery_commander"
                            or _unitRole == "observer")
            then

                net.log("SSB - Player Selected Non Aircraft Slot - player: ".._playerName.." side:"..side.." slot: "..slotID.." ucid: ".._ucid.." type: ".._unitRole)

                local _allow = false

                if ssb.controlNonAircraftSlots and  ssb.slotBlockEnabled()  then

                    for _,_value in pairs(ssb.commanderPlayerUCID) do

                        if _value == _ucid then
                            _allow  = true
                            break
                        end
                    end

                    if not _allow then

                        ssb.rejectMessage(playerID)
                        net.log("SSB - REJECTING Player Selected Non Aircraft Slot - player: ".._playerName.." side:"..side.." slot: "..slotID.." ucid: ".._ucid.." type: ".._unitRole)

                        return false
                    end
                end

                net.log("SSB - ALLOWING Player Selected Non Aircraft Slot - player: ".._playerName.." side:"..side.." slot: "..slotID.." ucid: ".._ucid.." type: ".._unitRole)

                return true
            else
                local _allow = ssb.shouldAllowAircraftSlot(playerID,slotID)

                if not _allow then
                    net.log("SSB - REJECTING Aircraft Slot - player: ".._playerName.." side:"..side.." slot: "..slotID.." ucid: ".._ucid)

                    ssb.rejectMessage(playerID)

                    return false
                else
                    if ssb.showEnabledMessage then
                        --Disable chat message to user
                        local _chatMessage = string.format("*** %s - Slot Allowed! ***",_playerName)
                        net.send_chat_to(_chatMessage, playerID)
                    end
                end
            end

            net.log("SSB - ALLOWING Aircraft Slot - player: ".._playerName.." side:"..side.." slot: "..slotID.." ucid: ".._ucid)

        end
    end

    return true

end

ssb.slotBlockEnabled = function()

    local _res = ssb.getFlagValue("SSB") --SSB disabled by Default

    return _res == 100

end

ssb.rejectMessage = function(playerID)
    local _playerName = net.get_player_info(playerID, 'name')

    if _playerName ~= nil then
        --Disable chat message to user
        local _chatMessage = string.format("*** Sorry %s - Slot CURRENTLY DISABLED - Pick a different slot! ***",_playerName)
        net.send_chat_to(_chatMessage, playerID)
    end

end


ssb.rejectPlayer = function(playerID)
    net.log("SSB - REJECTING Slot - force spectators - "..playerID)

    -- put to spectators
    net.force_player_slot(playerID, 0, '')

    ssb.rejectMessage(playerID)
end

ssb.trimStr = function(_str)
    return  string.format( "%s", _str:match( "^%s*(.-)%s*$" ) )
end

DCS.setUserCallbacks(ssb)

net.log("Loaded - SIMPLE SLOT BLOCK v".. ssb.version.. " by Ciribob")