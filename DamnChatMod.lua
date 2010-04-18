local DamnChat = select(2, ...)
local queuedID, queueType

function DamnChat:ADDON_LOADED(addon)
	if( addon ~= "DamnChatMod" ) then return end
	self:UnregisterEvent("ADDON_LOADED")
	
	DamnChatModDB = DamnChatModDB or {whitelist = {}}
end

local function randomChannelIndex(channelID)
	for i=1,  GetNumDisplayChannels() do
		if( i ~= channelID and not select(2, GetChannelDisplayInfo(i)) ) then
			return i
		end
	end
end

local function pullPlayers(channelID)
	local randomID = randomChannelIndex(channelID)
	if( randomID ) then
		DamnChat:RegisterEvent("CHANNEL_ROSTER_UPDATE")
		SetSelectedDisplayChannel(randomID)
		SetSelectedDisplayChannel(channelID)
	else
		DamnChat:CHANNEL_ROSTER_UPDATE(channelID, nil)
	end
end

local function getChannelIndex(channel)
	channel = string.lower(channel)
	for i=1,  GetNumDisplayChannels() do
		local name, _, _, channelNumber, count = GetChannelDisplayInfo(i)
		if( string.lower(name) == channel ) then
			return i, count
		end
	end
	
	return nil
end

local function getNonModerators(channelID)
	local players = {}
	for i=1, select(5, GetChannelDisplayInfo(channelID)) do
		local name, _, moderator  = GetChannelRosterInfo(channelID, i)
		if( name and not moderator ) then
			table.insert(players, name)
		end
	end
	return players
end

local function getModerators(channelID)
	local players, ownerName = {}
	for i=1, select(5, GetChannelDisplayInfo(channelID)) do
		local name, owner, moderator = GetChannelRosterInfo(channelID, i)
		if( owner ) then
			ownerName = name
		end
		
		if( moderator ) then
			table.insert(players, name)
		end
	end
	
	return players, ownerName
end

local function removeHiddenMods(channelID)
	local channel = GetChannelDisplayInfo(channelID)
	local mods, owner = getModerators(channelID)
	if( owner ~= UnitName("player") ) then
		DamnChat:Print(string.format("[%s] Failed to remove hidden moderators, you need to be the channel owner. %s is currently the owner", channel, owner))
		return
	end

	local players = getNonModerators(channelID)
	for _, player in pairs(players) do
		ChannelModerator(channel, player)
		ChannelUnmoderator(channel, player)
	end
	
	DamnChat:Print(string.format("[%s] Removed all hidden moderators", channel))
end

