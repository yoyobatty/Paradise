/// Is this water that reflects the world and ripples when something steps in?
/proc/is_reflective_water(turf/T)
	if(!istype(T, /turf/simulated/floor/beach/water) && !istype(T, /turf/simulated/floor/beach/away/water))
		return FALSE
	// The reef stone around the sea is a kind of water turf
	return !T.opacity

/**
 * Sets a water turf up to reflect the world. Called by the water turfs as they are made.
 *
 * The reflection plane copies the whole world plane. This tile's mirror map tells it to show the tile above this one
 * upside down here, and its mask and shimmer cut that copy to the water and break it up where the ripples are. Its
 * ripple map says which way the waves slope, which bends the reflection, the pool floor and the glints under them.
 */
/turf/simulated/floor/beach/proc/make_reflective(whole_tile_mask = TRUE)
	// Water with edges puts its own mask on as it picks them
	if(whole_tile_mask)
		overlays += get_pool_appearance("mask", WATER_MASK_PLANE)
	overlays += get_pool_appearance("mirror_map", WATER_MIRROR_PLANE)
	// These follow the ripples, which repeat every 2x2 tiles. Rows of the sprites count from the top, and y counts up,
	// so odd y is the top row
	var/quarter = "[x % 2][y % 2 ? 0 : 1]"
	overlays += get_pool_appearance("ripple_map_[quarter]", WATER_RIPPLE_PLANE)
	overlays += get_pool_appearance("reflection_breakup_[quarter]", WATER_SHIMMER_PLANE)

/// Pool edge styles, and the pool bottom drawn under each
GLOBAL_LIST_INIT(pool_edge_floors, list(
	"coping" = "floor_tiles",
	"deck" = "floor_tiles",
	"rock" = "floor_stones",
	"sand" = "floor_sand",
))

/// Colour and alpha of the light on the pool floor for each look
GLOBAL_LIST_INIT(pool_caustic_colours, list(
	"pool" = list("#B0FCF0", 255),
	"deep" = list("#BEEBFF", 255),
))

/// Colour and alpha of the water's surface for each look
GLOBAL_LIST_INIT(pool_surface_colours, list(
	"pool" = list("#00BAC4", 100),
	"deep" = list("#3478BE", 125),
))

/// One appearance from the pool sprites, made once and shared by every tile that uses it
/proc/get_pool_appearance(state, plane = FLOAT_PLANE, layer = FLOAT_LAYER, colour = null, alpha = 255)
	var/static/list/made = list()
	var/key = "[state]|[plane]|[layer]|[colour]|[alpha]"
	. = made[key]
	if(!.)
		var/mutable_appearance/appearance = mutable_appearance('icons/turf/floors/pool_water.dmi', state, layer, plane = plane, alpha = alpha)
		appearance.color = colour
		made[key] = appearance
		. = appearance

/// Picks one of the three versions of the edge for this tile. The same place always gets the same one.
/turf/simulated/floor/beach/water/proc/pick_edge_variant()
	return (x * 7 + y * 11) % 5 % 3 + 1

/// Puts the pool bottom and its moving light under the water's edge sprite, and the ripples and glints on it
/turf/simulated/floor/beach/water/proc/setup_pool_look()
	underlays += get_pool_appearance(GLOB.pool_edge_floors[edge_style], POOL_FLOOR_PLANE)
	// The web of light the waves focus onto the bottom. An overlay, so it's over the depth's darkening and still shows
	// in deep water. It repeats every 4x4 tiles, and rows of it count from the top
	var/list/light = GLOB.pool_caustic_colours[water_look]
	overlays += get_pool_appearance("caustics_[x % 4][3 - y % 4]", POOL_FLOOR_PLANE, FLOAT_LAYER, light[1], light[2])
	// And the shafts of that light coming down through the water, the same colour
	overlays += get_pool_appearance("rays_[x % 4][3 - y % 4]", WATER_RAYS_PLANE, FLOAT_LAYER, light[1], light[2])
	// Glints on the tops of the waves, which repeat every 2x2 tiles, and glints flashing here and there, every 4x4
	overlays += get_pool_appearance("surface_ripple_[x % 2][y % 2 ? 0 : 1]", WATER_SHINE_PLANE)
	overlays += get_pool_appearance("sparkle_[x % 4][3 - y % 4]", WATER_SHINE_PLANE)
	set_pool_edge_overlays(smoothing_junction || 255)
	update_depth()

