// Fires drawn as burning gas: thin see-through flames that sway, pinch off and rise away, joining up with the fires
// round them. The animations are worked out ahead of time (tools/shift_bench/make_gas_fire.py, local), so a fire is
// one animated overlay and costs the client about what the old sprite did.
//
// A fire pushes up and out the way a real one does. Each burning tile looks at what is round it:
// - fire on all four sides: a churning bed of flame under the low flames, one texture across the tiles with no seams,
//   so the middle of a big fire burns as one sheet ("bed")
// - fire behind it (north): low, fat flames that run into the fires round it ("inner")
// - a wall or something solid behind it: flames that run up its face ("climb")
// - open behind it: the back edge of the fire in the station's three-quarter view, tall tongues and smoke ("edge").
//   The deeper the fire in front of it, the bigger it is drawn, so a big fire has a wall of flame along its back.
// - open air to one side only: its flames lean out into it.
// - a big fire: its flames reach the ceiling and spread across it, each one flame that rises, turns over and runs on.
//   The station's three-quarter view has no ceiling to see, but it would be a little under a tile up the screen. They
//   spread every way across it, so the rows of a big fire join into one rolling sheet.
// Fires are drawn on a plane of their own. That picture is laid over the lit game, and a blurred copy of it is added
// round it as the light the flames throw; it flickers. The brightest parts bloom.
// The hot air over a middling or big fire shimmers: soft blobs on the plane the game's own warp reads, so walls,
// floors and people ripple above it at no extra drawing cost. Both are cut down to where the lighting is not pitch black: being over the
// lighting, they would show behind walls and in the dark round a fire, where the lighting hides everything else. A
// burning tile is lit by its own fire, so its flames stay. Viewers who see in the dark see them all.
// A slow noise scrolling up the screen pushes the whole picture about, so a
// big fire surges as one. The glow and the surge are both whole-screen passes, so players can turn them off.

/// How many different fires of each form and size there are. A turf always shows the same one, mirrored for half of them.
#define FLAME_KINDS 3
/// A fire burns paler with a blue root above this, and goes back below FLAME_HOT_END. The gap stops a fire flicking between the two.
#define FLAME_HOT_START 5000
#define FLAME_HOT_END 4500
/// How far the light round the flames is blurred, and how strong it is (0 to 255)
#define FLAME_GLOW_BLUR 10
#define FLAME_GLOW_ALPHA 160
/// Brighter than this in the flames blooms
#define FLAME_BLOOM_THRESHOLD "#F0D080"
/// How many pixels the surge pushes the flames about at most
#define FLAME_SURGE 7
/// How many seconds the surge noise takes to scroll a whole screen of it up
#define FLAME_SURGE_TIME 9
/// A fire looks again at the walls and things round it every this many updates, as they can move without telling it
#define FLAME_LOOK_ROUND_EVERY 10
/// A fire's look changes at most this often, as each new look starts its animation over
#define FLAME_REDRAW_GAP (2 SECONDS)
/// How long a new look takes to fade in over the old one
#define FLAME_FADE (0.5 SECONDS)
/// How long the flames of a fire that went out take to die down
#define FLAME_DIE (1 SECONDS)

// MARK: The planes

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
	set_cut(mymob)
	remove_filter("surge")
	shown.remove_filter("bloom")
	if(mymob.client.prefs?.toggles3 & PREFTOGGLE_3_PLAIN_FIRE)
		mymob.client.screen -= glow
		return
	mymob.client.screen |= glow
	add_filter("surge", 1, displacement_map_filter(render_source = FIRE_NOISE_RENDER_TARGET, size = FLAME_SURGE))
	shown.add_filter("bloom", 5, bloom_filter(threshold = FLAME_BLOOM_THRESHOLD, size = 2, offset = 1, alpha = 150))

