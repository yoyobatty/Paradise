/// All the following lights. Turfs check these for light that doesn't come from their corners.
GLOBAL_LIST_EMPTY(following_lights)

/**
 * A light source for lights that get carried around, like flashlights.
 *
 * An ordinary light relights every corner in range each time it moves, and every turf around those corners gets redrawn.
 * This one doesn't light corners at all. It's one glow on the lighting plane that moves with whatever carries it,
 * with the turfs it can't reach shaded out.
 *
 * An atom gets one by setting light_follows, see [/atom/proc/light_source_type].
 */
/datum/light_source/following
	/// The object that shows our glow and shadows
	var/atom/movable/following_light/glow
	/// The turf we last worked out the lit turfs from. Null while the light is hidden.
	var/turf/lit_from
	/// Whether the light reaches each turf in the square around lit_from, row by row from the bottom left
	var/list/lit_turfs
	/// Set when something nearby starts or stops blocking light, so the lit turfs get worked out again
	var/shadows_stale = FALSE

/datum/light_source/following/New(atom/owner, atom/top)
	glow = new(null)
	GLOB.following_lights += src
	..()

/datum/light_source/following/Destroy(force)
	GLOB.following_lights -= src
	lit_from = null
	if(glow)
		qdel(glow, force = TRUE)
		glow = null
	return ..()

/datum/light_source/following/update(atom/new_top_atom)
	..()
	// Move the glow now instead of waiting for SSlighting, so it keeps up with the carrier
	follow_top_atom()

/datum/light_source/following/vis_update()
	shadows_stale = TRUE
	..()

/datum/light_source/following/force_update()
	shadows_stale = TRUE
	..()

/// Moves the glow to top_atom's turf, or hides it if top_atom isn't on a turf, like a mob in a locker
/datum/light_source/following/proc/follow_top_atom()
	if(QDELETED(glow))
		return
	var/atom/movable/carrier = top_atom
	if(!istype(carrier) || !isturf(carrier.loc))
		glow.loc = null
		lit_from = null
		return
	var/turf/old_turf = glow.loc
	var/turf/new_turf = carrier.loc
	if(old_turf == new_turf)
		return
	// A step to the next turf slides over the time the carrier's glide takes, anything else is a jump
	var/step_time = 0
	if(old_turf && old_turf.z == new_turf.z && get_dist(old_turf, new_turf) == 1 && carrier.glide_size > 0)
		// glide_size is in pixels per tick
		step_time = world.icon_size / carrier.glide_size * world.tick_lag
	glow.move_to(new_turf, step_time)
	// No size yet, update_corners() hasn't run
	if(!glow.reach)
		return
	// Redo the shadows in the same tick as the move
	if(step_time)
		find_lit_turfs(new_turf.x - old_turf.x, new_turf.y - old_turf.y, step_time)
	else
		find_lit_turfs()

/**
 * Works out which turfs in range the light reaches, and shades out the rest.
 *
 * Arguments:
 * * across - How many turfs east we moved since last time
 * * up - How many turfs north we moved since last time
 * * fade_time - How long the shadows take to change, 0 for straight away
 */
/datum/light_source/following/proc/find_lit_turfs(across = 0, up = 0, fade_time = 0)
	var/turf/centre = glow.loc
	var/reach = glow.reach
	var/size = reach * 2 + 1
	var/left = centre.x - reach
	var/bottom = centre.y - reach
	var/list/lit = new /list(size * size)
	// Opaque turfs can be lit but don't light their corners, same as with an ordinary light
	var/list/lights_corners = new /list(size * size)
	// view() from a turf only returns lit turfs, and our glow lights the turfs it reaches
	for(var/turf/seen in view(reach, centre))
		var/i = (seen.x - left) + (seen.y - bottom) * size + 1
		lit[i] = TRUE
		if(!IS_OPAQUE_TURF(seen))
			lights_corners[i] = TRUE
	lit_from = centre
	lit_turfs = lit
	shadows_stale = FALSE
	glow.set_shadows(lights_corners, across, up, fade_time)

