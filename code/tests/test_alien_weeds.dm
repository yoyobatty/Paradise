/// Alien weeds stop processing once they've got nowhere left to grow, and start again when a weed next to them
/// dies or something that was blocking them goes away
/datum/game_test/room_test/alien_weeds_rest/Run()
	var/turf/node_turf = locate(bottom_left.x + 2, bottom_left.y + 1, bottom_left.z)
	var/turf/blocked_turf = locate(node_turf.x + 2, node_turf.y, node_turf.z)
	var/turf/regrow_turf = locate(node_turf.x - 1, node_turf.y, node_turf.z)
	var/obj/structure/inflatable/blocker = allocate(/obj/structure/inflatable, blocked_turf)
	var/obj/structure/alien/weeds/node/node = allocate(/obj/structure/alien/weeds/node, node_turf)

	pass_fires(40)
	TEST_ASSERT(locate(/obj/structure/alien/weeds) in regrow_turf, "The weeds didn't grow out from their node")
	TEST_ASSERT(!(locate(/obj/structure/alien/weeds) in blocked_turf), "The weeds grew into an airtight tile")
	TEST_ASSERT_EQUAL(awake_weeds(), 0, "Weeds kept processing with nowhere left to grow")

	qdel(blocker)
	TEST_ASSERT(awake_weeds(), "Taking away what blocked the weeds didn't wake any of them")
	pass_fires(20)
	TEST_ASSERT(locate(/obj/structure/alien/weeds) in blocked_turf, "The weeds didn't grow into the tile that opened up")
	TEST_ASSERT_EQUAL(awake_weeds(), 0, "Weeds kept processing after filling the tile that opened up")

	qdel(locate(/obj/structure/alien/weeds) in regrow_turf)
	TEST_ASSERT(awake_weeds(), "Killing a weed didn't wake the ones next to it")
	pass_fires(20)
	TEST_ASSERT(locate(/obj/structure/alien/weeds) in regrow_turf, "The killed weed didn't grow back")
	TEST_ASSERT_EQUAL(awake_weeds(), 0, "Weeds kept processing after growing back")

	qdel(node)
	pass_fires(600)
	TEST_ASSERT_EQUAL(length(room_weeds()), 0, "There were still weeds long after their node died")

/datum/game_test/room_test/alien_weeds_rest/proc/room_weeds()
	. = list()
	for(var/turf/T in get_area_turfs(/area/game_test))
		for(var/obj/structure/alien/weeds/weed in T)
			. += weed

/datum/game_test/room_test/alien_weeds_rest/proc/awake_weeds()
	. = 0
	for(var/obj/structure/alien/weeds/weed as anything in room_weeds())
		if(weed.isprocessing)
			.++

/// Does to the weeds what that many fires of SSobj would
/datum/game_test/room_test/alien_weeds_rest/proc/pass_fires(fires)
	for(var/i in 1 to fires)
		for(var/obj/structure/alien/weeds/weed as anything in room_weeds())
			if(weed.isprocessing && !QDELETED(weed))
				weed.process()
