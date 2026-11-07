// This is where the fun begins.
// These are the main datums that emit light.

/datum/light_source
	/// The atom we're emitting light from (for example a mob if we're from a flashlight that's being held).
	var/atom/top_atom
	/// The atom that we belong to.
	var/atom/source_atom

	/// The turf under the above.
	var/turf/source_turf
	/// The turf the top_atom appears to over.
	var/turf/pixel_turf
	/// Intensity of the emitter light.
	var/light_power
	/// The range of the emitted light.
	var/light_range
	/// The colour of the light, string, decomposed by parse_light_color()
	var/light_color

	// Variables for keeping track of the colour.
	var/lum_r
	var/lum_g
	var/lum_b

	// The lumcount values used to apply the light.
	var/tmp/applied_lum_r
	var/tmp/applied_lum_g
	var/tmp/applied_lum_b

	/// Whether we have applied our light yet or not.
	var/applied = FALSE

	/// Whether we are queued for an update.
	var/needs_update = LIGHTING_NO_UPDATE


/datum/light_source/New(atom/owner, atom/top)
	source_atom = owner // Set our new owner.
	LAZYADD(source_atom.light_sources, src)
	if(top.flags_2 & BLOCKS_LIGHT_2) // If the top atom blocks light, then our owner becomes the topmost instead. This still allows atoms that block light to be a light of their own.
		top_atom = source_atom
	else
		top_atom = top
	if(top_atom != source_atom)
		LAZYADD(top_atom.light_sources, src)

	source_turf = top_atom
	pixel_turf = get_turf_pixel(top_atom) || source_turf
	if(!pixel_turf)
		stack_trace("[src] had no pixel turf assigned to it")
		qdel(src)
		return // Get us out of here before we do unneded operations

	light_power = source_atom.light_power
	light_range = source_atom.light_range
	light_color = source_atom.light_color

	PARSE_LIGHT_COLOR(src)

	update()

/datum/light_source/Destroy(force)
	remove_lum()
	SSlighting.engine_forget(src)
	if(source_atom)
		source_atom.delete_lights()
		LAZYREMOVE(source_atom.light_sources, src)

	if(top_atom)
		LAZYREMOVE(top_atom.light_sources, src)

	if(needs_update)
		SSlighting.sources_queue -= src

	. = ..()

// Yes this doesn't align correctly on anything other than 4 width tabs.
// If you want it to go switch everybody to elastic tab stops.
// Actually that'd be great if you could!
#define EFFECT_UPDATE(level)                \
	if(needs_update == LIGHTING_NO_UPDATE) \
		SSlighting.sources_queue += src; \
	if(needs_update < level)               \
		needs_update            = level;    \


// This proc will cause the light source to update the top atom, and add itself to the update queue.
/datum/light_source/proc/update(atom/new_top_atom)
	// This top atom is different.
	if(new_top_atom && new_top_atom != top_atom)
		if(top_atom != source_atom && top_atom.light_sources) // Remove ourselves from the light sources of that top atom.
			LAZYREMOVE(top_atom.light_sources, src)

		if(new_top_atom.flags_2 & BLOCKS_LIGHT_2)
			top_atom = source_atom
		else
			top_atom = new_top_atom

		if(top_atom != source_atom)
			LAZYADD(top_atom.light_sources, src) // Add ourselves to the light sources of our new top atom.

	EFFECT_UPDATE(LIGHTING_CHECK_UPDATE)

// Will force an update without checking if it's actually needed.
/datum/light_source/proc/force_update()
	EFFECT_UPDATE(LIGHTING_FORCE_UPDATE)

// Will cause the light source to recalculate turfs that were removed or added to visibility only.
/datum/light_source/proc/vis_update()
	EFFECT_UPDATE(LIGHTING_VIS_UPDATE)

/// Removes our light from every corner we're lighting.
/datum/light_source/proc/remove_lum()
	applied = FALSE
	if(engine_id)
		rustlibs_lighting_remove(engine_id)

/datum/light_source/proc/update_corners()
	var/update = FALSE
	var/atom/source_atom = src.source_atom

	if(QDELETED(source_atom))
		qdel(src)
		return

	if(source_atom.light_power != light_power)
		light_power = source_atom.light_power
		update = TRUE

	if(source_atom.light_range != light_range)
		light_range = source_atom.light_range
		update = TRUE

	if(!top_atom)
		top_atom = source_atom
		update = TRUE

	if(!light_range || !light_power)
		qdel(src)
		return

	if(isturf(top_atom))
		if(source_turf != top_atom)
			source_turf = top_atom
			pixel_turf = source_turf
			update = TRUE
	else if(top_atom.loc != source_turf)
		source_turf = top_atom.loc
		pixel_turf = get_turf_pixel(top_atom)
		update = TRUE
	else
		var/pixel_loc = get_turf_pixel(top_atom)
		if(pixel_loc != pixel_turf)
			pixel_turf = pixel_loc
			update = TRUE

	if(!isturf(source_turf))
		if(applied)
			remove_lum()
		return

	if(light_range && light_power && !applied)
		update = TRUE

	if(source_atom.light_color != light_color)
		light_color = source_atom.light_color
		PARSE_LIGHT_COLOR(src)
		update = TRUE

	else if(applied_lum_r != lum_r || applied_lum_g != lum_g || applied_lum_b != lum_b)
		update = TRUE

	if(update)
		needs_update = LIGHTING_CHECK_UPDATE
		applied = TRUE
		if(source_atom)
			source_atom.update_bloom()
	else if(needs_update == LIGHTING_CHECK_UPDATE)
		return //nothing's changed

	var/light_reach = CEILING(light_range, 1)
	var/oldlum = source_turf.luminosity
	source_turf.luminosity = light_reach + 1 // luminosity N only lights N - 1 tiles out, and view() needs the whole square lit
	var/list/seen = view(light_reach, source_turf)
	source_turf.luminosity = oldlum

	// The lighting engine works out what we give every corner we see. On a visibility update, the corners we already light keep what they have.
	SSlighting.engine_update(src, seen, needs_update == LIGHTING_VIS_UPDATE)

	applied_lum_r = lum_r
	applied_lum_g = lum_g
	applied_lum_b = lum_b

#undef EFFECT_UPDATE
