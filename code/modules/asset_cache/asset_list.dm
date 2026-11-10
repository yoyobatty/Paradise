//These datums are used to populate the asset cache, the proc "register()" does this.
//Place any asset datums you create in asset_list_items.dm

//all of our asset datums, used for referring to these later
GLOBAL_LIST_EMPTY(asset_datums)

//get an assetdatum or make a new one
//does NOT ensure it's filled, if you want that use get_asset_datum()
/proc/load_asset_datum(type)
	return GLOB.asset_datums[type] || new type()

/proc/get_asset_datum(type)
	var/datum/asset/loaded_asset = GLOB.asset_datums[type] || new type()
	return loaded_asset.ensure_ready()

/datum/asset
	var/_abstract = /datum/asset
	var/cached_serialized_url_mappings
	var/cached_serialized_url_mappings_transport_type

	/// Whether or not this asset should be loaded in the "early assets" SS
	var/early = FALSE

/datum/asset/New()
	GLOB.asset_datums[type] = src
	register()

/// Stub that allows us to react to something trying to get us
/// Not useful here, more handy for sprite sheets
/datum/asset/proc/ensure_ready()
	return src

/datum/asset/proc/get_url_mappings()
	return list()

/datum/asset/proc/register()
	return

/datum/asset/proc/send(client)
	return

/// If you don't need anything complicated.
/datum/asset/simple
	_abstract = /datum/asset/simple
	/// List of assets for this datum in the form of asset_filename = asset_file. At runtime the asset_file will be converted into a asset_cache datum
	var/assets = list()
	/// Set to true to have this asset also be sent via browse_rsc when cdn asset transports are enabled
	var/legacy = FALSE
	/// TRUE for keeping local asset names when browse_rsc backend is used
	var/keep_local_name = FALSE

/datum/asset/simple/register()
	for(var/asset_name in assets)
		var/datum/asset_cache_item/ACI = SSassets.transport.register_asset(asset_name, assets[asset_name])
		if(!ACI)
			log_debug("ERROR: Invalid asset: [type]:[asset_name]:[ACI]")
			continue
		if(legacy)
			ACI.legacy = TRUE
		if(keep_local_name)
			ACI.keep_local_name = keep_local_name
		assets[asset_name] = ACI

/datum/asset/simple/send(client)
	. = SSassets.transport.send_assets(client, assets)

/datum/asset/simple/get_url_mappings()
	. = list()
	for(var/asset_name in assets)
		var/datum/asset_cache_item/ACI = assets[asset_name]
		if(!ACI)
			continue
		.[asset_name] = SSassets.transport.get_asset_url(asset_name, assets[asset_name])


/// For registering or sending multiple others at once
/datum/asset/group
	_abstract = /datum/asset/group
	var/list/children

/datum/asset/group/register()
	for(var/type in children)
		load_asset_datum(type)

/datum/asset/group/send(client/C)
	for(var/type in children)
		var/datum/asset/A = get_asset_datum(type)
		. = A.send(C) || .

/datum/asset/group/get_url_mappings()
	. = list()
	for(var/type in children)
		var/datum/asset/A = get_asset_datum(type)
		. += A.get_url_mappings()

/// Returns a cached tgui message of URL mappings
/datum/asset/proc/get_serialized_url_mappings()
	if(isnull(cached_serialized_url_mappings) || cached_serialized_url_mappings_transport_type != SSassets.transport.type)
		cached_serialized_url_mappings = TGUI_CREATE_MESSAGE("asset/mappings", get_url_mappings())
		cached_serialized_url_mappings_transport_type = SSassets.transport.type

	return cached_serialized_url_mappings

// spritesheet implementation - coalesces various icons into a single .png file
// and uses CSS to select icons out of that file - saves on transferring some
// 1400-odd individual PNG files
// The sheets are built by iconforge in Rust, which is far quicker than building /icons in DM.
#define SPR_SIZE "size_id"
#define SPR_IDX "position"

/datum/asset/spritesheet
	_abstract = /datum/asset/spritesheet
	var/name
	/// list("32x32", "16x16")
	var/list/sizes = list()
	/// "foo_bar" -> list("size_id" = "32x32", "position" = 5)
	var/list/sprites = list()
	/// "foo_bar" -> the sprite as iconforge reads it, from Insert()
	var/list/entries = list()

/datum/asset/spritesheet/register()
	SHOULD_NOT_OVERRIDE(TRUE)

	if(!name)
		CRASH("spritesheet [type] cannot register without a name")

	create_spritesheets()
	realize_spritesheets()

