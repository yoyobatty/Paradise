/// The biggest catch of each kind of fish this shift. Name of the fish = its /datum/fishing_record
GLOBAL_LIST_EMPTY(fishing_records)

/// The biggest one of a kind of fish caught this shift.
/datum/fishing_record
	/// The kind of fish
	var/fish_name
	/// Who caught it
	var/angler
	/// How long it was, in cm
	var/length_cm
	/// The kind of spot it was caught in
	var/spot_name
	/// Station time it was caught at
	var/time

/// Notes down a catch if it's the biggest of its kind so far. Returns TRUE if it beat an older one.
/proc/record_fishing_catch(angler, fish_name, length_cm, spot_name)
	var/datum/fishing_record/old_record = GLOB.fishing_records[fish_name]
	if(old_record && old_record.length_cm >= length_cm)
		return FALSE
	var/datum/fishing_record/record = new
	record.fish_name = fish_name
	record.angler = angler
	record.length_cm = length_cm
	record.spot_name = spot_name
	record.time = station_time_timestamp("hh:mm")
	GLOB.fishing_records[fish_name] = record
	// The first of a kind sets the record without beating anybody
	return !!old_record

// MARK: Record board

/obj/item/mounted/fishing_board
	name = "angler's record board"
	desc = "A board that keeps track of the biggest fish caught this shift. It goes on a wall."
	icon = 'icons/obj/fishing.dmi'
	icon_state = "board"
	w_class = WEIGHT_CLASS_BULKY

/obj/item/mounted/fishing_board/do_build(turf/on_wall, mob/user)
	new /obj/structure/fishing_board(get_turf(user), get_dir(on_wall, user), TRUE)
	qdel(src)

/obj/structure/fishing_board
	name = "angler's record board"
	desc = "The biggest fish caught this shift, and who caught them."
	icon = 'icons/obj/fishing.dmi'
	icon_state = "board"
	anchored = TRUE
	max_integrity = 100

/obj/structure/fishing_board/Initialize(mapload, direction, building = FALSE)
	. = ..()
	if(building)
		setDir(direction)
		set_pixel_offsets_from_dir(-32, 32, -30, 30)

/obj/structure/fishing_board/examine(mob/user)
	. = ..()
	. += SPAN_NOTICE("It can be <b>pried</b> off the wall.")

/obj/structure/fishing_board/attack_hand(mob/user)
	ui_interact(user)

/obj/structure/fishing_board/attack_ghost(mob/user)
	ui_interact(user)

/obj/structure/fishing_board/crowbar_act(mob/living/user, obj/item/I)
	. = TRUE
	if(!I.use_tool(src, user, 2 SECONDS, volume = I.tool_volume))
		return
	to_chat(user, SPAN_NOTICE("You pry [src] off the wall."))
	deconstruct(TRUE)

/obj/structure/fishing_board/deconstruct(disassembled = TRUE)
	if(disassembled)
		new /obj/item/mounted/fishing_board(drop_location())
	else
		new /obj/item/stack/sheet/wood(drop_location(), 2)
	qdel(src)

/obj/structure/fishing_board/ui_state(mob/user)
	return GLOB.default_state

/obj/structure/fishing_board/ui_interact(mob/user, datum/tgui/ui = null)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "FishingBoard", name)
		ui.open()

/obj/structure/fishing_board/ui_data(mob/user)
	var/list/data = list()
	var/list/records = list()
	for(var/fish_name in GLOB.fishing_records)
		var/datum/fishing_record/record = GLOB.fishing_records[fish_name]
		records += list(list(
			"fish" = record.fish_name,
			"angler" = record.angler,
			"length" = record.length_cm,
			"spot" = record.spot_name,
			"time" = record.time,
		))
	data["records"] = records
	return data

// MARK: Trophy plaque

/obj/item/mounted/fish_plaque
	name = "trophy plaque"
	desc = "A polished wooden plaque for showing off a catch. Put a fish you caught on it, then hang it on a wall."
	icon = 'icons/obj/fishing.dmi'
	icon_state = "plaque"
	/// The fish on the plaque
	var/obj/item/mounted_fish

/obj/item/mounted/fish_plaque/Destroy()
	QDEL_NULL(mounted_fish)
	return ..()

/obj/item/mounted/fish_plaque/examine(mob/user)
	. = ..()
	if(mounted_fish)
		. += SPAN_NOTICE("<b>Alt-Click</b> to take [mounted_fish] off it.")

