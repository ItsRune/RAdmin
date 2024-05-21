--// Services \\--
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

--// Variables \\--
local Player = Players.LocalPlayer
local playerGui = Player:WaitForChild("PlayerGui")

local Gui, remoteEvent, remoteInvoke, TweenService, Table

local Mainframe = {
	userPermission = 0,
	Prefixes = { ":", "!" },
	Commands = {}, -- { Name: string, Desc: string, Perms: number, Shortener: { string? }, prefixType: "Dom" | "Sub", Usage: string }
	Roles = {}, -- { [Permission]: string<roleName> }
	Connections = {},

	_lowestPermission = -0x80000000,

	-- States
	_consoleToggled = false,
}

--// Functions \\--
local function Disconnect(item: { RBXScriptConnection } | RBXScriptConnection)
	if typeof(item) == "table" then
		for _, v in item do
			Disconnect(v)
		end
	elseif typeof(item) == "RBXScriptConnection" then
		item:Disconnect()
	end
end

local function toggleConsole()
	local newState = not Mainframe._consoleToggled
	local Info = TweenInfo.new(0.35, Enum.EasingStyle.Exponential)
	local transparency = newState and 0 or 1

	Mainframe._consoleToggled = newState

	TweenService(Gui.Console, Info, {
		GroupTransparency = transparency,
	}):Play()
end

local function onUserInputBegan(Input: InputObject, gameProcessing: boolean)
	if gameProcessing then
		return
	end

	if
		Input.UserInputType == Enum.UserInputType.Keyboard
		and Input.KeyCode == Enum.KeyCode.Quote
		and not Mainframe._consoleToggled
	then
		toggleConsole()
		Gui.Console.Input:CaptureFocus()

		Mainframe.Connections["consoleInput"] = Gui.Console.Input.FocusLost:Connect(function(enterPressed: boolean)
			toggleConsole()
			Disconnect(Mainframe.Connections["consoleInput"])

			if not enterPressed then
				return
			end

			remoteInvoke:InvokeServer("Command", Gui.Console.Input.Text)
		end)

		task.wait()
		Gui.Console.Input.Text = ""
	end
end

local function onClientEvent(Command: string, ...: any)
	local Data = { ... }

	if Command == "adminUpdate" then
		if Data[1] == Mainframe._lowestPermission then
			if not Mainframe.Connections["InputBegan"] then
				return
			end

			Mainframe.Connections["InputBegan"]:Disconnect()
			Mainframe.Connections["InputBegan"] = nil
			return
		end

		-- Ensure 1 connection stays and no more are created.
		if Mainframe.Connections["InputBegan"] ~= nil then
			return
		end

		Mainframe.Connections["InputBegan"] = UserInputService.InputBegan:Connect(onUserInputBegan)
	end
end

local function onStart()
	Mainframe.Connections["playerGuiUpdated"] = playerGui.ChildAdded:Connect(function(Child: Instance)
		if Child.Name == "RAdminGui" then
			Gui = Child
		end
	end)

	local sharedFolder = ReplicatedStorage:WaitForChild("RAdminShared")
	remoteEvent, remoteInvoke, Table, TweenService =
		sharedFolder:WaitForChild("RAdminEvent"),
		sharedFolder:WaitForChild("RAdminFunction"),
		require(sharedFolder:WaitForChild("Table")),
		require(sharedFolder:WaitForChild("TweenService"))

	remoteEvent.OnClientEvent:Connect(onClientEvent)

	local usefulInformation = remoteInvoke:InvokeServer("clientInfo")
	Mainframe.userPermission = usefulInformation[1]
	Mainframe.Prefixes = usefulInformation[2]
	Mainframe.Commands = usefulInformation[3]
	Mainframe.Roles = usefulInformation[4]
end

--// Start \\--
onStart()
