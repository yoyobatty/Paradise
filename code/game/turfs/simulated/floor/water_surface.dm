/// Is this water that reflects the world and ripples when something steps in?
/proc/is_reflective_water(turf/T)
	if(!istype(T, /turf/simulated/floor/beach/water) && !istype(T, /turf/simulated/floor/beach/away/water))
		return FALSE
	// The reef stone around the sea is a kind of water turf
	return !T.opacity

/// Sets a water turf up to reflect the world and ripple.
/// whole_tile_mask - FALSE for water with edges, which puts on its own mask
/// still_waves - FALSE for pool water, whose waves come from /datum/pool_waves
/turf/simulated/floor/beach/proc/make_reflective(whole_tile_mask = TRUE, still_waves = TRUE)
	if(whole_tile_mask)
		overlays += get_pool_appearance("mask", WATER_MASK_PLANE)
	overlays += get_pool_appearance("mirror_map", WATER_MIRROR_PLANE)
	// Which quarter of the 2x2 wave sprites this tile is. Sprite rows count from the top, so odd y is the top row
	var/quarter = "[x % 2][y % 2 ? 0 : 1]"
	// Fades the reflection with height, as a mask over the tile north of this one
	var/static/mutable_appearance/mirror_fade
	if(!mirror_fade)
		mirror_fade = mutable_appearance('icons/turf/floors/pool_water.dmi', "mirror_fade", plane = WATER_UNMIRRORED_PLANE)
		mirror_fade.pixel_y = world.icon_size
	overlays += mirror_fade
	// Flat water for the waves to be drawn over
	overlays += get_pool_appearance("wave_flat", WATER_RIPPLE_PLANE)
	if(still_waves)
		// Always the same gentle waves
		overlays += get_pool_appearance("chop_[quarter]", WATER_RIPPLE_PLANE, alpha = 110)
		overlays += get_pool_appearance("fine_[quarter]", WATER_RIPPLE_PLANE, alpha = 80)

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

/// How much of the light on the pool floor is left under 0, 1, 2 and 3 tiles of water
GLOBAL_LIST_INIT(pool_caustic_fade, list(1, 0.86, 0.72, 0.6))

/// Colour and alpha of the water's surface for each look
GLOBAL_LIST_INIT(pool_surface_colours, list(
	"pool" = list("#00BAC4", 100),
	"deep" = list("#3478BE", 125),
))

/// Gets a pool sprite appearance, made once and shared by every tile
/proc/get_pool_appearance(state, plane = FLOAT_PLANE, layer = FLOAT_LAYER, colour = null, alpha = 255)
	var/static/list/made = list()
	var/key = "[state]|[plane]|[layer]|[colour]|[alpha]"
	. = made[key]
	if(!.)
		var/mutable_appearance/appearance = mutable_appearance('icons/turf/floors/pool_water.dmi', state, layer, plane = plane, alpha = alpha)
		appearance.color = colour
		made[key] = appearance
		. = appearance

/// Gets a pool sprite state as an icon for filters, made once
/proc/get_pool_filter_icon(state)
	var/static/list/made = list()
	. = made[state]
	if(!.)
		. = made[state] = icon('icons/turf/floors/pool_water.dmi', state)

/// Picks one of three edge versions for this tile, always the same one for the same spot
/turf/simulated/floor/beach/water/proc/pick_edge_variant()
	return (x * 7 + y * 11) % 5 % 3 + 1

