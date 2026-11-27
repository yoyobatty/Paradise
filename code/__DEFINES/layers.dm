//Defines for atom layers and planes
//KEEP THESE IN A NICE ACSCENDING ORDER, PLEASE

#define CLICKCATCHER_PLANE -99

#define GRAVITY_PULSE_PLANE -96 //Needs to be behind space, otherwise it blocks space, lol
#define GRAVITY_PULSE_RENDER_TARGET "*GRAVPULSE_RENDER_TARGET"

#define PLANE_SPACE -95
#define PLANE_SPACE_PARALLAX -90

/// The bright molten part of lava, in its own colours. Never shown here: blurred, and added over the lighting by the
/// above lighting plane, so lava blooms past its edges
#define LAVA_GLOW_PLANE -23
#define LAVA_GLOW_RENDER_TARGET "*LAVA_GLOW_RENDER_TARGET"
/// How strong lava's wide glow is at its faintest and its strongest, as it breathes, out of 255
#define LAVA_GLOW_WIDE_LOW 90
#define LAVA_GLOW_WIDE_HIGH 150
/// Which way the water's surface slopes: a normal map, made of a pool's layers of waves, the rings of waves from
/// anything touching it and the wakes of anyone moving through it. Never shown: the pool floor, the reflections and the
/// foam are moved by it, so they bend under the waves, and the relief planes light the waves by it
#define WATER_RIPPLE_PLANE -22
#define WATER_RIPPLE_RENDER_TARGET "*WATER_RIPPLE_RENDER_TARGET"
/// How many pixels the ripples bend the pool floor seen through them
#define POOL_REFRACTION 3
/// How many pixels they bend reflections. More than the floor, as in real water
#define POOL_REFLECTION_RIPPLE 4
/// How far to move each pixel of the world to make its reflection in the water below it. Never shown, the
/// reflection plane reads it
#define WATER_MIRROR_PLANE -21
#define WATER_MIRROR_RENDER_TARGET "*WATER_MIRROR_RENDER_TARGET"
/// How many pixels a mirror map can move a pixel each way. A tile mirrors the one above it, so up to 63
#define POOL_MIRROR_REACH 64
/// Where the ripples break reflections up. Never shown, the reflection plane reads it as a second mask
#define WATER_SHIMMER_PLANE -20
#define WATER_SHIMMER_RENDER_TARGET "*WATER_SHIMMER_RENDER_TARGET"
/// Where there is water for things to be mirrored in. Never shown, only used to cut reflections to the water's shape
#define WATER_MASK_PLANE -19
#define WATER_MASK_RENDER_TARGET "*WATER_MASK_RENDER_TARGET"
/// A band along every edge of the water, strongest at the edge. Made from the water mask, nothing is drawn on it, and
/// never shown: it's where there is always a little foam
#define WATER_EDGE_BAND_PLANE -18
#define WATER_EDGE_BAND_RENDER_TARGET "*WATER_EDGE_BAND_RENDER_TARGET"
/// Where foam shows: the steep faces of waves, and the band along the water's edges. Made from the ripple plane and
/// the edge band, nothing is drawn on it, and never shown
#define WATER_FOAM_DRIVE_PLANE -17
#define WATER_FOAM_DRIVE_RENDER_TARGET "*WATER_FOAM_DRIVE_RENDER_TARGET"
/// The bottom of a pool, seen through the water
#define POOL_FLOOR_PLANE -16
/// Water turfs that are one flat sprite, like the beach away mission's sea
#define WATER_PLANE -15
/// Pool water turfs: the edge of the pool and the water's colour. All of these are under the floor plane so
/// reflections can be drawn between the water and what stands in it
#define WATER_EDGE_PLANE -14
/// Shafts of light slanting down through the water, added on
#define WATER_RAYS_PLANE -13
/// Reflections in water: a mirrored copy of the world plane, cut to the water. Over the water's colour, so they're
/// as clear as on real water
#define WATER_REFLECTION_PLANE -12
/// The sides of the waves facing away from the light, darkened. Made from the ripple map, nothing is drawn on it
#define WATER_RELIEF_SHADE_PLANE -11
/// The sides of the waves facing the light, brightened. Made from the ripple map, nothing is drawn on it
#define WATER_RELIEF_LIGHT_PLANE -10
#define WATER_RELIEF_LIGHT_RENDER_TARGET "WATER_RELIEF_LIGHT_RENDER_TARGET"
/// Glints of whatever light falls on the water, on the sides of the waves facing up into it. Never shown here: the
/// above lighting plane adds it after the lighting, so a glint can be brighter than the light on the water
#define WATER_SPECULAR_PLANE -9
#define WATER_SPECULAR_RENDER_TARGET "*WATER_SPECULAR_RENDER_TARGET"
/// Flecks of foam on the water, cut to where the foam drive plane says there is any
#define WATER_FOAM_PLANE -8
/// The glints of light on the water and the wakes on it, on top of its colour so they shine
#define WATER_SHINE_PLANE -7
// How hard a pool's wave machine is running
#define POOL_WAVES_OFF 0
#define POOL_WAVES_GENTLE 1
#define POOL_WAVES_STRONG 2
/// How many tiles from dry land pool water is at its darkest
#define POOL_MAX_DEPTH 3

