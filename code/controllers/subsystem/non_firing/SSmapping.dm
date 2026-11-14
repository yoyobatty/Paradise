SUBSYSTEM_DEF(mapping)
	name = "Mapping"
	init_order = INIT_ORDER_MAPPING // 9

	/// What map datum are we using
	var/datum/map/map_datum
	/// What map will be used next round
	var/datum/map/next_map
	/// What map was used last round?
	var/datum/map/last_map
	/// The trader shuttle to load at Centcom in late_mapping.
	var/datum/map_template/shuttle/trader_shuttle_id = /datum/map_template/shuttle/trader/synthetic
	/// The Gamma Armory shuttle to load at Centcom in late_mapping.
	var/gamma_armory_shuttle_id = "gamma_armory_base"
	/// The emergency shuttle to load at Centcom in late_mapping
	var/emergency_shuttle_id = "emergency_cyb"
	/// List of all areas that can be accessed via IC means
	var/list/teleportlocs
	/// List of all areas that can be accessed via IC and OOC means
	var/list/ghostteleportlocs
	///List of areas that exist on the station this shift
	var/list/existing_station_areas
	/// TRUE while lavaland and the ruins are still being built after startup. The round won't start until it's done.
	var/building_zlevels = FALSE
	/// Types of areas that exist on the station this shift
	var/list/existing_station_areas_types

	/// The type of the Lavaland theme for the next round, if selected.
	var/next_lavaland_theme
	/// The type of the current Lavaland theme.
	var/current_lavaland_theme
	/// The [/datum/lavaland_theme] instantiated for the current round.
	var/datum/lavaland_theme/lavaland_theme

	///What primary cave theme we have picked for cave generation today.
	var/datum/caves_theme/caves_theme
	// Tells if all maintenance airlocks have emergency access enabled
	var/maint_all_access = FALSE
	// Tells if all station airlocks have emergency access enabled
	var/station_all_access = FALSE

	/// A mapping of environment names to MILLA environment IDs.
	var/list/environments

	/// Ruin placement manager for space levels.
	var/datum/ruin_placer/space/space_ruins_placer
	/// Ruin placement manager for lavaland levels.
	var/datum/ruin_placer/lavaland/lavaland_ruins_placer

	var/num_of_res_levels = 0
	var/clearing_reserved_turfs = FALSE
	var/list/datum/turf_reservations //list of turf reservations

	var/list/turf/unused_turfs = list() //Not actually unused turfs they're unused but reserved for use for whatever requests them. "[zlevel_of_turf]" = list(turfs)
	var/list/used_turfs = list() //list of turf = datum/turf_reservation
	/// List of lists of turfs to reserve
	var/list/lists_to_reserve = list()

// This has to be here because world/New() uses [station_name()], which looks this datum up
/datum/controller/subsystem/mapping/PreInit()
	. = ..()
	if(map_datum) // Dont do this again if we are recovering
		return
	if(fexists("data/next_map.txt"))
		var/list/lines = file2list("data/next_map.txt")
		// Check its valid
		try
			map_datum = text2path(lines[1])
			map_datum = new map_datum
		catch
			map_datum = new /datum/map/boxstation // Assume cyberiad if non-existent
		fdel("data/next_map.txt") // Remove to avoid the same map existing forever
	else
		map_datum = new /datum/map/boxstation // Assume cyberiad if non-existent
	if(fexists("data/last_map.txt"))
		var/list/lines = file2list("data/last_map.txt")
		// Check its valid
		try
			last_map = text2path(lines[1])
			last_map = new last_map
		catch
			last_map = new /datum/map/cerestation // Assume cerestation if non-existent
		fdel("data/last_map.txt") // Remove to avoid the same map existing forever
	else
		last_map = new /datum/map/cerestation // Assume cerestation if non-existent
	if(fexists("data/next_lavaland_theme.txt"))
		var/list/lines = file2list("data/next_lavaland_theme.txt")
		try
			current_lavaland_theme = text2path(lines[1])
		catch
			log_startup_progress("invalid data/next_lavaland_theme.txt, choosing randomly on init")
		fdel("data/next_lavaland_theme.txt")

