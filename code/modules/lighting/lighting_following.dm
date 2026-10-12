/// Every following light there is. Turfs look through it for the light they get from them.
GLOBAL_LIST_EMPTY(following_lights)

/**
 * A light source for things that get carried about, like flashlights.
 *
 * An ordinary light source works out every corner in range each time it moves, and every turf around
 * those corners gets redrawn. This one leaves the turfs alone. It shows as a single glow on the lighting plane
 * that moves along with whatever is carrying it. Turfs in range that the light can't reach are shaded out of the glow.
 *
 * An atom gets one by setting light_follows, see [/atom/proc/light_source_type].
 */
/datum/light_source/following
	/// What shows our light
	var/atom/movable/following_light/glow
	/// The turf our light was last worked out from. Null while the light can't be seen.
	var/turf/lit_from
	/// Whether the light reaches each turf of the square in range of lit_from, a row at a time from the bottom left
	var/list/lit_turfs
	/// TRUE when something near us started or stopped blocking light, so the lit turfs need working out again
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
	// The glow goes with whatever is carrying us now, it can't wait for the lighting subsystem
	follow_top_atom()

/datum/light_source/following/vis_update()
	shadows_stale = TRUE
	..()

/datum/light_source/following/force_update()
	shadows_stale = TRUE
	..()

/// Puts the glow on top_atom's turf. Hides it if top_atom isn't on one, like a mob that got into a locker.
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
	// A step to the next turf is slid and faded over the time the carrier's glide takes. Anything further is a jump.
	var/step_time = 0
	if(old_turf && old_turf.z == new_turf.z && get_dist(old_turf, new_turf) == 1 && carrier.glide_size > 0)
		// A glide covers glide_size pixels a tick
		step_time = world.icon_size / carrier.glide_size * world.tick_lag
	glow.move_to(new_turf, step_time)
	if(!glow.reach)
		return
	// The shadows are for the turf we are on, so they change in the same tick as the move
	if(step_time)
		find_lit_turfs(new_turf.x - old_turf.x, new_turf.y - old_turf.y, step_time)
	else
		find_lit_turfs()

/**
 * Works out which turfs in range the light reaches, and shades the rest.
 *
 * Arguments:
 * * across - How many turfs east we have moved since the shadows were last worked out
 * * up - How many turfs north
 * * fade_time - How long the shadows take to change, 0 for at once
 */
/datum/light_source/following/proc/find_lit_turfs(across = 0, up = 0, fade_time = 0)
	var/turf/centre = glow.loc
	var/reach = glow.reach
	var/size = reach * 2 + 1
	var/left = centre.x - reach
	var/bottom = centre.y - reach
	var/list/lit = new /list(size * size)
	// The lit turfs that light their corners. Ones that block light don't, the same as with an ordinary light.
	var/list/lights_corners = new /list(size * size)
	// view() from a turf only returns what is lit. The glow lights the turfs it reaches, so that's what comes back.
	for(var/turf/seen in view(reach, centre))
		var/i = (seen.x - left) + (seen.y - bottom) * size + 1
		lit[i] = TRUE
		if(!IS_OPAQUE_TURF(seen))
			lights_corners[i] = TRUE
	lit_from = centre
	lit_turfs = lit
	shadows_stale = FALSE
	glow.set_shadows(lights_corners, across, up, fade_time)

/// A turf near us started or stopped blocking light
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
	var/reach = CEILING(light_range, 1)
	if(across > reach || across < -reach || up > reach || up < -reach)
		return 0
	if(!lit_turfs[(across + reach) + (up + reach) * (reach * 2 + 1) + 1])
		return 0
	// The same falloff the corners use
	return max(0, 1 - sqrt(across * across + up * up + LIGHTING_HEIGHT) / light_range) * light_power * (lum_r + lum_g + lum_b) / 3

// We don't light corners. This is where the lighting subsystem sends us when something about us changed.
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
		// A different size of glow starts again with new shadows
		find_lit_turfs()
	else if(shadows_stale || lit_from != glow.loc)
		// Something like a door changed what we can reach, so its shadow fades in or out
		find_lit_turfs(fade_time = FOLLOWING_LIGHT_FADE_TIME)