/datum/asset/spritesheet/proc/realize_spritesheets()
	if(!length(entries))
		CRASH("spritesheet [type] has no sprites")
	var/output = rustlibs_iconforge_generate("data/spritesheets/", name, json_encode(entries))
	if(!findtext(output, "{", 1, 2))
		CRASH("Failed to build spritesheet [name]: [output]")
	var/list/data = json_decode(output)
	sizes = data["sizes"]
	sprites = data["sprites"]
	for(var/size_id in sizes)
		var/png_name = "[name]_[size_id].png"
		var/file_directory = "data/spritesheets/[png_name]"
		SSassets.transport.register_asset(png_name, fcopy_rsc(file_directory))
		fdel(file_directory)
	var/css_name = "spritesheet_[name].css"
	var/file_directory = "data/spritesheets/[css_name]"
	fdel(file_directory)
	text2file(generate_css(), file_directory)
	SSassets.transport.register_asset(css_name, fcopy_rsc(file_directory))
	fdel(file_directory)
	if(length(data["error"]))
		stack_trace("Errors building spritesheet [name]: [data["error"]]")

/datum/asset/spritesheet/send(client/client)
	if(!name)
		return
	var/all = list("spritesheet_[name].css")
	for(var/size_id in sizes)
		all += "[name]_[size_id].png"
	. = SSassets.transport.send_assets(client, all)

/datum/asset/spritesheet/get_url_mappings()
	if(!name)
		return

	. = list("spritesheet_[name].css" = SSassets.transport.get_asset_url("spritesheet_[name].css"))
	for(var/size_id in sizes)
		.["[name]_[size_id].png"] = SSassets.transport.get_asset_url("[name]_[size_id].png")

/datum/asset/spritesheet/proc/generate_css()
	var/list/out = list()

	for(var/size_id in sizes)
		var/list/size = splittext(size_id, "x")
		out += ".[name][size_id]{display:inline-block;width:[size[1]]px;height:[size[2]]px;background:url('[SSassets.transport.get_asset_url("[name]_[size_id].png")]') no-repeat;}"

	// iconforge puts all the sprites of one size in a single row
	for(var/sprite_id in sprites)
		var/sprite = sprites[sprite_id]
		var/size_id = sprite[SPR_SIZE]
		var/width = text2num(splittext(size_id, "x")[1])
		out += ".[name][size_id].[sprite_id]{background-position:-[sprite[SPR_IDX] * width]px 0px;}"

	return out.Join("\n")

/*
 * Override this in order to start the creation of the spritehseet.
 * This is where all your Insert, InsertAll, etc calls should be inside.
 */
/datum/asset/spritesheet/proc/create_spritesheets()
	SHOULD_CALL_PARENT(FALSE)
	CRASH("create_spritesheets() not implemented for [type]!")

/**
 * Adds a sprite to the sheet. Sprites whose state, dir or frame isn't in the file are left out.
 *
 * Arguments:
 * * sprite_name: the sprite's CSS class name
 * * I: the icon file
 * * transforms: changes made to the sprite, in order, from ICONFORGE_SCALE() and the like
 */
/datum/asset/spritesheet/proc/Insert(sprite_name, icon/I, icon_state = "", dir = SOUTH, frame = 1, list/transforms)
	if(entries[sprite_name])
		CRASH("duplicate sprite \"[sprite_name]\" in sheet [name] ([type])")
	entries[sprite_name] = list(
		"icon_file" = "[I]",
		"icon_state" = icon_state,
		"dir" = dir,
		"frame" = frame,
		"transform" = transforms || list(),
	)

/datum/asset/spritesheet/proc/InsertAll(prefix, icon/I, list/directions)
	if(length(prefix))
		prefix = "[prefix]-"

	if(!directions)
		directions = list(SOUTH)

	for(var/icon_state_name in icon_states(I))
		for(var/direction in directions)
			var/prefix2 = length(directions) > 1 ? "[dir2text(direction)]-" : ""
			Insert("[prefix][prefix2][icon_state_name]", I, icon_state=icon_state_name, dir=direction)

/datum/asset/spritesheet/proc/css_tag()
	return {"<link rel="stylesheet" href="[css_filename()]" />"}

/datum/asset/spritesheet/proc/css_filename()
	return SSassets.transport.get_asset_url("spritesheet_[name].css")

/datum/asset/spritesheet/proc/icon_tag(sprite_name)
	var/sprite = sprites[sprite_name]
	if(!sprite)
		return null
	var/size_id = sprite[SPR_SIZE]
	return {"<span class='[name][size_id] [sprite_name]'></span>"}

/datum/asset/spritesheet/proc/icon_class_name(sprite_name)
	var/sprite = sprites[sprite_name]
	if(!sprite)
		return null
	var/size_id = sprite[SPR_SIZE]
	return {"[name][size_id] [sprite_name]"}

/**
 * Returns the size class (ex design32x32) for a given sprite's icon
 *
 * Arguments:
 * * sprite_name - The sprite to get the size of
 */
/datum/asset/spritesheet/proc/icon_size_id(sprite_name)
	var/sprite = sprites[sprite_name]
	if(!sprite)
		return null
	var/size_id = sprite[SPR_SIZE]
	return "[name][size_id]"

#undef SPR_SIZE
#undef SPR_IDX


/datum/asset/spritesheet/simple
	_abstract = /datum/asset/spritesheet/simple
	var/list/assets

