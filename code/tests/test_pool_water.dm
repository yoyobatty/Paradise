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
	// It reflects the world: a mirror map tells the reflection plane what to show, and a shimmer mask breaks it up
	var/list/states = list()
	for(var/mutable_appearance/MA as anything in top_left.overlays)
		states["[MA.icon_state] [MA.plane]"] = TRUE
	var/quarter = "[top_left.x % 2][top_left.y % 2 ? 0 : 1]"
	TEST_ASSERT(states["mirror_map [WATER_MIRROR_PLANE]"], "pool water has no mirror map, so it won't reflect anything")
	TEST_ASSERT(states["wave_flat [WATER_RIPPLE_PLANE]"], "pool water has no flat water for its waves to be drawn over")
	TEST_ASSERT(states["reflection_breakup_[quarter] [WATER_SHIMMER_PLANE]"], "pool water has no shimmer mask")
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

	// Things lying in the pool look sunk, and stop when they're taken out
	var/obj/item/wrench/wrench = allocate(/obj/item/wrench, top_middle)
	TEST_ASSERT_NOTNULL(wrench.GetComponent(/datum/component/pool_sunk), "an item made in the pool doesn't look sunk")
	wrench.forceMove(origin)
	TEST_ASSERT_NULL(wrench.GetComponent(/datum/component/pool_sunk), "an item taken out of the pool still looks sunk")
	TEST_ASSERT_NULL(wrench.get_filter("pool_sunk"), "an item taken out of the pool still has the water drawn over it")

	// Filling in a corner gives the water next to it an edge
	var/turf/corner = locate(origin.x + 3, origin.y, origin.z)
	corner.ChangeTurf(turfs_before[corner])
	top_middle.smooth_icon()
	// Water south (2), west (8) and south west (64)
	TEST_ASSERT_EQUAL(top_middle.smoothing_junction, 74, "water beside a filled in tile didn't lose its east side")

	for(var/turf/T as anything in pool)
		T.ChangeTurf(turfs_before[T])
	TEST_ASSERT(QDELETED(waves), "a pool's waves outlived its last tile")
