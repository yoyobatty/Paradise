// MARK: Lava golem

/// How long a lava golem can stay out of the lava before it has to go back in
#define LAVA_GOLEM_LAND_TIME (12 SECONDS)
/// How many cooling steps it goes through out of the lava before it has to go back
#define LAVA_GOLEM_COOL_STEPS 6
/// How many times faster it heats back up in the lava than it cools on land
#define LAVA_GOLEM_REHEAT 3
/// How long past LAVA_GOLEM_LAND_TIME it lasts if it can't get back, before it starts cracking apart
#define LAVA_GOLEM_SET_TIME (10 SECONDS)
/// How far it looks for lava to go back to
#define LAVA_GOLEM_HOME_RANGE 8
/// Blackboard key: the lava it's going back to
#define BB_LAVA_GOLEM_HOME "BB_lava_golem_home"

/**
 * Rock golem that lives in lava. It comes out to fight, cools on land and has to go back in to heat up again.
 *
 * Its glow is two copies of its sprite in vis_contents (emissive and bloom), so every flick is done on all three.
 */
/mob/living/basic/mining/lava_golem
	name = "lava golem"
	desc = "A hulking thing of black rock held together by the molten lava in its cracks. It lives in the lava and wades out after whatever disturbs it, but it can't stay out for long before it starts to set."
	icon = 'icons/mob/lava_golem.dmi'
	icon_state = "golem_wade"
	icon_living = "golem_wade"
	icon_dead = "golem_dead"
	pixel_x = -16
	pixel_y = -8
	maxHealth = 150
	health = 150
	speed = 2
	melee_damage_lower = 12
	melee_damage_upper = 18
	melee_damage_type = BURN
	obj_damage = 40
	attack_verb_continuous = "pounds"
	attack_verb_simple = "pound"
	attack_sound = 'sound/weapons/punch4.ogg'
	death_message = "cracks apart into a heap of cooling rock."
	death_sound = 'sound/effects/break_stone.ogg'
	blocks_emissive = EMISSIVE_BLOCK_UNIQUE
	butcher_results = list(
		/obj/item/stack/ore/glass/basalt = 6,
		/obj/item/stack/ore/gold = 3,
	)
	ai_controller = /datum/ai_controller/basic_controller/lava_golem
	/// Is it standing in lava right now?
	var/in_lava = FALSE
	/// How far it has cooled out of the lava, 0 to LAVA_GOLEM_COOL_STEPS
	var/cooled = 0
	/// Cooling step its look currently shows
	var/shown_cool_step = -1
	/// When it last came out of the lava
	var/left_lava_at = 0
	/// Has it cooled too much and is heading back to the lava? Stays set until it's heated up again
	var/must_go_back = FALSE
	/// Has it started cracking apart from being out too long?
	var/cracking = FALSE
	/// Emissive copy of its molten parts, so the lighting doesn't darken them
	var/obj/effect/abstract/lava_golem_glow/emissive_copy
	/// Copy of its molten parts on the lava glow plane, for the bloom
	var/obj/effect/abstract/lava_golem_glow/bloom/bloom_copy

/mob/living/basic/mining/lava_golem/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/ai_retaliate)
	emissive_copy = new
	bloom_copy = new
	vis_contents += list(emissive_copy, bloom_copy)
	in_lava = islava(loc)
	if(in_lava)
		// flick() is lost on a new atom, so play the emerge state once and switch to wading after
		show_look("golem_emerge")
		addtimer(CALLBACK(src, PROC_REF(finish_emerging)), 1 SECONDS)
		playsound(src, 'sound/effects/bubbles2.ogg', 60, TRUE)
	else
		// Hauled out onto land, so it starts cooling right away
		show_look("golem")
		left_lava_at = world.time
		START_PROCESSING(SSprocessing, src)
	update_heat()

/mob/living/basic/mining/lava_golem/Destroy()
	STOP_PROCESSING(SSprocessing, src)
	vis_contents.Cut()
	QDEL_NULL(emissive_copy)
	QDEL_NULL(bloom_copy)
	return ..()

/mob/living/basic/mining/lava_golem/proc/finish_emerging()
	if(stat != DEAD && icon_state == "golem_emerge")
		show_look(in_lava ? "golem_wade" : "golem")

