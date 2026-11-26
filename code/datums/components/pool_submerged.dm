/// How far the squash map can move a row of a mob's legs, in pixels. The map is drawn for this
#define POOL_LEG_SQUASH 4
/// How far the ripple running down a mob's legs moves them left and right, in pixels
#define POOL_LEG_WAVE 1.2
/// How long one wave takes to run down the legs
#define POOL_LEG_WAVE_TIME (1.6 SECONDS)

/**
 * Makes a mob standing in a pool look waist deep.
 *
 * Water is drawn over the mob's own pixels from the waist down, its legs look shorter through the water with ripples
 * running down them, and a ring of water sits round its waist, half behind it and half in front. Pool water gives this
 * to mobs that walk in, and it takes itself off when they walk out.
 */
/datum/component/pool_submerged
	/// The colours of the pool the mob is in, "pool" or "deep"
	var/look
	/// The back half of the ring of water round the mob's waist, drawn behind it
	var/obj/effect/abstract/waterline/back_ring
	/// The front half, drawn over it
	var/obj/effect/abstract/waterline/front_ring
	/// Their shadow on the pool floor
	var/obj/effect/abstract/waterline/floor_shadow

/datum/component/pool_submerged/Initialize(look)
	if(!isliving(parent))
		return COMPONENT_INCOMPATIBLE
	var/mob/living/owner = parent
	// Back in the water, so no longer dripping
	qdel(owner.GetComponent(/datum/component/pool_wet))
	back_ring = new(null, "waterline_back")
	back_ring.vis_flags |= VIS_UNDERLAY
	front_ring = new(null, "waterline_front")
	// On the pool floor under the water, so it's tinted with it and the ripples bend it
	floor_shadow = new(null, "swimmer_shadow")
	floor_shadow.vis_flags = VIS_INHERIT_ID
	floor_shadow.plane = POOL_FLOOR_PLANE
	owner.vis_contents += list(back_ring, front_ring, floor_shadow)
	set_look(look)

/datum/component/pool_submerged/Destroy(force)
	var/mob/living/owner = parent
	owner.vis_contents -= list(back_ring, front_ring, floor_shadow)
	QDEL_NULL(back_ring)
	QDEL_NULL(front_ring)
	QDEL_NULL(floor_shadow)
	owner.remove_filter(list("pool_submerged", "pool_legs_squash", "pool_legs_wave_sin", "pool_legs_wave_cos"))
	return ..()

/datum/component/pool_submerged/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))

/datum/component/pool_submerged/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_MOVABLE_MOVED)

/// Puts the water over the mob's legs in the colours of the pool it's in
/datum/component/pool_submerged/proc/set_look(new_look)
	look = new_look
	var/mob/living/owner = parent
	// Drawn over the mob's own pixels only, so the tile round it isn't tinted twice
	owner.add_filter("pool_submerged", 20, layering_filter(icon = icon('icons/turf/floors/pool_water.dmi', "submerged_[look]"), blend_mode = BLEND_INSET_OVERLAY))
	// Legs look a little shorter through the water. These maps leave the mob alone above its waist
	owner.add_filter("pool_legs_squash", 21, displacement_map_filter(icon = icon('icons/turf/floors/pool_water.dmi', "submerged_squash"), size = POOL_LEG_SQUASH))
	// Two waves down the legs, a quarter of a wave apart. Swaying them in turn adds up to one ripple running down the
	// legs, where swaying one alone would bend the whole leg back and forth
	owner.add_filter("pool_legs_wave_sin", 22, displacement_map_filter(icon = icon('icons/turf/floors/pool_water.dmi', "submerged_wave_sin"), size = POOL_LEG_WAVE))
	owner.add_filter("pool_legs_wave_cos", 23, displacement_map_filter(icon = icon('icons/turf/floors/pool_water.dmi', "submerged_wave_cos"), size = 0))
	// Adding a filter makes them all again, which stops the waves, so they're started after all of them are on.
	// One goes like cos and the other like -sin, which together give sin(row - time): a wave moving down
	var/quarter = POOL_LEG_WAVE_TIME / 4
	animate(owner.get_filter("pool_legs_wave_sin"), size = 0, time = quarter, loop = -1, easing = SINE_EASING | EASE_IN)
	animate(size = -POOL_LEG_WAVE, time = quarter, easing = SINE_EASING | EASE_OUT)
	animate(size = 0, time = quarter, easing = SINE_EASING | EASE_IN)
	animate(size = POOL_LEG_WAVE, time = quarter, easing = SINE_EASING | EASE_OUT)
	animate(owner.get_filter("pool_legs_wave_cos"), size = -POOL_LEG_WAVE, time = quarter, loop = -1, easing = SINE_EASING | EASE_OUT)
	animate(size = 0, time = quarter, easing = SINE_EASING | EASE_IN)
	animate(size = POOL_LEG_WAVE, time = quarter, easing = SINE_EASING | EASE_OUT)
	animate(size = 0, time = quarter, easing = SINE_EASING | EASE_IN)

/datum/component/pool_submerged/proc/on_moved(atom/movable/source, atom/old_loc, direction)
	SIGNAL_HANDLER // COMSIG_MOVABLE_MOVED
	if(!check_water())
		return
	// A wake on the water they just left
	if(direction && istype(old_loc, /turf/simulated/floor/beach/water))
		new /obj/effect/temp_visual/water_wake(old_loc, direction)

/**
 * Keeps the look in step with the water the mob is in. Called when it moves, and when the water under it is drained
 * or changed while it stands still.
 *
 * Returns FALSE, and takes itself off, if the mob isn't in pool water any more.
 */
/datum/component/pool_submerged/proc/check_water()
	var/atom/movable/owner = parent
	var/turf/simulated/floor/beach/water/pool = owner.loc
	if(!istype(pool) || !pool.water_look)
		// Out of the water: dripping for a while, and leaving wet footprints if they walked out onto the floor
		if(isturf(owner.loc))
			owner.AddComponent(/datum/component/pool_wet)
		qdel(src)
		return FALSE
	if(pool.water_look != look)
		set_look(pool.water_look)
	return TRUE

/// One half of the ring of water round a mob's waist, in the mob's vis_contents.
/obj/effect/abstract/waterline
	icon = 'icons/turf/floors/pool_water.dmi'
	invisibility = 0
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	// Drawn on the mob's plane, and clicks on it count as clicks on the mob
	vis_flags = VIS_INHERIT_PLANE | VIS_INHERIT_ID

/obj/effect/abstract/waterline/Initialize(mapload, state)
	. = ..()
	icon_state = state

#undef POOL_LEG_SQUASH
#undef POOL_LEG_WAVE
#undef POOL_LEG_WAVE_TIME
