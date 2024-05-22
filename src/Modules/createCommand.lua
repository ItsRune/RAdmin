return function(
	commandsTbl: { any },
	name: string,
	description: string,
	shortener: { string? },
	perms: number,
	prefixType: "Sub" | "Dom",
	usage: string,
	callback: (Player: Player, ...any) -> ()
)
	local isOk, err = pcall(
		assert,
		typeof(commandsTbl) == "table",
		string.format(
			"First parameter for '%s' should be the commands table!",
			typeof(commandsTbl) == "string" and commandsTbl or "Unknown"
		)
	)

	if not isOk then
		local stackTrace = debug.traceback(nil, 2)
		warn("[RAdmin]:", err, "\n", stackTrace)
		return
	end

	table.insert(commandsTbl, {
		Name = name,
		Desc = description,
		Perms = perms,
		Shortener = shortener,
		prefixType = prefixType,
		Usage = usage,
		Callback = callback,
	})
end
