// Merged flames prototype.
// Fires are drawn on a plane of their own that is never shown. Three copies of that picture are then drawn over the
// lit game:
// - the outer flame: blurred a little, with everything under a set strength cut away, so the flames of neighbouring
//   tiles join into one shape with one edge. It is the fire's heat colour, darker and redder at the edge.
// - the core: blurred a lot and cut higher, so it only shows where a fire is thick. Brighter and yellower.
// - the glow: both of those blurred wide and added, as the light round the flames.

/// TRUE for merged flames, FALSE for the old one sprite a tile
GLOBAL_VAR_INIT(merged_flames, TRUE)

/// The numbers the look is made of. Change one, then call flame_look_changed().
/// tools/shift_bench/flame_look_sim.py draws the same sums without the game: keep its numbers in step.
GLOBAL_LIST_INIT(flame_look, list(
	// The outer flame: how far it is blurred before the cut, in pixels
	"blur" = 2,
	// The strength under which nothing is drawn, 0 to 1
	"cut" = 0.3,
	// How fast a flame becomes solid above the cut. Higher is a harder edge, and a brighter middle: see flame_filters().
	"edge" = 5,
	// How much of the fire's own heat colour goes into red, green and blue at the edge
	"heat_red" = 0.7,
	"heat_green" = 0.3,
	"heat_blue" = 0.3,
	// The core: the same three
	"core_blur" = 7,
	"core_cut" = 0.58,
	"core_edge" = 5,
	// How much of the heat colour's green and blue goes into it, and how much green and blue every core gets
	"core_heat" = 0.6,
	"core_green" = 0.12,
	"core_blue" = 0.03,
	// The glow: how far it is blurred and how strong it is, 0 to 255
	"glow_blur" = 10,
	"glow_alpha" = 70,
	// The licking: how many pixels the flames are pushed about at most (0 for none), and how many seconds the
	// noise that pushes them takes to scroll 24 tiles up the screen
	"lick" = 10,
	"lick_time" = 10,
	// The body of a small, middling and big fire: strength 0 to 255 and size
	"body_alpha_1" = 70,
	"body_alpha_2" = 95,
	"body_alpha_3" = 120,
	"body_scale_1" = 0.8,
	"body_scale_2" = 0.95,
	"body_scale_3" = 1.1,
	// The moving swirl inside it
	"swirl_alpha" = 110,
	"swirl_scale" = 1.7,
	// The tongues that rise off it: how many a fire has at once, how many start each tenth of a second, their
	// strength 0 to 255, width, how many times taller than wide, how fast they rise and how many tenths of a
	// second they last
	"tongues" = 8,
	"tongue_rate" = 0.7,
	"tongue_alpha" = 170,
	"tongue_size" = 0.45,
	"tongue_tall" = 2.2,
	"tongue_rise" = 3.4,
	"tongue_life" = 11,
))

// MARK: The plane

/atom/movable/screen/plane_master/fire
	name = "fire plane master"
	plane = FIRE_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = FIRE_RENDER_TARGET
	var/atom/movable/screen/fire_relay/outer
	var/atom/movable/screen/fire_relay/core/core
	var/atom/movable/screen/fire_relay/glow/glow

/atom/movable/screen/plane_master/fire/Destroy()
	QDEL_NULL(outer)
	QDEL_NULL(core)
	QDEL_NULL(glow)
	return ..()

// No ..(): that adds gravity's warp, and nothing here is on screen to be warped
/atom/movable/screen/plane_master/fire/backdrop(mob/mymob)
	if(!outer)
		outer = new
		core = new
		glow = new
	if(mymob?.client)
		mymob.client.screen |= outer
		mymob.client.screen |= core
		mymob.client.screen |= glow
	set_look()

/**
 * The colour filter that cuts a blurred picture of the fires down to flames.
 *
 * Rows are what each of red, green, blue and alpha going in gives to red, green, blue and alpha coming out, then what
 * is added to each. BYOND multiplies the colour that comes out by the alpha that comes out before it caps that alpha
 * at 1. With edge 5 and cut 0.3 that is times 1 at the edge of a flame and times 3.5 at full strength, so the colours
 * are kept low and a flame grows brighter towards its middle by itself.
 */
