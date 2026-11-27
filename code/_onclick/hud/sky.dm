// The sky's shared moving art and the round's choice of sky; one sky_art serves every client's layer of its kind

/// Repeating art that moves by itself (twinkle, drift), shared by everyone so all see the same thing at once
/atom/movable/screen/sky_art
	icon = 'icons/effects/sky/sky.dmi'
	blend_mode = BLEND_ADD
	plane = PLANE_SPACE_PARALLAX
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	/// How many times its sprite's size it's drawn
	var/scale = 1
	/// Its sprite's width in pixels: how far apart its copies sit
	var/sprite_size = PARALLAX_TILE

/// Repeats the art round the middle copy, `reach` copies each way
/atom/movable/screen/sky_art/proc/tile(reach = 2)
	transform = matrix(scale, 0, 0, 0, scale, 0)
	var/list/tiles = list()
	for(var/x in -reach to reach)
		for(var/y in -reach to reach)
			if(x == 0 && y == 0)
				continue
			var/mutable_appearance/copy = mutable_appearance(icon, icon_state)
			copy.transform = matrix(1, 0, x * sprite_size, 0, 1, y * sprite_size)
			tiles += copy
	cut_overlays()
	add_overlay(tiles)

/// tile() for a sprite kept as four quarters "<base>_XY": a sprite bigger than the view would grow everyone's map
/atom/movable/screen/sky_art/proc/tile_quarters(base, reach = 2)
	icon_state = "[base]_00"
	transform = matrix(scale, 0, 0, 0, scale, 0)
	var/half = sprite_size / 2
	var/list/tiles = list()
	for(var/x in -reach to reach)
		for(var/y in -reach to reach)
			for(var/qx in 0 to 1)
				for(var/qy in 0 to 1)
					if(x == 0 && y == 0 && qx == 0 && qy == 0)
						continue
					var/mutable_appearance/copy = mutable_appearance(icon, "[base]_[qx][qy]")
					copy.transform = matrix(1, 0, x * sprite_size + qx * half, 0, 1, y * sprite_size + qy * half)
					tiles += copy
	cut_overlays()
	add_overlay(tiles)

/// Fades between full and faint and back every 2 * `half`, for good
/atom/movable/screen/sky_art/proc/twinkle(half)
	animate(src, alpha = 45, time = half, loop = -1, easing = SINE_EASING)
	animate(alpha = 255, time = half, easing = SINE_EASING)

/// Brightens and dims unevenly, for good: a quasar's core
/atom/movable/screen/sky_art/proc/flicker()
	animate(src, alpha = 255, time = 30, loop = -1, easing = SINE_EASING)
	animate(alpha = 170, time = 45, easing = SINE_EASING)
	animate(alpha = 235, time = 20, easing = SINE_EASING)
	animate(alpha = 140, time = 60, easing = SINE_EASING)
	animate(alpha = 215, time = 25, easing = SINE_EASING)
	animate(alpha = 160, time = 40, easing = SINE_EASING)

// Core radii in pixels: how much room each single thing's light takes when placing others
#define SKY_SUN_CORE 105
#define SKY_WORLD_CORE 40
#define SKY_PLANET_CORE 150
#define SKY_GALAXY_CORE 40
/// Least distance from the sun to the galaxy band's middle line
#define SKY_BAND_SUN_GAP 110
/// Extra room between far things
#define SKY_PLACE_MARGIN 30

/datum/controller/subsystem/parallax
	/// This round's sky
	var/datum/sky_theme/theme
	/// The shared art made so far, by name
	var/list/sky_art = list()
	/// Where the single things sit: name to list(x, y), pixels from mid-screen with the eye mid-map
	var/list/body_places = list()
	/// Which part of each theme cloud is overhead this round: list(x, y) pixels each
	var/list/nebula_shifts = list()
	/// How far the galaxy band's middle line runs off the middle of the screen, in pixels along its normal
	var/band_offset = 0
	/// The round's far things: list(sky_deep.dmi state, degrees turned, size), at body_places["deep<n>"]
	var/list/deep_sky = list()
	/// The real sun's bearing as the sky turns: list(degrees clockwise from north, at world.time, degrees per decisecond)
	var/list/turn_line

/// Follows SSsun: lines the sky's turn up with the real sun again when they've drifted over a degree apart
/datum/controller/subsystem/parallax/proc/sun_moved(time = world.time)
	if(!isnum(SSsun.angle))
		return
	var/rate = SSsun.rate * 6 / SSsun.wait
	if(turn_line && turn_line[3] == rate && abs(closer_angle_difference(turn_line[1] + rate * (time - turn_line[2]), SSsun.angle)) <= 1)
		return
	turn_line = list(SSsun.angle, time, rate)
	for(var/client/C as anything in GLOB.clients)
		if(C.mob?.hud_used && isnull(C.parallax_snapped))
			C.mob.hud_used.turn_sky(C)