/// Cuts the fires to where the lighting is not black, unless the mob sees in the dark
/atom/movable/screen/plane_master/fire/proc/set_cut(mob/viewer)
	var/cut = viewer.lighting_alpha >= LIGHTING_PLANE_ALPHA_VISIBLE
	shown.cut_to_seen(cut)
	glow.cut_to_seen(cut)

/mob/sync_lighting_plane_alpha()
	. = ..()
	var/atom/movable/screen/plane_master/fire/master = hud_used?.plane_masters["[FIRE_PLANE]"]
	master?.set_cut(src)

/// The picture of the fires drawn as a thing over the lit game
/atom/movable/screen/fire_relay
	// The bottom left corner is where a plane's picture lines up with the screen
	screen_loc = "SOUTHWEST"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	plane = ABOVE_LIGHTING_PLANE
	layer = ABOVE_LIGHTING_LAYER + 0.2
	render_source = FIRE_RENDER_TARGET

/atom/movable/screen/fire_relay/glow
	layer = ABOVE_LIGHTING_LAYER + 0.1
	blend_mode = BLEND_ADD
	alpha = FLAME_GLOW_ALPHA

/// Cuts us to where the viewer can see, or doesn't
/atom/movable/screen/fire_relay/proc/cut_to_seen(cut)
	remove_filter("seen")
	if(cut)
		add_filter("seen", 10, alpha_mask_filter(render_source = FIRE_SEEN_RENDER_TARGET))

/atom/movable/screen/fire_relay/glow/Initialize(mapload)
	. = ..()
	// Blurred first and cut after, so the light doesn't spread into what can't be seen either
	add_filter("blur", 1, gauss_blur_filter(size = FLAME_GLOW_BLUR))
	// It flickers, unevenly. On the alpha, not a filter, as rebuilding the filters would start it over.
	animate(src, alpha = FLAME_GLOW_ALPHA + 20, time = 4, loop = -1, easing = SINE_EASING)
	animate(alpha = FLAME_GLOW_ALPHA - 25, time = 3, easing = SINE_EASING)
	animate(alpha = FLAME_GLOW_ALPHA + 10, time = 5, easing = SINE_EASING)
	animate(alpha = FLAME_GLOW_ALPHA - 10, time = 2, easing = SINE_EASING)

/// Where the viewer can see, for cutting the fires down to: the lighting's picture, solid wherever it is not black. Never shown.
/atom/movable/screen/plane_master/fire_seen
	name = "fire seen plane master"
	plane = FIRE_SEEN_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = FIRE_SEEN_RENDER_TARGET
	var/atom/movable/screen/fire_seen_part/lit

/atom/movable/screen/plane_master/fire_seen/Initialize(mapload)
	. = ..()
	// Soft at its edges: the lighting fades out over a wall's face, and a hard cut there left flames hanging like teeth
	add_filter("soften", 1, gauss_blur_filter(size = 3))

/atom/movable/screen/plane_master/fire_seen/Destroy()
	QDEL_NULL(lit)
	return ..()

// No ..(), the same as the fire plane
/atom/movable/screen/plane_master/fire_seen/backdrop(mob/mymob)
	if(!lit)
		lit = new
	mymob?.client?.screen |= lit

/// The lighting's picture drawn on the seen plane, see-through where it is black and solid where it is even a little lit
/atom/movable/screen/fire_seen_part
	screen_loc = "SOUTHWEST"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	plane = FIRE_SEEN_PLANE
	render_source = LIGHTING_PLANE_RENDER_TARGET
	// Red, green and blue each add to how solid it is, twenty times over, so even faint light counts; the colour is white
	color = list(0, 0, 0, 20, 0, 0, 0, 20, 0, 0, 0, 20, 0, 0, 0, 0, 1, 1, 1, 0)

/// Holds the noise the fires are pushed about by. Never shown.
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
	mymob?.client?.screen |= noise

