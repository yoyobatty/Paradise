// The skies a round can have; SSparallax picks one by weight before anyone connects
// A nebula entry: list(state, colour or colour matrix, alpha, flight speed); clouds stay still like the stars

/datum/sky_theme
	var/name = "Open space"
	/// Chance of this sky against the others
	var/weight = 10
	/// The theme's clouds; the first is the one the Med pref shows
	var/list/nebula = list()
	/// Tint on every star layer, or null for their own colours
	var/star_tint
	/// The galaxy in view, a sky_bodies.dmi state, or null
	var/galaxy
	/// The other world of this system, a sky_bodies.dmi state, or null
	var/neighbour
	/// The sun's colour, if this sky has one in view
	var/sun
	/// Whether a field of asteroids drifts close by
	var/asteroids = FALSE
	/// The colour of the light space gives off, or null for COLOR_STARLIGHT
	var/starlight
	/// The galaxy's band across the sky as list(tint, alpha), or null for none
	var/list/band = list("#ffffff", 220)

/datum/sky_theme/New()
	..()
	if(band)
		nebula += list(list("band", band[1], band[2], 0.2))

/// Every layer of this sky for one client; each layer knows its own depth
/datum/sky_theme/proc/build_layers()
	. = list()
	for(var/index in 1 to length(nebula))
		var/atom/movable/screen/parallax_layer/nebula/cloud = new
		cloud.setup(index, nebula[index])
		. += cloud
	for(var/type in list(/atom/movable/screen/parallax_layer/stars/deep, /atom/movable/screen/parallax_layer/stars, /atom/movable/screen/parallax_layer/stars/mid, /atom/movable/screen/parallax_layer/stars/near))
		var/atom/movable/screen/parallax_layer/stars = new type
		stars.color = star_tint
		. += stars
	if(galaxy)
		var/atom/movable/screen/parallax_layer/body/galaxy/far_galaxy = new
		far_galaxy.icon_state = galaxy
		. += far_galaxy
	if(sun)
		var/atom/movable/screen/parallax_layer/body/sun/near_star = new
		near_star.color = sun
		. += near_star
	if(neighbour)
		var/atom/movable/screen/parallax_layer/body/world/other_world = new
		other_world.icon_state = neighbour
		. += other_world
	for(var/index in 1 to length(SSparallax.deep_sky))
		var/atom/movable/screen/parallax_layer/body/deep/far_thing = new
		far_thing.setup(index)
		. += far_thing
	. += new /atom/movable/screen/parallax_layer/body/planet
	. += new /atom/movable/screen/parallax_layer/flybys
	if(asteroids)
		. += new /atom/movable/screen/parallax_layer/asteroids
	. += new /atom/movable/screen/parallax_layer/dust
	. += new /atom/movable/screen/parallax_layer/dust/mid

/datum/sky_theme/ember
	name = "Ember Reach"
	nebula = list(
		list("billow1", list(0.499, 0.0867, 0.0434, 0.922, 0.607, 0.26, 0.922, 0.882, 0.795), 255, 0.45),
		list("veil1", list(0.471, 0.166, 0.0664, 0.471, 0.332, 0.166, 0.107, 0.0221, 0.0295), 255, 0.55),
		list("haze", list(0.101, 0.0231, 0.12, 0.134, 0.0369, 0.0185, 0.588, 0.245, 0.111), 255, 0.35))
	neighbour = "world_redrock"
	sun = "#ffd2a8"
	starlight = "#f08a6c"
	band = list("#ffe2c8", 220)

/datum/sky_theme/glacier
	name = "Glacier Drift"
	nebula = list(
		list("billow2", list(0.048, 0.214, 0.517, 0.347, 0.827, 0.941, 0.797, 0.915, 0.941), 255, 0.45),
		list("veil2", list(0.215, 0.389, 0.431, 0.179, 0.206, 0.431, 0.0169, 0.0507, 0.108), 255, 0.55),
		list("haze", list(0.0295, 0.0886, 0.157, 0.0197, 0.118, 0.182, 0.182, 0.354, 0.492), 255, 0.35))
	neighbour = "world_ice"
	galaxy = "galaxy3"
	starlight = "#6cb6f5"
	band = list("#d8ecff", 220)

