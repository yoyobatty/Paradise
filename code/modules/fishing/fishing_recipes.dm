/datum/crafting_recipe/fishing_rod
	name = "Makeshift Fishing Rod"
	result = list(/obj/item/fishing_rod)
	reqs = list(/obj/item/stack/rods = 2,
				/obj/item/stack/cable_coil = 5)
	time = 4 SECONDS
	category = CAT_MISC

/datum/crafting_recipe/fishing_hook
	name = "Fishing Hook"
	result = list(/obj/item/fishing_hook)
	reqs = list(/obj/item/stack/rods = 1)
	tools = list(TOOL_WIRECUTTER)
	time = 2 SECONDS
	category = CAT_MISC

/datum/crafting_recipe/fishing_line
	name = "Fishing Line"
	result = list(/obj/item/fishing_line)
	reqs = list(/obj/item/stack/cable_coil = 5)
	time = 2 SECONDS
	category = CAT_MISC

/datum/crafting_recipe/fishing_line_long
	name = "Deep Fishing Line"
	result = list(/obj/item/fishing_line/long)
	reqs = list(/obj/item/stack/cable_coil = 15)
	time = 4 SECONDS
	category = CAT_MISC

/datum/crafting_recipe/fishing_line_sinew
	name = "Sinew Fishing Line"
	result = list(/obj/item/fishing_line/sinew)
	reqs = list(/obj/item/stack/sheet/sinew = 3)
	time = 4 SECONDS
	category = CAT_PRIMAL

/datum/crafting_recipe/fish_plaque
	name = "Trophy Plaque"
	result = list(/obj/item/mounted/fish_plaque)
	reqs = list(/obj/item/stack/sheet/wood = 2)
	category = CAT_MISC

/datum/crafting_recipe/fishing_board
	name = "Angler's Record Board"
	result = list(/obj/item/mounted/fishing_board)
	reqs = list(/obj/item/stack/sheet/wood = 5)
	time = 4 SECONDS
	category = CAT_MISC
