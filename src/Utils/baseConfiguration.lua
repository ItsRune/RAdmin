return {
	Prefix = ":",
	subPrefix = "!",
	Permissions = {
		Roles = {
			{
				Name = "Admin Creator",
				Permission = 5,
				Shortener = "debugger", -- Name used for 'setperms user name'
				Users = { 107392833 },
			},
			{
				Name = "Game Creator",
				Permission = 4,
				Shortener = "owner", -- Name used for 'setperms user name'
				Users = {},
			},
			{
				Name = "Administrator",
				Permission = 3,
				Shortener = "admin", -- Name used for 'setperms user name'
				Users = {},
			},
			{
				Name = "Moderator",
				Permission = 2,
				Shortener = "mod", -- Name used for 'setperms user name'
				Users = {},
			},
			{
				Name = "Donator",
				Permission = 1,
				Shortener = "dono", -- Name used for 'setperms user name'
				Users = {},
			},
		},

		Groups = {
			{
				groupId = 0,
				permissionLevel = 0,
				rankRequired = 0,
				Tolerance = "==",
			},
		},
	},

	commandConfig = {
		["fly"] = {
			Permission = 4,
			Abusive = true, -- Forces a command confirmation onto the player's screen
		},
		["unfly"] = {
			Permission = 4,
			Abusive = true, -- Forces a command confirmation onto the player's screen
		},
	},

	-- A list of shorteners the system is allowed to use.
	commandArgShorteners = {
		"all",
		"others",
		"me",
		"updo",
		"bacons",
		"random",
	},

	dataStoreName = "RAdmin_Data",
}