/datum/controller/subsystem/mapping/Shutdown()
	if(next_map) // Save map for next round
		var/F = file("data/next_map.txt")
		F << next_map.type
	if(map_datum) // Save which map was this round as the last map
		var/F = file("data/last_map.txt")
		F << map_datum.type
	if(next_lavaland_theme)
		var/F = file("data/next_lavaland_theme.txt")
		F << "[next_lavaland_theme]"

/datum/controller/subsystem/mapping/Initialize()
	environments = list()
	environments[ENVIRONMENT_LAVALAND] = create_environment(oxygen = LAVALAND_OXYGEN, nitrogen = LAVALAND_NITROGEN, temperature = LAVALAND_TEMPERATURE)
	environments[ENVIRONMENT_TEMPERATE] = create_environment(oxygen = MOLES_O2STANDARD, nitrogen = MOLES_N2STANDARD, temperature = T20C)
	environments[ENVIRONMENT_COLD] = create_environment(oxygen = MOLES_O2STANDARD, nitrogen = MOLES_N2STANDARD, temperature = 180)

	if(!current_lavaland_theme)
		current_lavaland_theme = pick(subtypesof(/datum/lavaland_theme))

	ASSERT(current_lavaland_theme)
	lavaland_theme = new current_lavaland_theme
	log_startup_progress("We're in the mood for [lavaland_theme.name] today...") //We load this first. In the event some nerd ever makes a surface map, and we don't have it in lavaland in the event lavaland is disabled.
	SSblackbox.record_feedback("text", "procgen_settings", 1, "[current_lavaland_theme]")

	var/caves_theme_type = pick(subtypesof(/datum/caves_theme))
	ASSERT(caves_theme_type)
	caves_theme = new caves_theme_type
	log_startup_progress("We feel like [caves_theme.name] today...")
	SSblackbox.record_feedback("text", "procgen_settings", 1, "[caves_theme_type]")

	// Load all Z level templates
	preloadTemplates()

	// Load the station
	loadStation()

	generate_zlevels()

	var/empty_z_traits = list(REACHABLE_BY_CREW, REACHABLE_SPACE_ONLY)
#ifdef GAME_TESTS
	preloadTemplates(path = "_maps/map_files/tests/")
	empty_z_traits |= GAME_TEST_LEVEL
#endif

	// Makes a blank space level for the sake of randomness
	var/empty_z = GLOB.space_manager.add_new_zlevel("Empty Area", linkage = CROSSLINKED, traits = empty_z_traits)
#ifndef GAME_TESTS
	// Nothing goes here, so its space can wait for the lobby too
	var/datum/space_level/empty_level = GLOB.space_manager.get_zlev(empty_z)
	empty_level.filled_after_startup = TRUE
#endif
	// Add a reserved z-level for shuttle transit
	add_reservation_zlevel(required_traits = list(TCOMM_RELAY_ALWAYS))

	// Now we make a list of areas for teleport locs
	// Located below is some of the worst code I've ever seen
	// Checking all areas to see if they have a turf in them? Nice one ssmapping!

	var/list/all_areas = list()
	for(var/area/areas in world)
		all_areas += areas

	teleportlocs = list()
	for(var/area/AR as anything in all_areas)
		if(AR.no_teleportlocs)
			continue
		if(teleportlocs[AR.name])
			continue
		var/list/pickable_turfs = list()
		for(var/turf/turfs in AR)
			pickable_turfs += turfs
			CHECK_TICK
		var/turf/picked = safepick(pickable_turfs)
		if(picked && is_station_level(picked.z))
			teleportlocs[AR.name] = AR
		CHECK_TICK

	teleportlocs = sortAssoc(teleportlocs)

	update_ghost_teleport_locs(all_areas)

	// Now we make a list of areas that exist on the station. Good for if you don't want to select areas that exist for one station but not others. Directly references
	existing_station_areas = list()
	existing_station_areas_types = list()
	for(var/area/AR as anything in all_areas)
		var/list/pickable_turfs = list()
		for(var/turf/turfs in AR)
			pickable_turfs += turfs
			CHECK_TICK
		var/turf/picked = safepick(pickable_turfs)
		if(picked && is_station_level(picked.z))
			existing_station_areas += AR
			existing_station_areas_types += AR.type
		CHECK_TICK

	// World name
	if(GLOB.configuration.general.server_name)
		world.name = "[GLOB.configuration.general.server_name]: [station_name()]"
	else
		world.name = station_name()

	if(HAS_TRAIT(SSstation, STATION_TRAIT_MESSY))
		generate_themed_messes(subtypesof(/obj/effect/spawner/themed_mess) - /obj/effect/spawner/themed_mess/party)
	if(HAS_TRAIT(SSstation, STATION_TRAIT_HANGOVER))
		generate_themed_messes(list(/obj/effect/spawner/themed_mess/party))

