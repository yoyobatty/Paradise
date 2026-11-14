#define Z_LEVEL_NORTH 		"1"
#define Z_LEVEL_SOUTH 		"2"
#define Z_LEVEL_EAST 		"4"
#define Z_LEVEL_WEST 		"8"

#define TRANSITIONEDGE	7 //Distance from edge to move to another z-level

// Defining these here so everything is consistent
#define TRANSITION_BORDER_NORTH		(world.maxy - TRANSITIONEDGE - 1)
#define TRANSITION_BORDER_SOUTH		TRANSITIONEDGE
#define TRANSITION_BORDER_EAST		(world.maxx - TRANSITIONEDGE - 1)
#define TRANSITION_BORDER_WEST		TRANSITIONEDGE

#define TRANSITION_TAG_SPACE "SPACE"
#define TRANSITION_TAG_LAVALAND "LAVALAND"

/// TRUE if the turf's z-level is being built after startup, see /datum/space_level/var/being_built. A define because turfs check it a lot while one is.
#define TURF_LEVEL_BEING_BUILT(turf) ((turf).z <= length(GLOB.space_manager.levels_being_built) && GLOB.space_manager.levels_being_built[(turf).z])
/// TRUE if the turf is in the band along a level's edges that can lead to other levels. Only those go in the transit lists.
#define TURF_ON_TRANSITION_BORDER(level, turf) ((turf).x <= (level).transition_border_west || (turf).x >= (level).transition_border_east || (turf).y <= (level).transition_border_south || (turf).y >= (level).transition_border_north)
