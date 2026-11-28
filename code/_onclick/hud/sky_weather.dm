// Sky art tied to game weather and events: an ash storm on Lavaland, Aurora Caelus's curtains, a radiation storm's shimmer

/// Moves a 480 px sky_weather.dmi sprite's middle to where a 256 px sky_events.dmi sprite's middle would be
#define SKY_WEATHER_NUDGE (256 / 2 - PARALLAX_TILE / 2)

/datum/controller/subsystem/parallax
	/// Art every client's Lavaland carries: its aurora, an ash storm
	var/list/planet_art = list()
	/// The ash storm over Lavaland while it blows
	var/list/ash_art
	/// Aurora Caelus's curtains while it lasts
	var/list/caelus_art
	/// The radiation storm's shimmer while it lasts
	var/atom/movable/screen/sky_art/piece/rad_art
	/// The ash storms and radiation storms blowing now that put their art in the sky
	var/list/ash_storms = list()
	var/list/rad_storms = list()
	/// Holds weather right at the station, drawn over every celestial body
	var/atom/movable/screen/sky_art/flyby/near_weather

/// The shared holder for weather at the station, made when first needed
/datum/controller/subsystem/parallax/proc/near_weather_art()
	if(!near_weather)
		near_weather = new
		near_weather.layer = 45
	return near_weather

/// A new piece of weather at the station, in front of the whole sky
/datum/controller/subsystem/parallax/proc/near_piece(state, layer_add = 0)
	var/atom/movable/screen/sky_art/piece/P = new
	P.icon = 'icons/effects/sky/sky_weather.dmi'
	P.icon_state = state
	P.layer = 45 + layer_add
	near_weather_art().vis_contents += P
	return P

/// Puts `A` on every client's Lavaland, and on any made later
/datum/controller/subsystem/parallax/proc/add_planet_art(atom/movable/screen/sky_art/A)
	planet_art |= A
	for(var/client/C as anything in GLOB.clients)
		for(var/atom/movable/screen/parallax_layer/body/planet/L in C.parallax_layers_cached)
			L.vis_contents |= A

/// Takes `A` off every client's Lavaland
/datum/controller/subsystem/parallax/proc/remove_planet_art(atom/movable/screen/sky_art/A)
	planet_art -= A
	for(var/client/C as anything in GLOB.clients)
		for(var/atom/movable/screen/parallax_layer/body/planet/L in C.parallax_layers_cached)
			L.vis_contents -= A

/// Weather W has begun: its kind shows in the sky
/datum/controller/subsystem/parallax/proc/weather_began(datum/weather/W)
	if(istype(W, /datum/weather/ash_storm))
		ash_storms |= W
		lavaland_ash_storm(TRUE)
	else if(istype(W, /datum/weather/rad_storm))
		rad_storms |= W
		rad_storm_sky(TRUE)

/// Weather W is over or deleted: its kind leaves the sky once no other storm of that kind that began is still blowing
/datum/controller/subsystem/parallax/proc/weather_over(datum/weather/W)
	if(W in ash_storms)
		ash_storms -= W
		if(!length(ash_storms))
			lavaland_ash_storm(FALSE)
	if(W in rad_storms)
		rad_storms -= W
		if(!length(rad_storms))
			rad_storm_sky(FALSE)

/// Fades `art` out over SKY_WEATHER_FADE, then deletes it
/datum/controller/subsystem/parallax/proc/fade_out_art(list/art)
	for(var/atom/movable/screen/sky_art/A as anything in art)
		animate(A, alpha = 0, time = SKY_WEATHER_FADE, easing = SINE_EASING, flags = ANIMATION_END_NOW)
	addtimer(CALLBACK(src, PROC_REF(clear_art), art), SKY_WEATHER_FADE)

/// Deletes `art`, taking it off Lavaland first
/datum/controller/subsystem/parallax/proc/clear_art(list/art)
	for(var/atom/movable/screen/sky_art/A as anything in art)
		if(A in planet_art)
			remove_planet_art(A)
		qdel(A)

/// A matrix turned clockwise by `angle` about its middle, then moved `x`, `y` pixels
/proc/sky_turned_at(angle, x, y)
	var/matrix/M = matrix()
	M.Turn(angle)
	M.Translate(x, y)
	return M

