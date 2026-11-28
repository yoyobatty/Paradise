// The sky behind space: the round's theme gives the layers (sky_themes.dm), shared moving art and events are in sky.dm

/// The sky's turn is animated a quarter turn per animate() step
#define SKY_TURN_STEP 90
/// Most animate() steps one sky turn queues; SSparallax.sun_moved() starts it again before they run out
#define SKY_TURN_MAX_STEPS 100
/// How long the sky swings to a quarter turn when a shuttle sets off
#define SKY_SNAP_TIME 30
/// How long the sky swings back to its turn when a shuttle stops
#define SKY_UNSNAP_TIME 30

// Pixels each layer slides per tile the eye moves; everything beyond the station is far enough to move as one
#define SKY_DEPTH_FAR 0.06
/// Lavaland is near enough to slide a little more than the rest of the sky
#define SKY_DEPTH_PLANET 0.15
#define SKY_DEPTH_NEAR_DUST 24
#define SKY_DEPTH_MID_DUST 9
/// Pixels from the middle of the screen Lavaland rests at, on the far side from the sun
#define SKY_PLANET_REST 210

/// Degrees the sky has turned by `time`, clockwise, so the painted sun sits where SSsun is; 0 before the sun is up
/proc/sky_turn_angle(time = world.time)
	var/list/line = SSparallax.turn_line
	var/list/sun = SSparallax.body_places["sun"]
	if(!line || !sun)
		return 0
	return line[1] + line[3] * (time - line[2]) - (90 - arctan(sun[1], sun[2]))

/// The painted sun's bearing on screen at `time`, degrees clockwise from north like SSsun.angle; null with no sun painted
/proc/sky_sun_bearing(time = world.time)
	var/list/sun = SSparallax.body_places["sun"]
	if(!sun)
		return null
	return SIMPLIFY_DEGREES(90 - arctan(sun[1], sun[2]) + sky_turn_angle(time))

/// How the sky's turn is animated: list(degrees a step, deciseconds a step, steps), up to 12 hours or SKY_TURN_MAX_STEPS
/proc/sky_turn_plan()
	var/list/line = SSparallax.turn_line
	var/rate = line ? line[3] : 0
	if(!rate)
		return list(0, 0, 0)
	var/step_time = SKY_TURN_STEP / abs(rate)
	return list(SKY_TURN_STEP * SIGN(rate), step_time, min(ceil(12 HOURS / step_time) + 1, SKY_TURN_MAX_STEPS))

/// A matrix turned clockwise by `angle` degrees
/proc/sky_turned(angle)
	var/matrix/M = matrix()
	M.Turn(angle)
	return M

/// SKY_QUALITY_* for a Parallax pref: how much of the sky moves by itself
/proc/sky_quality_for_pref(pref)
	if(pref >= PARALLAX_HIGH)
		return SKY_QUALITY_HIGH
	if(pref >= PARALLAX_MED)
		return SKY_QUALITY_MEDIUM
	return SKY_QUALITY_LOW

/// The angle this client's sky is at, or is turning to
/client/proc/parallax_angle()
	return isnull(parallax_snapped) ? sky_turn_angle() : parallax_snapped

/// The one sky object on a client's screen; turning it turns the whole sky about the screen middle
/atom/movable/screen/parallax_home
	icon = 'icons/effects/sky/sky.dmi'
	icon_state = null
	blend_mode = BLEND_ADD
	plane = PLANE_SPACE_PARALLAX
	screen_loc = "CENTER-7,CENTER-7"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/atom/movable/screen/parallax_home/Destroy()
	vis_contents.Cut()
	return ..()

