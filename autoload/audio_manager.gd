extends Node

## Ses yönetimi. Bkz. CLAUDE.md §10.8. EventBus sinyallerine kendisi bağlanır
## (UI/mantık ses bilmez — tam decoupled). Placeholder ücretsiz assetler; M5'te
## bağlama/ney temalı final ses tasarımı gelir.
##
## NOT: preload YERİNE load() — böylece asset henüz import edilmemişken bile script
## derlenir (yoksa autoload derlenmez, import bloklanır: tavuk-yumurta).

const MUSIC_PATH := "res://assets/audio/music_ambient.mp3"
const SFX_PATHS := {
	"reveal": "res://assets/audio/sfx_reveal.wav",
	"mark": "res://assets/audio/sfx_mark.wav",
	"cull_evil": "res://assets/audio/sfx_cull_evil.mp3",
	"cull_good": "res://assets/audio/sfx_cull_good.mp3",
	"win": "res://assets/audio/sfx_win.wav",
	"lose": "res://assets/audio/sfx_lose.mp3",
	"deal": "res://assets/audio/sfx_deal.wav",
}
const SFX_POOL := 8

var _music: AudioStreamPlayer
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_i := 0
var _cache := {}


func _ready() -> void:
	_ensure_buses()
	_music = AudioStreamPlayer.new()
	_music.volume_db = -6.0
	_music.bus = &"Music"
	add_child(_music)
	var mstream := load(MUSIC_PATH)
	if mstream != null:
		if "loop" in mstream:
			mstream.loop = true
		_music.stream = mstream
		_music.play()

	for i in range(SFX_POOL):
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_sfx.append(p)

	apply_volumes()


## Master altında Music/SFX bus'ları yoksa oluştur (proje bus layout'undan bağımsız).
func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")


## Ayarlardaki 0..1 doğrusal seviyeleri bus dB'sine uygula (Ayarlar ekranı çağırır).
func apply_volumes() -> void:
	var s: Dictionary = SaveManager.settings
	_set_bus_linear(&"Master", s.get("vol_master", 0.9))
	_set_bus_linear(&"Music", s.get("vol_music", 0.6))
	_set_bus_linear(&"SFX", s.get("vol_sfx", 1.0))


func _set_bus_linear(bus_name: StringName, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var lin := clampf(v, 0.0, 1.0)
	if lin <= 0.001:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(lin))

	# V2 sinyalleri (§0.5): sorgu = kart/kağıt sesi; gece avı = boğuk darbe;
	# şafak = dağıtma sesi (hafif). Kurt ayıklama/kaybetme aynı.
	EventBus.character_questioned.connect(func(_s): sfx("reveal"))
	EventBus.night_kill.connect(func(_s): sfx("cull_good", -2.0, 0.8))  # düşük perde = av
	EventBus.day_started.connect(func(_d): sfx("deal", -8.0, 1.15))
	EventBus.card_executed.connect(_on_executed)
	EventBus.mark_changed.connect(func(_s, _m): sfx("mark", -6.0))
	EventBus.village_won.connect(func(_score): sfx("win"))
	EventBus.village_lost.connect(func(_r): sfx("lose"))


func _stream(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	if not SFX_PATHS.has(name):
		return null
	var s := load(SFX_PATHS[name]) as AudioStream
	_cache[name] = s
	return s


func sfx(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s := _stream(name)
	if s == null:
		return
	var p := _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## Yeni köy açılışında deste dağıtma sesi (board çağırır).
func play_deal() -> void:
	sfx("deal", -3.0)


func _on_executed(_seat: int, was_evil: bool) -> void:
	if was_evil:
		sfx("cull_evil", 2.0)
	else:
		sfx("cull_good", 0.0)
