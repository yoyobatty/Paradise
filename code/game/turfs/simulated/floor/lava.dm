/// How many different heat hazes there are, so neighbouring tiles don't ripple in step
#define LAVA_HAZE_KINDS 4
/// How many tiles across a chunk of the map is, for finding lava near a player
#define LAVA_EFFECT_CHUNK 16

/**
 * Lava turf, burns things that are on it.
 * Currently a subtype of floor so that footsteps work on it.
 * Perhaps we could move it down to /turf/simulated/lava someday, as I dont think footsteps over lava are very important.
 */
/turf/simulated/floor/lava
	name = "lava"
	desc = "Extremely hot liquefied rock, exceptionally dangerous to anything without proper protection. It's very viscous and will slow down anything going through it."
	icon = 'icons/turf/floors/lava.dmi'
	icon_state = "lava-255"
	base_icon_state = "lava"
	gender = PLURAL //"That's some lava."
	baseturf = /turf/simulated/floor/lava //lava all the way down
	slowdown = 2
	light_range = 2
	light_power = 0.75
	light_color = LIGHT_COLOR_LAVA
	footstep = FOOTSTEP_LAVA
	barefootstep = FOOTSTEP_LAVA
	clawfootstep = FOOTSTEP_LAVA
	heavyfootstep = FOOTSTEP_LAVA
	smoothing_flags = SMOOTH_BITMASK | SMOOTH_BORDER
	smoothing_groups = list(SMOOTH_GROUP_TURF, SMOOTH_GROUP_FLOOR_LAVA)
	canSmoothWith = list(SMOOTH_GROUP_FLOOR_LAVA)
	intact = FALSE
	floor_tile = null
	real_layer = PLATING_LAYER
	rust_resistance = RUST_RESISTANCE_ABSOLUTE
	/// Does the air over it ripple with the heat? See get_lava_heat_haze()
	var/hazy = TRUE
	/// The glow over the molten part of the sprite, see update_lava_glow()
	var/list/lava_glow_overlays

/turf/simulated/floor/lava/Initialize(mapload)
	. = ..()
	update_lava_glow()
	add_lava_effect_tile(src)
	if(hazy)
		add_overlay(get_lava_heat_haze((x * 7 + y * 13) % LAVA_HAZE_KINDS))

/turf/simulated/floor/lava/Destroy()
	remove_lava_effect_tile(src)
	return ..()

/turf/simulated/floor/lava/set_smoothed_icon_state(new_junction)
	. = ..()
	update_lava_glow()

/**
 * Makes the molten part of the lava glow, to match the sprite it has now.
 *
 * On the emissive plane the lighting doesn't darken it, so molten lava shines at full brightness even in the dark. On
 * the lava glow plane it blooms, and the halo is added over the lighting, round its edges onto the crust and the floor.
 * Both keep only the molten pixels, so the dark crust round the edges doesn't glow.
 */
/turf/simulated/floor/lava/proc/update_lava_glow()
	if(lava_glow_overlays)
		cut_overlay(lava_glow_overlays)
	lava_glow_overlays = list(get_lava_glow(icon, icon_state, EMISSIVE_PLANE), get_lava_glow(icon, icon_state, LAVA_GLOW_PLANE))
	add_overlay(lava_glow_overlays)

/turf/simulated/floor/lava/ex_act()
	return

/turf/simulated/floor/lava/acid_act(acidpwr, acid_volume)
	return

/turf/simulated/floor/lava/Entered(atom/movable/AM)
	..()
	if(burn_stuff(AM))
		START_PROCESSING(SSprocessing, src)

/turf/simulated/floor/lava/hitby(atom/movable/AM, skipcatch, hitpush, blocked, datum/thrownthing/throwingdatum)
	if(burn_stuff(AM))
		START_PROCESSING(SSprocessing, src)

/turf/simulated/floor/lava/process()
	if(!burn_stuff())
		STOP_PROCESSING(SSprocessing, src)

/turf/simulated/floor/lava/singularity_act()
	return

/turf/simulated/floor/lava/singularity_pull(S, current_size)
	return

/turf/simulated/floor/plating/lava/make_plating()
	return

/turf/simulated/floor/plating/lava/remove_plating()
	return