local function removeModerators(channelID)
	local channel = GetChannelDisplayInfo(channelID)
	local mods, owner = getModerators(channelID)
	if( owner ~= UnitName("player") ) then
		DamnChat:Print(string.format("[%s] Failed to demote moderators, you need to be the channel owner. %s is currently the owner", channel, owner))
		return
	end

	local whitelist = DamnChatModDB.whitelist[string.lower(channel)]
	local playerName = string.lower(UnitName("player"))
	for i=#(mods), 1, -1 do
		moderator = string.lower(mods[i])
		if( whitelist[moderator] or moderator == playerName ) then
			table.remove(mods, i)
		else
			ChannelUnmoderator(channel, mods[i])
		end
	end
		
	DamnChat:Print(string.format("[%s] Removing %d moderators: %s", channel, #(mods), table.concat(mods, ", ")))
end

local function listModerators(channelID)
	local mods, owner = getModerators(channelID)
	local name, _, _, _, players = GetChannelDisplayInfo(channelID)
	DamnChat:Print(string.format("[%s] %d moderators out of %d: %s", name, #(mods), players, table.concat(mods, ", ")))
	if( owner ~= UnitName("player") ) then
		DEFAULT_CHAT_FRAME:AddMessage(string.format("You will need channel owner to demote moderators, %s is owner", owner))
	end
end

function DamnChat:CHANNEL_ROSTER_UPDATE(channelID, players)
	if( channelID ~= queuedID ) then return end
	self:UnregisterEvent("CHANNEL_ROSTER_UPDATE")
	
	if( queueType == "hidden" ) then
		removeHiddenMods(channelID)
	elseif( queueType == "list" ) then
		listModerators(channelID)
	elseif( queueType == "demod" ) then
		removeModerators(channelID)
	end

	queuedID, queueType = nil, nil
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
	DamnChat[event](DamnChat, ...)
end)

function DamnChat:RegisterEvent(event) frame:RegisterEvent(event) end
function DamnChat:UnregisterEvent(event) frame:UnregisterEvent(event) end
function DamnChat:Print(msg) DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99Damn Mod|r: " .. msg) end

SLASH_DAMNCHAT1 = "/damnchat"
SLASH_DAMNCHAT2 = "/dc"
SlashCmdList["DAMNCHAT"] = function(msg)
	local cmd, arg = string.split(" ", msg or "", 2)
	cmd = string.lower(cmd or "")
	
	if( cmd == "mods" and arg ) then
		local channelID, players = getChannelIndex(arg)
		if( not channelID ) then
			DamnChat:Print(string.format("Failed to find the channel \"%s\"", arg))
			return
		end
		
		DamnChat:Print(string.format("Pulling players for %s from the server, listing moderators in a minute.", arg))
		queuedID, queueType = channelID, "list"
		pullPlayers(channelID)

--[[
	elseif( cmd == "hdmod" and arg ) then
		local channelID, players = getChannelIndex(arg)
		if( not channelID ) then
			DamnChat:Print(string.format("Failed to find the channel \"%s\"", arg))
			return
		end
		
		DamnChat:Print(string.format("Pulling players for %s from the server, removing hidden moderators in a miute.", arg))
		queuedID, queueType = channelID, "hidden"
		pullPlayers(channelID)
]]		
	elseif( cmd == "unmod" and arg ) then
		local  channelID, players = getChannelIndex(arg)
		if( not channelID ) then
			DamnChat:Print(string.format("Failed to find the channel \"%s\"", arg))
			return
		end

		DamnChat:Print(string.format("Pulling players for %s from the server, removing all unapproved moderators in a minute.", arg))
		queuedID, queueType = channelID, "demod"
		pullPlayers(channelID)
		
	elseif( cmd == "white" and arg ) then
		local channel, playerName = string.split(" ", arg, 2)
		if( not channel or not playerName ) then
			DamnChat:Print(string.format("Invalid commands passed to whitelist, channel \"%s\", player \"%s\".", channel or "", playerName or ""))
			return
		elseif( string.lower(playerName) == string.lower(UnitName("player")) ) then
			DamnChat:Print("You do not need to add yourself to the whitelist, you are automatically ignored.")
			return
		end
		
		DamnChatModDB.whitelist[string.lower(channel)] = DamnChatModDB.whitelist[string.lower(channel)] or {}
		DamnChatModDB.whitelist[string.lower(channel)][string.lower(playerName)] = playerName
		DamnChat:Print(string.format("Added %s to a whitelist for channel %s", playerName, channel))
	elseif( cmd == "rmwhite" and arg ) then
		local channel, playerName = string.split(" ", arg, 2)
		if( not channel or not playerName ) then
			DamnChat:Print(string.format("Invalid commands passed to whitelist, channel \"%s\", player \"%s\".", channel or "", playerName or ""))
			return
		elseif( not DamnChatModDB.whitelist[string.lower(channel)] or not DamnChatModDB.whitelist[string.lower(channel)][string.lower(playerName)] ) then
			DamnChat:Print(string.format("Player %s is not on the whitelist for the channel %s.", playerName, channel))
			return
		end
		
		DamnChatModDB.whitelist[string.lower(channel)][string.lower(playerName)] = nil
		DamnChat:Print(string.format("Removed %s from the whitelist for channel %s", playerName, channel))

		local found
		for k in pairs(DamnChatModDB.whitelist[string.lower(channel)]) do found = true break end
		if( not foudn ) then
			DamnChatModDB.whitelist[string.lower(channel)] = nil
		end
		
	elseif( cmd == "lswhite" ) then
		local total = 0
		for k in pairs(DamnChatModDB.whitelist) do total = total + 1 end
		
		DamnChat:Print(string.format("Listing %d channel whitelists", total))
		for channel, list in pairs(DamnChatModDB.whitelist) do
			local players = {}
			for _, name in pairs(list) do table.insert(players, name) end
			
			DEFAULT_CHAT_FRAME:AddMessage(string.format("[%s] %s", channel, table.concat(players, ", ")))
		end
	else
		DamnChat:Print("Slash commands")
		DEFAULT_CHAT_FRAME:AddMessage("/damnchat mods <channel name> - Lists moderators in the given channel")
		--DEFAULT_CHAT_FRAME:AddMessage("/damnchat hdmod <channel name> - Removes hidden moderators from the channel, THIS WILL SPAM.")
		DEFAULT_CHAT_FRAME:AddMessage("/damnchat unmod <channel name> - Removes all current moderators in a channel, unless they are yourself or on the whitelist")
		DEFAULT_CHAT_FRAME:AddMessage("/damnchat white <channel name> <player name> - Adds the given player to a per-channel whitelist who will not be mass demoted")
		DEFAULT_CHAT_FRAME:AddMessage("/damnchat rmwhite <channel name> <player name> - Removes a player from a channels whitelist")
		DEFAULT_CHAT_FRAME:AddMessage("/damnchat lswhite - Lists the whitelist for all channels and the players in them")
	end
end