/**
 * What shows a [/datum/light_source/following]: its shadows, with the glow under them.
 *
 * Sits on the turf of whatever is carrying the light, and adds the glow less the shadows to the lighting plane.
 * It is its own object, and not part of the carrier, so the light still shows to someone who can see the lit turfs but not the carrier.
 * It doesn't glide. The shadows have to stay lined up with the walls, so only the glow slides to keep up with the carrier.
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
	/// How many whole tiles the light reaches
	var/reach = 0
	/// How strong the light is
	var/power = 0
	/// The round glow. It and the two below are drawn as part of us.
	var/atom/movable/following_light_part/glow
	/// The shadows that are fading out
	var/atom/movable/following_light_part/leaving
	/// The shadows that are fading in
	var/atom/movable/following_light_part/arriving
	/// Which corners are dark, for each turf of the square in range. See [/atom/movable/following_light/proc/make_cover]
	var/list/cover
	/// The key cover is kept under in covers
	var/cover_key
	/// The cover for each range and pattern of lit turfs that has come up, with all its pictures
	var/static/list/covers = list()
	/// The pictures for changing from one cover to another, as the same step past the same walls comes up over and over
	var/static/list/fades = list()
	/// Each shadow picture that has been needed, by where it goes and which corners are dark
	var/static/list/cover_pictures = list()
	/// Whether the glow touches each turf of the square in reach, for each range
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

/// Makes the glow and the two lots of fading shadows, and draws them as part of us
/atom/movable/following_light/proc/make_parts()
	glow = new(null)
	glow.icon = 'icons/effects/light_352.dmi'
	glow.icon_state = "light"
	// The picture is 11 tiles wide with the light in the middle
	glow.pixel_x = -FOLLOWING_LIGHT_GLOW_OFFSET
	glow.pixel_y = -FOLLOWING_LIGHT_GLOW_OFFSET
	glow.layer = LIGHTING_LAYER + 0.1
	leaving = new(null)
	arriving = new(null)
	vis_contents += list(glow, leaving, arriving)

/// Moves to a turf. With a step_time the glow starts where we were and slides over in that time, to keep up with whatever is carrying the light.
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
 * Sets the size, strength and colour of the light. Returns TRUE if the size changed.
 *
 * The glow picture is sized to fade out where an ordinary light of the same range does. It stays bright
 * further out from its middle than an ordinary light, so it is turned down to [FOLLOWING_LIGHT_GLOW_BRIGHTNESS]
 * of one's middle, which makes the light it adds over the whole patch come out the same.
 */
/atom/movable/following_light/proc/set_light_look(new_range, new_power, new_color)
	color = new_color
	if(new_range == range && new_power == power)
		return FALSE
	if(!glow)
		make_parts()
	var/brightness = FOLLOWING_LIGHT_GLOW_BRIGHTNESS * (1 - sqrt(LIGHTING_HEIGHT) / new_range) * new_power
	// The picture is white and fades by its alpha, so the alpha is what gets turned up or down
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
	// This is what lets players see things on the turfs we light. A luminosity of N only reaches N - 1 turfs.
	luminosity = reach + 1
	// How many tiles out an ordinary light of this range fades to nothing
	var/glow_edge = sqrt(range * range - LIGHTING_HEIGHT)
	var/matrix/glow_size = matrix()
	glow_size.Scale(glow_edge * world.icon_size / FOLLOWING_LIGHT_GLOW_EDGE)
	glow.transform = glow_size
	if(!touched["[range]"])
		find_touched(glow_edge)
	// The old shadows were for another size
	cover = null
	return TRUE

/**
 * Shades the glow out of the turfs the light doesn't reach.
 *
 * Arguments:
 * * lights_corners - Whether each turf of the square in range is lit and lights its corners
 * * across - How many turfs east we have moved since the last time
 * * up - How many turfs north
 * * fade_time - How long shadows that come or go take to fade, 0 to change at once
 */
