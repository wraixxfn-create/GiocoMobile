class_name SfxDirector
extends Node
## Effetti sonori generati a runtime (nessun asset audio esterno, nessun file
## da importare): brevi "blip" sintetizzati in PCM 16 bit.
##
## Proprietà importanti:
## - **Leggero**: ogni suono dura meno di un secondo, è mono, 22 kHz, e viene
##   sintetizzato una sola volta all'avvio. In gioco non si alloca nulla.
## - **Non invasivo**: un piccolo pool di `AudioStreamPlayer` riutilizzati, con
##   un intervallo minimo tra due raccolte per evitare raffiche sovrapposte.
## - **Silenziabile**: lo stato attivo/muto è persistente (`user://`) e viene
##   applicato subito; nessun suono parte quando è muto.
## - **Sicuro nei test headless**: nessuna API audio obbligatoria, solo player
##   standard; in assenza di dispositivo il gioco continua a funzionare.

signal mute_changed(muted: bool)

const SECTION: String = "audio"
const MUTED_KEY: String = "muted"

## Percorso del salvataggio (modificabile nei test, come il portafoglio).
@export var save_path: String = GameConfig.AUDIO_SAVE_PATH
## Stato iniziale usato solo al primo avvio, quando il file non esiste.
@export var start_muted: bool = false
@export_range(-40.0, 6.0, 0.5) var sfx_volume_db: float = GameConfig.AUDIO_SFX_VOLUME_DB

## True quando l'audio è silenziato dall'utente.
var muted: bool = false

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _voice_index: int = 0
var _last_coin_ms: int = -100000
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# I suoni devono poter partire anche con la scena in pausa (pulsanti).
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"sfx")
	_rng.seed = 20240917
	_build_players()
	_build_streams()
	load_settings()


# ------------------------------------------------------------- Riproduzione ---

func play_coin() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_coin_ms < int(GameConfig.AUDIO_COIN_MIN_INTERVAL * 1000.0):
		return
	_last_coin_ms = now
	_play(&"coin", -2.0, _rng.randf_range(0.97, 1.05))


## `delta` positivo = evoluzione, negativo = regressione: due suoni distinti.
func play_evolution(delta: int = 1) -> void:
	if delta < 0:
		_play(&"regress", 0.0, 1.0)
	else:
		_play(&"evolution", 0.0, 1.0)


func play_impact() -> void:
	_play(&"impact", 1.0, _rng.randf_range(0.94, 1.04))


func play_victory() -> void:
	_play(&"victory", 1.0, 1.0)


func play_defeat() -> void:
	_play(&"defeat", 0.0, 1.0)


func play_button() -> void:
	_play(&"button", -1.0, _rng.randf_range(0.98, 1.04))


func stop_all() -> void:
	for player in _players:
		if player != null:
			player.stop()


# -------------------------------------------------------------------- Muto ---

func is_muted() -> bool:
	return muted


## Applica e salva lo stato. Emette `mute_changed` solo se cambia davvero.
func set_muted(value: bool) -> void:
	if value == muted:
		return
	muted = value
	if muted:
		stop_all()
	save_settings()
	mute_changed.emit(muted)


## Restituisce il nuovo stato (utile per aggiornare l'etichetta del pulsante).
func toggle_mute() -> bool:
	set_muted(not muted)
	return muted


func load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(save_path)
	if error == OK:
		muted = bool(config.get_value(SECTION, MUTED_KEY, start_muted))
	elif error == ERR_FILE_NOT_FOUND:
		muted = start_muted
		save_settings()
	else:
		push_warning("Impostazioni audio non leggibili (%s): uso i valori predefiniti." % save_path)
		muted = start_muted
	if muted:
		stop_all()