/// The water's surface and reflection mask follow its edges, so they stay off the edge itself
/turf/simulated/floor/beach/water/proc/set_pool_edge_overlays(junction)
	if(pool_edge_overlays)
		overlays -= pool_edge_overlays
	var/list/surface = GLOB.pool_surface_colours[water_look]
	var/list/new_overlays = list(
		// Over the pool floor and under mobs: a mob in the pool gets its own water from the waist down
		get_pool_appearance("[base_icon_state]_water-[junction]", FLOAT_PLANE, FLOAT_LAYER, surface[1], surface[2]),
		get_pool_appearance("[base_icon_state]_water-[junction]", WATER_MASK_PLANE),
	)
	// With dry land south, the near side of the pool is in front of anyone standing in it and hides their legs below it.
	// Otherwise their legs, the water on them and the ring round them would show over the edge
	if(!(junction & SOUTH))
		new_overlays += get_pool_appearance("[base_icon_state]_lip-[junction]", GAME_PLANE, ABOVE_MOB_LAYER + 0.01)
	overlays += new_overlays
	pool_edge_overlays = new_overlays

/turf/simulated/floor/beach/water/set_smoothed_icon_state(new_junction)
	. = ..()
	// Broken or burnt floors keep their old junction, so the overlays stay with it too
	if(water_look && !broken && !burnt)
		set_pool_edge_overlays(new_junction)
		update_depth()

/// Is this a turf the pool's depth is measured from?
/turf/simulated/floor/beach/water/proc/is_pool_land(turf/T)
	return !istype(T, /turf/simulated/floor/beach/water)

/**
 * Darkens the water by how far it is from dry land, so a pool gets deeper toward its middle.
 *
 * Each corner of the tile gets a depth from 0 to POOL_MAX_DEPTH: how many tiles lie between it and the nearest
 * dry land. The sprite blends between its four corners, and tiles that meet share corners, so the shade runs
 * smoothly across the pool.
 */
/turf/simulated/floor/beach/water/proc/update_depth()
	// Corners in the order the sprites are named: north west, north east, south west, south east
	var/list/corner_x = list(-1, 1, -1, 1)
	var/list/corner_y = list(1, 1, -1, -1)
	var/list/depths = list(POOL_MAX_DEPTH, POOL_MAX_DEPTH, POOL_MAX_DEPTH, POOL_MAX_DEPTH)
	for(var/turf/T as anything in RANGE_TURFS(POOL_MAX_DEPTH, src))
		if(!is_pool_land(T))
			continue
		var/dx = T.x - x
		var/dy = T.y - y
		for(var/i in 1 to 4)
			// In half tiles from the corner to the near side of that tile, so it comes out a whole number of tiles
			var/reach = (max(abs(2 * dx - corner_x[i]), abs(2 * dy - corner_y[i])) - 1) / 2
			if(reach < depths[i])
				depths[i] = reach
	var/mutable_appearance/new_underlay = get_pool_appearance("depth-[depths[1]][depths[2]][depths[3]][depths[4]]", POOL_FLOOR_PLANE)
	if(new_underlay == pool_depth_underlay)
		return
	if(pool_depth_underlay)
		underlays -= pool_depth_underlay
	underlays += new_underlay
	pool_depth_underlay = new_underlay

/// Has the pool water near this tile pick its edges and depth again, after this tile became or stopped being water
/turf/simulated/floor/beach/water/proc/resmooth_pool_around()
	for(var/turf/simulated/floor/beach/water/W in RANGE_TURFS(POOL_MAX_DEPTH, src))
		if(W != src && W.water_look)
			QUEUE_SMOOTH(W)

/// Spreads ripples out from where a mob stepped into the water, with a splash if it came in from dry land
/turf/simulated/floor/beach/proc/ripple_from(atom/movable/splasher, atom/old_loc)
	if(!isliving(splasher))
		return
	// Wading on through the water. Someone waist deep leaves a wake that carries the ring of waves too, so a step
	// makes one object. Anyone else just sends out a small ring
	if(!isturf(old_loc) || is_reflective_water(old_loc))
		if(!splasher.GetComponent(/datum/component/pool_submerged))
			new /obj/effect/temp_visual/ripple_wave/small(src)
		return
	// Stepping in from dry land: a ring round their waist, the far half behind them and the near half in front,
	// a splash, and a big ring of waves out across the water
	new /obj/effect/temp_visual/water_ripple/waist(src)
	new /obj/effect/temp_visual/water_ripple/waist/back(src)
	new /obj/effect/temp_visual/water_splash(src)
	new /obj/effect/temp_visual/ripple_wave(src)

