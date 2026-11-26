/// The float on the end of a cast line. It only shows where the hook is, clicks go through it to the water.
/obj/effect/abstract/fishing_bobber
	name = "bobber"
	desc = "A little float on the end of somebody's fishing line."
	icon = 'icons/obj/fishing.dmi'
	icon_state = "bobber"
	invisibility = 0
	layer = ABOVE_ALL_MOB_LAYER
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/// One cast of a fishing rod: the wait for a bite, the pull, and the fight to reel the catch in.
/datum/fishing_session
	/// The rod that was cast
	var/obj/item/fishing_rod/rod
	/// The angler
	var/mob/living/user
	/// The turf or object being fished in
	var/atom/target
	/// The kind of spot the target is
	var/datum/fishing_spot/spot
	/// The float sitting on the target
	var/obj/effect/abstract/fishing_bobber/bobber
	/// The line drawn from the angler to the bobber
	var/datum/beam/line_beam
	/// How far along the cast is, one of the FISHING_ stages
	var/state = FISHING_WAITING
	/// Timer for the next nibble or bite, or for the bite being missed
	var/next_timer
	/// How many more times the bobber twitches before something really bites
	var/nibbles_left = 0
	/// How long to wait between those twitches
	var/nibble_wait = 0

	/// What is on the hook, once something is
	var/datum/fishing_catch/hooked
	/// How long the catch is, in cm
	var/length_cm = 0
	/// How hard this one pulls, its kind's strength scaled by its size
	var/fight_strength = 0
	/// Seconds of running it has left before it's worn out
	var/stamina_left = 0
	/// What the fish is doing, one of the FISHING_FISH_ states
	var/fish_state = FISHING_FISH_RESTING
	/// Seconds until the fish does something else
	var/fish_state_time = 0
	/// Strain on the line. It snaps at FISHING_MAX_TENSION
	var/tension = 0
	/// How much line is still out, in tiles. The catch is landed at 0
	var/distance = 0
	/// The catch gets away if this much line is out
	var/max_distance = 0
	/// Is the angler winding the reel?
	var/reeling = FALSE

/datum/fishing_session/New(obj/item/fishing_rod/cast_rod, mob/living/angler, atom/cast_target, datum/fishing_spot/cast_spot)
	rod = cast_rod
	user = angler
	target = cast_target
	spot = cast_spot
	bobber = new(get_turf(target))
	line_beam = user.Beam(bobber, "fishing_line", 'icons/obj/fishing.dmi', INFINITY, INFINITY, /obj/effect/ebeam, rod.line.line_color)

	RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(on_user_moved))
	RegisterSignal(bobber, COMSIG_PARENT_QDELETING, PROC_REF(on_spot_gone))
	if(isturf(target))
		RegisterSignal(target, COMSIG_TURF_CHANGE, PROC_REF(on_spot_gone))
	else
		RegisterSignal(target, COMSIG_PARENT_QDELETING, PROC_REF(on_spot_gone))

	user.visible_message(SPAN_NOTICE("[user] casts [user.p_their()] line into [spot.name]."), SPAN_NOTICE("You cast your line into [spot.name]."))
	if(spot.splash_sound)
		playsound(bobber, spot.splash_sound, 40, TRUE)
	splash()
	wait_for_bite()

/// Sends a ripple out from the bobber, if it's floating on water
/datum/fishing_session/proc/splash()
	var/turf/bobber_turf = get_turf(bobber)
	if(is_reflective_water(bobber_turf))
		new /obj/effect/temp_visual/water_ripple(bobber_turf)

/// The bobber's icon state for a stage of the cast, floating or hanging depending on the spot
/datum/fishing_session/proc/bobber_state(stage)
	return spot.has_surface ? "bobber[stage]" : "bobber[stage]_dry"

/datum/fishing_session/Destroy()
	STOP_PROCESSING(SSfastprocess, src)
	deltimer(next_timer)
	if(rod)
		rod.session = null
		SStgui.close_uis(rod)
	if(bobber)
		UnregisterSignal(bobber, COMSIG_PARENT_QDELETING)
		QDEL_NULL(bobber)
	QDEL_NULL(line_beam)
	rod = null
	user = null
	target = null
	spot = null
	hooked = null
	return ..()

/// Can the angler still fish? They have to be up and holding the rod.
/datum/fishing_session/proc/angler_ready()
	return !QDELETED(user) && !user.incapacitated() && user.is_holding(rod)

