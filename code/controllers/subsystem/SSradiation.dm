/// No waves need anything from us right now
#define RAD_WAVES_DONE 0
/// Going through the tiles the waves reach this step, finding what's on each
#define RAD_WAVES_LOOKING 1
/// Giving the things on those tiles their radiation
#define RAD_WAVES_ACTING 2

PROCESSING_SUBSYSTEM_DEF(radiation)
	name = "Radiation"
	flags = SS_BACKGROUND | SS_NO_INIT
	wait = 1 SECONDS
	offline_implications = "Radiation will no longer function; power generation may not happen. A restart may or may not be required, depending on the situation."
	cpu_display = SS_CPUDISPLAY_HIGH
	var/list/warned_atoms = list()
	// Cache radiation levels for each turf so it doesn't need to be done iteratively
	// turf_rad_cache is the state in the current loop, and may not be 100% representative
	// until processing is complete.
	// prev_rad_cache is the fully evaluated radiation state cache from the previous tick.
	var/last_rad_cache_update = 0
	var/rad_cache_update_interval = 5 SECONDS
	var/list/turf_rad_cache = list()
	var/list/prev_rad_cache = list()
	/// Lazy list of all radioactive components
	var/list/all_radiations
	/// The radiation waves that are still spreading, by the number the Rust side gave them. How they spread is worked out there.
	var/list/datum/radiation_wave/waves = list()
	/// How many of those there are
	var/wave_count = 0
	/// Have we cleared out whatever waves the Rust side had from before this world started?
	var/waves_reset = FALSE
	/// Which part of spreading the waves we're on this fire, so it can stop when the tick runs out and carry on from there
	var/wave_stage = RAD_WAVES_DONE
	/// How far through that part's list we've got
	var/wave_position = 0
	/// The tiles the waves reach this step: x, y, z and emission type for each
	var/list/wave_asks
	/// For each of those tiles, the things on it that radiation acts on
	var/list/wave_contents
	/// For each of those tiles, whether there's anything in that list
	var/list/wave_occupied
	/// For each wave reaching a tile with something on it: the wave's number, which tile, and how much of the wave gets there
	var/list/wave_hits
	/// How much of each of those got through
	var/list/wave_passed
	/// Has everything else that processes here been started this fire?
	var/others_started = TRUE


/datum/controller/subsystem/processing/radiation/proc/warn(datum/component/radioactive/contamination)
	if(!contamination || QDELETED(contamination))
		return
	var/ref = contamination.parent.UID()
	if(warned_atoms[ref])
		return
	warned_atoms[ref] = TRUE
	var/atom/master = contamination.parent
	SSblackbox.record_feedback("tally", "contaminated", 1, master.type)
	var/msg = "has become contaminated with enough radiation to emit radiation waves || Source: [contamination.source] || Strength: [contamination.alpha_strength + contamination.beta_strength + contamination.gamma_strength]"
	master.investigate_log(msg, INVESTIGATE_RADIATION)

/datum/controller/subsystem/processing/radiation/fire(resumed)
	if(world.time > last_rad_cache_update + rad_cache_update_interval)
		refresh_rad_cache()
		last_rad_cache_update = world.time
	// The waves go first, then everything else that processes here
	if(!resumed)
		begin_waves()
		others_started = FALSE
	if(wave_stage != RAD_WAVES_DONE)
		spread_waves()
		if(state == SS_PAUSED || state == SS_PAUSING)
			return
	var/already_started = others_started
	others_started = TRUE
	. = ..(already_started)

/// Hands a new wave to the Rust side to spread. Weight is how much of it got past the tile it started on.
/datum/controller/subsystem/processing/radiation/proc/start_wave(datum/radiation_wave/wave, turf/place, weight)
	if(!waves_reset)
		rustlibs_rad_waves_reset()
		waves_reset = TRUE
	var/number = rustlibs_rad_wave_start(place.x, place.y, place.z, wave.intensity, wave.emission_type, weight)
	if(length(waves) < number)
		waves.len = number
	waves[number] = wave
	wave_count++

