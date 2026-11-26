/**
 * Mirrors a mob in the water at its feet.
 *
 * Water turfs give this to mobs that step onto the tile north of them. It stays on the mob while it walks
 * along the water's edge and takes itself off a moment after the mob leaves.
 */
/datum/component/water_reflection
	/// The mirror image, in the mob's vis_contents
	var/atom/movable/water_reflection/reflection
	/// Timer that takes the reflection away after the mob has left the water's edge
	var/leave_timer

/datum/component/water_reflection/Initialize()
	if(!isliving(parent))
		return COMPONENT_INCOMPATIBLE
	var/mob/living/owner = parent
	// The reflection copies the mob's picture as it is drawn, which needs it to have a name to copy it by
	if(!owner.render_target)
		owner.render_target = ref(owner)
	reflection = new(null, owner.render_target)
	owner.vis_contents += reflection

/datum/component/water_reflection/Destroy()
	deltimer(leave_timer)
	var/mob/living/owner = parent
	owner.vis_contents -= reflection
	QDEL_NULL(reflection)
	return ..()

/datum/component/water_reflection/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))

/datum/component/water_reflection/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_MOVABLE_MOVED)

/datum/component/water_reflection/proc/on_moved(atom/movable/source)
	SIGNAL_HANDLER // COMSIG_MOVABLE_MOVED
	if(isturf(source.loc) && is_reflective_water(get_step(source, SOUTH)))
		deltimer(leave_timer)
		leave_timer = null
		return
	if(leave_timer)
		return
	// Not straight away, so the reflection slides out from under the bank as the mob walks off instead of blinking out
	leave_timer = addtimer(CALLBACK(src, PROC_REF(leave)), 0.5 SECONDS, TIMER_STOPPABLE)

/datum/component/water_reflection/proc/leave()
	qdel(src)