/atom/movable/following_light/proc/set_shadows(list/lights_corners, across, up, fade_time)
	var/new_key = "[range]:[jointext(lights_corners, ",")]"
	var/list/kept = covers[new_key]
	if(!kept)
		// A walk down a corridor only has a few patterns, but a whole round has no end of them
		if(length(covers) >= FOLLOWING_LIGHT_MAX_KEPT_SHADOWS)
			covers.Cut()
		var/list/made = make_cover(lights_corners)
		kept = list(made, all_pictures(made))
		covers[new_key] = kept
	var/list/old_cover = cover
	var/old_key = cover_key
	var/list/new_cover = kept[1]
	cover = new_cover
	cover_key = new_key

	if(!old_cover || !fade_time)
		// Nothing to fade from, or no time to
		overlays = kept[2]
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
		fade = make_fade(old_cover, new_cover, across, up)
		fades[fade_key] = fade
	// The shadows that stay are ours and don't flicker. The ones going and coming fade on their own.
	overlays = fade[1]
	leaving.overlays = fade[2]
	arriving.overlays = fade[3]
	leaving.alpha = 255
	arriving.alpha = 0
	animate(leaving, alpha = 0, time = fade_time)
	animate(arriving, alpha = 255, time = fade_time)

/**
 * Works out which corners of each turf of the square in range are dark, for a pattern of lit turfs.
 *
 * It follows what an ordinary light does: a lit turf that doesn't block light lights its four corners, and every
 * turf is shaded between its corners. So a wall is lit on the side the light is on, and light fades out over
 * the turf past the edge of what the light can reach.
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
			// The turfs too far for the glow to touch need nothing
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

/// Every picture of a cover
/atom/movable/following_light/proc/all_pictures(list/whole_cover)
	. = list()
	var/size = reach * 2 + 1
	for(var/row in 1 to size)
		for(var/column in 1 to size)
			var/dark_corners = whole_cover[column + (row - 1) * size]
			if(dark_corners)
				. += cover_picture(column - 1 - reach, row - 1 - reach, dark_corners)

/**
 * Sorts the pictures of two covers into the ones that stay, the ones that go and the ones that come.
 *
 * The new cover is around where we are now and the old one around where we were, so the old one is
 * shifted by how far we moved to compare the same turfs.
 * Returns list(staying, going, coming).
 */
/atom/movable/following_light/proc/make_fade(list/old_cover, list/new_cover, across, up)
	var/list/staying = list()
	var/list/going = list()
	var/list/coming = list()
	var/size = reach * 2 + 1
	// One turf further out each way, for the old shadows that are just outside the new square
	for(var/row in 0 to size + 1)
		for(var/column in 0 to size + 1)
			var/new_corners
			if(row >= 1 && row <= size && column >= 1 && column <= size)
				new_corners = new_cover[column + (row - 1) * size]
			// The same turf was this much further along in the old square
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
		// The lighting icon has how near each pixel is to each corner of the turf in its red, green, blue and alpha,
		// in the order below. This makes black of it that is solid at the dark corners and clear at the lit ones,
		// the way a lit turf is shaded between its corners.
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

/// Works out which turfs of the square in range the glow touches at all, for our range. glow_edge is how many tiles out the glow fades to nothing.
/atom/movable/following_light/proc/find_touched(glow_edge)
	var/list/reach_touched = list()
	for(var/up in -reach to reach)
		for(var/across in -reach to reach)
			// How close this turf gets to the middle
			var/near_x = max(abs(across) - 0.5, 0)
			var/near_y = max(abs(up) - 0.5, 0)
			reach_touched += (sqrt(near_x * near_x + near_y * near_y) < glow_edge)
	touched["[range]"] = reach_touched

/// A part of a [/atom/movable/following_light] that moves or fades on its own: the glow, or shadows that are coming or going
/atom/movable/following_light_part
	plane = FLOAT_PLANE
	layer = LIGHTING_LAYER + 0.3
	vis_flags = VIS_INHERIT_PLANE | VIS_INHERIT_ID
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE
	simulated = FALSE
