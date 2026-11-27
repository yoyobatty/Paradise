SUBSYSTEM_DEF(parallax)
	name = "Parallax"
	wait = 2
	flags = SS_POST_FIRE_TIMING | SS_BACKGROUND | SS_NO_INIT
	priority = FIRE_PRIORITY_PARALLAX
	runlevels = RUNLEVEL_LOBBY | RUNLEVELS_DEFAULT
	offline_implications = "Space parallax will no longer move around. No immediate action is needed."
	cpu_display = SS_CPUDISPLAY_HIGH
	var/list/currentrun
	var/planet_x_offset = 128
	var/planet_y_offset = 128

//These are cached per client so needs to be done asap so people joining at roundstart do not miss these.
/datum/controller/subsystem/parallax/PreInit()
	. = ..()
	planet_y_offset = rand(100, 160)
	planet_x_offset = rand(100, 160)
	var/list/themes = list()
	for(var/datum/sky_theme/theme_type as anything in subtypesof(/datum/sky_theme))
		themes[theme_type] = initial(theme_type.weight)
	var/picked = pickweight(themes)
	set_theme(new picked)


/datum/controller/subsystem/parallax/fire(resumed = 0)
	if(!resumed)
		src.currentrun = GLOB.clients.Copy()

	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun

	while(length(currentrun))
		var/client/C = currentrun[length(currentrun)]
		currentrun.len--
		if(!C || !C.eye)
			if(MC_TICK_CHECK)
				return
			continue
		var/atom/movable/A = C.eye
		if(!istype(A))
			continue
		for(A; isatom(A.loc) && !isturf(A.loc); A = A.loc);

		if(A != C.movingmob)
			if(C.movingmob != null && C.movingmob.client_mobs_in_contents)
				C.movingmob.client_mobs_in_contents -= C.mob
				UNSETEMPTY(C.movingmob.client_mobs_in_contents)
			LAZYINITLIST(A.client_mobs_in_contents)
			A.client_mobs_in_contents += C.mob
			C.movingmob = A
		if(MC_TICK_CHECK)
			return
	currentrun = null
