// MARK: Caught fish

/// Remembers how big a caught fish is, who caught it and where. Lets it go into a fish tank while it's still alive.
/datum/component/caught_fish
	/// How long the fish is, in cm
	var/length_cm
	/// Is it big for its kind? Big ones give an extra fillet
	var/big
	/// Name of whoever caught it
	var/angler
	/// Name of the kind of spot it came out of
	var/spot_name
	/// The kind of tank fish it is, if it can live in a fish tank
	var/datum/fish/fish_type
	/// The world.time it dies at if it isn't in a tank by then
	var/alive_until

/datum/component/caught_fish/Initialize(length_cm, big, angler, spot_name, fish_type)
	if(!isitem(parent))
		return COMPONENT_INCOMPATIBLE
	src.length_cm = length_cm
	src.big = big
	src.angler = angler
	src.spot_name = spot_name
	src.fish_type = fish_type
	alive_until = world.time + FISHING_FISH_LIFETIME

/datum/component/caught_fish/RegisterWithParent()
	RegisterSignal(parent, COMSIG_PARENT_EXAMINE, PROC_REF(on_examine))
	RegisterSignal(parent, COMSIG_INTERACTING, PROC_REF(on_interacting))

/datum/component/caught_fish/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_PARENT_EXAMINE, COMSIG_INTERACTING))

/datum/component/caught_fish/proc/is_alive()
	return world.time < alive_until

/datum/component/caught_fish/proc/on_examine(datum/source, mob/user, list/examine_list)
	SIGNAL_HANDLER // COMSIG_PARENT_EXAMINE
	examine_list += SPAN_NOTICE("It's [length_cm] cm long. [angler] caught it in [spot_name].")
	if(fish_type && is_alive())
		examine_list += SPAN_NOTICE("It's still flopping. It would live if it got into a fish tank soon.")

/datum/component/caught_fish/proc/on_interacting(datum/source, mob/living/user, atom/target, list/modifiers)
	SIGNAL_HANDLER // COMSIG_INTERACTING
	if(!istype(target, /obj/machinery/fishtank))
		return
	release_into(target, user)
	return ITEM_INTERACT_COMPLETE

/// Lets the fish go in `tank`, if it's alive and the tank has room for it
/datum/component/caught_fish/proc/release_into(obj/machinery/fishtank/tank, mob/living/user)
	var/obj/item/fish = parent
	if(!fish_type)
		to_chat(user, SPAN_WARNING("[fish] wouldn't live in a fish tank."))
		return
	if(!is_alive())
		to_chat(user, SPAN_WARNING("[fish] has been out of the water too long. It's dead."))
		return
	if(tank.has_lid && tank.lid_switch)
		to_chat(user, SPAN_WARNING("The lid of [tank] is closed."))
		return
	if(!tank.water_level)
		to_chat(user, SPAN_WARNING("[tank] has no water in it."))
		return
	if(tank.get_num_fish() >= tank.max_fish)
		to_chat(user, SPAN_WARNING("[tank] can't hold any more fish."))
		return
	tank.fish_list += new fish_type
	tank.update_icon(UPDATE_OVERLAYS)
	user.visible_message(SPAN_NOTICE("[user] lowers [fish] into [tank]. It swims off."), SPAN_NOTICE("You lower [fish] into [tank]. It swims off."))
	qdel(fish)

// MARK: Wild fish

/// Fish that only come from fishing. They all get cleaned the same way.
/obj/item/fish/wild
	/// What cleaning it with something sharp gives
	var/fillet_type = /obj/item/food/cave_fillet
	/// How many fillets it gives. A big one gives one more
	var/fillet_amount = 1

/obj/item/fish/wild/item_interaction(mob/living/user, obj/item/used, list/modifiers)
	if(!used.sharp)
		return ..()
	var/amount = fillet_amount
	var/datum/component/caught_fish/info = GetComponent(/datum/component/caught_fish)
	if(info?.big)
		amount++
	to_chat(user, SPAN_NOTICE("You carefully clean and gut \the [src.name]."))
	for(var/i in 1 to amount)
		new fillet_type(get_turf(src))
	qdel(src)
	return ITEM_INTERACT_COMPLETE

/obj/item/fish/wild/magma_eel
	name = "magma eel"
	desc = "A long eel with skin like cooling lava. It's still warm to the touch."
	icon = 'icons/obj/fishing.dmi'
	icon_state = "magma_eel"
	fillet_type = /obj/item/food/magma_fillet
	fillet_amount = 2

/obj/item/fish/wild/magma_eel/Initialize(mapload)
	. = ..()
	set_light(2, 1, "#FF7B2E")

/obj/item/fish/wild/ash_perch
	name = "ash perch"
	desc = "A stubby grey fish that eats whatever falls into the lava."
	icon = 'icons/obj/fishing.dmi'
	icon_state = "ash_perch"
	fillet_type = /obj/item/food/magma_fillet

/obj/item/fish/wild/cinder_crab
	name = "cinder crab"
	desc = "A crab with a shell like a hot coal. Not a fish, but it came up on a hook all the same."
	icon = 'icons/obj/fishing.dmi'
	icon_state = "cinder_crab"
	hitsound = 'sound/weapons/bite.ogg'
	fillet_type = /obj/item/food/magma_fillet

