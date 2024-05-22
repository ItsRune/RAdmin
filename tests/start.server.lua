local Module = script.Parent.MainModule
local Hook = require(Module)

Hook(
	require(Module.Utils.baseConfiguration),
	{ Module.Utils.Plugins.baseCommandPlugin, Module.Utils.Plugins.baseEnvPlugin }
)
