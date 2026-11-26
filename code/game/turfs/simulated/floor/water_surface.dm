/// Is this water that mobs standing beside it are mirrored in?
/proc/is_reflective_water(turf/T)
	if(!istype(T, /turf/simulated/floor/beach/water) && !istype(T, /turf/simulated/floor/beach/away/water))
		return FALSE
	// The reef stone around the sea is a kind of water turf
	return !T.opacity

/**
 * Sets a water turf up to mirror the mobs on the tile north of it. Called by the water turfs as they are made.
 *
 * The mirror image is drawn a tile below the mob, so it's the water south of a mob that shows it.
 */
/turf/simulated/floor/beach/proc/make_reflective()
	var/static/mutable_appearance/water_mask
	if(!water_mask)
		water_mask = mutable_appearance('icons/turf/floors/pool_water.dmi', "mask", plane = WATER_MASK_PLANE)
	overlays += water_mask

	var/turf/north = get_step(src, NORTH)
	if(!north)
		return
	RegisterSignal(north, list(COMSIG_ATOM_ENTERED, COMSIG_ATOM_INITIALIZED_ON), PROC_REF(on_north_entered))
	for(var/mob/living/onlooker in north)
		start_reflecting(onlooker)

/turf/simulated/floor/beach/proc/on_north_entered(turf/source, atom/movable/arrived)
	SIGNAL_HANDLER // COMSIG_ATOM_ENTERED, COMSIG_ATOM_INITIALIZED_ON
	if(isliving(arrived))
		start_reflecting(arrived)

/turf/simulated/floor/beach/proc/start_reflecting(mob/living/onlooker)
	// It keeps its reflection as it walks along the water's edge
	if(!onlooker.GetComponent(/datum/component/water_reflection))
		onlooker.AddComponent(/datum/component/water_reflection)

/// Spreads a ring out from where a mob stepped into the water
/turf/simulated/floor/beach/proc/ripple_from(atom/movable/splasher)
	if(isliving(splasher))
		new /obj/effect/temp_visual/water_ripple(src)

/// The upside down picture of a mob in the water at its feet. It sits in the mob's vis_contents, a tile below it.
/atom/movable/water_reflection
	plane = WATER_REFLECTION_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	// Drawn apart from the mob, and the mob's turning, colour and alpha are already in the picture it copies
	appearance_flags = KEEP_APART | RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
	alpha = 160
	pixel_y = -32

/atom/movable/water_reflection/Initialize(mapload, source)
	. = ..()
	render_source = source
	// Flipped top to bottom
	transform = matrix(1, 0, 0, 0, -1, 0)

/// A ring spreading out on water where something touched it.
/obj/effect/temp_visual/water_ripple
	icon = 'icons/turf/floors/pool_water.dmi'
	icon_state = "ripple"
	layer = ABOVE_MOB_LAYER + 0.05
	duration = 0.9 SECONDS
	randomdir = FALSE
	// Around the feet, not the middle, of whoever made it
	pixel_y = -6

/obj/effect/temp_visual/water_ripple/Initialize(mapload)
	. = ..()
	transform = matrix(0.3, 0, 0, 0, 0.3, 0)
	animate(src, transform = matrix(1.15, 0, 0, 0, 1.15, 0), alpha = 0, time = duration, easing = SINE_EASING | EASE_OUT)