/// Called when a turf starts or stops blocking light, see [/turf/proc/reconsider_lights]
/datum/light_source/following/proc/turf_opacity_changed(turf/changed)
	if(lit_from && lit_from.z == changed.z && get_dist(lit_from, changed) <= light_range)
		vis_update()

/// How much light we put on a turf, on the same scale as [/turf/proc/get_lumcount]
/datum/light_source/following/proc/get_lum_on(turf/lit)
	var/turf/centre = lit_from
	if(!centre || centre.z != lit.z)
		return 0
	var/across = lit.x - centre.x
	var/up = lit.y - centre.y
	// The same reach lit_turfs was worked out with
	var/reach = glow.reach
	if(across > reach || across < -reach || up > reach || up < -reach)
		return 0
	if(!lit_turfs[(across + reach) + (up + reach) * (reach * 2 + 1) + 1])
		return 0
	// Same falloff as the corners of an ordinary light
	return max(0, 1 - sqrt(across * across + up * up + LIGHTING_HEIGHT) / light_range) * light_power * (lum_r + lum_g + lum_b) / 3

// We don't light corners. SSlighting calls this when something about us changed.
/datum/light_source/following/update_corners()
	var/atom/source = source_atom
	if(QDELETED(source))
		qdel(src)
		return

	light_power = source.light_power
	light_range = source.light_range
	if(!light_range || !light_power)
		qdel(src)
		return
	if(source.light_color != light_color)
		light_color = source.light_color
		PARSE_LIGHT_COLOR(src)

	follow_top_atom()
	if(!glow.loc)
		return
	if(glow.set_light_look(light_range, light_power, light_color))
		// A new size starts over with new shadows
		find_lit_turfs()
	else if(shadows_stale || lit_from != glow.loc)
		// Something like a door changed what we can reach, so fade the shadows over
		find_lit_turfs(fade_time = FOLLOWING_LIGHT_FADE_TIME)

/**
 * Shows a [/datum/light_source/following]: its glow, with the shadows over it.
 *
 * It sits on the carrier's turf as its own object instead of being part of the carrier,
 * so the light still shows to someone who can see the lit turfs but not the carrier.
 * It doesn't glide, so the shadows stay lined up with the walls. Only the glow slides along with the carrier.
 */
/atom/movable/following_light
	plane = LIGHTING_PLANE
	layer = LIGHTING_LAYER + 0.2
	blend_mode = BLEND_ADD
	// KEEP_TOGETHER so the shadows only shade our own glow, and not the lighting under it
	appearance_flags = KEEP_TOGETHER | RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	animate_movement = NO_STEPS
	anchored = TRUE
	simulated = FALSE
	/// The light's range
	var/range = 0
	/// How many whole turfs the light reaches
	var/reach = 0
	/// How bright the light is
	var/power = 0
	/// The round glow picture. It and the two below are in our vis_contents.
	var/atom/movable/following_light_part/glow
	/// Shadows that are fading out
	var/atom/movable/following_light_part/leaving
	/// Shadows that are fading in
	var/atom/movable/following_light_part/arriving
	/// Which corners are dark on each turf of the square in range, see [/atom/movable/following_light/proc/make_cover]
	var/list/cover
	/// The key our cover is stored under in covers
	var/cover_key
	/// Every cover worked out so far with its pictures, by range and lit turfs
	var/static/list/covers = list()
	/// The pictures for going from one cover to another, since the same steps past the same walls keep coming up
	var/static/list/fades = list()
	/// Every shadow picture made so far, by where it goes and which corners are dark
	var/static/list/cover_pictures = list()
	/// Whether the glow touches each turf of the square in range, by range
	var/static/list/touched = list()