/turf/simulated/floor/plating/lava/get_smooth_underlay_icon(mutable_appearance/underlay_appearance, turf/asking_turf, adjacency_dir)
	underlay_appearance.icon = 'icons/turf/floors.dmi'
	underlay_appearance.icon_state = "basalt"
	return TRUE

/turf/simulated/floor/lava/is_safe()
	if(find_safeties() && ..())
		return TRUE
	return FALSE

/turf/simulated/floor/lava/CanPathfindPass(to_dir, datum/can_pass_info/pass_info)
	if(!pass_info.is_living)
		return TRUE

	return pass_info.is_flying || pass_info.is_megafauna || (locate(/obj/structure/bridge_walkway) in src)

/turf/simulated/floor/lava/proc/burn_stuff(AM)
	. = FALSE

	if(find_safeties())
		return FALSE

	var/thing_to_check = src
	if(AM)
		thing_to_check = list(AM)
	for(var/atom/thing in thing_to_check)
		if(HAS_TRAIT(thing, TRAIT_FLYING))
			continue	//YOU'RE FLYING OVER IT

		if(isobj(thing))
			var/obj/O = thing
			if(!O.simulated)
				continue
			if((O.resistance_flags & (LAVA_PROOF|INDESTRUCTIBLE)) || O.throwing)
				continue
			. = TRUE
			if((O.resistance_flags & (ON_FIRE)))
				continue
			if(!(O.resistance_flags & FLAMMABLE))
				O.resistance_flags |= FLAMMABLE //Even fireproof things burn up in lava
			if(O.resistance_flags & FIRE_PROOF)
				O.resistance_flags &= ~FIRE_PROOF
			if(O.armor.getRating(FIRE) > 50) //obj with 100% fire armor still get slowly burned away.
				O.armor = O.armor.setRating(fire_value = 50)
			O.fire_act(10000, 1000)

		else if(isliving(thing))
			. = TRUE
			var/mob/living/L = thing
			var/buckle_check = L.buckling
			if(!buckle_check)
				buckle_check = L.buckled
			if(isobj(buckle_check))
				var/obj/O = buckle_check
				if(O.resistance_flags & LAVA_PROOF)
					continue
			else if(isliving(buckle_check))
				var/mob/living/live = buckle_check
				if("lava" in live.weather_immunities)
					continue

			if("lava" in L.weather_immunities)
				continue

			L.adjustFireLoss(20)
			if(L) //mobs turning into object corpses could get deleted here.
				L.adjust_fire_stacks(20)
				L.IgniteMob()

/// Lava isn't a good foundation to build on.
/turf/simulated/floor/lava/item_interaction(mob/living/user, obj/item/used, list/modifiers)
	if(istype(used, /obj/item/stack/rods/lava))
		var/obj/item/stack/rods/lava/R = used
		var/obj/structure/lattice/lava/H = locate(/obj/structure/lattice/lava, src)
		if(H)
			to_chat(user, SPAN_WARNING("There is already a lattice here!"))
			return ITEM_INTERACT_COMPLETE
		if(R.use(1))
			to_chat(user, SPAN_WARNING("You construct a lattice."))
			playsound(src, 'sound/weapons/genhit.ogg', 50, TRUE)
			new /obj/structure/lattice/lava(locate(x, y, z))
			return ITEM_INTERACT_COMPLETE
		else
			to_chat(user, SPAN_WARNING("You need one rod to build a heatproof lattice."))
			return ITEM_INTERACT_COMPLETE

	if(istype(used, /obj/item/stack/tile/plasteel))
		var/obj/structure/lattice/L = locate(/obj/structure/lattice/lava, src)
		if(!L)
			to_chat(user, SPAN_WARNING("The plating is going to need some support! Place metal rods first."))
			return ITEM_INTERACT_COMPLETE
		var/obj/item/stack/tile/plasteel/S = used
		if(S.use(1))
			qdel(L)
			playsound(src, 'sound/weapons/genhit.ogg', 50, 1)
			to_chat(user, SPAN_NOTICE("You build a floor."))
			ChangeTurf(/turf/simulated/floor/plating, keep_icon = FALSE)
			return ITEM_INTERACT_COMPLETE
		else
			to_chat(user, SPAN_WARNING("You need one floor tile to build a floor!"))
			return ITEM_INTERACT_COMPLETE

/turf/simulated/floor/lava/screwdriver_act()
	return

