/**
 * Someone who's just climbed out of a pool: they drip for a while and leave wet footprints for their first few steps.
 * Taken off when they dry, or when they get back in.
 */
/datum/component/pool_wet
	/// The drips falling off them
	var/obj/effect/abstract/particle_holder/drips
	/// How many more steps leave wet footprints
	var/wet_steps = 6
	/// Timer for when they're dry
	var/dry_timer

/datum/component/pool_wet/Initialize()
	if(!isliving(parent))
		return COMPONENT_INCOMPATIBLE
	drips = new(parent, /particles/water_drip)
	dry_timer = addtimer(CALLBACK(src, PROC_REF(dry)), 12 SECONDS, TIMER_STOPPABLE)

/datum/component/pool_wet/Destroy(force)
	deltimer(dry_timer)
	QDEL_NULL(drips)
	return ..()

/datum/component/pool_wet/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))

/datum/component/pool_wet/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_MOVABLE_MOVED)

/datum/component/pool_wet/proc/on_moved(atom/movable/source, atom/old_loc, direction)
	SIGNAL_HANDLER // COMSIG_MOVABLE_MOVED
	if(!wet_steps || !direction || !isturf(source.loc) || is_reflective_water(source.loc))
		return
	wet_steps--
	new /obj/effect/temp_visual/wet_footprints(source.loc, direction)

/datum/component/pool_wet/proc/dry()
	qdel(src)
