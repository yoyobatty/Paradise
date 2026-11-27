// Things that cross the sky (fly-bys) and the rare whole-sky events; all scenery, tied to no game event

/// Something crosses the sky this often
#define SKY_FLYBY_MIN (50 SECONDS)
#define SKY_FLYBY_MAX (170 SECONDS)
#define SKY_EVENT_MIDDLE (PARALLAX_TILE / 2 - 128)
/// How far ahead of its sprite's middle a streak's head is, and a comet's, and a shard's
#define SKY_STREAK_LEAD 84.5
#define SKY_COMET_LEAD 94.5
#define SKY_SHARD_LEAD 63
/// Lavaland's disc in the planet sprites: its radius and how far its middle is off the sheet's, in pixels
#define SKY_LAVALAND_RADIUS 127
/// The giant's sprite is 448 px (under the 480 px view, or BYOND grows the map): scale it to its 512 px art's size
#define SKY_GIANT_SCALE (512 / 448)
/// Moves a 448 px sprite's middle to where a 256 px sky_events.dmi sprite's middle would be
#define SKY_GIANT_NUDGE (256 / 2 - 448 / 2)
#define SKY_LAVALAND_SHIFT_X -1
#define SKY_LAVALAND_SHIFT_Y 0
/// Rare events: none this early in a round, then a memoryless wait with this mean
#define SKY_EVENT_FLOOR (15 MINUTES)
#define SKY_EVENT_MEAN (180 MINUTES)
#define SKY_EVENT_AFTER (45 MINUTES)
#define SKY_EVENT_RETRY (2 MINUTES)
/// Placement (set_theme): radii holding most of each sprite's light
#define SKY_SUN_CORE 105
#define SKY_WORLD_CORE 40
#define SKY_PLANET_CORE 150 // its disc and its halo, plus the 0.4 px a tile it slides as the eye moves
#define SKY_GALAXY_CORE 40
#define SKY_BAND_SUN_GAP 110
/// Extra room between far things: a nebula's faint lobes reach past its core
#define SKY_PLACE_MARGIN 30

/// What the fly-by layer shows: it holds every piece of whatever is crossing the sky, and never moves itself
/atom/movable/screen/sky_art/flyby
	icon = null
	layer = 20
	appearance_flags = RESET_COLOR | NO_CLIENT_COLOR // turns with the sky (no RESET_TRANSFORM)

/// One sprite of a fly-by or an event, in the fly-by layer's holder (or a client's Lavaland, for the aurora)
/atom/movable/screen/sky_art/piece
	icon = 'icons/effects/sky/sky_events.dmi'
	alpha = 0
	layer = 20
	// Turns with the sky (no RESET_TRANSFORM) and is filtered when scaled or turned (no PIXEL_SCALE)
	appearance_flags = RESET_COLOR | NO_CLIENT_COLOR

/atom/movable/screen/sky_art/piece/Destroy()
	SSparallax.flyby?.vis_contents -= src
	SSparallax.near_weather?.vis_contents -= src
	return ..()

/// Where a piece goes: its middle at x, y from the middle of the screen, turned to heading
/proc/sky_at(x, y, heading = 0, size = 1, size_y, nudge = 0)
	var/matrix/M = matrix(size, 0, 0, 0, isnull(size_y) ? size : size_y, 0)
	if(heading)
		M.Turn(heading)
	M.Translate(x + SKY_EVENT_MIDDLE + nudge, y + SKY_EVENT_MIDDLE + nudge)
	return M


/datum/controller/subsystem/parallax
	/// Holds whatever is crossing the sky, shared by every client's fly-by layer
	var/atom/movable/screen/sky_art/flyby/flyby
	/// When the next fly-by goes
	var/next_flyby = 0
	/// When the next rare event comes (sky_event()): set once the round starts
	var/next_sky_event = 0
	/// When the event that's on now is over
	var/event_until = 0
	/// A star only goes once a round: what's left of it stays up
	var/supernova_done = FALSE
	/// The aurora over Lavaland while it's up; it rides every client's planet layer
	var/atom/movable/screen/sky_art/piece/aurora

/datum/controller/subsystem/parallax/proc/flyby_art()
	if(!flyby)
		flyby = new
		next_flyby = world.time + rand(SKY_FLYBY_MIN, SKY_FLYBY_MAX) / 2
	return flyby

/// A new piece in the fly-by layer, gone after life (0: it stays)
/datum/controller/subsystem/parallax/proc/sky_piece(state, life, layer_add = 0)
	var/atom/movable/screen/sky_art/piece/P = new
	P.icon_state = state
	P.layer += layer_add
	var/atom/movable/screen/sky_art/flyby/holder = flyby_art()
	holder.vis_contents += P
	if(life)
		QDEL_IN(P, life)
	return P

/// A straight path across the sky: list(middle x, middle y, along x, along y, half its length)
/datum/controller/subsystem/parallax/proc/sky_path(heading, miss, half)
	var/along_x = cos(heading)
	var/along_y = -sin(heading)
	return list(-along_y * miss, along_x * miss, along_x, along_y, half)

/// Where a piece goes whose head (lead pixels ahead of its middle, along face) is f of the way along a path
/datum/controller/subsystem/parallax/proc/on_path(list/path, f, face, lead = 0, size = 1, flip = 1)
	var/head_x = path[1] + path[3] * path[5] * (2 * f - 1)
	var/head_y = path[2] + path[4] * path[5] * (2 * f - 1)
	return sky_at(head_x - cos(face) * lead * size, head_y + sin(face) * lead * size, face, size, size * flip)

// MARK: Keeping clear of what's already up there

/// How far a point is past the reach of the nearest single thing in the sky (negative: on top of it)
/datum/controller/subsystem/parallax/proc/sky_clearance(x, y, solid, lavaland = TRUE)
	. = INFINITY
	for(var/name in body_places)
		var/reach = 70
		switch(name)
			if("sun")
				if(!theme.sun)
					continue
				reach = 110
			if("world")
				if(!theme.neighbour)
					continue
			if("galaxy")
				if(!theme.galaxy || solid)
					continue
			else // deep1 and on
				if(solid)
					continue
				var/list/far_thing = deep_sky[text2num(copytext(name, 5))]
				reach = 150 * far_thing[3]
		var/list/place = body_places[name]
		. = min(., sqrt((x - place[1]) ** 2 + (y - place[2]) ** 2) - reach)
	if(lavaland)
		. = min(., lavaland_clearance(x, y)) // drawn over the fly-bys and big now: anything placed behind it is lost

