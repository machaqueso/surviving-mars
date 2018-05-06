return PlaceObj('ModDef', {
	'title', "AutoCargo",
	'description', "Enables your Transport Rovers to automatically haul resources between depots.\r\n\r\nLatest changes: \r\n- Rover will go to nearest cable to recharge if battery is low. A notification will be shown if rover is unable to find a suitable place to recharge.\r\n\r\nKnown issues:\r\n- Aborting a pickup might cause the resources to sit in depot unavailable for drones/shuttles. To workaround this, destroy and rebuild the depot.\r\n- Shuttle transport algorithm has issues: rovers might enter endless loop picking up from A, drop at B, pick at B, drop back at A...\r\n\r\nSource code in github: https://github.com/machaqueso/surviving-mars",
	'image', "AutoCargo_preview.png",
	'id', "uo54uro",
	'steam_id', "1368419943",
	'author', "MachaQueso",
	'version', 18,
	'lua_revision', 229422,
	'code', {
		"Code/AutoCargo.lua",
	},
	'saved', 1525571697,
	'TagGameplay', true,
})