/atom/movable/following_light/Destroy(force)
	// Only our light source gets rid of us
	if(!force)
		return QDEL_HINT_LETMELIVE
	vis_contents.Cut()
	QDEL_NULL(glow)
	QDEL_NULL(leaving)
	QDEL_NULL(arriving)
	return ..()

/// Makes the glow and the two sets of fading shadows
/atom/movable/following_light/proc/make_parts()
	glow = new(null)
	glow.icon = 'icons/effects/light_352.dmi'
	glow.icon_state = "light"
	// The picture is 11 tiles wide, this puts its middle on our tile
	glow.pixel_x = -FOLLOWING_LIGHT_GLOW_OFFSET
	glow.pixel_y = -FOLLOWING_LIGHT_GLOW_OFFSET
	glow.layer = LIGHTING_LAYER + 0.1
	leaving = new(null)
	arriving = new(null)
	vis_contents += list(glow, leaving, arriving)

/// Moves to new_turf. With a step_time, the glow starts from our old turf and slides over in that time.
/atom/movable/following_light/proc/move_to(turf/new_turf, step_time)
	if(!glow)
		make_parts()
	var/turf/old_turf = loc
	loc = new_turf
	if(!step_time)
		animate(glow, pixel_x = -FOLLOWING_LIGHT_GLOW_OFFSET, pixel_y = -FOLLOWING_LIGHT_GLOW_OFFSET, time = 0)
		return
	glow.pixel_x = -FOLLOWING_LIGHT_GLOW_OFFSET + (old_turf.x - new_turf.x) * world.icon_size
	glow.pixel_y = -FOLLOWING_LIGHT_GLOW_OFFSET + (old_turf.y - new_turf.y) * world.icon_size
	animate(glow, pixel_x = -FOLLOWING_LIGHT_GLOW_OFFSET, pixel_y = -FOLLOWING_LIGHT_GLOW_OFFSET, time = step_time)

/**
 * Sets the light's size, brightness and colour. Returns TRUE if the size changed.
 *
 * The glow is sized to fade out where an ordinary light of the same range does. It stays brighter further out than
 * an ordinary light, so its middle is turned down to [FOLLOWING_LIGHT_GLOW_BRIGHTNESS] to give the same light overall.
 */
/atom/movable/following_light/proc/set_light_look(new_range, new_power, new_color)
	color = new_color
	if(new_range == range && new_power == power)
		return FALSE
	if(!glow)
		make_parts()
	var/brightness = FOLLOWING_LIGHT_GLOW_BRIGHTNESS * (1 - sqrt(LIGHTING_HEIGHT) / new_range) * new_power
	// The picture is white and fades out by its alpha, so the alpha sets how bright it is
	glow.color = list(
		1, 0, 0, 0,
		0, 1, 0, 0,
		0, 0, 1, 0,
		0, 0, 0, brightness,
		0, 0, 0, 0
	)
	power = new_power
	if(new_range == range)
		return FALSE
	range = new_range
	reach = CEILING(range, 1)
	// This lets people see what's on the turfs we light. A luminosity of N only reaches N - 1 turfs.
	luminosity = reach + 1
	// How many tiles out an ordinary light of this range fades to nothing
	var/glow_edge = sqrt(range * range - LIGHTING_HEIGHT)
	var/matrix/glow_size = matrix()
	glow_size.Scale(glow_edge * world.icon_size / FOLLOWING_LIGHT_GLOW_EDGE)
	glow.transform = glow_size
	if(!touched["[range]"])
		find_touched(glow_edge)
	// The old shadows were for the old size
	cover = null
	return TRUE

/**
 * Shades the glow out of the turfs the light doesn't reach.
 *
 * Arguments:
 * * lights_corners - Whether each turf of the square in range is lit and lights its corners
 * * across - How many turfs east we moved since last time
 * * up - How many turfs north we moved since last time
 * * fade_time - How long shadows that change take to fade, 0 for straight away
 */