/proc/flame_filter(cut, edge, red, green, blue, add_green = 0, add_blue = 0)
	return color_matrix_filter(list(
		red, 0, 0, 0,
		0, green, 0, 0,
		0, 0, blue, 0,
		0, 0, 0, edge,
		0, add_green, add_blue, -edge * cut,
	))

/// Sets the blurs, the cuts and the colours from GLOB.flame_look
/atom/movable/screen/plane_master/fire/proc/set_look()
	var/list/look = GLOB.flame_look
	var/list/outer_cut = flame_filter(look["cut"], look["edge"], look["heat_red"], look["heat_green"], look["heat_blue"])
	outer.clear_filters()
	outer.add_filter("blur", 1, gauss_blur_filter(size = look["blur"]))
	outer.add_filter("cut", 2, outer_cut)
	core.clear_filters()
	core.add_filter("blur", 1, gauss_blur_filter(size = look["core_blur"]))
	core.add_filter("cut", 2, flame_filter(look["core_cut"], look["core_edge"], 1, look["core_heat"], look["core_heat"], look["core_green"], look["core_blue"]))
	glow.clear_filters()
	glow.add_filter("blur", 1, gauss_blur_filter(size = look["blur"]))
	glow.add_filter("cut", 2, outer_cut)
	glow.add_filter("spread", 3, gauss_blur_filter(size = look["glow_blur"]))
	glow.alpha = look["glow_alpha"]
	if(look["lick"] > 0)
		// Before the blur and the cut, so the edge that comes out is still smooth
		var/list/lick = displacement_map_filter(render_source = FIRE_NOISE_RENDER_TARGET, size = look["lick"])
		outer.add_filter("lick", 0, lick)
		core.add_filter("lick", 0, lick)

/// Holds the noise the flames are pushed about by. Never shown.
/atom/movable/screen/plane_master/fire_noise
	name = "fire noise plane master"
	plane = FIRE_NOISE_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = FIRE_NOISE_RENDER_TARGET
	var/atom/movable/screen/fire_noise/noise

/atom/movable/screen/plane_master/fire_noise/Destroy()
	QDEL_NULL(noise)
	return ..()

// No ..(), the same as the fire plane
/atom/movable/screen/plane_master/fire_noise/backdrop(mob/mymob)
	if(!noise)
		noise = new
		noise.start_scroll()
	if(mymob?.client)
		mymob.client.screen |= noise

/**
 * Smooth random red and green, three times its size so it covers the whole screen, scrolling upwards for ever.
 *
 * In a displace filter red pushes a pixel sideways and green up or down, and mid grey leaves it be.
 * The sheet is the same square twice, one above the other, so after scrolling one square's height it can jump
 * back to where it started without that showing.
 */
/atom/movable/screen/fire_noise
	icon = 'icons/effects/flame_noise.dmi'
	icon_state = "noise"
	screen_loc = "SOUTHWEST"
	plane = FIRE_NOISE_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	appearance_flags = NO_CLIENT_COLOR
	// Scaling is about the sheet's middle, so this puts its left edge back at the screen's
	pixel_x = 256

/atom/movable/screen/fire_noise/proc/start_scroll()
	transform = matrix().Scale(3)
	pixel_y = -256
	animate(src, pixel_y = 512, time = GLOB.flame_look["lick_time"] SECONDS, loop = -1)
	animate(pixel_y = -256, time = 0)

/// The picture of the fires drawn as a thing over the lit game
/atom/movable/screen/fire_relay
	// The bottom left corner is where a plane's picture lines up with the screen
	screen_loc = "SOUTHWEST"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	appearance_flags = NO_CLIENT_COLOR
	plane = ABOVE_LIGHTING_PLANE
	layer = ABOVE_LIGHTING_LAYER + 0.2
	render_source = FIRE_RENDER_TARGET

/atom/movable/screen/fire_relay/core
	layer = ABOVE_LIGHTING_LAYER + 0.3

/atom/movable/screen/fire_relay/glow
	layer = ABOVE_LIGHTING_LAYER + 0.1
	blend_mode = BLEND_ADD

// MARK: The flames

/// Shapes that rise off a fire and thin out. Above the body they are cut down to tongues of flame.
/particles/flame_tongues
	icon = 'icons/effects/flame_body.dmi'
	icon_state = "blob"
	width = 160
	height = 256
	fade = 0.5 SECONDS
	fadein = 0.1 SECONDS
	position = generator("box", list(-10, -8), list(10, 2), UNIFORM_RAND)
	drift = generator("vector", list(-0.25, 0), list(0.25, 0.12), UNIFORM_RAND)