/// An ash storm on Lavaland: ash haze over the planet and a slow cyclone that hides the glowing cracks
/datum/controller/subsystem/parallax/proc/lavaland_ash_storm(on)
	if(!on)
		if(ash_art)
			fade_out_art(ash_art)
			ash_art = null
		return
	if(ash_art)
		return
	var/atom/movable/screen/sky_art/veil = new
	veil.icon = 'icons/effects/sky/sky_weather.dmi'
	veil.icon_state = "ash_veil"
	veil.blend_mode = BLEND_OVERLAY
	veil.layer = 30.1
	veil.alpha = 0
	var/atom/movable/screen/sky_art/swirl = new
	swirl.icon = 'icons/effects/sky/sky_weather.dmi'
	swirl.icon_state = "ash_swirl"
	swirl.blend_mode = BLEND_OVERLAY
	swirl.layer = 30.2
	swirl.alpha = 0
	// somewhere on the disc, turning once every three minutes
	var/bearing = rand(0, 359)
	var/out = rand(15, 45)
	var/x = cos(bearing) * out
	var/y = sin(bearing) * out
	var/start = rand(0, 359)
	swirl.transform = sky_turned_at(start, x, y)
	animate(swirl, transform = sky_turned_at(start + 120, x, y), time = 1 MINUTES, loop = -1)
	animate(transform = sky_turned_at(start + 240, x, y), time = 1 MINUTES)
	animate(transform = sky_turned_at(start + 360, x, y), time = 1 MINUTES)
	ash_art = list(veil, swirl)
	for(var/atom/movable/screen/sky_art/A as anything in ash_art)
		add_planet_art(A)
		animate(A, alpha = 255, time = SKY_WEATHER_FADE, easing = SINE_EASING, flags = ANIMATION_PARALLEL)

/// Aurora Caelus: green curtains of light hang over the sky and shimmer while it lasts
/datum/controller/subsystem/parallax/proc/aurora_caelus_sky(on)
	if(!on)
		if(caelus_art)
			fade_out_art(caelus_art)
			caelus_art = null
		return
	if(caelus_art)
		return
	caelus_art = list()
	for(var/i in 1 to 3)
		var/atom/movable/screen/sky_art/piece/P = near_piece("aurora[i % 2 + 1]", i * 0.01)
		var/x = (i - 2) * 220 + rand(-40, 40)
		var/y = rand(30, 110)
		var/size = rand(22, 30) / 10
		P.transform = sky_at(x, y, 0, size, nudge = SKY_WEATHER_NUDGE)
		// shimmers unevenly, and sways a little
		animate(P, alpha = 230, time = 4 SECONDS, loop = -1, easing = SINE_EASING)
		animate(alpha = 150, time = 5 SECONDS, easing = SINE_EASING)
		animate(alpha = 245, time = 3 SECONDS, easing = SINE_EASING)
		animate(alpha = 170, time = 6 SECONDS, easing = SINE_EASING)
		animate(P, transform = sky_at(x + 35, y, 0, size * 1.04, nudge = SKY_WEATHER_NUDGE), time = 50 SECONDS, loop = -1, easing = SINE_EASING, flags = ANIMATION_PARALLEL)
		animate(transform = sky_at(x, y, 0, size, nudge = SKY_WEATHER_NUDGE), time = 50 SECONDS, easing = SINE_EASING)
		caelus_art += P

/// A radiation storm: a faint green shimmer over the whole sky while it lasts
/datum/controller/subsystem/parallax/proc/rad_storm_sky(on)
	if(!on)
		if(rad_art)
			fade_out_art(list(rad_art))
			rad_art = null
		return
	if(rad_art)
		return
	rad_art = near_piece("rad_veil", 0.5)
	rad_art.tile()
	animate(rad_art, alpha = 110, time = 4 SECONDS, loop = -1, easing = SINE_EASING)
	animate(alpha = 55, time = 4 SECONDS, easing = SINE_EASING)

/// Weather right at the station (Aurora Caelus, a radiation storm), over every celestial body; shown at every pref but Off
/atom/movable/screen/parallax_layer/near_weather
	icon_state = null
	layer = 45
	// held to the middle of the screen like the fly-bys
	absolute = TRUE

/atom/movable/screen/parallax_layer/near_weather/place_x(eye_x)
	return 0

/atom/movable/screen/parallax_layer/near_weather/place_y(eye_y)
	return 0

/atom/movable/screen/parallax_layer/near_weather/set_quality(quality)
	vis_contents = carry(list(SSparallax.near_weather_art()))

/// Only seen from the station's level, where the aurora and the radiation storm are
/atom/movable/screen/parallax_layer/near_weather/update_status(mob/M)
	var/turf/T = get_turf(M)
	invisibility = (T && is_station_level(T.z)) ? 0 : INVISIBILITY_ABSTRACT

#undef SKY_WEATHER_NUDGE
