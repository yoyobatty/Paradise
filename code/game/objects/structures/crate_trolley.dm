/// How many crates fit on a trolley
#define CRATE_TROLLEY_CAPACITY 4
/// How far up the sprite the bottom crate sits
#define CRATE_TROLLEY_BASE_Y 6
/// How much higher each crate sits than the one under it
#define CRATE_TROLLEY_STEP_Y 11
#define CRATE_TROLLEY_LOAD_TIME (1 SECONDS)
/// How much each crate aboard slows down whoever is pulling the trolley
#define CRATE_TROLLEY_SLOWDOWN_PER_CRATE 0.25
/// Chance per crate of height that whoever stands on top falls off, each step the trolley is pulled at a run
#define CRATE_TROLLEY_WOBBLE_CHANCE 5
/// Brute damage per crate of height when someone falls off the top
#define CRATE_TROLLEY_FALL_DAMAGE 5

/// A low flat cart for moving several crates at once. Built from metal sheets.
/obj/structure/crate_trolley
	name = "crate trolley"
	desc = "A low, flat cart for moving crates. Drag crates onto it to stack them up."
	icon = 'icons/obj/crate_trolley.dmi'
	icon_state = "trolley"
	density = TRUE
	max_integrity = 150
	climbable = TRUE
	buckle_lying = FALSE
	/// The crates aboard, bottom first
	var/list/crates = list()
	/// How many crates high the person standing on top is
	var/rider_height = 0
	/// Set while someone climbs down on purpose, so post_unbuckle_mob() doesn't make them fall
	var/climbing_down = FALSE

/obj/structure/crate_trolley/Initialize(mapload)
	. = ..()
	update_icon(UPDATE_OVERLAYS)

/obj/structure/crate_trolley/Destroy()
	// Whoever is on top falls before the crates come off
	unbuckle_all_mobs(force = TRUE)
	for(var/obj/structure/closet/crate/crate as anything in crates.Copy())
		crate.forceMove(drop_location())
	return ..()

/obj/structure/crate_trolley/deconstruct(disassembled = TRUE)
	if(!(flags & NODECONSTRUCT))
		new /obj/item/stack/sheet/metal(drop_location(), 5)
	qdel(src)

/obj/structure/crate_trolley/update_overlays()
	. = ..()
	for(var/i in 1 to length(crates))
		var/mutable_appearance/stacked = new(crates[i])
		stacked.layer = FLOAT_LAYER
		stacked.plane = FLOAT_PLANE
		stacked.pixel_x = 0
		stacked.pixel_y = CRATE_TROLLEY_BASE_Y + CRATE_TROLLEY_STEP_Y * (i - 1)
		. += stacked
	// Added last so the handle shows over the crates
	. += "handle"

/obj/structure/crate_trolley/examine(mob/user)
	. = ..()
	if(length(crates))
		var/list/names = list()
		for(var/obj/structure/closet/crate/crate as anything in crates)
			names += "\a [crate]"
		. += SPAN_NOTICE("It's carrying [english_list(names)].")
	else
		. += SPAN_NOTICE("It's empty.")
	. += SPAN_NOTICE("Drag a closed crate onto it to load it, it takes [CRATE_TROLLEY_CAPACITY]. The more it carries, the slower it is to pull.")
	. += SPAN_NOTICE("Click it to set the top crate down beside it, drag it onto a floor tile to put the top crate there, or <b>Alt-Click</b> it to unload everything.")
	. += SPAN_NOTICE("When it's empty, a wrench takes it apart.")

/obj/structure/crate_trolley/get_climb_text()
	return SPAN_NOTICE("You can <b>Click-Drag</b> yourself to [src] to climb up onto its crates. Pull it at a walk, or whoever is up there might fall off.")

/obj/structure/crate_trolley/MouseDrop_T(atom/dropping, mob/living/user, params)
	if(!istype(dropping, /obj/structure/closet/crate))
		return ..()
	try_load(dropping, user)
	return TRUE

/obj/structure/crate_trolley/proc/can_load(obj/structure/closet/crate/crate, mob/living/user, silent = FALSE)
	if(!isliving(user) || user.incapacitated() || HAS_TRAIT(user, TRAIT_HANDS_BLOCKED))
		return FALSE
	if(!user.Adjacent(src) || !user.Adjacent(crate) || !isturf(crate.loc) || crate.anchored)
		return FALSE
	if(has_buckled_mobs())
		if(!silent)
			to_chat(user, SPAN_WARNING("Someone is standing on the crates."))
		return FALSE
	if(length(crates) >= CRATE_TROLLEY_CAPACITY)
		if(!silent)
			to_chat(user, SPAN_WARNING("[src] can't take any more crates."))
		return FALSE
	if(crate.opened)
		if(!silent)
			to_chat(user, SPAN_WARNING("Close [crate] first."))
		return FALSE
	// Nobody gets carted around inside a crate
	for(var/mob/living/stowaway in crate.GetAllContents())
		if(!silent)
			to_chat(user, SPAN_WARNING("Something shifts inside [crate] as you lift it. You set it back down."))
		return FALSE
	return TRUE