/// Adds the pool floor, light, glints, foam, bubbles, edges and depth to this tile
/turf/simulated/floor/beach/water/proc/setup_pool_look()
	underlays += get_pool_appearance(GLOB.pool_edge_floors[edge_style], POOL_FLOOR_PLANE)
	// Shafts of light down through the water. The light on the floor is added in update_depth()
	var/list/light = GLOB.pool_caustic_colours[water_look]
	overlays += get_pool_appearance("rays_[x % 4][3 - y % 4]", WATER_RAYS_PLANE, FLOAT_LAYER, light[1], light[2])
	// Glints, repeating every 4x4 tiles
	overlays += get_pool_appearance("sparkle_[x % 4][3 - y % 4]", WATER_SHINE_PLANE)
	// Foam flecks, which only show at the water's edges and on steep waves
	overlays += get_pool_appearance("foam_[x % 4][3 - y % 4]", WATER_FOAM_PLANE)
	// Bubbles rise now and then on a few tiles
	if((x * 13 + y * 7) % 17 == 0)
		overlays += get_pool_appearance("bubbles_[(x + y) % 3 + 1]", WATER_SHINE_PLANE)
	set_pool_edge_overlays(smoothing_junction || 255)
	update_depth()

/// Sets the water surface, reflection mask and near edge to match this tile's edges
/turf/simulated/floor/beach/water/proc/set_pool_edge_overlays(junction)
	if(pool_edge_overlays)
		overlays -= pool_edge_overlays
	var/list/surface = GLOB.pool_surface_colours[water_look]
	var/list/new_overlays = list(
		// Over the pool floor and under mobs, who get their own water from the waist down
		get_pool_appearance("[base_icon_state]_water-[junction]", FLOAT_PLANE, FLOAT_LAYER, surface[1], surface[2]),
		get_pool_appearance("[base_icon_state]_water-[junction]", WATER_MASK_PLANE),
	)
	// With dry land south, the near edge is drawn over anyone in the pool so their legs don't show over it
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

/// Shades the water deeper the farther each corner is from dry land, and dims the floor light to match
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
			// Tiles from this corner to the near side of that tile, worked out in half tiles
			var/reach = (max(abs(2 * dx - corner_x[i]), abs(2 * dy - corner_y[i])) - 1) / 2
			if(reach < depths[i])
				depths[i] = reach
	var/mutable_appearance/new_underlay = get_pool_appearance("depth-[depths[1]][depths[2]][depths[3]][depths[4]]", POOL_FLOOR_PLANE)
	if(new_underlay != pool_depth_underlay)
		if(pool_depth_underlay)
			underlays -= pool_depth_underlay
		underlays += new_underlay
		pool_depth_underlay = new_underlay
	// Light on the floor, fainter in deeper water. An overlay, so it's drawn over the depth's darkening
	var/depth = clamp(round((depths[1] + depths[2] + depths[3] + depths[4]) / 4, 1), 0, POOL_MAX_DEPTH)
	var/list/light = GLOB.pool_caustic_colours[water_look]
	var/mutable_appearance/new_caustics = get_pool_appearance("caustics_[x % 4][3 - y % 4]", POOL_FLOOR_PLANE, FLOAT_LAYER, light[1], round(light[2] * GLOB.pool_caustic_fade[depth + 1]))
	if(new_caustics != pool_caustics)
		if(pool_caustics)
			overlays -= pool_caustics
		overlays += new_caustics
		pool_caustics = new_caustics

/// Makes nearby pool water redo its edges and depth after this tile becomes or stops being water
/turf/simulated/floor/beach/water/proc/resmooth_pool_around()
	for(var/turf/simulated/floor/beach/water/W in RANGE_TURFS(POOL_MAX_DEPTH, src))
		if(W != src && W.water_look)
			QUEUE_SMOOTH(W)

/// Joins this tile to the waves of the pool beside it, or starts new ones
/turf/simulated/floor/beach/water/proc/join_pool_waves()
	var/datum/pool_waves/joined
	for(var/direction in GLOB.cardinal)
		var/turf/simulated/floor/beach/water/beside = get_step(src, direction)
		if(!istype(beside) || !beside.waves)
			continue
		// This tile joins two pools into one
		joined = joined ? joined.merge(beside.waves) : beside.waves
	if(!joined)
		joined = new
	joined.add_tile(src)

