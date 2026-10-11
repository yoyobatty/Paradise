/datum/proximity_monitor/advanced/singulo

/datum/proximity_monitor/advanced/singulo/on_entered(turf/source, atom/movable/entered, turf/old_loc)
	// Everything a loose singularity drags around comes through here, and only projectiles matter to it
	if(!isprojectile(entered))
		return
	. = ..()

	var/angle_to_singulo = ATAN2(host.y - source.y, host.x - source.x)
	var/distance_to_singulo = get_dist(source, host)

	var/obj/projectile/P = entered
	var/distance = distance_to_singulo
	var/projectile_angle = P.Angle
	var/angle_to_projectile = angle_to_singulo
	if(angle_to_projectile == 180)
		angle_to_projectile = -180
	angle_to_projectile -= projectile_angle
	if(angle_to_projectile > 180)
		angle_to_projectile -= 360
	else if(angle_to_projectile < -180)
		angle_to_projectile += 360

	if(distance == 0)
		qdel(P)
		return
	projectile_angle += angle_to_projectile / (distance ** 2)
	P.damage += 10 / distance
	P.set_angle(projectile_angle)

/datum/proximity_monitor/advanced/singulo/on_uncrossed(turf/source, atom/movable/gone, direction)
	// Nothing happens when something leaves the field, so don't work out where it went
	return