/obj/item/fish/wild/plasma_lungfish
	name = "plasma lungfish"
	desc = "It breathes liquid plasma. Nobody is sure how, and it isn't telling."
	icon = 'icons/obj/fishing.dmi'
	icon_state = "plasma_lungfish"
	fillet_type = /obj/item/food/rime_fillet
	fillet_amount = 2

/obj/item/fish/wild/rime_pike
	name = "rime pike"
	desc = "All teeth and bad temper, out of a river cold enough to freeze the air."
	icon = 'icons/obj/fishing.dmi'
	icon_state = "rime_pike"
	hitsound = 'sound/weapons/bite.ogg'
	force = 3
	fillet_type = /obj/item/food/rime_fillet
	fillet_amount = 2

/obj/item/fish/wild/cave_blindfish
	name = "cave blindfish"
	desc = "It has no eyes, and no need for them at the bottom of a chasm."
	icon = 'icons/obj/fishing.dmi'
	icon_state = "cave_blindfish"

/obj/item/fish/wild/glowmaw_angler
	name = "glowmaw angler"
	desc = "It dangles a little light in front of a very large mouth. It was fishing long before you were."
	icon = 'icons/obj/fishing.dmi'
	icon_state = "glowmaw_angler"
	hitsound = 'sound/weapons/bite.ogg'
	force = 3
	fillet_amount = 2

/obj/item/fish/wild/glowmaw_angler/Initialize(mapload)
	. = ..()
	set_light(2, 1, "#7DF9FF")

/obj/item/fish/wild/void_ray
	name = "void ray"
	desc = "It glides through vacuum on wings a metre across. It looks as surprised to be here as you are."
	icon = 'icons/obj/fishing.dmi'
	icon_state = "void_ray"
	fillet_type = /obj/item/food/void_fillet
	fillet_amount = 3

/obj/item/fish/wild/comet_minnow
	name = "comet minnow"
	desc = "A tiny silver fish that leaves a faint trail of frost behind it."
	icon = 'icons/obj/fishing.dmi'
	icon_state = "comet_minnow"
	fillet_type = /obj/item/food/void_fillet

// MARK: Tank fish

// Wild fish live in a tank but only lay dud eggs there

/datum/fish/magma_eel
	fish_name = "magma eel"
	fish_item = /obj/item/fish/wild/magma_eel
	crossbreeder = 0

/datum/fish/ash_perch
	fish_name = "ash perch"
	fish_item = /obj/item/fish/wild/ash_perch
	crossbreeder = 0

/datum/fish/cinder_crab
	fish_name = "cinder crab"
	fish_item = /obj/item/fish/wild/cinder_crab
	crossbreeder = 0

/datum/fish/plasma_lungfish
	fish_name = "plasma lungfish"
	fish_item = /obj/item/fish/wild/plasma_lungfish
	crossbreeder = 0

/datum/fish/rime_pike
	fish_name = "rime pike"
	fish_item = /obj/item/fish/wild/rime_pike
	crossbreeder = 0

/datum/fish/cave_blindfish
	fish_name = "cave blindfish"
	fish_item = /obj/item/fish/wild/cave_blindfish
	crossbreeder = 0

/datum/fish/glowmaw_angler
	fish_name = "glowmaw angler"
	fish_item = /obj/item/fish/wild/glowmaw_angler
	crossbreeder = 0

/datum/fish/void_ray
	fish_name = "void ray"
	fish_item = /obj/item/fish/wild/void_ray
	crossbreeder = 0

/datum/fish/comet_minnow
	fish_name = "comet minnow"
	fish_item = /obj/item/fish/wild/comet_minnow
	crossbreeder = 0

// MARK: Fillets

/obj/item/food/magma_fillet
	name = "magma fish fillet"
	desc = "A fillet from something that lived in lava. It never quite cools down."
	icon = 'icons/obj/fishing.dmi'
	icon_state = "fillet_magma"
	filling_color = "#E8601C"
	bitesize = 6
	list_reagents = list("protein" = 3, "vitamin" = 1, "capsaicin" = 3)
	tastes = list("smoky fish" = 2, "burning" = 1)

/obj/item/food/rime_fillet
	name = "rime fish fillet"
	desc = "A pale blue fillet with frost on it. It numbs your fingers."
	icon = 'icons/obj/fishing.dmi'
	icon_state = "fillet_rime"
	filling_color = "#9FD8F2"
	bitesize = 6
	list_reagents = list("protein" = 3, "vitamin" = 1, "frostoil" = 3)
	tastes = list("clean white fish" = 2, "ice" = 1)

/obj/item/food/cave_fillet
	name = "cave fish fillet"
	desc = "A soft grey fillet from something that never saw daylight."
	icon = 'icons/obj/fishing.dmi'
	icon_state = "fillet_cave"
	filling_color = "#B9B4A8"
	bitesize = 6
	list_reagents = list("protein" = 3, "vitamin" = 3)
	tastes = list("muddy fish" = 1)

/obj/item/food/void_fillet
	name = "void fish fillet"
	desc = "A dark fillet that seems to soak up the light around it. Rich, if you can get past the look."
	icon = 'icons/obj/fishing.dmi'
	icon_state = "fillet_void"
	filling_color = "#3A2E5C"
	bitesize = 6
	list_reagents = list("protein" = 4, "vitamin" = 2)
	tastes = list("rich fish" = 2, "static" = 1)