/**
 * Smooth random red and green, three times its size so it covers the whole screen, scrolling up for ever.
 *
 * In a displace filter red pushes a pixel sideways and green up or down, and mid grey leaves it be.
 * The sheet is the same square twice, one above the other, so after scrolling one square's height it jumps back to
 * where it started without that showing.
 */
/atom/movable/screen/fire_noise
	icon = 'icons/effects/flame_noise.dmi'
	icon_state = "noise"
	screen_loc = "SOUTHWEST"
	plane = FIRE_NOISE_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	// Scaling is about the sheet's middle, so this puts its left edge back at the screen's
	pixel_x = 256
	pixel_y = -256

/atom/movable/screen/fire_noise/Initialize(mapload)
	. = ..()
	transform = matrix().Scale(3)
	animate(src, pixel_y = 512, time = FLAME_SURGE_TIME SECONDS, loop = -1)
	animate(pixel_y = -256, time = 0)

// MARK: The flames

/obj/effect/hotspot
	/// 1, 2 or 3 for a small, middling or big fire
	var/flame_size = 1
	/// Whether we burn paler and hotter
	var/flame_hot = FALSE
	/// "bed", "inner", "edge" or "climb": what is round us
	var/flame_form = "edge"
	/// -1 or 1 to lean our flames out to the west or east, where there is open air on that side only
	var/flame_lean = 0
	/// How many burning tiles are in front of us, up to 3: a deep fire's back edge is drawn bigger
	var/flame_depth = 0
	/// Counts updates, for looking round again now and then
	var/flame_updates = 0
	/// What our flames are drawn on. A new one fades in over the old one when they change.
	var/obj/effect/abstract/flame_layer/flame_layer
	/// When our flames were last drawn
	var/flame_drawn_at = 0
	/// TRUE when our flames should change but were drawn too lately
	var/flame_dirty = FALSE

/**
 * What a fire's flames are drawn on, shown as part of the fire.
 *
 * A fire's animations start from their first frame whenever they change, so a tile that just swapped to a new look
 * jumps. Each look gets one of these instead, and the new one fades in while the old one fades out.
 */
/obj/effect/abstract/flame_layer
	// Abstract effects can't be seen, and neither can what shows them
	invisibility = 0
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	plane = FIRE_PLANE
	appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM | KEEP_APART | PIXEL_SCALE

/obj/effect/abstract/flame_layer/Destroy()
	// Only fires show these, and they are movables
	for(var/atom/movable/shown_by as anything in vis_locs)
		shown_by.vis_contents -= src
	return ..()

/// Sets our size from how much fuel we burnt. A size is only left again well past the line it was reached at, so a
/// fire burning right on a line doesn't flick between two sizes.
/obj/effect/hotspot/proc/set_flame_fuel(fuel)
	var/size = 1
	if(fuel > 1 || (flame_size == 3 && fuel > 0.6))
		size = 3
	else if(fuel > 0.1 || (flame_size >= 2 && fuel > 0.06))
		size = 2
	set_flame_size(size)

/// Draws us as a small (1), middling (2) or big (3) fire, as hot as we are now
/obj/effect/hotspot/proc/set_flame_size(size)
	var/hot = flame_hot ? (temperature > FLAME_HOT_END) : (temperature > FLAME_HOT_START)
	if(size == flame_size && hot == flame_hot)
		return
	flame_size = size
	flame_hot = hot
	update_flames()

/// Whether a turf is burning
/proc/flame_burning(turf/T)
	return T && !isnull(locate(/obj/effect/hotspot) in T)

/// Whether flames can't go into a turf: a wall, the edge of the map, or something solid on it
/proc/flame_blocked(turf/T)
	if(!T || T.density)
		return TRUE
	for(var/obj/thing in T)
		if(thing.density && !iseffect(thing))
			return TRUE
	return FALSE

