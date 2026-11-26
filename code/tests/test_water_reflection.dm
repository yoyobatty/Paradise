/// Makes sure mobs beside water are mirrored in it, and stop being when they leave or the water goes
/datum/game_test/room_test/water_reflection/Run()
	var/datum/test_puppeteer/player = new(src)
	var/mob/living/carbon/human/puppet = player.puppet
	var/turf/bank = get_turf(puppet)
	var/turf/water = get_step(puppet, SOUTH)
	var/turf_before = water.type

	// Water appearing south of a mob
	water.ChangeTurf(/turf/simulated/floor/beach/water)
	var/datum/component/water_reflection/mirror = puppet.GetComponent(/datum/component/water_reflection)
	TEST_ASSERT_NOTNULL(mirror, "water made south of a mob didn't mirror it")
	TEST_ASSERT(mirror.reflection in puppet.vis_contents, "the reflection isn't drawn with the mob")
	TEST_ASSERT_EQUAL(mirror.reflection.render_source, puppet.render_target, "the reflection doesn't copy the mob's picture")

	// A mob walking onto the bank, and off it again
	var/mob/living/carbon/human/walker = allocate(/mob/living/carbon/human, get_step(bank, NORTH))
	TEST_ASSERT_NULL(walker.GetComponent(/datum/component/water_reflection), "a mob a tile back from the bank is mirrored")
	walker.forceMove(bank)
	var/datum/component/water_reflection/walker_mirror = walker.GetComponent(/datum/component/water_reflection)
	TEST_ASSERT_NOTNULL(walker_mirror, "a mob stepping onto the bank wasn't mirrored")
	walker.forceMove(get_step(bank, NORTH))
	TEST_ASSERT_NOTNULL(walker_mirror.leave_timer, "leaving the bank didn't start taking the reflection away")
	walker_mirror.leave()
	TEST_ASSERT_NULL(walker.GetComponent(/datum/component/water_reflection), "the reflection stayed after its mob left the bank")
	TEST_ASSERT_EQUAL(length(walker.vis_contents), 0, "the reflection is still drawn with a mob that left")

	// Stepping in makes a ripple
	walker.forceMove(water)
	TEST_ASSERT_NOTNULL(locate(/obj/effect/temp_visual/water_ripple) in water, "stepping into water didn't make a ripple")
	walker.forceMove(get_step(bank, NORTH))

	// Water turned back into floor
	water.ChangeTurf(turf_before)
	walker.forceMove(bank)
	TEST_ASSERT_NULL(walker.GetComponent(/datum/component/water_reflection), "floor that used to be water still mirrors mobs")