/datum/asset/spritesheet/simple/create_spritesheets()
	for(var/key in assets)
		Insert(key, assets[key])

/// Generates assets based on iconstates of a single icon
/datum/asset/simple/icon_states
	_abstract = /datum/asset/simple/icon_states
	var/icon
	var/list/directions = list(SOUTH)
	var/frame = 1
	var/movement_states = FALSE

	/// Used in asset name generation, (asset_name = `"[prefix].[icon_state_name].png"`)
	var/prefix = "default"
	/// Generate icon filenames using GENERATE_ASSET_NAME instead the `"[prefix].[icon_state_name].png"` format
	var/generic_icon_names = FALSE

/datum/asset/simple/icon_states/register(_icon = icon)
	for(var/icon_state_name in icon_states(_icon))
		for(var/direction in directions)
			var/asset = icon(_icon, icon_state_name, direction, frame, movement_states)
			if(!asset)
				continue
			asset = fcopy_rsc(asset) //dedupe
			var/prefix2 = (length(directions) > 1) ? "[dir2text(direction)]." : ""
			var/asset_name = "[prefix].[prefix2][icon_state_name].png"
			if(generic_icon_names)
				asset_name = "[GENERATE_ASSET_NAME(asset)].png"

			SSassets.transport.register_asset(asset_name, asset)

/datum/asset/simple/icon_states/multiple_icons
	_abstract = /datum/asset/simple/icon_states/multiple_icons
	var/list/icons

/datum/asset/simple/icon_states/multiple_icons/register()
	for(var/i in icons)
		..(i)

/// Namespace'ed assets (for static css and html files)
/// When sent over a cdn transport, all assets in the same asset datum will exist in the same folder, as their plain names.
/// Used to ensure css files can reference files by url() without having to generate the css at runtime, both the css file and the files it depends on must exist in the same namespace asset datum. (Also works for html)
/// For example `blah.css` with asset `blah.png` will get loaded as `namespaces/a3d..14f/f12..d3c.css` and `namespaces/a3d..14f/blah.png`. allowing the css file to load `blah.png` by a relative url rather then compute the generated url with get_url_mappings().
/// The namespace folder's name will change if any of the assets change. (excluding parent assets)
/datum/asset/simple/namespaced
	_abstract = /datum/asset/simple/namespaced
	/// parents - list of the parent asset or assets (in name = file assoicated format) for this namespace.
	/// parent assets must be referenced by their generated url, but if an update changes a parent asset, it won't change the namespace's identity.
	var/list/parents = list()

/datum/asset/simple/namespaced/register()
	if(legacy)
		assets |= parents
	var/list/hashlist = list()
	var/list/sorted_assets = sortTim(assets, GLOBAL_PROC_REF(cmp_text_asc), TRUE)

	for(var/asset_name in sorted_assets)
		var/datum/asset_cache_item/ACI = new(asset_name, sorted_assets[asset_name])
		if(!ACI?.hash)
			log_debug("ERROR: Invalid asset: [type]:[asset_name]:[ACI]")
			continue
		hashlist += ACI.hash
		sorted_assets[asset_name] = ACI
	var/namespace = md5(hashlist.Join())

	for(var/asset_name in parents)
		var/datum/asset_cache_item/ACI = new(asset_name, parents[asset_name])
		if(!ACI?.hash)
			log_debug("ERROR: Invalid asset: [type]:[asset_name]:[ACI]")
			continue
		ACI.namespace_parent = TRUE
		sorted_assets[asset_name] = ACI

	for(var/asset_name in sorted_assets)
		var/datum/asset_cache_item/ACI = sorted_assets[asset_name]
		if(!ACI?.hash)
			log_debug("ERROR: Invalid asset: [type]:[asset_name]:[ACI]")
			continue
		ACI.namespace = namespace

	assets = sorted_assets
	..()

/// A subtype to generate a JSON file from a list
/datum/asset/json
	_abstract = /datum/asset/json
	/// The filename, will be suffixed with ".json"
	var/name

/datum/asset/json/send(client)
	return SSassets.transport.send_assets(client, "[name].json")

/datum/asset/json/get_url_mappings()
	return list(
		"[name].json" = SSassets.transport.get_asset_url("[name].json"),
	)

/datum/asset/json/register()
	var/filename = "data/[name].json"
	fdel(filename)
	text2file(json_encode(generate()), filename)
	SSassets.transport.register_asset("[name].json", fcopy_rsc(filename))
	fdel(filename)

/// Returns the data that will be JSON encoded
/datum/asset/json/proc/generate()
	SHOULD_CALL_PARENT(FALSE)
	CRASH("generate() not implemented for [type]!")

/*
 * Get a html string that will load a html asset.
 * Needed because byond doesn't allow you to browse() to a url.
 */
/datum/asset/simple/namespaced/proc/get_htmlloader(filename)
	return URL2HTMLLOADER(SSassets.transport.get_asset_url(filename, assets[filename]))
