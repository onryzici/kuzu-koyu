class_name LocTableBoard
extends RefCounted

## Yerelleştirme tablosu (board modülü). Loc autoload'u _ready'de birleştirir.
## Biçim: "anahtar": {"tr": "...", "en": "..."} — % yer tutucuları korunur.

const T := {
	# --- village_board.gd: gece/gündüz banner'ları ---
	"night_fell": {
		"tr": "Gece çöktü...",
		"en": "Night has fallen...",
	},
	"night_fell_howls": {
		"tr": "Gece çöktü — sürüden ulumalar geliyor...",
		"en": "Night has fallen — howls rise from the flock...",
	},
	"wolf_attacked": {
		"tr": "Kurt saldırdı — #%d can verdi!",
		"en": "The wolf struck — #%d is dead!",
	},
	"flock_survived": {
		"tr": "Sürü bu gece sağ çıktı.",
		"en": "The flock survived the night.",
	},
	# --- V3 Gece Trafiği (bkz. CLAUDE.md §0.7) ---
	"dawn_saved": {
		"tr": "Sessiz şafak — kurt saldırdı ama Otacı oradaydı. Kimse ölmedi.",
		"en": "A quiet dawn — the wolf struck, but the Herbalist was there. No one died.",
	},
	"dawn_report": {
		"tr": "Şafak raporları düştü (%s) — sorgu harcamadan.",
		"en": "The dawn reports are in (%s) — no question spent.",
	},
	# --- V3.1: Yüzleştirme (Y) ---
	"confront_pick": {
		"tr": "YÜZLEŞTİRME — #%d kimin hakkında konuşsun? Hedefi tıkla (2 sorgu hakkı) · iptal: aynı kart",
		"en": "CONFRONTATION — who should #%d speak about? Click a target (costs 2 questions) · cancel: same card",
	},
	"confront_no_q": {
		"tr": "Yüzleştirme 2 sorgu hakkı ister — hakkın yetmiyor.",
		"en": "A confrontation costs 2 questions — you don't have enough.",
	},
	"confront_pair_used": {
		"tr": "Bu ikiliyi zaten yüzleştirdin — aynı soruya aynı cevap.",
		"en": "You already confronted this pair — same question, same answer.",
	},
	"confront_hint": {
		"tr": "İpucu: Y ile yüzleştirme — bir kartı seç, hedefi tıklat; 2 sorguya nokta atışı cevap.",
		"en": "Tip: press Y to confront — pick a card, click a target; a pointed answer for 2 questions.",
	},
	# --- V3.1: Hipotez modu (H) ---
	"hypo_on": {
		"tr": "HİPOTEZ: '#%d kurt' varsayımı — %d dünya tutuyor. Halkalar: kızıl=kesin kurt, yeşil=kesin koyun. Kapat: H",
		"en": "HYPOTHESIS: assuming '#%d is a wolf' — %d worlds hold. Rings: red=certain wolf, green=certain sheep. Toggle off: H",
	},
	"hypo_off": {
		"tr": "Hipotez kapatıldı.",
		"en": "Hypothesis cleared.",
	},
	"hypo_impossible": {
		"tr": "İMKÂNSIZ: hiçbir tutarlı dünyada #%d kurt değil — bu da kanıttır: #%d KOYUN.",
		"en": "IMPOSSIBLE: no consistent world has #%d as a wolf — which is proof itself: #%d is a SHEEP.",
	},
	"day_refreshed": {
		"tr": "GÜN %d — sorgu hakların tazelendi",
		"en": "DAY %d — your questions are restored",
	},
	# --- village_board.gd: AĞIL (koruma) akışı ---
	"pen_dead_denied": {
		"tr": "Ölüler ağıla alınmaz — koruma seç ya da tekrar G'ye bas",
		"en": "The dead cannot be penned — pick a card to shelter or press G again",
	},
	"pen_protected": {
		"tr": "#%d ağıla alındı — gece çöküyor...",
		"en": "#%d is safe in the pen — night is falling...",
	},
	"pen_prompt": {
		"tr": "AĞIL — koruyacağın kartı seç · korumasız gece: tekrar GECE/G%s",
		"en": "THE PEN — pick a card to shelter · unguarded night: press NIGHT/G again%s",
	},
	"pen_qwarn": {
		"tr": "  (%d sorgu hakkın yanacak!)",
		"en": "  (%d questions will be wasted!)",
	},
	# --- village_board.gd: aktif yetenek hedefleme ---
	"target_verb_slay": {
		"tr": "kılıç saplayacağın",
		"en": "to strike with the blade",
	},
	"target_verb_hunt": {
		"tr": "ok atacağın",
		"en": "to loose an arrow at",
	},
	"target_verb_trap": {
		"tr": "kapan kuracağın",
		"en": "to set the trap on",
	},
	"target_pick": {
		"tr": "%s — %s kartı seç (iptal: tekrar tık)",
		"en": "%s — pick the card %s (cancel: click again)",
	},
	"slayer_hit": {
		"tr": "İsabet! Kurt vuruldu ve öldü.",
		"en": "A true strike! The wolf is slain.",
	},
	"slayer_miss": {
		"tr": "Iska — #%d bir kurt değildi.",
		"en": "A miss — #%d was no wolf.",
	},
	"trap_set": {
		"tr": "🪤 Kapan #%d'ye kuruldu — gece av oraya düşerse kurt yakalanır",
		"en": "🪤 Trap set at #%d — if the night hunt falls there, the wolf is caught",
	},
	"trap_sprung": {
		"tr": "🪤 KAPAN KAPANDI! #%d'ye saldıran #%d bir KURTTU — postu düştü!",
		"en": "🪤 TRAP SPRUNG! #%d's attacker, #%d, was a WOLF — its fleece has fallen!",
	},
	# --- village_board.gd: kurt son replikleri (WOLF_LAST_WORDS) ---
	"wolf_last_1": {
		"tr": "Ahh... ucuz bir vuruştu bu...",
		"en": "Ahh... a cheap shot, that...",
	},
	"wolf_last_2": {
		"tr": "Beni buldun demek, çoban...",
		"en": "So you found me, shepherd...",
	},
	"wolf_last_3": {
		"tr": "Kokumu nereden aldın?..",
		"en": "How did you catch my scent?..",
	},
	"wolf_last_4": {
		"tr": "Sürü... hâlâ bizim...",
		"en": "The flock... is still ours...",
	},
	"wolf_last_5": {
		"tr": "Bu daha bitmedi...",
		"en": "This is not over...",
	},
	"wolf_last_6": {
		"tr": "Postum düştü... ama dişlerim kaldı...",
		"en": "My fleece has fallen... but my teeth remain...",
	},
	"wolves_win_line": {
		"tr": "Sürü artık bizim, çoban...",
		"en": "The flock is ours now, shepherd...",
	},
	# --- hud.gd: sol menü panelleri ---
	"quest_foggy": {
		"tr": "SİSLİ GECE — kurt EN UZAK koyunu avlıyor!",
		"en": "FOGGY NIGHT — the wolf hunts the FARTHEST sheep!",
	},
	"quest_kills_suffix": {
		"tr": "  (gecede %d av)",
		"en": "  (%d kills a night)",
	},
	"quest_multi": {
		"tr": "Kurtları bul! Sürü gecede %d kurban veriyor",
		"en": "Find the wolves! The flock loses %d a night",
	},
	"quest_basic": {
		"tr": "Kurtları bul — her gece bir koyun can veriyor",
		"en": "Find the wolves — every night a sheep dies",
	},
	"hunted_progress": {
		"tr": "Avlanan: %d / %d Kurt",
		"en": "Hunted: %d / %d Wolves",
	},
	"day_label": {
		"tr": "Gün %d/%d   ·   Sorgu: %s",
		"en": "Day %d/%d   ·   Questions: %s",
	},
	"deaths_label": {
		"tr": "Kayıplar: %s  (kurda en yakındılar)",
		"en": "The fallen: %s  (they were nearest the wolf)",
	},
	"village_label": {
		"tr": "Köy: %d / %d",
		"en": "Village: %d / %d",
	},
	"meta_label": {
		"tr": "Çile: %d   ·   Para: %d",
		"en": "Ordeal: %d   ·   Coin: %d",
	},
	"flock_label": {
		"tr": "Sürü: %d hayvan",
		"en": "Flock: %d animals",
	},
	"score_label": {
		"tr": "Skor: %d",
		"en": "Score: %d",
	},
	# --- hud.gd: modlar, omen, overlay ---
	"hunt_mode_on": {
		"tr": "AV MODU — bir kart seç (yanlışsa −5 can)",
		"en": "HUNT MODE — pick a card (wrong pick: −5 health)",
	},
	"hunt_mode_off": {
		"tr": "Sorgula (sol tık) · işaretle (sağ tık) · G: günü bitir",
		"en": "Question (left click) · mark (right click) · G: end the day",
	},
	"omen_unknown": {
		"tr": "◉ Gizli Kural: ???",
		"en": "◉ Hidden Rule: ???",
	},
	"omen_unknown_hint": {
		"tr": "Kurtların dizilişinde bir desen var — Müneccim'i sorgula ya da çöz.",
		"en": "There is a pattern to where the wolves sit — question the Stargazer or deduce it.",
	},
	"wrong_cull": {
		"tr": "✘ Yanlış — masum bir koyundu. −5 can",
		"en": "✘ Wrong — it was an innocent sheep. −5 health",
	},
	"overlay_won": {
		"tr": "SÜRÜ KURTARILDI\nSkor: %d",
		"en": "THE FLOCK IS SAVED\nScore: %d",
	},
	"overlay_lost": {
		"tr": "SÜRÜ KURTLARA YEM OLDU\n(%s)",
		"en": "THE FLOCK FELL TO THE WOLVES\n(%s)",
	},
	"log_btn_tip": {
		"tr": "İfade Defteri (TAB)",
		"en": "Testimony Ledger (TAB)",
	},
	"new_village_btn": {
		"tr": "Yeni Köy (R)",
		"en": "New Village (R)",
	},
	# --- ability_tooltip.gd ---
	"tip_night_dead": {
		"tr": "Gece kurda yem oldu — kesin İYİYDİ. Verdiği ifadeler hâlâ geçerli.",
		"en": "Taken by the wolf in the night — certainly GOOD. Their testimonies still hold.",
	},
	"tip_question_hint": {
		"tr": "\nSorgula: sol tık.  Kalan ifadesi: %d.",
		"en": "\nQuestion: left click.  Statements left: %d.",
	},
	"tip_claims_header": {
		"tr": "\n\nİfadeleri:\n",
		"en": "\n\nTheir testimonies:\n",
	},
	"tip_was_wolf": {
		"tr": "Kurt!",
		"en": "Wolf!",
	},
	"tip_was_good": {
		"tr": "İyiydi",
		"en": "Was Good",
	},
	"tip_anchor": {
		"tr": "Kefilli — kesin İyi",
		"en": "Vouched — certainly Good",
	},
	"cat_villager": {
		"tr": "Koyun",
		"en": "Sheep",
	},
	"cat_outcast": {
		"tr": "Parya",
		"en": "Outcast",
	},
	"cat_minion": {
		"tr": "Kurt",
		"en": "Wolf",
	},
	"cat_demon": {
		"tr": "Alfa Kurt",
		"en": "Alpha Wolf",
	},
	# --- testimony_log.gd ---
	"log_title": {
		"tr": "İFADE DEFTERİ",
		"en": "TESTIMONY LEDGER",
	},
	"log_hint": {
		"tr": "Kurt HER ifadesinde yalan söyler; cesetler asla söylemez.  (TAB: kapat)",
		"en": "The wolf lies in EVERY testimony; the dead never lie.  (TAB: close)",
	},
	"night_rule_nearest": {
		"tr": "kurda en yakın koyun",
		"en": "the sheep nearest a wolf",
	},
	"night_rule_farthest": {
		"tr": "SİS: kurda en uzak koyun",
		"en": "FOG: the sheep farthest from a wolf",
	},
	"log_trap_entry": {
		"tr": "🪤 Gece %d: kapan #%d'de kapandı — #%d KURT çıktı (yakalandı, sağ).",
		"en": "🪤 Night %d: the trap at #%d snapped shut — #%d was a WOLF (caught alive).",
	},
	"log_night_entry": {
		"tr": "🌙 Gece %d: #%d kurda yem oldu — KESİN İYİYDİ. (Av: %s)",
		"en": "🌙 Night %d: #%d was taken by the wolf — CERTAINLY GOOD. (Prey: %s)",
	},
	"log_cull_wolf": {
		"tr": "🗡 #%d avlandı — KURT çıktı.",
		"en": "🗡 #%d was culled — a WOLF.",
	},
	"log_cull_good": {
		"tr": "🗡 #%d avlandı — İYİYDİ (hata).",
		"en": "🗡 #%d was culled — was GOOD (a mistake).",
	},
	"log_day_header": {
		"tr": "— GÜN %d —",
		"en": "— DAY %d —",
	},
	"log_culls_header": {
		"tr": "— ÇOBANIN AVLARI —",
		"en": "— THE SHEPHERD'S KILLS —",
	},
	"log_empty": {
		"tr": "Defter boş — henüz kimse sorgulanmadı.",
		"en": "The ledger is empty — no one has been questioned yet.",
	},
	# --- tutorial_guide.gd ---
	"tut_title": {
		"tr": "ÇOBAN REHBERİ",
		"en": "SHEPHERD'S GUIDE",
	},
	"tut_skip": {
		"tr": "Rehberi Geç",
		"en": "Skip Guide",
	},
	"tut_step_1": {
		"tr": "Sürüne hoş geldin çoban. Bu koyunlardan biri POSTA BÜRÜNMÜŞ KURT.\nBir karaktere tıklayıp SORGULA — herkes bir ifade verir.",
		"en": "Welcome to your flock, shepherd. One of these sheep is a WOLF IN WOOL.\nClick a character to QUESTION them — everyone gives a testimony.",
	},
	"tut_step_2": {
		"tr": "İşte bir ifade. İYİLER daima doğru söyler; KURT ise HER ifadesinde YALAN söyler.\nAynı karakteri tekrar sorgulayabilirsin — kurt konuştukça kendini ele verir.",
		"en": "There — a testimony. The GOOD always speak true; the WOLF LIES in EVERY testimony.\nYou may question the same character again — the more the wolf talks, the more it betrays itself.",
	},
	"tut_step_3": {
		"tr": "İpuçlarını kaybetme: TAB ile İFADE DEFTERİ'ni aç, sağ tıkla kartlara işaret koy.\nSorgu hakkın bitince GECE butonuyla günü kapat — ama bil: gece kurt avlanır.",
		"en": "Lose no clue: open the TESTIMONY LEDGER with TAB, right-click cards to mark them.\nWhen your questions run out, end the day with the NIGHT button — but know this: at night the wolf hunts.",
	},
	"tut_step_4": {
		"tr": "Kurt, kendisine ÇEMBERDE EN YAKIN koyunu yedi. Ceset asla yalan söylemez:\nölüm yerinden kurdun nerede OLAMAYACAĞINI çıkar. GECE'ye basmadan önce\nbutonun üstünde bekleyerek olası kurbanları görebilirsin.",
		"en": "The wolf ate the sheep NEAREST it on the CIRCLE. A corpse never lies:\nfrom where death fell, deduce where the wolf CANNOT be. Before pressing NIGHT,\nhover over the button to see who might fall prey.",
	},
	"tut_step_5": {
		"tr": "Kurdu bulduğuna inanıyorsan AVLA (E) butonuna bas, sonra kartı seç.\nDikkat: yanlış av sürüne −5 CAN. Emin ol, sonra vur.",
		"en": "If you believe you've found the wolf, press HUNT (E), then pick the card.\nBeware: a wrong kill costs the flock −5 HEALTH. Be certain, then strike.",
	},
	"tut_step_6": {
		"tr": "Kurdu buldun! Tüm kurtlar avlanınca köy kurtulur.\nBundan sonrası sende çoban — sürünü koru.",
		"en": "You found the wolf! When every wolf is hunted down, the village is saved.\nThe rest is yours, shepherd — guard your flock.",
	},
	"tut_wrong_cull": {
		"tr": "Bu bir koyundu — sürü −5 can kaybetti! İfadeleri DEFTERden tekrar tara;\nkurt, ifadesi yalanlarla çelişendir. Acele etme.",
		"en": "That was a sheep — the flock lost 5 health! Comb the LEDGER again;\nthe wolf is the one whose words clash with the truth. Do not rush.",
	},
	# --- game_state.gd: sorgu reddi + kayıp nedenleri ---
	"qdeny_no_questions": {
		"tr": "sorgu hakkı bitti",
		"en": "no questions left",
	},
	"qdeny_no_claims": {
		"tr": "söyleyecek yeni şeyi yok",
		"en": "nothing new to say",
	},
	"lose_jinxed": {
		"tr": "Uğursuz'un nazarı sürüyü bitirdi",
		"en": "the Jinxed one's evil eye finished the flock",
	},
	"lose_overrun": {
		"tr": "sürü kurtlara yenik düştü",
		"en": "the flock fell to the wolves",
	},
	"lose_days": {
		"tr": "şafaklar tükendi — kurtlar kazandı",
		"en": "the dawns ran out — the wolves won",
	},
	"lose_saint": {
		"tr": "Ermiş'i avladın — felaket!",
		"en": "you culled the Saint — calamity!",
	},
	"lose_health": {
		"tr": "can bitti",
		"en": "health ran out",
	},
}
