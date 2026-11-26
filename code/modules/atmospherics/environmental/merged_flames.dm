// Fires drawn as burning gas: thin see-through flames that sway, pinch off and rise away, joining up with the fires
// round them. The animations are worked out ahead of time (tools/shift_bench/make_gas_fire.py, local), so a fire is
// one animated overlay and costs the client about what the old sprite did.
//
// A tile with fire behind it (to the north) shows low, fat flames that run into the fires round it. A tile with no fire
// behind it is the back edge of the fire in the station's three-quarter view, and shows tall tongues and smoke.
// Fires are drawn on a plane of their own. That picture is laid over the lit game, and a blurred copy of it is added
// round it as the light the flames throw.

/// How many different fires of each size there are. A turf always shows the same one, mirrored for half of them.
#define FLAME_KINDS 4
/// A fire burns paler with a blue root above this, and goes back below FLAME_HOT_END. The gap stops a fire flicking between the two.
#define FLAME_HOT_START 5000
#define FLAME_HOT_END 4500
/// How far the light round the flames is blurred, and how strong it is (0 to 255)
#define FLAME_GLOW_BLUR 10
#define FLAME_GLOW_ALPHA 160

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
	if(!mymob?.client)
		return
	mymob.client.screen |= shown
	// The glow is a blur of the whole screen, the dearest part of a fire to draw, so players can turn it off
	if(mymob.client.prefs?.toggles3 & PREFTOGGLE_3_NO_FIRE_GLOW)
		mymob.client.screen -= glow
	else
		mymob.client.screen |= glow

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
	alpha = FLAME_GLOW_ALPHA

/atom/movable/screen/fire_relay/glow/Initialize(mapload)
	. = ..()
	add_filter("blur", 1, gauss_blur_filter(size = FLAME_GLOW_BLUR))

// MARK: The flames

/obj/effect/hotspot
	/// 1, 2 or 3 for a small, middling or big fire
	var/flame_size = 1
	/// Whether we burn blue-white
	var/flame_hot = FALSE
	/// Whether there is a fire behind us, so we show low flames and no smoke
	var/flame_inner = FALSE

/// Draws us as a small (1), middling (2) or big (3) fire, as hot as we are now
/obj/effect/hotspot/proc/set_flame_size(size)
	var/hot = flame_hot ? (temperature > FLAME_HOT_END) : (temperature > FLAME_HOT_START)
	if(size == flame_size && hot == flame_hot)
		return
	flame_size = size
	flame_hot = hot
	update_flames()

/// Whether there is a fire on the turf to the north of us
/obj/effect/hotspot/proc/set_flame_inner(inner)
	if(inner == flame_inner)
		return
	flame_inner = inner
	update_flames()

/obj/effect/hotspot/proc/update_flames()
	cut_overlays()
	if(!isturf(loc))
		return
	add_overlay(flame_overlay(flame_size, flame_hot, flame_inner, loc))
	if(!flame_inner && flame_size > 1)
		add_overlay(flame_smoke_overlay(flame_size, loc))

/// Finds out whether we have a fire behind us, and tells the fire in front of us that it has one now
/obj/effect/hotspot/proc/join_flames()
	var/turf/behind = get_step(src, NORTH)
	flame_inner = behind && !isnull(locate(/obj/effect/hotspot) in behind)
	var/turf/in_front = get_step(src, SOUTH)
	var/obj/effect/hotspot/fire = in_front && (locate(/obj/effect/hotspot) in in_front)
	fire?.set_flame_inner(TRUE)

/// Tells the fire in front of us that it has nothing behind it any more
/obj/effect/hotspot/proc/part_flames()
	var/turf/in_front = get_step(src, SOUTH)
	var/obj/effect/hotspot/fire = in_front && (locate(/obj/effect/hotspot) in in_front)
	fire?.set_flame_inner(FALSE)

/// Which of the fires a turf shows, 0 to FLAME_KINDS * 2 - 1, the top half mirrored.
/// Not x and y times numbers mod a power of two, which repeat every few tiles in a lattice you can see.
/proc/flame_kind(turf/where)
	return ((where.x * 9283 + where.y * 6917) % 1009 * 7 + where.x * where.y) % (FLAME_KINDS * 2)

/proc/flame_overlay(size, hot, inner, turf/where)
	var/static/list/made = list()
	var/kind = flame_kind(where)
	var/key = "[inner][size][hot]-[kind]"
	if(made[key])
		return made[key]
	var/mutable_appearance/flames = mutable_appearance(inner ? 'icons/effects/flame_gas_inner.dmi' : 'icons/effects/flame_gas.dmi', "[size][hot ? "h" : ""]-[kind % FLAME_KINDS]", plane = FIRE_PLANE)
	// Both sheets are two tiles wide with the tile in the middle, 16 pixels up from their bottom
	flames.pixel_x = -16
	flames.pixel_y = -16
	if(kind >= FLAME_KINDS)
		flames.transform = matrix(-1, 0, 0, 0, 1, 0)
	flames.appearance_flags = RESET_COLOR | RESET_ALPHA | KEEP_APART | PIXEL_SCALE
	made[key] = flames
	return flames

/// The smoke over the back edge of a fire. It is drawn on the game, under the lighting, so it is as dark as the room and lit by the fire.
/proc/flame_smoke_overlay(size, turf/where)
	var/static/list/made = list()
	var/kind = flame_kind(where)
	var/key = "[size]-[kind]"
	if(made[key])
		return made[key]
	var/mutable_appearance/smoke = mutable_appearance('icons/effects/flame_smoke.dmi', "smoke[size]-[kind % FLAME_KINDS]", MASSIVE_OBJ_LAYER + 0.1, GAME_PLANE)
	smoke.pixel_x = -16
	smoke.pixel_y = -16
	if(kind >= FLAME_KINDS)
		smoke.transform = matrix(-1, 0, 0, 0, 1, 0)
	smoke.appearance_flags = RESET_COLOR | RESET_ALPHA | KEEP_APART | PIXEL_SCALE
	made[key] = smoke
	return smoke

#undef FLAME_KINDS
#undef FLAME_HOT_START
#undef FLAME_HOT_END
#undef FLAME_GLOW_BLUR
#undef FLAME_GLOW_ALPHA