/obj/item/mounted/fish_plaque/item_interaction(mob/living/user, obj/item/used, list/modifiers)
	var/datum/component/caught_fish/info = used.GetComponent(/datum/component/caught_fish)
	if(!info)
		return ..()
	if(mounted_fish)
		to_chat(user, SPAN_WARNING("There's already \a [mounted_fish] on [src]."))
		return ITEM_INTERACT_COMPLETE
	if(!user.transfer_item_to(used, src))
		return ITEM_INTERACT_COMPLETE
	mounted_fish = used
	name = "mounted [used.name]"
	desc = "\A [used.name], [info.length_cm] cm long. [info.angler] caught it in [info.spot_name]."
	update_icon(UPDATE_OVERLAYS)
	to_chat(user, SPAN_NOTICE("You fix [used] to the plaque."))
	return ITEM_INTERACT_COMPLETE

/obj/item/mounted/fish_plaque/AltClick(mob/user)
	if(user.stat || HAS_TRAIT(user, TRAIT_HANDS_BLOCKED) || !Adjacent(user))
		return
	if(!mounted_fish)
		return
	to_chat(user, SPAN_NOTICE("You take [mounted_fish] off the plaque."))
	user.put_in_hands(mounted_fish)

/obj/item/mounted/fish_plaque/Exited(atom/movable/gone, direction)
	. = ..()
	forget_fish(gone)

// A fish deleted while on the plaque doesn't call Exited()
/obj/item/mounted/fish_plaque/handle_atom_del(atom/deleted)
	. = ..()
	forget_fish(deleted)

/obj/item/mounted/fish_plaque/proc/forget_fish(atom/movable/gone)
	if(gone != mounted_fish)
		return
	mounted_fish = null
	name = initial(name)
	desc = initial(desc)
	update_icon(UPDATE_OVERLAYS)

/obj/item/mounted/fish_plaque/update_overlays()
	. = ..()
	if(mounted_fish)
		. += mutable_appearance(mounted_fish.icon, mounted_fish.icon_state)

/obj/item/mounted/fish_plaque/try_build(turf/on_wall, mob/user)
	if(!mounted_fish)
		to_chat(user, SPAN_WARNING("Put a fish on [src] before hanging it."))
		return FALSE
	return ..()

/obj/item/mounted/fish_plaque/do_build(turf/on_wall, mob/user)
	if(!user.unequip(src))
		return
	new /obj/structure/fish_trophy(get_turf(user), get_dir(on_wall, user), src)

/// A trophy plaque hanging on a wall. It holds the plaque item and looks like it.
/obj/structure/fish_trophy
	name = "mounted fish"
	icon = 'icons/obj/fishing.dmi'
	icon_state = "plaque"
	anchored = TRUE
	max_integrity = 50
	/// The plaque that was hung up, with its fish on it
	var/obj/item/mounted/fish_plaque/plaque

/obj/structure/fish_trophy/Initialize(mapload, direction, obj/item/mounted/fish_plaque/hung_plaque)
	. = ..()
	if(!hung_plaque)
		return
	plaque = hung_plaque
	plaque.forceMove(src)
	name = plaque.name
	desc = plaque.desc
	setDir(direction)
	set_pixel_offsets_from_dir(-32, 32, -30, 30)
	update_icon(UPDATE_OVERLAYS)

/obj/structure/fish_trophy/Destroy()
	QDEL_NULL(plaque)
	return ..()

/obj/structure/fish_trophy/examine(mob/user)
	. = ..()
	. += SPAN_NOTICE("It can be <b>pried</b> off the wall.")

/obj/structure/fish_trophy/update_overlays()
	. = ..()
	if(plaque?.mounted_fish)
		. += mutable_appearance(plaque.mounted_fish.icon, plaque.mounted_fish.icon_state)

/obj/structure/fish_trophy/crowbar_act(mob/living/user, obj/item/I)
	. = TRUE
	if(!I.use_tool(src, user, 2 SECONDS, volume = I.tool_volume))
		return
	to_chat(user, SPAN_NOTICE("You pry [src] off the wall."))
	deconstruct(TRUE)

// The plaque comes down in one piece either way
/obj/structure/fish_trophy/deconstruct(disassembled = TRUE)
	if(plaque)
		plaque.forceMove(drop_location())
		plaque = null
	qdel(src)