/turf/simulated/floor/lava/welder_act()
	return

/turf/simulated/floor/lava/break_tile()
	return

/turf/simulated/floor/lava/burn_tile()
	return

/turf/simulated/floor/lava/can_cross_safely(atom/movable/crossing)
	if(isliving(crossing))
		var/mob/living/crosser = crossing
		return (locate(/obj/structure/bridge_walkway) in src) || HAS_TRAIT(crossing, TRAIT_FLYING) || ("lava" in crosser.weather_immunities)
	return locate(/obj/structure/bridge_walkway) in src || HAS_TRAIT(crossing, TRAIT_FLYING)

/turf/simulated/floor/lava/lava_land_surface
	oxygen = LAVALAND_OXYGEN
	nitrogen = LAVALAND_NITROGEN
	temperature = LAVALAND_TEMPERATURE
	atmos_mode = ATMOS_MODE_EXPOSED_TO_ENVIRONMENT
	atmos_environment = ENVIRONMENT_LAVALAND
	baseturf = /turf/simulated/floor/chasm/straight_down/lava_land_surface

/turf/simulated/floor/lava/lava_land_surface/plasma
	name = "liquid plasma"
	desc = "A flowing stream of chilled liquid plasma. You probably shouldn't get in."
	icon = 'icons/turf/floors/liquidplasma.dmi'
	icon_state = "liquidplasma-255"
	base_icon_state = "liquidplasma"
	baseturf = /turf/simulated/floor/lava/lava_land_surface/plasma
	hazy = FALSE

	light_range = 3
	light_color = LIGHT_COLOR_PINK

/turf/simulated/floor/lava/lava_land_surface/plasma/examine(mob/user)
	. = ..()
	. += SPAN_NOTICE("Some <b>liquid plasma<b> could probably be scooped up with a <b>container</b>.")

/turf/simulated/floor/lava/lava_land_surface/plasma/item_interaction(mob/living/user, obj/item/used, list/modifiers)
	if(!used.is_open_container())
		return ..()
	if(!used.reagents.add_reagent("plasma", 10))
		to_chat(user, SPAN_WARNING("[used] is full."))
		return ITEM_INTERACT_COMPLETE

	to_chat(user, SPAN_NOTICE("You scoop out some plasma from the [src] using [used]."))
	return ITEM_INTERACT_COMPLETE

/turf/simulated/floor/lava/lava_land_surface/plasma/burn_stuff(AM)
	. = FALSE
	if(find_safeties())
		return FALSE

	var/thing_to_check = src
	if(AM)
		thing_to_check = list(AM)
	for(var/atom/thing in thing_to_check)
		if(HAS_TRAIT(thing, TRAIT_FLYING))
			continue	//YOU'RE FLYING OVER IT

		if(isobj(thing))
			var/obj/O = thing
			if(!O.simulated)
				continue
			if((O.resistance_flags & (LAVA_PROOF|INDESTRUCTIBLE)) || O.throwing)
				continue
			. = TRUE
			if(O.resistance_flags & ON_FIRE)
				continue
			if(!(O.resistance_flags & FLAMMABLE))
				O.resistance_flags |= FLAMMABLE //Even fireproof things burn up in lava
			if(O.resistance_flags & FIRE_PROOF)
				O.resistance_flags &= ~FIRE_PROOF
			if(O.armor.getRating(FIRE) > 50) //obj with 100% fire armor still get slowly burned away.
				O.armor = O.armor.setRating(fire_value = 50)
			O.fire_act(10000, 1000)

		if(!isliving(thing))
			continue
		. = TRUE
		var/mob/living/burn_living = thing
		if(HAS_TRAIT(burn_living, TRAIT_FLYING))
			continue	//YOU'RE FLYING OVER IT
		var/buckle_check = burn_living.buckling
		if(!buckle_check)
			buckle_check = burn_living.buckled
		if(isobj(buckle_check))
			var/obj/O = buckle_check
			if(O.resistance_flags & LAVA_PROOF)
				continue
		else if(isliving(buckle_check))
			var/mob/living/live = buckle_check
			if("lava" in live.weather_immunities)
				continue
		if("lava" in burn_living.weather_immunities)
			continue
		burn_living.adjustFireLoss(2)
		if(QDELETED(burn_living))
			return
		burn_living.adjust_fire_stacks(20) //dipping into a stream of plasma would probably make you more flammable than usual
		burn_living.IgniteMob()
		burn_living.adjust_bodytemperature(-rand(50, 65)) //its cold, man
		if(!ishuman(burn_living) || prob(65))
			return
		var/mob/living/carbon/human/burn_human = burn_living
		var/datum/species/burn_species = burn_human.dna.species
		if(istype(burn_species, /datum/species/plasmaman) || istype(burn_species, /datum/species/machine)) //ignore plasmamen/robotic species.
			return

		burn_human.adjustToxLoss(15) //Cold mutagen is bad for you, more at 11.
		burn_human.adjustFireLoss(15)

