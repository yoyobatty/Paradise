/*
 * In this file you can find the particles for bullet hits
 * Originally from https://github.com/tgstation/TerraGov-Marine-Corps/pull/12752
 *
 * This used to be a component, but every wall and rock tile got one, and making a component for each of them cost more
 * than anything else they do at startup. Now types just set these vars, and bullet_act() checks them.
 */

/atom
	/// Icon state of the debris particles a projectile knocks off us, or null for no debris or smoke at all
	var/debris_icon_state
	/// Velocity of debris particles
	var/debris_velocity = -15
	/// Amount of debris particles
	var/debris_amount = 8
	/// Scale of particle debris
	var/debris_scale = 0.7

/// Smoke where a projectile hit us, and debris if it was a brute hit. See debris_icon_state.
/atom/proc/kick_up_debris(obj/projectile/P)
	var/angle = !isnull(P.Angle) ? P.Angle : round(get_angle(P.starting, src), 1)
	var/x_component = sin(angle) * debris_velocity
	var/y_component = cos(angle) * debris_velocity
	var/x_component_smoke = sin(angle) * -15
	var/y_component_smoke = cos(angle) * -15

	var/obj/effect/abstract/particle_holder/debris_visuals
	var/obj/effect/abstract/particle_holder/smoke_visuals
	var/position_offset = rand(-6, 6)

	smoke_visuals = new(src, /particles/impact_smoke)
	smoke_visuals.particles.position = list(position_offset, position_offset)
	smoke_visuals.particles.velocity = list(x_component_smoke, y_component_smoke)

	if(P.damage_type == BRUTE)
		debris_visuals = new(src, /particles/debris)
		debris_visuals.particles.position = generator(GEN_CIRCLE, position_offset, position_offset)
		debris_visuals.particles.velocity = list(x_component, y_component)
		debris_visuals.layer = ABOVE_OBJ_LAYER + 0.02
		debris_visuals.particles.icon_state = debris_icon_state
		debris_visuals.particles.count = debris_amount
		debris_visuals.particles.spawning = debris_amount
		debris_visuals.particles.scale = debris_scale
	smoke_visuals.layer = ABOVE_OBJ_LAYER + 0.01

	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(remove_debris_visuals), smoke_visuals, debris_visuals), 0.5 SECONDS)

/proc/remove_debris_visuals(obj/effect/abstract/particle_holder/smoke_visuals, obj/effect/abstract/particle_holder/debris_visuals)
	qdel(smoke_visuals)
	if(debris_visuals)
		qdel(debris_visuals)