/// Every area with a turf in it, for ghosts to teleport to
/datum/controller/subsystem/mapping/proc/update_ghost_teleport_locs(list/all_areas)
	var/list/new_locs = list()
	for(var/area/AR as anything in all_areas)
		if(new_locs[AR.name])
			continue
		var/list/pickable_turfs = list()
		for(var/turf/turfs in AR)
			pickable_turfs += turfs
			CHECK_TICK
		if(length(pickable_turfs))
			new_locs[AR.name] = AR
		CHECK_TICK

	ghostteleportlocs = sortAssoc(new_locs)

/datum/controller/subsystem/mapping/proc/generate_zlevels()
	generate_space_zlevels()
	generate_lavaland_zlevels()

	// Setup the Z-level linkage
	GLOB.space_manager.do_transition_setup()

#ifdef GAME_TESTS
	// Tests run right after startup, so they need everything there
	fill_zlevels()
#else
	for(var/z in levels_by_trait(ORE_LEVEL) | levels_by_trait(SPAWN_RUINS))
		var/datum/space_level/level = GLOB.space_manager.get_zlev(z)
		level.filled_after_startup = TRUE
#endif

/datum/controller/subsystem/mapping/LateInitialize()
#ifndef GAME_TESTS
	// Lavaland and the ruins are most of the startup time, so they get built while the lobby is up
	fill_zlevels()
#endif

