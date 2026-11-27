/// How far the squash map can move a row of a mob's legs, in pixels. The map is drawn for this
#define POOL_LEG_SQUASH 4

/**
 * Makes a mob standing in a pool look waist deep.
 *
 * Water is drawn over the mob's own pixels from the waist down, its legs look shorter through the water and bend
 * under the waves, and a ring of water sits round its waist, half behind it and half in front. A mob lying down in
 * the pool is under the water from head to toe instead. Pool water gives this to mobs that walk in, and it takes
 * itself off when they walk out.
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
	/// Where the waves bend them, on the refraction plane: more the further down their legs, as deeper water does
	var/obj/effect/abstract/waterline/refraction
	/// Is the mob lying down in the water? Then all of it is under, not only its legs
	var/lying = FALSE

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
	refraction = new(null, "refract_legs")
	refraction.vis_flags = VIS_INHERIT_ID
	refraction.plane = WATER_REFRACT_PLANE
	owner.vis_contents += list(back_ring, front_ring, floor_shadow, refraction)
	// The water rises and falls a little round them
	for(var/obj/effect/abstract/waterline/ring in list(back_ring, front_ring))
		animate(ring, pixel_y = 1, time = 1.6 SECONDS, loop = -1, easing = SINE_EASING)
		animate(pixel_y = -1, time = 1.6 SECONDS, easing = SINE_EASING)
	lying = owner.body_position == LYING_DOWN
	set_look(look)

/datum/component/pool_submerged/Destroy(force)
	var/mob/living/owner = parent
	owner.vis_contents -= list(back_ring, front_ring, floor_shadow, refraction)
	QDEL_NULL(back_ring)
	QDEL_NULL(front_ring)
	QDEL_NULL(floor_shadow)
	QDEL_NULL(refraction)
	owner.remove_filter(list("pool_submerged", "pool_legs_squash"))
	return ..()

/datum/component/pool_submerged/proc/on_resting(datum/source, now_lying)
	SIGNAL_HANDLER // COMSIG_LIVING_RESTING
	lying = now_lying
	set_look(look)

/datum/component/pool_submerged/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	RegisterSignal(parent, COMSIG_LIVING_RESTING, PROC_REF(on_resting))

/datum/component/pool_submerged/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_RESTING))

/// Puts the water over the mob's legs in the colours of the pool it's in
/datum/component/pool_submerged/proc/set_look(new_look)
	look = new_look
	var/mob/living/owner = parent
	// No ring round the waist of someone lying under the water
	back_ring.alpha = lying ? 0 : 255
	front_ring.alpha = lying ? 0 : 255
	// The waves bend all of someone lying under the water, and only the legs of someone standing in it
	refraction.icon_state = lying ? "refract_all" : "refract_legs"
	if(lying)
		// All of them is under, and there are no legs standing in it to look shorter
		owner.remove_filter("pool_legs_squash")
		owner.add_filter("pool_submerged", 20, layering_filter(icon = get_pool_filter_icon("sunk_[look]"), blend_mode = BLEND_INSET_OVERLAY))
		return
	// Drawn over the mob's own pixels only, so the tile round it isn't tinted twice
	owner.add_filter("pool_submerged", 20, layering_filter(icon = get_pool_filter_icon("submerged_[look]"), blend_mode = BLEND_INSET_OVERLAY))
	// Legs look a little shorter through the water. The map leaves the mob alone above its waist
	owner.add_filter("pool_legs_squash", 21, displacement_map_filter(icon = get_pool_filter_icon("submerged_squash"), size = POOL_LEG_SQUASH))

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
