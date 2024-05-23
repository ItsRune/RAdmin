return {
	Prefix = ":",
	subPrefix = "!",
	Permissions = {
		Roles = {
			{
				Name = "Game Creator",
				Permission = 4,
				-- Below is the name shortener for
				-- 'setperms user shortener' OR 'shortener user'
				Shortener = "owner",
				Users = {},
			},
			{
				Name = "Administrator",
				Permission = 3,
				-- Below is the name shortener for
				-- 'setperms user shortener' OR 'shortener user'
				Shortener = "admin",
				Users = {},
			},
			{
				Name = "Moderator",
				Permission = 2,
				-- Below is the name shortener for
				-- 'setperms user shortener' OR 'shortener user'
				Shortener = "mod",
				Users = {},
			},
			{
				Name = "Donator",
				Permission = 1,
				-- Below is the name shortener for
				-- 'setperms user shortener' OR 'shortener user'
				Shortener = "dono",
				Users = {},
			},
		},

		Groups = {
			{
				groupId = 2859030,
				permissionLevel = 5,
				rankRequired = 200,
				Tolerance = ">=",
			},
		},
	},

	--[[
		This section will allow for easy configuration of 4 powerful commands,
		these commands relate to group rank management within game servers. You
		will need an external bot account in order to properly use these, we will
		NOT supply one for you.
	]]
	--
	appProtocolInterfaces = {
		{
			usedFor = "", -- Command Name (Promote/Demotion/SetRank/Etc)
			Request = {
				-- See 'https://create.roblox.com/docs/reference/engine/classes/HttpService#RequestAsync'
				-- for reference of what to put into below. (Do not encode the Body)
				Url = "",
				Method = "",
				Headers = {},
				Body = {},
			},
			allowCaching = false, -- When true, it'll cache the result and add a timeout
			retryRate = 0, -- Retry rate for queued 429 (Too Many Requests)
			retryTimeout = 0, -- If unknown leave as 0
		},
	},

	--[[
		- Each message type has it's own formatting codes.
		'Kicks' (Related commands 'pban', 'kick', 'ban'):
			<Issuer> -> The username of the player who issued the kick.
			<Timestamp> -> The timestamp of when the kick occurred.
			<Reason> -> The provided reason for the kick
			(Punctuation) -> This is an option, if you'd like punctuation
				to be within kick reasons, this will add the character supplied
				if the reason doesn't have it already.
	]]
	--
	Messages = {
		Kicks = {
			-- Shown when a player is banned from the game server.
			Ban_Reason = "You have been banned from the server for <Reason>(.)",

			-- Shown when a player is kicked from the game.
			Kick_Reason = "You have been kicked from the server for <Reason>(.)",

			-- Shown when a player is perma banned from the game.
			Perm_Ban_Reason = "You have been permanently banned from the game for <Reason>(!)",
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
	allowedCommandArgShorteners = {
		"all",
		"others",
		"me",
		"updo",
		"bacons",
		"random",
		-- "fake_shortener" -- This will disable it's use
	},

	dataStoreName = "RAdmin_Data",
}
