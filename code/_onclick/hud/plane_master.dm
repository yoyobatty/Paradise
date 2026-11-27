/atom/movable/screen/plane_master
	screen_loc = "CENTER"
	icon_state = "blank"
	appearance_flags = PLANE_MASTER|NO_CLIENT_COLOR
	blend_mode = BLEND_OVERLAY
	var/show_alpha = 255
	var/hide_alpha = 0
	/// Are this plane's filters part of the water effects, which are off for players away from water?
	var/water_effect = FALSE
	/// Is this plane only there for the water effects, so it's hidden while they're off?
	var/water_effect_only = FALSE
	/// Is this plane taken off the screen while the water effects are off, to save its full screen pass?
	var/water_effect_removable = FALSE
	/// Are the water effects off for this player right now?
	var/water_effects_off = FALSE

// Keeps the filters off while the water effects are off
/atom/movable/screen/plane_master/update_filters()
	if(water_effects_off)
		filters = null
		return
	return ..()

/// Turns this plane's part of the water effects on or off, see /datum/water_effects_watcher
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

/atom/movable/screen/plane_master/water_ripple
	name = "water ripple plane master"
	plane = WATER_RIPPLE_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = WATER_RIPPLE_RENDER_TARGET

/// The waves over whatever is under the water, used to bend it on the world plane
/atom/movable/screen/plane_master/water_refract
	name = "water refraction plane master"
	plane = WATER_REFRACT_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = WATER_REFRACT_RENDER_TARGET
	water_effect = TRUE
	water_effect_only = TRUE

/atom/movable/screen/plane_master/water_refract/Initialize(mapload)
	. = ..()
	// Only in the water, so the pool's near edge over a swimmer's legs isn't bent
	add_filter("water_mask", 1, alpha_mask_filter(render_source = WATER_MASK_RENDER_TARGET))
	// The ripple map, only where those things are
	add_filter("waves", 2, layering_filter(render_source = WATER_RIPPLE_RENDER_TARGET, blend_mode = BLEND_INSET_OVERLAY))

/// Where things in the water are, for the reflection plane to leave out.
/// The tile mirror would put their reflection too low, so each has its own /obj/effect/abstract/water_reflection
/atom/movable/screen/plane_master/water_unmirrored
	name = "water unmirrored plane master"
	plane = WATER_UNMIRRORED_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = WATER_UNMIRRORED_RENDER_TARGET
	water_effect = TRUE
	water_effect_only = TRUE

/atom/movable/screen/plane_master/water_mirror
	name = "water mirror plane master"
	plane = WATER_MIRROR_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = WATER_MIRROR_RENDER_TARGET

/// How much of a mirror the water is: wave sides sloping away from the viewer reflect, the others show the floor
/atom/movable/screen/plane_master/water_fresnel
	name = "water fresnel plane master"
	plane = WATER_FRESNEL_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = WATER_FRESNEL_RENDER_TARGET
	water_effect = TRUE
	water_effect_only = TRUE

/atom/movable/screen/plane_master/water_fresnel/Initialize(mapload)
	. = ..()
	add_filter("normals", 1, layering_filter(render_source = WATER_RIPPLE_RENDER_TARGET))
	// Mirror strength is 0.55 + 1.5 * the slope up the screen, away from the viewer.
	// The ripple map's green is 0.502 + 0.498 * the slope down the screen
	add_filter("reflectance", 2, color_matrix_filter(list(0, 0, 0, 0, 0, 0, 0, -3.012, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 2.062)))

/// Reflections of things in the water, see /obj/effect/abstract/water_reflection
/atom/movable/screen/plane_master/water_self_reflection
	name = "water self reflection plane master"
	plane = WATER_SELF_REFLECTION_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = WATER_SELF_REFLECTION_RENDER_TARGET
	water_effect = TRUE
	water_effect_only = TRUE

/// Puts the reflections back over swimmers' legs and sunk things, which the world plane draws over the water
/atom/movable/screen/plane_master/water_over
	name = "water over plane master"
	plane = WATER_OVER_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	water_effect = TRUE
	water_effect_only = TRUE
	water_effect_removable = TRUE

