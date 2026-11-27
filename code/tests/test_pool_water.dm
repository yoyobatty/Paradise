/// Makes sure pool water picks its edges and depth from the water round it, and picks them again when that changes
/datum/game_test/room_test/pool_water_edges/Run()
	var/datum/test_puppeteer/player = new(src)
	var/turf/origin = get_turf(player.puppet)
	// A pool 3 wide and 2 tall, east of the test player
	var/list/pool = block(locate(origin.x + 1, origin.y - 1, origin.z), locate(origin.x + 3, origin.y, origin.z))
	var/list/turfs_before = list()
	for(var/turf/T as anything in pool)
		turfs_before[T] = T.type
		T.ChangeTurf(/turf/simulated/floor/beach/water)
	for(var/turf/simulated/floor/beach/water/W in pool)
		W.smooth_icon()

	var/turf/simulated/floor/beach/water/top_left = locate(origin.x + 1, origin.y, origin.z)
	var/turf/simulated/floor/beach/water/top_middle = locate(origin.x + 2, origin.y, origin.z)
	TEST_ASSERT_EQUAL(top_left.water_look, "pool", "plain water isn't drawn in the pool look")
	// Water south (2), east (4) and south east (32)
	TEST_ASSERT_EQUAL(top_left.smoothing_junction, 38, "the top left corner didn't find the water south and east of it")
	TEST_ASSERT_EQUAL(top_left.icon_state, "[top_left.base_icon_state]-[top_left.smoothing_junction]", "the edge sprite doesn't match the junction")
	var/has_surface = FALSE
	for(var/mutable_appearance/MA as anything in top_left.overlays)
		if(MA.icon_state == "[top_left.base_icon_state]_water-[top_left.smoothing_junction]")
			has_surface = TRUE
	TEST_ASSERT(has_surface, "the surface doesn't follow the edge")
	TEST_ASSERT_EQUAL(top_left.plane, WATER_EDGE_PLANE, "pool water isn't drawn on the edge plane")
	// It reflects the world: a mirror map tells the reflection plane what to show, fading with height above the water
	var/list/states = list()
	for(var/mutable_appearance/MA as anything in top_left.overlays)
		states["[MA.icon_state] [MA.plane]"] = TRUE
	TEST_ASSERT(states["mirror_map [WATER_MIRROR_PLANE]"], "pool water has no mirror map, so it won't reflect anything")
	TEST_ASSERT(states["wave_flat [WATER_RIPPLE_PLANE]"], "pool water has no flat water for its waves to be drawn over")
	TEST_ASSERT(states["mirror_fade [WATER_UNMIRRORED_PLANE]"], "what pool water mirrors doesn't fade with its height above the water")
	TEST_ASSERT(states["rays_[top_left.x % 4][3 - top_left.y % 4] [WATER_RAYS_PLANE]"], "pool water has no shafts of light")
	for(var/mutable_appearance/MA as anything in top_left.underlays)
		TEST_ASSERT_EQUAL(MA.plane, POOL_FLOOR_PLANE, "part of the pool's bottom isn't on the pool floor plane")
	TEST_ASSERT(states["caustics_[top_left.x % 4][3 - top_left.y % 4] [POOL_FLOOR_PLANE]"], "pool water has no light on its floor")
	// The bottom row has land south, so the pool's near side goes over anyone standing in it. The top row doesn't
	var/turf/simulated/floor/beach/water/bottom_left = locate(origin.x + 1, origin.y - 1, origin.z)
	var/has_lip = FALSE
	for(var/mutable_appearance/MA as anything in bottom_left.overlays)
		if(MA.icon_state == "[bottom_left.base_icon_state]_lip-[bottom_left.smoothing_junction]" && MA.plane == GAME_PLANE)
			has_lip = TRUE
	TEST_ASSERT(has_lip, "the pool's near side isn't drawn over people standing in it")
	TEST_ASSERT(!states["[top_left.base_icon_state]_lip-[top_left.smoothing_junction] [GAME_PLANE]"], "water with more water south has a near side over people")
	// Its north corners touch land, its south ones are a tile from it
	TEST_ASSERT_EQUAL(top_middle.pool_depth_underlay?.icon_state, "depth-0011", "the water in the middle of the pool has the wrong depth")

	// The pool has one set of waves, in layers on every tile, and they follow what happens in it
	var/datum/pool_waves/waves = top_left.waves
	TEST_ASSERT_NOTNULL(waves, "pool water has no waves")
	TEST_ASSERT_EQUAL(length(waves.tiles), 6, "the pool's tiles don't all share its waves")
	TEST_ASSERT_EQUAL(top_middle.waves, waves, "two tiles of one pool have different waves")
	TEST_ASSERT_EQUAL(length(top_left.vis_contents), 2, "a calm pool's tile doesn't show two layers of waves")
	TEST_ASSERT_EQUAL(waves.energy, 0, "a pool nothing has touched isn't calm")
	top_left.stir_water(0.2)
	TEST_ASSERT_EQUAL(waves.energy, 0.2, "disturbing the water didn't stir the pool up")
	waves.process(1 MINUTES)
	TEST_ASSERT_EQUAL(waves.energy, 0, "a stirred up pool didn't settle")
	waves.set_machine(POOL_WAVES_STRONG)
	TEST_ASSERT_EQUAL(waves.swell_axis, "ew", "the swell doesn't run along a pool that's wider than it's tall")
	TEST_ASSERT_EQUAL(length(top_left.vis_contents), 4, "the wave machine didn't add the swell and the one coming back")
	waves.process(1 MINUTES)
	TEST_ASSERT(waves.energy > 0.5, "a strong wave machine doesn't keep the pool rough")
	waves.set_machine(POOL_WAVES_OFF)

	// Things lying in the pool look sunk and bend under the waves, and stop when they're taken out
	var/obj/item/wrench/wrench = allocate(/obj/item/wrench, top_middle)
	var/datum/component/pool_sunk/sunk = wrench.GetComponent(/datum/component/pool_sunk)
	TEST_ASSERT_NOTNULL(sunk, "an item made in the pool doesn't look sunk")
	TEST_ASSERT_NOTNULL(wrench.get_filter("pool_sunk"), "an item in the pool has no water drawn over it")
	TEST_ASSERT_EQUAL(sunk.refraction?.plane, WATER_REFRACT_PLANE, "the waves don't bend an item on the pool's bottom")
	TEST_ASSERT(sunk.refraction in wrench.vis_contents, "where the waves bend a sunk item isn't drawn with it")
	wrench.forceMove(origin)
	TEST_ASSERT_NULL(wrench.GetComponent(/datum/component/pool_sunk), "an item taken out of the pool still looks sunk")
	TEST_ASSERT_NULL(wrench.get_filter("pool_sunk"), "an item taken out of the pool still has the water drawn over it")
	TEST_ASSERT_EQUAL(length(wrench.vis_contents), 0, "an item taken out of the pool still has the water's parts drawn with it")
	TEST_ASSERT_EQUAL(wrench.pixel_z, 0, "an item taken out of the pool is still drawn as low as on its bottom")

	// A beach ball floats: a ring of water round it and only its underside under the water
	var/obj/item/beach_ball/ball = allocate(/obj/item/beach_ball, top_middle)
	var/datum/component/pool_sunk/afloat = ball.GetComponent(/datum/component/pool_sunk)
	TEST_ASSERT(afloat?.floating, "a beach ball in the pool doesn't float")
	TEST_ASSERT_NULL(ball.get_filter("pool_sunk"), "a floating beach ball has the water drawn over all of it")
	TEST_ASSERT_NOTNULL(ball.get_filter("pool_afloat"), "a floating beach ball has no water drawn over its underside")
	TEST_ASSERT_EQUAL(length(afloat.rings), 2, "a floating beach ball has no ring of water round it")
	TEST_ASSERT(afloat in GLOB.pool_things_afloat, "a floating beach ball isn't known to the waves that should lift it")
	TEST_ASSERT_NOTNULL(ball.render_target, "a floating beach ball has nothing for its reflection to copy")
	TEST_ASSERT_EQUAL(afloat.reflection?.render_source, ball.render_target, "a floating beach ball has no reflection of its own")
	TEST_ASSERT_NULL(sunk.reflection, "an item on the pool's bottom is reflected on top of the water")
	TEST_ASSERT(afloat.float_line["across"] >= 16, "the ring of water round a beach ball isn't as wide as the ball")
	// Hitting the water from the air makes a splash and a ring where it went in
	var/obj/item/wrench/dropped = allocate(/obj/item/wrench, origin)
	dropped.forceMove(top_left)
	TEST_ASSERT_NOTNULL(locate(/obj/effect/temp_visual/water_ripple/item) in top_left, "an item dropped into the pool made no ring")
	TEST_ASSERT_NOTNULL(locate(/obj/effect/temp_visual/sink_bubbles) in top_left, "an item going under sent up no bubbles")
	// A mob standing in the pool has its legs bent by the waves
	var/mob/living/carbon/human/swimmer = allocate(/mob/living/carbon/human, top_left)
	var/datum/component/pool_submerged/waist_deep = swimmer.GetComponent(/datum/component/pool_submerged)
	TEST_ASSERT_EQUAL(waist_deep?.refraction?.icon_state, "refract_legs", "the waves don't bend the legs of someone standing in the pool")
	TEST_ASSERT_EQUAL(waist_deep.reflection?.render_source, swimmer.render_target, "someone standing in the pool has no reflection at their waist")
	TEST_ASSERT_EQUAL(waist_deep.unmirrored?.plane, WATER_UNMIRRORED_PLANE, "someone standing in the pool is still mirrored a tile below them")
	swimmer.forceMove(origin)
	ball.forceMove(origin)
	TEST_ASSERT(!(afloat in GLOB.pool_things_afloat), "a beach ball taken out of the pool is still afloat")
	TEST_ASSERT_NULL(ball.render_target, "a beach ball taken out of the pool is still being copied for a reflection")
	dropped.forceMove(origin)

	// Filling in a corner gives the water next to it an edge
	var/turf/corner = locate(origin.x + 3, origin.y, origin.z)
	corner.ChangeTurf(turfs_before[corner])
	top_middle.smooth_icon()
	// Water south (2), west (8) and south west (64)
	TEST_ASSERT_EQUAL(top_middle.smoothing_junction, 74, "water beside a filled in tile didn't lose its east side")

	for(var/turf/T as anything in pool)
		T.ChangeTurf(turfs_before[T])
	TEST_ASSERT(QDELETED(waves), "a pool's waves outlived its last tile")