/obj/structure/crate_trolley/proc/try_load(obj/structure/closet/crate/crate, mob/living/user)
	if(!can_load(crate, user))
		return FALSE
	user.visible_message(SPAN_NOTICE("[user] starts lifting [crate] onto [src]."), SPAN_NOTICE("You start lifting [crate] onto [src]..."))
	if(!do_after(user, CRATE_TROLLEY_LOAD_TIME, target = crate) || !can_load(crate, user))
		return FALSE
	crate.pulledby?.stop_pulling()
	// On the list first, so Entered() knows it's being loaded
	crates += crate
	crate.forceMove(src)
	user.visible_message(SPAN_NOTICE("[user] loads [crate] onto [src]."), SPAN_NOTICE("You load [crate] onto [src]."))
	load_changed()
	return TRUE

/obj/structure/crate_trolley/attack_hand(mob/living/user)
	if(..())
		return
	if(has_buckled_mobs())
		pull_down(buckled_mobs[1], user)
		return
	if(!length(crates))
		return
	var/turf/spot = free_spot_beside(user)
	if(!spot)
		to_chat(user, SPAN_WARNING("There's nowhere beside [src] to set a crate down."))
		return
	unload_top(user, spot)

/obj/structure/crate_trolley/MouseDrop(atom/over, src_location, over_location, src_control, over_control, params)
	var/mob/living/user = usr
	if(!isturf(over) || !length(crates) || !isliving(user) || user.incapacitated() || !user.Adjacent(src))
		return ..()
	if(has_buckled_mobs())
		to_chat(user, SPAN_WARNING("Someone is standing on the crates."))
		return
	var/turf/spot = over
	if(!Adjacent(spot) || !spot_is_free(spot))
		to_chat(user, SPAN_WARNING("You can't set a crate down there."))
		return
	unload_top(user, spot)

/obj/structure/crate_trolley/AltClick(mob/living/user)
	if(!length(crates) || !isliving(user) || !Adjacent(user) || user.incapacitated() || HAS_TRAIT(user, TRAIT_HANDS_BLOCKED))
		return ..()
	if(has_buckled_mobs())
		to_chat(user, SPAN_WARNING("Someone is standing on the crates."))
		return
	var/unloaded = 0
	while(length(crates))
		var/turf/spot = free_spot_beside(user)
		if(!spot)
			break
		unload_top(user, spot, silent = TRUE)
		unloaded++
	if(unloaded)
		user.visible_message(SPAN_NOTICE("[user] unloads [unloaded] crate\s from [src]."), SPAN_NOTICE("You unload [unloaded] crate\s from [src]."))
	if(length(crates))
		to_chat(user, SPAN_WARNING("There's no room beside [src] for the rest."))

/obj/structure/crate_trolley/proc/unload_top(mob/living/user, turf/spot, silent = FALSE)
	var/obj/structure/closet/crate/crate = crates[length(crates)]
	// Exited() takes it off the list
	crate.forceMove(spot)
	if(!silent)
		user.visible_message(SPAN_NOTICE("[user] sets [crate] down off [src]."), SPAN_NOTICE("You set [crate] down off [src]."))

/// Finds a tile next to the trolley to put a crate on: the far side from `near` first, then its sides, then the corners
/obj/structure/crate_trolley/proc/free_spot_beside(atom/near)
	var/away = get_dir(near, src) || SOUTH
	for(var/direction in list(away, turn(away, 90), turn(away, -90), turn(away, 45), turn(away, -45), turn(away, 135), turn(away, -135)))
		var/turf/spot = get_step(src, direction)
		if(spot && spot != get_turf(near) && Adjacent(spot) && spot_is_free(spot))
			return spot

/obj/structure/crate_trolley/proc/spot_is_free(turf/spot)
	return !spot.is_blocked_turf() && !(locate(/obj/structure/closet) in spot)

/obj/structure/crate_trolley/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	. = ..()
	if(arrived in crates)
		return
	// Something came out of a crate aboard, like someone breaking out of it. Crates drop their contents into
	// their loc, which is us, so tidy up once the crate has finished opening.
	addtimer(CALLBACK(src, PROC_REF(drop_spilled)), 0, TIMER_UNIQUE)