/datum/fishing_session/proc/on_user_moved(datum/source)
	SIGNAL_HANDLER // COMSIG_MOVABLE_MOVED
	// A couple of tiles of slack past the cast range, then the hook comes out
	if(user.z == bobber.z && get_dist(user, bobber) <= rod.line.cast_range + 2)
		return
	to_chat(user, SPAN_WARNING("Your line pulls tight and the hook comes loose."))
	qdel(src)

/datum/fishing_session/proc/on_spot_gone(datum/source)
	SIGNAL_HANDLER // COMSIG_TURF_CHANGE, COMSIG_PARENT_QDELETING
	if(!QDELETED(user))
		to_chat(user, SPAN_WARNING("Your line goes slack."))
	qdel(src)

/// The rod left the angler's hands
/datum/fishing_session/proc/give_up(mob/living/quitter)
	if(state == FISHING_FIGHT)
		to_chat(quitter, SPAN_WARNING("You let go of [rod] and whatever was on the line gets away."))
	qdel(src)

// MARK: Waiting and the bite

/datum/fishing_session/proc/wait_for_bite()
	deltimer(next_timer)
	state = FISHING_WAITING
	bobber.icon_state = bobber_state("")
	var/wait = rand(spot.bite_wait_min, spot.bite_wait_max)
	if(rod.get_bait_kind())
		wait *= FISHING_BAIT_WAIT_MULT
	// The wait is split up by a few twitches of the bobber that aren't bites
	nibbles_left = rand(0, 2)
	nibble_wait = wait / (nibbles_left + 1)
	next_timer = addtimer(CALLBACK(src, PROC_REF(nibble_or_bite)), nibble_wait, TIMER_STOPPABLE)

/datum/fishing_session/proc/nibble_or_bite()
	if(!angler_ready())
		qdel(src)
		return
	if(nibbles_left > 0)
		nibbles_left--
		flick(bobber_state("_nibble"), bobber)
		next_timer = addtimer(CALLBACK(src, PROC_REF(nibble_or_bite)), nibble_wait, TIMER_STOPPABLE)
		return
	bite()

/datum/fishing_session/proc/bite()
	deltimer(next_timer)
	state = FISHING_BITE
	bobber.icon_state = bobber_state("_bite")
	playsound(bobber, spot.splash_sound || 'sound/effects/pop.ogg', 60, TRUE)
	splash()
	to_chat(user, SPAN_BOLDNOTICE("Something takes the hook! Pull!"))
	next_timer = addtimer(CALLBACK(src, PROC_REF(miss_bite)), rod.hook.bite_window, TIMER_STOPPABLE)

/// The angler didn't pull in time
/datum/fishing_session/proc/miss_bite()
	if(state != FISHING_BITE)
		return
	if(!angler_ready())
		qdel(src)
		return
	if(rod.bait && prob(50))
		to_chat(user, SPAN_WARNING("Too slow! Whatever it was, it took [rod.bait] with it."))
		QDEL_NULL(rod.bait)
	else
		to_chat(user, SPAN_WARNING("Too slow! Whatever it was, it's gone."))
	wait_for_bite()

/// The angler used the rod while the line is out. What that does depends on how far along the cast is.
/datum/fishing_session/proc/pull(mob/living/puller)
	if(puller != user)
		return
	switch(state)
		if(FISHING_WAITING)
			to_chat(user, SPAN_NOTICE("You reel your line back in."))
			qdel(src)
		if(FISHING_BITE)
			hook_catch()
		if(FISHING_FIGHT)
			// For anglers without the reel window open
			reeling = !reeling
			to_chat(user, SPAN_NOTICE("You [reeling ? "start winding the reel" : "let go of the reel"]."))

/datum/fishing_session/proc/hook_catch()
	hooked = spot.pick_catch(target, rod.get_bait_kind())
	if(!hooked)
		to_chat(user, SPAN_WARNING("The hook comes back empty."))
		qdel(src)
		return
	length_cm = hooked.roll_length()
	if(!hooked.fights)
		land()
		return
	// Whatever fights for it has swallowed the bait
	if(rod.bait)
		QDEL_NULL(rod.bait)
	start_fight()

// MARK: The fight

/datum/fishing_session/proc/start_fight()
	deltimer(next_timer)
	state = FISHING_FIGHT
	var/size = hooked.size_factor(length_cm)
	fight_strength = hooked.strength * size
	stamina_left = hooked.stamina * size
	distance = max(get_dist(user, bobber), 2) + 1
	max_distance = distance + FISHING_SPARE_LINE * rod.hook.spare_line_mult
	tension = 0
	reeling = FALSE
	// It bolts as soon as it feels the hook
	set_fish_state(FISHING_FISH_TENSING)
	to_chat(user, SPAN_NOTICE("You hook something! There's [hooked.pull_hint(fight_strength)] on the line."))
	START_PROCESSING(SSfastprocess, src)
	rod.ui_interact(user)

