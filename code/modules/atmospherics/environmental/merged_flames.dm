// Pixel flames prototype. The baked flames and smoke are drawn by tools/shift_bench/make_flame_bed.py the way
// KFMod254's fires are made: flames that flare up and die, and dark smoke rising over them.
// A fire is a crowd of small pixel art flame licks that rise, go from pale yellow to dark red and die. They are added
// over each other, so where a fire is thick it burns white-yellow and its loose edge is orange and red, and the
// flames of neighbouring tiles run into each other with no tile edge between them.
// Fires are drawn on a plane of their own that is never shown. That picture is drawn over the lit game, and again
// blurred and added round it, as the light the flames throw.

/// FLAMES_OLD for the old one sprite a tile, FLAMES_PARTICLES for pixel flames made by particles, FLAMES_BAKED for the
/// same worked out ahead of time and shown as an animated sprite (icons/effects/flame_bed.dmi), with only embers as particles
#define FLAMES_OLD 0
#define FLAMES_PARTICLES 1
#define FLAMES_BAKED 2
/// The same in the station's own sprite style: solid pixel art in flat fire colours, low flames, no particles at all
#define FLAMES_STATION 3
/// Burning gas: thin see-through licks that sway, pinch off and rise away (icons/effects/flame_gas.dmi), soft smoke over them
#define FLAMES_GAS 4
GLOBAL_VAR_INIT(merged_flames, FLAMES_GAS)

/// The numbers the look is made of. Change one, then call flame_look_changed().
GLOBAL_LIST_INIT(flame_look, list(
	// Flame licks a small, middling and big fire has at once, and how many start each tenth of a second
	"count_1" = 12,
	"count_2" = 22,
	"count_3" = 32,
	"rate_1" = 2,
	"rate_2" = 3.5,
	"rate_3" = 5,
	// How many tenths of a second a lick lasts, at least and at most
	"life_min" = 5,
	"life_max" = 10,
	// How many pixels a tenth of a second they rise, at least and at most
	"rise_min" = 0.4,
	"rise_max" = 1.2,
	// Their size, at least and at most, and how much they shrink each tenth of a second
	"scale_min" = 1.8,
	"scale_max" = 3,
	"shrink" = 0.1,
	// How far down the colour list a lick moves each tenth of a second: higher burns out redder sooner
	"cool" = 0.14,
	// Strength of the licks, 0 to 255
	"alpha" = 200,
	// 1 to add the fires over the game, 0 to lay them over it
	"add" = 1,
	// The light round the flames: how far it is blurred and how strong it is, 0 to 255
	"glow_blur" = 10,
	"glow_alpha" = 160,
	// Embers: how many at once and how many start each tenth of a second
	"embers" = 3,
	"ember_rate" = 0.25,
	// Strength of the smoke over middling and big baked fires, 0 to 255 (0 for none)
	"smoke_alpha" = 255,
))

/// How many different fires of each size and heat there are. A turf always gets the same one.
#define FLAME_KINDS 8
/// Above this a fire burns paler
#define FLAME_HOT_TEMPERATURE 4000

// MARK: The plane

/atom/movable/screen/plane_master/fire
	name = "fire plane master"
	plane = FIRE_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = FIRE_RENDER_TARGET
	var/atom/movable/screen/fire_relay/shown
	var/atom/movable/screen/fire_relay/glow/glow

/atom/movable/screen/plane_master/fire/Destroy()
	QDEL_NULL(shown)
	QDEL_NULL(glow)
	return ..()

// No ..(): that adds gravity's warp, and nothing here is on screen to be warped
/atom/movable/screen/plane_master/fire/backdrop(mob/mymob)
	if(!shown)
		shown = new
		glow = new
	if(mymob?.client)
		mymob.client.screen |= shown
		mymob.client.screen |= glow
	set_look()

/atom/movable/screen/plane_master/fire/proc/set_look()
	var/list/look = GLOB.flame_look
	// Station style flames are solid sprites, laid over; the others are light, added
	shown.blend_mode = (look["add"] && GLOB.merged_flames != FLAMES_STATION && GLOB.merged_flames != FLAMES_GAS) ? BLEND_ADD : BLEND_OVERLAY
	glow.clear_filters()
	glow.add_filter("blur", 1, gauss_blur_filter(size = look["glow_blur"]))
	glow.alpha = look["glow_alpha"]