/// Changes the sky for everyone, there and then
/datum/controller/subsystem/parallax/proc/set_theme(datum/sky_theme/new_theme)
	theme = new_theme
	// The sun to one side, Lavaland opposite it, the other world off to the sun's side, the band clear of the sun
	var/sun_bearing = rand(0, 359)
	var/world_bearing = sun_bearing + pick(-1, 1) * rand(70, 115)
	body_places = list(
		"sun" = list(cos(sun_bearing) * 170, sin(sun_bearing) * 170),
		"world" = list(cos(world_bearing) * 140, sin(world_bearing) * 140))
	deep_sky = list()
	pick_band()
	body_places["galaxy"] = far_spot(SKY_GALAXY_CORE)
	pick_deep_sky()
	nebula_shifts = list()
	var/half_repeat = PARALLAX_TILE * SKY_NEBULA_SCALE / 2
	for(var/list/cloud in theme.nebula)
		var/across = cloud[1] == "band" ? band_offset : rand(-half_repeat, half_repeat)
		nebula_shifts += list(list(rand(-half_repeat, half_repeat), across))
	for(var/name in sky_art)
		qdel(sky_art[name])
	sky_art = list()
	for(var/client/C as anything in GLOB.clients)
		if(C.mob?.hud_used)
			C.mob.hud_used.update_parallax_pref(C.mob)

/// Slants the galaxy band (never flat or upright) and offsets it, keeping it SKY_BAND_SUN_GAP from the sun
/datum/controller/subsystem/parallax/proc/pick_band()
	var/list/sun = body_places["sun"]
	for(var/attempt in 1 to 40)
		theme.band_angle = pick(-1, 1) * rand(20, 70)
		band_offset = rand(-90, 90)
		if(!theme.sun || band_distance(sun[1], sun[2]) >= SKY_BAND_SUN_GAP)
			return

/// How far a point is from the band's middle line; the band repeats every period of its art
/datum/controller/subsystem/parallax/proc/band_distance(x, y)
	var/period = PARALLAX_TILE * SKY_NEBULA_SCALE
	var/across = x * sin(theme.band_angle) + y * cos(theme.band_angle) - band_offset
	across = ((across + period / 2) % period + period) % period - period / 2
	return abs(across)

/// What's already up there as list(x, y, core radius) each: sun, other world, Lavaland's rest, galaxy, far things
/datum/controller/subsystem/parallax/proc/sky_cores()
	. = list()
	var/list/sun = body_places["sun"]
	if(theme.sun)
		. += list(list(sun[1], sun[2], SKY_SUN_CORE))
	if(theme.neighbour)
		var/list/world_place = body_places["world"]
		. += list(list(world_place[1], world_place[2], SKY_WORLD_CORE))
	var/away = arctan(-sun[1], -sun[2])
	. += list(list(cos(away) * SKY_PLANET_REST, sin(away) * SKY_PLANET_REST, SKY_PLANET_CORE))
	if(theme.galaxy && body_places["galaxy"])
		var/list/galaxy = body_places["galaxy"]
		. += list(list(galaxy[1], galaxy[2], SKY_GALAXY_CORE))
	for(var/index in 1 to length(deep_sky))
		var/list/place = body_places["deep[index]"]
		var/list/far_thing = deep_sky[index]
		. += list(list(place[1], place[2], deep_core(far_thing[1]) * far_thing[3]))

/// The radius holding most of a far thing's light at full size
/datum/controller/subsystem/parallax/proc/deep_core(kind)
	var/static/list/cores = list("nebula_ring" = 50, "nebula_bipolar" = 77, "nebula_remnant" = 110, "quasar" = 128)
	return cores[kind] || 80

/// The emptiest of 60 spots for a thing of core radius `r`: clear of every core, off the band, on screen
/datum/controller/subsystem/parallax/proc/far_spot(r)
	var/list/cores = sky_cores()
	var/mass_x = 0
	var/mass_y = 0
	for(var/list/core in cores)
		mass_x += core[1] * core[3]
		mass_y += core[2] * core[3]
	var/mass = sqrt(mass_x ** 2 + mass_y ** 2)
	var/best = -INFINITY
	. = list(0, 0)
	for(var/attempt in 1 to 60)
		var/bearing = rand(0, 359)
		var/reach = rand(55, 100) / 100
		var/x = cos(bearing) * 200 * reach
		var/y = sin(bearing) * 170 * reach
		var/clear = 999
		for(var/list/core in cores)
			clear = min(clear, sqrt((x - core[1]) ** 2 + (y - core[2]) ** 2) - r - core[3] - SKY_PLACE_MARGIN)
		if(length(theme.nebula) && has_band())
			clear = min(clear, (band_distance(x, y) - 80) * 2)
		if(mass)
			clear -= 0.15 * max(0, (x * mass_x + y * mass_y) / mass)
		clear = min(clear, (PARALLAX_TILE / 2 - max(abs(x), abs(y)) - r * 0.4) * 2)
		if(clear > best)
			best = clear
			. = list(x, y)