/atom/movable/following_light/proc/set_shadows(list/lights_corners, across, up, fade_time)
	var/new_key = "[range]:[jointext(lights_corners, ",")]"
	var/list/cached = covers[new_key]
	if(!cached)
		// Walking down a corridor only gives a few patterns, but a whole round gives no end of them
		if(length(covers) >= FOLLOWING_LIGHT_MAX_KEPT_SHADOWS)
			covers.Cut()
		var/list/new_cover = make_cover(lights_corners)
		cached = list(new_cover, all_pictures(new_cover))
		covers[new_key] = cached
	var/list/old_cover = cover
	var/old_key = cover_key
	cover = cached[1]
	cover_key = new_key

	if(!old_cover || !fade_time)
		// Nothing to fade from, or no time to fade
		overlays = cached[2]
		leaving.overlays.Cut()
		arriving.overlays.Cut()
		return
	if(old_key == new_key && !across && !up)
		return

	var/fade_key = "[old_key]>[new_key]:[across],[up]"
	var/list/fade = fades[fade_key]
	if(!fade)
		if(length(fades) >= FOLLOWING_LIGHT_MAX_KEPT_SHADOWS)
			fades.Cut()
		fade = make_fade(old_cover, cover, across, up)
		fades[fade_key] = fade
	// Shadows that stay are on us so they don't flicker, the ones that change fade in and out on their own
	overlays = fade[1]
	leaving.overlays = fade[2]
	arriving.overlays = fade[3]
	leaving.alpha = 255
	arriving.alpha = 0
	animate(leaving, alpha = 0, time = fade_time)
	animate(arriving, alpha = 255, time = fade_time)

/**
 * Works out which corners of each turf in range are dark, from which turfs light their corners.
 *
 * This works like an ordinary light: a lit turf that doesn't block light lights its four corners,
 * and each turf is shaded between its corners. So a wall is lit on the side facing the light,
 * and the light fades out across the turfs at the edge of what it can reach.
 */
/atom/movable/following_light/proc/make_cover(list/lights_corners)
	var/size = reach * 2 + 1
	// Corners have one more to a row than turfs do
	var/corners_wide = size + 1
	var/list/corner_lit = new /list(corners_wide * corners_wide)
	for(var/row in 1 to size)
		for(var/column in 1 to size)
			if(!lights_corners[column + (row - 1) * size])
				continue
			var/south_west = column + (row - 1) * corners_wide
			corner_lit[south_west] = TRUE
			corner_lit[south_west + 1] = TRUE
			corner_lit[south_west + corners_wide] = TRUE
			corner_lit[south_west + corners_wide + 1] = TRUE

	var/list/reach_touched = touched["[range]"]
	var/list/new_cover = new /list(size * size)
	for(var/row in 1 to size)
		for(var/column in 1 to size)
			var/i = column + (row - 1) * size
			// The glow doesn't reach this turf at all, so it needs no shadow
			if(!reach_touched[i])
				continue
			var/south_west = column + (row - 1) * corners_wide
			var/dark_corners = NONE
			if(!corner_lit[south_west])
				dark_corners |= FOLLOWING_LIGHT_DARK_SOUTHWEST
			if(!corner_lit[south_west + 1])
				dark_corners |= FOLLOWING_LIGHT_DARK_SOUTHEAST
			if(!corner_lit[south_west + corners_wide])
				dark_corners |= FOLLOWING_LIGHT_DARK_NORTHWEST
			if(!corner_lit[south_west + corners_wide + 1])
				dark_corners |= FOLLOWING_LIGHT_DARK_NORTHEAST
			if(dark_corners)
				new_cover[i] = dark_corners
	return new_cover

/// Every shadow picture for a cover
/atom/movable/following_light/proc/all_pictures(list/whole_cover)
	. = list()
	var/size = reach * 2 + 1
	for(var/row in 1 to size)
		for(var/column in 1 to size)
			var/dark_corners = whole_cover[column + (row - 1) * size]
			if(dark_corners)
				. += cover_picture(column - 1 - reach, row - 1 - reach, dark_corners)

