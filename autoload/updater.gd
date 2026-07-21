extends Node

## OTOMATİK GÜNCELLEME (GitHub Releases).
## Açılıştan birkaç saniye sonra releases/latest'ten son sürüm etiketi çekilir;
## yereldekinden (project.godot → application/config/version) yeniyse sağ-alt
## köşede bildirim çıkar. "Güncelle" → release'teki exe indirilir, çalışan exe
## `.old`'a taşınır (Windows çalışan exe'nin yeniden adlandırılmasına izin verir),
## yeni exe yerine konur ve oyun yeniden başlatılır. Bir sonraki açılışta `.old`
## kalıntısı silinir. Yalnız dışa aktarılmış Windows sürümünde aktif; editörde
## ve diğer platformlarda pasif. Yayınlama akışı: tools/release.ps1.
## İndirme başarısız olursa (izin yok / ağ koptu) release sayfası linki gösterilir.

const REPO := "onryzici/kuzu-koyu"
const API_LATEST := "https://api.github.com/repos/" + REPO + "/releases/latest"
const RELEASES_PAGE := "https://github.com/" + REPO + "/releases/latest"
## Açılış sekansıyla yarışmasın; menü otururken sessizce kontrol et.
const CHECK_DELAY := 3.0

var _latest_tag := ""
var _asset_url := ""
var _asset_size := 0
var _dl: HTTPRequest = null
var _dl_path := ""

var _ui: CanvasLayer = null
var _panel: PanelContainer = null
var _title_label: Label = null
var _body_label: Label = null
var _buttons: HBoxContainer = null


func _ready() -> void:
	# Güncelleme indirilirken oyuncu duraklatsa da indirme sürsün.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("standalone") or OS.get_name() != "Windows":
		return
	_cleanup_leftovers()
	await get_tree().create_timer(CHECK_DELAY).timeout
	_check_latest()


## Önceki güncellemeden kalan dosyalar: eski exe (.old) ve yarım indirme.
func _cleanup_leftovers() -> void:
	var exe := OS.get_executable_path()
	for p in [exe + ".old", exe.get_base_dir().path_join("WolfInWool.update.exe")]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _check_latest() -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(_on_latest_response.bind(req))
	var err := req.request(API_LATEST,
		["Accept: application/vnd.github+json", "User-Agent: WolfInWool-Updater"])
	if err != OK:
		req.queue_free()  # sessiz geç: güncelleme kontrolü oyunu asla bozmamalı


func _on_latest_response(result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray, req: HTTPRequest) -> void:
	req.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var j = JSON.parse_string(body.get_string_from_utf8())
	if j == null or typeof(j) != TYPE_DICTIONARY:
		return
	_latest_tag = String(j.get("tag_name", "")).trim_prefix("v")
	if _latest_tag == "" or not _is_newer(_latest_tag, _local_version()):
		return
	for a in j.get("assets", []):
		if String(a.get("name", "")).ends_with(".exe"):
			_asset_url = String(a.get("browser_download_url", ""))
			_asset_size = int(a.get("size", 0))
			break
	if _asset_url == "":
		return
	_show_prompt()


func _local_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## "1.2.10" > "1.2.9" gibi sayısal semver karşılaştırması (string karşılaştırma
## 10 < 9 derdi yaşar; o yüzden parça parça int).
func _is_newer(a: String, b: String) -> bool:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in range(maxi(pa.size(), pb.size())):
		var na := int(pa[i]) if i < pa.size() else 0
		var nb := int(pb[i]) if i < pb.size() else 0
		if na != nb:
			return na > nb
	return false


# ---------------------------------------------------------------- UI (toast)

