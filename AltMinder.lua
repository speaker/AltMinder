-----------------------------------------------------------------------------------
--                                     AltMinder
-----------------------------------------------------------------------------------
--
-- A WoW Mod that keeps track of alts and mains

-- When complete, it will have the following:

-- An entry system to enter mains and their alts
-- A recall system to return the stored data
-- A window that will dynamically report on a selected mob
-- A window that will report the last few message sender's "main" identity
--
-- Return values
-- zero on success
-- negative on failure
-- positive success & counter value
--   Note: some return 1 mean simple success

-- Author:  Adam Potolsky
-- Created:  06/29/06
-- Update:  N/A

-- Notes:


-----------------------------------------------------------------------------------

-----------------------------------------------------------------------------------
--
-- This is the main structure for the program. In AltM_Savedvars:
-- AltM_MainList is a list of mains and their alts (deprecated after v0.3)
-- AltM_AltsList is a list of alts and who their main is. (deprecated after v0.3)
--    Note: Both of these need to be maintained, however, AltM_MainList should
--          always be assumed to be correct. (deprecated after v0.3)
--
-----------------------------------------------------------------------------------
AltM_SavedVars = {
  AltM_MainList = {},
  AltM_AltList = {},
  NoEmote,
  AltM_MainTag,
  AltM_MainOn,
  AltM_Mains = {},
  AltM_Alts = {},
  AltM_Upgraded, -- 1 is unupgraded; 2 is DB upgrade not done; 3 is upgrade complete
}

local AltM_TurnOn = true    -- allows the turning off and on of AltMinder

ALTM_NO_MATCH = 0
ALTM_MAIN_MATCH = 1
ALTM_ALT_MATCH = 2

local AltMinder = {}
_G.AltMinder = AltMinder
local AltM = _G.AltMinder_Frame

-- This is an artifact of an attempt to add a debugging level to output messages.
-- I left it in in case anyoen else wants to make a go at it.


AltM_Debug_Threshhold = 100

-- This is the Hook for the event frame

local Hook_ChatFrame_MessageEventHandler

local AddMessageHooked = false

sRealmName = GetRealmName():gsub("%s+", "")

-------------------------------------------------------------------------------
--                                   AltM_OnLoad
-------------------------------------------------------------------------------
--
-- AltM_OnLoad() -- Called when AltMinder is first loaded.
--
-- Arguements: none
--
-- Description: When the addon is loaded we need to Hook the Event Handler
-- from the Chat Frame (window). Then register for whatever command line
-- commands are used, and then register for when the variables are loaded.
--
-- Last, if the data structure is empty, then populate it with at least some
-- core data.
--
-- Notes:
--
-- AltMinder Versions: No changes Needed
--


function AltMinder:AltM_OnLoad(self)
  self:RegisterEvent("VARIABLES_LOADED")
  self:RegisterEvent("ADDON_LOADED")
end

local AltM_items = AltM_SavedVars.AltM_MainList

function AltMinder:AltM_DD_OnClick(self)
   UIDropDownMenu_SetSelectedID(AltM_DropDown, self:GetID())
end

function AltMinder:AltM_DD_MainList(self, level)
	local info = UIDropDownMenu_CreateInfo()
	for index,value in pairs(AltM_SavedVars[sRealmName].AltM_Mains) do
		info = UIDropDownMenu_CreateInfo()
		info.text = index
		info.value = index
		info.func = AltMinder:AltM_DD_OnClick()
		AltMinder:UIDropDownMenu_AddButton(info, level)
	end
end



-------------------------------------------------------------------------------
--                                   AltM_OnEvent
-------------------------------------------------------------------------------
--
-- AltM_OnEvent() -- Called when AltMinder is first loaded.
--
-- Arguements: none
--
-- This is the only event we care about, the rest come from the ChatFrame
-- Event Handler
--
--
-- Notes:
--
-- AltMinder Versions: No changes Needed
--
--