/**
 * Splits two covers into the shadows that stay, the ones that go and the ones that come.
 *
 * The old cover is around where we were, so it's shifted by how far we moved to line up the same turfs.
 * Returns list(staying, going, coming).
 */
/atom/movable/following_light/proc/make_fade(list/old_cover, list/new_cover, across, up)
	var/list/staying = list()
	var/list/going = list()
	var/list/coming = list()
	var/size = reach * 2 + 1
	// One turf further out on each side, for old shadows just outside the new square
	for(var/row in 0 to size + 1)
		for(var/column in 0 to size + 1)
			var/new_corners
			if(row >= 1 && row <= size && column >= 1 && column <= size)
				new_corners = new_cover[column + (row - 1) * size]
			// Where this turf was in the old square
			var/old_row = row + up
			var/old_column = column + across
			var/old_corners
			if(old_row >= 1 && old_row <= size && old_column >= 1 && old_column <= size)
				old_corners = old_cover[old_column + (old_row - 1) * size]
			if(new_corners == old_corners)
				if(new_corners)
					staying += cover_picture(column - 1 - reach, row - 1 - reach, new_corners)
				continue
			if(new_corners)
				coming += cover_picture(column - 1 - reach, row - 1 - reach, new_corners)
			if(old_corners)
				going += cover_picture(column - 1 - reach, row - 1 - reach, old_corners)
	return list(staying, going, coming)

/// The shadow picture for the turf that many turfs east and north of us, with those corners dark
/atom/movable/following_light/proc/cover_picture(across, up, dark_corners)
	var/picture_key = "[across],[up],[dark_corners]"
	var/mutable_appearance/picture = cover_pictures[picture_key]
	if(picture)
		return picture
	if(dark_corners == FOLLOWING_LIGHT_DARK_ALL)
		picture = mutable_appearance(LIGHTING_ICON, "lighting_dark")
	else
		// Each colour channel of the lighting icon is how close a pixel is to one corner, in the order below.
		// This turns it black, solid at the dark corners and clear at the lit ones, like the shading on a lit turf.
		picture = mutable_appearance(LIGHTING_ICON)
		picture.color = list(
			0, 0, 0, (dark_corners & FOLLOWING_LIGHT_DARK_SOUTHWEST) ? 1 : 0,
			0, 0, 0, (dark_corners & FOLLOWING_LIGHT_DARK_SOUTHEAST) ? 1 : 0,
			0, 0, 0, (dark_corners & FOLLOWING_LIGHT_DARK_NORTHWEST) ? 1 : 0,
			0, 0, 0, (dark_corners & FOLLOWING_LIGHT_DARK_NORTHEAST) ? 1 : 0,
			0, 0, 0, 0
		)
	picture.pixel_x = across * world.icon_size
	picture.pixel_y = up * world.icon_size
	cover_pictures[picture_key] = picture
	return picture

/// Works out which turfs of the square the glow touches at all, for our range. glow_edge is how many tiles out the glow fades to nothing.
/atom/movable/following_light/proc/find_touched(glow_edge)
	var/list/reach_touched = list()
	for(var/up in -reach to reach)
		for(var/across in -reach to reach)
			// How close this turf comes to the middle
			var/near_x = max(abs(across) - 0.5, 0)
			var/near_y = max(abs(up) - 0.5, 0)
			reach_touched += (sqrt(near_x * near_x + near_y * near_y) < glow_edge)
	touched["[range]"] = reach_touched

/// A part of a [/atom/movable/following_light] that moves or fades by itself: the glow, or shadows fading in or out
/atom/movable/following_light_part
	plane = FLOAT_PLANE
	layer = LIGHTING_LAYER + 0.3
	vis_flags = VIS_INHERIT_PLANE | VIS_INHERIT_ID
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE
	simulated = FALSE
