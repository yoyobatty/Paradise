/**
 * Makes an item lying in a pool look like it's under the water, or floating on it.
 *
 * The water's colour is drawn over the item's own pixels, the same way it is over the legs of someone standing in
 * the pool. A few things float instead, and bob up and down on the water. Pool water gives this to items that land
 * in it, and it takes itself off when they're picked up or moved out.
 */
/datum/component/pool_sunk
	/// The colours of the pool the item is in, "pool" or "deep"
	var/look
	/// Does the item float on the water instead of lying under it?
	var/floating = FALSE

/datum/component/pool_sunk/Initialize(look, floating = FALSE)
	if(!isitem(parent))
		return COMPONENT_INCOMPATIBLE
	src.floating = floating
	if(!floating)
		set_look(look)
		return
	// Up and down with the water, at its own pace so two of them don't move as one
	var/obj/item/floater = parent
	var/bob = rand(14, 20)
	animate(floater, pixel_z = 2, time = bob, loop = -1, easing = SINE_EASING, flags = ANIMATION_PARALLEL)
	animate(pixel_z = 0, time = bob, easing = SINE_EASING)

/datum/component/pool_sunk/Destroy(force)
	var/obj/item/sunk = parent
	if(floating)
		animate(sunk, pixel_z = 0, time = 2)
	else
		sunk.remove_filter("pool_sunk")
	return ..()

/datum/component/pool_sunk/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))

/datum/component/pool_sunk/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_MOVABLE_MOVED)

/datum/component/pool_sunk/proc/set_look(new_look)
	look = new_look
	var/obj/item/sunk = parent
	// Drawn over the item's own pixels only, so the tile round it isn't tinted twice
	sunk.add_filter("pool_sunk", 20, layering_filter(icon = icon('icons/turf/floors/pool_water.dmi', "sunk_[look]"), blend_mode = BLEND_INSET_OVERLAY))

/datum/component/pool_sunk/proc/on_moved(atom/movable/source, atom/old_loc, direction)
	SIGNAL_HANDLER // COMSIG_MOVABLE_MOVED
	check_water()

/// Keeps the look in step with the water the item is in, and takes it off once the item isn't in pool water any more
/datum/component/pool_sunk/proc/check_water()
	var/atom/movable/sunk = parent
	var/turf/simulated/floor/beach/water/pool = sunk.loc
	if(!istype(pool) || !pool.water_look)
		qdel(src)
		return
	if(pool.water_look != look && !floating)
		set_look(pool.water_look)