/datum/fishing_session/proc/set_fish_state(new_state)
	fish_state = new_state
	switch(fish_state)
		if(FISHING_FISH_RESTING)
			fish_state_time = hooked.rest_time * rand(70, 130) / 100
		if(FISHING_FISH_TENSING)
			fish_state_time = FISHING_TENSING_TIME
		if(FISHING_FISH_RUNNING)
			fish_state_time = hooked.run_time * rand(70, 130) / 100
		if(FISHING_FISH_WORN_OUT)
			fish_state_time = INFINITY
	if(fish_state == FISHING_FISH_RUNNING)
		splash()
	bobber.icon_state = bobber_state(fish_state == FISHING_FISH_RUNNING ? "_run" : "_fight")

/// Moves the fish on to what it does next: rest, a short warning, run, rest again
/datum/fishing_session/proc/next_fish_state()
	switch(fish_state)
		if(FISHING_FISH_RESTING)
			set_fish_state(FISHING_FISH_TENSING)
		if(FISHING_FISH_TENSING)
			set_fish_state(FISHING_FISH_RUNNING)
		if(FISHING_FISH_RUNNING)
			set_fish_state(FISHING_FISH_RESTING)

/datum/fishing_session/process(wait)
	if(state != FISHING_FIGHT)
		return PROCESS_KILL
	if(!angler_ready())
		give_up(user)
		return PROCESS_KILL
	var/seconds = wait * 0.1

	fish_state_time -= seconds
	if(fish_state_time <= 0)
		next_fish_state()
	var/running = (fish_state == FISHING_FISH_RUNNING)
	if(running)
		// Holding on while it runs wears it out faster
		stamina_left -= seconds * (reeling ? FISHING_TIRING_BONUS : 1)
		if(stamina_left <= 0)
			set_fish_state(FISHING_FISH_WORN_OUT)
			running = FALSE
			to_chat(user, SPAN_NOTICE("The pull on the line goes weak. It's worn out!"))

	if(reeling)
		var/target_tension = FISHING_REEL_TENSION
		if(running)
			target_tension += fight_strength * FISHING_RUN_STRAIN
		target_tension *= rod.strain_mult / rod.line.strength
		if(tension < target_tension)
			tension = min(target_tension, tension + FISHING_TENSION_RISE * seconds)
		else
			tension = max(target_tension, tension - FISHING_TENSION_FALL * seconds)
		distance -= rod.reel_speed * (running ? FISHING_RUN_REEL_MULT : 1) * seconds
	else
		tension = max(0, tension - FISHING_TENSION_FALL * seconds)
		if(running)
			distance += (FISHING_RUN_SPEED + fight_strength * FISHING_RUN_SPEED_PER_STRENGTH) * seconds

	if(tension >= FISHING_MAX_TENSION)
		snap_line()
		return PROCESS_KILL
	if(distance >= max_distance)
		to_chat(user, SPAN_WARNING("It takes all the line it wants, shakes the hook out and is gone."))
		qdel(src)
		return PROCESS_KILL
	if(distance <= 0)
		land()
		return PROCESS_KILL
	SStgui.update_uis(rod)

/datum/fishing_session/proc/snap_line()
	user.visible_message(SPAN_WARNING("[user]'s fishing line snaps!"), SPAN_WARNING("The line snaps! [rod.hook] is gone, and so is whatever was on it."))
	playsound(user, 'sound/effects/snap.ogg', 50, TRUE)
	QDEL_NULL(rod.hook)
	qdel(src)

// MARK: Landing

/datum/fishing_session/proc/land()
	state = FISHING_DONE
	if(!spot.take_catch(target, hooked))
		to_chat(user, SPAN_WARNING("The hook comes back empty."))
		qdel(src)
		return
	var/landed_name = length_cm ? "a [length_cm] cm [hooked.name]" : "\a [hooked.name]"
	user.visible_message(SPAN_NOTICE("[user] reels in [landed_name]!"), SPAN_NOTICE("You reel in [landed_name]!"))
	playsound(user, 'sound/items/ratchet.ogg', 30, TRUE)
	if(length_cm && record_fishing_catch(user.real_name, hooked.name, length_cm, spot.name))
		user.visible_message(SPAN_BOLDNOTICE("That's the biggest [hooked.name] anyone has caught this shift!"))
	hooked.land(user, src)
	qdel(src)
