/atom/movable/screen/plane_master
	screen_loc = "CENTER"
	icon_state = "blank"
	appearance_flags = PLANE_MASTER|NO_CLIENT_COLOR
	blend_mode = BLEND_OVERLAY
	var/show_alpha = 255
	var/hide_alpha = 0
	/// Are this plane's filters part of the water and lava effects, which are off for players with none nearby?
	var/water_effect = FALSE
	/// Is the plane only drawn for those effects, so it's hidden too while they're off?
	var/water_effect_only = FALSE
	/// Is this a shown plane that's taken off the player's screen while the effects are off? Each plane master on
	/// screen is a pass over the whole screen every frame, even with nothing on it
	var/water_effect_removable = FALSE
	/// Are the water and lava effects off for this player right now?
	var/water_effects_off = FALSE

// While the water and lava effects are off, nothing puts their filters back
/atom/movable/screen/plane_master/update_filters()
	if(water_effects_off)
		filters = null
		return
	return ..()

/// Turns this plane's part of the water and lava effects on or off, see /datum/water_effects_watcher
/atom/movable/screen/plane_master/proc/set_water_effects(on)
	water_effects_off = !on
	update_filters()
	if(water_effect_only)
		alpha = on ? 255 : 0

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

/atom/movable/screen/plane_master/water_mask
	name = "water mask plane master"
	plane = WATER_MASK_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = WATER_MASK_RENDER_TARGET

/atom/movable/screen/plane_master/lava_glow
	name = "lava glow plane master"
	plane = LAVA_GLOW_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = LAVA_GLOW_RENDER_TARGET
	water_effect = TRUE
	water_effect_only = TRUE

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
	var/wide_glow = get_filter("bloom_wide")
	if(!wide_glow)
		return
	animate(wide_glow, alpha = LAVA_GLOW_WIDE_HIGH, time = 2.2 SECONDS, loop = -1, easing = SINE_EASING)
	animate(alpha = LAVA_GLOW_WIDE_LOW, time = 2.2 SECONDS, easing = SINE_EASING)

/atom/movable/screen/plane_master/water_ripple
	name = "water ripple plane master"
	plane = WATER_RIPPLE_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = WATER_RIPPLE_RENDER_TARGET

/atom/movable/screen/plane_master/water_mirror
	name = "water mirror plane master"
	plane = WATER_MIRROR_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = WATER_MIRROR_RENDER_TARGET

/atom/movable/screen/plane_master/water_shimmer
	name = "water shimmer plane master"
	plane = WATER_SHIMMER_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = WATER_SHIMMER_RENDER_TARGET

/atom/movable/screen/plane_master/pool_floor
	name = "pool floor plane master"
	plane = POOL_FLOOR_PLANE
	appearance_flags = PLANE_MASTER
	water_effect = TRUE
	water_effect_removable = TRUE

/atom/movable/screen/plane_master/pool_floor/Initialize(mapload)
	. = ..()
	// The tiles bend under the ripples, like a pool's floor seen through moving water
	add_filter("ripples", 1, displacement_map_filter(render_source = WATER_RIPPLE_RENDER_TARGET, size = POOL_REFRACTION))

/atom/movable/screen/plane_master/water
	name = "water plane master"
	plane = WATER_PLANE
	appearance_flags = PLANE_MASTER

/atom/movable/screen/plane_master/water_edge
	name = "water edge plane master"
	plane = WATER_EDGE_PLANE
	appearance_flags = PLANE_MASTER

/atom/movable/screen/plane_master/water_rays
	name = "water rays plane master"
	plane = WATER_RAYS_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	blend_mode = BLEND_ADD
	water_effect = TRUE
	water_effect_removable = TRUE
	water_effect_only = TRUE

/atom/movable/screen/plane_master/water_rays/Initialize(mapload)
	. = ..()
	// Shafts of light only show in the water
	add_filter("water_mask", 1, alpha_mask_filter(render_source = WATER_MASK_RENDER_TARGET))

/atom/movable/screen/plane_master/water_reflection
	name = "water reflection plane master"
	plane = WATER_REFLECTION_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	water_effect = TRUE
	water_effect_removable = TRUE
	water_effect_only = TRUE

