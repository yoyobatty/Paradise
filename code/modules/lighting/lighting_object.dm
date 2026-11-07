/datum/lighting_object
	/// the underlay we are currently applying to our turf to apply light
	var/mutable_appearance/current_underlay
	/// whether we are already in the SSlighting.objects_queue list
	var/needs_update = FALSE
	/// the turf that our light is applied to
	var/turf/affected_turf

/datum/lighting_object/New(turf/source)
	if(!isturf(source))
		qdel(src, force = TRUE)
		stack_trace("a lighting object was assigned to [source], a non turf!")
		return
	. = ..()
	current_underlay = mutable_appearance(LIGHTING_ICON, "transparent", -LIGHTING_LAYER, LIGHTING_PLANE, 255, RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM)

	affected_turf = source
	if(affected_turf.lighting_object)
		qdel(affected_turf.lighting_object, force = TRUE)
		stack_trace("a lighting object was assigned to a turf that already had a lighting object!")

	affected_turf.lighting_object = src
	affected_turf.luminosity = 0
	affected_turf.lighting_engine_push()

	for(var/turf/space/space_tile in RANGE_TURFS(1, affected_turf))
		space_tile.update_starlight()

	needs_update = TRUE
	SSlighting.objects_queue += src

/datum/lighting_object/Destroy(force)
	if(!force)
		return QDEL_HINT_LETMELIVE
	SSlighting.objects_queue -= src
	if(isturf(affected_turf))
		affected_turf.lighting_object = null
		affected_turf.luminosity = 1
		affected_turf.underlays -= current_underlay
		affected_turf.lighting_engine_push()
	affected_turf = null
	return ..()

/// Draws what the lighting engine has for our turf's corners
/datum/lighting_object/proc/update()
	var/list/values = list()
	rustlibs_lighting_object(affected_turf, values)
	draw(values[1], values[2], values[3], values[4], values[5], values[6], values[7], values[8], values[9], values[10], values[11], values[12], values[13])

/// Draws the four corners' colours (red = SW, green = SE, blue = NW, alpha = NE), max being the brightest of them
/datum/lighting_object/proc/draw(rr, rg, rb, gr, gg, gb, br, bg, bb, ar, ag, ab, max)
	#if LIGHTING_SOFT_THRESHOLD != 0
	var/set_luminosity = max > LIGHTING_SOFT_THRESHOLD
	#else
	// Because of floating points™?, it won't even be a flat 0.
	// This number is mostly arbitrary.
	var/set_luminosity = max > 1e-6
	#endif

	if((rr & gr & br & ar) && (rg + gg + bg + ag + rb + gb + bb + ab == 8))
		// anything that passes the first case is very likely to pass the second, and addition is a little faster in this case
		affected_turf.underlays -= current_underlay
		current_underlay.icon_state = "lighting_transparent"
		current_underlay.color = null
		affected_turf.underlays += current_underlay
	else if(!set_luminosity)
		affected_turf.underlays -= current_underlay
		current_underlay.icon_state = "lighting_dark"
		current_underlay.color = null
		affected_turf.underlays += current_underlay
	else
		affected_turf.underlays -= current_underlay
		current_underlay.icon_state = null
		current_underlay.color = list(
			rr, rg, rb, 00,
			gr, gg, gb, 00,
			br, bg, bb, 00,
			ar, ag, ab, 00,
			00, 00, 00, 01
		)
		affected_turf.underlays += current_underlay

	affected_turf.luminosity = set_luminosity