func save_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(save_path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		config = ConfigFile.new()
	config.set_value(SECTION, MUTED_KEY, muted)
	var save_error := config.save(save_path)
	if save_error != OK:
		push_warning("Impossibile salvare le impostazioni audio (%s), errore %d."
			% [save_path, save_error])


# ---------------------------------------------------------------- Interni ----

func _build_players() -> void:
	var count: int = maxi(GameConfig.AUDIO_VOICE_COUNT, 1)
	for index in count:
		var player := AudioStreamPlayer.new()
		player.name = "Voice_%d" % index
		player.volume_db = sfx_volume_db
		player.bus = &"Master"
		add_child(player)
		_players.append(player)


func _build_streams() -> void:
	_streams[&"coin"] = _make_coin()
	_streams[&"evolution"] = _make_evolution()
	_streams[&"regress"] = _make_regress()
	_streams[&"impact"] = _make_impact()
	_streams[&"victory"] = _make_victory()
	_streams[&"defeat"] = _make_defeat()
	_streams[&"button"] = _make_button()


## Sceglie una voce libera (o ricicla quella successiva) e la avvia.
func _play(key: StringName, volume_offset: float, pitch: float) -> void:
	if muted or _players.is_empty():
		return
	var stream := _streams.get(key, null) as AudioStream
	if stream == null:
		return
	var player := _free_player()
	player.stream = stream
	player.volume_db = sfx_volume_db + volume_offset
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.play()


func _free_player() -> AudioStreamPlayer:
	var count := _players.size()
	for offset in count:
		var candidate := _players[(_voice_index + offset) % count]
		if candidate != null and not candidate.playing:
			_voice_index = (_voice_index + offset + 1) % count
			return candidate
	var fallback := _players[_voice_index % count]
	_voice_index = (_voice_index + 1) % count
	return fallback


# ------------------------------------------------------------ Sintesi audio ---
## Ogni nota è un dizionario:
## start/length (s), freq (Hz), gain, decay, attack, wave (0=seno, 1=onda ricca),
## slide (variazione relativa di frequenza nella durata della nota).
static func _render(duration: float, notes: Array, noise: float = 0.0) -> AudioStreamWAV:
	var rate: int = maxi(GameConfig.AUDIO_SAMPLE_RATE, 8000)
	var count := int(ceil(duration * float(rate)))
	var data := PackedByteArray()
	data.resize(count * 2)

	# I parametri delle note vengono copiati in array tipizzati una sola volta:
	# il ciclo campione-per-campione resta leggero anche su un telefono.
	var note_count := notes.size()
	var starts := PackedFloat32Array()
	var lengths := PackedFloat32Array()
	var freqs := PackedFloat32Array()
	var gains := PackedFloat32Array()
	var decays := PackedFloat32Array()
	var attacks := PackedFloat32Array()
	var slides := PackedFloat32Array()
	var rich := PackedByteArray()
	starts.resize(note_count)
	lengths.resize(note_count)
	freqs.resize(note_count)
	gains.resize(note_count)
	decays.resize(note_count)
	attacks.resize(note_count)
	slides.resize(note_count)
	rich.resize(note_count)
	for note_index in note_count:
		var note: Dictionary = notes[note_index]
		var start := float(note.get("start", 0.0))
		starts[note_index] = start
		lengths[note_index] = maxf(float(note.get("length", duration - start)), 0.001)
		freqs[note_index] = float(note.get("freq", 440.0))
		gains[note_index] = float(note.get("gain", 0.35))
		decays[note_index] = float(note.get("decay", 6.0))
		attacks[note_index] = maxf(float(note.get("attack", 0.006)), 0.0005)
		slides[note_index] = float(note.get("slide", 0.0))
		rich[note_index] = 1 if int(note.get("wave", 0)) == 1 else 0

	var phases := PackedFloat32Array()
	phases.resize(note_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7351
	var rate_f := float(rate)
	for index in count:
		var time := float(index) / rate_f
		var value := 0.0
		for note_index in note_count:
			var local := time - starts[note_index]
			if local < 0.0 or local > lengths[note_index]:
				continue
			var length := lengths[note_index]
			var frequency := freqs[note_index] * (
				1.0 + slides[note_index] * (local / length)
			)
			phases[note_index] += TAU * frequency / rate_f
			var phase := phases[note_index]
			var envelope := (
				clampf(local / attacks[note_index], 0.0, 1.0)
				* exp(-local * decays[note_index])
			)
			var wave := sin(phase)
			if rich[note_index] == 1:
				wave = sin(phase) + 0.30 * sin(phase * 2.0) + 0.12 * sin(phase * 3.0)
			value += wave * envelope * gains[note_index]
		if noise > 0.0:
			value += rng.randf_range(-1.0, 1.0) * noise * exp(-time * 22.0)
		# Coda in dissolvenza: nessun click a fine suono.
		var tail := clampf((duration - time) / 0.02, 0.0, 1.0)
		var sample := clampf(value, -1.0, 1.0) * tail
		data.encode_s16(index * 2, int(round(sample * 30000.0)))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = data
	return stream


## Raccolta moneta: due note cristalline, brevissime.
static func _make_coin() -> AudioStreamWAV:
	return _render(0.17, [
		{"start": 0.0, "length": 0.09, "freq": 1174.7, "gain": 0.30, "decay": 22.0},
		{"start": 0.055, "length": 0.115, "freq": 1760.0, "gain": 0.26, "decay": 16.0, "wave": 1},
	])


## Evoluzione: arpeggio ascendente, luminoso ma breve.
static func _make_evolution() -> AudioStreamWAV:
	return _render(0.58, [
		{"start": 0.0, "length": 0.20, "freq": 523.3, "gain": 0.28, "decay": 7.0, "wave": 1},
		{"start": 0.10, "length": 0.22, "freq": 659.3, "gain": 0.28, "decay": 7.0, "wave": 1},
		{"start": 0.20, "length": 0.24, "freq": 784.0, "gain": 0.26, "decay": 6.0, "wave": 1},
		{"start": 0.30, "length": 0.28, "freq": 1046.5, "gain": 0.30, "decay": 4.5, "wave": 1},
	])


## Regressione: due note discendenti, morbide (mai fastidiose).
static func _make_regress() -> AudioStreamWAV:
	return _render(0.42, [
		{"start": 0.0, "length": 0.20, "freq": 392.0, "gain": 0.26, "decay": 8.0},
		{"start": 0.14, "length": 0.28, "freq": 261.6, "gain": 0.24, "decay": 6.0},
	])


## Collisione: tonfo basso con un soffio di rumore, molto corto.
static func _make_impact() -> AudioStreamWAV:
	return _render(0.26, [
		{"start": 0.0, "length": 0.26, "freq": 150.0, "gain": 0.42, "decay": 13.0,
			"attack": 0.002, "slide": -0.45},
		{"start": 0.0, "length": 0.14, "freq": 78.0, "gain": 0.30, "decay": 10.0},
	], 0.22)


## Vittoria: jingle ascendente e breve.
static func _make_victory() -> AudioStreamWAV:
	return _render(0.95, [
		{"start": 0.0, "length": 0.30, "freq": 523.3, "gain": 0.26, "decay": 4.0, "wave": 1},
		{"start": 0.12, "length": 0.32, "freq": 659.3, "gain": 0.26, "decay": 4.0, "wave": 1},
		{"start": 0.24, "length": 0.34, "freq": 784.0, "gain": 0.26, "decay": 3.6, "wave": 1},
		{"start": 0.38, "length": 0.55, "freq": 1046.5, "gain": 0.28, "decay": 2.6, "wave": 1},
		{"start": 0.38, "length": 0.55, "freq": 784.0, "gain": 0.14, "decay": 2.6},
	])


## Sconfitta: due note basse, senza drammi.
static func _make_defeat() -> AudioStreamWAV:
	return _render(0.7, [
		{"start": 0.0, "length": 0.36, "freq": 349.2, "gain": 0.26, "decay": 4.0},
		{"start": 0.22, "length": 0.48, "freq": 261.6, "gain": 0.26, "decay": 3.0},
		{"start": 0.22, "length": 0.48, "freq": 174.6, "gain": 0.12, "decay": 3.0},
	])


## Pulsante: click secco e leggero.
static func _make_button() -> AudioStreamWAV:
	return _render(0.075, [
		{"start": 0.0, "length": 0.075, "freq": 740.0, "gain": 0.22, "decay": 34.0,
			"attack": 0.002, "wave": 1},
	])
