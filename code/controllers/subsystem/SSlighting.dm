SUBSYSTEM_DEF(lighting)
	name = "Lighting"
	wait = 2
	init_order = INIT_ORDER_LIGHTING
	flags = SS_TICKER
	offline_implications = "Lighting will no longer update. Shuttle call recommended."
	cpu_display = SS_CPUDISPLAY_HIGH
	var/static/list/sources_queue = list() // List of lighting sources queued for update.
	var/static/list/objects_queue = list() // List of lighting objects queued for update.

/datum/controller/subsystem/lighting/get_stat_details()
	return "L:[length(sources_queue)]|O:[length(objects_queue)]"

/datum/controller/subsystem/lighting/get_metrics()
	. = ..()
	var/list/cust = list()
	cust["sources_queue"] = length(sources_queue)
	cust["objects_queue"] = length(objects_queue)
	.["custom"] = cust

/datum/controller/subsystem/lighting/Initialize()
	if(!initialized)
		engine_setup()
		if(GLOB.configuration.general.starlight)
			for(var/I in GLOB.all_areas)
				var/area/A = I
				if(A.dynamic_lighting == DYNAMIC_LIGHTING_IFSTARLIGHT)
					A.luminosity = 0

		create_all_lighting_objects()
		engine_hand_over_turfs()

	fire(FALSE, TRUE)

/datum/controller/subsystem/lighting/fire(resumed, init_tick_checks)
	if(world.maxx != engine_maxx || world.maxy != engine_maxy)
		engine_world_resized()
	MC_SPLIT_TICK_INIT(2)
	if(!init_tick_checks)
		MC_SPLIT_TICK
	var/list/queue = sources_queue
	var/i = 0
	for(i in 1 to length(queue))
		var/datum/light_source/L = queue[i]

		L.update_corners()

		L.needs_update = LIGHTING_NO_UPDATE

		if(init_tick_checks)
			CHECK_TICK
		else if(MC_TICK_CHECK)
			break
	if(i)
		queue.Cut(1, i + 1)
		i = 0

	if(!init_tick_checks)
		MC_SPLIT_TICK

	// The lighting engine's corner stage, then drawing
	engine_draw(init_tick_checks)

/datum/controller/subsystem/lighting/Recover()
	initialized = SSlighting.initialized
	..()