/datum/hud/proc/create_parallax(mob/viewmob)
	var/mob/screenmob = viewmob || mymob
	if(!screenmob.client)
		return
	var/client/C = screenmob.client
	if(!apply_parallax_pref(screenmob))
		return
	// this is needed so it blends properly with the space plane and blackness plane.
	var/atom/movable/screen/plane_master/space/S = plane_masters["[PLANE_SPACE]"]
	if(C.prefs.toggles2 & PREFTOGGLE_2_PARALLAX_IN_DARKNESS)
		S.color = rgb(0, 0, 0, 0)
	else
		S.color = list(1, 1, 1, 1,
					1, 1, 1, 1,
					1, 1, 1, 1,
					1, 1, 1, 1,)
	S.appearance_flags |= NO_CLIENT_COLOR

	var/datum/sky_theme/theme = SSparallax.theme
	if(!length(C.parallax_layers_cached) || C.parallax_theme != theme)
		if(length(C.parallax_layers_cached))
			C.parallax_home?.vis_contents.Cut()
			QDEL_LIST_CONTENTS(C.parallax_layers_cached)
		C.parallax_layers_cached = theme.build_layers()
		C.parallax_theme = theme

	var/quality = sky_quality_for_pref(C.parallax_detail)
	C.parallax_layers = list()
	for(var/atom/movable/screen/parallax_layer/L as anything in C.parallax_layers_cached)
		if(!L.shown_at(C.parallax_detail))
			continue
		L.set_quality(quality)
		C.parallax_layers += L

	var/atom/movable/screen/plane_master/parallax/parallax_plane_master = plane_masters["[PLANE_SPACE_PARALLAX]"]
	if(C.prefs.toggles2 & PREFTOGGLE_2_PARALLAX_IN_DARKNESS)
		parallax_plane_master.blend_mode = BLEND_ADD
	else
		parallax_plane_master.blend_mode = BLEND_MULTIPLY

	if(!C.parallax_home)
		C.parallax_home = new
	var/list/holders = list()
	for(var/atom/movable/screen/parallax_layer/L as anything in C.parallax_layers)
		holders += L.holder
	C.parallax_home.vis_contents = holders
	C.screen |= list(C.parallax_home) + C.parallax_static_layers_tail
	if(isnull(C.parallax_snapped))
		turn_sky(C)
	else
		animate(C.parallax_home, transform = sky_turned(C.parallax_snapped), time = 0, flags = ANIMATION_END_NOW)
	// Kept layers stop where they are; the next update_parallax() sends them off again if this eye is in flight too
	for(var/atom/movable/screen/parallax_layer/L as anything in C.parallax_layers)
		if(L.flight_heading)
			L.come_to_rest(TRUE)
	C.parallax_movedir = 0
	track_parallax_mover(C)

/// Makes the thing carrying the client's eye update its sky when it moves, now rather than at SSparallax's next pass
/datum/hud/proc/track_parallax_mover(client/C)
	var/atom/movable/A = C.eye
	if(!istype(A))
		return
	while(ismovable(A.loc))
		A = A.loc
	if(A == C.movingmob)
		return
	if(C.movingmob)
		C.movingmob.client_mobs_in_contents -= C.mob
		UNSETEMPTY(C.movingmob.client_mobs_in_contents)
	LAZYINITLIST(A.client_mobs_in_contents)
	A.client_mobs_in_contents |= C.mob
	C.movingmob = A

/datum/hud/proc/remove_parallax(mob/viewmob)
	var/mob/screenmob = viewmob || mymob
	var/client/C = screenmob.client
	if(!C)
		return
	C.screen -= list(C.parallax_home) + C.parallax_static_layers_tail
	C.parallax_layers = null
	var/atom/movable/screen/plane_master/space/S = plane_masters["[PLANE_SPACE]"]
	S.color = null
	S.appearance_flags &= ~NO_CLIENT_COLOR

/datum/hud/proc/apply_parallax_pref(mob/viewmob)
	var/mob/screen_mob = viewmob || mymob
	var/client/C = screen_mob.client
	if(!istype(C))
		return FALSE
	var/pref = C.prefs?.parallax
	if(isnull(pref))
		pref = PARALLAX_HIGH
	if(pref == PARALLAX_DISABLE)
		return FALSE
	C.parallax_detail = pref
	switch(pref)
		if(PARALLAX_INSANE)
			C.parallax_throttle = FALSE
		if(PARALLAX_MED)
			C.parallax_throttle = PARALLAX_DELAY_MED
		if(PARALLAX_LOW)
			C.parallax_throttle = PARALLAX_DELAY_LOW
		else
			C.parallax_throttle = PARALLAX_DELAY_DEFAULT
	return TRUE

/datum/hud/proc/update_parallax_pref(mob/viewmob)
	var/mob/screen_mob = viewmob || mymob
	if(!screen_mob.client)
		return
	remove_parallax(screen_mob)
	create_parallax(screen_mob)
	// Forgetting the last turf makes update_parallax() lay every layer out from scratch
	screen_mob.client.previous_turf = null
	update_parallax(screen_mob)

/// Sets the client's sky turning from where it should be now, or swinging there over `ease` deciseconds
/datum/hud/proc/turn_sky(client/C, ease = 0)
	var/atom/movable/screen/parallax_home/home = C?.parallax_home
	if(!home)
		return
	var/angle = sky_turn_angle(world.time + ease)
	if(ease)
		animate(home, transform = sky_turned(angle), time = ease, easing = SINE_EASING)
	else
		animate(home, transform = sky_turned(angle), time = 0, flags = ANIMATION_END_NOW)
	var/list/plan = sky_turn_plan()
	for(var/step in 1 to plan[3])
		animate(transform = sky_turned(angle + step * plan[1]), time = plan[2])