/// The worst clearance along the part of a path that's on screen (a 19x15 view at the most)
/datum/controller/subsystem/parallax/proc/path_clearance(list/path, tail = 0, solid)
	. = INFINITY
	var/list/sun = body_places["sun"]
	for(var/step in 0 to 24)
		var/f = step / 24
		var/x = path[1] + path[3] * path[5] * (2 * f - 1)
		var/y = path[2] + path[4] * path[5] * (2 * f - 1)
		if(abs(x) < 310 && abs(y) < 250)
			. = min(., sky_clearance(x, y, solid))
		if(tail)
			var/away = sqrt((x - sun[1]) ** 2 + (y - sun[2]) ** 2) || 1
			for(var/part in list(0.5, 1))
				var/tail_x = x + (x - sun[1]) / away * tail * part
				var/tail_y = y + (y - sun[2]) / away * tail * part
				if(abs(tail_x) < 310 && abs(tail_y) < 250)
					. = min(., sky_clearance(tail_x, tail_y))

/// A path from off screen to off screen, passing within miss_low to miss_high pixels of the middle
/datum/controller/subsystem/parallax/proc/clear_path(miss_low, miss_high, half = 400, tail = 0)
	var/best_clear = -INFINITY
	for(var/attempt in 1 to 40)
		var/list/path = sky_path(rand(0, 359), rand(miss_low, miss_high) * pick(-1, 1), half)
		var/clear = path_clearance(path, tail)
		if(clear > best_clear)
			best_clear = clear
			. = path
		if(clear >= 0)
			return

/// A place for something big to happen: within reach (pixels, a little wider than tall) of the middle
/datum/controller/subsystem/parallax/proc/clear_place(reach_low, reach_high, margin)
	var/best_clear = -INFINITY
	for(var/attempt in 1 to 30)
		var/angle = rand(0, 359)
		var/out = rand(reach_low, reach_high)
		var/x = cos(angle) * out * 1.15
		var/y = sin(angle) * out * 0.85
		var/clear = sky_clearance(x, y)
		if(clear > best_clear)
			best_clear = clear
			. = list(x, y)
		if(clear >= margin)
			return

// MARK: Fly-bys, something crosses the sky every minute or two

/// Sends something across the sky: a shooting star mostly, now and then a comet or ships far off
/datum/controller/subsystem/parallax/proc/launch_flyby(kind, forced_time)
	next_flyby = world.time + rand(SKY_FLYBY_MIN, SKY_FLYBY_MAX)
	if(!flyby && !kind)
		return
	if(!kind)
		kind = pickweight(list("meteor" = 6, "comet" = 1, "ship" = 2))
	switch(kind)
		if("comet")
			send_comet(forced_time)
		if("ship", "convoy")
			if(kind == "ship" && prob(30))
				kind = "convoy"
			send_ship(kind, forced_time)
		else
			var/state = kind == "meteor" ? pickweight(list("meteor" = 5, "meteor_o" = 2, "meteor_b" = 2, "bolide" = 1)) : kind
			var/big = state == "bolide"
			send_meteor(state, clear_path(0, 190), forced_time || (big ? rand(16, 22) : rand(7, 10)))
	return kind

/// A shooting star along a path, edge to edge in time
/datum/controller/subsystem/parallax/proc/send_meteor(state, list/path, time, size = 1)
	var/atom/movable/screen/sky_art/piece/P = sky_piece(state, time + 5)
	var/heading = -arctan(path[3], path[4])
	P.transform = on_path(path, 0, heading, SKY_STREAK_LEAD, size)
	if(state == "bolide")
		animate(P, alpha = 255, transform = on_path(path, 0.15, heading, SKY_STREAK_LEAD, size), time = time * 0.15, flags = ANIMATION_LINEAR_TRANSFORM)
		animate(transform = on_path(path, 0.55, heading, SKY_STREAK_LEAD, size), time = time * 0.4, flags = ANIMATION_LINEAR_TRANSFORM)
		animate(transform = on_path(path, 0.65, heading, SKY_STREAK_LEAD, size * 1.3), time = time * 0.1, flags = ANIMATION_LINEAR_TRANSFORM)
		animate(alpha = 0, transform = on_path(path, 1, heading, SKY_STREAK_LEAD, size * 1.1), time = time * 0.35, flags = ANIMATION_LINEAR_TRANSFORM)
		return
	animate(P, alpha = 255, transform = on_path(path, 0.1, heading, SKY_STREAK_LEAD, size), time = time * 0.1, flags = ANIMATION_LINEAR_TRANSFORM)
	animate(transform = on_path(path, 0.9, heading, SKY_STREAK_LEAD, size), time = time * 0.8, flags = ANIMATION_LINEAR_TRANSFORM)
	animate(alpha = 0, transform = on_path(path, 1, heading, SKY_STREAK_LEAD, size), time = time * 0.1, flags = ANIMATION_LINEAR_TRANSFORM)

/// Ships far off, crossing the whole sky: one, or a convoy of three
/datum/controller/subsystem/parallax/proc/send_ship(kind, time)
	if(!time)
		time = kind == "convoy" ? rand(500, 800) : rand(350, 600)
	var/list/path = clear_path(0, 170)
	var/heading = -arctan(path[3], path[4])
	var/atom/movable/screen/sky_art/piece/P = sky_piece(kind, time + 5)
	P.transform = on_path(path, 0, heading)
	animate(P, alpha = 225, transform = on_path(path, 0.15, heading), time = time * 0.15, flags = ANIMATION_LINEAR_TRANSFORM)
	animate(transform = on_path(path, 0.85, heading), time = time * 0.7, flags = ANIMATION_LINEAR_TRANSFORM)
	animate(alpha = 0, transform = on_path(path, 1, heading), time = time * 0.15, flags = ANIMATION_LINEAR_TRANSFORM)