/atom/movable/screen/plane_master/water_reflection/Initialize(mapload)
	. = ..()
	// A copy of the world: walls, machines, items and mobs
	add_filter("world", 1, layering_filter(render_source = GAME_PLANE_RENDER_TARGET))
	// Lamps and lit screens, added on so they reflect as bright spots
	add_filter("lamps", 2, layering_filter(render_source = LIGHTING_LAMPS_RENDER_TARGET, blend_mode = BLEND_ADD))
	// A reflection is a little darker and bluer than the thing itself
	add_filter("reflection_tone", 3, color_matrix_filter(list(0.78, 0, 0, 0, 0, 0.8, 0, 0, 0, 0, 0.86, 0, 0, 0, 0, 0.62, 0.02, 0.04, 0.08, 0)))
	// Every water tile moves its pixels so it shows the tile above it upside down
	add_filter("mirror", 4, displacement_map_filter(render_source = WATER_MIRROR_RENDER_TARGET, size = POOL_MIRROR_REACH))
	// Then the waves bend it
	add_filter("ripples", 5, displacement_map_filter(render_source = WATER_RIPPLE_RENDER_TARGET, size = POOL_REFLECTION_RIPPLE))
	// A reflection only shows where there is water under it
	add_filter("water_mask", 6, alpha_mask_filter(render_source = WATER_MASK_RENDER_TARGET))
	// And the ripples break it up as they pass
	add_filter("water_shimmer", 7, alpha_mask_filter(render_source = WATER_SHIMMER_RENDER_TARGET))
	// Bright things in it, like lamps, glow
	add_filter("reflection_bloom", 8, bloom_filter(threshold = "#A0A0A0", size = 3, offset = 1, alpha = 170))

/**
 * Light and shade on the waves, worked out from the ripple map as a normal map.
 *
 * The ripple map says which way the surface tilts at each pixel. A colour matrix turns that into how much each pixel
 * faces a light up and to the left, the same light the glints are drawn for. The shade plane darkens the sides facing
 * away and the light plane brightens the sides facing it, so the waves, and every ring spreading from a step, stand
 * out of the water. Both are under the lighting plane, so a dark room darkens them and a coloured lamp colours them.
 */
/atom/movable/screen/plane_master/water_relief_shade
	name = "water relief shade plane master"
	plane = WATER_RELIEF_SHADE_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	blend_mode = BLEND_MULTIPLY
	water_effect = TRUE
	water_effect_removable = TRUE
	water_effect_only = TRUE

/atom/movable/screen/plane_master/water_relief_shade/Initialize(mapload)
	. = ..()
	add_filter("normals", 1, layering_filter(render_source = WATER_RIPPLE_RENDER_TARGET))
	// 1 + 0.18 * (how much it faces the light). Sides facing it come out over white, which a multiply leaves alone.
	// Blue darkens a little less, so the shaded sides go deeper blue rather than grey
	add_filter("shading", 2, color_matrix_filter(list(-0.216, -0.216, -0.144, 0, -0.288, -0.288, -0.192, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1.252, 1.252, 1.168, 0)))
	add_filter("water_mask", 3, alpha_mask_filter(render_source = WATER_MASK_RENDER_TARGET))

/atom/movable/screen/plane_master/water_relief_light
	name = "water relief light plane master"
	plane = WATER_RELIEF_LIGHT_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	blend_mode = BLEND_ADD
	water_effect = TRUE
	water_effect_removable = TRUE
	water_effect_only = TRUE
	// The specular plane uses it to find the sides of the waves that catch the light
	render_target = WATER_RELIEF_LIGHT_RENDER_TARGET

/atom/movable/screen/plane_master/water_relief_light/Initialize(mapload)
	. = ..()
	add_filter("normals", 1, layering_filter(render_source = WATER_RIPPLE_RENDER_TARGET))
	// Pale light, as strong as 0.18 * (how much it faces the light)
	add_filter("shading", 2, color_matrix_filter(list(0, 0, 0, -0.216, 0, 0, 0, -0.288, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.97, 1, 0.252)))
	add_filter("water_mask", 3, alpha_mask_filter(render_source = WATER_MASK_RENDER_TARGET))

/**
 * Glints of the light falling on the water, in its colour: bright where a lamp lights the water, none in the dark.
 *
 * Everything under the lighting plane is darkened by it, so nothing there can be brighter than the light on it. This
 * plane is only read: the above lighting plane adds it on after the lighting, which lets a glint shine.
 */
/atom/movable/screen/plane_master/water_specular
	name = "water specular plane master"
	plane = WATER_SPECULAR_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = WATER_SPECULAR_RENDER_TARGET
	water_effect = TRUE
	water_effect_only = TRUE

/atom/movable/screen/plane_master/water_specular/Initialize(mapload)
	. = ..()
	// The light falling on each pixel, with dim light taken off so only properly lit water glints
	add_filter("light", 1, layering_filter(render_source = LIGHTING_PLANE_RENDER_TARGET))
	add_filter("bright_only", 2, color_matrix_filter(list(1.4, 0, 0, 0, 0, 1.4, 0, 0, 0, 0, 1.4, 0, 0, 0, 0, 1, -0.35, -0.35, -0.35, 0)))
	// Only on the sides of the waves that face the light, and only on water. 4 * face - 0.08 keeps it to the steeper
	// part of each face: small glints on ripples, and no more than a sheen on the whole face of a big wave
	add_filter("wave_faces", 3, alpha_mask_filter(render_source = WATER_RELIEF_LIGHT_RENDER_TARGET))
	add_filter("strength", 4, color_matrix_filter(list(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 4, 0, 0, 0, -0.08)))
	add_filter("water_mask", 5, alpha_mask_filter(render_source = WATER_MASK_RENDER_TARGET))
	// Not over anything standing in or beside the water, it's drawn over the whole world
	add_filter("not_over_things", 6, alpha_mask_filter(render_source = GAME_PLANE_RENDER_TARGET, flags = MASK_INVERSE))
	// The brightest glow a little
	add_filter("glint_bloom", 7, bloom_filter(threshold = "#D0D0D0", size = 2, offset = 0, alpha = 120))

