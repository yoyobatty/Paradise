/// Makes sure every fishing spot only lists catches that exist, and every catch can really be landed
/datum/game_test/fishing_tables/Run()
	var/list/bait_kinds = list(FISHING_BAIT_MEAT, FISHING_BAIT_CHEESE, FISHING_BAIT_PLANT, FISHING_BAIT_LIVE, FISHING_BAIT_GLOW, FISHING_BAIT_SHINY)
	for(var/datum/fishing_spot/spot as anything in GLOB.fishing_spots)
		for(var/catch_type in spot.catches)
			TEST_ASSERT_NOTNULL(GLOB.fishing_catches[catch_type], "[spot.type] lists [catch_type], which can't be caught")
			TEST_ASSERT(spot.catches[catch_type] >= 1, "[spot.type] lists [catch_type] with no chance to bite")

	for(var/catch_type in GLOB.fishing_catches)
		var/datum/fishing_catch/entry = GLOB.fishing_catches[catch_type]
		TEST_ASSERT(ispath(entry.catch_type, /atom/movable), "[catch_type] has nothing to land")
		TEST_ASSERT(entry.max_length >= entry.min_length, "[catch_type] has a longest length under its shortest")
		if(entry.fish_type)
			TEST_ASSERT(entry.max_length > 0, "[catch_type] is a tank fish with no length")
			TEST_ASSERT_NOTNULL(initial(entry.fish_type.fish_item), "[entry.fish_type] has no item to come out of a tank as")
		for(var/bait_kind in entry.bait_likes)
			TEST_ASSERT(bait_kind in bait_kinds, "[catch_type] likes [bait_kind], which isn't a kind of bait")

/// Plays out a cast: the wait, the bite, the fight and the landing, and the ways it can go wrong
/datum/game_test/room_test/fishing_cast/Run()
	var/datum/test_puppeteer/player = new(src)
	var/turf/water = get_step(player.puppet, EAST)
	var/turf_before = water.type
	water.ChangeTurf(/turf/simulated/floor/beach/water)
	var/obj/item/fishing_rod/rod = player.spawn_obj_in_hand(/obj/item/fishing_rod)

	// Reeling in before anything bites
	player.click_on(water)
	TEST_ASSERT_NOTNULL(rod.session, "clicking water with a rod didn't cast it")
	TEST_ASSERT_LAST_CHATLOG(player, "You cast your line")
	player.click_on(water)
	TEST_ASSERT_NULL(rod.session, "clicking again with nothing on the hook didn't reel in")

	// Missing the bite goes back to waiting
	player.click_on(water)
	var/datum/fishing_session/session = rod.session
	session.bite()
	session.miss_bite()
	TEST_ASSERT_EQUAL(session.state, FISHING_WAITING, "a missed bite didn't go back to waiting")

	// Hooking a salmon and playing it properly: wind while it rests, let go while it runs
	session.bite()
	session.hooked = GLOB.fishing_catches[/datum/fishing_catch/salmon]
	session.length_cm = 70
	session.start_fight()
	for(var/i in 1 to 1000)
		if(QDELETED(session))
			break
		session.reeling = (session.fish_state == FISHING_FISH_RESTING || session.fish_state == FISHING_FISH_WORN_OUT)
		session.process(SSfastprocess.wait)
	TEST_ASSERT(QDELETED(session), "a well played salmon never came in")
	TEST_ASSERT_ANY_CHATLOG(player, "You reel in a 70 cm salmon")
	var/obj/item/fish/salmon/salmon = player.puppet.get_inactive_hand()
	TEST_ASSERT(istype(salmon), "the salmon didn't end up in the angler's free hand")
	var/datum/component/caught_fish/info = salmon.GetComponent(/datum/component/caught_fish)
	TEST_ASSERT_EQUAL(info?.length_cm, 70, "the salmon didn't keep its length")
	TEST_ASSERT_NOTNULL(GLOB.fishing_records["salmon"], "the salmon didn't make the record board")

	// It goes into a tank while it's still alive
	var/obj/machinery/fishtank/tank/tank = player.spawn_obj_nearby(/obj/machinery/fishtank/tank, WEST)
	tank.water_level = tank.water_capacity
	player.puppet.swap_hand()
	player.click_on(tank)
	TEST_ASSERT_EQUAL(tank.get_num_fish(), 1, "a live caught fish didn't go into the tank")
	player.puppet.swap_hand()

	// Winding against a shark the whole way snaps the line and loses the hook
	player.click_on(water)
	session = rod.session
	session.bite()
	session.hooked = GLOB.fishing_catches[/datum/fishing_catch/shark]
	session.length_cm = 300
	session.start_fight()
	for(var/i in 1 to 1000)
		if(QDELETED(session))
			break
		session.reeling = TRUE
		session.process(SSfastprocess.wait)
	TEST_ASSERT(QDELETED(session), "the fight with the shark never ended")
	TEST_ASSERT_NULL(rod.hook, "winding against a shark the whole way didn't cost the hook")

	// No hook, no cast
	player.click_on(water)
	TEST_ASSERT_NULL(rod.session, "a rod without a hook was cast")
	rod.hook = new /obj/item/fishing_hook(rod)

	// A plain line can't go in lava
	water.ChangeTurf(/turf/simulated/floor/lava)
	player.click_on(water)
	TEST_ASSERT_NULL(rod.session, "a plain line was cast into lava")
	TEST_ASSERT_LAST_CHATLOG(player, "would burn up")
	qdel(rod.line)
	rod.line = new /obj/item/fishing_line/sinew(rod)
	player.click_on(water)
	TEST_ASSERT_NOTNULL(rod.session, "a sinew line couldn't be cast into lava")

	// Dropping the rod ends the cast
	player.drop_held_item()
	TEST_ASSERT_NULL(rod.session, "the line stayed out after the rod was dropped")

	// No lava left behind for the next test to stand beside
	water.ChangeTurf(turf_before)
