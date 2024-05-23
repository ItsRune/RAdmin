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

	TweenService(Gui.ConsoleDropdown, Info, {
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
		local amountOfFrames = 0

		Mainframe.Connections["consoleDropdown"] = Gui.Console.Input
			:GetPropertyChangedSignal("ContentText")
			:Connect(function()
				local input = Gui.Console.Input.ContentText
				local split = string.split(input, " ")

				if #split ~= 1 or string.sub(input, 1, 1) == "" then
					return
				end

				if amountOfFrames > 0 then
					for i = 1, amountOfFrames do
						Gui.ConsoleDropdown[tostring(i)]:Destroy()
					end
				end

				Disconnect(Mainframe.Connections["consoleDropdownButtons"])
				Gui.ConsoleDropdown.Size = UDim2.fromOffset(0, 0)
				amountOfFrames = 0

				local domPrefix = string.sub(input, 1, 1) == Mainframe.Prefixes[1]
				local subPrefix = string.sub(input, 1, 1) == Mainframe.Prefixes[2]
				local hasPrefix = (domPrefix or subPrefix)
				local contentWithoutPrefix = hasPrefix and string.sub(input, 2, #input) or input
				local commandsToDisplay = {}
				local maxCommandsToDisplay = UserInputService.TouchEnabled and 3 or 5

				for _, commandData: { any } in Mainframe.Commands do
					if commandData.Perms < Mainframe.userPermission then
						continue
					end

					for _, commandShortener: string in commandData.Shortener do
						if
							string.sub(string.lower(commandShortener), 1, #contentWithoutPrefix)
							== string.lower(contentWithoutPrefix)
						then
							table.insert(commandsToDisplay, {
								Name = commandShortener,
								Desc = commandData.Desc,
								prefixType = commandData.prefixType,
								Usage = commandData.Usage,
								Perms = commandData.Perms,
							})
							break
						end
					end

					if #commandsToDisplay == maxCommandsToDisplay then
						break
					end
				end

				local function getPrefix(commandData: { any }): string
					if not hasPrefix then
						return ""
					end

					return (string.lower(commandData.prefixType) == "dom") and Mainframe.Prefixes[1]
						or Mainframe.Prefixes[2]
				end

				Mainframe.Connections["consoleDropdownButtons"] = {}
				amountOfFrames = #commandsToDisplay

				Gui.ConsoleDropdown.Size += UDim2.fromOffset(0, amountOfFrames * 40 + (amountOfFrames > 0 and 5 or 0))
				for i = 1, #commandsToDisplay do
					local commandData = commandsToDisplay[i]
					local newFrame = Gui.Components.consoleDropdownEx:Clone()

					newFrame.Name = i
					newFrame.commandDesc.Text = commandData.Desc
					newFrame.commandName.Text =
						string.format("%s%s %s", getPrefix(commandData), commandData.Name, commandData.Usage)
					newFrame.Position = UDim2.fromOffset(10, (i - 1) * 40 + 5)
					newFrame.Parent = Gui.ConsoleDropdown
					newFrame.Visible = true

					table.insert(
						Mainframe.Connections["consoleDropdownButtons"],
						newFrame.Button.MouseButton1Click:Connect(function()
							warn(newFrame.commandName.Text)
						end)
					)
				end
			end)

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

local function List<T, K>(
	listType: "Complex" | "Simple",
	Title: string,
	Data: { K },
	Schema: { T },
	Options: {
		canRefresh: boolean?,
		canSearch: boolean?,
		refreshMethod: string?,
		complexType: "Dropdown" | "Default"?,
	}
): ()
	if not Title or not Data or not Schema then
		warn("[RAdmin Client]:", "Invalid syntax for '" .. listType .. "' List!")
		return
	end

	Options = Options or {}
	Options.canRefresh = Options.canRefresh or false
	Options.canSearch = Options.canSearch or false
	Options.refreshMethod = Options.refreshMethod or nil
	Options.complexType = Options.complexType or "Default"

	--
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
	elseif Command == "complexList" or Command == "simpleList" then
		local listType = string.match(tostring(Command), "(.+)List")
		listType = string.upper(string.sub(listType, 1, 1)) .. string.lower(string.sub(listType, 2, #listType))

		List(listType, ...)
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
	warn(usefulInformation)
	Mainframe.userPermission = usefulInformation[1]
	Mainframe.Prefixes = usefulInformation[2]
	Mainframe.Commands = usefulInformation[3]
	Mainframe.Roles = usefulInformation[4]
end

--// Start \\--
onStart()