/// Things drawn over the lighting, like welding sparks and tracers. Water glints and the bloom of lava are added here too
/atom/movable/screen/plane_master/above_lighting
	name = "above lighting plane master"
	plane = ABOVE_LIGHTING_PLANE
	// Only a plane master, so these still take the client's colour like they did without one
	appearance_flags = PLANE_MASTER
	water_effect = TRUE
	water_effect_removable = TRUE

/atom/movable/screen/plane_master/above_lighting/Initialize(mapload)
	. = ..()
	add_filter("water_glints", 1, layering_filter(render_source = WATER_SPECULAR_RENDER_TARGET, blend_mode = BLEND_ADD))
	// And lava blooming past its edges
	add_filter("lava_bloom", 2, layering_filter(render_source = LAVA_GLOW_RENDER_TARGET, blend_mode = BLEND_ADD))

/atom/movable/screen/plane_master/water_edge_band
	name = "water edge band plane master"
	plane = WATER_EDGE_BAND_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = WATER_EDGE_BAND_RENDER_TARGET
	water_effect = TRUE
	water_effect_only = TRUE

/atom/movable/screen/plane_master/water_edge_band/Initialize(mapload)
	. = ..()
	// Where the water is, spread out past its edges and turned inside out: that's a band along every edge of the
	// water, strongest right at the edge and gone a few pixels in. 0.9 * (1 - how much water)
	add_filter("water", 1, layering_filter(render_source = WATER_MASK_RENDER_TARGET))
	add_filter("spread", 2, gauss_blur_filter(size = 4))
	add_filter("edge_only", 3, color_matrix_filter(list(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -0.9, 1, 1, 1, 0.9)))

/atom/movable/screen/plane_master/water_foam_drive
	name = "water foam drive plane master"
	plane = WATER_FOAM_DRIVE_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = WATER_FOAM_DRIVE_RENDER_TARGET
	water_effect = TRUE
	water_effect_only = TRUE

/atom/movable/screen/plane_master/water_foam_drive/Initialize(mapload)
	. = ..()
	// White wherever a wave is steep and faces the light, and nothing where the water is flat: a calm pool has no
	// foam on it, a rough one has whitecaps, and a strong swell carries a thin line of foam on each wave's face.
	// 6.5 * (how much it faces the light) - 3
	add_filter("normals", 1, layering_filter(render_source = WATER_RIPPLE_RENDER_TARGET))
	add_filter("steep_faces", 2, color_matrix_filter(list(0, 0, 0, -7.8, 0, 0, 0, -10.4, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 6.1)))
	// And the band along the water's edges, where it always laps a little
	add_filter("edges", 3, layering_filter(render_source = WATER_EDGE_BAND_RENDER_TARGET))

/// Foam: flecks of it are drawn all over the water, and only show where the foam drive plane lets them
/atom/movable/screen/plane_master/water_foam
	name = "water foam plane master"
	plane = WATER_FOAM_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	water_effect = TRUE
	water_effect_only = TRUE
	water_effect_removable = TRUE

/atom/movable/screen/plane_master/water_foam/Initialize(mapload)
	. = ..()
	// Foam rides the waves
	add_filter("ripples", 1, displacement_map_filter(render_source = WATER_RIPPLE_RENDER_TARGET, size = POOL_REFRACTION))
	add_filter("where_foam_is", 2, alpha_mask_filter(render_source = WATER_FOAM_DRIVE_RENDER_TARGET))
	add_filter("water_mask", 3, alpha_mask_filter(render_source = WATER_MASK_RENDER_TARGET))

/atom/movable/screen/plane_master/water_shine
	name = "water shine plane master"
	plane = WATER_SHINE_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	water_effect = TRUE
	water_effect_removable = TRUE

/atom/movable/screen/plane_master/water_shine/Initialize(mapload)
	. = ..()
	// Glints ride the waves, so a ring spreading across the water bends them too
	add_filter("ripples", 1, displacement_map_filter(render_source = WATER_RIPPLE_RENDER_TARGET, size = POOL_REFRACTION))
	// Ripples and glints only show over water
	add_filter("water_mask", 2, alpha_mask_filter(render_source = WATER_MASK_RENDER_TARGET))
	// And the brightest glints glow a little
	add_filter("glint_bloom", 3, bloom_filter(threshold = "#F2F2F2", size = 1, offset = 0, alpha = 110))

/atom/movable/screen/plane_master/game_world
	name = "game world plane master"
	plane = GAME_PLANE
	appearance_flags = PLANE_MASTER
	render_target = GAME_PLANE_RENDER_TARGET

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
	// Water reads it to glint with the light falling on it
	render_target = LIGHTING_PLANE_RENDER_TARGET

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
