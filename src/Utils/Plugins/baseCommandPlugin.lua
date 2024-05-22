return {
	Name = "exampleCommandPlugin",
	Type = "Command",
	Description = "Example description",
	Permissions = 0,
	Shorteners = { "ecp" },
	prefixType = "Dom", -- "Dom" OR "Sub"
	usage = "",
	Callback = function(Player: Player, ...: any)
		warn(Player, ...)
	end,
}