/// A comet crossing in a few minutes, its ion tail pointing straight away from the sun and its dust tail swept back
/datum/controller/subsystem/parallax/proc/send_comet(time, through_middle, break_at)
	if(!time)
		time = rand(2400, 3300)
	var/list/path = through_middle ? clear_path(0, 90, 400, 170) : clear_path(0, 160, 400, 170)
	if(break_at) // it breaks up where it can be seen: not behind Lavaland, which is drawn over the fly-bys
		var/best = -INFINITY
		for(var/attempt in 1 to 20)
			var/list/maybe = attempt == 1 ? path : clear_path(0, 90, 400, 170)
			var/at_x = maybe[1] + maybe[3] * maybe[5] * (2 * break_at - 1)
			var/at_y = maybe[2] + maybe[4] * maybe[5] * (2 * break_at - 1)
			var/clear = min(lavaland_clearance(at_x, at_y) - 60, path_clearance(maybe, 170) + 30)
			if(clear > best)
				best = clear
				path = maybe
			if(clear >= 0)
				break
	var/list/sun = body_places["sun"]
	var/toward_sun = arctan(sun[1] - path[1], sun[2] - path[2])
	var/face = -toward_sun
	// the dust tail is drawn curving to the right of the head: mirrored when the comet moves right, so it trails
	var/flip = (path[3] * -sin(toward_sun) + path[4] * cos(toward_sun)) > 0 ? 1 : -1
	var/atom/movable/screen/sky_art/piece/P = sky_piece("comet", time + 5)
	P.transform = on_path(path, 0, face, SKY_COMET_LEAD, 1, flip)
	animate(P, alpha = 235, transform = on_path(path, 0.15, face, SKY_COMET_LEAD, 1, flip), time = time * 0.15, flags = ANIMATION_LINEAR_TRANSFORM)
	if(!break_at)
		animate(transform = on_path(path, 0.85, face, SKY_COMET_LEAD, 1, flip), time = time * 0.7, flags = ANIMATION_LINEAR_TRANSFORM)
		animate(alpha = 0, transform = on_path(path, 1, face, SKY_COMET_LEAD, 1, flip), time = time * 0.15, flags = ANIMATION_LINEAR_TRANSFORM)
		return
	animate(transform = on_path(path, break_at, face, SKY_COMET_LEAD, 1, flip), time = time * (break_at - 0.15), flags = ANIMATION_LINEAR_TRANSFORM)
	animate(alpha = 0, transform = on_path(path, break_at + 20 / time, face, SKY_COMET_LEAD, 1, flip), time = 20, flags = ANIMATION_LINEAR_TRANSFORM)
	addtimer(CALLBACK(src, PROC_REF(comet_breaks), path, break_at, time, face, flip), time * break_at)

/// The comet's nucleus flies apart: a flash, a cloud of dust left behind, and the pieces going on, drifting apart
/datum/controller/subsystem/parallax/proc/comet_breaks(list/path, break_at, time, face, flip)
	var/head_x = path[1] + path[3] * path[5] * (2 * break_at - 1)
	var/head_y = path[2] + path[4] * path[5] * (2 * break_at - 1)
	var/speed = path[5] * 2 / time
	var/motion = -arctan(path[3], path[4])
	var/atom/movable/screen/sky_art/piece/flash = sky_piece("flash", 60, 0.3)
	flash.color = "#d8f6ff"
	flash.transform = sky_at(head_x, head_y, 0, 0.12)
	animate(flash, alpha = 255, transform = sky_at(head_x, head_y, 0, 0.45), time = 3, flags = ANIMATION_LINEAR_TRANSFORM)
	animate(alpha = 0, transform = sky_at(head_x, head_y, 0, 0.2), time = 50, easing = QUAD_EASING | EASE_OUT, flags = ANIMATION_LINEAR_TRANSFORM)
	var/atom/movable/screen/sky_art/piece/shock = sky_piece("ring", 70, 0.2)
	var/turn = rand(0, 359)
	shock.transform = sky_at(head_x, head_y, turn, 0.02)
	animate(shock, alpha = 140, time = 2)
	animate(alpha = 0, transform = sky_at(head_x, head_y, turn, 0.35), time = 65, easing = QUAD_EASING | EASE_OUT, flags = ANIMATION_LINEAR_TRANSFORM)
	var/atom/movable/screen/sky_art/piece/dust = sky_piece("puff", 910, -0.1)
	dust.transform = sky_at(head_x, head_y, turn, 0.2)
	animate(dust, alpha = 150, transform = sky_at(head_x + path[3] * speed * 75, head_y + path[4] * speed * 75, turn, 0.7), time = 150, flags = ANIMATION_LINEAR_TRANSFORM)
	animate(alpha = 0, transform = sky_at(head_x + path[3] * speed * 450, head_y + path[4] * speed * 450, turn, 1.5), time = 750, flags = ANIMATION_LINEAR_TRANSFORM)
	var/left = time * (1 - break_at)
	for(var/piece in 1 to 4)
		var/swerve = piece == 1 ? 0 : rand(-7, 7)
		var/pace = piece == 1 ? speed : speed * rand(84, 112) / 100
		var/size = piece == 1 ? 1 : rand(55, 85) / 100
		var/list/shard_path = list(0, 0, cos(motion + swerve), -sin(motion + swerve), pace * left / 2)
		shard_path[1] = head_x + rand(-2, 2) + shard_path[3] * shard_path[5]
		shard_path[2] = head_y + rand(-2, 2) + shard_path[4] * shard_path[5]
		var/shard_face = face + rand(-3, 3)
		var/atom/movable/screen/sky_art/piece/shard = sky_piece("comet_shard", left + 5, piece * 0.01)
		shard.transform = on_path(shard_path, 0, shard_face, SKY_SHARD_LEAD, size, flip)
		var/lit = 30 / left
		animate(shard, alpha = 120 + 110 * size, transform = on_path(shard_path, lit, shard_face, SKY_SHARD_LEAD, size, flip), time = 30, flags = ANIMATION_LINEAR_TRANSFORM)
		animate(transform = on_path(shard_path, 0.8, shard_face, SKY_SHARD_LEAD, size, flip), time = left * (0.8 - lit), flags = ANIMATION_LINEAR_TRANSFORM)
		animate(alpha = 0, transform = on_path(shard_path, 1, shard_face, SKY_SHARD_LEAD, size, flip), time = left * 0.2, flags = ANIMATION_LINEAR_TRANSFORM)

// MARK: Rare events, none in a round's first SKY_EVENT_FLOOR, then a memoryless wait

/// A wait of floor, then an exponential draw with this mean
/proc/sky_wait(floor, mean)
	return floor + round(-mean * log(max(rand(), 0.0001)))

/// Starts one of the rare events (kind, or a pick among those that fit now) and puts the next one off
/datum/controller/subsystem/parallax/proc/sky_event(kind)
	if(!kind)
		if(world.time < event_until)
			next_sky_event = event_until + SKY_EVENT_RETRY
			return
		var/list/kinds = list("vortex" = 3, "shower" = 3, "battle" = 2, "breakup" = 2, "giant" = 2)
		if(theme.sun)
			kinds["prism"] = 2
		if(!supernova_done)
			kinds["supernova"] = 1
		if(planet_watched())
			kinds["aurora"] = 2
		kind = pickweight(kinds)
	flyby_art()
	var/length
	switch(kind)
		if("vortex")
			length = start_vortex()
		if("shower")
			length = start_shower()
		if("supernova")
			length = start_supernova()
		if("battle")
			length = start_battle()
		if("aurora")
			length = start_aurora()
		if("breakup")
			length = send_comet(rand(2700, 3300), TRUE, rand(42, 52) / 100) || 3300
		if("prism")
			length = start_prism()
		if("giant")
			length = start_giant()
	if(!length)
		next_sky_event = world.time + SKY_EVENT_RETRY
		return
	event_until = world.time + length
	next_sky_event = event_until + sky_wait(SKY_EVENT_AFTER, SKY_EVENT_MEAN)
	log_game("Sky event: [kind]")
	return kind