/// Sets its icon state and its glow copies', flicking `once` first if given
/mob/living/basic/mining/lava_golem/proc/show_look(look, once)
	icon_state = look
	icon_living = look
	emissive_copy.icon_state = look
	bloom_copy.icon_state = look
	if(once)
		flick(once, src)
		flick(once, emissive_copy)
		flick(once, bloom_copy)

// Can't leave the lava again until it has heated back up
/mob/living/basic/mining/lava_golem/Move(atom/newloc, direct = 0, glide_size_override = 0, update_dir = TRUE)
	if(in_lava && cooled > 0 && !client && isturf(newloc) && !islava(newloc))
		return FALSE
	return ..()

/mob/living/basic/mining/lava_golem/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	. = ..()
	if(stat == DEAD || QDELETED(src) || !isturf(loc))
		return
	var/was_in_lava = in_lava
	in_lava = islava(loc)
	if(in_lava && !was_in_lava)
		show_look("golem_wade", "golem_sink")
		new /obj/effect/temp_visual/lava_disturb/wade_in(loc)
		playsound(src, 'sound/effects/footstep/lava1.ogg', 50, TRUE)
	else if(!in_lava && was_in_lava)
		show_look("golem", "golem_rise")
		if(islava(old_loc))
			new /obj/effect/temp_visual/lava_disturb(old_loc)
		// Lava it drags out spills onto the floor
		new /obj/effect/decal/cleanable/lava_ember/spill(loc, 3, movement_dir)
		playsound(src, 'sound/effects/fire_sizzle.ogg', 40, TRUE)
		left_lava_at = world.time
		START_PROCESSING(SSprocessing, src)
	else if(!in_lava)
		flick("golem_walk", src)
		flick("golem_walk", emissive_copy)
		flick("golem_walk", bloom_copy)
		// Drips where it walked, less the more it has cooled
		if(isturf(old_loc) && !islava(old_loc) && prob(100 - 70 * cooled / LAVA_GOLEM_COOL_STEPS))
			new /obj/effect/decal/cleanable/lava_ember(old_loc, drip_heat())

/// Heat of its drips, 3 fresh out of the lava down to 1 nearly cooled
/mob/living/basic/mining/lava_golem/proc/drip_heat()
	return clamp(3 - round(cooled * 3 / LAVA_GOLEM_COOL_STEPS), 1, 3)

/mob/living/basic/mining/lava_golem/process()
	if(stat == DEAD)
		return PROCESS_KILL
	// SSprocessing passes its wait in deciseconds, not seconds
	var/seconds_per_tick = SSprocessing.wait / (1 SECONDS)
	var/step_per_second = LAVA_GOLEM_COOL_STEPS / (LAVA_GOLEM_LAND_TIME / (1 SECONDS))
	if(in_lava)
		cooled = max(0, cooled - step_per_second * LAVA_GOLEM_REHEAT * seconds_per_tick)
		if(!cooled)
			must_go_back = FALSE
			cracking = FALSE
			update_heat()
			return PROCESS_KILL
	else
		cooled = min(LAVA_GOLEM_COOL_STEPS, cooled + step_per_second * seconds_per_tick)
		if(cooled >= LAVA_GOLEM_COOL_STEPS)
			must_go_back = TRUE
		// Drips while standing still too
		if(SPT_PROB(30 * (1 - cooled / LAVA_GOLEM_COOL_STEPS), seconds_per_tick) && isturf(loc))
			new /obj/effect/decal/cleanable/lava_ember(loc, drip_heat())
		// Couldn't get back in time, so it cracks apart
		if(world.time - left_lava_at > LAVA_GOLEM_LAND_TIME + LAVA_GOLEM_SET_TIME)
			if(!cracking)
				cracking = TRUE
				visible_message(SPAN_WARNING("[src] stiffens as the lava in it sets, and its crust starts to crack!"))
			adjustBruteLoss(12 * seconds_per_tick)
	update_heat()

/// Dims its molten parts and glow to match how cooled it is
/mob/living/basic/mining/lava_golem/proc/update_heat()
	var/step = round(cooled)
	if(step == shown_cool_step || stat == DEAD)
		return
	shown_cool_step = step
	var/heat = 1 - step / LAVA_GOLEM_COOL_STEPS
	// Shifts molten orange towards dull red, grey rock barely changes
	if(step)
		var/k = 0.8 * (1 - heat)
		var/k2 = 0.7 * (1 - heat)
		var/dim = 1 - 0.25 * (1 - heat)
		color = list((1 - k) * dim, 0, 0, k * dim, (1 - k2) * dim, 0, 0, k2 * dim, dim, 0, 0, 0)
	else
		color = null
	var/glow = 0.3 + 0.7 * heat
	emissive_copy.set_strength(glow)
	bloom_copy.set_strength(glow)
	set_light(2 + glow, 0.5 + 0.7 * glow, LIGHT_COLOR_LAVA)