/// Loads lavaland, places ruins and generates lavaland's caves and rivers
/datum/controller/subsystem/mapping/proc/fill_zlevels()
	building_zlevels = TRUE
	var/watch = start_watch()
	// Lighting is done in one go at the end, in the right order, so each lighting object only draws once
	if(initialized)
		SSlighting.can_fire = FALSE
	var/phase = start_watch()
	if(GLOB.configuration.ruins.enable_ruins)
		preloadRuinTemplates()
	log_startup_progress("PHASE templates: [stop_watch(phase)]s")
	phase = start_watch()
	var/list/filled_levels = levels_by_trait(ORE_LEVEL) | levels_by_trait(SPAWN_RUINS)
	for(var/z in 1 to world.maxz)
		var/datum/space_level/level = GLOB.space_manager.get_zlev(z)
		if(level?.filled_after_startup)
			filled_levels |= z
	// Hold off initializing what gets placed until it's all in, the same as at startup
	for(var/z in filled_levels)
		GLOB.space_manager.add_dirt(z)
		if(initialized)
			var/datum/space_level/level = GLOB.space_manager.get_zlev(z)
			level.being_built = TRUE
			LISTASSERTLEN(GLOB.space_manager.levels_being_built, z, FALSE)
			GLOB.space_manager.levels_being_built[z] = TRUE

	load_lavaland_zlevels()
	log_startup_progress("PHASE lavaland base: [stop_watch(phase)]s")
	phase = start_watch()

	// Seed ruins
	if(GLOB.configuration.ruins.enable_ruins)
		place_lavaland_ruins()
		place_space_ruins()
	else
		log_startup_progress("Skipping z-level content...")
	log_startup_progress("PHASE ruins: [stop_watch(phase)]s")
	phase = start_watch()

	// Perform procedural generation for lavaland rivers and caves, which
	// happens after ruin placement.
	procgen_lavaland()
	log_startup_progress("PHASE procgen: [stop_watch(phase)]s")
	phase = start_watch()

	if(initialized)
		// Turf changes here skipped telling MILLA which sides are airtight, since the air setup below does every turf.
		// Firedoors read that when they initialize, so the turfs around them get it now, the same as at startup.
		for(var/z in filled_levels)
			var/datum/space_level/level = GLOB.space_manager.get_zlev(z)
			for(var/obj/machinery/door/firedoor/door in level.init_list)
				var/turf/door_turf = get_turf(door)
				if(!door_turf)
					continue
				door_turf.recalculate_atmos_connectivity()
				for(var/direction in GLOB.cardinal)
					var/turf/next_to_door = get_step(door_turf, direction)
					next_to_door?.recalculate_atmos_connectivity()

	for(var/z in filled_levels)
		GLOB.space_manager.remove_dirt(z)
		if(initialized)
			// Everything's in and initialized. Changes from here on (like timers that went off) are normal ones, and the passes below catch up the rest.
			var/datum/space_level/level = GLOB.space_manager.get_zlev(z)
			level.being_built = FALSE
			GLOB.space_manager.levels_being_built[z] = FALSE
	log_startup_progress("PHASE init atoms: [stop_watch(phase)]s")
	phase = start_watch()

	if(initialized)
		// SSatoms left the empty space nobody built on for us
		var/list/mapload_arg = list(TRUE)
		for(var/z in filled_levels)
			for(var/turf/T as anything in block(1, 1, z, world.maxx, world.maxy, z))
				if(!T.initialized)
					SSatoms.InitAtom(T, mapload_arg)
			CHECK_TICK
		// Lights first, then the lighting objects, like create_all_lighting_objects() at startup. Lighting is paused, so each object is drawn
		// once after all the lights are in, and the ones no light reaches draw dark straight away.
		SSlighting.process_queues_now()
		for(var/z in filled_levels)
			for(var/turf/T as anything in block(1, 1, z, world.maxx, world.maxy, z))
				var/area/A = T.loc
				if(!T.lighting_object && IS_DYNAMIC_LIGHTING(T) && IS_DYNAMIC_LIGHTING(A))
					new /datum/lighting_object(T)
				CHECK_TICK
		SSlighting.process_queues_now()
		SSlighting.can_fire = TRUE
		log_startup_progress("PHASE lighting: [stop_watch(phase)]s")
		phase = start_watch()

	if(initialized)
		// Startup already set up air, lighting and smoothing for the rest of the world, so catch these levels up
		for(var/z in filled_levels)
			var/datum/milla_safe/setup_level_air/milla = new()
			milla.invoke_async(z)
			var/datum/space_level/level = GLOB.space_manager.get_zlev(z)
			level.filled_after_startup = FALSE
			CHECK_TICK
		log_startup_progress("PHASE air: [stop_watch(phase)]s")
		phase = start_watch()
		for(var/z in filled_levels)
			for(var/turf/T as anything in block(1, 1, z, world.maxx, world.maxy, z))
				if(T.smoothing_flags & (SMOOTH_CORNERS|SMOOTH_BITMASK))
					T.smooth_icon()
				for(var/atom/A as anything in T)
					if(A.smoothing_flags & (SMOOTH_CORNERS|SMOOTH_BITMASK))
						A.smooth_icon()
				CHECK_TICK
		log_startup_progress("PHASE smoothing: [stop_watch(phase)]s")
		phase = start_watch()
		GLOB.spawn_pool_manager.process_pools()
		log_startup_progress("PHASE pools: [stop_watch(phase)]s")
		phase = start_watch()
		// Lighting runs in the lobby too. Wait for it to light these levels so the round doesn't start with the backlog.
		UNTIL(!length(SSlighting.sources_queue) && !length(SSlighting.corners_queue) && !length(SSlighting.objects_queue))
		log_startup_progress("PHASE lighting wait: [stop_watch(phase)]s")
		phase = start_watch()
		var/list/all_areas = list()
		for(var/area/areas in world)
			all_areas += areas
		update_ghost_teleport_locs(all_areas)

	building_zlevels = FALSE
	log_startup_progress("Built lavaland and ruins in [stop_watch(watch)]s.")