/// Whether anyone with the sky up can see Lavaland: it's only shown from the station's z-level
/datum/controller/subsystem/parallax/proc/planet_watched()
	for(var/client/C as anything in GLOB.clients)
		var/turf/T = get_turf(C.mob)
		if(T && is_station_level(T.z))
			return TRUE

/// An ion maelstrom: a storm of glowing gas winds into a spiral over the station
/datum/controller/subsystem/parallax/proc/start_vortex()
	var/fade = 45 SECONDS
	var/peak = rand(6 MINUTES, 9 MINUTES)
	var/life = peak + fade * 2 + 5
	var/atom/movable/screen/sky_art/piece/far = sky_piece("vortex_far", life, -3)
	spin(far, 3.1, 7 MINUTES, rand(0, 359))
	animate(far, alpha = 170, time = fade, easing = SINE_EASING, flags = ANIMATION_PARALLEL)
	animate(time = peak)
	animate(alpha = 0, time = fade, easing = SINE_EASING)
	var/near_angle = rand(0, 359)
	var/atom/movable/screen/sky_art/piece/shroud = sky_piece("vortex_shroud", life, -3.05) // the storm's dust
	shroud.blend_mode = BLEND_MULTIPLY
	spin(shroud, 3.4, 4 MINUTES, near_angle)
	animate(shroud, alpha = 255, time = fade, easing = SINE_EASING, flags = ANIMATION_PARALLEL)
	animate(time = peak)
	animate(alpha = 0, time = fade, easing = SINE_EASING)
	var/atom/movable/screen/sky_art/piece/near = sky_piece("vortex", life, -2.9)
	spin(near, 3.4, 4 MINUTES, near_angle)
	animate(near, alpha = 215, time = fade, easing = SINE_EASING, flags = ANIMATION_PARALLEL)
	animate(time = peak)
	animate(alpha = 0, time = fade, easing = SINE_EASING)
	var/atom/movable/screen/sky_art/piece/eye = sky_piece("vortex_eye", life, -2.8)
	eye.transform = sky_at(0, 0, 0, 2.0)
	animate(eye, color = "#7c7c7c", time = 25, loop = -1, easing = SINE_EASING) // the rim throbs
	animate(color = "#ffffff", time = 18, easing = SINE_EASING)
	animate(eye, alpha = 220, transform = sky_at(0, 0, 0, 3.4), time = fade * 1.6, easing = SINE_EASING, flags = ANIMATION_PARALLEL)
	animate(time = peak - fade * 0.6)
	animate(alpha = 0, time = fade, easing = SINE_EASING)
	var/at = fade
	while(at < fade + peak)
		addtimer(CALLBACK(src, PROC_REF(vortex_lightning)), at)
		if(prob(30)) // a second stroke hard on the first
			addtimer(CALLBACK(src, PROC_REF(vortex_lightning)), at + rand(3, 8))
		at += rand(25, 160)
	return life

/// Turns a piece in the middle of the sky round and round, a whole turn every period, for as long as it lasts
/datum/controller/subsystem/parallax/proc/spin(atom/movable/screen/sky_art/piece/P, size, period, angle)
	P.transform = sky_at(0, 0, angle, size)
	animate(P, transform = sky_at(0, 0, angle + 90, size), time = period / 4, loop = -1)
	animate(transform = sky_at(0, 0, angle + 180, size), time = period / 4)
	animate(transform = sky_at(0, 0, angle + 270, size), time = period / 4)
	animate(transform = sky_at(0, 0, angle, size), time = period / 4)

/// A fork of lightning inside the maelstrom's arms, and the whole storm lit by it for a moment
/datum/controller/subsystem/parallax/proc/vortex_lightning()
	var/x
	var/y
	var/angle
	for(var/attempt in 1 to 6) // lit gas over a bright far thing would wash it out to white: strike clear of them
		angle = rand(0, 359)
		var/out = rand(90, 230)
		x = cos(angle) * out
		y = sin(angle) * out
		if(sky_clearance(x, y) > 40)
			break
	var/size = rand(80, 135) / 100
	var/atom/movable/screen/sky_art/piece/bolt = sky_piece(pick("lightning", "lightning2"), 15, 0.5)
	bolt.transform = sky_at(x, y, -angle + 90 + rand(-35, 35), size, size * pick(-1, 1))
	animate(bolt, alpha = 255, time = 1)
	animate(alpha = 80, time = 1)
	animate(alpha = 255, time = 1)
	animate(alpha = 0, time = 9, easing = QUAD_EASING | EASE_OUT)
	var/atom/movable/screen/sky_art/piece/lit = sky_piece("glow", 14, -2.5)
	lit.color = "#9c94e0"
	lit.transform = sky_at(x * 0.85, y * 0.85, 0, 2.6)
	animate(lit, alpha = 34, time = 1)
	animate(alpha = 12, time = 1)
	animate(alpha = 28, time = 1)
	animate(alpha = 0, time = 10, easing = QUAD_EASING | EASE_OUT)

/// A meteor storm, seven minutes of it, nine hundred shooting stars
/datum/controller/subsystem/parallax/proc/start_shower(length = 7 MINUTES)
	var/radiant_x
	var/radiant_y
	var/best = -1
	var/first = rand(0, 23) * 15
	for(var/turn in 0 to 23) // the side of the sky most of whose streams would come through clear of the sun and the
		var/bearing = first + turn * 15
		var/x = cos(bearing) * 380
		var/y = sin(bearing) * 330
		var/clear = 0
		for(var/aim in 1 to 12)
			var/aim_x = (aim % 4 - 1.5) * 160
			var/aim_y = (round((aim - 1) / 4) - 1) * 150
			var/dist = sqrt((aim_x - x) ** 2 + (aim_y - y) ** 2)
			if(path_clearance(list(x + (aim_x - x) / dist * 450, y + (aim_y - y) / dist * 450, (aim_x - x) / dist, (aim_y - y) / dist, 450), 0, TRUE) >= 0)
				clear++
		if(clear > best)
			best = clear
			radiant_x = x
			radiant_y = y
	for(var/meteor in 1 to rand(1600, 1800)) // a storm, not a shower: at its peak a dozen or more streaks are in the
		addtimer(CALLBACK(src, PROC_REF(shower_meteor), radiant_x, radiant_y), clamp(gaussian(0.5, 0.17), 0.01, 0.99) * length)
	return length