/atom/movable/screen/plane_master/water_over/Initialize(mapload)
	. = ..()
	add_filter("reflections", 1, layering_filter(render_source = WATER_REFLECTION_RENDER_TARGET))
	// Only where something is under the water, more the deeper it is
	add_filter("underwater", 2, alpha_mask_filter(render_source = WATER_REFRACT_RENDER_TARGET))
	// And only over the things themselves. The water round them has its reflections already
	add_filter("over_things", 3, alpha_mask_filter(render_source = GAME_PLANE_RENDER_TARGET))

/atom/movable/screen/plane_master/pool_floor
	name = "pool floor plane master"
	plane = POOL_FLOOR_PLANE
	appearance_flags = PLANE_MASTER
	water_effect = TRUE
	water_effect_removable = TRUE

/atom/movable/screen/plane_master/pool_floor/Initialize(mapload)
	. = ..()
	// The floor bends under the ripples
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
	// Read by the water over plane
	render_target = WATER_REFLECTION_RENDER_TARGET

/atom/movable/screen/plane_master/water_reflection/Initialize(mapload)
	. = ..()
	// A copy of the world: walls, machines, items and mobs
	add_filter("world", 1, layering_filter(render_source = GAME_PLANE_RENDER_TARGET))
	// Lamps and lit screens, added on so they reflect as bright spots
	add_filter("lamps", 2, layering_filter(render_source = LIGHTING_LAMPS_RENDER_TARGET, blend_mode = BLEND_ADD))
	// Not what's in the water. It has its own reflection at its waterline, or none if it's on the bottom
	add_filter("not_in_water", 2.5, alpha_mask_filter(render_source = WATER_UNMIRRORED_RENDER_TARGET, flags = MASK_INVERSE))
	// A reflection is a little darker and bluer than the thing itself
	add_filter("reflection_tone", 3, color_matrix_filter(list(0.78, 0, 0, 0, 0, 0.8, 0, 0, 0, 0, 0.86, 0, 0, 0, 0, 0.9, 0.02, 0.04, 0.08, 0)))
	// Each water tile shows the tile above it upside down
	add_filter("mirror", 4, displacement_map_filter(render_source = WATER_MIRROR_RENDER_TARGET, size = POOL_MIRROR_REACH))
	// After the mirror, since these reflections are already flipped and in place
	add_filter("in_water", 4.5, layering_filter(render_source = WATER_SELF_REFLECTION_RENDER_TARGET))
	// Then the waves bend it
	add_filter("ripples", 5, displacement_map_filter(render_source = WATER_RIPPLE_RENDER_TARGET, size = POOL_REFLECTION_RIPPLE))
	// A reflection only shows where there is water under it
	add_filter("water_mask", 6, alpha_mask_filter(render_source = WATER_MASK_RENDER_TARGET))
	// And only as much as the water is a mirror there
	add_filter("fresnel", 7, alpha_mask_filter(render_source = WATER_FRESNEL_RENDER_TARGET))
	// Bright things in it, like lamps, glow
	add_filter("reflection_bloom", 8, bloom_filter(threshold = "#A0A0A0", size = 3, offset = 1, alpha = 170))

/// Darkens the sides of the waves facing away from a light up and to the left.
/// Under the lighting plane, so a dark room or a coloured lamp changes it too
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
	// 1 + 0.18 * (how much it faces the light), so lit sides come out white and the multiply leaves them alone.
	// Blue darkens less, so shade goes deeper blue, not grey
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

/// Glints in the colour of the light on the water, drawn over the lighting by the above lighting plane
/atom/movable/screen/plane_master/water_specular
	name = "water specular plane master"
	plane = WATER_SPECULAR_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = WATER_SPECULAR_RENDER_TARGET
	water_effect = TRUE
	water_effect_only = TRUE