/datum/controller/subsystem/mapping/proc/seed_space_salvage(space_z_levels)
	log_startup_progress("Seeding space salvage...")
	var/space_salvage_timer = start_watch()
	var/seeded_salvage_surfaces = list()
	var/seeded_salvage_closets = list()

	var/list/small_salvage_items = list(
		/obj/item/salvage/ruin/brick,
		/obj/item/salvage/ruin/nanotrasen,
		/obj/item/salvage/ruin/carp,
		/obj/item/salvage/ruin/tablet,
		/obj/item/salvage/ruin/pirate,
		/obj/item/salvage/ruin/soviet
	)

	for(var/z_level in space_z_levels)
		var/list/turf/z_level_turfs = block(1, 1, z_level, world.maxx, world.maxy, z_level)
		for(var/z_level_turf in z_level_turfs)
			var/turf/T = z_level_turf
			var/area/A = get_area(T)
			if(istype(A, /area/ruin/space))
							// cardboard boxes are blacklisted otherwise deepstorage.dmm ends up hogging all the loot
				var/list/closet_blacklist = list(/obj/structure/closet/cardboard, /obj/structure/closet/fireaxecabinet, /obj/structure/closet/walllocker/emerglocker, /obj/structure/closet/crate/can, /obj/structure/closet/body_bag, /obj/structure/closet/coffin)
				for(var/obj/structure/closet/closet in T)
					if(is_type_in_list(closet, closet_blacklist))
						continue

					seeded_salvage_closets |= closet
				for(var/obj/structure/table/table in T)
					if(locate(/obj/machinery) in T)
						continue // Machinery on tables tend to take up all the visible space
					if(table.flipped)
						continue // Looks very silly
					seeded_salvage_surfaces |= table

	var/max_salvage_attempts = rand(10, 15)
	while(max_salvage_attempts > 0 && length(seeded_salvage_closets) > 0)
		var/obj/structure/closet/C = pick_n_take(seeded_salvage_closets)
		var/salvage_item_type = pick(small_salvage_items)
		var/obj/salvage_item = new salvage_item_type(C)
		salvage_item.scatter_atom()
		max_salvage_attempts -= 1

	max_salvage_attempts = rand(10, 15)
	while(max_salvage_attempts > 0 && length(seeded_salvage_surfaces) > 0)
		var/obj/T = pick_n_take(seeded_salvage_surfaces)
		var/salvage_item_type = pick(small_salvage_items)
		var/obj/salvage_item = new salvage_item_type(T.loc)
		salvage_item.scatter_atom()
		max_salvage_attempts -= 1

	log_startup_progress("Successfully seeded space salvage in [stop_watch(space_salvage_timer)]s.")

/datum/controller/subsystem/mapping/proc/generate_space_zlevels()
	var/zlevel_count = rand(GLOB.configuration.ruins.minimum_space_zlevels, GLOB.configuration.ruins.maximum_space_zlevels)
	if(!GLOB.configuration.ruins.enable_space || zlevel_count == 0)
		log_startup_progress("Skipping space levels...")
		return

	var/watch = start_watch()
	log_startup_progress("Adding space levels...")
	for(var/i in 1 to zlevel_count)
		GLOB.space_manager.add_new_zlevel(
			"Ruin Area #[i]",
			linkage = CROSSLINKED,
			traits = list(REACHABLE_BY_CREW, SPAWN_RUINS, REACHABLE_SPACE_ONLY),
			transition_tag = TRANSITION_TAG_SPACE
		)
		CHECK_TICK

	log_startup_progress("Added [zlevel_count] space levels in [stop_watch(watch)]s.")

/datum/controller/subsystem/mapping/proc/generate_lavaland_zlevels()
	var/zlevel_count = rand(GLOB.configuration.ruins.minimum_lavaland_zlevels, GLOB.configuration.ruins.maximum_lavaland_zlevels)
	if(!GLOB.configuration.ruins.enable_lavaland || zlevel_count == 0)
		log_startup_progress("Skipping lavaland levels...")
		return

	for(var/i in 1 to zlevel_count)
		GLOB.space_manager.add_new_zlevel(
			"LAVALAND[i]",
			linkage = CROSSLINKED,
			traits = list(ORE_LEVEL, REACHABLE_BY_CREW, STATION_CONTACT, HAS_WEATHER, AI_OK),
			transition_tag = TRANSITION_TAG_LAVALAND,
			level_type = /datum/space_level/lavaland
		)

/// Loads lavaland's base layer onto its z-levels
/datum/controller/subsystem/mapping/proc/load_lavaland_zlevels()
	var/list/lavaland_levels = levels_by_trait(ORE_LEVEL)
	if(!length(lavaland_levels))
		return
	log_startup_progress("Loading lavaland...")
	var/watch = start_watch()
	for(var/lavaland_zlevel in lavaland_levels)
		GLOB.maploader.load_map(file("_maps/map_files/generic/lavaland_baselayer.dmm"), z_offset = lavaland_zlevel)
		CHECK_TICK
	log_startup_progress("Added [length(lavaland_levels)] lavaland levels in [stop_watch(watch)]s")