/// Stirs the water here by `amount`, out of 1. Only pools do anything with it
/turf/simulated/floor/beach/proc/stir_water(amount)
	return

/turf/simulated/floor/beach/water/stir_water(amount)
	waves?.stir(amount)

/// How long a ring of waves takes to cross a tile
#define WAVE_RING_TILE_TIME (0.9 SECONDS)

/// Sends a ring of waves out from this tile, bounces it off the dry edges beside it, and lifts things afloat nearby.
/// small - a smaller ring, from a step or a small thing landing
/// offset_x, offset_y - how many pixels right and up of the tile's middle the ring starts
/turf/simulated/floor/beach/proc/make_wave_ring(small = FALSE, offset_x = 0, offset_y = 0)
	var/ring_type = small ? /obj/effect/temp_visual/ripple_wave/small : /obj/effect/temp_visual/ripple_wave
	var/echo_type = small ? /obj/effect/temp_visual/ripple_wave/small/echo : /obj/effect/temp_visual/ripple_wave/echo
	var/obj/effect/temp_visual/ripple_wave/ring = new ring_type(src)
	ring.pixel_x += offset_x
	ring.pixel_y += offset_y
	for(var/direction in GLOB.cardinal)
		var/turf/beside = get_step(src, direction)
		if(!beside || is_reflective_water(beside))
			continue
		// As far from the edge on that side as the ring is on this one
		var/obj/effect/temp_visual/ripple_wave/echo = new echo_type(beside)
		echo.pixel_x += (direction & (EAST | WEST)) ? -offset_x : offset_x
		echo.pixel_y += (direction & (NORTH | SOUTH)) ? -offset_y : offset_y
	var/reach = small ? 1 : 2
	for(var/datum/component/pool_sunk/afloat as anything in GLOB.pool_things_afloat)
		var/atom/movable/thing = afloat.parent
		if(thing.z != z || !isturf(thing.loc))
			continue
		var/away = get_dist(src, thing)
		// Not things on this tile, like whatever just landed and made the ring
		if(away >= 1 && away <= reach)
			addtimer(CALLBACK(afloat, TYPE_PROC_REF(/datum/component/pool_sunk, ride_wave)), away * WAVE_RING_TILE_TIME)

#undef WAVE_RING_TILE_TIME

/// Spreads ripples out from where a mob stepped into the water, with a splash if it came in from dry land
/turf/simulated/floor/beach/proc/ripple_from(atom/movable/splasher, atom/old_loc)
	if(!isliving(splasher))
		return
	// Wading on. Someone waist deep leaves a wake, anyone else sends out a small ring
	if(!isturf(old_loc) || is_reflective_water(old_loc))
		stir_water(0.03)
		if(!splasher.GetComponent(/datum/component/pool_submerged))
			new /obj/effect/temp_visual/ripple_wave/small(src)
		return
	// Stepping in from dry land: a ring round their waist, a splash and a big ring of waves
	stir_water(0.2)
	playsound(src, 'sound/effects/slosh.ogg', 30, TRUE)
	new /obj/effect/temp_visual/water_ripple/waist(src)
	new /obj/effect/temp_visual/water_ripple/waist/back(src)
	new /obj/effect/temp_visual/water_splash(src)
	make_wave_ring()

/// Reflection of something standing or floating in water, flipped at its waterline. Goes in its vis_contents
/obj/effect/abstract/water_reflection
	plane = WATER_SELF_REFLECTION_PLANE
	invisibility = 0
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	// The copy already has the thing's colour and transform
	appearance_flags = KEEP_APART | RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
	/// TRUE if this set the thing's render_target, so it clears it again
	var/made_render_target = FALSE