/// Sets the eye's shuttle heading: layers wind up and stream past, the sky holds at a quarter turn
/datum/hud/proc/set_parallax_movedir(mob/viewmob, new_parallax_movedir, skip_windups)
	. = FALSE
	var/mob/screen_mob = viewmob || mymob
	var/client/C = screen_mob.client
	if(!istype(C))
		return
	new_parallax_movedir = new_parallax_movedir || 0
	if(new_parallax_movedir == C.parallax_movedir)
		if(!new_parallax_movedir && !isnull(C.parallax_snapped))
			C.parallax_snapped = null
			turn_sky(C, SKY_UNSNAP_TIME)
		return
	var/animatedir = new_parallax_movedir || C.parallax_movedir

	for(var/layer in C.parallax_animate_timers)
		deltimer(C.parallax_animate_timers[layer])
	C.parallax_animate_timers = list()

	if(new_parallax_movedir && isnull(C.parallax_snapped))
		C.parallax_snapped = round(sky_turn_angle(), SKY_TURN_STEP)
		if(C.parallax_home)
			animate(C.parallax_home, transform = sky_turned(C.parallax_snapped), time = skip_windups ? 0 : SKY_SNAP_TIME, easing = SINE_EASING)
	// The heading in the turned sky's frame
	var/heading = animatedir
	if(!isnull(C.parallax_snapped))
		heading = turn(animatedir, C.parallax_snapped % 360)

	var/longest = 0
	for(var/atom/movable/screen/parallax_layer/L as anything in C.parallax_layers)
		if(!L.flies())
			continue
		if(!new_parallax_movedir)
			longest = max(longest, L.come_to_rest(skip_windups))
			continue
		var/windup = L.launch(heading, skip_windups)
		longest = max(longest, windup)
		if(windup)
			C.parallax_animate_timers[L] = addtimer(CALLBACK(src, PROC_REF(update_parallax_motionblur), C, L), windup, TIMER_CLIENT_TIME|TIMER_STOPPABLE)

	if(!new_parallax_movedir && !isnull(C.parallax_snapped))
		C.parallax_snapped = null
		turn_sky(C, skip_windups ? 0 : SKY_UNSNAP_TIME)
	C.dont_animate_parallax = world.time + min(longest, PARALLAX_LOOP_TIME)
	C.parallax_movedir = new_parallax_movedir

/// A layer up to speed starts its endless flight loop
/datum/hud/proc/update_parallax_motionblur(client/C, atom/movable/screen/parallax_layer/L)
	if(!C || QDELETED(L))
		return
	LAZYREMOVE(C.parallax_animate_timers, L)
	if(L.flight_heading)
		L.cruise()