/datum/controller/subsystem/mapping/proc/place_lavaland_ruins()
	log_startup_progress("Placing lavaland ruins...")
	var/watch = start_watch()
	lavaland_ruins_placer = new()
	lavaland_ruins_placer.place_ruins(levels_by_trait(ORE_LEVEL))
	log_startup_progress("Placed lavaland ruins in [stop_watch(watch)]s.")

/datum/controller/subsystem/mapping/proc/place_space_ruins()
	log_startup_progress("Placing space ruins...")
	var/watch = start_watch()
	space_ruins_placer = new()
	space_ruins_placer.place_ruins(levels_by_trait(SPAWN_RUINS))
	log_startup_progress("Placed space ruins in [stop_watch(watch)]s.")
	seed_space_salvage(levels_by_trait(SPAWN_RUINS))

// Loads in the station
/datum/controller/subsystem/mapping/proc/loadStation()
	if(GLOB.configuration.system.override_map)
		log_startup_progress("Station map overridden by configuration to [GLOB.configuration.system.override_map].")
		var/map_datum_path = text2path(GLOB.configuration.system.override_map)
		if(map_datum_path)
			map_datum = new map_datum_path
		else
			to_chat(world, SPAN_NARSIE("ERROR: The map datum specified to load is invalid. Falling back to... cyberiad probably?"))

	ASSERT(map_datum.map_path)
	if(!fexists(map_datum.map_path))
		// Make a VERY OBVIOUS error
		to_chat(world, SPAN_NARSIE("ERROR: The path specified for the map to load is invalid. No station has been loaded!"))
		return

	var/watch = start_watch()
	log_startup_progress("Loading [map_datum.fluff_name]...")
	// This should always be Z2, but you never know
	var/map_z_level = GLOB.space_manager.add_new_zlevel(
		MAIN_STATION,
		linkage = CROSSLINKED,
		traits = list(STATION_LEVEL, STATION_CONTACT, REACHABLE_BY_CREW, REACHABLE_SPACE_ONLY, AI_OK),
		transition_tag = TRANSITION_TAG_SPACE
	)
	GLOB.maploader.load_map(wrap_file(map_datum.map_path), z_offset = map_z_level)
	log_startup_progress("Loaded [map_datum.fluff_name] in [stop_watch(watch)]s")

	// Save station name in the DB
	if(!SSdbcore.IsConnected())
		return
	var/datum/db_query/query_set_map = SSdbcore.NewQuery(
		"UPDATE round SET start_datetime=NOW(), map_name=:mapname, station_name=:stationname WHERE id=:round_id",
		list("mapname" = map_datum.technical_name, "stationname" = map_datum.fluff_name, "round_id" = GLOB.round_id)
	)
	query_set_map.Execute(async = FALSE) // This happens during a time of intense server lag, so should be non-async
	qdel(query_set_map)

/datum/controller/subsystem/mapping/proc/procgen_lavaland()
	var/theme_watch = start_watch()
	log_startup_progress("Loading lavaland themes...")
	if(lavaland_theme)
		lavaland_theme.setup()
	if(caves_theme)
		caves_theme.setup()
	if(lavaland_theme)
		lavaland_theme.replace_mapping_lava()
	log_startup_progress("Loaded lavaland themes in [stop_watch(theme_watch)]s")

/datum/controller/subsystem/mapping/proc/make_maint_all_access()
	for(var/area/station/maintenance/A in existing_station_areas)
		for(var/obj/machinery/door/airlock/D in A)
			D.emergency = TRUE
			D.update_icon()
	GLOB.minor_announcement.Announce("Access restrictions on maintenance and external airlocks have been removed.")
	maint_all_access = TRUE
	SSblackbox.record_feedback("nested tally", "keycard_auths", 1, list("emergency maintenance access", "enabled"))

/datum/controller/subsystem/mapping/proc/revoke_maint_all_access()
	for(var/area/station/maintenance/A in existing_station_areas)
		for(var/obj/machinery/door/airlock/D in A)
			D.emergency = FALSE
			D.update_icon()
	GLOB.minor_announcement.Announce("Access restrictions on maintenance and external airlocks have been re-added.")
	maint_all_access = FALSE
	SSblackbox.record_feedback("nested tally", "keycard_auths", 1, list("emergency maintenance access", "disabled"))

