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
	"question": "res://assets/audio/sfx_question.mp3",  # sorgu: şaşkın hayvan sesi
	"howl": "res://assets/audio/wolf_howl.wav",         # gece: uzak kurt uluması (sentez)
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
var _pitch_rng := RandomNumberGenerator.new()  # yalnız kozmetik perde oynaması


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
	_connect_signals()


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
# şafak = dağıtma sesi (hafif). Kurt ayıklama/kaybetme aynı. Yalnız _ready'den
# BİR KEZ çağrılır (apply_volumes her ayar değişiminde koşar; oraya koyma!).
func _connect_signals() -> void:
	# Sorgu: şaşkın hayvan sesi — perde her seferinde hafif oynar (her koyun
	# biraz farklı melesin). Kozmetik rastlantı; gameplay Rng stream'ine dokunmaz.
	EventBus.character_questioned.connect(func(_s): sfx("question", -4.0, _pitch_rng.randf_range(0.88, 1.14)))
	EventBus.night_kill.connect(func(_s): sfx("cull_good", -2.0, 0.8))  # düşük perde = av
	EventBus.day_started.connect(func(_d): sfx("deal", -8.0, 1.15))
	EventBus.card_executed.connect(_on_executed)
	# Gün/gece müzik dinamiği: gece çökerken müzik kısılır (tehdit sessizliği),
	# şafakta yumuşakça geri açılır. Kayıp/kazançta da alçalır (sonuç öne çıksın).
	# Gece ambiyansı (rüzgâr + cırcır, sentez loop) gece boyunca eşlik eder;
	# karanlığın ortasında uzaktan bir kurt ULUR.
	EventBus.night_passed.connect(func(_v):
		_duck_music(-15.0, 0.7)
		_start_ambience()
		var ht := get_tree().create_timer(1.6)
		ht.timeout.connect(func(): sfx("howl", -9.0, _pitch_rng.randf_range(0.9, 1.05))))
	EventBus.day_started.connect(func(_d):
		_duck_music(-6.0, 1.4)
		_stop_ambience())
	EventBus.village_won.connect(func(_s): _stop_ambience())
	EventBus.village_lost.connect(func(_r): _stop_ambience())
	EventBus.village_lost.connect(func(_r): _duck_music(-13.0, 1.0))
	EventBus.village_won.connect(func(_s): _duck_music(-6.0, 1.0))
	# İşaretleme sesi kaldırıldı (gecikmeli + rahatsızdı); mark yalnız görsel pop.
	EventBus.village_won.connect(func(_score): sfx("win"))
	EventBus.village_lost.connect(func(_r): sfx("lose"))
	# GERİLİM KATMANI: can azaldıkça + şafaklar tükendikçe fısıltılar yükselir
	# (amb_whispers). Sessiz şafak: yumuşak rahatlama çanı. Şafak raporu: kısa işaret.
	EventBus.player_damaged.connect(func(_a, _h): _update_tension())
	EventBus.card_executed.connect(func(_s, _e): _update_tension())
	EventBus.day_started.connect(func(_d): _update_tension())
	EventBus.night_passed.connect(func(_v): _update_tension())
	EventBus.village_won.connect(func(_s): _set_whisper(0.0))
	EventBus.village_lost.connect(func(_r): _set_whisper(0.0))
	EventBus.night_saved.connect(func(): sfx("reveal", -8.0, 1.35))
	EventBus.dawn_reports_given.connect(func(_seats): sfx("question", -12.0, 1.3))


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


## Gece ambiyansı: loop'lu rüzgâr+cırcır; fade ile girer/çıkar.
var _ambience: AudioStreamPlayer
var _amb_tween: Tween

func _start_ambience() -> void:
	if _ambience == null:
		_ambience = AudioStreamPlayer.new()
		_ambience.bus = &"SFX"
		add_child(_ambience)
		var stream := load("res://assets/audio/night_ambience.wav")
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = stream.data.size() / 2  # 16-bit mono: örnek sayısı
		_ambience.stream = stream
	if _ambience.stream == null:
		return
	if _amb_tween != null and _amb_tween.is_valid():
		_amb_tween.kill()
	_ambience.volume_db = -34.0
	if not _ambience.playing:
		_ambience.play()
	_amb_tween = create_tween()
	_amb_tween.tween_property(_ambience, "volume_db", -14.0, 2.2)


func _stop_ambience() -> void:
	if _ambience == null or not _ambience.playing:
		return
	if _amb_tween != null and _amb_tween.is_valid():
		_amb_tween.kill()
	_amb_tween = create_tween()
	_amb_tween.tween_property(_ambience, "volume_db", -36.0, 1.6)
	_amb_tween.tween_callback(func(): _ambience.stop())


## GERİLİM FISILTILARI: köy sıkıştıkça (düşük can + tükenen şafaklar) yükselen
## loop'lu fısıltı katmanı (amb_whispers). Müzik bus'ında yaşar; köy bitince susar.
var _whisper: AudioStreamPlayer
var _whisper_tween: Tween

func _update_tension() -> void:
	var t := 0.0
	if GameState.village != null and GameState.is_active():
		var v: VillageState = GameState.village
		t = clampf(0.55 * (1.0 - float(GameState.health) / float(GameState.max_health())) \
			+ 0.45 * float(v.day - 1) / float(maxi(1, v.max_days - 1)), 0.0, 1.0)
	_set_whisper(t)


func _set_whisper(t: float) -> void:
	if _whisper == null:
		_whisper = AudioStreamPlayer.new()
		_whisper.bus = &"Music"
		add_child(_whisper)
		var ws := load("res://assets/audio/amb_whispers.mp3")
		if ws != null and "loop" in ws:
			ws.loop = true
		_whisper.stream = ws
	if _whisper.stream == null:
		return
	if _whisper_tween != null and _whisper_tween.is_valid():
		_whisper_tween.kill()
	if t < 0.08:
		if _whisper.playing:
			_whisper_tween = create_tween()
			_whisper_tween.tween_property(_whisper, "volume_db", -44.0, 1.4)
			_whisper_tween.tween_callback(func(): _whisper.stop())
		return
	if not _whisper.playing:
		_whisper.volume_db = -44.0
		_whisper.play()
	_whisper_tween = create_tween()
	_whisper_tween.tween_property(_whisper, "volume_db", lerpf(-38.0, -13.0, t), 1.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Müziği hedef desibele yumuşakça taşı (gün/gece dinamiği).
var _duck_tween: Tween

func _duck_music(target_db: float, dur: float) -> void:
	if _music == null:
		return
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_property(_music, "volume_db", target_db, dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_executed(_seat: int, was_evil: bool) -> void:
	if was_evil:
		# cull_evil abartılıydı (kullanıcı geri bildirimi) — onun yerine av
		# vuruşunun iyice boğuk/düşük perdeli hali: tok, kısa, dramatik.
		sfx("cull_good", -6.0, 0.62)
	else:
		sfx("cull_good", 0.0)
