/// All job icon sprites, as visible on a security HUD. Used by orbit menu.
/datum/asset/spritesheet/job_icons
	name = "job_icons"

/datum/asset/spritesheet/job_icons/create_spritesheets()
	var/list/states = GLOB.joblist + "prisoner" + "centcom" + "solgov" + "soviet" + "unknown"
	for(var/state in states)
		Insert(ckey(state), 'icons/mob/hud/job_assets.dmi', ckey(state), transforms = list(ICONFORGE_SCALE(16, 16)))