/atom/movable/screen/plane_master/water_specular/Initialize(mapload)
	. = ..()
	// The light on each pixel, minus dim light so only well lit water glints
	add_filter("light", 1, layering_filter(render_source = LIGHTING_PLANE_RENDER_TARGET))
	add_filter("bright_only", 2, color_matrix_filter(list(1.4, 0, 0, 0, 0, 1.4, 0, 0, 0, 0, 1.4, 0, 0, 0, 0, 1, -0.35, -0.35, -0.35, 0)))
	// Only on wave sides facing the light, and only on water.
	// 4 * face - 0.08 keeps it to the steeper part of each face, so a big wave only gets a sheen
	add_filter("wave_faces", 3, alpha_mask_filter(render_source = WATER_RELIEF_LIGHT_RENDER_TARGET))
	add_filter("strength", 4, color_matrix_filter(list(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 4, 0, 0, 0, -0.08)))
	add_filter("water_mask", 5, alpha_mask_filter(render_source = WATER_MASK_RENDER_TARGET))
	// Not over things in or beside the water, since it's drawn over the whole world
	add_filter("not_over_things", 6, alpha_mask_filter(render_source = GAME_PLANE_RENDER_TARGET, flags = MASK_INVERSE))
	// The brightest glints glow a little
	add_filter("glint_bloom", 7, bloom_filter(threshold = "#D0D0D0", size = 2, offset = 0, alpha = 120))

/// Things drawn over the lighting, like welding sparks and tracers. Water glints are added here too
/atom/movable/screen/plane_master/above_lighting
	name = "above lighting plane master"
	plane = ABOVE_LIGHTING_PLANE
	// Only PLANE_MASTER, so these still take the client's colour as they did without a plane master
	appearance_flags = PLANE_MASTER
	water_effect = TRUE
	water_effect_removable = TRUE

/atom/movable/screen/plane_master/above_lighting/Initialize(mapload)
	. = ..()
	add_filter("water_glints", 1, layering_filter(render_source = WATER_SPECULAR_RENDER_TARGET, blend_mode = BLEND_ADD))

/atom/movable/screen/plane_master/water_edge_band
	name = "water edge band plane master"
	plane = WATER_EDGE_BAND_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = WATER_EDGE_BAND_RENDER_TARGET
	water_effect = TRUE
	water_effect_only = TRUE

/atom/movable/screen/plane_master/water_edge_band/Initialize(mapload)
	. = ..()
	// The water mask blurred and inverted: a band along each edge, gone a few pixels in. 0.9 * (1 - water)
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
	// White where a wave is steep and faces the light, nothing on calm water.
	// 6.5 * (how much it faces the light) - 3
	add_filter("normals", 1, layering_filter(render_source = WATER_RIPPLE_RENDER_TARGET))
	add_filter("steep_faces", 2, color_matrix_filter(list(0, 0, 0, -7.8, 0, 0, 0, -10.4, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 6.1)))
	// And the band along the water's edges, where it always laps a little
	add_filter("edges", 3, layering_filter(render_source = WATER_EDGE_BAND_RENDER_TARGET))

/// Foam flecks are drawn all over the water and only show where the foam drive plane lets them
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
	// Glints bend with the waves and rings
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
	/// Do the waves bend what's under the water? Off for players away from water
	var/water_refraction = TRUE

/atom/movable/screen/plane_master/game_world/Initialize(mapload)
	. = ..()
	set_water_refraction(water_refraction)

/atom/movable/screen/plane_master/game_world/backdrop(mob/mymob)
	. = ..() //if you delete it so help me god
	clear_filters()
	if(istype(mymob) && mymob.client && mymob.client.prefs && (mymob.client.prefs.toggles & PREFTOGGLE_AMBIENT_OCCLUSION))
		add_filter("AO", 1, drop_shadow_filter(x = 0, y = -2, size = 4, color = "#04080FAA"))
	set_water_refraction(water_refraction)

/// Turns the waves bending what's under the water on or off. Before the shadows, so they follow the bent shapes
/atom/movable/screen/plane_master/game_world/proc/set_water_refraction(on)
	water_refraction = on
	if(on)
		add_filter("water_refraction", 0, displacement_map_filter(render_source = WATER_REFRACT_RENDER_TARGET, size = POOL_REFRACTION))
	else
		remove_filter("water_refraction")

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