/turf/simulated/floor/lava/mapping_lava
	name = "Adaptive lava / chasm / plasma"
	icon_state = "mappinglava"
	base_icon_state = "mappinglava"
	baseturf = /turf/simulated/floor/lava/mapping_lava
	oxygen = LAVALAND_OXYGEN
	nitrogen = LAVALAND_NITROGEN
	temperature = LAVALAND_TEMPERATURE
	atmos_mode = ATMOS_MODE_EXPOSED_TO_ENVIRONMENT
	atmos_environment = ENVIRONMENT_LAVALAND

/turf/simulated/floor/lava/mapping_lava/normal_air
	oxygen = MOLES_O2STANDARD
	nitrogen = MOLES_N2STANDARD
	temperature = T20C
	atmos_mode = ATMOS_MODE_SEALED
	atmos_environment = null

/turf/simulated/floor/lava/plasma
	name = "liquid plasma"
	desc = "A swirling pit of liquid plasma. It bubbles ominously."
	icon = 'icons/turf/floors/liquidplasma.dmi'
	icon_state = "liquidplasma-255"
	base_icon_state = "liquidplasma"
	baseturf = /turf/simulated/floor/lava/plasma
	hazy = FALSE
	light_range = 3
	light_color = LIGHT_COLOR_PINK

// special turf for the asteroid core on EmeraldStation
/turf/simulated/floor/lava/plasma/fuming
	baseturf = /turf/simulated/floor/lava/plasma/fuming
	atmos_mode = ATMOS_MODE_NO_DECAY

	// Hot Ass Plasma lava
	temperature = 1000
	oxygen = 0
	nitrogen = 0
	carbon_dioxide = 1.2
	toxins = 10

/turf/simulated/floor/lava/mapping_lava/Initialize(mapload)
	. = ..()
	return INITIALIZE_HINT_LATELOAD //Lateload is needed, otherwise atmos does not setup right on the turf roundstart, leading it to be vacume. This is bad.

/turf/simulated/floor/lava/mapping_lava/LateInitialize()
	. = ..()
	if(SSmapping.lavaland_theme?.primary_turf_type)
		ChangeTurf(SSmapping.lavaland_theme.primary_turf_type, ignore_air = TRUE)

/**
 * The heat haze over lava, `kind` 0 to LAVA_HAZE_KINDS - 1, made once and shared.
 *
 * Heat distortion, not fumes: ripples rising off the lava, half a tile wider than the tile each side and two tiles
 * above it, so a lake's tiles overlap into one haze. It's drawn where the game's own warp reads it (red pushes
 * sideways, green up and down, mid grey not at all) and never seen itself: the lava and whatever is over and behind it
 * ripple a pixel or two, mostly sideways, as hot air does.
 */
/proc/get_lava_heat_haze(kind)
	var/static/list/made = list()
	. = made["[kind]"]
	if(.)
		return
	var/mutable_appearance/shimmer = mutable_appearance('icons/effects/lava_haze.dmi', "shimmer-[kind]", plane = GRAVITY_PULSE_PLANE, appearance_flags = KEEP_APART | RESET_COLOR)
	shimmer.pixel_x = -16
	. = shimmer
	made["[kind]"] = .

/**
 * The bright molten part of a lava sprite on `plane`, made once and shared by every lava tile with that sprite.
 *
 * How bright each pixel is decides how much of it glows: 6 * (0.5 red + 0.4 green + 0.1 blue - 0.24). The grey crust
 * comes out at nothing, the dull red of cooling rock at a little, and the molten rock at full. On the emissive plane
 * it's white, on the lava glow plane it keeps its own colour for the bloom.
 */
