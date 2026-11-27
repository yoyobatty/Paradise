/// How far a floating thing rises and falls on a calm pool, in pixels
#define POOL_FLOAT_BOB 2
/// How much lower a thing on the bottom of a pool is drawn than one on the ground
#define POOL_SUNK_DROP 2
/// Where the water sprites of a floating thing have their waterline, in rows from the bottom. They're moved to its own
#define POOL_FLOAT_SPRITE_LINE 16

/// Everything floating on a pool right now, for rings of waves to lift as they pass
GLOBAL_LIST_EMPTY(pool_things_afloat)

/**
 * Where the water comes up to on a floating thing's sprite, worked out once for each sprite from its shape.
 *
 * It floats with about the bottom third of it under the water. Returns a list: "x" and "y", how far to move the water
 * sprites drawn for a floating thing so they sit on its waterline, and "across", how many pixels wide it is there,
 * rounded up to the even widths the ring round it is drawn in.
 */
/proc/get_float_line(obj/item/floater)
	var/static/list/float_lines = list()
	var/key = "[floater.icon]|[floater.icon_state]"
	var/list/float_line = float_lines[key]
	if(float_line)
		return float_line
	var/icon/sprite = icon(floater.icon, floater.icon_state, SOUTH, 1)
	var/height = sprite.Height()
	var/width = sprite.Width()
	// Its lowest and highest rows with anything drawn on them
	var/list/row_left = list()
	var/list/row_right = list()
	var/bottom = 0
	var/top = 0
	for(var/y in 1 to height)
		for(var/x in 1 to width)
			if(!sprite.GetPixel(x, y))
				continue
			if(!row_left["[y]"])
				row_left["[y]"] = x
			row_right["[y]"] = x
		if(!row_left["[y]"])
			continue
		if(!bottom)
			bottom = y
		top = y
	// Nothing drawn at all: as if it filled the middle of its tile
	if(!bottom)
		float_line = list("x" = 0, "y" = 0, "across" = 16)
		float_lines[key] = float_line
		return float_line
	// The highest row that's under the water, and how wide the thing is there
	var/wet_row = bottom + clamp(round((top - bottom + 1) * 0.3, 1), 2, 7) - 1
	var/left = row_left["[wet_row]"]
	var/right = row_right["[wet_row]"]
	var/across = clamp(CEILING(right - left + 1, 2), 4, 26)
	float_line = list("x" = round((left + right) / 2 - (width + 1) / 2, 1), "y" = wet_row - POOL_FLOAT_SPRITE_LINE, "across" = across)
	float_lines[key] = float_line
	return float_line

/**
 * Puts an item that's in a pool under the water, or afloat on it.
 *
 * Most things sink. The water's colour is drawn over the item's own pixels, the same way it is over the legs of someone
 * standing in the pool, and the waves bend it like they bend the pool floor. A few things float instead: they ride up
 * and down on the water with a ring of it round them, only their underside is under it, and small waves spread out
 * from them. Something that lands in the water from the air goes under, or dips and bobs back up, as it arrives.
 * Pool water gives this to items that land in it, and it takes itself off when they're picked up or moved out.
 */
/datum/component/pool_sunk
	/// The colours of the pool the item is in, "pool" or "deep"
	var/look
	/// Does the item float on the water instead of lying under it?
	var/floating = FALSE
	/// Where the item was drawn before the water moved it up, down and sideways
	var/old_pixel_z = 0
	var/old_pixel_w = 0
	/// What's drawn with the item while it's in the water: the rings round a floating thing, its shadow, the small
	/// waves it makes, and where the waves bend it
	var/list/obj/effect/abstract/waterline/parts = list()
	/// The halves of the ring of water round a floating thing
	var/list/obj/effect/abstract/waterline/rings = list()
	/// Where the waves bend the item, on the refraction plane
	var/obj/effect/abstract/waterline/refraction
	/// A floating thing's reflection on the water in front of it, of the part of it above the water
	var/obj/effect/abstract/water_reflection/reflection
	/// For a floating thing, where the water comes up to on its sprite. See get_float_line()
	var/list/float_line

/datum/component/pool_sunk/Initialize(look, floating = FALSE, landing = FALSE)
	if(!isitem(parent))
		return COMPONENT_INCOMPATIBLE
	var/obj/item/sunk = parent
	src.floating = floating
	old_pixel_z = sunk.pixel_z
	old_pixel_w = sunk.pixel_w
	if(floating)
		float_line = get_float_line(sunk)
		add_floating_parts()
		GLOB.pool_things_afloat += src
	else
		// All of it is under the water, so the waves bend all of it
		refraction = add_part("refract_all", WATER_REFRACT_PLANE)
	// Left out of the reflection plane's mirror, which would put its reflection a tile too low
	parts += make_unmirrored_block()
	sunk.vis_contents += parts
	set_look(look)
	if(landing)
		land()
	else if(floating)
		bob()
	else
		sunk.pixel_z = old_pixel_z - POOL_SUNK_DROP