/// Puts opened crates, and whatever came out of them, on the floor beside the trolley
/obj/structure/crate_trolley/proc/drop_spilled()
	var/turf/spot = drop_location()
	for(var/obj/structure/closet/crate/crate as anything in crates.Copy())
		if(!crate.opened)
			continue
		spot = free_spot_beside(crate) || drop_location()
		crate.forceMove(spot)
	for(var/atom/movable/spilled in contents)
		if(!(spilled in crates))
			spilled.forceMove(spot)

/obj/structure/crate_trolley/Exited(atom/movable/gone, direction)
	. = ..()
	if(!(gone in crates))
		return
	crates -= gone
	if(!QDELETED(src))
		load_changed()

// A crate deleted while aboard, like one sold off the supply shuttle, never calls Exited()
/obj/structure/crate_trolley/handle_atom_del(atom/deleted)
	. = ..()
	if(!(deleted in crates))
		return
	crates -= deleted
	if(!QDELETED(src))
		load_changed()

/// Redraws the stack and sets how much the load slows down whoever is pulling
/obj/structure/crate_trolley/proc/load_changed()
	pull_slowdown = CRATE_TROLLEY_SLOWDOWN_PER_CRATE * length(crates)
	update_icon(UPDATE_OVERLAYS)
	// A crate came out from under whoever is standing on top
	if(has_buckled_mobs() && length(crates) != rider_height)
		unbuckle_mob(buckled_mobs[1], force = TRUE)

/obj/structure/crate_trolley/wrench_act(mob/living/user, obj/item/I)
	if(flags & NODECONSTRUCT)
		return
	. = TRUE
	if(length(crates))
		to_chat(user, SPAN_WARNING("Unload [src] first."))
		return
	to_chat(user, SPAN_NOTICE("You start taking [src] apart..."))
	if(!I.use_tool(src, user, 2 SECONDS, volume = I.tool_volume) || length(crates))
		return
	to_chat(user, SPAN_NOTICE("You take [src] apart."))
	deconstruct(TRUE)

// Standing on the crates. The person on top is buckled to the trolley, so they ride along when it's pulled.

/obj/structure/crate_trolley/start_climb(mob/living/user)
	if(!length(crates))
		to_chat(user, SPAN_WARNING("There's nothing on [src] to climb up onto."))
		return FALSE
	if(has_buckled_mobs())
		to_chat(user, SPAN_WARNING("Someone is already standing on the crates."))
		return FALSE
	climbers += user
	RegisterSignal(user, COMSIG_PARENT_QDELETING, PROC_REF(remove_climber))
	if(do_climb(user) && length(crates) && !has_buckled_mobs())
		// Straight onto our tile, since walking into a dense trolley would shove it away
		user.forceMove(loc)
		if(buckle_mob(user, force = TRUE, check_loc = FALSE))
			user.visible_message(SPAN_WARNING("[user] climbs up onto the crates on [src]!"), SPAN_NOTICE("You climb up onto the crates on [src]."))
	if(QDELETED(src))
		return
	climbers -= user
	UnregisterSignal(user, COMSIG_PARENT_QDELETING)
	return TRUE

/obj/structure/crate_trolley/post_buckle_mob(mob/living/M)
	rider_height = length(crates)
	// Feet on the lid of the top crate
	M.pixel_y = initial(M.pixel_y) + CRATE_TROLLEY_BASE_Y + CRATE_TROLLEY_STEP_Y * rider_height + 2
	RegisterSignal(M, list(SIGNAL_ADDTRAIT(TRAIT_FLOORED), COMSIG_MOB_STATCHANGE), PROC_REF(on_rider_knocked_down))

/obj/structure/crate_trolley/post_unbuckle_mob(mob/living/M)
	M.pixel_y = initial(M.pixel_y)
	UnregisterSignal(M, list(SIGNAL_ADDTRAIT(TRAIT_FLOORED), COMSIG_MOB_STATCHANGE))
	var/height = rider_height
	rider_height = 0
	if(!climbing_down && !QDELETED(M) && M.loc == loc)
		fall_off(M, height)

/// Knocked down or out while standing on top
/obj/structure/crate_trolley/proc/on_rider_knocked_down(mob/living/rider)
	SIGNAL_HANDLER // SIGNAL_ADDTRAIT(TRAIT_FLOORED), COMSIG_MOB_STATCHANGE
	if(rider.stat == CONSCIOUS && !HAS_TRAIT(rider, TRAIT_FLOORED))
		return
	INVOKE_ASYNC(src, TYPE_PROC_REF(/atom/movable, unbuckle_mob), rider, TRUE)

