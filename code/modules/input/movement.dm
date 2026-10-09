#define NORTH_SOUTH (NORTH | SOUTH)
#define EAST_WEST (EAST | WEST)

/// Key loop to check for movement keys held and move in the desired direction.
/atom/movable/key_loop(client/C)
	var/datum/input_data/ID = C.input_data
	if(!ID)
		return

	var/direction = ID.desired_move_dir | ID.desired_move_dir_add
	if(!direction)
		// Nothing held and nothing waiting, so there's nothing a release could still cancel.
		// Forgetting it here is what lets a quick tap right after letting go count.
		ID.desired_move_dir_sub = NONE
		return
	direction &= ~ID.desired_move_dir_sub //bitflag fun at no extra cost

	// Pressing two opposite directions will cancel both out
	if((direction & NORTH_SOUTH) >= NORTH_SOUTH)
		direction &= ~NORTH_SOUTH
	if((direction & EAST_WEST) >= EAST_WEST)
		direction &= ~EAST_WEST

	C.Move(get_step(src, direction), direction)

#undef NORTH_SOUTH
#undef EAST_WEST