/datum/component/pool_sunk/Destroy(force)
	var/obj/item/sunk = parent
	GLOB.pool_things_afloat -= src
	sunk.vis_contents -= parts
	rings.Cut()
	refraction = null
	reflection?.stop_reflecting(sunk)
	reflection = null
	QDEL_LIST_CONTENTS(parts)
	sunk.remove_filter(list("pool_sunk", "pool_afloat"))
	// Back to where it was drawn before, which stops it bobbing too
	animate(sunk, pixel_z = old_pixel_z, pixel_w = old_pixel_w, time = 0.1 SECONDS)
	return ..()

/datum/component/pool_sunk/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))

/datum/component/pool_sunk/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_MOVABLE_MOVED)

/// Makes one of the things drawn with the item. On the item's own plane, unless it's given another
/datum/component/pool_sunk/proc/add_part(state, plane)
	var/obj/effect/abstract/waterline/part = new(null, state)
	if(plane)
		part.vis_flags = VIS_INHERIT_ID
		part.plane = plane
	parts += part
	return part

/// What's drawn with a floating thing, all of it at its waterline
/datum/component/pool_sunk/proc/add_floating_parts()
	var/across = float_line["across"]
	var/line_x = float_line["x"]
	var/line_y = float_line["y"]
	// The ring of water against its sides where it sits in the surface, half behind it and half in front
	var/obj/effect/abstract/waterline/back_ring = add_part("floater_ring_[across]_back")
	back_ring.vis_flags |= VIS_UNDERLAY
	rings = list(back_ring, add_part("floater_ring_[across]_front"))
	for(var/obj/effect/abstract/waterline/ring as anything in rings)
		ring.pixel_x = line_x
		ring.pixel_y = line_y
	// The waves bend the part of it that's under the water
	refraction = add_part("refract_float", WATER_REFRACT_PLANE)
	refraction.pixel_y = line_y
	// Small waves spread out from it as it bobs. On the hidden ripple plane, in a sprite 3x3 tiles big
	var/obj/effect/abstract/waterline/small_waves = add_part("float", WATER_RIPPLE_PLANE)
	small_waves.icon = 'icons/effects/water_ripple_wave.dmi'
	small_waves.pixel_x = line_x - 32
	small_waves.pixel_y = line_y - 32
	// Its shadow on the pool floor, down and to the right of it like a swimmer's
	var/obj/effect/abstract/waterline/shadow = add_part("floater_shadow", POOL_FLOOR_PLANE)
	shadow.pixel_x = line_x + 3
	shadow.pixel_y = line_y - 5
	// The sprite is 18 pixels wide
	shadow.transform = matrix(across / 18 + 0.1, 0, 0, 0, across / 18 + 0.1, 0)
	// Its reflection, upside down about its waterline: the top of the highest row that's under the water
	reflection = new(null, parent, line_y + POOL_FLOAT_SPRITE_LINE)
	parts += reflection

/// Draws the water over the item in the colours of the pool it's in
/datum/component/pool_sunk/proc/set_look(new_look)
	look = new_look
	var/obj/item/sunk = parent
	// Drawn over the item's own pixels only, so the tile round it isn't tinted twice
	if(floating)
		sunk.add_filter("pool_afloat", 20, layering_filter(icon = get_pool_filter_icon("floater_under_[look]"), y = float_line["y"], blend_mode = BLEND_INSET_OVERLAY))
	else
		sunk.add_filter("pool_sunk", 20, layering_filter(icon = get_pool_filter_icon("sunk_[look]"), blend_mode = BLEND_INSET_OVERLAY))

/// Where the item meets the water, in pixels right of and above the middle of its tile: where a splash and rings start
/datum/component/pool_sunk/proc/meets_water_at()
	var/obj/item/sunk = parent
	if(floating)
		return list(sunk.pixel_x + float_line["x"], sunk.pixel_y + float_line["y"])
	return list(sunk.pixel_x, sunk.pixel_y)