/mob/living/basic/mining/lava_golem/death(gibbed)
	. = ..()
	if(!.)
		return
	STOP_PROCESSING(SSprocessing, src)
	color = null
	emissive_copy.icon_state = icon_dead
	bloom_copy.icon_state = icon_dead
	emissive_copy.set_strength(0.6)
	bloom_copy.set_strength(0.6)
	set_light(2, 0.6, LIGHT_COLOR_LAVA)
	// The heap stops glowing after a while
	addtimer(CALLBACK(src, PROC_REF(cool_heap)), 20 SECONDS)

/mob/living/basic/mining/lava_golem/proc/cool_heap()
	if(stat != DEAD)
		return
	emissive_copy.set_strength(0)
	bloom_copy.set_strength(0)
	set_light(0)

/mob/living/basic/mining/lava_golem/revive()
	. = ..()
	shown_cool_step = -1
	show_look(in_lava ? "golem_wade" : "golem")
	update_heat()

/// Returns the closest lava turf it can walk into, or null
/mob/living/basic/mining/lava_golem/proc/nearest_lava()
	var/best_dist = INFINITY
	for(var/turf/T as anything in RANGE_TURFS(LAVA_GOLEM_HOME_RANGE, src))
		if(!islava(T) || T.is_blocked_turf())
			continue
		var/dist = get_dist(src, T)
		if(dist < best_dist)
			best_dist = dist
			. = T

/// Copy of a lava golem's sprite showing only the molten pixels, picked out by colour. White, on the emissive plane
/obj/effect/abstract/lava_golem_glow
	icon = 'icons/mob/lava_golem.dmi'
	icon_state = "golem_wade"
	plane = EMISSIVE_PLANE
	appearance_flags = KEEP_APART | RESET_COLOR | PIXEL_SCALE
	vis_flags = VIS_INHERIT_DIR | VIS_INHERIT_ID
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/// Sets how strongly it glows, 0 to 1. Goes in the colour matrix, since alpha is ignored while color is a matrix
/obj/effect/abstract/lava_golem_glow/proc/set_strength(strength)
	color = lava_golem_glow_matrix(strength, TRUE)

/// Same copy in the golem's own colours, on the lava glow plane for the bloom
/obj/effect/abstract/lava_golem_glow/bloom
	plane = LAVA_GLOW_PLANE

/obj/effect/abstract/lava_golem_glow/bloom/set_strength(strength)
	color = lava_golem_glow_matrix(strength, FALSE)

/// Colour matrix that keeps only the molten pixels: alpha is 3 * (red - blue) - 0.4
/proc/lava_golem_glow_matrix(strength, white)
	var/a = 3 * strength
	if(white)
		return list(0, 0, 0, a, 0, 0, 0, 0, 0, 0, 0, -a, 0, 0, 0, 0, 1, 1, 1, -0.4 * strength)
	return list(1, 0, 0, a, 0, 1, 0, 0, 0, 0, 1, -a, 0, 0, 0, 0, 0, 0, 0, -0.4 * strength)

/// Emissive overlay of a sprite's molten pixels, for the golem's drips and lava splashes
/proc/lava_golem_emissive(icon, icon_state, strength)
	var/mutable_appearance/glow = mutable_appearance(icon, icon_state, plane = EMISSIVE_PLANE, appearance_flags = KEEP_APART | RESET_COLOR)
	glow.color = lava_golem_glow_matrix(strength, TRUE)
	return glow

/datum/ai_controller/basic_controller/lava_golem
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
	)
	ai_movement = /datum/ai_movement/basic_avoidance
	idle_behavior = /datum/idle_behavior/idle_random_walk/lava_golem
	interesting_dist = AI_SIMPLE_INTERESTING_DIST
	planning_subtrees = list(
		/datum/ai_planning_subtree/lava_golem_go_back,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/attack_obstacle_in_path,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
		/datum/ai_planning_subtree/lava_golem_go_back/nothing_to_fight,
	)

/// Goes back to the lava once it has cooled too much
/datum/ai_planning_subtree/lava_golem_go_back