func _show_prompt() -> void:
	_build_ui()
	_title_label.text = Loc.t("upd_title") % _latest_tag
	_body_label.text = Loc.t("upd_body") % _local_version()
	_add_button(Loc.t("upd_now"), _start_download, true)
	_add_button(Loc.t("upd_later"), _dismiss, false)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 99
	add_child(_ui)

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.045, 0.035, 0.97)
	sb.border_color = Color("e4a72e")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 10
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.position = Vector2(-16, -16)
	_ui.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 17)
	_title_label.add_theme_color_override("font_color", Color("e4a72e"))
	box.add_child(_title_label)

	_body_label = Label.new()
	_body_label.add_theme_font_size_override("font_size", 13)
	_body_label.add_theme_color_override("font_color", Color("ede3c8"))
	box.add_child(_body_label)

	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(_buttons)

	# Belirme animasyonu: sağdan yumuşak kayış.
	_panel.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_panel, "modulate:a", 1.0, 0.35)


func _add_button(text: String, cb: Callable, primary: bool) -> void:
	var b := Button.new()
	b.text = text
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("e4a72e") if primary else Color(0.16, 0.12, 0.09)
	sb.set_corner_radius_all(7)
	sb.set_content_margin_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = sbh.bg_color.lightened(0.12)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_color_override("font_color", Color("1c1712") if primary else Color("ede3c8"))
	b.add_theme_color_override("font_hover_color", Color("1c1712") if primary else Color("fff2dc"))
	b.pressed.connect(cb)
	_buttons.add_child(b)


func _clear_buttons() -> void:
	for c in _buttons.get_children():
		c.queue_free()


func _dismiss() -> void:
	if _ui != null:
		_ui.queue_free()
		_ui = null


# ---------------------------------------------------------------- indirme + kurulum

func _start_download() -> void:
	_clear_buttons()
	_body_label.text = Loc.t("upd_downloading") % 0
	_dl_path = OS.get_executable_path().get_base_dir().path_join("WolfInWool.update.exe")
	_dl = HTTPRequest.new()
	_dl.download_file = _dl_path
	# 182 MB'ı belleğe değil doğrudan diske akıt.
	_dl.download_chunk_size = 262144
	add_child(_dl)
	_dl.request_completed.connect(_on_download_done)
	var err := _dl.request(_asset_url, ["User-Agent: WolfInWool-Updater"])
	if err != OK:
		_fail()


func _process(_delta: float) -> void:
	if _dl == null or _asset_size <= 0 or _body_label == null:
		return
	var pct := int(100.0 * float(_dl.get_downloaded_bytes()) / float(_asset_size))
	_body_label.text = Loc.t("upd_downloading") % clampi(pct, 0, 99)


func _on_download_done(result: int, code: int, _headers: PackedStringArray,
		_body: PackedByteArray) -> void:
	var dl := _dl
	_dl = null
	dl.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail()
		return
	# Boyut kontrolü: yarım inen dosyayla exe'nin üzerine YAZMA.
	var f := FileAccess.open(_dl_path, FileAccess.READ)
	if f == null or (_asset_size > 0 and f.get_length() != _asset_size):
		if f != null:
			f.close()
		_fail()
		return
	f.close()
	_install_and_restart()


## Çalışan exe'yi değiştirme numarası: Windows çalışan exe'yi SİLMEYE izin vermez
## ama YENİDEN ADLANDIRMAYA izin verir. exe → .old, yeni → exe, yeniden başlat.
func _install_and_restart() -> void:
	var exe := OS.get_executable_path()
	var old := exe + ".old"
	DirAccess.remove_absolute(old)
	if DirAccess.rename_absolute(exe, old) != OK:
		_fail()  # yazma izni yok (ör. Program Files) — elle indirme yolunu göster
		return
	if DirAccess.rename_absolute(_dl_path, exe) != OK:
		DirAccess.rename_absolute(old, exe)  # geri al: oyun eski haliyle sağlam kalsın
		_fail()
		return
	_body_label.text = Loc.t("upd_restart")
	await get_tree().create_timer(0.8).timeout
	OS.create_process(exe, [])
	get_tree().quit()


func _fail() -> void:
	if _body_label == null:
		return
	_body_label.text = Loc.t("upd_failed")
	_clear_buttons()
	_add_button(Loc.t("upd_open_page"), func(): OS.shell_open(RELEASES_PAGE), true)
	_add_button(Loc.t("upd_later"), _dismiss, false)
