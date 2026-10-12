/// A flashlight's light follows whoever carries it, lights only the turfs it can reach, and goes when the flashlight is put away or switched off
/datum/game_test/room_test/following_light
	/// The turfs we gave lighting to, so it can be taken away again
	var/list/turf/darkened = list()

/datum/game_test/room_test/following_light/Destroy()
	for(var/turf/dark_turf as anything in darkened)
		dark_turf.lighting_clear_overlay()
	return ..()

/datum/game_test/room_test/following_light/Run()
	// The test room is loaded without any lighting, so all of it counts as lit. Give it some, so it is dark.
	for(var/turf/room_turf in get_area_turfs(/area/game_test))
		if(!room_turf.lighting_object)
			room_turf.lighting_build_overlay()
			darkened += room_turf

	var/turf/start = locate(bottom_left.x + 1, bottom_left.y, bottom_left.z)
	var/turf/next_to_start = locate(start.x + 1, start.y, start.z)
	var/turf/door_turf = locate(start.x + 2, start.y, start.z)
	var/turf/past_door = locate(start.x + 3, start.y, start.z)
	var/turf/above_start = locate(start.x, start.y + 1, start.z)
	var/lights_before = length(GLOB.following_lights)

	var/datum/test_puppeteer/player = new(src, /mob/living/carbon/human, start)
	TEST_ASSERT_EQUAL(next_to_start.get_lumcount(), 0, "The test room wasn't dark to start with")
	var/obj/item/flashlight/flashlight = player.spawn_obj_in_hand(/obj/item/flashlight)
	flashlight.on = TRUE
	flashlight.update_brightness()
	var/datum/light_source/following/light = flashlight.light
	TEST_ASSERT(istype(light), "A lit flashlight didn't get a following light")
	TEST_ASSERT_EQUAL(light.glow.loc, start, "The glow wasn't put on the carrier's turf")

	light.update_corners()
	TEST_ASSERT(next_to_start.get_lumcount() > 0, "The turf next to the carrier wasn't lit")
	TEST_ASSERT(past_door.get_lumcount() > 0, "A turf three tiles from the carrier wasn't lit")
	TEST_ASSERT(!next_to_start.lighting_corner_NE?.lum_r, "A following light lit the corners of a turf")

	// A shut door blocks the light
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, door_turf)
	light.update_corners()
	TEST_ASSERT_EQUAL(past_door.get_lumcount(), 0, "The light went through a shut door")
	TEST_ASSERT(next_to_start.get_lumcount() > 0, "The turf before the door stopped being lit")
	qdel(door)
	light.update_corners()
	TEST_ASSERT(past_door.get_lumcount() > 0, "The light didn't come back when the door was gone")

	// The glow goes with the carrier as soon as it moves
	player.puppet.forceMove(above_start)
	TEST_ASSERT_EQUAL(light.glow.loc, above_start, "The glow didn't move with the carrier")

	// A locker hides it
	var/obj/structure/closet/locker = allocate(/obj/structure/closet, start)
	player.puppet.forceMove(locker)
	TEST_ASSERT_NULL(light.glow.loc, "The glow was still showing with the carrier in a locker")
	TEST_ASSERT_EQUAL(next_to_start.get_lumcount(), 0, "A turf was still lit with the carrier in a locker")
	player.puppet.forceMove(start)
	light.update_corners()
	TEST_ASSERT_EQUAL(light.glow.loc, start, "The glow didn't come back when the carrier left the locker")
	TEST_ASSERT(next_to_start.get_lumcount() > 0, "The light didn't come back when the carrier left the locker")

	// Dropped, the light stays with the flashlight
	player.puppet.drop_item_to_ground(flashlight)
	light = flashlight.light
	TEST_ASSERT(istype(light), "A dropped flashlight lost its following light")
	TEST_ASSERT_EQUAL(light.glow.loc, flashlight.loc, "The glow didn't stay with the dropped flashlight")

	// A range of 7 is too big for a following light, so it becomes an ordinary one
	flashlight.set_light(7)
	TEST_ASSERT_EQUAL(flashlight.light.type, /datum/light_source, "A range too big for a following light didn't become an ordinary light")
	flashlight.set_light(4)
	TEST_ASSERT(istype(flashlight.light, /datum/light_source/following), "The flashlight didn't go back to a following light")

	flashlight.on = FALSE
	flashlight.update_brightness()
	TEST_ASSERT_NULL(flashlight.light, "A flashlight that was switched off still had a light")
	TEST_ASSERT_EQUAL(length(GLOB.following_lights), lights_before, "Switching the flashlight off left a following light behind")