/datum/sky_theme/violet
	name = "Violet Deep"
	nebula = list(
		list("billow3", list(0.262, 0.0424, 0.509, 0.902, 0.205, 0.545, 0.902, 0.821, 0.87), 255, 0.42),
		list("veil1", list(0.155, 0.269, 0.373, 0.225, 0.202, 0.373, 0.0468, 0.0146, 0.0818), 255, 0.58),
		list("haze", list(0.0646, 0.0185, 0.129, 0.111, 0.0231, 0.0923, 0.369, 0.221, 0.588), 255, 0.35))
	neighbour = "world_rock"
	sun = "#d8dcff"
	starlight = "#a97cf5"
	band = list("#e8dcff", 220)

/datum/sky_theme/verdant
	name = "Verdant Shoal"
	nebula = list(
		list("billow4", list(0.0252, 0.303, 0.233, 0.151, 0.763, 0.53, 0.804, 0.763, 0.504), 255, 0.45),
		list("veil1", list(0.249, 0.294, 0.159, 0.294, 0.231, 0.111, 0.00692, 0.0484, 0.0415), 255, 0.55),
		list("haze", list(0.0111, 0.0775, 0.107, 0.0148, 0.0886, 0.0517, 0.118, 0.384, 0.295), 255, 0.35))
	neighbour = "world_jungle"
	galaxy = "galaxy4"
	starlight = "#62d9b4"
	band = list("#dcffe8", 220)

/datum/sky_theme/gold
	name = "Gilded Band"
	nebula = list(
		list("billow6", list(0.385, 0.214, 0.0378, 0.804, 0.656, 0.353, 0.804, 0.776, 0.694), 255, 0.40),
		list("veil2", list(0.125, 0.233, 0.365, 0.189, 0.325, 0.431, 0.0169, 0.044, 0.0812), 255, 0.48),
		list("haze", list(0.0969, 0.0646, 0.0277, 0.0277, 0.06, 0.0969, 0.443, 0.332, 0.185), 255, 0.35))
	band = list("#ffe6b0", 250)
	sun = "#fff0c8"
	asteroids = TRUE
	starlight = "#f2cf86"

/datum/sky_theme/rose
	name = "Rose Nursery"
	nebula = list(
		list("billow5", list(0.554, 0.0969, 0.346, 0.882, 0.422, 0.664, 0.882, 0.83, 0.858), 255, 0.42),
		list("billow3", list(0.066, 0.152, 0.447, 0.244, 0.447, 0.647, 0.589, 0.619, 0.647), 255, 0.52),
		list("veil2", list(0.314, 0.256, 0.285, 0.314, 0.17, 0.246, 0.0591, 0.0197, 0.0517), 255, 0.58))
	neighbour = "world_ocean"
	starlight = "#f08ac2"
	band = list("#ffdcec", 220)

/// Black with a faint band and a galaxy; likelier than any one of the others
/datum/sky_theme/quiet
	name = "Quiet Black"
	weight = 20
	nebula = list(
		list("haze", list(0.0418, 0.068, 0.146, 0.0314, 0.0523, 0.105, 0.235, 0.277, 0.403), 255, 0.35),
		list("veil2", list(0.0847, 0.108, 0.175, 0.0614, 0.076, 0.14, 0.0175, 0.0234, 0.0468), 255, 0.40))
	band = list("#c8d4f0", 150)
	galaxy = "galaxy"
	asteroids = TRUE

/datum/sky_theme/quiet/New()
	. = ..()
	galaxy = pick("galaxy", "galaxy2", "galaxy3", "galaxy4")