/obj/effect/abstract/water_reflection/Initialize(mapload, atom/movable/reflected, waterline)
	. = ..()
	// Things with their own emissive blocker already have one, with the same name
	if(!reflected.render_target)
		reflected.render_target = ref(reflected)
		made_render_target = TRUE
	render_source = reflected.render_target
	// Darker, bluer and a bit see-through. Alpha is in the matrix, BYOND ignores alpha while colour is a matrix
	color = list(0.78, 0, 0, 0, 0, 0.8, 0, 0, 0, 0, 0.86, 0, 0, 0, 0, 0.9, 0.02, 0.04, 0.08, 0)
	// Flipped at the waterline, `waterline` pixels up from the bottom of the sprite
	transform = matrix(1, 0, 0, 0, -1, 2 * waterline - world.icon_size)

/// Takes back the render_target this gave the thing, once it's out of the water
/obj/effect/abstract/water_reflection/proc/stop_reflecting(atom/movable/reflected)
	if(made_render_target && !reflected.em_block)
		reflected.render_target = null

/// Makes a block for a thing's vis_contents that keeps it out of the reflection plane's mirror
/proc/make_unmirrored_block()
	var/obj/effect/abstract/waterline/block = new(null, "mask")
	block.vis_flags = VIS_INHERIT_ID
	block.plane = WATER_UNMIRRORED_PLANE
	return block

/// A ring spreading out on water where something touched it.
/obj/effect/temp_visual/water_ripple
	icon = 'icons/turf/floors/pool_water.dmi'
	icon_state = "ripple"
	layer = ABOVE_MOB_LAYER + 0.05
	duration = 0.9 SECONDS
	randomdir = FALSE
	// At the feet of whoever made it
	pixel_y = -6
	/// Size it grows to before it's gone, 1 is a tile across
	var/final_scale = 1.15

/// A ring of waves on the hidden ripple plane, which bends the floor, reflections and glints as it spreads
/obj/effect/temp_visual/ripple_wave
	icon = 'icons/effects/water_ripple_wave.dmi'
	icon_state = "wave"
	plane = WATER_RIPPLE_PLANE
	duration = 1.1 SECONDS
	randomdir = FALSE
	// The sprite is 3x3 tiles with the touch in the middle
	pixel_x = -32
	pixel_y = -32

/// A smaller ring, from a step or something small landing
/obj/effect/temp_visual/ripple_wave/small

/obj/effect/temp_visual/ripple_wave/small/Initialize(mapload)
	. = ..()
	transform = matrix(0.6, 0, 0, 0, 0.6, 0)

/// A fainter ring bounced back off the water's edge, see make_wave_ring()
/obj/effect/temp_visual/ripple_wave/echo
	alpha = 150

/obj/effect/temp_visual/ripple_wave/small/echo
	alpha = 150

/// Smaller ring where an item lands in the water
/obj/effect/temp_visual/water_ripple/item
	// On the shine plane, so it's cut to the water and under the thing that made it
	plane = WATER_SHINE_PLANE
	pixel_y = 0
	final_scale = 0.75

/// Ring for something big
/obj/effect/temp_visual/water_ripple/item/big
	final_scale = 1.1

/// Bubbles coming up where something has just sunk.
/obj/effect/temp_visual/sink_bubbles
	icon = 'icons/turf/floors/pool_water.dmi'
	icon_state = "sink_bubbles"
	plane = WATER_SHINE_PLANE
	duration = 1.7 SECONDS
	randomdir = FALSE

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
	/// The droplets it throws up
	var/splash_type = /particles/water_splash

/// The few droplets from something small landing in the water.
/obj/effect/temp_visual/water_splash/small
	splash_type = /particles/water_splash/small

/obj/effect/temp_visual/water_splash/Initialize(mapload)
	. = ..()
	particles = new splash_type
	// One burst, then the droplets already in the air fall back
	addtimer(CALLBACK(src, PROC_REF(stop_spawning)), 0.1 SECONDS)

/obj/effect/temp_visual/water_splash/Destroy()
	QDEL_NULL(particles)
	return ..()

/obj/effect/temp_visual/water_splash/proc/stop_spawning()
	particles?.spawning = 0

