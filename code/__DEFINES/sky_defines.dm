// The sky behind space (code/_onclick/hud/parallax.dm, sky.dm, sky_themes.dm)

/// A parallax tile in pixels: the sky's sheets are this size and layers repeat this far apart
#define PARALLAX_TILE 480

/// How much moves by itself, from the Parallax pref (sky_quality_for_pref()): nothing at Low
#define SKY_QUALITY_LOW 0
/// Stars twinkle and nebulae drift
#define SKY_QUALITY_MEDIUM 1
/// Near dust, comets, shooting stars and ships too
#define SKY_QUALITY_HIGH 2

/// Nebula clouds are drawn this many times their sprite's size
#define SKY_NEBULA_SCALE 2
/// How many groups the twinkling stars are in (twinkle1.. in sky.dmi)
#define SKY_TWINKLE_GROUPS 3

/// Light space gives off when the sky has no colour of its own
#define COLOR_STARLIGHT "#ffffff"

/// The angle the baked Lavaland sprites are lit from, degrees counter-clockwise from screen east (upper left)
#define SKY_PLANET_BAKE_ANGLE 135