/datum/hud/proc/update_parallax(mob/viewmob)
	var/mob/screenmob = viewmob || mymob
	var/client/C = screenmob.client
	if(!C)
		return
	var/turf/posobj = get_turf(C.eye)
	if(!posobj)
		return
	var/area/areaobj = posobj.loc

	// Shuttles in flight stream the sky past
	var/movedir = areaobj.moving ? areaobj.parallax_move_direction : 0
	set_parallax_movedir(screenmob, movedir)

	var/force
	if(!C.previous_turf || (C.previous_turf.z != posobj.z))
		C.previous_turf = posobj
		force = TRUE

	if(!force && world.time < C.last_parallax_shift + C.parallax_throttle)
		return

	// Measured from the last turf so layers don't jump on a z-level change
	var/offset_x = posobj.x - C.previous_turf.x
	var/offset_y = posobj.y - C.previous_turf.y

	if(!offset_x && !offset_y && !force)
		return

	C.previous_turf = posobj
	C.last_parallax_shift = world.time

	// The sky slides for as long as the eye glides to its new tile, so the two move as one
	var/atom/movable/eye = C.eye
	var/glide_size = istype(eye) ? eye.glide_size : screenmob.glide_size
	var/glide_time = glide_size ? round(world.icon_size / glide_size * world.tick_lag, world.tick_lag) : 0
	var/largest_change = max(abs(offset_x), abs(offset_y))
	// No glide for a jump, in a flying shuttle, or while layers wind down
	var/glide = glide_time && !force && !movedir && C.dont_animate_parallax <= world.time && largest_change <= (glide_time / world.tick_lag) + 1

	// Layers slide in the turned sky's frame: a step east still slides everything west on screen
	var/matrix/unturn = sky_turned(-C.parallax_angle())

	for(var/atom/movable/screen/parallax_layer/L as anything in C.parallax_layers)
		L.update_status(screenmob)
		if(L.view_sized != C.view)
			L.update_o(C.view)

		var/screen_x
		var/screen_y
		var/new_x
		var/new_y
		if(L.absolute)
			if(force) // laid out from its rest: that part turns with the sky, the eye's parallax doesn't
				var/list/rest = L.sky_rest()
				screen_x = L.place_x(posobj.x) - rest[1]
				screen_y = L.place_y(posobj.y) - rest[2]
				new_x = rest[1] + unturn.a * screen_x + unturn.b * screen_y
				new_y = rest[2] + unturn.d * screen_x + unturn.e * screen_y
			else
				screen_x = L.place_x(posobj.x) - L.place_x(posobj.x - offset_x)
				screen_y = L.place_y(posobj.y) - L.place_y(posobj.y - offset_y)
		else
			screen_x = -offset_x * L.speed
			screen_y = -offset_y * L.speed
		if(isnull(new_x))
			new_x = L.offset_x + unturn.a * screen_x + unturn.b * screen_y
			new_y = L.offset_y + unturn.d * screen_x + unturn.e * screen_y
		if(!L.absolute)
			// The art repeats every period: jump back a whole one where it can't be seen, along the layer's own axes
			var/half = L.period / 2
			var/across = new_x
			var/along = new_y
			if(L.angle)
				var/matrix/own = sky_turned(-L.angle)
				across = own.a * new_x + own.b * new_y
				along = own.d * new_x + own.e * new_y
			var/wrap_u = across > half ? -L.period : (across < -half ? L.period : 0)
			var/wrap_v = along > half ? -L.period : (along < -half ? L.period : 0)
			if(wrap_u || wrap_v)
				var/wrap_x = wrap_u
				var/wrap_y = wrap_v
				if(L.angle)
					var/matrix/back = sky_turned(L.angle)
					wrap_x = back.a * wrap_u + back.b * wrap_v
					wrap_y = back.d * wrap_u + back.e * wrap_v
				new_x += wrap_x
				new_y += wrap_y
				L.slide_to(round(L.offset_x + wrap_x, 1), round(L.offset_y + wrap_y, 1))

		L.offset_x = new_x
		L.offset_y = new_y
		// Any move that shows glides with the eye, even a far layer's single pixel
		var/drawn_x = round(new_x, 1)
		var/drawn_y = round(new_y, 1)
		if(glide && (drawn_x != L.drawn_x || drawn_y != L.drawn_y))
			L.slide_to(drawn_x, drawn_y, glide_time)
		else
			L.slide_to(drawn_x, drawn_y)

/atom/movable/proc/update_parallax_contents()
	if(length(client_mobs_in_contents))
		for(var/thing in client_mobs_in_contents)
			var/mob/M = thing
			if(M && M.client && M.hud_used && length(M.client.parallax_layers))
				M.hud_used.update_parallax()

/// Degrees the theme's galaxy band sits turned by, clockwise
/datum/sky_theme/var/band_angle = 0

/atom/movable/screen/parallax_layer
	icon = 'icons/effects/sky/sky.dmi'
	/// Pixels it slides for each tile the eye moves: the nearer, the more
	var/speed = 1
	/// How fast it streams past in a shuttle flight: 1 is a repeat in PARALLAX_LOOP_TIME
	var/flight_speed = 1
	var/offset_x = 0
	var/offset_y = 0
	var/view_sized
	/// Sits at one place in the sky (place_x/place_y) instead of repeating across it
	var/absolute = FALSE
	/// How far apart its art repeats on screen, in pixels
	var/period = PARALLAX_TILE
	/// The lowest Parallax pref that shows it
	var/detail = PARALLAX_LOW
	/// The lowest SKY_QUALITY_* that shows it
	var/quality = SKY_QUALITY_LOW
	/// How many times longer it's drawn along a shuttle's heading at full speed
	var/streak = 1
	/// Degrees it sits turned by on top of the sky's own turn (set_sky_angle())
	var/angle = 0
	/// The heading of the flight it's looping in, in the sky's frame; 0 at rest
	var/flight_heading = 0
	/// REALTIMEOFDAY its wind-up started
	var/flight_start = 0
	/// How long its wind-up takes
	var/flight_windup = 0
	/// REALTIMEOFDAY its flight loop started; 0 while winding up
	var/cruise_start = 0
	blend_mode = BLEND_ADD
	plane = PLANE_SPACE_PARALLAX
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	// No RESET_TRANSFORM: a layer turns with the sky holding it; no PIXEL_SCALE: smooth when turned
	appearance_flags = RESET_COLOR | NO_CLIENT_COLOR
	/// Carries the layer at the screen middle and slides it by its transform, so the sky's turn swings every layer as one
	var/atom/movable/screen/parallax_holder/holder
	/// Pixels the holder has the layer slid by
	var/drawn_x = 0
	var/drawn_y = 0

