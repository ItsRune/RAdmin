--# selene: allow(incorrect_standard_library_use)
--// Override \\--
local this = script
script = Instance.new("ModuleScript")

for _, v in pairs(this:GetDescendants()) do
	if v:IsA("Package") then
		v.Parent = script
	end
end

--// Services \\--
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")

--// Modules \\--
local Table = require(script.Table)
local createCommand = require(script.createCommand)
local baseConfiguration = require(script.baseConfiguration)

--// Variables \\--
local dataStore, remoteEvent, remoteInvoke
local clientScript = script.client

local Commands = {}
local Mainframe = {
	Configuration = Table.Clone(baseConfiguration, true),
	userPermissions = {},
	Connections = {},
	commandLogs = {},
	joinAndLeaveLogs = { {}, {} },
}

--// Functions \\--
local function Warn(...: any)
	warn(string.format("[%s]:", "RAdmin"), ...)
end

local function findPlayer(Player: Player, argumentToCheck: string, isAbusiveCommand: boolean?)
	local users = {}
	local argSplit = string.split(argumentToCheck, ",")

	if not argumentToCheck or tostring(argumentToCheck) == nil then
		return users
	end

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
	local clonedData = Table.Clone(Mainframe.Configuration.Permissions.Groups, true)
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

	return highestPermission
end

local function fetchHighestUserPermissions(Player: Player)
	local highestPermission = nil

	for _, roleData: { any } in Mainframe.Configuration.Roles do
		if highestPermission ~= nil and roleData < highestPermission then
			continue
		end

		if table.find(roleData.Users, Player.UserId) ~= nil then
			highestPermission = roleData.Rank
		end
	end

	return highestPermission
end

local function changePlayerPermission(Player: Player, newPermission: number)
	Mainframe.userPermissions[Player.UserId] = newPermission

	remoteEvent:FireClient(Player, "adminUpdate", newPermission)
end

local function fetchHighestPermissionForPlayer(Player: Player)
	local userPermission = fetchHighestUserPermissions
	local groupPermission = fetchHighestGroupPermissions(Player)

	local permissionToUse = (userPermission > groupPermission) and userPermission or groupPermission

	Mainframe.userPermissions[Player.UserId] = permissionToUse
end

local function handleCommandInput(Player: Player, Message: string)
	local prefixToUse = (
		string.sub(Message, 1, #Mainframe.Configuration.subPrefix) == Mainframe.Configuration.subPrefix
	)
			and Mainframe.Configuration.subPrefix
		or (string.sub(Message, 1, #Mainframe.Configuration.Prefix) == Mainframe.Configuration.Prefix) and Mainframe.Configuration.Prefix
		or nil

	if not prefixToUse then
		return
	end

	local prefixType = (prefixToUse == Mainframe.Configuration.Prefix) and "dom" or "sub"
	local commandArgs = string.split(string.sub(Message, #prefixToUse + 1, #Message), " ")

	local commandData = Table.Find(Commands, function(Command)
		local shorts = table.clone(Command.Shortener)
		table.insert(shorts, string.lower(Command.Name))

		return string.lower(Command.prefixType) == prefixType
			and Table.Find(shorts, function(shortString: string)
					return string.lower(commandArgs[1]) == shortString
				end)
				~= nil
	end)

	if not commandData then
		Warn("No command data!", commandArgs, prefixType)
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

	local permissionLevel = fetchHighestPermissionForPlayer(Player)
	if not permissionLevel then
		return
	end

	changePlayerPermission(Player, permissionLevel)
end

local function onPlayerRemoving(Player: Player)
	table.insert(Mainframe.joinAndLeaveLogs[2], Player.Name)

	for _, Connection: RBXScriptConnection in pairs(Mainframe.Connections[Player.UserId]) do
		Connection:Disconnect()
	end

	Mainframe.Connections[Player.UserId] = nil
end

local function onServerInvoke(Player: Player, Command: string, ...: any)
	if Command == "Command" then
		handleCommandInput(Player, ...)
		return true
	end
end

--// Commands \\--
createCommand(
	Commands,
	"Forcefield",
	"Creates one or more forcefields and parents it to a player's character",
	{ "ff" },
	1,
	"Dom",
	"<User(s)>",
	function(Player: Player, ...: any)
		local Args = { ... }
		local targetList = Args[1]
		local Targets = findPlayer(Player, targetList)

		for _, Target: Player in Targets do
			Instance.new("ForceField").Parent = Target.Character
		end
	end
)

createCommand(
	Commands,
	"Undo ForceField",
	"Destroys all forcefields within a player's character.",
	{ "unff" },
	1,
	"Dom",
	"<User(s)>",
	function(Player: Player, ...: any)
		local Args = { ... }
		local targetList = Args[1]
		local Targets = findPlayer(Player, targetList)

		for _, Target: Player in Targets do
			if not Target.Character then
				continue
			end

			for _, Child: Instance in pairs(Target.Character:GetChildren()) do
				if not Child:IsA("ForceField") then
					continue
				end

				Child:Destroy()
			end
		end
	end
)

--// Main \\--
return function(Configuration: { any })
	dataStore = DataStoreService:GetDataStore(Mainframe.Configuration.dataStoreName)
	Mainframe.Configuration = Configuration

	script.Parent = ServerScriptService

	local newClient = clientScript:Clone()
	newClient.Parent = StarterPlayer:WaitForChild("StarterPlayerScripts")
	newClient.Enabled = true

	local sharedFolder = Instance.new("Folder")
	sharedFolder.Name = "RAdmin_Shared"
	sharedFolder.Parent = ReplicatedStorage

	remoteEvent, remoteInvoke = Instance.new("RemoteEvent"), Instance.new("RemoteFunction")
	remoteEvent.Name, remoteInvoke.Name = "RAdmin_Event", "RAdmin_Invoke"
	remoteEvent.Parent, remoteInvoke.Parent = sharedFolder, sharedFolder

	remoteInvoke.OnServerInvoke = onServerInvoke

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end