/// The picture of the fires drawn as a thing over the lit game
/atom/movable/screen/fire_relay
	// The bottom left corner is where a plane's picture lines up with the screen
	screen_loc = "SOUTHWEST"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	appearance_flags = NO_CLIENT_COLOR
	plane = ABOVE_LIGHTING_PLANE
	layer = ABOVE_LIGHTING_LAYER + 0.2
	render_source = FIRE_RENDER_TARGET

/atom/movable/screen/fire_relay/glow
	layer = ABOVE_LIGHTING_LAYER + 0.1
	blend_mode = BLEND_ADD

// MARK: The flames

/particles/pixel_flame
	icon = 'icons/effects/flame_bits.dmi'
	icon_state = list("1" = 1, "2" = 1, "3" = 1, "4" = 1, "5" = 1, "6" = 1, "7" = 1, "8" = 1)
	width = 96
	height = 128
	fadein = 1
	fade = 3
	position = generator("box", list(-13, -15), list(13, 5), UNIFORM_RAND)
	drift = generator("vector", list(-0.08, 0), list(0.08, 0.05), UNIFORM_RAND)
	color = 0

/particles/pixel_flame/embers
	icon_state = "spark"
	width = 96
	height = 224
	fade = 8
	position = generator("box", list(-12, -4), list(12, 8), UNIFORM_RAND)
	velocity = generator("vector", list(-0.6, 1.6), list(0.6, 3), UNIFORM_RAND)
	drift = generator("vector", list(-0.3, -0.05), list(0.3, 0.1), UNIFORM_RAND)
	scale = list(1, 1)

/// What shows a fire's flames. A few are made of each kind and every fire of that kind shows one, so a fire costs
/// the server one entry in a list.
/obj/effect/abstract/flame_holder
	invisibility = 0
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	plane = FIRE_PLANE
	blend_mode = BLEND_ADD
	// The fire's own colour and see-through-ness are for the old look
	appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM | KEEP_APART | PIXEL_SCALE

/// The colours a lick goes through as it rises: index 0 when it starts, 1 when it is about to go
/proc/flame_gradient(hot)
	if(hot)
		return list(0, "#ffffff", 0.3, "#e8f0ff", 0.6, "#ffe9a8", 0.85, "#ff9a3c", 1, "#a02a10")
	return list(0, "#fff7d0", 0.25, "#ffd24a", 0.5, "#ff9a22", 0.75, "#e8480e", 1, "#7a1206")

/// The holders for a fire of that size and heat on that turf
/proc/flame_holders(size, hot, turf/where)
	var/static/list/holders = list()
	if(isnull(size))
		for(var/key in holders)
			QDEL_LIST_CONTENTS(holders[key])
		holders = list()
		return
	var/kind = (where.x * 37 + where.y * 61 + where.x * where.y * 11) % FLAME_KINDS
	var/key = "[size]-[hot]-[kind]"
	if(holders[key])
		return holders[key]
	var/list/look = GLOB.flame_look
	var/obj/effect/abstract/flame_holder/flames = new(null)
	var/particles/pixel_flame/licks = new
	licks.count = look["count_[size]"]
	licks.spawning = look["rate_[size]"]
	licks.lifespan = generator("num", look["life_min"], look["life_max"], UNIFORM_RAND)
	licks.velocity = generator("vector", list(-0.15, look["rise_min"]), list(0.15, look["rise_max"]), UNIFORM_RAND)
	licks.scale = generator("vector", list(look["scale_min"], look["scale_min"]), list(look["scale_max"], look["scale_max"]), UNIFORM_RAND)
	licks.grow = list(-look["shrink"], -look["shrink"])
	licks.gradient = flame_gradient(hot)
	licks.color_change = look["cool"]
	flames.particles = licks
	flames.alpha = look["alpha"]
	var/list/parts = list(flames)
	if(look["embers"] > 0 && size > 1)
		var/obj/effect/abstract/flame_holder/sparks = new(null)
		var/particles/pixel_flame/embers/embers = new
		embers.count = look["embers"]
		embers.spawning = look["ember_rate"]
		embers.lifespan = generator("num", 12, 24, UNIFORM_RAND)
		embers.gradient = flame_gradient(hot)
		embers.color_change = look["cool"] * 0.5
		sparks.particles = embers
		parts += sparks
	holders[key] = parts
	return parts

/obj/effect/hotspot
	/// 1, 2 or 3 for a small, middling or big fire
	var/flame_size = 1
	/// Whether we were last drawn hot
	var/flame_hot = FALSE
	/// The value of GLOB.merged_flames we were last drawn for
	var/flame_merged

