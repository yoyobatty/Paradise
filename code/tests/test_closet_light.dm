/// A lit flashlight shut in a closet or a crate doesn't light the room, and lights it again once the closet is opened
/datum/game_test/room_test/closet_blocks_light
	/// The turfs we gave lighting to, so it can be taken away again
	var/list/turf/darkened = list()

/datum/game_test/room_test/closet_blocks_light/Destroy()
	for(var/turf/dark_turf as anything in darkened)
		dark_turf.lighting_clear_overlay()
	return ..()

/datum/game_test/room_test/closet_blocks_light/Run()
	// The test room is loaded without any lighting, so all of it counts as lit. Give it some, so it is dark.
	for(var/turf/room_turf in get_area_turfs(/area/game_test))
		if(!room_turf.lighting_object)
			room_turf.lighting_build_overlay()
			darkened += room_turf

	var/turf/closet_turf = locate(bottom_left.x + 1, bottom_left.y, bottom_left.z)
	var/turf/beside = locate(closet_turf.x + 1, closet_turf.y, closet_turf.z)
	TEST_ASSERT(beside.get_lumcount() < 0.01, "The test room wasn't dark to start with")

	for(var/closet_type in list(/obj/structure/closet, /obj/structure/closet/crate))
		var/obj/structure/closet/closet = allocate(closet_type, closet_turf)
		var/obj/item/flashlight/flashlight = allocate(/obj/item/flashlight, closet)
		flashlight.on = TRUE
		flashlight.update_brightness()
		flashlight.light.update_corners()
		TEST_ASSERT(beside.get_lumcount() < 0.01, "A lit flashlight shut in \a [closet] lit the turf beside it")

		closet.open()
		flashlight.light.update_corners()
		TEST_ASSERT(beside.get_lumcount() > 0.01, "A lit flashlight didn't light the turf beside it with \the [closet] open")

		closet.close()
		TEST_ASSERT_EQUAL(flashlight.loc, closet, "Shutting \the [closet] didn't take the flashlight back in")
		flashlight.light.update_corners()
		TEST_ASSERT(beside.get_lumcount() < 0.01, "A lit flashlight still lit the turf beside it after \the [closet] was shut again")

		qdel(flashlight)
		qdel(closet)