/datum/ai_planning_subtree/lava_golem_go_back/select_behaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/mining/lava_golem/golem = controller.pawn
	if(!istype(golem) || golem.in_lava || !should_go_back(golem, controller))
		return
	var/turf/home = controller.blackboard[BB_LAVA_GOLEM_HOME]
	if(!islava(home) || home.is_blocked_turf())
		home = golem.nearest_lava()
		if(!home)
			return
		controller.set_blackboard_key(BB_LAVA_GOLEM_HOME, home)
	controller.queue_behavior(/datum/ai_behavior/travel_towards/stop_on_arrival, BB_LAVA_GOLEM_HOME)
	return SUBTREE_RETURN_FINISH_PLANNING

/datum/ai_planning_subtree/lava_golem_go_back/proc/should_go_back(mob/living/basic/mining/lava_golem/golem, datum/ai_controller/controller)
	return golem.must_go_back

/// Also goes back when it has nothing left to fight
/datum/ai_planning_subtree/lava_golem_go_back/nothing_to_fight

/datum/ai_planning_subtree/lava_golem_go_back/nothing_to_fight/should_go_back(mob/living/basic/mining/lava_golem/golem, datum/ai_controller/controller)
	return !controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]

/// Only wanders around inside the lava
/datum/idle_behavior/idle_random_walk/lava_golem
	walk_chance = 15