/datum/controller/subsystem/parallax/proc/shower_meteor(radiant_x, radiant_y)
	var/list/path
	for(var/attempt in 1 to 12) // aimed at a point on screen, from the radiant
		var/aim_x = rand(-280, 280)
		var/aim_y = rand(-220, 220)
		var/dx = aim_x - radiant_x
		var/dy = aim_y - radiant_y
		var/dist = sqrt(dx * dx + dy * dy)
		var/start = rand(0, 90)
		var/list/maybe = list(radiant_x + dx / dist * (start + 450), radiant_y + dy / dist * (start + 450), dx / dist, dy / dist, 450)
		if(lavaland_clearance(aim_x, aim_y) >= 0)
			path = maybe
			break
	if(!path)
		return
	var/state = pickweight(list("meteor" = 6, "meteor_o" = 2, "meteor_b" = 3, "bolide" = 1))
	send_meteor(state, path, state == "bolide" ? rand(30, 40) : rand(15, 24), state == "bolide" ? 1 : rand(65, 100) / 100)

/// A star in the sky swells, then blows up: a flash that lights the whole sky and a shock front rushing out
/datum/controller/subsystem/parallax/proc/start_supernova()
	if(supernova_done)
		return
	supernova_done = TRUE
	var/list/place = clear_place(70, 140, 60)
	var/x = place[1]
	var/y = place[2]
	var/atom/movable/screen/sky_art/piece/star = sky_piece("star_point", 640)
	star.transform = sky_at(x, y)
	star.color = "#ffe6c8"
	animate(star, alpha = 150, time = 200)
	animate(alpha = 255, color = "#ffffff", transform = sky_at(x, y, 0, 1.8), time = 400, easing = QUAD_EASING | EASE_IN, flags = ANIMATION_LINEAR_TRANSFORM)
	animate(alpha = 0, time = 20)
	addtimer(CALLBACK(src, PROC_REF(supernova_flash), x, y), 600)
	return 10 MINUTES

/datum/controller/subsystem/parallax/proc/supernova_flash(x, y)
	var/atom/movable/screen/sky_art/piece/flash = sky_piece("flash", 0, 0.3)
	flash.color = "#f4f8ff"
	flash.transform = sky_at(x, y, 0, 0.3)
	animate(flash, alpha = 255, transform = sky_at(x, y, 0, 1.5), time = 12, easing = SINE_EASING, flags = ANIMATION_LINEAR_TRANSFORM)
	animate(alpha = 220, transform = sky_at(x, y, 0, 1.05), time = 150, easing = SINE_EASING, flags = ANIMATION_LINEAR_TRANSFORM)
	animate(alpha = 150, color = "#ffd9b4", transform = sky_at(x, y, 0, 0.75), time = 900, easing = SINE_EASING, flags = ANIMATION_LINEAR_TRANSFORM)
	animate(alpha = 80, color = "#ff9a7c", transform = sky_at(x, y, 0, 0.5), time = 4800, easing = SINE_EASING, flags = ANIMATION_LINEAR_TRANSFORM)
	var/atom/movable/screen/sky_art/piece/sky = sky_piece("glow", 360, -2)
	sky.color = "#e8f0ff"
	sky.transform = sky_at(x, y, 0, 5)
	animate(sky, alpha = 105, time = 12, easing = SINE_EASING)
	animate(alpha = 0, time = 340, easing = QUAD_EASING | EASE_OUT)
	var/atom/movable/screen/sky_art/piece/shock = sky_piece("ring", 470, 0.2)
	var/turn = rand(0, 359)
	shock.color = "#cfe4ff"
	shock.transform = sky_at(x, y, turn, 0.03)
	animate(shock, alpha = 120, time = 25)
	animate(alpha = 0, transform = sky_at(x, y, turn, 2.4), time = 460, easing = QUAD_EASING | EASE_OUT, flags = ANIMATION_LINEAR_TRANSFORM)
	var/atom/movable/screen/sky_art/piece/remnant = sky_piece("remnant", 0, -0.2)
	turn = rand(0, 359)
	remnant.transform = sky_at(x, y, turn, 0.1)
	animate(remnant, alpha = 0, time = 60)
	animate(alpha = 230, transform = sky_at(x, y, turn, 0.7), time = 3000, easing = SINE_EASING, flags = ANIMATION_LINEAR_TRANSFORM)
	animate(alpha = 190, transform = sky_at(x, y, turn, 1.1), time = 15000, flags = ANIMATION_LINEAR_TRANSFORM)

/// A battle, close enough to fill the middle of the sky, six or seven minutes of it
/datum/controller/subsystem/parallax/proc/start_battle()
	var/fade = 45 SECONDS
	var/time = rand(5 MINUTES, 7 MINUTES) + fade * 2
	var/list/middle = clear_place(0, 70, 110)
	var/short = 70 - lavaland_clearance(middle[1], middle[2]) // Lavaland's drawn over the fly-bys
	if(short > 0)
		var/list/sun = body_places["sun"]
		var/away = (sun && (sun[1] || sun[2])) ? arctan(-sun[1], -sun[2]) : 270
		middle = list(middle[1] - cos(away) * short, middle[2] - sin(away) * short)
	var/line = rand(-25, 25) + pick(0, 180)
	var/gap = rand(105, 130) // the lines' hulls spread ~65 px each way now: room between them for the shots
	var/list/sides = list(
		list(middle[1] - cos(line) * gap, middle[2] + sin(line) * gap, line, "#ffb48c", "fleet_a"),
		list(middle[1] + cos(line) * gap, middle[2] - sin(line) * gap, line + 180, "#9edcff", "fleet_b"))
	for(var/list/side as anything in sides)
		var/atom/movable/screen/sky_art/piece/fleet = sky_piece(side[5], time + 5)
		fleet.color = side[4]
		fleet.transform = sky_at(side[1], side[2], side[3], 2.2)
		animate(fleet, alpha = 235, time = fade)
		animate(time = time - fade * 2)
		animate(alpha = 0, time = fade)
	var/at = fade * 0.6
	while(at < time - fade)
		addtimer(CALLBACK(src, PROC_REF(battle_shot), sides), at)
		at += rand(1, 7)
	for(var/when in list(0.3, 0.55, 0.8))
		addtimer(CALLBACK(src, PROC_REF(battle_kill), pick(sides)), time * when + rand(-60, 60))
	return time