/obj/effect/hotspot
	/// 1, 2 or 3 for a small, middling or big fire
	var/flame_size = 1
	/// The value of GLOB.merged_flames we were last drawn for
	var/flame_merged

/// The parts of a merged fire of that size. A turf always gets the same ones, so a fire doesn't jump about when it changes size.
/proc/merged_flame_parts(size, turf/where)
	var/static/list/parts = list()
	if(isnull(size))
		parts = list()
		return
	var/kind = (where.x * 7 + where.y * 13) % 8
	var/key = "[size]-[kind]"
	if(parts[key])
		return parts[key]
	var/list/look = GLOB.flame_look
	// Each kind is a little off the tile's middle and a little bigger or smaller, so the edge of a fire is not a straight line
	var/shift_x = ((kind * 5) % 11) - 5
	var/shift_y = ((kind * 3) % 9) - 4
	var/stretch = 0.88 + (kind % 4) * 0.08
	var/mutable_appearance/body = mutable_appearance('icons/effects/flame_body.dmi', "blob")
	body.alpha = look["body_alpha_[size]"]
	body.transform = matrix().Scale(look["body_scale_[size]"] * stretch)
	// The sheet is three tiles wide
	body.pixel_x = -32 + shift_x
	body.pixel_y = -32 + shift_y
	var/mutable_appearance/swirl = mutable_appearance('icons/effects/flame_swirl.dmi', "[size]")
	swirl.alpha = look["swirl_alpha"]
	swirl.transform = matrix().Scale(look["swirl_scale"])
	swirl.pixel_x = shift_x
	swirl.pixel_y = shift_y
	parts[key] = list(body, swirl)
	return parts[key]

/// The tongues every merged fire shares
/proc/merged_flame_tongues(remake = FALSE)
	var/static/particles/flame_tongues/tongues
	if(!tongues || remake)
		if(!tongues)
			tongues = new
		var/list/look = GLOB.flame_look
		tongues.count = look["tongues"]
		tongues.spawning = look["tongue_rate"]
		tongues.color = rgb(255, 255, 255, look["tongue_alpha"])
		var/wide = look["tongue_size"]
		var/tall = wide * look["tongue_tall"]
		tongues.scale = generator("vector", list(wide * 0.7, tall * 0.7), list(wide * 1.3, tall * 1.3), UNIFORM_RAND)
		tongues.grow = list(-wide / 22, -tall / 22)
		tongues.velocity = generator("vector", list(-0.25, look["tongue_rise"] * 0.6), list(0.25, look["tongue_rise"] * 1.3), UNIFORM_RAND)
		tongues.lifespan = generator("num", look["tongue_life"] * 0.7, look["tongue_life"] * 1.3, UNIFORM_RAND)
	return tongues

/// Draws us as a small (1), middling (2) or big (3) fire
/obj/effect/hotspot/proc/set_flame_size(size, force = FALSE)
	if(!force && size == flame_size && flame_merged == GLOB.merged_flames)
		return
	flame_size = size
	flame_merged = GLOB.merged_flames
	cut_overlays()
	if(!flame_merged)
		plane = initial(plane)
		blend_mode = initial(blend_mode)
		alpha = initial(alpha)
		icon = initial(icon)
		icon_state = "[size]"
		particles = null
		return
	plane = FIRE_PLANE
	blend_mode = BLEND_DEFAULT
	alpha = 255
	icon = null
	particles = merged_flame_tongues()
	if(isturf(loc))
		add_overlay(merged_flame_parts(size, loc))

/// Call after changing GLOB.flame_look or GLOB.merged_flames: every fire and every client's fire plane takes the new numbers
/proc/flame_look_changed()
	merged_flame_parts(null)
	merged_flame_tongues(TRUE)
	for(var/obj/effect/hotspot/fire in world)
		fire.set_flame_size(fire.flame_size, TRUE)
	for(var/client/C as anything in GLOB.clients)
		var/atom/movable/screen/plane_master/fire/master = C.mob?.hud_used?.plane_masters["[FIRE_PLANE]"]
		master?.set_look()
		var/atom/movable/screen/plane_master/fire_noise/noise_master = C.mob?.hud_used?.plane_masters["[FIRE_NOISE_PLANE]"]
		noise_master?.noise?.start_scroll()