#define FLOOR_PLANE -6
#define FLOOR_OVERLAY_PLANE -5

#define FLOOR_LIGHTING_LAMPS_GLARE -4
#define FLOOR_LIGHTING_LAMPS_SELFGLOW -3
#define FLOOR_LIGHTING_LAMPS_PLANE -2
#define FLOOR_LIGHTING_LAMPS_RENDER_TARGET "*FLOOR_LIGHTING_LAMPS_RENDER_TARGET"
#define ABOVE_GAME_PLANE -1.5
#define GAME_PLANE -1
/// The world plane's picture, for water to reflect. No * at the front, so the plane is still drawn as well
#define GAME_PLANE_RENDER_TARGET "GAME_PLANE_RENDER_TARGET"
#define BLACKNESS_PLANE 0 //To keep from conflicts with SEE_BLACKNESS internals

#define AREA_PLANE 1

#define SPACE_LAYER 1.5
#define GRASS_UNDER_LAYER 1.6
/// Which layer turfs appear on by default in the map editor. Should be unique!
#define MAP_EDITOR_TURF_LAYER 1.6999
#define PLATING_LAYER 1.7
#define LATTICE_LAYER 1.701
#define DISPOSAL_PIPE_LAYER 1.71
#define GAS_PIPE_HIDDEN_LAYER 1.72
#define WIRE_LAYER 1.73
#define WIRE_TERMINAL_LAYER 1.75
#define ABOVE_PLATING_LAYER 1.76 // generic for /obj/hide
#define TRAY_SCAN_LAYER_OFFSET 0.5 // place images above TURF_LAYER
//#define TURF_LAYER 2 //For easy recordkeeping; this is a byond define
#define ABOVE_TRANSPARENT_TURF_LAYER 2.01 // put wire terminals here if T.transparent_floor
#define MID_TURF_LAYER 2.02
#define HIGH_TURF_LAYER 2.03
#define TURF_PLATING_DECAL_LAYER 2.031
#define TURF_DECAL_LAYER 2.039 //Makes turf decals appear in DM how they will look inworld.
#define ABOVE_OPEN_TURF_LAYER 2.04
#define CLOSED_TURF_LAYER 2.05
#define BULLET_HOLE_LAYER 2.06
#define ABOVE_NORMAL_TURF_LAYER 2.08
#define ABOVE_ICYOVERLAY_LAYER 2.11
#define GAS_SCRUBBER_OFFSET -0.001
#define GAS_PIPE_VISIBLE_LAYER 2.47
#define GAS_PIPE_SCRUB_OFFSET 0.001
#define GAS_PIPE_SUPPLY_OFFSET 0.002
#define GAS_FILTER_OFFSET 0.003
#define GAS_PUMP_OFFSET 0.004
#define HOLOPAD_LAYER 2.491
#define CONVEYOR_LAYER 2.495
#define LOW_OBJ_LAYER 2.5
#define LOW_SIGIL_LAYER 2.52
#define SIGIL_LAYER 2.54
#define HIGH_SIGIL_LAYER 2.56

