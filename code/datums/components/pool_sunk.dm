/**
 * Makes an item lying in a pool look like it's under the water.
 *
 * The water's colour is drawn over the item's own pixels, the same way it is over the legs of someone standing in
 * the pool. Pool water gives this to items that land in it, and it takes itself off when they're picked up or moved
 * out.
 */
/datum/component/pool_sunk
	/// The colours of the pool the item is in, "pool" or "deep"
	var/look

/datum/component/pool_sunk/Initialize(look)
	if(!isitem(parent))
		return COMPONENT_INCOMPATIBLE
	set_look(look)

/datum/component/pool_sunk/Destroy(force)
	var/obj/item/sunk = parent
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
	if(pool.water_look != look)
		set_look(pool.water_look)