/atom/movable/screen/parallax_layer/Initialize(mapload, view)
	. = ..()
	holder = new
	holder.layer = layer
	holder.vis_contents += src
	if(!view)
		view = world.view
	update_o(view)

/atom/movable/screen/parallax_layer/Destroy()
	QDEL_NULL(holder)
	return ..()

/// Slides the layer to `x`, `y` pixels from the screen middle, over `time` if given
/atom/movable/screen/parallax_layer/proc/slide_to(x, y, time)
	drawn_x = x
	drawn_y = y
	if(time)
		animate(holder, transform = matrix(1, 0, x, 0, 1, y), time = time)
	else
		holder.transform = matrix(1, 0, x, 0, 1, y)

/// Holds one parallax layer in parallax_home's vis_contents; its transform is the layer's slide
/atom/movable/screen/parallax_holder
	plane = PLANE_SPACE_PARALLAX
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	appearance_flags = NO_CLIENT_COLOR

/atom/movable/screen/parallax_holder/Destroy()
	vis_contents.Cut()
	return ..()

/// Whether a client with this Parallax pref sees the layer
/atom/movable/screen/parallax_layer/proc/shown_at(pref)
	return pref >= detail && sky_quality_for_pref(pref) >= quality

/// Tiles the layer's own icon over the view; a layer with no icon state shows shared art instead (set_quality())
/atom/movable/screen/parallax_layer/proc/update_o(view)
	if(!view)
		view = world.view
	view_sized = view
	if(!icon_state)
		return

	var/list/viewscales = getviewsize(view)
	// Out to the view's corners whichever way the sky is turned, plus one repeat for a shuttle's slide
	var/reach = sqrt(viewscales[1] ** 2 + viewscales[2] ** 2) * world.icon_size / 2
	var/count = ceil(reach / period) + 1
	var/list/new_overlays = list()
	for(var/x in -count to count)
		for(var/y in -count to count)
			if(x == 0 && y == 0)
				continue
			var/mutable_appearance/texture_overlay = mutable_appearance(icon, icon_state)
			texture_overlay.transform = matrix(1, 0, x * period, 0, 1, y * period)
			new_overlays += texture_overlay
	cut_overlays()
	add_overlay(new_overlays)

/atom/movable/screen/parallax_layer/proc/update_status(mob/M)
	return

/// Picks the shared art the layer carries for a SKY_QUALITY_* (moving or still)
/atom/movable/screen/parallax_layer/proc/set_quality(quality)
	return

/// Readies shared art for a layer's vis_contents so it turns, stretches and loops with the layer
/atom/movable/screen/parallax_layer/proc/carry(list/art)
	for(var/atom/movable/screen/A as anything in art)
		A.appearance_flags &= ~RESET_TRANSFORM
	return art

/// Where an absolute layer sits, pixels from the middle of the screen, with the eye at this map x
/atom/movable/screen/parallax_layer/proc/place_x(eye_x)
	return -(eye_x - SSparallax.planet_x_offset) * speed

/// Where an absolute layer sits, pixels from the middle of the screen, with the eye at this map y
/atom/movable/screen/parallax_layer/proc/place_y(eye_y)
	return -(eye_y - SSparallax.planet_y_offset) * speed

/// How long one repeat takes to pass in a shuttle at full speed
/atom/movable/screen/parallax_layer/proc/loop_time()
	return PARALLAX_LOOP_TIME / flight_speed * (period / PARALLAX_TILE)

/// Where an absolute layer rests in the sky with the eye at the middle of the map
/atom/movable/screen/parallax_layer/proc/sky_rest()
	return list(place_x(world.maxx / 2), place_y(world.maxy / 2))

/// Sits turned by `new_angle` degrees on top of the sky's own turn
/atom/movable/screen/parallax_layer/proc/set_sky_angle(new_angle)
	angle = new_angle
	transform = angle ? sky_turned(angle) : matrix()