/datum/idle_behavior/idle_random_walk/lava_golem/perform_idle_behavior(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/basic/mining/lava_golem/golem = controller.pawn
	if(!istype(golem) || !golem.in_lava)
		return ..()
	if(!SPT_PROB(walk_chance, seconds_per_tick) || !(golem.mobility_flags & MOBILITY_MOVE) || golem.pulledby)
		return TRUE
	var/move_dir = pick(GLOB.alldirs)
	var/turf/destination = get_step(golem, move_dir)
	if(islava(destination))
		golem.Move(destination, move_dir)
	return TRUE

/datum/fishing_catch/creature/lava_golem
	name = "lava golem"
	catch_type = /mob/living/basic/mining/lava_golem
	strength = 50
	stamina = 20
	bait_likes = list(FISHING_BAIT_MEAT = 3)
	rare = TRUE

/// How long a lava golem drip takes to cool one step
#define LAVA_EMBER_COOL_STEP (6 SECONDS)

/// Molten rock dripped by a lava golem, cools to a black crust. A new drip on the same tile heats the old one back up
/obj/effect/decal/cleanable/lava_ember
	name = "molten rock"
	desc = "A splash of molten rock, glowing as it cools into a black crust."
	icon = 'icons/effects/lava_embers.dmi'
	icon_state = "ember0-3"
	base_icon_state = "ember"
	/// 3 is molten, 0 is a cold crust
	var/heat = 3
	/// Which splash shape it uses
	var/shape = 0
	/// Emissive glow while it's hot
	var/mutable_appearance/glow
	/// Timer for the next cooling step
	var/cool_timer
	/// Time per cooling step
	var/cool_step = LAVA_EMBER_COOL_STEP

/obj/effect/decal/cleanable/lava_ember/Initialize(mapload, new_heat = 3)
	heat = new_heat
	. = ..()
	if(. == INITIALIZE_HINT_QDEL)
		return
	place()
	set_heat(heat)

/// Picks its shape and offset on the tile
/obj/effect/decal/cleanable/lava_ember/proc/place()
	shape = rand(0, 2)
	pixel_x = rand(-6, 6)
	pixel_y = rand(-5, 5)

/obj/effect/decal/cleanable/lava_ember/Destroy()
	deltimer(cool_timer)
	return ..()

/obj/effect/decal/cleanable/lava_ember/replace_decal(obj/effect/decal/cleanable/lava_ember/old)
	if(heat > old.heat)
		old.set_heat(heat)
	return TRUE

/obj/effect/decal/cleanable/lava_ember/proc/set_heat(new_heat)
	heat = new_heat
	icon_state = "[base_icon_state][shape]-[heat]"
	if(glow)
		cut_overlay(glow)
		glow = null
	deltimer(cool_timer)
	cool_timer = null
	if(!heat)
		name = "cooled rock"
		desc = "A splash of molten rock that has cooled into a black crust."
		set_light(0)
		return
	name = initial(name)
	desc = initial(desc)
	glow = lava_golem_emissive(icon, icon_state, 0.5 + heat / 6)
	glow.dir = dir
	add_overlay(glow)
	if(heat >= 2)
		set_light(1, heat == 3 ? 0.9 : 0.5, LIGHT_COLOR_LAVA)
	else
		set_light(0)
	cool_timer = addtimer(CALLBACK(src, PROC_REF(set_heat), heat - 1), cool_step, TIMER_STOPPABLE)

/// Lava a golem drags onto the floor climbing out. Faces the way it went, cools slower than a drip
/obj/effect/decal/cleanable/lava_ember/spill
	name = "spilled lava"
	desc = "Lava dragged out onto the floor, glowing as it cools into a black crust."
	icon_state = "spill0-3"
	base_icon_state = "spill"
	cool_step = 9 SECONDS

/obj/effect/decal/cleanable/lava_ember/spill/Initialize(mapload, new_heat = 3, spill_dir = SOUTH)
	dir = spill_dir
	return ..()

/obj/effect/decal/cleanable/lava_ember/spill/place()
	shape = rand(0, 1)

/// Disturbed lava where a golem climbs out: a bright hole slowly closing over, globs falling back, a puff of smoke
/obj/effect/temp_visual/lava_disturb
	name = "lava"
	icon = 'icons/mob/lava_golem.dmi'
	icon_state = "lava_out"
	duration = 1.6 SECONDS
	randomdir = FALSE
	pixel_x = -16
	pixel_y = -8
	plane = FLOOR_PLANE
	layer = ABOVE_NORMAL_TURF_LAYER

/// Where a golem wades in: globs thrown up and a heap of lava that settles
/obj/effect/temp_visual/lava_disturb/wade_in
	icon_state = "lava_in"
	duration = 1.4 SECONDS

/obj/effect/temp_visual/lava_disturb/Initialize(mapload)
	. = ..()
	add_overlay(lava_golem_emissive(icon, icon_state, 1))

// MARK: Lava leviathan

/// The biggest thing in the lava, and only out in the deep.
/obj/item/fish/wild/lava_leviathan
	name = "lava leviathan"
	desc = "A huge armoured fish from deep in the lava, plated like cooled rock with fire showing through the seams. It's still hot enough to cook on."
	icon = 'icons/obj/fishing.dmi'
	icon_state = "lava_leviathan"
	w_class = WEIGHT_CLASS_HUGE
	force = 12
	fillet_type = /obj/item/food/magma_fillet
	fillet_amount = 6

/obj/item/fish/wild/lava_leviathan/Initialize(mapload)
	. = ..()
	set_light(3, 1.5, "#FF7B2E")

/datum/fishing_catch/lava_leviathan
	name = "lava leviathan"
	catch_type = /obj/item/fish/wild/lava_leviathan
	min_length = 150
	max_length = 420
	strength = 58
	stamina = 26
	run_time = 3
	bait_likes = list(FISHING_BAIT_MEAT = 2, FISHING_BAIT_LIVE = 3)
	rare = TRUE

// MARK: Deep lava treasure

/datum/fishing_catch/junk/gold_ore_lode
	name = "lump of gold ore"
	catch_type = /obj/item/stack/ore/gold
	amount = 8

/datum/fishing_catch/junk/diamond_cluster
	name = "cluster of diamonds"
	catch_type = /obj/item/stack/ore/diamond
	amount = 3
	rare = TRUE

/datum/fishing_catch/junk/bluespace_crystals
	name = "handful of bluespace crystals"
	catch_type = /obj/item/stack/ore/bluespace_crystal
	amount = 2
	rare = TRUE

/datum/fishing_catch/junk/ashdrake_hide
	name = "ash drake hide"
	catch_type = /obj/item/stack/sheet/animalhide/ashdrake
	amount = 2

/// A necropolis chest that sank into the lava long ago, still full
/datum/fishing_catch/junk/necropolis_chest
	name = "sunken necropolis chest"
	catch_type = /obj/structure/closet/crate/necropolis/tendril
	rare = TRUE

#undef LAVA_GOLEM_LAND_TIME
#undef LAVA_GOLEM_COOL_STEPS
#undef LAVA_GOLEM_REHEAT
#undef LAVA_GOLEM_SET_TIME
#undef LAVA_GOLEM_HOME_RANGE
#undef BB_LAVA_GOLEM_HOME
#undef LAVA_EMBER_COOL_STEP