/obj/structure/crate_trolley/Move(atom/newloc, direct = 0, glide_size_override = 0, update_dir = TRUE, momentum_change = TRUE)
	. = ..()
	if(!. || !has_buckled_mobs())
		return
	// Pulling it at a walk keeps it steady
	var/mob/living/puller = pulledby
	if(istype(puller) && puller.m_intent == MOVE_INTENT_WALK)
		return
	if(!prob(CRATE_TROLLEY_WOBBLE_CHANCE * rider_height))
		return
	var/mob/living/rider = buckled_mobs[1]
	if(puller)
		add_attack_logs(puller, rider, "Made them fall off a crate trolley by pulling it at a run")
	unbuckle_mob(rider, force = TRUE)

/// Throws the person on top off the side of the stack. The higher they were, the more it hurts.
/obj/structure/crate_trolley/proc/fall_off(mob/living/rider, height)
	var/list/landings = list()
	for(var/turf/spot in orange(1, src))
		if(Adjacent(spot) && !spot.is_blocked_turf())
			landings += spot
	if(length(landings))
		rider.forceMove(pick(landings))
	rider.visible_message(SPAN_WARNING("[rider] falls off the crates on [src]!"), SPAN_USERDANGER("You fall off the crates on [src]!"))
	playsound(rider, "bodyfall", 50, TRUE)
	if(!height)
		return
	rider.KnockDown(height SECONDS)
	rider.apply_damage(CRATE_TROLLEY_FALL_DAMAGE * height, BRUTE, pick(BODY_ZONE_HEAD, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_PRECISE_L_HAND, BODY_ZONE_PRECISE_R_HAND, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG, BODY_ZONE_PRECISE_L_FOOT, BODY_ZONE_PRECISE_R_FOOT))

// Resisting or moving while on top climbs down instead of falling
/obj/structure/crate_trolley/user_unbuckle_mob(mob/living/buckled_mob, mob/user)
	if(buckled_mob != user)
		return ..()
	INVOKE_ASYNC(src, PROC_REF(climb_down), user)

/obj/structure/crate_trolley/relaymove(mob/living/user, direction)
	if(user.buckled == src)
		INVOKE_ASYNC(src, PROC_REF(climb_down), user, direction)

/// Climbs down off the crates on purpose, on the given side if there's room there
/obj/structure/crate_trolley/proc/climb_down(mob/living/user, direction)
	// Moving calls this every tick while the key is held
	if(DOING_INTERACTION(user, src))
		return
	var/turf/landing = direction ? get_step(src, direction) : null
	if(!landing || !Adjacent(landing) || landing.is_blocked_turf())
		landing = free_spot_beside(user)
	if(!landing)
		to_chat(user, SPAN_WARNING("There's nowhere to climb down to."))
		return
	user.visible_message(SPAN_NOTICE("[user] starts climbing down from [src]."), SPAN_NOTICE("You start climbing down from [src]..."))
	if(!do_after(user, 2 SECONDS, target = src, interaction_key = src) || user.buckled != src)
		return
	if(!Adjacent(landing) || landing.is_blocked_turf())
		to_chat(user, SPAN_WARNING("Something is in the way."))
		return
	climbing_down = TRUE
	unbuckle_mob(user, force = TRUE)
	climbing_down = FALSE
	user.forceMove(landing)
	user.visible_message(SPAN_NOTICE("[user] climbs down from [src]."), SPAN_NOTICE("You climb down from [src]."))

/// Someone pulls the person on top down off the crates. They fall.
/obj/structure/crate_trolley/proc/pull_down(mob/living/rider, mob/living/user)
	if(rider == user)
		climb_down(user)
		return
	user.visible_message(SPAN_WARNING("[user] starts pulling [rider] down off [src]!"), SPAN_WARNING("You start pulling [rider] down off [src]..."))
	if(!do_after(user, 1 SECONDS, target = rider) || rider.buckled != src)
		return
	add_attack_logs(user, rider, "Pulled them off a crate trolley")
	unbuckle_mob(rider, force = TRUE)

#undef CRATE_TROLLEY_CAPACITY
#undef CRATE_TROLLEY_BASE_Y
#undef CRATE_TROLLEY_STEP_Y
#undef CRATE_TROLLEY_LOAD_TIME
#undef CRATE_TROLLEY_SLOWDOWN_PER_CRATE
#undef CRATE_TROLLEY_WOBBLE_CHANCE
#undef CRATE_TROLLEY_FALL_DAMAGE