/// Looks at what is round us and redraws us if that changed what we show
/obj/effect/hotspot/proc/look_round()
	var/turf/here = loc
	if(!isturf(here))
		return
	var/turf/behind = get_step(here, NORTH)
	var/form = "edge"
	if(flame_burning(behind))
		form = "inner"
		if(flame_burning(get_step(here, SOUTH)) && flame_burning(get_step(here, EAST)) && flame_burning(get_step(here, WEST)))
			form = "bed"
	else if(flame_blocked(behind))
		form = "climb"
	var/lean = 0
	if(form != "climb")
		var/turf/east = get_step(here, EAST)
		var/turf/west = get_step(here, WEST)
		var/open_east = !flame_burning(east) && !flame_blocked(east)
		var/open_west = !flame_burning(west) && !flame_blocked(west)
		if(open_east != open_west)
			lean = open_east ? 1 : -1
	var/depth = 0
	if(form == "edge" || form == "climb")
		var/turf/in_front = get_step(here, SOUTH)
		while(depth < 3 && flame_burning(in_front))
			depth++
			in_front = get_step(in_front, SOUTH)
	if(form == flame_form && lean == flame_lean && depth == flame_depth)
		return
	flame_form = form
	flame_lean = lean
	flame_depth = depth
	update_flames()

/// Tells the fires whose looks depend on a turf to look round again: beside it, and behind it up to three tiles
/proc/flame_tell_neighbours(turf/here)
	if(!isturf(here))
		return
	for(var/direction in list(SOUTH, EAST, WEST))
		for(var/obj/effect/hotspot/fire in get_step(here, direction))
			fire.look_round()
	var/turf/behind = here
	for(var/i in 1 to 3)
		behind = get_step(behind, NORTH)
		if(!behind)
			return
		for(var/obj/effect/hotspot/fire in behind)
			fire.look_round()

/// Called on every update: draws a change that had to wait, and now and then looks round again, as walls and things
/// can come and go without telling us
/obj/effect/hotspot/proc/flames_tick()
	flame_updates++
	if(flame_updates % FLAME_LOOK_ROUND_EVERY == 0)
		look_round()
	if(flame_dirty && world.time >= flame_drawn_at + FLAME_REDRAW_GAP)
		update_flames()

/obj/effect/hotspot/proc/update_flames()
	if(!isturf(loc))
		return
	// Redrawn at most so often, as every new look starts its animation over
	if(flame_layer && world.time < flame_drawn_at + FLAME_REDRAW_GAP)
		flame_dirty = TRUE
		return
	flame_dirty = FALSE
	flame_drawn_at = world.time
	var/obj/effect/abstract/flame_layer/fresh = new(null)
	// A deep fire's back edge is drawn bigger: as big as the burning tiles in front of it
	var/size = (flame_form == "edge" || flame_form == "climb") ? max(flame_size, flame_depth) : flame_size
	var/list/parts = list()
	if(flame_form == "bed")
		parts += flame_bed_overlay(size, flame_hot, loc)
		parts += flame_overlay("inner", size, flame_hot, 0, loc)
	else
		parts += flame_overlay(flame_form, size, flame_hot, flame_lean, loc)
	if((flame_form == "edge" || flame_form == "climb") && size > 1)
		parts += flame_smoke_overlay(size, loc)
	if(size > 1)
		parts += flame_heat_overlay(size, loc)
	fresh.add_overlay(parts)
	fresh.alpha = 0
	vis_contents += fresh
	animate(fresh, alpha = 255, time = FLAME_FADE)
	if(flame_layer)
		animate(flame_layer, alpha = 0, time = FLAME_FADE)
		QDEL_IN(flame_layer, FLAME_FADE)
	flame_layer = fresh

/// Leaves our flames on the turf to die down, as we go out
/obj/effect/hotspot/proc/flames_die()
	if(!flame_layer)
		return
	var/obj/effect/abstract/flame_layer/dying = flame_layer
	flame_layer = null
	vis_contents -= dying
	if(!isturf(loc))
		qdel(dying)
		return
	dying.forceMove(loc)
	animate(dying, alpha = 0, time = FLAME_DIE)
	QDEL_IN(dying, FLAME_DIE)