/// Whether it streams past in a shuttle flight: single things and turned layers stay put
/atom/movable/screen/parallax_layer/proc/flies()
	return !absolute && !angle

/// The layer stretched `stretch` times along a heading and moved `shift` pixels back along it
/atom/movable/screen/parallax_layer/proc/flight_matrix(heading, shift, stretch)
	switch(heading)
		if(NORTH)
			return matrix(1, 0, 0, 0, stretch, shift)
		if(SOUTH)
			return matrix(1, 0, 0, 0, stretch, -shift)
		if(EAST)
			return matrix(stretch, 0, shift, 0, 1, 0)
		if(WEST)
			return matrix(stretch, 0, -shift, 0, 1, 0)
	return matrix()

/// One loop at full speed: a stretched repeat at the speed the wind-up ended on
/atom/movable/screen/parallax_layer/proc/cruise_time()
	return loop_time() * streak / 2

/// Starts winding up along `heading` and returns how long until it should cruise(); 0 if it cruises already
/atom/movable/screen/parallax_layer/proc/launch(heading, skip_windup)
	flight_heading = heading
	flight_start = REALTIMEOFDAY
	cruise_start = 0
	if(skip_windup)
		flight_windup = 0
		cruise()
		return 0
	flight_windup = loop_time()
	transform = flight_matrix(heading, period, 1)
	animate(src, transform = flight_matrix(heading, 0, streak), time = flight_windup, easing = QUAD_EASING | EASE_IN, flags = ANIMATION_END_NOW)
	// One loop queued behind it so a late timer doesn't leave it standing
	animate(transform = flight_matrix(heading, period * streak, streak), time = 0)
	animate(transform = flight_matrix(heading, 0, streak), time = cruise_time())
	return flight_windup

/// Loops at full speed until it comes to rest
/atom/movable/screen/parallax_layer/proc/cruise()
	cruise_start = REALTIMEOFDAY
	animate(src, transform = flight_matrix(flight_heading, period * streak, streak), time = 0, loop = -1, flags = ANIMATION_END_NOW)
	animate(transform = flight_matrix(flight_heading, 0, streak), time = cruise_time())

/// Slows to a stop on a whole repeat over PARALLAX_LOOP_TIME, unstretching; returns how long that takes
/atom/movable/screen/parallax_layer/proc/come_to_rest(instantly)
	var/heading = flight_heading
	flight_heading = 0
	if(!heading || instantly)
		animate(src, transform = matrix(), time = 0, flags = ANIMATION_END_NOW)
		return 0
	var/now = REALTIMEOFDAY
	var/shift
	var/stretch
	var/speed_now // pixels a decisecond
	if(cruise_start)
		var/loop = cruise_time()
		var/into = MODULUS(now - cruise_start, loop)
		shift = period * streak * (1 - into / loop)
		stretch = streak
		speed_now = period * streak / loop
	else
		var/through = clamp((now - flight_start) / max(flight_windup, 1), 0, 1)
		shift = period * (1 - through ** 2)
		stretch = 1 + (streak - 1) * through ** 2
		speed_now = 2 * period * through / max(flight_windup, 1)
	// Easing out starts at twice the average speed: travel this far to keep the speed it had
	var/wanted = speed_now * PARALLAX_LOOP_TIME / 2
	var/repeats = round((shift - wanted) / period)
	var/far = shift - repeats * period
	var/near = far - period
	var/travel = (near >= 0 && abs(near - wanted) < abs(far - wanted)) ? near : far
	transform = flight_matrix(heading, shift, stretch)
	animate(src, transform = flight_matrix(heading, shift - travel, 1), time = PARALLAX_LOOP_TIME, easing = QUAD_EASING | EASE_OUT, flags = ANIMATION_END_NOW)
	animate(transform = matrix(), time = 0)
	return PARALLAX_LOOP_TIME

// MARK: Stars, far to near

/atom/movable/screen/parallax_layer/stars
	icon_state = "stars_far"
	speed = SKY_DEPTH_FAR
	flight_speed = 0.45
	streak = 2.5
	layer = 4

/atom/movable/screen/parallax_layer/stars/deep
	icon_state = "stars_deep"
	speed = SKY_DEPTH_FAR
	flight_speed = 0.2
	streak = 1.6
	layer = 2
	detail = PARALLAX_MED

/atom/movable/screen/parallax_layer/stars/mid
	icon_state = "stars_mid"
	speed = SKY_DEPTH_FAR
	flight_speed = 0.9
	streak = 4
	layer = 5
	detail = PARALLAX_MED