/datum/controller/subsystem/mapping/proc/make_station_all_access()
	for(var/obj/machinery/door/airlock/D in GLOB.airlocks)
		if(is_station_level(D.z))
			D.emergency = TRUE
			D.update_icon()
	GLOB.minor_announcement.Announce("Access restrictions on all station airlocks have been removed due to an ongoing crisis. Trespassing laws still apply unless ordered otherwise by Command staff.")
	station_all_access = TRUE
	SSblackbox.record_feedback("nested tally", "keycard_auths", 1, list("emergency station access", "enabled"))

/datum/controller/subsystem/mapping/proc/revoke_station_all_access()
	for(var/obj/machinery/door/airlock/D in GLOB.airlocks)
		if(is_station_level(D.z))
			D.emergency = FALSE
			D.update_icon()
	GLOB.minor_announcement.Announce("Access restrictions on all station airlocks have been re-added. Seek station AI or a colleague's assistance if you are stuck.")
	station_all_access = FALSE
	SSblackbox.record_feedback("nested tally", "keycard_auths", 1, list("emergency station access", "disabled"))

/datum/controller/subsystem/mapping/Recover()
	num_of_res_levels = SSmapping.num_of_res_levels
	clearing_reserved_turfs = SSmapping.clearing_reserved_turfs
	turf_reservations = SSmapping.turf_reservations
	unused_turfs = SSmapping.unused_turfs
	used_turfs = SSmapping.used_turfs
	lists_to_reserve = SSmapping.lists_to_reserve

/datum/controller/subsystem/mapping/proc/get_reservation_from_turf(turf/T)
	RETURN_TYPE(/datum/turf_reservation)
	return used_turfs[T]

/// Requests a /datum/turf_reservation based on the given width, height.
/datum/controller/subsystem/mapping/proc/request_turf_block_reservation(width, height, reservation_type = /datum/turf_reservation, turf_type_override)
	UNTIL(!clearing_reserved_turfs)
	log_debug("Reserving [width]x[height] turf reservation")
	var/datum/turf_reservation/reserve = new reservation_type
	if(!isnull(turf_type_override))
		reserve.turf_type = turf_type_override
	var/list/required_traits = reserve.required_traits | Z_FLAG_RESERVED
	for(var/z in GLOB.space_manager.z_list)
		var/datum/space_level/level = GLOB.space_manager.z_list[z]
		if(!level.has_all_traits(required_traits))
			continue
		if(reserve.reserve(width, height, z))
			return reserve
	//If we didn't return at this point, theres a good chance we ran out of room on the exisiting reserved z levels, so lets try a new one
	var/z_level_num = add_reservation_zlevel(required_traits)
	if(reserve.reserve(width, height, z_level_num))
		return reserve
	qdel(reserve)

/datum/controller/subsystem/mapping/proc/add_reservation_zlevel(list/required_traits = list())
	required_traits |= list(Z_FLAG_RESERVED, BLOCK_TELEPORT, IMPEDES_MAGIC)
	num_of_res_levels++
	// . here is the z of the just added z-level
	. = GLOB.space_manager.add_new_zlevel("Transit/Reserved #[num_of_res_levels]", traits = required_traits)
	initialize_reserved_level(.)
	if(!initialized)
		return
	if(length(SSidlenpcpool.idle_mobs_by_zlevel) == . || !islist(SSidlenpcpool.idle_mobs_by_zlevel)) // arbitrary chosen from these lists that require the length of the z-levels
		return
	LISTASSERTLEN(SSidlenpcpool.idle_mobs_by_zlevel, ., list())
	LISTASSERTLEN(SSmobs.clients_by_zlevel, ., list())
	LISTASSERTLEN(SSmobs.dead_players_by_zlevel, ., list())