/// A ring spreading out on water where something touched it.
/obj/effect/temp_visual/water_ripple
	icon = 'icons/turf/floors/pool_water.dmi'
	icon_state = "ripple"
	layer = ABOVE_MOB_LAYER + 0.05
	duration = 0.9 SECONDS
	randomdir = FALSE
	// Around the feet, not the middle, of whoever made it
	pixel_y = -6

/**
 * A ring of waves spreading out from where something touched the water.
 *
 * It's drawn on the hidden ripple plane, so it isn't seen itself. Instead it bends the pool floor, the reflections and
 * the glints as it passes over them, the way a real ripple does.
 */
/obj/effect/temp_visual/ripple_wave
	icon = 'icons/effects/water_ripple_wave.dmi'
	icon_state = "wave"
	plane = WATER_RIPPLE_PLANE
	duration = 1.1 SECONDS
	randomdir = FALSE
	// The sprite is 3x3 tiles with the touch in the middle
	pixel_x = -32
	pixel_y = -32

/// A smaller ring, from a step or a bobber
/obj/effect/temp_visual/ripple_wave/small

/obj/effect/temp_visual/ripple_wave/small/Initialize(mapload)
	. = ..()
	transform = matrix(0.6, 0, 0, 0, 0.6, 0)

/// The half of a ripple round a mob's waist that's in front of it.
/obj/effect/temp_visual/water_ripple/waist
	icon_state = "ripple_front"
	layer = MOB_LAYER + 0.02
	// Puts the middle of the ring at the mob's waist
	pixel_y = -4

/// The half behind the mob.
/obj/effect/temp_visual/water_ripple/waist/back
	icon_state = "ripple_back"
	layer = MOB_LAYER - 0.02

/// Droplets thrown up when someone jumps into the water.
/obj/effect/temp_visual/water_splash
	icon = null
	layer = ABOVE_MOB_LAYER + 0.06
	randomdir = FALSE

/obj/effect/temp_visual/water_splash/Initialize(mapload)
	. = ..()
	particles = new /particles/water_splash
	// One burst, then the droplets already in the air fall back
	addtimer(CALLBACK(src, PROC_REF(stop_spawning)), 0.1 SECONDS)

/obj/effect/temp_visual/water_splash/Destroy()
	QDEL_NULL(particles)
	return ..()

/obj/effect/temp_visual/water_splash/proc/stop_spawning()
	particles?.spawning = 0

/// A V of foam left behind someone moving through the water, on the tile they left, and the small ring of waves the
/// step sends out.
/obj/effect/temp_visual/water_wake
	icon = 'icons/turf/floors/pool_water.dmi'
	icon_state = "wake"
	// On the shine plane, so it's cut to the water and lies on top of it
	plane = WATER_SHINE_PLANE
	duration = 1.2 SECONDS
	randomdir = FALSE

/obj/effect/temp_visual/water_wake/Initialize(mapload, direction)
	. = ..()
	setDir(direction)
	// The ring rides along as an overlay on the hidden ripple plane, rather than being an object of its own
	var/static/mutable_appearance/ring
	if(!ring)
		ring = mutable_appearance('icons/effects/water_ripple_wave.dmi', "wave", plane = WATER_RIPPLE_PLANE)
		ring.pixel_x = -32
		ring.pixel_y = -32
		ring.transform = matrix(0.6, 0, 0, 0, 0.6, 0)
	overlays += ring
	animate(src, alpha = 0, transform = matrix(1.25, 0, 0, 0, 1.25, 0), time = duration, easing = SINE_EASING | EASE_OUT)

/// Wet footprints left by someone who's just climbed out of the water. They dry up.
/obj/effect/temp_visual/wet_footprints
	icon = 'icons/turf/floors/pool_water.dmi'
	icon_state = "wet_footprints"
	layer = LOW_OBJ_LAYER
	duration = 8 SECONDS
	randomdir = FALSE

/obj/effect/temp_visual/wet_footprints/Initialize(mapload, direction)
	. = ..()
	setDir(direction)
	animate(src, alpha = 0, time = duration, easing = SINE_EASING | EASE_IN)