/// The few bright stars; three shared groups of them twinkle at their own pace
/atom/movable/screen/parallax_layer/stars/near
	icon_state = "stars_near"
	speed = SKY_DEPTH_FAR
	flight_speed = 1.6
	streak = 6
	layer = 7
	detail = PARALLAX_MED

/atom/movable/screen/parallax_layer/stars/near/set_quality(quality)
	var/list/groups = list()
	for(var/group in 1 to SKY_TWINKLE_GROUPS)
		groups += SSparallax.twinkle_art(group, quality >= SKY_QUALITY_MEDIUM)
	vis_contents = carry(groups)

// MARK: Nebulae

/// One of the theme's clouds from sky_nebula.dmi in its colours, drawn at double size
/atom/movable/screen/parallax_layer/nebula
	icon_state = null
	period = PARALLAX_TILE * SKY_NEBULA_SCALE
	speed = SKY_DEPTH_FAR
	flight_speed = 0.45
	layer = 3
	detail = PARALLAX_HIGH
	/// Which of the theme's clouds this is
	var/index = 1

/// Sets the layer up for theme cloud `cloud`: list(state, colour, alpha, flight speed)
/atom/movable/screen/parallax_layer/nebula/proc/setup(new_index, list/cloud)
	index = new_index
	flight_speed = cloud[4]
	layer = initial(layer) + index * 0.01
	holder.layer = layer
	// Which part of the cloud is overhead changes from round to round, the same for everyone
	var/list/shift = SSparallax.nebula_shifts[index]
	offset_x = shift[1]
	offset_y = shift[2]
	if(index == 1) // the Med pref shows the theme's main cloud
		detail = PARALLAX_MED
	if(cloud[1] == "band") // the galaxy band runs along x in its art; the theme turns it
		set_sky_angle(SSparallax.theme.band_angle)
		var/matrix/own = sky_turned(angle)
		offset_x = own.a * shift[1] + own.b * shift[2]
		offset_y = own.d * shift[1] + own.e * shift[2]

/atom/movable/screen/parallax_layer/nebula/set_quality(quality)
	vis_contents = carry(list(SSparallax.nebula_art(index)))

// MARK: Single things

/// A body at one place in the sky: Lavaland, another world, the sun, a galaxy
/atom/movable/screen/parallax_layer/body
	icon = 'icons/effects/sky/sky_bodies.dmi'
	blend_mode = BLEND_OVERLAY
	absolute = TRUE
	detail = PARALLAX_HIGH
	/// Which of SSparallax.body_places it sits at
	var/place

/atom/movable/screen/parallax_layer/body/update_o(view)
	view_sized = view || world.view

/atom/movable/screen/parallax_layer/body/place_x(eye_x)
	var/list/shift = SSparallax.body_places[place]
	return shift[1] - (eye_x - world.maxx / 2) * speed

/atom/movable/screen/parallax_layer/body/place_y(eye_y)
	var/list/shift = SSparallax.body_places[place]
	return shift[2] - (eye_y - world.maxy / 2) * speed

/// Hidden on reserved levels (shuttles in transit)
/atom/movable/screen/parallax_layer/body/update_status(mob/M)
	var/turf/T = get_turf(M)
	invisibility = (T && check_level_trait(T.z, Z_FLAG_RESERVED)) ? INVISIBILITY_ABSTRACT : 0

/// Turns the body so its lit side, baked at `bake_angle`, faces the sun
/atom/movable/screen/parallax_layer/body/proc/face_sun(bake_angle = 0)
	var/list/sun = SSparallax.body_places["sun"]
	if(sun && (sun[1] || sun[2]))
		set_sky_angle(bake_angle - arctan(sun[1], sun[2]))

/// Lavaland, the planet the station orbits: its Lavaland theme's sprite, resting on the far side from the sun
/atom/movable/screen/parallax_layer/body/planet
	icon_state = "planet_lava"
	speed = SKY_DEPTH_PLANET
	layer = 30
	detail = PARALLAX_MED

/atom/movable/screen/parallax_layer/body/planet/Initialize(mapload, view)
	. = ..()
	if(SSmapping.lavaland_theme?.planet_icon_state)
		icon_state = SSmapping.lavaland_theme.planet_icon_state
	face_sun(SKY_PLANET_BAKE_ANGLE)

/atom/movable/screen/parallax_layer/body/planet/place_x(eye_x)
	return planet_rest()[1] - (eye_x - SSparallax.planet_x_offset) * speed

/atom/movable/screen/parallax_layer/body/planet/place_y(eye_y)
	return planet_rest()[2] - (eye_y - SSparallax.planet_y_offset) * speed

