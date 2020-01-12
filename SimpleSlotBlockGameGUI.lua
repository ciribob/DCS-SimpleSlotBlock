local ssb = {} -- DONT REMOVE!!!

--[[

   Simple Slot Block - V 1.1

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
   
   Additions:
   
   * 2017-10-19 - FlightControl
     
     You can now kick players out of their airplane or unit back to spectators during your running missions.
     This by setting user flags with the key the group name of the group seated by the player, to a value other than zero!
     
     => trigger.action.setUserFlag("HELI2",100) -- This will kick the group HELI2 when in the game.
     
       - Kicking players is enabled by default, but you can disable the function by modifying ssb.KickPlayers.
         => ssb.kickPlayers = true -- (default) This will enable the players to be kicked. 
         => ssb.kickPlayers = false -- This will disable the players to be kicked. 
         
       - Slotblocker will check upon a defined time interval whether a player needs to be kicked.
         => ssb.kickTimeInterval = 1 -- (default) Check every 1 seconds if a player needs to be kicked.
         => ssb.kickTimeInterval = 5 -- Check every 5 seconds if a player needs to be kicked.
         
       - By default, when a player gets kicked, its slot will be automatically unblocked.
         But maybe the mission designer wants to mission to be in control which slots get unblocked.
         => ssb.kickReset = true -- (default) The slot will be automatically reset to open, after kicking the player.
         => ssb.kickReset = false -- The slot will NOT be automatically reset to open, after kicking the player.

       

--]]

ssb.showEnabledMessage = true -- if set to true, the player will be told that the slot is enabled when switching to it
ssb.controlNonAircraftSlots = false -- if true, only unique DCS Player ids will be allowed for the Commander / GCI / Observer Slots


-- New addon version 1.1 -- kicking of players.
ssb.kickPlayers = true -- Change to false if you want to disable to kick players.
ssb.kickTimeInterval = 1 -- Change the amount of seconds if you want to shorten the interval time or make the interval time longer.
ssb.kickReset = true -- The slot will be automatically reset to open, after kicking the player.
ssb.kickTimePrev = 0 -- leave this untouched!


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



ssb.version = "1.1"



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


-- Logic to allow a player in a slot
function ssb.allowAircraftSlot(_playerID, _slotID) -- _slotID == Unit ID unless its multi aircraft in which case slotID is unitId_seatID (added by FlightControl)

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
  local _result = ssb.setFlagValue(_groupName, 0)

  return _result

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


function ssb.setFlagValue(_flag, _number) -- Added by FlightControl

  local _status,_error  = net.dostring_in('server', " return trigger.action.setUserFlag(\"".._flag.."\", " .. _number .. "); ")

  if not _status and _error then
    net.log("SSB - error setting flag: ".._error)
    return false
  end
  return true
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


--- Reset the persistent variables when a new mission is loaded.
ssb.onMissionLoadEnd = function()

  ssb.kickTimePrev = 0 -- Reset when a new mission has been loaded!

end


--- For each simulation frame, check if a player needs to be kicked.
ssb.onSimulationFrame = function()

  -- For each slot, check the flags...

  ssb.kickTimeNow = DCS.getModelTime()

  -- Check every 5 seconds if a player needs to be kicked.
  if ssb.kickPlayers and ssb.kickTimePrev + ssb.kickTimeInterval <= ssb.kickTimeNow then

    ssb.kickTimePrev = ssb.kickTimeNow

    if DCS.isServer() and DCS.isMultiplayer() then
      if DCS.getModelTime() > 1 and  ssb.slotBlockEnabled() then  -- must check this to prevent a possible CTD by using a_do_script before the game is ready to use a_do_script. -- Source GRIMES :)

        local Players = net.get_player_list()
        for PlayerIDIndex, playerID in pairs( Players ) do

          -- is player still in a valid slot
          local _playerDetails = net.get_player_info( playerID )

          if _playerDetails ~=nil and _playerDetails.side ~= 0 and _playerDetails.slot ~= "" and _playerDetails.slot ~= nil then

            local _unitRole = DCS.getUnitType( _playerDetails.slot )
            if _unitRole ~= nil and
              ( _unitRole == "forward_observer" or
              _unitRole == "instructor"or
              _unitRole == "artillery_commander" or
              _unitRole == "observer" )
            then
              return true
            end

            local _allow = ssb.shouldAllowAircraftSlot(playerID, _playerDetails.slot)

            if not _allow then
              ssb.rejectPlayer(playerID)
              if ssb.kickReset then
                ssb.allowAircraftSlot(playerID,_playerDetails.slot)
              end    
            end
          end
        end
      end
    end
  end
end


---DOC
-- onGameEvent(eventName,arg1,arg2,arg3,arg4)
--"friendly_fire", playerID, weaponName, victimPlayerID
--"mission_end", winner, msg
--"kill", killerPlayerID, killerUnitType, killerSide, victimPlayerID, victimUnitType, victimSide, weaponName
--"self_kill", playerID
ssb.onPlayerChangeSlot = function(playerID)


  if  DCS.isServer() and DCS.isMultiplayer() then
    local slotID = net.get_player_info(playerID, 'slot')
    local side = net.get_player_info(playerID, 'side')
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
             ssb.rejectPlayer(playerID)
            return 
          end
        end

        net.log("SSB - ALLOWING Player Selected Non Aircraft Slot - player: ".._playerName.." side:"..side.." slot: "..slotID.." ucid: ".._ucid.." type: ".._unitRole)

        return 
      else
        local _allow = ssb.shouldAllowAircraftSlot(playerID,slotID)

        if not _allow then
          net.log("SSB - REJECTING Aircraft Slot - player: ".._playerName.." side:"..side.." slot: "..slotID.." ucid: ".._ucid)

          ssb.rejectMessage(playerID)
          ssb.rejectPlayer(playerID)
          return 
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

  return 

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