/obj/effect/temp_visual/water_ripple/Initialize(mapload)
	. = ..()
	transform = matrix(0.3, 0, 0, 0, 0.3, 0)
	animate(src, transform = matrix(1.15, 0, 0, 0, 1.15, 0), alpha = 0, time = duration, easing = SINE_EASING | EASE_OUT)

// MARK: Effects only near water

/// How many tiles across a chunk of the map is, for finding water and lava near a player
#define WATER_EFFECT_CHUNK 16

/// Chunks of the map with water or lava in them, "z:x:y" = how many tiles of it
GLOBAL_LIST_EMPTY(water_effect_chunks)
GLOBAL_DATUM(water_effects_watcher, /datum/water_effects_watcher)

/proc/water_effect_chunk_key(turf/T)
	return "[T.z]:[round(T.x / WATER_EFFECT_CHUNK)]:[round(T.y / WATER_EFFECT_CHUNK)]"

/// A tile of water or lava was made, so players near it get the water and lava effects
/proc/add_water_effect_tile(turf/T)
	var/key = water_effect_chunk_key(T)
	GLOB.water_effect_chunks[key] += 1
	if(!GLOB.water_effects_watcher)
		GLOB.water_effects_watcher = new

/// A tile of water or lava is gone
/proc/remove_water_effect_tile(turf/T)
	var/key = water_effect_chunk_key(T)
	var/left = GLOB.water_effect_chunks[key] - 1
	if(left > 0)
		GLOB.water_effect_chunks[key] = left
	else
		GLOB.water_effect_chunks -= key

/// Is there water or lava in the chunk `T` is in, or one next to it? That reaches past a player's screen
/proc/water_effects_near(turf/T)
	var/cx = round(T.x / WATER_EFFECT_CHUNK)
	var/cy = round(T.y / WATER_EFFECT_CHUNK)
	for(var/dx in -1 to 1)
		for(var/dy in -1 to 1)
			if(GLOB.water_effect_chunks["[T.z]:[cx + dx]:[cy + dy]"])
				return TRUE
	return FALSE

/**
 * Turns the water and lava effects on for players with water or lava nearby, and off for everyone else.
 *
 * The reflections, the light on the waves, the glints and the lava's bloom are full screen passes that run every
 * frame whether there's any water on screen or not, and so is every plane master on the screen. Most players are
 * nowhere near any water, so for them the passes are turned off and the water's shown planes taken off the screen.
 * A chunk next to the player's counts as near, so it's all back before any water comes into view.
 */
/datum/water_effects_watcher

/datum/water_effects_watcher/New()
	START_PROCESSING(SSprocessing, src)

/datum/water_effects_watcher/process()
	for(var/client/C as anything in GLOB.clients)
		var/datum/hud/hud = C.mob?.hud_used
		if(!hud)
			continue
		var/turf/T = get_turf(C.eye)
		var/near = !!(T && water_effects_near(T))
		if(near != hud.water_effects_on)
			hud.set_water_effects(near)
		else if(!near)
			// Refreshing the hud puts every plane master back on the screen
			hud.remove_water_planes()

/datum/hud/proc/set_water_effects(on)
	water_effects_on = on
	for(var/plane in plane_masters)
		var/atom/movable/screen/plane_master/master = plane_masters[plane]
		if(!master.water_effect)
			continue
		master.set_water_effects(on)
		if(on && master.water_effect_removable)
			mymob?.client?.screen |= master
	if(!on)
		remove_water_planes()
	// The world and the light on it are only copied for the water to use
	var/atom/movable/screen/plane_master/world_master = plane_masters["[GAME_PLANE]"]
	if(world_master)
		world_master.render_target = on ? GAME_PLANE_RENDER_TARGET : null
	var/atom/movable/screen/plane_master/lighting_master = plane_masters["[LIGHTING_PLANE]"]
	if(lighting_master)
		lighting_master.render_target = on ? LIGHTING_PLANE_RENDER_TARGET : null

/// Takes the water planes that are shown off the player's screen. Nothing is on them with no water or lava nearby,
/// and each plane master on screen costs a pass over the whole screen every frame
/datum/hud/proc/remove_water_planes()
	var/client/viewer = mymob?.client
	if(!viewer)
		return
	for(var/plane in plane_masters)
		var/atom/movable/screen/plane_master/master = plane_masters[plane]
		if(master.water_effect_removable)
			viewer.screen -= master

#undef WATER_EFFECT_CHUNK

