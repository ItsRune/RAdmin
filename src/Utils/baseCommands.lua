type environmentVariables = {
	Mainframe: { any },
	Commands: { any },
	createCommand: (
		tbl: { any },
		name: string,
		description: string,
		shortener: { string? },
		perms: number,
		prefixType: "Dom" | "Sub",
		usage: string,
		callback: (Player: Player, ...any) -> ()
	) -> (),
	findPlayer: (Player: Player, argumentToCheck: string, isAbusiveCommand: boolean?) -> { Player? },
	changePlayerPermission: (Player: Player, newPermission: number?) -> (),
}

--selene: allow(unused_variable)
local function teleportCharacterToCFrame(Character: Model, toCFrame: CFrame): ()
	-- Player could be possibly sitting in a seat of some kind,
	-- make sure to make the player jump before teleporting (if
	-- they are indeed sitting)

	local humanoid = Character:FindFirstChildOfClass("Humanoid")
	local root = Character.PrimaryPart

	if not humanoid or not root then
		return
	end

	local isSeated, seatedPart = humanoid.Sit, humanoid.SeatPart
	local Connection

	if seatedPart ~= nil and isSeated then
		Connection = seatedPart:GetPropertyChangedSignal("Occupant"):Connect(function()
			Connection:Disconnect()
			root.CFrame = toCFrame
		end)
	else
		humanoid.Jump = isSeated
		root.CFrame = toCFrame
	end
end

return function(env: environmentVariables)
	local Mainframe, Commands, createCommand, findPlayer, changePlayerPermission, handleCommandInput =
		env.Mainframe,
		env.Commands,
		env.createCommand,
		env.findPlayer,
		env.changePlayerPermission,
		env.handleCommandInput

	--/ Forcefield
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

	--/ Unforcefield
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

	--/ Sparkles
	createCommand(
		Commands,
		"Sparkles",
		"Adds sparkles to a player's character.",
		{ "sparkles", "sp", "s" },
		2,
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

				Instance.new("Sparkles").Parent = Target.Character.PrimaryPart
			end
		end
	)

	--/ Unsparkles
	createCommand(
		Commands,
		"Undo Sparkles",
		"Destroys all sparkle instances from a player's character.",
		{ "unsparkles", "unsp", "uns" },
		2,
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

				for _, Child: Instance in pairs(Target.Character.PrimaryPart:GetChildren()) do
					if not Child:IsA("Sparkles") then
						continue
					end

					Child:Destroy()
				end
			end
		end
	)

	--/ Fire
	createCommand(
		Commands,
		"Fire",
		"Adds fire to a player's character.",
		{ "fire", "f" },
		2,
		"Dom",
		"<User(s)> (R) (G) (B)",
		function(Player: Player, ...: any)
			local Args = { ... }
			local targetList = Args[1]
			local color = Color3.fromRGB(tonumber(Args[2]) or 255, tonumber(Args[3]) or 255, tonumber(Args[4]) or 255)
			local Targets = findPlayer(Player, targetList)

			for _, Target: Player in Targets do
				if not Target.Character then
					continue
				end

				local newFire = Instance.new("Fire")
				newFire.Color = color
				newFire.Parent = Target.Character.PrimaryPart
			end
		end
	)

	--/ Unfire
	createCommand(
		Commands,
		"Undo Fire",
		"Destroys all fire instances from a player's character.",
		{ "unfire", "unf" },
		2,
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

				for _, Child: Instance in pairs(Target.Character.PrimaryPart:GetChildren()) do
					if not Child:IsA("Fire") then
						continue
					end

					Child:Destroy()
				end
			end
		end
	)

	--/ Revoke Permissions
	createCommand(
		Commands,
		"Revoke Permissions",
		"Removes a player's permissions and makes them unable to use commands.",
		{ "unadmin", "revokeperms", "rp" },
		2,
		"Dom",
		"<User(s)>",
		function(Player: Player, ...: any)
			local Args = { ... }
			local targetList = Args[1]
			local Targets = findPlayer(Player, targetList, true)
			local currentPermissionLevel = Mainframe.userPermissions[Player.UserId]

			for _, Target: Player in Targets do
				local targetPermission = Mainframe.userPermissions[Target.UserId]
				if targetPermission == nil or currentPermissionLevel <= targetPermission then
					continue
				end

				changePlayerPermission(Target, nil)
			end
		end
	)

	--/ Set Permissions
	createCommand(
		Commands,
		"Set Permissions",
		"Sets a players permission level, ",
		{}, -- This gets set when the admin is loaded.
		2,
		"Dom",
		"<User(s)>",
		function(Player: Player, ...: any)
			local Args = { ... }
			local targetList = Args[1]
			local adminPermission = Args[2]
			local Targets = findPlayer(Player, targetList, true)
			local userPermission = Mainframe.userPermissions[Player.UserId]

			for _, roleData: { any } in Mainframe.Permissions.Roles do
				if userPermission <= roleData.Permission or roleData["Shortener"] == nil then
					continue
				end

				if
					string.sub(string.lower(roleData.Shortener), 1, #adminPermission) == string.lower(adminPermission)
				then
					for _, Target: Player in Targets do
						local targetPermission = Mainframe.userPermissions[Target.UserId]
						if targetPermission >= userPermission then
							continue
						end

						changePlayerPermission(Target, roleData.Permission)
					end
					break
				end
			end
		end
	)

	--/ Kill
	createCommand(
		Commands,
		"Kill",
		"Kills the user(s).",
		{ "kill" },
		1,
		"Dom",
		"<User(s)>",
		function(Player: Player, ...: any)
			local Args = { ... }
			local targetList = Args[1]
			local Targets = findPlayer(Player, targetList, true)

			for _, Target: Player in Targets do
				if not Target.Character then
					continue
				end

				Target.Character.Humanoid.Health = 0
			end
		end
	)

	--/ Sudo
	createCommand(
		Commands,
		"Sudo",
		"Forces another player to run a command.",
		{ "sudo", "force" },
		5,
		"Dom",
		"<User(s)> <...>",
		function(Player: Player, ...: any)
			local Args = { ... }
			local targetList = Args[1]
			local commandToRun = table.concat(Args, " ", 2, #Args) or ""
			local Targets = findPlayer(Player, targetList, true)

			for _, Target: Player in Targets do
				pcall(function()
					handleCommandInput(Target, commandToRun, true)
				end)
			end
		end
	)

	--/ Teleport
	-- createCommand(
	-- 	Commands,
	-- 	"Teleport",
	-- 	"Teleports a player to another player.",
	-- 	{ "teleport", "tp" },
	-- 	2,
	-- 	"Dom",
	-- 	"<User(s)> <User(s)>",
	-- 	function(Player: Player, ...: any)
	-- 		local Args = { ... }
	-- 		local fromTargetList = Args[1]
	-- 		local toTargetList = Args[2]

	-- 		fromTargetList = findPlayer(Player, fromTargetList)
	-- 		toTargetList = findPlayer(Player, toTargetList)

	-- 		local amountOfUsers = #fromTargetList
	-- 		local skippedUsers = 0
	-- 		local PI = math.pi

	-- 		for _, Target: Player in fromTargetList do
	-- 			local character = Target.Character
	-- 			if not character then
	-- 				continue
	-- 			end

	-- 			local x = math.cos()
	-- 		end
	-- 	end
	-- )
end