/// Gets every wave's next step worked out, and finds out which tiles we need to look at for it.
/datum/controller/subsystem/processing/radiation/proc/begin_waves()
	if(!waves_reset)
		rustlibs_rad_waves_reset()
		waves_reset = TRUE
	var/list/answer = rustlibs_rad_waves_begin(world.maxx, world.maxy)
	// First comes how many waves have run out, then their numbers
	var/ended = answer[1]
	for(var/i in 2 to ended + 1)
		var/number = answer[i]
		qdel(waves[number])
		waves[number] = null
		wave_count--
	// The rest is the tiles to look at
	answer.Cut(1, ended + 2)
	wave_asks = answer
	// One slot for each tile, filled in for the ones that turn out to have something on them
	wave_contents = new /list(length(answer) / 4)
	wave_occupied = new /list(length(answer) / 4)
	wave_position = 0
	wave_stage = RAD_WAVES_LOOKING

/// Moves every wave on a step. Stops when the tick runs out, and picks up where it left off next time.
/datum/controller/subsystem/processing/radiation/proc/spread_waves()
	if(wave_stage == RAD_WAVES_LOOKING)
		var/list/asks = wave_asks
		var/list/contents = wave_contents
		var/list/occupied = wave_occupied
		var/ask_count = length(asks)
		while(wave_position < ask_count)
			var/turf/place = locate(asks[wave_position + 1], asks[wave_position + 2], asks[wave_position + 3])
			var/list/things = get_rad_contents(place, asks[wave_position + 4])
			wave_position += 4
			if(length(things))
				contents[wave_position / 4] = things
				occupied[wave_position / 4] = TRUE
			// Not every tile, checking costs about as much as an empty one does
			if(!(wave_position % 64) && MC_TICK_CHECK)
				return
		wave_hits = rustlibs_rad_waves_resolve(occupied)
		wave_passed = list()
		wave_position = 0
		wave_stage = RAD_WAVES_ACTING

	if(wave_stage == RAD_WAVES_ACTING)
		var/list/hits = wave_hits
		var/list/passed = wave_passed
		var/hit_count = length(hits)
		while(wave_position < hit_count)
			var/datum/radiation_wave/wave = waves[hits[wave_position + 1]]
			var/list/things = wave_contents[hits[wave_position + 2]]
			var/weight = hits[wave_position + 3]
			wave_position += 3
			if(wave)
				var/atom/source = wave.source
				var/intensity = wave.intensity
				var/emission_type = wave.emission_type
				for(var/atom/thing as anything in things)
					if(QDELETED(thing))
						continue
					weight = weight * thing.base_rad_act(source, weight * intensity, emission_type)
			passed += weight
			if(MC_TICK_CHECK)
				return
		rustlibs_rad_waves_finish(passed)
		wave_asks = null
		wave_contents = null
		wave_occupied = null
		wave_hits = null
		wave_passed = null
		wave_stage = RAD_WAVES_DONE

/datum/controller/subsystem/processing/radiation/proc/get_turf_radiation(turf/place)
	if(prev_rad_cache[place])
		return prev_rad_cache[place]
	else
		return 0

/datum/controller/subsystem/processing/radiation/proc/update_rad_cache_contaminated(datum/component/radioactive/thing)
	var/atom/owner = thing.parent
	var/turf/place = get_turf(owner)
	if(turf_rad_cache[place])
		turf_rad_cache[place][1] += thing.alpha_strength
		turf_rad_cache[place][2] += thing.beta_strength
		turf_rad_cache[place][3] += thing.gamma_strength
	else
		turf_rad_cache[place] = list(thing.alpha_strength, thing.beta_strength, thing.gamma_strength)

/datum/controller/subsystem/processing/radiation/proc/update_rad_cache_inherent(datum/component/inherent_radioactivity/thing)
	var/atom/owner = thing.parent
	var/turf/place = get_turf(owner)
	if(turf_rad_cache[place])
		turf_rad_cache[place][1] += thing.radioactivity_alpha
		turf_rad_cache[place][2] += thing.radioactivity_beta
		turf_rad_cache[place][3] += thing.radioactivity_gamma
	else
		turf_rad_cache[place] = list(thing.radioactivity_alpha, thing.radioactivity_beta, thing.radioactivity_gamma)


/datum/controller/subsystem/processing/radiation/proc/refresh_rad_cache()
	prev_rad_cache.Cut()
	prev_rad_cache = turf_rad_cache
	turf_rad_cache = list()

#undef RAD_WAVES_DONE
#undef RAD_WAVES_LOOKING
#undef RAD_WAVES_ACTING
