extends Node

## Global sinyal merkezi. Node'lar birbirine DOĞRUDAN bağlı olmamalı; tüm
## motor->UI iletişimi buradan geçer. Bkz. CLAUDE.md §13.4, §16.

signal card_revealed(seat: int)                 ## legacy (V2'de kullanılmıyor)
signal card_executed(seat: int, was_evil: bool)

## V2 — Sorgu & Gece (bkz. CLAUDE.md §0.5).
signal character_questioned(seat: int)          ## ifade alındı (given arttı)
signal question_denied(seat: int, reason: String) ## hak yok / söyleyecek şey yok
signal night_kill(victim_seat: int)             ## kurt bir koyunu avladı
signal night_passed(victims: Array)             ## gece bitti (kurban listesi; boş=av yok)
signal day_started(day: int)                    ## şafak — sorgu hakları tazelendi
signal question_bought(questions_left: int, coins: int) ## parayla +1 sorgu alındı
signal player_damaged(amount: int, current_hp: int)
signal mark_changed(seat: int, mark_type: int)
signal spread_occurred(seat: int)               ## M3
signal village_won(score: int)
signal village_lost(reason: String)
signal omen_hint_learned(omen_type_partial: int) ## M3
signal trap_set(trapper_seat: int, target_seat: int)
signal trap_sprung(trapped_seat: int, caught_seat: int)
signal slayer_used(slayer_seat: int, target_seat: int, hit: bool) ## aktif yetenek
signal phase_changed(new_phase: int)

## Sefer (Run) seviyesi sinyaller — M2.
signal run_started(ascension: int, seed: int)
signal run_map_advanced(node_index: int)
signal run_completed(total_score: int, coins: int)
signal run_failed(node_index: int)
