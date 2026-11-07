/// Where the windows this test opens are saved, so tgui can check they all draw (tgui/bin/tgui --window-check)
#define TGUI_WINDOW_DATA_FILE "data/tgui_window_data.json"
/// How long a window gets to open before the test gives up on it
#define TGUI_WINDOW_OPEN_TIMEOUT (5 SECONDS)

/**
 * Opens the TGUI window of everything that has one, as a test player, and checks:
 * - nothing runtimes while it opens or builds its data
 * - the data has no objects or NaN in it, since those reach the window as junk
 * - the interface it asks for exists in tgui
 * Everything each window was sent is saved to TGUI_WINDOW_DATA_FILE, and CI draws each one with it afterwards.
 */
/datum/game_test/tgui_windows
	/// Things that can't open their window in a test, and why. Their subtypes are skipped too.
	var/list/cant_test = list(
		/obj/item/camera_bug = "shows a camera view, which needs a real player",
		/obj/item/handheld_mirror = "makes its window the first time it's used",
		/obj/item/radio/phone_receiver = "only exists inside a phone",
		/obj/machinery/computer/scan_consolenew = "needs a DNA scanner next to it",
		/obj/machinery/computer/security = "shows a camera view, which needs a real player",
		/obj/machinery/computer/syndicate_depot = "only works inside the syndicate depot",
	)
	/// The window type being opened right now, so the timeout knows what hung
	var/opening_type
	/// Set once the window type being opened is done
	var/opened = FALSE

/datum/game_test/tgui_windows/Run()
	var/datum/test_puppeteer/player = new(src)
	var/list/saved_windows = list()
	var/list/opened_interfaces = list()

	for(var/window_type in find_window_types())
		if(QDELETED(player.puppet) || player.puppet.stat == DEAD)
			player = new(src)
		var/atom/movable/thing
		try
			thing = new window_type(get_step(player.puppet, EAST))
		catch(var/exception/spawn_error)
			TEST_FAIL("[window_type] runtimed when it was made: [spawn_error] at [spawn_error.file]:[spawn_error.line]")
			continue
		if(QDELETED(thing))
			continue
		if(isitem(thing))
			player.puppet.put_in_hands(thing)

		GLOB.game_test_tgui_windows = list()
		open_window(thing, player.puppet)
		var/list/windows = GLOB.game_test_tgui_windows
		GLOB.game_test_tgui_windows = null

		for(var/datum/tgui/window in windows)
			opened_interfaces[window.interface] = TRUE
			var/payload = check_window(window, window_type)
			if(payload)
				saved_windows += list(list("type" = "[window_type]", "interface" = window.interface, "payload" = payload))
			window.src_object = null
			window.user = null
		player.puppet.drop_l_hand(force = TRUE)
		player.puppet.drop_r_hand(force = TRUE)
		qdel(thing)
		CHECK_TICK

	fdel(TGUI_WINDOW_DATA_FILE)
	text2file(json_encode(saved_windows), TGUI_WINDOW_DATA_FILE)
	log_world("TGUI windows: opened [length(saved_windows)] windows using [length(opened_interfaces)] interfaces")

/// Every type that has a TGUI window of its own, and everything under it
/datum/game_test/tgui_windows/proc/find_window_types()
	var/list/window_types = list()
	// BYOND can't tell which types change a proc, so read the code for it.
	// Paradise always writes these with the full path, like /obj/machinery/autolathe/ui_interact(
	var/list/folders = list("code/")
	while(length(folders))
		var/folder = folders[length(folders)]
		folders.len--
		for(var/entry in flist(folder))
			if(copytext(entry, -1) == "/")
				folders += "[folder][entry]"
				continue
			if(copytext(entry, -3) != ".dm")
				continue
			var/text = file2text("[folder][entry]")
			var/position = findtext(text, "/ui_interact(")
			while(position)
				var/line_start = findlasttext(text, "\n", position) + 1
				if(text2ascii(text, line_start) == 47) // Starts with a /
					var/window_host = text2path(copytext(text, line_start, position))
					if(ispath(window_host, /atom/movable))
						window_types |= typesof(window_host)
				position = findtext(text, "/ui_interact(", position + 1)

	var/list/testable_types = list()
	for(var/atom/movable/window_type as anything in window_types)
		if(initial(window_type.desc) == ABSTRACT_TYPE_DESC)
			continue
		var/skipped = FALSE
		for(var/skipped_type in cant_test)
			if(ispath(window_type, skipped_type))
				skipped = TRUE
				break
		if(!skipped)
			testable_types += window_type
	return testable_types

/datum/game_test/tgui_windows/proc/open_window(atom/movable/thing, mob/user)
	opening_type = thing.type
	opened = FALSE
	open_window_async(thing, user)
	var/give_up_at = world.time + TGUI_WINDOW_OPEN_TIMEOUT
	while(!opened && world.time < give_up_at)
		stoplag()
	if(!opened)
		TEST_FAIL("[opening_type] didn't finish opening its window within [TGUI_WINDOW_OPEN_TIMEOUT / 10] seconds")
		opened = TRUE

/datum/game_test/tgui_windows/proc/open_window_async(atom/movable/thing, mob/user)
	set waitfor = FALSE
	var/our_type = thing.type
	try
		thing.ui_interact(user)
	catch(var/exception/open_error)
		TEST_FAIL("[our_type] runtimed opening its window: [open_error] at [open_error.file]:[open_error.line]")
	if(opening_type == our_type)
		opened = TRUE

/// Builds what the window would send to a player and checks it. Returns it as JSON, or null if it couldn't be built.
/datum/game_test/tgui_windows/proc/check_window(datum/tgui/window, window_type)
	var/interface = window.interface
	if(!fexists("tgui/packages/tgui/interfaces/[interface].tsx") && !fexists("tgui/packages/tgui/interfaces/[interface].jsx") \
		&& !fexists("tgui/packages/tgui/interfaces/[interface]/index.tsx") && !fexists("tgui/packages/tgui/interfaces/[interface]/index.jsx"))
		TEST_FAIL("[window_type] opens the \"[interface]\" interface, but tgui/packages/tgui/interfaces has no file for it")
		return

	// Real players only get a window they can use, but draw every one as if they could
	window.status = UI_INTERACTIVE
	var/list/payload
	try
		window.src_object.ui_assets(window.user)
		payload = window.get_payload(with_data = TRUE, with_static_data = TRUE)
	catch(var/exception/data_error)
		TEST_FAIL("[window_type] runtimed building the data for its \"[interface]\" window: [data_error] at [data_error.file]:[data_error.line]")
		return

	for(var/part in list("data", "static_data"))
		var/problem = find_bad_value(payload[part], part)
		if(problem)
			TEST_FAIL("[window_type] sends [problem] to its \"[interface]\" window")
	return json_encode(payload)

/// Looks through window data for things that don't survive being sent. Returns where the first one is, or null.
/datum/game_test/tgui_windows/proc/find_bad_value(value, where)
	if(isdatum(value))
		return "an object ([value:type]) in [where]"
	if(isnum(value) && value != value)
		return "NaN in [where]"
	if(!islist(value))
		return
	var/list/value_list = value
	for(var/i in 1 to length(value_list))
		var/key = value_list[i]
		var/problem = find_bad_value(key, "[where]\[[i]\]")
		if(problem)
			return problem
		if(istext(key))
			problem = find_bad_value(value_list[key], "[where].[key]")
			if(problem)
				return problem

#undef TGUI_WINDOW_DATA_FILE
#undef TGUI_WINDOW_OPEN_TIMEOUT
