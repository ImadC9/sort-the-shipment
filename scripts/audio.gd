extends Node
## Sound effects pool + background music.

const SFX := ["click", "pick", "land_ship", "land_buffer", "horn", "ship_full", "coin", "reveal",
	"unlock", "error", "whoosh", "splash", "star1", "star2", "star3", "win", "lose",
	"warn", "gold", "stamp", "star_lost", "rankup", "crate"]
const DISPATCH_SFX := ["dispatch_feeder", "dispatch_tanker", "dispatch_coaster", "dispatch_seal", "dispatch_chime"]

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _last_play := {}
var _duck_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in SFX + DISPATCH_SFX:
		var s = load("res://assets/audio/%s.wav" % n)
		if s:
			_streams[n] = s
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	var m = load("res://assets/audio/music.wav")
	if m is AudioStreamWAV:
		m.loop_mode = AudioStreamWAV.LOOP_FORWARD
		m.loop_begin = 0
		m.loop_end = int(m.get_length() * m.mix_rate)
	_music.stream = m
	_music.volume_db = -11.0
	add_child(_music)

func play(name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not Save.sound or not _streams.has(name):
		return
	# avoid stacking the exact same sound in the same frame
	var now := Time.get_ticks_msec()
	if _last_play.get(name, -1000) > now - 25:
		return
	_last_play[name] = now
	for p in _pool:
		if not p.playing:
			p.stream = _streams[name]
			p.pitch_scale = pitch
			p.volume_db = volume_db
			p.play()
			return

func music_on() -> void:
	if Save.music and not _music.playing:
		_music.play()

func music_off() -> void:
	_music.stop()

## A different timbre for each ship family, with a modest chain pitch lift.
func dispatch_horn(colour: int, rank: int = 1) -> void:
	if not Save.sound:
		return
	var family: String = DISPATCH_SFX[colour % 3]
	play(family, pow(2.0, 2.0 * mini(rank - 1, 2) / 12.0), -4.0)
	if not Save.music or not _music:
		return
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_property(_music, "volume_db", -14.0, 0.10)
	_duck_tween.tween_interval(0.75)
	_duck_tween.tween_property(_music, "volume_db", -11.0, 0.20)

func refresh_music() -> void:
	if Save.music:
		music_on()
	else:
		music_off()
