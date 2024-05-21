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