/// V wake of foam and waves left on the tile someone waded out of
/obj/effect/temp_visual/water_wake
	icon = 'icons/turf/floors/pool_water.dmi'
	icon_state = "wake"
	// On the shine plane, so it's cut to the water and lies on top of it
	plane = WATER_SHINE_PLANE
	duration = 1.6 SECONDS
	randomdir = FALSE

/obj/effect/temp_visual/water_wake/Initialize(mapload, direction)
	. = ..()
	setDir(direction)
	// The waves are an overlay, so they turn with the wake
	var/static/mutable_appearance/waves
	if(!waves)
		waves = mutable_appearance('icons/effects/water_ripple_wave.dmi', "wake", plane = WATER_RIPPLE_PLANE)
		// The sprite is 3x3 tiles with this tile in the middle
		waves.pixel_x = -32
		waves.pixel_y = -32
	overlays += waves
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
	animate(src, transform = matrix(final_scale, 0, 0, 0, final_scale, 0), alpha = 0, time = duration, easing = SINE_EASING | EASE_OUT)

// MARK: Effects only near water

/// Size of a map chunk in tiles, for checking if a player is near water
#define WATER_EFFECT_CHUNK 16

/// Chunks of the map with water in them, "z:x:y" = how many tiles of it
GLOBAL_LIST_EMPTY(water_effect_chunks)
GLOBAL_DATUM(water_effects_watcher, /datum/water_effects_watcher)

/proc/water_effect_chunk_key(turf/T)
	return "[T.z]:[round(T.x / WATER_EFFECT_CHUNK)]:[round(T.y / WATER_EFFECT_CHUNK)]"

/// Counts a new water tile in its chunk
/proc/add_water_effect_tile(turf/T)
	var/key = water_effect_chunk_key(T)
	GLOB.water_effect_chunks[key] += 1
	if(!GLOB.water_effects_watcher)
		GLOB.water_effects_watcher = new

/// Takes a water tile off its chunk's count
/proc/remove_water_effect_tile(turf/T)
	var/key = water_effect_chunk_key(T)
	var/left = GLOB.water_effect_chunks[key] - 1
	if(left > 0)
		GLOB.water_effect_chunks[key] = left
	else
		GLOB.water_effect_chunks -= key

/// Is there water in the chunk `T` is in, or one next to it?
/proc/water_effects_near(turf/T)
	var/cx = round(T.x / WATER_EFFECT_CHUNK)
	var/cy = round(T.y / WATER_EFFECT_CHUNK)
	for(var/dx in -1 to 1)
		for(var/dy in -1 to 1)
			if(GLOB.water_effect_chunks["[T.z]:[cx + dx]:[cy + dy]"])
				return TRUE
	return FALSE

/// Turns the water effects on for players near water and off for everyone else.
/// The water planes cost full screen passes every frame, even with no water on screen.
/// Checking the chunks around the player turns them on before any water comes into view.
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
	// Only copy the world and lighting, and bend the world, while the water effects are on
	var/atom/movable/screen/plane_master/game_world/world_master = plane_masters["[GAME_PLANE]"]
	if(world_master)
		world_master.render_target = on ? GAME_PLANE_RENDER_TARGET : null
		world_master.set_water_refraction(on)
	var/atom/movable/screen/plane_master/lighting_master = plane_masters["[LIGHTING_PLANE]"]
	if(lighting_master)
		lighting_master.render_target = on ? LIGHTING_PLANE_RENDER_TARGET : null

/// Takes the shown water planes off the player's screen, since each costs a full screen pass every frame
/datum/hud/proc/remove_water_planes()
	var/client/viewer = mymob?.client
	if(!viewer)
		return
	for(var/plane in plane_masters)
		var/atom/movable/screen/plane_master/master = plane_masters[plane]
		if(master.water_effect_removable)
			viewer.screen -= master

#undef WATER_EFFECT_CHUNK