/// Whether the theme has a galaxy band among its clouds
/datum/controller/subsystem/parallax/proc/has_band()
	for(var/list/cloud in theme.nebula)
		if(cloud[1] == "band")
			return TRUE
	return FALSE

/// Picks the round's far things: mostly one, sometimes two or none, each turned and sized its own way
/datum/controller/subsystem/parallax/proc/pick_deep_sky()
	deep_sky = list()
	// kind to list(smallest, largest) size in hundredths
	var/static/list/sizes = list("nebula_ring" = list(70, 95), "nebula_bipolar" = list(55, 75), "nebula_remnant" = list(40, 55), "quasar" = list(70, 90))
	var/list/kinds = sizes.Copy()
	for(var/index in 1 to pick(0, 1, 1, 1, 2, 2))
		var/kind = pick_n_take(kinds)
		var/list/size = sizes[kind]
		var/scale = rand(size[1], size[2]) / 100
		body_places["deep[index]"] = far_spot(deep_core(kind) * scale)
		deep_sky += list(list(kind, rand(0, 359), scale))

/// One far thing's art for a layer: its sprite, and a quasar's jets and core, moving unless `moving` is FALSE
/datum/controller/subsystem/parallax/proc/deep_art(index, moving)
	var/list/far_thing = deep_sky[index]
	var/kind = far_thing[1]
	var/list/states = list(kind)
	if(kind == "quasar")
		states += moving ? "quasar_jets" : "quasar_jets_still"
		states += "quasar_core"
	var/matrix/turned = matrix(far_thing[3], 0, 0, 0, far_thing[3], 0)
	turned.Turn(far_thing[2])
	. = list()
	for(var/state in states)
		var/name = "deep [index] [state][moving ? "" : " still"]"
		var/atom/movable/screen/sky_art/A = sky_art[name]
		if(!A)
			A = new
			A.icon = 'icons/effects/sky/sky_deep.dmi'
			A.icon_state = state
			A.layer = 5.5 + index * 0.01 + length(.) * 0.001
			A.transform = turned
			if(moving && state == "quasar_core")
				A.flicker()
			sky_art[name] = A
		. += A

/// One theme cloud in its colours
/datum/controller/subsystem/parallax/proc/nebula_art(index)
	var/name = "nebula [index]"
	var/atom/movable/screen/sky_art/A = sky_art[name]
	if(A)
		return A
	var/list/cloud = theme.nebula[index]
	A = new
	A.icon = 'icons/effects/sky/sky_nebula.dmi'
	A.icon_state = cloud[1]
	A.color = cloud[2]
	A.alpha = cloud[3]
	A.layer = 3 + index * 0.01
	A.scale = SKY_NEBULA_SCALE
	if(cloud[1] == "band") // drawn full size in its own sheet so its grain stars stay sharp
		A.icon = 'icons/effects/sky/sky_band.dmi'
		A.scale = 1
		A.sprite_size = PARALLAX_TILE * SKY_NEBULA_SCALE
		A.tile_quarters("band")
		// puts the double-size sprite's middle, the band's line, mid-screen; a transform so it turns with the sky
		A.transform = matrix(1, 0, -PARALLAX_TILE / 2, 0, 1, -PARALLAX_TILE / 2)
	else
		A.tile()
	sky_art[name] = A
	return A

/// One group of twinkling stars, steady unless `moving`
/datum/controller/subsystem/parallax/proc/twinkle_art(group, moving)
	var/name = "twinkle [group][moving ? "" : " still"]"
	var/atom/movable/screen/sky_art/A = sky_art[name]
	if(A)
		return A
	A = new
	A.icon_state = "twinkle[group]"
	A.color = theme.star_tint
	A.layer = 7.1
	A.tile()
	if(moving)
		A.twinkle(9 + group * 4) // each group at its own pace
	else
		A.alpha = 200
	sky_art[name] = A
	return A

/// The near dust's lit specks, catching the light in the sky's colour
/datum/controller/subsystem/parallax/proc/dust_art()
	var/atom/movable/screen/sky_art/A = sky_art["dust lit"]
	if(A)
		return A
	A = new
	A.icon = 'icons/effects/sky/sky_events_dust.dmi'
	A.icon_state = "dust_lit"
	A.color = theme.starlight || theme.sun || COLOR_STARLIGHT
	A.layer = 40.1
	A.tile()
	sky_art["dust lit"] = A
	return A
