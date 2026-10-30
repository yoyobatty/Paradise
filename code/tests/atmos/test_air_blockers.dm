/// Anything that seals a tile has to tell MILLA when it turns up and again when it goes.
/datum/game_test/room_test/air_blockers
	var/list/blocker_types = list(
		/obj/effect/forcefield/cosmic_field,
		/obj/effect/forcefield/wizard,
		/obj/effect/temp_visual/drakewall,
		/obj/machinery/fishtank/wall,
		/obj/machinery/power/compressor,
		/obj/machinery/shield,
	)

/// Which sides MILLA thinks are sealed, once anything waiting on it has run
/datum/game_test/room_test/air_blockers/proc/milla_airtight(turf/T)
	while(!SSair.milla_idle)
		sleep(world.tick_lag)
	var/list/tile = new/list(MILLA_TILE_SIZE)
	get_tile_atmos(T, tile)
	return tile[MILLA_INDEX_AIRTIGHT_DIRECTIONS]

/datum/game_test/room_test/air_blockers/Run()
	var/turf/T = available_turfs[1]
	var/all_sides = MILLA_NORTH | MILLA_EAST | MILLA_SOUTH | MILLA_WEST
	TEST_ASSERT_EQUAL(milla_airtight(T), 0, "the test tile started out sealed.")
	for(var/blocker_type in blocker_types)
		var/obj/blocker = new blocker_type(T)
		TEST_ASSERT_EQUAL(milla_airtight(T), all_sides, "[blocker_type] didn't seal the tile.")
		qdel(blocker)
		TEST_ASSERT_EQUAL(milla_airtight(T), 0, "[blocker_type] left the tile sealed when it was deleted.")