/// Pixels from the middle of the screen the planet rests at, away from the sun
/atom/movable/screen/parallax_layer/body/planet/proc/planet_rest()
	var/list/sun = SSparallax.body_places["sun"]
	if(!sun || (!sun[1] && !sun[2]))
		return list(0, -SKY_PLANET_REST)
	var/away = arctan(-sun[1], -sun[2])
	return list(cos(away) * SKY_PLANET_REST, sin(away) * SKY_PLANET_REST)

/// Only seen from the station's level
/atom/movable/screen/parallax_layer/body/planet/update_status(mob/M)
	var/turf/T = get_turf(M)
	invisibility = (T && is_station_level(T.z)) ? 0 : INVISIBILITY_ABSTRACT

/// Another world of this system, further off; the theme says which
/atom/movable/screen/parallax_layer/body/world
	speed = SKY_DEPTH_FAR
	layer = 10
	place = "world"

/atom/movable/screen/parallax_layer/body/world/Initialize(mapload, view)
	. = ..()
	face_sun()

/atom/movable/screen/parallax_layer/body/sun
	icon_state = "sun"
	blend_mode = BLEND_ADD
	speed = SKY_DEPTH_FAR
	layer = 8
	place = "sun"

/atom/movable/screen/parallax_layer/body/galaxy
	icon_state = "galaxy"
	speed = SKY_DEPTH_FAR
	layer = 6
	place = "galaxy"

/// A nebula or quasar far beyond this system (SSparallax.deep_sky); its art is shared, turned and sized for the round
/atom/movable/screen/parallax_layer/body/deep
	icon_state = null
	blend_mode = BLEND_ADD
	speed = SKY_DEPTH_FAR
	layer = 5.5
	/// Which of the round's far things it is
	var/index = 1

/atom/movable/screen/parallax_layer/body/deep/proc/setup(new_index)
	index = new_index
	place = "deep[index]"
	layer = initial(layer) + index * 0.01
	holder.layer = layer

/atom/movable/screen/parallax_layer/body/deep/set_quality(quality)
	vis_contents = carry(SSparallax.deep_art(index, quality >= SKY_QUALITY_MEDIUM))

// MARK: Near things

/// Close specks of dust that slide past fast
/atom/movable/screen/parallax_layer/dust
	icon = 'icons/effects/sky/sky_events_dust.dmi'
	icon_state = "dust"
	speed = SKY_DEPTH_NEAR_DUST
	flight_speed = 5
	streak = 6
	layer = 40
	detail = PARALLAX_HIGH
	quality = SKY_QUALITY_HIGH

/atom/movable/screen/parallax_layer/dust/set_quality(quality)
	vis_contents = carry(list(SSparallax.dust_art()))

/// Sparser, fainter dust between the near dust and the stars
/atom/movable/screen/parallax_layer/dust/mid
	speed = SKY_DEPTH_MID_DUST
	flight_speed = 2.5
	streak = 4
	layer = 39
	alpha = 95
	offset_x = 173
	offset_y = -131

/// A field of asteroids drifting close by, for themes that have one
/atom/movable/screen/parallax_layer/asteroids
	icon = 'icons/effects/sky/sky_asteroids.dmi'
	icon_state = "asteroids_0"
	blend_mode = BLEND_OVERLAY
	speed = 6
	flight_speed = 3
	layer = 35
	detail = PARALLAX_HIGH

/// The sheet has the field lit from 16 headings; it takes the one nearest the sun
/atom/movable/screen/parallax_layer/asteroids/Initialize(mapload, view)
	. = ..()
	var/list/sun = SSparallax.body_places["sun"]
	if(sun && (sun[1] || sun[2]))
		icon_state = "asteroids_[round((arctan(sun[1], sun[2]) + 360) / 22.5, 1) % 16]"
		update_o(view_sized)

/atom/movable/screen/parallax_pmaster
	appearance_flags = PLANE_MASTER
	plane = PLANE_SPACE_PARALLAX
	blend_mode = BLEND_MULTIPLY
	mouse_opacity = FALSE
	screen_loc = "CENTER-7,CENTER-7"

/atom/movable/screen/parallax_space_whitifier
	appearance_flags = PLANE_MASTER
	plane = PLANE_SPACE
	color = list(
		0, 0, 0, 0,
		0, 0, 0, 0,
		0, 0, 0, 0,
		1, 1, 1, 1,
		0, 0, 0, 0
		)
	screen_loc = "CENTER-7,CENTER-7"
