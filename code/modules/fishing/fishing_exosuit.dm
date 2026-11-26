/**
 * A hydraulic fishing rod for working exosuits.
 *
 * Its braided steel line doesn't burn and reaches deep lava, where no hand rod can fish. A firefighter Ripley can
 * wade out into the lava to get to it. Whatever's caught goes into a Ripley's cargo hold, or onto the nearest floor
 * that isn't lava.
 */
/obj/item/mecha_parts/mecha_equipment/fishing_rod
	name = "exosuit fishing rod"
	desc = "A hydraulic fishing rod and winch for working exosuits, on a braided steel line that won't burn. It reaches deep lava."
	icon = 'icons/obj/fishing.dmi'
	icon_state = "mecha_fishing_rod"
	range = MECHA_MELEE | MECHA_RANGED
	energy_drain = 20
	/// The rod it fishes with
	var/obj/item/fishing_rod/exosuit/rod

/obj/item/mecha_parts/mecha_equipment/fishing_rod/Initialize(mapload)
	. = ..()
	rod = new(src)

/obj/item/mecha_parts/mecha_equipment/fishing_rod/Destroy()
	QDEL_NULL(rod)
	return ..()

/obj/item/mecha_parts/mecha_equipment/fishing_rod/can_attach(obj/mecha/M)
	return ..() && istype(M, /obj/mecha/working)

/obj/item/mecha_parts/mecha_equipment/fishing_rod/detach(atom/moveto)
	// Deleting it drops the rod before taking it off the exosuit
	if(rod)
		QDEL_NULL(rod.session)
	return ..()

/obj/item/mecha_parts/mecha_equipment/fishing_rod/action(atom/target)
	if(!action_checks(target) || !chassis.occupant)
		return
	if(rod.use_on(target, chassis.occupant))
		chassis.use_power(energy_drain)

/// The rod inside an exosuit fishing rod. The exosuit holds it, so the line comes out of the exosuit.
/obj/item/fishing_rod/exosuit
	name = "exosuit fishing rod"
	line = /obj/item/fishing_line/exosuit
	hook = /obj/item/fishing_hook/barbed
	reel_speed = 2
	strain_mult = 0.6

/// The exosuit this rod is mounted on, if it is
/obj/item/fishing_rod/exosuit/proc/get_chassis()
	var/obj/item/mecha_parts/mecha_equipment/fishing_rod/mount = loc
	return istype(mount) ? mount.chassis : null

/obj/item/fishing_rod/exosuit/angler_body(mob/living/user)
	return get_chassis() || user

/obj/item/fishing_rod/exosuit/can_keep_fishing(mob/living/user)
	var/obj/mecha/chassis = get_chassis()
	return !QDELETED(chassis) && chassis.occupant == user && user.stat == CONSCIOUS

// Out from the exosuit's arm, on the side it's facing
/obj/item/fishing_rod/exosuit/tip_offset(atom/movable/body)
	switch(body.dir)
		if(NORTH)
			return list(27.5, 30.5)
		if(EAST)
			return list(31.5, 25.5)
		if(WEST)
			return list(0.5, 25.5)
	return list(4.5, 26.5)

/obj/item/fishing_rod/exosuit/receive_catch(atom/movable/landed, mob/living/user)
	var/obj/mecha/working/ripley/ripley = get_chassis()
	if(istype(ripley) && isobj(landed) && length(ripley.cargo) < ripley.cargo_capacity)
		landed.forceMove(ripley)
		ripley.cargo += landed
		to_chat(user, SPAN_NOTICE("[landed] goes into the cargo hold."))
		return
	// Not back into the lava it came out of
	var/turf/here = get_turf(landed)
	for(var/turf/T as anything in RANGE_TURFS(3, here))
		if(!islava(T) && !T.density && !ischasm(T))
			landed.forceMove(T)
			return

// The exosuit is in the way of a hands-only window
/obj/item/fishing_rod/exosuit/ui_state(mob/user)
	return GLOB.always_state

/// The line on an exosuit fishing rod
/obj/item/fishing_line/exosuit
	name = "braided steel fishing line"
	desc = "Thin steel cable, braided. It won't burn, and it's long and strong enough to haul things out of deep lava."
	icon_state = "line_steel"
	line_flags = FISHING_LINE_HEATPROOF | FISHING_LINE_LONG | FISHING_LINE_MAGMA
	cast_range = 7
	strength = 1.6
	line_color = "#c6ccd6"