--[[
--function AltMinder:AltM_OnEvent(event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
    --AltM_Out("OnEvent")
    --self[event](self, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
--end
--
function AltMinder.ADDON_LOADED(self, addon) 
	if addon ~= "AltMinder" then
		print(" XXXXXXXXXXXXX load test")
	else
		print(addon .. "load test")
	end 
	self:UnregisterEvent("ADDON_LOADED") 
end
]]--

function AltMinder:AltM_OnEvent(self, event, ...)
  if event ~= "VARIABLES_LOADED" then
	  return
  else
    AltMinder:AltM_Out("AltMinder Variables Loaded for:" .. sRealmName)

-- Old datastore doesnt' exist, treat as new install

     if( AltM_SavedVars.AltM_MainList == nil ) then
       AltM_SavedVars.AltM_Upgraded = 3  -- AltMinder new install, just use new stuff
     end

    if( AltM_SavedVars.AltM_MainOn == nil ) then
      AltM_SavedVars.AltM_MainOn = true
    end

    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL",AltMinder.AltM_AddMessage);
    ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD",AltMinder.AltM_AddMessage);
    ChatFrame_AddMessageEventFilter("CHAT_MSG_BATTLEGROUND",AltMinder.AltM_AddMessage);
    ChatFrame_AddMessageEventFilter("CHAT_MSG_OFFICER",AltMinder.AltM_AddMessage);
    ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY",AltMinder.AltM_AddMessage);
    ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER",AltMinder.AltM_AddMessage);
    ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID",AltMinder.AltM_AddMessage);
    ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER",AltMinder.AltM_AddMessage);
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY",AltMinder.AltM_AddMessage);
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER",AltMinder.AltM_AddMessage);
    ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL",AltMinder.AltM_AddMessage);

    if( AltM_SavedVars[sRealmName] == nil) then
      AltM_SavedVars[sRealmName] = {}
      AltM_SavedVars[sRealmName].AltM_Alts = {}
      AltM_SavedVars[sRealmName].AltM_Mains = {}
    end

    if( AltM_SavedVars.AltM_MainTag == nil or AltM_SavedVars.AltM_MainTag == "") then
      AltM_SavedVars.AltM_MainTag = ALTM_DEFAULT_MAINTAG
    end

    if(AltM_SavedVars.AltM_Upgraded == nil ) then
      AltM_SavedVars.AltM_Upgraded = 1
      elseif(AltM_SavedVars.AltM_Upgraded == 2) then
        AltMinder:AltM_Out("Altminder appears to have failed upgrading to the new datastore. Trying again.")
        AltM_SavedVars[sRealmName] = {}
        AltM_SavedVars.AltM_Upgraded = 1
    end

    if (AltM_SavedVars.AltM_Upgraded == 1) then
      AltM_SavedVars.AltM_Upgraded = 2
      AltMinder:AltM_Out("AltMinder being upgraded to version 2 database")
      if( AltM_SavedVars[sRealmName] == nil )then
        AltM_SavedVars[sRealmName] = {}
      end
      if( AltM_SavedVars[sRealmName].AltM_Mains == nil )then
        AltM_SavedVars[sRealmName].AltM_Mains = {}
      end
      if( AltM_SavedVars[sRealmName].AltM_Alts == nil )then
        AltM_SavedVars[sRealmName].AltM_Alts = {}
      end
      AltMinder:AltM_UpgradeAltTable()
      AltMinder:AltM_UpgradeMainTable()
      AltM_SavedVars.AltM_Upgraded = 3
      AltMinder:AltM_Out("!!!!!!!!!!!! AltMinder databse has been modified. !!!!!!!!!!!!!!!!!!!")
      AltMinder:AltM_Out("If Alts were kept across multiple realms, you MUST do the following:")
      AltMinder:AltM_Out("Before Logging out, type the command /altm upg 1 then log into the next realm.")
      AltMinder:AltM_Out("This needs to be done for every realm. This need only be done once.")
      AltMinder:AltM_Out("!!!!!!!!!!!! AltMinder databse has been modified. !!!!!!!!!!!!!!!!!!!")
    end
  end
end

-------------------------------------------------------------------------------
--                       SlashCmdList.AltM_SlashCmdHandler
-------------------------------------------------------------------------------
--
-- SlashCmdList.AltM_SlashCmdHandler() -- Handles the /altm commands.
--
-- Arguements:
--      args                  The list of arguements to process
--
-- Description: This is the routine that manages all the /altm commands.
-- Here are the possible commands:
-- /altm                                     Display simple message.
-- /altm help                                Display a more complete message.
-- /altm add main <main-name> <alt-namelist> Add main with all-list names.
-- /altm add alt <alt-name> <main-name>      Add alt to the given main
-- /altm del main <main-name>                Delete the main and all it's alts
-- /altm del alt <alt-name>                  Delete the alt from both tables
-- /altm change main <name> <newname>        Changes the name of a main
-- /altm change alt <name> <newname>         Changes the name of an alt
-- /altm extract guild <verbose>             tries to extract from guild notes
--
-- Internal/debugging commands:
--
-- /altm dumpdata                            dump tables
-- /altm purgedata                           purges all data from the tables
--
-- Notes:
--
-- AltMinder Versions: CHECKME
--
--

-- the slash command handler "registration"
SLASH_AltM_SlashCmdHandler1="/altm"

function SlashCmdList.AltM_SlashCmdHandler(args)
  local iArgsLen = 0
  local iStartToken = 0
  local iEndToken = 0
  local nextToken = "ALT_NoVal"
  local restOfList = ""
  local iLoopCount = 1
  local argList = {}

  local iRetVal1 = 0; -- Used for debugging
  local iRetVal2 = 0; -- Used for debugging

-- This section builds a table from the list of args. 1 or more letters or numbers in a row qualify

  iArgsLen = string.len(args)
  iStartToken,iEndToken = string.find(args,"[^ ]*")
  while (nextToken and nextToken ~= "") do
    nextToken = string.sub(args,iStartToken,iEndToken)
    if(nextToken and nextToken ~= "") then
      table.insert(argList,nextToken)
    end

    iStartToken,iEndToken = string.find(args,"[^ ]*",iEndToken+2)

    if(iLoopCount >= 50) then nextToken = ""; end; -- Forces end to loop
    iLoopCount = iLoopCount + 1
  end

  if(argList[1] == nil or argList[1] == "") then
    AltMinder:AltM_Out(ALTM_MSG_BASE_SLASH)
    AltMinder:AltM_Out(ALTM_MSG_BASE_SLASH2)
  elseif(argList[1] == "debug") then
    if(argList[2] == nil or argList[2]== "") then
      AltMinder:AltM_Out(" /altm debug <number>")
    else
      AltM_Debug_Threshhold = tonumber(argList[2])
    end

-- help commands
  elseif(argList[1] == ALTM_SLASH_HELP) then
    AltMinder:AltM_Out(ALTM_MSG_BASE_SLASH)
    AltMinder:AltM_Out("   " .. ALTM_MSG_HELP)
    AltMinder:AltM_Out("   " .. ALTM_MSG_ONOFF)
    AltMinder:AltM_Out("   " .. ALTM_MSG_ADD_MAIN)
    AltMinder:AltM_Out("   " .. ALTM_MSG_ADD_ALT)
    AltMinder:AltM_Out("   " .. ALTM_MSG_DEL)
    AltMinder:AltM_Out("   " .. ALTM_MSG_EMOTE)
    AltMinder:AltM_Out("   " .. ALTM_MSG_CHG_MAIN)
    AltMinder:AltM_Out("   " .. ALTM_MSG_CHG_ALT)

-- Add commands    
  elseif(argList[1] == ALTM_SLASH_ADD) then
    if(argList[2] == ALTM_SLASH_ADD_MAIN) then
      if(argList[3] == nil or argList[3]== "") then
        AltMinder:AltM_Out(ALTM_MSG_CMD .. " " .. ALTM_MSG_ADD_MAIN)
        AltMinder:AltM_Out(ALTM_MSG_NEED_MAIN_NAME)
      else
        local iPos = 4
-- IF the main alredy exists exit
        if( AltMinder:AltM_AddMain(argList[3]) ~= 0 ) then return -1 end

-- For each alt given, add it to the main, and add it as an alt. If it can't be added to the main
-- then an error happened. If it can't be made an independant alt itself, then it might already exist
-- somewhere else in which case, just keep adding from the list.
        while(argList[iPos] and argList[iPos] ~= "") do
          if( AltMinder:AltM_AddAltToMain(argList[3],argList[iPos]) ~= 0) then
            return -1
          end
          if( AltMinder:AltM_AddAlt(argList[3],argList[iPos]) == 0) then
            AltMinder:AltM_Out(argList[iPos] .. ALTM_MSG_OUT_ADD_ALT .. argList[3])
          end
          iPos=iPos+1
        end

        AltMinder:AltM_Out(argList[3] .. ALTM_MSG_OUT_ADD_MAIN)
      end

-- Add an Alt. If either name is missing message and return
-- If the given alt is a main, suggest the names are out of order.
-- If the alt can be added, then add it to the main.
-- Messages issued by Add routines.
    elseif(argList[2] == ALTM_SLASH_ADD_ALT)then
      if(argList[3] == nil or argList[3]== "" or argList[4] == nil or argList[4]== "") then
        AltMinder:AltM_Out(ALTM_MSG_CMD .. " " .. ALTM_MSG_ADD_ALT)
        AltMinder:AltM_Out(ALTM_MSG_NEED_BOTHNAMES)
      elseif(AltMinder:AltM_FindMain(argList[4],sRealmName) == 0) then
        AltMinder:AltM_Out(ALTM_MSG_CMD .. " " .. ALTM_MSG_ADD_ALT)
        AltMinder:AltM_Out(argList[4] .. " " .. ALTM_MSG_MAIN_NOT_FOUND)
        AltMinder:AltM_Out(ALTM_MSG_TRY_MAIN .. argList[4] .. " " .. argList[3])
      else
        if(AltMinder:AltM_AddAlt(argList[4],argList[3]) == 0) then
          AltMinder:AltM_AddAltToMain(argList[4],argList[3])
          AltMinder:AltM_Out(argList[3] .. ALTM_MSG_OUT_ADD_ALT .. argList[4])
			  end
      end
-- Issue message about how the ADD commands work.
    else
      AltMinder:AltM_Out(ALTM_MSG_BASE_SLASH)
      AltMinder:AltM_Out(ALTM_MSG_CMD .. " " .. ALTM_MSG_ADD_MAIN)
      AltMinder:AltM_Out(ALTM_MSG_CMD .. " " .. ALTM_MSG_ADD_ALT)
    end

-- Delete commands
-- Everyone in the list is to be deleted. If one fails still delete the other.
-- No rebound processing shoudl be done outside these routines. If an alt fails to
-- delete, then try to remove it from the main.
-- Main delete processes itself.
  elseif(argList[1] == ALTM_SLASH_DEL)then
-- Delete a main
    if(argList[2] == ALTM_SLASH_DEL_MAIN)then
      if(argList[3] == nil or argList[3]== "") then
        AltMinder:AltM_Out(ALTM_MSG_CMD .. " " .. ALTM_MSG_DEL_MAIN)
      end
AltMinder:AltM_Out("AltMinder: Delete Main has been disabled pending update, sorry =/ .")
AltMinder:AltM_Out("AltMinder: Try /altm change main " .. argList[3] .. " <some-new-name>")
      -- AltM_DelMain(argList[3])
      -- AltMinder:AltM_Out(argList[3] .. ALTM_MSG_OUT_DEL_MAIN)
-- Delete an alt
    elseif(argList[2] == ALTM_SLASH_DEL_ALT)then
      if(argList[3] == nil or argList[3]== "") then
        AltMinder:AltM_Out(ALTM_MSG_CMD .. " " .. ALTM_MSG_DEL_ALT)
      end
      AltMinder:AltM_DelAltFromMain(argList[3])
      AltMinder:AltM_DelAlt(argList[3])
      AltMinder:AltM_Out(argList[3] .. ALTM_MSG_OUT_DEL_ALT)
-- Issue useage message
    else
      AltMinder:AltM_Out(ALTM_MSG_BASE_SLASH)
      AltMinder:AltM_Out(ALTM_MSG_CMD .. " " .. ALTM_MSG_DEL_MAIN)
      AltMinder:AltM_Out(ALTM_MSG_CMD .. " " .. ALTM_MSG_DEL_ALT)
    end
-- Change commands
  elseif(argList[1] == ALTM_SLASH_CHG)then
    if(argList[2] == ALTM_SLASH_CHG_MAIN)then
      if(argList[3] == nil or argList[3]== "" or argList[4] == nil or argList[4]== "") then
        AltMinder:AltM_Out(ALTM_MSG_CMD .. " " .. ALTM_MSG_CHG_MAIN)
      end
      AltMinder:AltM_ChangeMain(argList[3],argList[4])
      AltMinder:AltM_Out(argList[3] .. ALTM_MSG_OUT_CHG_NAME .. argList[4])
    elseif(argList[2] == ALTM_SLASH_CHG_ALT)then
      if(argList[3] == nil or argList[3]== "" or argList[4] == nil or argList[4]== "") then
        AltMinder:AltM_Out(ALTM_MSG_CMD .. " " .. ALTM_MSG_CHG_ALT)
      end
      AltMinder:AltM_ChangeAlt(argList[3],argList[4])
      AltMinder:AltM_Out(argList[3] .. ALTM_MSG_OUT_CHG_NAME .. argList[4])
    else
      AltMinder:AltM_Out(ALTM_MSG_BASE_SLASH)
      AltMinder:AltM_Out(ALTM_MSG_CMD .. " " .. ALTM_MSG_CHG_MAIN)
      AltMinder:AltM_Out(ALTM_MSG_CMD .. " " .. ALTM_MSG_CHG_ALT)
    end
-- Emote processing
  elseif(argList[1] == ALTM_SLASH_EMOTE)then
    if(argList[2] == "off")then
      AltM_SavedVars.NoEmote = true
      AltMinder:AltM_Out(ALTM_MSG_OUT_EMOTE_NO)
    elseif(argList[2] == "on")then
      AltM_SavedVars.NoEmote = false
      AltMinder:AltM_Out(ALTM_MSG_OUT_EMOTE_YES)
    else
      AltMinder:AltM_Out(ALTM_MSG_CMD .. " " .. ALTM_MSG_EMOTE)
      if(AltM_SavedVars.NoEmote == true)then
        AltMinder:AltM_Out(ALTM_MSG_OUT_EMOTE_NO)
      elseif(AltM_SavedVars.NoEmote == false)then
        AltMinder:AltM_Out(ALTM_MSG_OUT_EMOTE_YES)
      else
        AltMinder:AltM_Out(ALTM_MSG_OUT_EMOTE_UNK)
      end
    end
-- Processing ON
  elseif(argList[1] == ALTM_SLASH_ON )then
    AltMinder:AltM_Out(ALTM_MSG_ON)
    AltM_TurnOn = true
-- Processing OFF
  elseif(argList[1] == ALTM_SLASH_OFF )then
    AltMinder:AltM_Out(ALTM_MSG_OFF)
    AltM_TurnOn = false
-- Main tag processing
  elseif(argList[1] == ALTM_SLASH_MAINON )then
    AltMinder:AltM_Out(ALTM_MSG_OUT_MAIN_ON)
-- Tag value for main tag
    if(argList[2] ~= "" and argList[2] ~= nil ) then
      AltM_SavedVars.AltM_MainTag = argList[2]
      AltMinder:AltM_Out(ALTM_MSG_OUT_MAIN_SET .. AltM_SavedVars.AltM_MainTag)
    end
    AltM_SavedVars.AltM_MainOn = true
-- Main tag processing off
  elseif(argList[1] == ALTM_SLASH_MAINOFF )then
    AltMinder:AltM_Out(ALTM_MSG_OUT_MAIN_OFF)
    AltM_SavedVars.AltM_MainOn = false
-- Guild Extract processing
  elseif(argList[1] == ALTM_SLASH_EXTRACT)then
    if(argList[2] == ALTM_SLASH_GUILD) then
      if(argList[3] == ALTM_SLASH_VERBOSE) then
        AltMinder:AltM_ExtractGuildData(true)
      else
        AltMinder:AltM_ExtractGuildData(false)
      end
-- unsupported command for urbs -- kind of guild processing
    elseif(argList[2] == "urbs") then
      AltMinder:AltM_Out("What are you doing, Dave?")
      if(argList[3] == ALTM_SLASH_VERBOSE) then
        AltMinder:AltM_UrbsExtractGuildData(true)
      else
        AltMinder:AltM_UrbsExtractGuildData(false)
      end
    else
      AltMinder:AltM_Out(ALTM_MSG_CMD .. " " .. ALTM_MSG_EXTRACT)
      AltMinder:AltM_Out("  " .. ALTM_MSG_EXTRACT_VRBOP)
    end
-- query and info command for a particular given user
  elseif(argList[1] == ALTM_SLASH_QUERY or argList[1] == ALTM_SLASH_INFO )then
    if(argList[2] ~= "" and argList[2] ~= nil )then
      AltMinder:AltM_Out( AltMinder:AltM_GetInfo(argList[2]) )
    else
      AltMinder:AltM_Out(ALTM_MSG_QUERY)
    end
-- Forces DB upgrade command
  elseif(argList[1] == "upg")then
AltMinder:AltM_Out("AltM_Upgraded:" .. AltM_SavedVars.AltM_Upgraded)
      AltMinder:AltM_UpgradeAltTable()
      AltMinder:AltM_UpgradeMainTable()
                        AltM_SavedVars.AltM_Upgraded = 3
-- Dumpdata to screen
  elseif(argList[1] == "dumpdata")then
    AltMinder:AltM_DumpData( argList[2] )
-- reset all alt/main data
  elseif(argList[1] == "purgedata")then
    AltMinder:AltM_PurgeData()
-- checks current online guild members for their status
  elseif(argList[1] == ALTM_SLASH_GUILDCHK) or
	(argList[1] == ALTM_SLASH_GUILDCHECK) or
	((argList[1] == ALTM_SLASH_GUILD) and (argList[2] == ALTM_SLASH_CHECK)) then
    AltMinder:AltM_GuildCheck()
-- Unknown command error
elseif(argList[1] == "dd") then
	if AltM_DropDown == nil then
	   CreateFrame("Frame", "AltM_DropDown", UIParent, "UIDropDownMenuTemplate")
	end
	
	AltM_DropDown:ClearAllPoints()
	AltM_DropDown:SetPoint("CENTER", 0, 0)
	AltM_DropDown:Show()

	UIDropDownMenu_Initialize(AltM_DropDown, AltM_DD_MainList)
	UIDropDownMenu_SetWidth(AltM_DropDown, 100);
	UIDropDownMenu_SetButtonWidth(AltM_DropDown, 124)
	UIDropDownMenu_SetSelectedID(AltM_DropDown, 1)
	UIDropDownMenu_JustifyText(AltM_DropDown, "LEFT")
elseif(argList[1] == "ddoff") then
	if AltM_DropDown then
		AltM_DropDown:Hide()
	end
  else
    AltMinder:AltM_Out(ALTM_MSG_UNKNOWN_COMMAND .. argList[1])
    AltMinder:AltM_Out(ALTM_MSG_BASE_SLASH)
  end
end

-------------------------------------------------------------------------------
--                                   AltM_GetInfo
-------------------------------------------------------------------------------
--
-- AltM_GetInfo() -- given a name This routine returns a useful message
--
-- Arguements:
--      name               name to look for
--
-- Description: Search for name and return a string either as:
--     name is a main
--     name is an alt of XXXXX
--     name is not known
--
-- Notes: This does _NOT_ search the Main Table for a match.
--
-- AltMinder Versions: No upgrade needed, only calls other routines.
--
function AltMinder:AltM_GetInfo(name,server)
  local iCntr = 0
  local test = ""
  local iFindPos = 0
  local iFindEnd = 0

  iCntr = AltMinder:AltM_FindAlt(name,server)

  if(iCntr == 1) then
    test = AltMinder:AltM_FindMainOfAlt(name,sRealmName)
    return name .. " is an alt of " .. test
  end

  iCntr = 0

  iCntr = AltMinder:AltM_FindMain(name,sRealmName)

  if(iCntr ~= 0) then
    return "(" .. iCntr .. ")" .. name .. " has alts:" .. AltMinder:AltM_GetAltsFromMain(name)
  end

  return name .. " is not known"
end

-------------------------------------------------------------------------------
--                                   AltM_FindMainOfAlt
-------------------------------------------------------------------------------
--
-- AltM_FindMainOfAlt() -- given an alt, this routine returns the name of the
-- main associated with it.
--
-- Arguements:
--      name               name to look for
--
-- Description: Search the Alt Tablt for the given alt and return the name of
-- the Main listed in it.
--
-- Notes: This does _NOT_ search the Main Table for a match.
--
-- AltMinder Versions:
--           1 -- old style
--           2 -- old style
--           3 -- direct access from table.
--
function AltMinder:AltM_FindMainOfAlt(name, server)
  local iCntr = 1
  local test = ""
  local iFindPos = 0
  local iFindEnd = 0

  --AltMinder:AltM_Out("DELME: name:" .. name .. " server:" .. server)

  iCntr = AltMinder:AltM_FindAlt(name,server)

  if(iCntr ~= 1) then return "-NoMatch-" end

  test = AltM_SavedVars[server].AltM_Alts[name].main

  return test
end

-------------------------------------------------------------------------------
--                                   AltM_NameEncountered
-------------------------------------------------------------------------------
--
-- AltM_NameEncountered()
--
-- Arguements:
--      name               name to look for
--      server             server to look for "name" on
--
-- Description: when a name is found, this routine checks if it's a main, alt,
-- or none.
--
-- Notes:
-- This is a Kludge. Somehow my SlashCommands are getting here and they never
-- set an arg2 to become 'name'. As a result, name is (nil).
-- Return no match from here if no match is found and the message will pass
-- through unaltered. I suspect that this is related to the unhooking that
-- shoudl work but I can't get right.
--
function AltMinder:AltM_NameEncountered(name,server)


  if(AltM_TurnOn == false or name == nil or server== nil ) then return ALTM_NO_MATCH; end

  local ret = ALTM_NO_MATCH

  if(AltMinder:AltM_FindMain(name,server) > 0) then
	  ret = ALTM_MAIN_MATCH;
  elseif(AltMinder:AltM_FindAlt(name,server) > 0) then
	  ret = ALTM_ALT_MATCH;
  end

  return ret

end

-------------------------------------------------------------------------------
--                                   AltM_AddMessage
-------------------------------------------------------------------------------
--
-- Description: This routine is the one that replaces the AddMessage the
-- Chat Window would normally use.
-- It keyes off sender (the name of the messager)
-- looks for who it is and if they are in the table as a main or alt, it adds
-- an appropriate piece of data to the message. (MAIN) for a main and (altname)
-- if it is an alt. if all else fails, it will just print the message as it
-- would have if AltMinder wasn't running.
-- arg1: message
-- arg2: author
-- arg3: language
-- arg4: channel name with number ex: "1. General - Stormwind City"
-- arg5: target (second player name when two users are passed for a CHANNEL_NOTICE_USER (E.G. x kicked y))
-- arg6: AFK/DND/GM "CHAT_FLAG_"..arg6 flags
-- arg7: zone ID used for generic system channels (1 for General, 2 for Trade, 22 for LocalDefense, 23 for WorldDefense and 26 for LFG)
-- arg8: channel number
-- arg9: channel name without number (this is _sometimes_ in lowercase)
-- arg10: unknown
-- arg11: Chat lineID
-- arg12: Sender GUID
-- arg13: Bnet presenceID

--function AltMinder:AltM_AddMessage(event, msg, sender, language, channelString, target, flags, unknown, channelNumber, channelName, unknown2, counter, guid, presenceID)
function AltMinder:AltM_AddMessage(event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16)
  local msg = arg1
  local sender = arg2
  local language = arg3
  local channelString = arg4
  local target = arg5
  local flags = arg6
  local unknown = arg7
  local channelNumber = arg8
  local channelName = arg9
  local unknown2 = arg10
  local counter = arg11
  local guid = arg12
  local presenceID = arg13

  local newMessage = ""
  local iReturnValue = ALT_NO_MATCH
  local AltMessageName = "AltM_NIL"
  local iNumReplaced = 0
  local findString = sender
  local replaceString = "AltM_NoVal_1"

  --"text", "playerName", "languageName", "channelName", "playerName2", "specialFlags", zoneChannelID, channelIndex, "channelBaseName", unused, lineID, "guid", bnSenderID, isMobile, isSubtitle, hideSenderInLetterbox, supressRaidIcons

  if( sender == nil or sender == "") then
        iReturnValue = ALTM_NO_MATCH
  end

  local name,server = strsplit( "-" , sender , 2)

  if( msg == nil or msg == "") then
        iReturnValue = ALTM_NO_MATCH
  elseif(string.find(msg,"[[]Raid ",1)) then
        iReturnValue = ALTM_NO_MATCH
  else
  	iReturnValue = AltMinder:AltM_NameEncountered(name,server)
  end

  --AltMinder:AltM_Out("DELME: " .. iReturnValue .. "((" .. name .. "))" .. "Message:" .. msg )

  if(iReturnValue == ALTM_NO_MATCH) then
    newMessage = msg
  elseif( AltM_SavedVars.AltM_MainOn == false) then
    newMessage = msg
  elseif(iReturnValue == ALTM_MAIN_MATCH) then
   newMessage =  AltM_SavedVars.AltM_MainTag .. msg
  else

	  --AltMinder:AltM_Out("DELME: Building New Message...")

    altName = AltMinder:AltM_FindMainOfAlt( name, server)

	  --AltMinder:AltM_Out("DELME: altName:" .. altName)

   newMessage =  "<\124cffffffff\124Hitem:19:0:0:0:0:0:0:0\124h" .. altName .."\124h\124r>: " .. msg
  end

  return false, newMessage, sender, language, channelString, target, flags, unknown, channelNumber, channelName, unknown2, counter, guid, presenceID, arg14, arg15, arg16

end

-------------------------------------------------------------------------------
--                                   AltM_AddMain
-------------------------------------------------------------------------------
--
-- AltM_AddMain() -- Adds a main to the table.
--
-- Arguements:
--     string             main
--
-- Description: Adds the given main to the Main Table
--
-- Notes: Does _NOT_ add an alt, only preps the entry.
--
--  Upgrade version: Inserts data into both tables
--
function AltMinder:AltM_AddMain(main)

  local ret = AltMinder:AltM_FindMain(main,sRealmName)
  --if(AltMinder:AltM_FindMain(main,sRealmName) ~= 0) then
  if(ret ~= 0) then
    AltMinder:AltM_Out("AltMinder Error(10)".. ret .. ":" .. main .. " is already defined as a main on " .. sRealmName .. ".")
    return -1
  end

  if(AltMinder:AltM_FindAlt(main,sRealmName) == 1) then
    AltMinder:AltM_Out("AltMinder Error(20):" .. main .. " is already defined as an alt.")
    return -1
  end

  AltM_SavedVars[sRealmName].AltM_Mains[main] = { alts={} }
  return 0

end

-------------------------------------------------------------------------------
--                                   AltM_DelAltFromMain
-------------------------------------------------------------------------------
--
-- AltM_DelAltFromMain() -- Removes a specific alt from a given main
--
-- Arguements:
--     string             alt
--
-- Description: Searches the table entry for a given alt then find's it's
-- associated main and removes the alt from that main.
--
-- Notes: If the given alt doesn't have an Alt Table entry, we're done.
--        If the given main doesn't have an main Table entry, we're done.
--
function AltMinder:AltM_DelAltFromMain(alt)

  main = AltMinder:AltM_FindMainOfAlt(alt,sRealmName)

  if( main == nil ) then
    AltMinder:AltM_Out("AltMinder error(22): " .. alt .. " does not have a main.")
    return -1;
  end

  AltMinder:AltM_Out("Found " .. main .. " to be the main of " .. alt)

  for i,v in ipairs(AltM_SavedVars[sRealmName].AltM_Mains[main].alts) do
    if(v == alt) then
      table.remove(AltM_SavedVars[sRealmName].AltM_Mains[main].alts,i)
      return 1;
    end
    AltMinder:AltM_Out("AltMinder error(23): " .. main .. " does not have " .. alt)
  end


  --if( AltM_SavedVars[sRealmName].AltM_Mains[main].alts[alt]== nil ) then
    --AltM_Out("AltMinder error(23): " .. main .. " does not have " .. alt)
    --return -2;
  --end

  --AltM_TableRemove(AltM_SavedVars[sRealmName].AltM_Mains[main].alts,alt)

  AltMinder:AltM_Out("AltMinder error(23): " .. main .. " does not have " .. alt)
  return 0;
end

-------------------------------------------------------------------------------
--                                   AltM_DelMain
-------------------------------------------------------------------------------
--
-- AltM_DelMain() -- Removes the given Main from the Main table
--
-- Arguements:
--     string             main
--
-- Description:  Searches for a main and removes all it's alts from the alt
--    table. It then removes the main from the main table.
--
-- Notes:  This routine needs to be safe to call on an alt and return 0
--     if none is found that needs to be removed.
--

function AltMinder:AltM_DelMain(main)

  for sAltName in AltM_SavedVars[sRealmName].AltM_Mains[main].alts do
    AltM_TableRemove(AltM_SavedVars[sRealmName].AltM_Alts,alt)
  end
  AltM_SavedVars[sRealmName].AltM_Mains[main] = nil

end

-------------------------------------------------------------------------------
--                                   AltM_AddAlt
-------------------------------------------------------------------------------
--
-- AltM_AddAlt() -- Called when AltMinder is first loaded.
--
-- Arguements:
--     main          The main to add to the alt in the alt table
--     alt           The alt to add to the alt table.
--
--
-- Description: If the alt is not already in the list, add it.
--
-- Notes: This routine does not add the alt to the main.
--
function AltMinder:AltM_AddAlt(main,alt)

  if( AltMinder:AltM_FindMain(alt,sRealmName) ~= 0) then
    AltMinder:AltM_Out("AltMinder Error(30):" .. alt .. " is already defined as a main.")
    return -1
  end

  ret = AltMinder:AltM_FindAlt(main,sRealmName)
  if( ret == 1) then
    AltMinder:AltM_Out("AltMinder Error(40):" .. main .. " is already defined as an alt.")
    return -1
  elseif( ret == 0 ) then
    AltM_SavedVars[sRealmName].AltM_Alts[alt] = {}
    AltM_SavedVars[sRealmName].AltM_Alts[alt] = { main=main }
  else
    AltMinder:AltM_Out("AltMinder Error(50):" .. alt .. " is already defined as an alt of " .. AltM_SavedVars[sRealmName].AltM_Alts[alt].main )
    return -1
  end

  return 0
end

-------------------------------------------------------------------------------
--                                   AltM_DelAlt
-------------------------------------------------------------------------------
--
-- AltM_DelAlt() -- Removes the given alt from the alt table
--
-- Arguements:
--     string             alt
--
-- Description: Searches for an alt and removes it from the alt table.
--
-- Notes: This routine does _NOT_ remove the alt from it's main.
--

function AltMinder:AltM_DelAlt(alt)

  ret = AltMinder:AltM_FindAlt(alt,sRealmName)
  if( ret ~= 1 ) then
    AltMinder:AltM_Out("AltMinder Error(60:" .. ret .. "):" .. alt .. " is not defined.")
    return -1
  end

  AltM_SavedVars[sRealmName].AltM_Alts[alt] = nil;
  --AltM_TableRemove( AltM_SavedVars[sRealmName].AltM_Alts,alt)

  return 0
end


-------------------------------------------------------------------------------
--                              AltM_AddAltToMain
-------------------------------------------------------------------------------
--
-- AltM_AddAltToMain() -- Adds an alt to the main table.
--
-- Arguements:
--     string             main
--     string             alt
--
--
--  Description: Given a main and alt, the main table to searched for its
--  entry, and then 'alt' is added to it.
--
-- Notes:  It is not the province of this routine to check for an alt
--     already being a main. That should have been done externally.
--
function AltMinder:AltM_AddAltToMain(main,alt)

-- if the alt is already in the main's list, then return

  if( AltM_SavedVars[sRealmName].AltM_Mains[main].alts[alt] ) then
    AltMinder:AltM_Out(alt .. " is already an alt of " .. main)
    return 0
  end

  if( AltMinder:AltM_FindMain(alt,sRealmName) ~= 0) then 
    AltMinder:AltM_Out("AltMinder Error(70):" .. alt .. " is already defined as a main.")
    return -1
  end

  ret = AltMinder:AltM_FindAlt(alt,sRealmName) 
  if( ret == 1 ) then 
    if( AltM_SavedVars[sRealmName].AltM_Mains[main].alts[alt] ) then
      AltMinder:AltM_Out("AltMinder Error(80):" .. alt .. " is already defined as an alt of " .. AltM_SavedVars[sRealmName].AltM_Alts[alt].main )
      return -1
    end
  elseif( ret < 0 ) then
      AltMinder:AltM_Out("AltMinder Error(82): There was an error finding status of " .. alt)
  end

  table.insert(AltM_SavedVars[sRealmName].AltM_Mains[main].alts,alt)

 return 0

end

-------------------------------------------------------------------------------
--                              AltM_AddAltListToMain
-------------------------------------------------------------------------------
--
-- AltM_AddAltListToMain() --  Adds an altList to the main table and creates
--         entries for each alt in the alt table.
--
-- Arguements:
--     string             main
--     table              tAltList
--
--
--  Description:Given a main and a comma ',' separated altList, both the main
--      and alt tables are updated with the given information.
--
-- Notes:
--
function AltMinder:AltM_AddAltListToMain(main,tAltList)
  local iListLen = 1
  local iCntr = 1

  if(main == nil or main == "") then
    return
  end

  iListLen = table.getn(tAltList)
  for iCntr=1,iListLen do
    AltM_AddAltToMain(main,tAltList[iCntr])
    AltM_AddAlt(main,tAltList[iCntr])
  end
end

-------------------------------------------------------------------------------
--                                   AltM_FindMain
-------------------------------------------------------------------------------
--
-- AltM_FindMain() -- Routine to check if a main exists
--
-- Arguements:
--       string       main
--       string       server
--
-- Description: When called this routine searches the main Table for 'main'
-- If it is found, it returns 1
-- successful operation but no match is zero
-- otherwise <0 is returned.
--
-- Notes:
--
function AltMinder:AltM_FindMain(main, server)

  if( main == nil or main == "" ) then
    return -3
  end

  if( AltM_SavedVars == nil ) then
    return -2
  end

  if( server == nil ) then
	  server = sRealmName
	  if( server == nil ) then
		  return -1
	  end
  end

  if( AltM_SavedVars[sRealmName].AltM_Mains[main] == nil ) then
    return 0
  end

  return 1
end

-------------------------------------------------------------------------------
--                                   AltM_FindAlt
-------------------------------------------------------------------------------
--
-- AltM_FindAlt() -- Routine to find an alt exists
--
-- Arguements:
--       string       alt
--
-- Description: When called this routine searches the Alt Table for 'alt' and
-- If it is found, it returns 1
-- successful operation but no match is zero
-- otherwise <0 is returned.
--
-- Notes:
--
function AltMinder:AltM_FindAlt(alt,server)

  --AltMinder:AltM_Out("DELME1: alt:" .. alt .. " server:" .. server)

  if( alt == nil or alt == "") then
	  return -3
  end

  --AltMinder:AltM_Out("DELME2: alt:" .. alt .. " server:" .. server)
  if( AltM_SavedVars == nil ) then
    return -2
  end

  --AltMinder:AltM_Out("DELME3: alt:" .. alt .. " sRealmName:" .. sRealmName)
  if( server == nil ) then
	  server = sRealmName
	  if( server == nil ) then
		  return -1
	  end
  end

  --AltMinder:AltM_Out("DELME4: alt:" .. alt .. " server:" .. server)

  if( AltM_SavedVars[server] == nil ) then
    AltMinder:AltM_Out("DELME5: NO SERVER TABLE alt:" .. alt .. " server:" .. server)
    return -4
  end

  if( AltM_SavedVars[server].AltM_Alts[alt] == nil ) then
    return 0
  end

  --AltMinder:AltM_Out("DELME9: alt:" .. alt .. " server:" .. server)
  return 1
end




-------------------------------------------------------------------------------
--                                   AltM_DumpData
-------------------------------------------------------------------------------
--
-- AltM_DumpData() -- Routine to dump the data to the chat frame
--
-- Arguements: none
--
-- Description: Poorly formatted routine that dumps the data out in an
-- unfriendly format.
--
-- Notes:
--
function AltMinder:AltM_DumpData(flag)
 

  AltMinder:AltM_Out( "/altm dumpdata is not implemented in the new version of altminder" )
  if 1 then return 0 end

  if(flag == "main") then
    AltMinder:AltM_Out("Main Table:")
    for main in AltM_SavedVars[sRealmName].AltM_Mains do
      AltMinder:AltM_Out( "Main:" .. main .. "  with:" .. table.concat(AltM_SavedVars[sRealmName].AltM_Mains[main].alts, ", ") )
    end
  elseif(flag == "alt") then
    AltMinder:AltM_Out("Alt Table:")
    for alt in AltM_SavedVars[sRealmName].AltM_Alts do
      AltMinder:AltM_Out( "Alt:" .. alt .. "  of:" .. AltM_SavedVars[sRealmName].AltM_Alts[alt].main)
    end
  else
    AltMinder:AltM_Out("Please select either 'main' or 'alt after /altm dumpdata")
  end
end

-------------------------------------------------------------------------------
--                                   AltM_PurgeData
-------------------------------------------------------------------------------
--
-- AltM_PurgeData() -- Routine to purge the data from the tables
--
-- Arguements: none
--
-- Description: Completely empties the tables of data.
--
-- Notes:
--
function AltMinder:AltM_PurgeData()

  AltM_SavedVars[sRealmName].AltM_Alts = {}

  AltM_SavedVars[sRealmName].AltM_Mains = {}

  AltMinder:AltM_Out("AltMinder: Data Purged.")
end


-------------------------------------------------------------------------------
--                                   AltMinder:AltM_Out
-------------------------------------------------------------------------------
--
-- AltMinder:AltM_Out() --  Wrapper around output messages
--
-- Arguements:
--   string          message
--
-- Description: This routine is a wrapper around the output routines. It is
-- supposed to make sure the correct output is calles based on wether or not
-- the Hook is in place.
--
-- Notes:
--
function AltMinder:AltM_Out(message, ...)
    DEFAULT_CHAT_FRAME:AddMessage(message, ...)
end

-------------------------------------------------------------------------------
--                                   AltM_ChangeOnlyAlt
-------------------------------------------------------------------------------
--
-- AltM_ChangeOnlyAlt() -- Changes the given alt from the alt table
--
-- Arguements:
--   alt    Name of the alt to change
--  newname    New name of alt
--
-- Description: Searches for an alt and changes it.
--
-- Notes: This routine does not change the alt in its main.
--

function AltMinder:AltM_ChangeOnlyAlt(alt,newname)

  local sMainName = "AltM_Bogus_Main_Name"
  
  iPos = AltMinder:AltM_FindAlt(alt,sRealmName)

  if(iPos == 0) then
    AltMinder:AltM_Out("AltMinder Error(90): no alt named" .. alt .. "was found.")
    return -1
  end

-- make new alt entry with old entry stuff

  main = AltM_SavedVars[sRealmName].AltM_Alts[alt].main

  AltM_SavedVars[sRealmName].AltM_Alts[newname] = {}

  AltM_SavedVars[sRealmName].AltM_Alts[newname] = { main=main }

-- remove old alt entry
  AltM_TableRemove(AltM_SavedVars[sRealmName].AltM_Alts,alt)
  return 0
end

-------------------------------------------------------------------------------
--                                   AltM_ChangeAlt
-------------------------------------------------------------------------------
--
-- AltM_ChangeAlt() -- Changes the given alt from the alt table
--
-- Arguements:
--   alt    Name of the alt to change
--  newname    New name of alt
--
-- Description: Searches for an alt and changes it.
--
-- Notes: This routine does change the alt in its main.
--

function AltMinder:AltM_ChangeAlt(alt,newname)

  local sMainName = "AltM_Bogus_Main_Name"
  
  iPos = AltMinder:AltM_FindAlt(alt,sRealmName)

  if(iPos == 0) then
    AltMinder:AltM_Out("AltMinder Error(100): no alt named" .. alt .. "was found.")
    return -1
  end

-- find the main of this alt.
  sMainName = AltM_SavedVars[sRealmName].AltM_Alts[alt].main

-- add the new alt
  table.insert(AltM_SavedVars[sRealmName].AltM_Mains[sMainName].alts,newname)

-- remove the old alt from the main
  AltM_TableRemove(AltM_SavedVars[sRealmName].AltM_Mains[sMainName].alts,alt)

-- Chnage the alt table
  return AltM_ChangeOnlyAlt(alt,newname)

end

-------------------------------------------------------------------------------
--                                   AltM_ChangeMain
-------------------------------------------------------------------------------
--
-- AltM_ChangeMain() -- Changes the name of the given main
--
-- Arguements:
--   main    Name of the main to change
--  newname    New name of main
--
-- Description: Searches for an main and changes it.
--
-- Notes: This routine does change the alts of this main.
--

function AltMinder:AltM_ChangeMain(main,newname)

  local sAltName

-- check for the main
  if(AltMinder:AltM_FindMain(main,sRealmName) ~= 1) then
    AltMinder:AltM_Out("AltMinder Error(110):" .. main .. " was not found successfully.")
    return -1
  end

-- change every alt's main to the new main.
  for ignore,sAltName in pairs(AltM_SavedVars[sRealmName].AltM_Mains[main].alts) do
    AltM_SavedVars[sRealmName].AltM_Alts[sAltName].main = newname
  end

-- add the new main with the old main's data
  AltM_SavedVars[sRealmName].AltM_Mains[newname] = AltM_SavedVars[sRealmName].AltM_Mains[main]

-- remove the old main
  AltM_SavedVars[sRealmName].AltM_Mains[main] = nil

end

-------------------------------------------------------------------------------
--                              AltM_GetAltsFromMain
-------------------------------------------------------------------------------
--
-- AltM_GetAltsFromMain() -- Routine to find and report all the alts associated
-- with a given main in the form of a printable list.
--
-- Arguements:
--       string       main
--
-- Description: When called this routine returns a list of alt names
--

function AltMinder:AltM_GetAltsFromMain(main)
  return table.concat(AltM_SavedVars[sRealmName].AltM_Mains[main].alts, ", ")
end
