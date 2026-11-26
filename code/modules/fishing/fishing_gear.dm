// MARK: Lines

/obj/item/fishing_line
	name = "fishing line"
	desc = "A reel of plain fishing line. Good for water, toilets and the void of space."
	icon = 'icons/obj/fishing.dmi'
	icon_state = "line"
	w_class = WEIGHT_CLASS_TINY
	new_attack_chain = TRUE
	/// What this line can be used for, FISHING_LINE_ flags
	var/line_flags = NONE
	/// How far it can be cast, in tiles
	var/cast_range = 5
	/// How much pull it takes before it snaps. A line of 1.15 takes 15% more than a plain one
	var/strength = 1
	/// Colour of the line drawn from the angler to the bobber
	var/line_color = "#dddddd"

/obj/item/fishing_line/examine(mob/user)
	. = ..()
	. += SPAN_NOTICE("It can be cast up to [cast_range] tiles.")
	if(line_flags & FISHING_LINE_HEATPROOF)
		. += SPAN_NOTICE("It won't burn in lava or liquid plasma.")
	if(line_flags & FISHING_LINE_LONG)
		. += SPAN_NOTICE("It's long enough to reach the bottom of a chasm.")

/obj/item/fishing_line/sinew
	name = "sinew fishing line"
	desc = "Fishing line braided from watcher sinew. It doesn't burn and it's hard to snap."
	icon_state = "line_sinew"
	line_flags = FISHING_LINE_HEATPROOF
	strength = 1.15
	line_color = "#c98a5a"

/obj/item/fishing_line/long
	name = "deep fishing line"
	desc = "A fat reel of very thin line. There's a lot of it, but it snaps easier."
	icon_state = "line_long"
	line_flags = FISHING_LINE_LONG
	cast_range = 7
	strength = 0.85
	line_color = "#8fc1e6"

// MARK: Hooks

/obj/item/fishing_hook
	name = "fishing hook"
	desc = "A bent bit of metal with a point on the end."
	icon = 'icons/obj/fishing.dmi'
	icon_state = "hook"
	w_class = WEIGHT_CLASS_TINY
	new_attack_chain = TRUE
	/// How long the angler has to pull once something bites
	var/bite_window = 2 SECONDS
	/// A fish has to take this many times more line than usual to get off the hook
	var/spare_line_mult = 1
	/// The kind of bait this hook counts as while there's no bait on it
	var/lure_kind

/obj/item/fishing_hook/barbed
	name = "barbed fishing hook"
	desc = "A hook with barbs. Whatever bites it stays on for longer."
	icon_state = "hook_barbed"
	bite_window = 3 SECONDS
	spare_line_mult = 1.4

/obj/item/fishing_hook/lure
	name = "shiny lure"
	desc = "A hook with a polished spinner on it. Some fish can't resist a bit of glitter, and it never runs out."
	icon_state = "hook_lure"
	lure_kind = FISHING_BAIT_SHINY

// MARK: Bait

/// Gives the kind of bait `bait` is, or null if nothing would bite on it
/proc/get_fishing_bait_kind(obj/item/bait)
	var/static/list/bait_kinds = list(
		/obj/item/food/feederfish = FISHING_BAIT_LIVE,
		/obj/item/food/shrimp = FISHING_BAIT_LIVE,
		/obj/item/food/sliced/cheesewedge = FISHING_BAIT_CHEESE,
		/obj/item/food/meat = FISHING_BAIT_MEAT,
		/obj/item/food/monstermeat = FISHING_BAIT_MEAT,
		/obj/item/food/carpmeat = FISHING_BAIT_MEAT,
		/obj/item/food/salmonmeat = FISHING_BAIT_MEAT,
		/obj/item/food/catfishmeat = FISHING_BAIT_MEAT,
		/obj/item/food/grown = FISHING_BAIT_PLANT,
		/obj/item/flashlight/flare/glowstick = FISHING_BAIT_GLOW,
		/obj/item/coin = FISHING_BAIT_SHINY,
	)
	for(var/bait_type in bait_kinds)
		if(istype(bait, bait_type))
			return bait_kinds[bait_type]

// MARK: Tackle box

/obj/item/storage/fishing_tackle
	name = "tackle box"
	desc = "A box with little trays for fishing lines, hooks and bait."
	icon = 'icons/obj/fishing.dmi'
	icon_state = "tackle_box"
	storage_slots = 14
	max_combined_w_class = 28
	can_hold = list(
		/obj/item/fishing_line,
		/obj/item/fishing_hook,
		/obj/item/food,
		/obj/item/coin,
		/obj/item/flashlight/flare/glowstick,
	)

/// The tackle box from the cargo crate, with a line and a hook of every kind
/obj/item/storage/fishing_tackle/full

/obj/item/storage/fishing_tackle/full/populate_contents()
	new /obj/item/fishing_line(src)
	new /obj/item/fishing_line/sinew(src)
	new /obj/item/fishing_line/long(src)
	new /obj/item/fishing_hook(src)
	new /obj/item/fishing_hook(src)
	new /obj/item/fishing_hook/barbed(src)
	new /obj/item/fishing_hook/lure(src)