/// Draws us as a small (1), middling (2) or big (3) fire
/obj/effect/hotspot/proc/set_flame_size(size, force = FALSE)
	var/hot = temperature > FLAME_HOT_TEMPERATURE
	if(!force && size == flame_size && hot == flame_hot && flame_merged == GLOB.merged_flames)
		return
	flame_size = size
	flame_hot = hot
	flame_merged = GLOB.merged_flames
	vis_contents.Cut()
	cut_overlays()
	if(flame_merged == FLAMES_OLD)
		icon = initial(icon)
		icon_state = "[size]"
		return
	icon = null
	if(!isturf(loc))
		return
	if(flame_merged == FLAMES_PARTICLES)
		vis_contents += flame_holders(size, hot, loc)
		return
	var/station = (flame_merged == FLAMES_STATION)
	add_overlay(baked_flame(size, hot, loc, flame_merged))
	if(size > 1 && GLOB.flame_look["smoke_alpha"] > 0)
		add_overlay(baked_smoke(size, loc, station))
	if(station || flame_merged == FLAMES_GAS)
		return
	var/list/holders = flame_holders(size, hot, loc)
	// Only the embers, if this size has them
	if(length(holders) > 1)
		vis_contents += holders[2]

/// The animated flames for a fire of that size and heat on that turf
/proc/baked_flame(size, hot, turf/where, style = FLAMES_BAKED)
	var/static/list/baked = list()
	var/kind = (where.x * 37 + where.y * 61 + where.x * where.y * 11) % FLAME_KINDS
	var/state = "[size][hot ? "h" : ""]-[kind]"
	var/key = "[style][state]"
	if(baked[key])
		return baked[key]
	var/static/list/sheets = list("[FLAMES_BAKED]" = 'icons/effects/flame_bed.dmi', "[FLAMES_STATION]" = 'icons/effects/flame_station.dmi', "[FLAMES_GAS]" = 'icons/effects/flame_gas.dmi')
	var/mutable_appearance/flames = mutable_appearance(sheets["[style]"], state, plane = FIRE_PLANE)
	// The sheet is two tiles wide and three high, with the tile in the middle at the bottom
	flames.pixel_x = -16
	flames.pixel_y = -16
	// Only the KF style is light, added; the others are drawn see-through or solid
	flames.blend_mode = (style == FLAMES_BAKED) ? BLEND_ADD : BLEND_DEFAULT
	flames.appearance_flags = RESET_COLOR | RESET_ALPHA | KEEP_APART | PIXEL_SCALE
	baked[key] = flames
	return flames

/// The smoke over a fire of that size on that turf. It is drawn on the game, under the lighting, so it is as dark as the room and lit by the fire.
/proc/baked_smoke(size, turf/where, station = FALSE, remake = FALSE)
	var/static/list/baked = list()
	if(remake)
		baked = list()
		return
	var/kind = (where.x * 37 + where.y * 61 + where.x * where.y * 11) % FLAME_KINDS
	var/state = "smoke[size]-[kind]"
	var/key = "[station][state]"
	if(baked[key])
		return baked[key]
	var/mutable_appearance/smoke = mutable_appearance(station ? 'icons/effects/flame_station_smoke.dmi' : 'icons/effects/flame_smoke.dmi', state, MASSIVE_OBJ_LAYER + 0.1, GAME_PLANE)
	// The sheet is two tiles wide and four high, with the tile in the middle of the bottom one
	smoke.pixel_x = -16
	smoke.pixel_y = -16
	smoke.alpha = GLOB.flame_look["smoke_alpha"]
	smoke.appearance_flags = RESET_COLOR | RESET_ALPHA | KEEP_APART | PIXEL_SCALE
	baked[key] = smoke
	return smoke

/// Call after changing GLOB.flame_look or GLOB.merged_flames: every fire and every client's fire plane takes the new numbers
/proc/flame_look_changed()
	flame_holders(null)
	baked_smoke(remake = TRUE)
	for(var/obj/effect/hotspot/fire in world)
		fire.set_flame_size(fire.flame_size, TRUE)
	for(var/client/C as anything in GLOB.clients)
		var/atom/movable/screen/plane_master/fire/master = C.mob?.hud_used?.plane_masters["[FIRE_PLANE]"]
		master?.set_look()

#undef FLAME_KINDS
#undef FLAMES_OLD
#undef FLAMES_PARTICLES
#undef FLAMES_BAKED
#undef FLAMES_STATION
#undef FLAMES_GAS
#undef FLAME_HOT_TEMPERATURE