/datum/controller/subsystem/parallax/proc/battle_shot(list/sides)
	var/list/from = pick(sides)
	var/list/target = from == sides[1] ? sides[2] : sides[1]
	var/from_x = from[1] + rand(-22, 22)
	var/from_y = from[2] + rand(-12, 12)
	var/to_x = target[1] + rand(-24, 24)
	var/to_y = target[2] + rand(-13, 13)
	var/dx = to_x - from_x
	var/dy = to_y - from_y
	var/dist = max(1, sqrt(dx * dx + dy * dy))
	var/heading = -arctan(dx, dy)
	var/hit_in
	if(prob(10)) // a capital ship's beam, the whole way at once
		var/atom/movable/screen/sky_art/piece/beam = sky_piece("lance", 22, 0.1)
		beam.color = from[4]
		beam.transform = sky_at(from_x + dx * 0.5, from_y + dy * 0.5, heading, dist / 228, 1.6)
		animate(beam, alpha = 255, time = 1)
		animate(alpha = 140, time = 2)
		animate(alpha = 255, time = 2)
		animate(alpha = 205, time = 8)
		animate(alpha = 0, time = 6)
		hit_in = 2
	else
		var/atom/movable/screen/sky_art/piece/shots = sky_piece("volley", 25)
		shots.color = from[4]
		var/flight = max(4, dist / 12)
		shots.transform = sky_at(from_x, from_y, heading, 1.7)
		animate(shots, alpha = 255, transform = sky_at(from_x + dx / flight, from_y + dy / flight, heading, 1.7), time = 1, flags = ANIMATION_LINEAR_TRANSFORM)
		animate(alpha = 210, transform = sky_at(from_x + dx * 0.9, from_y + dy * 0.9, heading, 1.7), time = flight - 2, flags = ANIMATION_LINEAR_TRANSFORM)
		animate(alpha = 0, transform = sky_at(to_x, to_y, heading, 1.7), time = 1, flags = ANIMATION_LINEAR_TRANSFORM)
		hit_in = flight
		if(prob(50))
			return
	var/atom/movable/screen/sky_art/piece/hit = sky_piece("pop", hit_in + 16, 0.2)
	var/turn = rand(0, 359)
	hit.transform = sky_at(to_x, to_y, turn, 0.3)
	animate(hit, time = hit_in)
	animate(alpha = 255, transform = sky_at(to_x, to_y, turn, 0.65), time = 1, flags = ANIMATION_LINEAR_TRANSFORM)
	animate(alpha = 0, transform = sky_at(to_x, to_y, turn, 1.1), time = rand(6, 12), easing = QUAD_EASING | EASE_OUT, flags = ANIMATION_LINEAR_TRANSFORM)

/datum/controller/subsystem/parallax/proc/battle_kill(list/side)
	var/x = side[1] + rand(-18, 18)
	var/y = side[2] + rand(-9, 9)
	var/turn = rand(0, 359)
	var/atom/movable/screen/sky_art/piece/blast = sky_piece("kill", 95, 0.3)
	blast.transform = sky_at(x, y, turn, 0.3)
	animate(blast, alpha = 255, transform = sky_at(x, y, turn, 0.8), time = 2, flags = ANIMATION_LINEAR_TRANSFORM)
	animate(alpha = 0, transform = sky_at(x, y, turn, 1.8), time = 90, easing = QUAD_EASING | EASE_OUT, flags = ANIMATION_LINEAR_TRANSFORM)
	var/atom/movable/screen/sky_art/piece/shock = sky_piece("ring", 60, 0.2)
	shock.color = "#ffd2a0"
	shock.transform = sky_at(x, y, turn, 0.02)
	animate(shock, alpha = 80, time = 1)
	animate(alpha = 0, transform = sky_at(x, y, turn, 0.8), time = 55, easing = QUAD_EASING | EASE_OUT, flags = ANIMATION_LINEAR_TRANSFORM)
	var/atom/movable/screen/sky_art/piece/light = sky_piece("glow", 50, -1)
	light.color = "#ffc890"
	light.transform = sky_at(x, y, 0, 1.8)
	animate(light, alpha = 90, time = 2)
	animate(alpha = 0, time = 45, easing = QUAD_EASING | EASE_OUT)

/// A stream of ice crystals drifting between the station and the sun, six to eight minutes of it
/datum/controller/subsystem/parallax/proc/start_prism()
	var/list/sun = body_places["sun"]
	if(!theme.sun || !sun)
		return
	var/fade = 45 SECONDS
	var/time = rand(6 MINUTES, 8 MINUTES) + fade * 2
	var/wind = rand(0, 359)
	var/atom/movable/screen/sky_art/piece/halo = sky_piece("prism_halo", time + 5, -3)
	halo.transform = sky_at(sun[1], sun[2], wind, 1.25)
	animate(halo, time = fade)
	animate(alpha = 110, time = 2 MINUTES, easing = SINE_EASING)
	var/hold = max(0, time * 0.6 - fade - 2 MINUTES) // the halo goes as the crystals thin out
	animate(time = hold)
	animate(alpha = 0, time = time - fade - 2 MINUTES - hold, easing = SINE_EASING)
	for(var/shard in 1 to rand(60, 72)) // thin at first and at the end, thickest in the middle
		var/depth = rand(0, 100) / 100
		var/crossing = round(1900 - 1150 * depth)
		var/start = clamp(gaussian(0.45, 0.24), 0, 1) * max(10, time - fade - crossing)
		addtimer(CALLBACK(src, PROC_REF(prism_shard), wind, depth, crossing), start)
	for(var/speck in 1 to rand(170, 210))
		addtimer(CALLBACK(src, PROC_REF(prism_speck)), clamp(gaussian(0.5, 0.25), 0.03, 0.97) * time)
	return time

/// One crystal drifting across on the wind, from depth 0 (far, small, dim) to 1 (near)
/datum/controller/subsystem/parallax/proc/prism_shard(wind, depth, crossing)
	var/size = 0.3 + 0.85 * depth
	var/list/path
	for(var/attempt in 1 to 8)
		var/list/maybe = sky_path(wind + rand(-10, 10), rand(-270, 270), 330 + 130 * size)
		if(world_clearance(maybe) >= 75 * size) // the whole crystal clear of the other world
			path = maybe
			break
	if(!path)
		return
	var/atom/movable/screen/sky_art/piece/P = sky_piece(pick("prism_shard", "prism_shard2", "prism_shard3"), crossing + 5, depth * 0.5)
	var/angle = rand(0, 359)
	var/turning = rand(35, 140) * pick(-1, 1) // degrees a minute
	var/steps = max(3, round(crossing / 150))
	var/list/sun = body_places["sun"]
	P.transform = sky_at(path[1] - path[3] * path[5], path[2] - path[4] * path[5], angle, size)
	for(var/step in 1 to steps) // no ANIMATION_LINEAR_TRANSFORM: the turn is taken apart from the move
		var/f = step / steps
		var/matrix/M = sky_at(path[1] + path[3] * path[5] * (2 * f - 1), path[2] + path[4] * path[5] * (2 * f - 1), angle + turning * crossing * f / 600, size)
		if(step == 1)
			animate(P, transform = M, time = crossing / steps)
		else
			animate(transform = M, time = crossing / steps)
	animate(P, alpha = round(80 + 130 * depth), time = 40, flags = ANIMATION_PARALLEL)
	if(depth > 0.45 && prob(60))
		var/at = rand(25, 75) / 100
		var/x = path[1] + path[3] * path[5] * (2 * at - 1)
		var/y = path[2] + path[4] * path[5] * (2 * at - 1)
		addtimer(CALLBACK(src, PROC_REF(prism_flare), x, y, sun[1], sun[2], 0.7 + depth * 0.6), round(crossing * at))