///Sets up a z level as reserved
///This is not for wiping reserved levels, use wipe_reservations() for that.
///If this is called after SSatom init, it will call Initialize on all turfs on the passed z, as its name promises
/datum/controller/subsystem/mapping/proc/initialize_reserved_level(z)
	UNTIL(!clearing_reserved_turfs) //regardless, lets add a check just in case.
	log_debug("Initializing new reserved Z-level")
	clearing_reserved_turfs = TRUE //This operation will likely clear any existing reservations, so lets make sure nothing tries to make one while we're doing it.
	if(!check_level_trait(z, Z_FLAG_RESERVED))
		clearing_reserved_turfs = FALSE
		CRASH("Invalid z level prepared for reservations.")
	var/block = block(SHUTTLE_TRANSIT_BORDER, SHUTTLE_TRANSIT_BORDER, z, world.maxx - SHUTTLE_TRANSIT_BORDER, world.maxy - SHUTTLE_TRANSIT_BORDER)
	for(var/turf/T as anything in block)
		// No need to empty() these, because they just got created and are already /turf/space.
		T.turf_flags |= UNUSED_RESERVATION_TURF
		CHECK_TICK

	// Gotta create these suckers if we've not done so already
	if(SSatoms.initialized)
		SSatoms.InitializeAtoms(block(1, 1, world.maxx, world.maxy, z), FALSE)

	unused_turfs["[z]"] = block
	clearing_reserved_turfs = FALSE

// TODO: Firing in a non-fire folder... Someone needs to move this file someday.
/datum/controller/subsystem/mapping/fire(resumed)
	// Cache for sonic speed
	var/list/list/turf/unused_turfs = src.unused_turfs
	var/list/world_contents = GLOB.all_unique_areas[world.area].contents
	// var/list/world_turf_contents_by_z = GLOB.all_unique_areas[world.area].turfs_by_zlevel
	var/list/lists_to_reserve = src.lists_to_reserve
	var/index = 0
	while(index < length(lists_to_reserve))
		var/list/packet = lists_to_reserve[index + 1]
		var/packetlen = length(packet)
		while(packetlen)
			if(MC_TICK_CHECK)
				if(index)
					lists_to_reserve.Cut(1, index)
				return
			var/turf/reserving_turf = packet[packetlen]
			reserving_turf.empty(/turf/space)
			LAZYINITLIST(unused_turfs["[reserving_turf.z]"])
			if(!(reserving_turf in unused_turfs["[reserving_turf.z]"]))
				unused_turfs["[reserving_turf.z]"].Insert(1, reserving_turf)
			reserving_turf.turf_flags = UNUSED_RESERVATION_TURF

			world_contents += reserving_turf
			packet.len--
			packetlen = length(packet)

		index++
	lists_to_reserve.Cut(1, index)

/**
 * Lazy loads a template on a lazy-loaded z-level.
 */
/datum/controller/subsystem/mapping/proc/lazy_load_template(datum/map_template/template)
	RETURN_TYPE(/datum/turf_reservation)

	UNTIL(initialized)
	var/static/lazy_loading = FALSE
	UNTIL(!lazy_loading)

	lazy_loading = TRUE
	. = _lazy_load_template(template)
	lazy_loading = FALSE

/datum/controller/subsystem/mapping/proc/_lazy_load_template(datum/map_template/template)
	PRIVATE_PROC(TRUE)
	var/datum/turf_reservation/reservation = request_turf_block_reservation(template.width, template.height)
	if(!istype(reservation))
		return

	template.load(reservation.bottom_left_turf)
	return reservation

/// Schedules a group of turfs to be handed back to the reservation system's control
/datum/controller/subsystem/mapping/proc/unreserve_turfs(list/turfs)
	lists_to_reserve += list(turfs)

/// Sets up air for a whole z-level, the same as SSair does for everything at startup
/datum/milla_safe/setup_level_air

/datum/milla_safe/setup_level_air/on_run(z)
	// Empty space is what MILLA starts every tile as, so only load the stretches of each row that have something in them
	for(var/y in 1 to world.maxy)
		var/run_start = 0
		for(var/x in 1 to world.maxx + 1)
			var/turf/T = x <= world.maxx ? locate(x, y, z) : null
			var/empty_space = isnull(T) || (isspaceturf(T) && !length(T.contents) && T.atmos_mode == ATMOS_MODE_SPACE)
			if(!empty_space && !run_start)
				run_start = x
			else if(empty_space && run_start)
				SSair.setup_turfs(locate(run_start, y, z), locate(x - 1, y, z))
				run_start = 0