/// The item has just hit the water. A floating thing dips under and bobs back up, anything else goes down
/datum/component/pool_sunk/proc/land()
	var/obj/item/sunk = parent
	if(floating)
		// Under, back up higher than it floats, and down to rest. The water stays where it is, so the ring round it
		// and the waterline on it go the other way
		var/line_y = float_line["y"]
		animate(sunk, pixel_z = old_pixel_z - 4, time = 0.15 SECONDS, easing = QUAD_EASING | EASE_OUT, flags = ANIMATION_PARALLEL)
		animate(pixel_z = old_pixel_z + 3, time = 0.3 SECONDS, easing = SINE_EASING)
		animate(pixel_z = old_pixel_z, time = 0.35 SECONDS, easing = SINE_EASING)
		animate(sunk.get_filter("pool_afloat"), y = line_y + 4, time = 0.15 SECONDS, easing = QUAD_EASING | EASE_OUT)
		animate(y = line_y - 3, time = 0.3 SECONDS, easing = SINE_EASING)
		animate(y = line_y, time = 0.35 SECONDS, easing = SINE_EASING)
		for(var/obj/effect/abstract/waterline/ring as anything in rings)
			animate(ring, pixel_y = line_y + 4, time = 0.15 SECONDS, easing = QUAD_EASING | EASE_OUT)
			animate(pixel_y = line_y - 3, time = 0.3 SECONDS, easing = SINE_EASING)
			animate(pixel_y = line_y, time = 0.35 SECONDS, easing = SINE_EASING)
		addtimer(CALLBACK(src, PROC_REF(bob)), 0.8 SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE)
		return
	// The water closes over it from the bottom up as it goes under
	sunk.add_filter("pool_sunk", 20, layering_filter(icon = get_pool_filter_icon("sunk_[look]"), y = -26, blend_mode = BLEND_INSET_OVERLAY))
	sunk.transition_filter("pool_sunk", 0.45 SECONDS, list("y" = 0), QUAD_EASING | EASE_OUT)
	// It sinks to the bottom, rocking from side to side on its way down
	animate(sunk, pixel_z = old_pixel_z - POOL_SUNK_DROP, time = 0.7 SECONDS, easing = SINE_EASING | EASE_OUT, flags = ANIMATION_PARALLEL)
	animate(sunk, pixel_w = old_pixel_w + 2, time = 0.2 SECONDS, easing = SINE_EASING, flags = ANIMATION_PARALLEL)
	animate(pixel_w = old_pixel_w - 1.5, time = 0.25 SECONDS, easing = SINE_EASING)
	animate(pixel_w = old_pixel_w + 1, time = 0.25 SECONDS, easing = SINE_EASING)
	animate(pixel_w = old_pixel_w, time = 0.2 SECONDS, easing = SINE_EASING)
	// The waves bend it more the deeper it gets
	refraction.alpha = 0
	animate(refraction, alpha = 255, time = 0.6 SECONDS)
	// And bubbles come up from where it went
	var/obj/effect/temp_visual/sink_bubbles/bubbles = new(sunk.loc)
	bubbles.pixel_x += sunk.pixel_x
	bubbles.pixel_y += sunk.pixel_y

/// Up and down with the water and a little from side to side, each at its own pace so two things don't move as one
/datum/component/pool_sunk/proc/bob()
	var/obj/item/floater = parent
	var/turf/simulated/floor/beach/water/pool = floater.loc
	// Higher on a pool with its wave machine running
	var/rise = POOL_FLOAT_BOB
	if(istype(pool) && pool.waves)
		rise += round(4 * pool.waves.rest_energy(), 1)
	var/pace = rand(14, 20)
	animate(floater, pixel_z = old_pixel_z + rise, time = pace, loop = -1, easing = SINE_EASING)
	animate(pixel_z = old_pixel_z, time = pace, easing = SINE_EASING)
	animate(floater, pixel_w = old_pixel_w + 1, time = pace * 1.3, loop = -1, easing = SINE_EASING, flags = ANIMATION_PARALLEL)
	animate(pixel_w = old_pixel_w - 1, time = pace * 1.3, easing = SINE_EASING)
	// The water rises and falls a little round it
	var/line_y = float_line["y"]
	for(var/obj/effect/abstract/waterline/ring as anything in rings)
		animate(ring, pixel_y = line_y + 1, time = 1.6 SECONDS, loop = -1, easing = SINE_EASING)
		animate(pixel_y = line_y - 1, time = 1.6 SECONDS, easing = SINE_EASING)

/// A ring of waves is passing under a floating thing: it's lifted over it, and goes back to bobbing
/datum/component/pool_sunk/proc/ride_wave()
	if(!floating)
		return
	var/obj/item/floater = parent
	animate(floater, pixel_z = old_pixel_z + 4, time = 0.25 SECONDS, easing = SINE_EASING | EASE_OUT)
	animate(pixel_z = old_pixel_z - 1, time = 0.3 SECONDS, easing = SINE_EASING)
	animate(pixel_z = old_pixel_z, time = 0.25 SECONDS, easing = SINE_EASING)
	addtimer(CALLBACK(src, PROC_REF(bob)), 0.8 SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE)

/datum/component/pool_sunk/proc/on_moved(atom/movable/source, atom/old_loc, direction)
	SIGNAL_HANDLER // COMSIG_MOVABLE_MOVED
	check_water()

/// Keeps the look in step with the water the item is in, and takes it off once the item isn't in pool water any more
/datum/component/pool_sunk/proc/check_water()
	var/atom/movable/sunk = parent
	var/turf/simulated/floor/beach/water/pool = sunk.loc
	// Thrown out of the water, it's in the air until it lands
	if(!istype(pool) || !pool.water_look || sunk.throwing)
		qdel(src)
		return
	if(pool.water_look != look)
		set_look(pool.water_look)

#undef POOL_FLOAT_BOB
#undef POOL_SUNK_DROP
#undef POOL_FLOAT_SPRITE_LINE