/proc/get_lava_glow(icon, icon_state, plane)
	var/static/list/made = list()
	var/key = "[icon]|[icon_state]|[plane]"
	. = made[key]
	if(.)
		return
	var/mutable_appearance/glow = mutable_appearance(icon, icon_state, plane = plane)
	if(plane == EMISSIVE_PLANE)
		glow.color = list(0, 0, 0, 3, 0, 0, 0, 2.4, 0, 0, 0, 0.6, 0, 0, 0, 0, 1, 1, 1, -1.44)
	else
		glow.color = list(1, 0, 0, 3, 0, 1, 0, 2.4, 0, 0, 1, 0.6, 0, 0, 0, 0, 0, 0, 0, -1.44)
	made[key] = glow
	return glow

// MARK: Bloom only near lava

/// Chunks of the map with lava in them, "z:x:y" = how many lava tiles
GLOBAL_LIST_EMPTY(lava_effect_chunks)
GLOBAL_DATUM(lava_effects_watcher, /datum/lava_effects_watcher)

/proc/lava_effect_chunk_key(turf/T)
	return "[T.z]:[round(T.x / LAVA_EFFECT_CHUNK)]:[round(T.y / LAVA_EFFECT_CHUNK)]"

/// A tile of lava was made, so players near it get lava's bloom
/proc/add_lava_effect_tile(turf/T)
	GLOB.lava_effect_chunks[lava_effect_chunk_key(T)] += 1
	if(!GLOB.lava_effects_watcher)
		GLOB.lava_effects_watcher = new

/// A tile of lava is gone
/proc/remove_lava_effect_tile(turf/T)
	var/key = lava_effect_chunk_key(T)
	var/left = GLOB.lava_effect_chunks[key] - 1
	if(left > 0)
		GLOB.lava_effect_chunks[key] = left
	else
		GLOB.lava_effect_chunks -= key

/// Is there lava in the chunk `T` is in, or one next to it? That reaches past a player's screen
/proc/lava_effects_near(turf/T)
	var/cx = round(T.x / LAVA_EFFECT_CHUNK)
	var/cy = round(T.y / LAVA_EFFECT_CHUNK)
	for(var/dx in -1 to 1)
		for(var/dy in -1 to 1)
			if(GLOB.lava_effect_chunks["[T.z]:[cx + dx]:[cy + dy]"])
				return TRUE
	return FALSE

/**
 * Turns lava's bloom on for players with lava nearby, and off for everyone else.
 *
 * The bloom is a few passes over the whole screen every frame, whether there's lava on screen or not, and so is its
 * plane master over the lighting. Most players are nowhere near lava, so for them it's off and that plane master is
 * off the screen. A chunk next to the player's counts as near, so it's back on before any lava comes into view.
 */
/datum/lava_effects_watcher

/datum/lava_effects_watcher/New()
	START_PROCESSING(SSprocessing, src)

/datum/lava_effects_watcher/process()
	for(var/client/C as anything in GLOB.clients)
		var/datum/hud/hud = C.mob?.hud_used
		if(!hud)
			continue
		var/turf/T = get_turf(C.eye)
		var/near = !!(T && lava_effects_near(T))
		if(near != hud.lava_effects_on)
			hud.set_lava_effects(near)

/datum/hud/proc/set_lava_effects(on)
	lava_effects_on = on
	for(var/plane in plane_masters)
		var/atom/movable/screen/plane_master/master = plane_masters[plane]
		if(!master.lava_effect)
			continue
		master.set_lava_effects(on)
		if(on)
			mymob?.client?.screen |= master
	if(!on)
		remove_lava_planes()
	// The world is only copied for the bloom to keep off things standing in the lava
	var/atom/movable/screen/plane_master/world_master = plane_masters["[GAME_PLANE]"]
	if(world_master)
		world_master.render_target = on ? GAME_PLANE_RENDER_TARGET : null

/// Takes lava's plane masters off the player's screen, while there's no lava nearby
/datum/hud/proc/remove_lava_planes()
	var/client/viewer = mymob?.client
	if(!viewer)
		return
	for(var/plane in plane_masters)
		var/atom/movable/screen/plane_master/master = plane_masters[plane]
		if(master.lava_effect)
			viewer.screen -= master

#undef LAVA_HAZE_KINDS
#undef LAVA_EFFECT_CHUNK