/// How far a path's on-screen part keeps from the other world
/datum/controller/subsystem/parallax/proc/world_clearance(list/path)
	. = INFINITY
	var/list/place = body_places["world"]
	if(!theme.neighbour || !place)
		return
	for(var/step in 0 to 24)
		var/f = step / 24
		var/x = path[1] + path[3] * path[5] * (2 * f - 1)
		var/y = path[2] + path[4] * path[5] * (2 * f - 1)
		if(abs(x) < 310 && abs(y) < 250)
			. = min(., sqrt((x - place[1]) ** 2 + (y - place[2]) ** 2) - 70)

/// A crystal catching the sun: a hard white star and a fan of colour thrown straight away from the sun
/datum/controller/subsystem/parallax/proc/prism_flare(x, y, sun_x, sun_y, size)
	var/away = -arctan(x - sun_x, y - sun_y)
	var/atom/movable/screen/sky_art/piece/flare = sky_piece("prism_flare", 40, 1)
	flare.transform = sky_at(x + cos(away) * 68 * size, y - sin(away) * 68 * size, away, size)
	animate(flare, alpha = 255, time = 4, easing = SINE_EASING)
	animate(time = 6)
	animate(alpha = 0, time = 25, easing = QUAD_EASING | EASE_OUT)

/// A glint of the fine crystal dust between the shards
/datum/controller/subsystem/parallax/proc/prism_speck()
	var/x = rand(-250, 250)
	var/y = rand(-200, 200)
	if(sky_clearance(x, y, TRUE) < 0)
		return
	var/atom/movable/screen/sky_art/piece/speck = sky_piece("star_point", 30, -0.5)
	speck.color = pick("#ffe0d0", "#fff4d0", "#e0ffe8", "#d8ecff", "#ead8ff")
	speck.transform = sky_at(x, y, rand(0, 359), rand(18, 40) / 100)
	animate(speck, alpha = rand(150, 255), time = 4)
	animate(alpha = 0, time = rand(12, 24), easing = QUAD_EASING | EASE_OUT)

/// A ringed giant over the station, six to nine minutes: it comes out of the dark across from the sun
/datum/controller/subsystem/parallax/proc/start_giant()
	var/fade = 45 SECONDS
	var/time = rand(6 MINUTES, 9 MINUTES) + fade * 2
	var/list/sun = body_places["sun"]
	var/lit = theme.sun && sun && (sun[1] || sun[2])
	var/away = lit ? arctan(-sun[1], -sun[2]) : rand(0, 359)
	var/dark_light = rand(0, 359)
	var/best = -INFINITY
	var/x
	var/y
	var/size
	var/light
	for(var/try_size in list(0.9, 0.76, 0.64)) // as big as fits clear of the sun, the other world and Lavaland
		var/first = rand(0, 11) * 30
		for(var/turn in 0 to 11)
			for(var/out in list(40, 75, 110, 150, 185)) // out to half off the frame's edge
				var/cx = cos(first + turn * 30) * out * 1.1
				var/cy = sin(first + turn * 30) * out * 0.9
				var/toward = lit ? arctan(sun[1] - cx, sun[2] - cy) : dark_light
				var/clear = giant_clearance(cx, cy, toward, try_size)
				var/score = min(clear, 40) - out * 0.06 // clear enough, then as near the middle as can be
				if(score > best)
					best = score
					x = cx
					y = cy
					size = try_size
					light = toward
		if(best >= 0)
			break
	if(best < -30)
		return
	var/drift_x = 0
	var/drift_y = 0
	var/drift_clear = -INFINITY
	for(var/drift in 0 to 7) // it drifts the way that keeps it clearest, start and end
		var/dx = cos(drift * 45 + away) * 30
		var/dy = sin(drift * 45 + away) * 30
		var/clear = min(giant_clearance(x - dx, y - dy, light, size), giant_clearance(x + dx, y + dy, light, size * 1.06))
		if(clear > drift_clear + 1)
			drift_clear = clear
			drift_x = dx
			drift_y = dy
	var/atom/movable/screen/sky_art/piece/shine = sky_piece("ring_shine", time + 5, -1.1)
	shine.transform = sky_at(x, y, -light, size * 2.1)
	animate(shine, alpha = 150, time = fade * 2, easing = SINE_EASING)
	animate(time = time - fade * 4)
	animate(alpha = 0, time = fade * 2, easing = SINE_EASING)
	var/atom/movable/screen/sky_art/piece/giant = sky_piece("giant", time + 5, -1)
	giant.icon = 'icons/effects/sky/sky_events_big.dmi'
	giant.blend_mode = BLEND_OVERLAY
	giant.color = "#000000"
	giant.transform = sky_at(x - drift_x, y - drift_y, -light, size * SKY_GIANT_SCALE, nudge = SKY_GIANT_NUDGE)
	animate(giant, alpha = 255, color = "#ffffff", time = fade * 1.5, easing = SINE_EASING) // out of the dark
	animate(time = time - fade * 3)
	animate(alpha = 0, color = "#000000", time = fade * 1.5, easing = SINE_EASING)
	animate(giant, transform = sky_at(x + drift_x, y + drift_y, -light, size * 1.06 * SKY_GIANT_SCALE, nudge = SKY_GIANT_NUDGE), time = time, easing = SINE_EASING, flags = ANIMATION_PARALLEL)
	// a moon crossing its face: round the front of an orbit just inside the rings (flyby.py RING_ANGLE, RING_OPEN)
	var/atom/movable/screen/sky_art/piece/moon = sky_piece("moon", time + 5, -0.9)
	moon.blend_mode = BLEND_OVERLAY
	var/major = 112 * 1.2 * size
	var/minor = major * 0.32
	var/steps = 12
	for(var/step in 0 to steps)
		var/along = 15 + 150 * step / steps
		var/f = step / steps
		var/ax = cos(along) * major
		var/ay = sin(along) * minor
		var/mx = x - drift_x + drift_x * 2 * f + cos(light + 32) * ax + cos(light + 122) * ay
		var/my = y - drift_y + drift_y * 2 * f + sin(light + 32) * ax + sin(light + 122) * ay
		if(!step)
			moon.transform = sky_at(mx, my, -light, 0.9)
		else if(step == 1)
			animate(moon, transform = sky_at(mx, my, -light, 0.9), time = time / steps, flags = ANIMATION_LINEAR_TRANSFORM)
		else
			animate(transform = sky_at(mx, my, -light, 0.9), time = time / steps, flags = ANIMATION_LINEAR_TRANSFORM)
	moon.color = "#000000"
	animate(moon, alpha = 255, color = "#ffffff", time = fade * 1.5, easing = SINE_EASING, flags = ANIMATION_PARALLEL)
	animate(time = time - fade * 3)
	animate(alpha = 0, color = "#000000", time = fade * 1.5, easing = SINE_EASING)
	return time