/// Which of the fires a turf shows, 0 to FLAME_KINDS * 2 - 1, the top half mirrored.
/// Not x and y times numbers mod a power of two, which repeat every few tiles in a lattice you can see.
/proc/flame_kind(turf/where)
	return ((where.x * 9283 + where.y * 6917) % 1009 * 7 + where.x * where.y) % (FLAME_KINDS * 2)

// The parts below take their layer's see-through-ness, so they fade with it

/proc/flame_overlay(form, size, hot, lean, turf/where)
	var/static/list/made = list()
	var/kind = flame_kind(where)
	var/key = "[form][size][hot][lean]-[kind]"
	if(made[key])
		return made[key]
	var/static/list/sheets = list("inner" = 'icons/effects/flame_gas_inner.dmi', "edge" = 'icons/effects/flame_gas.dmi', "climb" = 'icons/effects/flame_gas_climb.dmi')
	// A big fire's inner flames run along the ceiling, so they have a wider sheet of their own
	var/rolling = (form == "inner" && size == 3)
	var/mutable_appearance/flames = mutable_appearance(rolling ? 'icons/effects/flame_gas_inner3.dmi' : sheets[form], "[form][size][hot ? "h" : ""]-[kind % FLAME_KINDS][lean ? "r" : ""]", plane = FIRE_PLANE)
	// Every sheet has the tile in the middle across, 16 pixels up from its bottom
	flames.pixel_x = rolling ? -32 : -16
	flames.pixel_y = -16
	// Leaning flames are drawn leaning east; mirrored they lean west. The others are mirrored for half the turfs.
	if(lean ? (lean < 0) : (kind >= FLAME_KINDS))
		flames.transform = matrix(-1, 0, 0, 0, 1, 0)
	flames.appearance_flags = KEEP_APART | PIXEL_SCALE
	made[key] = flames
	return flames

/// The bed of flame on a tile with fire all round it: the piece of a four by four tile texture that this turf shows,
/// so beds next to each other join with no seam
/proc/flame_bed_overlay(size, hot, turf/where)
	var/static/list/made = list()
	var/state = "bed[size][hot ? "h" : ""]-[where.x % 4][where.y % 4]"
	if(made[state])
		return made[state]
	var/mutable_appearance/bed = mutable_appearance('icons/effects/flame_gas_bed.dmi', state, plane = FIRE_PLANE)
	bed.appearance_flags = KEEP_APART | PIXEL_SCALE
	made[state] = bed
	return bed

/// The shimmer of the hot air over a middling or big fire, drawn where the game's warp reads it, not seen itself
/proc/flame_heat_overlay(size, turf/where)
	var/static/list/made = list()
	var/kind = flame_kind(where)
	var/key = "[size]-[kind]"
	if(made[key])
		return made[key]
	var/mutable_appearance/heat = mutable_appearance('icons/effects/flame_heat.dmi', "heat[size]-[kind % FLAME_KINDS]", plane = GRAVITY_PULSE_PLANE)
	heat.pixel_x = -16
	heat.pixel_y = -16
	heat.appearance_flags = KEEP_APART | PIXEL_SCALE
	made[key] = heat
	return heat

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
	smoke.appearance_flags = KEEP_APART | PIXEL_SCALE
	made[key] = smoke
	return smoke

#undef FLAME_KINDS
#undef FLAME_HOT_START
#undef FLAME_HOT_END
#undef FLAME_GLOW_BLUR
#undef FLAME_GLOW_ALPHA
#undef FLAME_BLOOM_THRESHOLD
#undef FLAME_SURGE
#undef FLAME_SURGE_TIME
#undef FLAME_LOOK_ROUND_EVERY
#undef FLAME_REDRAW_GAP
#undef FLAME_FADE
#undef FLAME_DIE
