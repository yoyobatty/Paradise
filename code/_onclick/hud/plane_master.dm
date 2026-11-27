/atom/movable/screen/plane_master
	screen_loc = "CENTER"
	icon_state = "blank"
	appearance_flags = PLANE_MASTER|NO_CLIENT_COLOR
	blend_mode = BLEND_OVERLAY
	var/show_alpha = 255
	var/hide_alpha = 0
	/// Is this plane master only for lava's bloom, which is off for players with no lava nearby?
	var/lava_effect = FALSE
	/// Is lava's bloom off for this player right now? It starts off: see /datum/lava_effects_watcher
	var/lava_effects_off = TRUE

/atom/movable/screen/plane_master/proc/Show(override)
	alpha = override || show_alpha

/atom/movable/screen/plane_master/proc/Hide(override)
	alpha = override || hide_alpha

//Why do plane masters need a backdrop sometimes? Read http://www.byond.com/forum/?post=2141928
//Trust me, you need one. Period. If you don't think you do, you're doing something extremely wrong.
/atom/movable/screen/plane_master/proc/backdrop(mob/mymob)
	addtimer(CALLBACK(src, TYPE_PROC_REF(/atom, add_filter), "displace", 1, displacement_map_filter(render_source = GRAVITY_PULSE_RENDER_TARGET, size = 10)), 2 SECONDS)//Why a timer vs just apply on initialize / async? I don't know. It just can't be, neither works correctly. Don't lower below 2 seconds unless you can see effects through walls with no issue.

/atom/movable/screen/plane_master/floor
	name = "floor plane master"
	plane = FLOOR_PLANE
	appearance_flags = PLANE_MASTER

/atom/movable/screen/plane_master/game_world
	name = "game world plane master"
	plane = GAME_PLANE
	appearance_flags = PLANE_MASTER

/atom/movable/screen/plane_master/game_world/backdrop(mob/mymob)
	. = ..() //if you delete it so help me god
	clear_filters()
	if(istype(mymob) && mymob.client && mymob.client.prefs && (mymob.client.prefs.toggles & PREFTOGGLE_AMBIENT_OCCLUSION))
		add_filter("AO", 1, drop_shadow_filter(x = 0, y = -2, size = 4, color = "#04080FAA"))

/atom/movable/screen/plane_master/lighting
	name = "lighting plane master"
	plane = LIGHTING_PLANE
	appearance_flags = PLANE_MASTER
	blend_mode = BLEND_MULTIPLY
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/atom/movable/screen/plane_master/lighting/backdrop(mob/mymob)
	. = ..()
	mymob.overlay_fullscreen("lighting_backdrop_lit", /atom/movable/screen/fullscreen/stretch/lighting_backdrop/lit)
	mymob.overlay_fullscreen("lighting_backdrop_unlit", /atom/movable/screen/fullscreen/stretch/lighting_backdrop/unlit)

/atom/movable/screen/plane_master/lighting/Initialize(mapload)
	. = ..()
	add_filter("emissives", 1, alpha_mask_filter(render_source = EMISSIVE_RENDER_TARGET, flags = MASK_INVERSE))

/atom/movable/screen/plane_master/point
	name = "point plane master"
	plane = POINT_PLANE
	appearance_flags = PLANE_MASTER //should use client color

/atom/movable/screen/plane_master/point/backdrop(mob/mymob)
	if(istype(mymob) && mymob.client && mymob.client.prefs)
		alpha = (mymob.client.prefs.toggles2 & PREFTOGGLE_2_THOUGHT_BUBBLE) ? 255 : 0

/atom/movable/screen/plane_master/cogbar
	name = "cogbar plane master"
	plane = COGBAR_PLANE
	appearance_flags = PLANE_MASTER //should use client color

/atom/movable/screen/plane_master/cogbar/backdrop(mob/mymob)
	if(istype(mymob) && mymob.client?.prefs)
		alpha = (mymob.client.prefs.toggles3 & PREFTOGGLE_3_COGBAR_ANIMATIONS) ? 255 : 0

/**
  * Things placed on this mask the lighting plane. Doesn't render directly.
  *
  * Gets masked by blocking plane. Use for things that you want blocked by
  * mobs, items, etc.
  */
/atom/movable/screen/plane_master/emissive
	name = "emissive plane master"
	plane = EMISSIVE_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = EMISSIVE_RENDER_TARGET