/// How clear of the sun and the other world a ringed giant would be (giant()): its disc, and points round its rings
/datum/controller/subsystem/parallax/proc/giant_clearance(x, y, light, size)
	. = min(sky_clearance(x, y, TRUE), sky_clearance(x, y) + 40, lavaland_clearance(x, y)) - 112 * size
	var/major = 112 * 2.18 * size
	var/minor = major * 0.32
	for(var/along in 0 to 345 step 15)
		var/ax = cos(along) * major
		var/ay = sin(along) * minor
		var/px = x + cos(light + 32) * ax + cos(light + 122) * ay
		var/py = y + sin(light + 32) * ax + sin(light + 122) * ay
		. = min(., sky_clearance(px, py, TRUE, FALSE), sky_clearance(px, py, FALSE, FALSE) + 40, lavaland_clearance(px, py) + 80)

/// How far a point is past Lavaland's disc where it rests on screen (parallax.dm planet_rest(), opposite the sun)
/datum/controller/subsystem/parallax/proc/lavaland_clearance(x, y)
	var/list/sun = body_places["sun"]
	var/rest_x = 0
	var/rest_y = -SKY_PLANET_REST
	if(sun && (sun[1] || sun[2]))
		var/away = arctan(-sun[1], -sun[2])
		rest_x = cos(away) * SKY_PLANET_REST
		rest_y = sin(away) * SKY_PLANET_REST
	return sqrt((x - rest_x) ** 2 + (y - rest_y) ** 2) - SKY_PLANET_CORE // its disc is drawn ~128 px across now

/// Aurorae over Lavaland's poles for seven or eight minutes
/datum/controller/subsystem/parallax/proc/start_aurora()
	end_aurora()
	var/fade = 45 SECONDS
	var/time = rand(7 MINUTES, 8 MINUTES)
	aurora = new
	aurora.icon_state = "aurora"
	aurora.layer = 31
	var/size = SKY_LAVALAND_RADIUS / 64
	// the planet layer turns its sprites lit from SKY_PLANET_BAKE_ANGLE; the aurora art is drawn for one lit from the east
	var/matrix/M = matrix(size, 0, 0, 0, size, 0)
	M.Turn(-SKY_PLANET_BAKE_ANGLE)
	M.Translate(SKY_EVENT_MIDDLE + SKY_LAVALAND_SHIFT_X, SKY_EVENT_MIDDLE + SKY_LAVALAND_SHIFT_Y)
	aurora.transform = M
	add_planet_art(aurora)
	animate(aurora, alpha = 170, time = fade, easing = SINE_EASING)
	animate(alpha = 120, time = 600, easing = SINE_EASING)
	animate(alpha = 255, time = 50) // the substorm: the whole oval lights up at once
	animate(alpha = 190, time = 500, easing = SINE_EASING)
	animate(alpha = 235, time = 400, easing = SINE_EASING)
	animate(time = time - fade * 2 - 1550)
	animate(alpha = 0, time = fade, easing = SINE_EASING)
	addtimer(CALLBACK(src, PROC_REF(end_aurora)), time)
	return time

/datum/controller/subsystem/parallax/proc/end_aurora()
	if(!aurora)
		return
	remove_planet_art(aurora)
	QDEL_NULL(aurora)

/// Lavaland carries its aurora and ash storm while they're up, for late arrivals too
/atom/movable/screen/parallax_layer/body/planet/set_quality(quality)
	vis_contents = carry(SSparallax.planet_art.Copy())


/datum/controller/subsystem/parallax/fire(resumed = 0)
	if(!resumed && flyby)
		if(world.time >= next_flyby)
			launch_flyby()
		if(!next_sky_event)
			if(SSticker.HasRoundStarted())
				next_sky_event = world.time + sky_wait(SKY_EVENT_FLOOR, SKY_EVENT_MEAN)
		else if(world.time >= next_sky_event)
			sky_event()
	..()


/// Comets, shooting stars and far-off ships cross this one; everyone's shows the same shared object
/atom/movable/screen/parallax_layer/flybys
	icon_state = null
	layer = 20
	// held to the middle of the screen: a fly-by's path is laid out round it
	absolute = TRUE
	detail = PARALLAX_HIGH
	quality = SKY_QUALITY_HIGH

/atom/movable/screen/parallax_layer/flybys/place_x(eye_x)
	return 0

/atom/movable/screen/parallax_layer/flybys/place_y(eye_y)
	return 0

/atom/movable/screen/parallax_layer/flybys/set_quality(quality)
	vis_contents = carry(list(SSparallax.flyby_art()))

/// Hidden on reserved levels (shuttles in transit)
/atom/movable/screen/parallax_layer/flybys/update_status(mob/M)
	var/turf/T = get_turf(M)
	invisibility = (T && check_level_trait(T.z, Z_FLAG_RESERVED)) ? INVISIBILITY_ABSTRACT : 0

USER_VERB(sky_event, R_EVENT, "Sky Event", "Something in the sky for everyone with the sky on High: a fly-by or a rare event.", VERB_CATEGORY_EVENT)
	var/static/list/flybys = list("meteor", "bolide", "comet", "ship", "convoy")
	var/static/list/events = list("vortex", "shower", "supernova", "battle", "aurora", "breakup", "prism", "giant")
	var/kind = tgui_input_list(client, "What happens in the sky?", "Sky Event", flybys + events)
	if(!kind)
		return
	if(kind in flybys)
		SSparallax.launch_flyby(kind)
	else if(!SSparallax.sky_event(kind))
		to_chat(client, SPAN_WARNING("No [kind] now: a star only goes once a round, a prism needs a sun, and nothing fits over the sun."))
		return
	message_admins("[key_name_admin(client)] put a sky event up: [kind].")
	log_admin("[key_name(client)] put a sky event up: [kind].")