#define BELOW_OPEN_DOOR_LAYER 2.6
#define BLASTDOOR_LAYER 2.65
#define OPEN_DOOR_LAYER 2.7
#define PROJECTILE_HIT_THRESHHOLD_LAYER 2.75 //projectiles won't hit objects at or below this layer if possible
#define TABLE_LAYER 2.8
#define BELOW_OBJ_LAYER 2.9
#define LOW_ITEM_LAYER 2.95
//#define OBJ_LAYER 3 //For easy recordkeeping; this is a byond define
#define CLOSED_BLASTDOOR_LAYER 3.05
#define CLOSED_DOOR_LAYER 3.1
#define CLOSED_FIREDOOR_LAYER 3.11
#define SHUTTER_LAYER 3.12 // HERE BE DRAGONS
#define ABOVE_OBJ_LAYER 3.2
#define ABOVE_WINDOW_LAYER 3.3
#define DOOR_HELPER_LAYER 3.31 // Keep this above doors and windoors
#define SIGN_LAYER 3.4
#define NOT_HIGH_OBJ_LAYER 3.5
#define HIGH_OBJ_LAYER 3.6

#define BELOW_MOB_LAYER 3.7
#define LYING_MOB_LAYER 3.8
#define ABOVE_LYING_MOB_LAYER 3.9
//#define MOB_LAYER 4 //For easy recordkeeping; this is a byond define
#define ABOVE_MOB_LAYER 4.1
#define HITSCAN_LAYER 4.2
#define WALL_OBJ_LAYER 4.25
#define EDGED_TURF_LAYER 4.3
#define ON_EDGED_TURF_LAYER 4.35
#define LARGE_MOB_LAYER 4.4
#define ABOVE_ALL_MOB_LAYER 4.5

#define SPACEVINE_LAYER 4.8
#define SPACEVINE_MOB_LAYER 4.9
//#define FLY_LAYER 5 //For easy recordkeeping; this is a byond define
#define GASFIRE_LAYER 5.05
#define RIPPLE_LAYER 5.1

#define GHOST_LAYER 6
#define LOW_LANDMARK_LAYER 9
#define MID_LANDMARK_LAYER 9.1
#define HIGH_LANDMARK_LAYER 9.2
#define AREA_LAYER 10
#define MASSIVE_OBJ_LAYER 11
#define SMOKE_PLANE 12
#define POINT_LAYER 13

#define CHAT_LAYER 12.0001 // Do not insert layers between these two values
#define CHAT_LAYER_MAX 12.9999

/// This plane masks out lighting to create an "emissive" effect, ie for glowing lights in otherwise dark areas.
#define EMISSIVE_PLANE 13
/// The render target used by the emissive.
#define EMISSIVE_RENDER_TARGET "*EMISSIVE_PLANE"

#define POINT_PLANE 14
#define COGBAR_PLANE 15

#define LIGHTING_PLANE 16
/// The light falling on everything, for water to glint with. No * at the front, so the plane is still drawn as well
#define LIGHTING_PLANE_RENDER_TARGET "LIGHTING_PLANE_RENDER_TARGET"
#define LIGHTING_LAYER 16

#define LIGHTING_LAMPS_GLARE 17 // Light glare (optional setting)
#define LIGHTING_EXPOSURE_PLANE 18 // Light sources "cones"
#define LIGHTING_LAMPS_SELFGLOW 19 // Light sources glow (lamps, doors overlay, etc.)
#define LIGHTING_LAMPS_PLANE 20 // Light sources themselves (lamps, screens, etc.)

#define LIGHTING_LAMPS_RENDER_TARGET "*LIGHTING_LAMPS_RENDER_TARGET"

#define RAD_TEXT_LAYER 20.1

#define ABOVE_LIGHTING_PLANE 21
#define ABOVE_LIGHTING_LAYER 21

#define FLOOR_OPENSPACE_PLANE 22
#define OPENSPACE_LAYER 22

#define INFO_TAG_PLANE 23

#define BYOND_LIGHTING_PLANE 24
#define BYOND_LIGHTING_LAYER 24

#define CAMERA_STATIC_PLANE 24
#define CAMERA_STATIC_LAYER 24

//HUD layer defines

#define FULLSCREEN_PLANE 25
#define FLASH_LAYER 25
#define FULLSCREEN_LAYER 25.1
#define UI_DAMAGE_LAYER 25.2
#define BLIND_LAYER 25.3
#define CRIT_LAYER 25.4
#define CURSE_LAYER 25.5

#define HUD_PLANE 26
#define HUD_LAYER 26
#define ABOVE_HUD_PLANE 27
#define ABOVE_HUD_LAYER 27

#define SPLASHSCREEN_LAYER 28
#define SPLASHSCREEN_PLANE 28

#define HUD_PLANE_BUILDMODE 30

// This should always be on top. No exceptions.
#define HUD_PLANE_DEBUGVIEW 40

///Plane master controller keys
#define PLANE_MASTERS_GAME "plane_masters_game"