/atom/movable/screen/plane_master/emissive/Initialize(mapload)
	. = ..()
	add_filter("em_block_masking", 1, color_matrix_filter(GLOB.em_mask_matrix))

/atom/movable/screen/plane_master/space
	name = "space plane master"
	plane = PLANE_SPACE
	appearance_flags = PLANE_MASTER

/atom/movable/screen/plane_master/parallax
	name = "parallax plane master"
	plane = PLANE_SPACE_PARALLAX
	appearance_flags = PLANE_MASTER
	blend_mode = BLEND_MULTIPLY

/atom/movable/screen/plane_master/blackness
	name = "blackness plane master"
	plane = BLACKNESS_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	color = list(null, null, null, "#0000", "#000f")
	blend_mode = BLEND_ADD
	appearance_flags = PLANE_MASTER | NO_CLIENT_COLOR | PIXEL_SCALE

/atom/movable/screen/plane_master/gravpulse
	name = "gravpulse plane"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	plane = GRAVITY_PULSE_PLANE
	blend_mode = BLEND_ADD
	render_target = GRAVITY_PULSE_RENDER_TARGET

/atom/movable/screen/plane_master/smoke
	name = "point plane master"
	plane = SMOKE_PLANE
	appearance_flags = PLANE_MASTER

/atom/movable/screen/plane_master/lamps
	name = "lamps plane master"
	plane = LIGHTING_LAMPS_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = LIGHTING_LAMPS_RENDER_TARGET

/atom/movable/screen/plane_master/lamps/floor
	name = "floor lamps plane master"
	plane = FLOOR_LIGHTING_LAMPS_PLANE
	render_target = FLOOR_LIGHTING_LAMPS_RENDER_TARGET

/atom/movable/screen/plane_master/exposure
	name = "exposure plane master"
	plane = LIGHTING_EXPOSURE_PLANE
	appearance_flags = parent_type::appearance_flags | PIXEL_SCALE //should use client color
	blend_mode = BLEND_ADD
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/atom/movable/screen/plane_master/exposure/backdrop(mob/mymob)
	remove_filter("blur_exposure")
	alpha = 0
	if(!istype(mymob) || !(mymob?.client?.prefs?.light & LIGHT_NEW_LIGHTING))
		return
	var/enabled = mymob?.client?.prefs?.light & LIGHT_EXPOSURE

	if(enabled)
		alpha = 255
		add_filter("blur_exposure", 1, gauss_blur_filter(size = 20)) // by refs such blur is heavy, but tests were okay and this allow us more flexibility with setup. Possible point for improvements

/atom/movable/screen/plane_master/lamps_selfglow
	name = "lamps selfglow plane master"
	plane = LIGHTING_LAMPS_SELFGLOW
	appearance_flags = PLANE_MASTER //should use client color
	blend_mode = BLEND_ADD
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	var/target_rendering = LIGHTING_LAMPS_RENDER_TARGET

/atom/movable/screen/plane_master/lamps_selfglow/floor
	name = "floor lamps selfglow plane master"
	plane = FLOOR_LIGHTING_LAMPS_SELFGLOW
	target_rendering = FLOOR_LIGHTING_LAMPS_RENDER_TARGET

/atom/movable/screen/plane_master/lamps_selfglow/backdrop(mob/mymob)
	remove_filter("add_lamps_to_selfglow")
	remove_filter("lamps_selfglow_bloom")

	if(!istype(mymob) || !(mymob?.client?.prefs?.light & LIGHT_NEW_LIGHTING))
		return
	var/level = mymob?.client?.prefs?.glowlevel

	if(isnull(level))
		return
	var/bloomsize = 0
	var/bloomoffset = 0
	switch(level)
		if(GLOW_LOW)
			bloomsize = 2
			bloomoffset = 1
		if(GLOW_MED)
			bloomsize = 3
			bloomoffset = 2
		if(GLOW_HIGH)
			bloomsize = 5
			bloomoffset = 3
		else
			return

	add_filter("add_lamps_to_selfglow", 1, layering_filter(render_source = target_rendering, blend_mode = BLEND_OVERLAY))
	add_filter("lamps_selfglow_bloom", 1, bloom_filter(threshold = "#777777", size = bloomsize, offset = bloomoffset, alpha = 80))

/atom/movable/screen/plane_master/lamps_glare
	name = "lamps glare plane master"
	plane = LIGHTING_LAMPS_GLARE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	var/target_rendering = LIGHTING_LAMPS_RENDER_TARGET

/atom/movable/screen/plane_master/lamps_glare/floor
	name = "floor lamps glare plane master"
	plane = FLOOR_LIGHTING_LAMPS_GLARE
	target_rendering = FLOOR_LIGHTING_LAMPS_RENDER_TARGET

/atom/movable/screen/plane_master/lamps_glare/backdrop(mob/mymob)
	remove_filter("add_lamps_to_glare")
	remove_filter("lamps_glare")

	if(!istype(mymob) || !(mymob?.client?.prefs?.light & LIGHT_NEW_LIGHTING))
		return

	var/enabled = mymob?.client?.prefs?.light & LIGHT_GLARE

	if(enabled)
		add_filter("add_lamps_to_glare", 1, layering_filter(render_source = target_rendering, blend_mode = BLEND_ADD))
		add_filter("lamps_glare", 1, radial_blur_filter(size = 0.035))

/**
 * The bright molten part of lava, in its own colours. Never shown itself: the above lighting plane master adds it
 * over the lighting, so lava blooms past its edges. Off, with no filters, for players with no lava nearby: see
 * /datum/lava_effects_watcher.
 */
/atom/movable/screen/plane_master/lava_glow
	name = "lava glow plane master"
	plane = LAVA_GLOW_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = LAVA_GLOW_RENDER_TARGET
	lava_effect = TRUE
	alpha = 0

/atom/movable/screen/plane_master/lava_glow/Initialize(mapload)
	. = ..()
	// A bright halo round the molten rock in its own colours, the way an emissive blooms: strongest at the rock's edge
	// and fading out over a few pixels onto the crust and the floor round it
	add_filter("bloom", 1, bloom_filter(threshold = "#000000", size = 3, offset = 2, alpha = 220))
	// And a wider, fainter glow round that, which breathes (see update_filters())
	add_filter("bloom_wide", 2, bloom_filter(threshold = "#000000", size = 10, offset = 1, alpha = LAVA_GLOW_WIDE_LOW))
	// Only the halo is added. The molten rock itself is already at full brightness, it's on the emissive plane
	add_filter("not_over_lava", 3, alpha_mask_filter(render_source = EMISSIVE_RENDER_TARGET, flags = MASK_INVERSE))
	// And not over anything standing in or beside the lava
	add_filter("not_over_things", 4, alpha_mask_filter(render_source = GAME_PLANE_RENDER_TARGET, flags = MASK_INVERSE))

// The wide glow swells and fades slowly, like heat. Making the filters again stops that, so it's started again here
/atom/movable/screen/plane_master/lava_glow/update_filters()
	. = ..()
	// With the bloom off it has no filters to look for
	if(lava_effects_off)
		return
	var/wide_glow = get_filter("bloom_wide")
	if(!wide_glow)
		return
	animate(wide_glow, alpha = LAVA_GLOW_WIDE_HIGH, time = 2.2 SECONDS, loop = -1, easing = SINE_EASING)
	animate(alpha = LAVA_GLOW_WIDE_LOW, time = 2.2 SECONDS, easing = SINE_EASING)

/atom/movable/screen/plane_master/lava_glow/set_lava_effects(on)
	. = ..()
	alpha = on ? 255 : 0

/**
 * Things drawn over the lighting, like welding sparks and tracers, with lava's bloom added. Only on the screen while
 * there's lava nearby: each plane master on the screen is a pass over the whole screen every frame. Away from it the
 * plane is drawn the way it always was, with no plane master.
 */
/atom/movable/screen/plane_master/above_lighting
	name = "above lighting plane master"
	plane = ABOVE_LIGHTING_PLANE
	// Only a plane master, so these still take the client's colour like they did without one
	appearance_flags = PLANE_MASTER
	lava_effect = TRUE

/atom/movable/screen/plane_master/above_lighting/Initialize(mapload)
	. = ..()
	add_filter("lava_bloom", 1, layering_filter(render_source = LAVA_GLOW_RENDER_TARGET, blend_mode = BLEND_ADD))

// While lava's bloom is off, nothing puts its filters back
/atom/movable/screen/plane_master/update_filters()
	if(lava_effect && lava_effects_off)
		filters = null
		return
	return ..()

/// Turns this plane master's part of lava's bloom on or off, see /datum/lava_effects_watcher
/atom/movable/screen/plane_master/proc/set_lava_effects(on)
	lava_effects_off = !on
	update_filters()
