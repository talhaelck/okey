extends Node3D
## Main 3D Kaotik Okey controller: 106-tile Okey rules, 4-player turn loop,
## physical tabletop interactions, tea spilling, leblebi throwing, smoke screen,
## Kabadayı sunglasses, and Karanlıkta Okey blackout events.

const COLOR_COUNT := 4
enum Phase { DRAW, DISCARD }

var hand := Hand.new()
var hud := Hud.new()
var watchers: Array[Watcher] = []
var stolen := 0
var caught := 0
var rounds_won := 0

const KNOCK_COOLDOWN := 6.0
var _knock_cooldown := 0.0
var _blackout_cooldown := 0.0
var _blackout_timer := 0.0
var _auto_blackout_clock := 28.0
var _rack_focus_time := 0.0
var _sort_by_number := false
var _magnifier_timer := 0.0

# Side Tables Snatch Contest
var _contest_clock := 14.0
var _contest_active := false
var _contest_timer := 0.0
var _contest_item := ""
var _contest_seat_idx := -1
var _lighter_light := OmniLight3D.new()

var turn_seat := 0
var turn_phase := Phase.DISCARD
var _turn_timer := 16.0
var _turn_max := 16.0
var _ai_step_done := false

var _knock_sound := AudioStreamPlayer3D.new()
var _sip_sound := AudioStreamPlayer3D.new()
var _bonk_sound := AudioStreamPlayer3D.new()

@onready var room: Node3D = $Room
@onready var camera: FocusCamera = $FocusCamera
@onready var table: Table = $Table
@onready var seats: Array[Seat] = [$Seats/Seat0, $Seats/Seat1, $Seats/Seat2, $Seats/Seat3]


func _ready() -> void:
	CafePreferences.restore()
	var chosen: String = CafePreferences.companion if CafePreferences.companion in CafePatron.KINDS else "sabri"
	seats[0].set_character(chosen)
	var all_kinds := ["sabri", "temel", "rifki", "davut"]
	var opp_kinds: Array = []
	for k in all_kinds:
		if k != chosen:
			opp_kinds.append(k)
	for i in 3:
		seats[i + 1].set_character(opp_kinds[i])

	_turn_max = 9.0 if CafePreferences.tile_speed == "HIZLI" else 16.0
	_deal()
	camera.attach_to_seat(seats[0])
	for seat in seats.slice(1):
		var watcher := Watcher.new()
		watcher.seat = seat
		watcher.local_seat = seats[0]
		for other in seats:
			if other != seat and other != seats[0]:
				watcher.others.append(other)
		add_child(watcher)
		watchers.append(watcher)

	hand.camera = camera
	hand.seat = seats[0]
	hand.seats = seats
	hand.table = table
	hand.watchers = watchers
	add_child(hand)
	hand.stole.connect(_on_stole)
	hand.caught.connect(_on_caught)
	hand.tile_drawn.connect(_on_tile_drawn)
	hand.tile_discarded.connect(_on_tile_discarded)
	hand.finish_declared.connect(_on_finish_declared)
	hand.prop_used.connect(_on_prop_used)
	hand.tile_snatched.connect(_on_tile_snatched)

	# Muhtar lighter flame light during blackout
	_lighter_light.name = "MuhtarLighterLight"
	_lighter_light.light_color = Color("ff9a36")
	_lighter_light.light_energy = 2.4
	_lighter_light.omni_range = 1.65
	_lighter_light.light_size = 0.08
	_lighter_light.position = seats[0].to_global(Vector3(0, Table.TOP + 0.16, 0.48))
	_lighter_light.visible = false
	add_child(_lighter_light)

	hud.camera = camera
	add_child(hud)
	hud.banter_spoken.connect(_on_banter_spoken)
	hud.action_requested.connect(_on_hud_action)

	_setup_sounds()

	var args := _user_args()
	if args.has("screenshot") and not get_parent().has_method("_home"):
		_capture(args)
	else:
		camera.set_focused(false, true)
		hud.flash("Masa Hazır! 15 taşın var — sağa 1 taş atarak [F] eli başlat", Color("ffd78a"))


func _process(delta: float) -> void:
	_knock_cooldown = maxf(0.0, _knock_cooldown - delta)
	_blackout_cooldown = maxf(0.0, _blackout_cooldown - delta)

	# Update Magnifier inspection mode
	if _magnifier_timer > 0.0:
		_magnifier_timer = maxf(0.0, _magnifier_timer - delta)
		if _magnifier_timer <= 0.0:
			camera.magnifier_active = false
			if not table.glasses_worn:
				for i in [1, 2, 3]:
					seats[i].rack.set_all_xray(false)

	# Update Side Tables Snatch Contest
	if _contest_active:
		_contest_timer -= delta
		if _contest_timer <= 0.0:
			_contest_active = false
			table.set_contested_prop("")
			if _contest_seat_idx >= 0 and _contest_seat_idx < seats.size():
				var actor := seats[_contest_seat_idx]
				table.animate_neighbor_take(_contest_item, _contest_seat_idx, 4.5)
				if actor.buddy:
					actor.buddy.say("Kaparlar böyle işte! Yavaşsın!", 2.8, Color("ffd580"))
	else:
		_contest_clock -= delta
		if _contest_clock <= 0.0:
			_contest_clock = randf_range(18.0, 28.0)
			_trigger_side_table_contest()

	# Update Blackout (Karanlıkta Okey)
	if _blackout_timer > 0.0:
		_blackout_timer = maxf(0.0, _blackout_timer - delta)
		if _blackout_timer <= 0.05:
			room.set_blackout(0.0)
			_lighter_light.visible = false
			if has_node("WorldEnvironment"):
				$WorldEnvironment.environment.ambient_light_energy = 0.28
			hud.flash("💡 Elektrikler geldi!", Color("ffe094"))
			_check_blackout_theft()
		else:
			room.set_blackout(1.0)
			_lighter_light.visible = true
			_lighter_light.light_energy = randf_range(2.0, 2.6)
			if has_node("WorldEnvironment"):
				$WorldEnvironment.environment.ambient_light_energy = 0.02
	else:
		_auto_blackout_clock -= delta
		if _auto_blackout_clock <= 0.0:
			_auto_blackout_clock = randf_range(30.0, 44.0)
			trigger_blackout(true)

	# Update Watcher vision multipliers (smoke, blackout, sunglasses)
	var v_mult := 1.0
	if table.smoke_active_timer > 0.0:
		v_mult *= 0.48
	if _blackout_timer > 0.0:
		v_mult = 0.0 # Pitch black!
	if table.glasses_worn:
		v_mult *= 0.50 # Sunglasses give poker face
	for w in watchers:
		w.vision_multiplier = v_mult
		if is_instance_valid(w.seat) and is_instance_valid(w.seat.rack):
			w.seat.rack.stealable_open = (_blackout_timer > 0.0 or not w.is_watching(seats[0]) or w.vision_multiplier <= 0.35)


	# Track how long local player stays buried in Rack View (opponents may pull a prank!)
	if camera.focused:
		_rack_focus_time += delta
		if _rack_focus_time > 6.5:
			_rack_focus_time = 0.0
			_ai_prank_distracted_player()
	else:
		_rack_focus_time = maxf(0.0, _rack_focus_time - delta * 2.0)

	_update_turn_loop(delta)
	_update_hud()


func _update_turn_loop(delta: float) -> void:
	_turn_timer = maxf(0.0, _turn_timer - delta)
	if turn_seat == 0:
		if _turn_timer <= 0.0:
			# Auto-play if timer expires so match flows smoothly
			if turn_phase == Phase.DRAW:
				_quick_draw_tile()
			var auto_t := seats[0].rack.pop_ai_discard(table.okey_value)
			if auto_t != null:
				table.put_discard(0, auto_t)
				hud.flash("⏳ Süre doldu! Otomatik taş atıldı: %s" % TileFactory.describe(auto_t.value), Color("e0a96d"))
				_advance_turn()
	else:
		var ai_duration := 1.1 if CafePreferences.tile_speed == "HIZLI" else 1.9
		var elapsed := ai_duration - _turn_timer
		if not _ai_step_done and elapsed >= ai_duration * 0.42:
			_ai_step_done = true
			_ai_perform_draw(turn_seat)
		if _turn_timer <= 0.0:
			_ai_perform_discard(turn_seat)
			_advance_turn()


func _ai_perform_draw(seat_idx: int) -> void:
	var s := seats[seat_idx]
	if s.buddy:
		s.buddy.gesture("Reach")
	var drawn := table.pop_draw_tile()
	if drawn != null:
		var free_slot := s.rack.nearest_free(Rack.SLOTS + 7)
		if free_slot >= 0:
			s.rack.put(drawn, free_slot, true)


func _ai_perform_discard(seat_idx: int) -> void:
	var s := seats[seat_idx]
	var discard := s.rack.pop_ai_discard(table.okey_value)
	if discard != null:
		table.put_discard(seat_idx, discard)
		_bonk_sound.global_position = table.to_global(Table.DISCARD_SPOTS[seat_idx])
		_bonk_sound.play()
		if s.buddy and randf() < 0.12:
			var lines := [
				"Al bakalım!",
				"İşine yararsa al!",
				"Hadi devam!",
			]
			s.buddy.say(lines.pick_random(), 1.8, Color("f5dfa6"))


func _advance_turn() -> void:
	if table.draw_count() <= 0:
		hud.flash("Ortada taş bitti! Yeni el dağıtılıyor...", Color("f0c678"))
		_deal()
		return
	turn_seat = (turn_seat + 1) % 4
	if turn_seat == 0:
		turn_phase = Phase.DRAW
		_turn_max = 9.0 if CafePreferences.tile_speed == "HIZLI" else 16.0
		_turn_timer = _turn_max
		var left_top := table.top_discard(3)
		var left_txt := (" veya Rıfkı'nın attığı %s taşını al" % TileFactory.describe(left_top.value)) if left_top else ""
		hud.flash("🎲 Sıra Sende! Ortadan taş çek [D]%s" % left_txt, Color("b9cfa6"))
	else:
		_ai_step_done = false
		_turn_max = 1.1 if CafePreferences.tile_speed == "HIZLI" else 1.9
		_turn_timer = _turn_max


func _ai_prank_distracted_player() -> void:
	if watchers.is_empty():
		return
	var prankster: Watcher = watchers.pick_random()
	var s := prankster.seat
	if s.buddy:
		s.buddy.gesture("Laugh")
		s.buddy.say("Ula ıstakaya gömüldün, uyuma!", 2.5, Color("ffd278"))
	camera.jolt(0.014)
	hud.flash("⚠️ %s masaya vurup dikkatini dağıttı! Masayı kontrol et!" % s.display_name(), Color("e6a15c"))


func _update_hud() -> void:
	hud.show_crosshair(not camera.focused)
	hud.set_hint(hand.hint)
	hud.set_table_state(watchers, camera.focused, _knock_cooldown, hand.exposure, hand.is_stealing(), hand.held != null)

	var is_draw := (turn_seat == 0 and turn_phase == Phase.DRAW)
	var holding_own := (hand.held != null)
	table.set_turn_guides(is_draw, holding_own)

	for w in watchers:
		var can_steal := (not w.is_watching(seats[0])) or w.vision_multiplier <= 0.45
		w.seat.rack.update_opponent_steal_visuals(can_steal, table.glasses_worn or can_steal, w.seat.display_name(), w.attention_text())

	var turn_txt := ""
	if turn_seat == 0:
		if turn_phase == Phase.DRAW:
			turn_txt = "▶ SIRA SENDE: Ortadan Çek [D] veya Yandan Al"
		else:
			turn_txt = "▶ SIRA SENDE: Istakandan Sağa Taş At [F]"
	else:
		turn_txt = "⏳ Sıra: %s oynuyor..." % seats[turn_seat].display_name()

	var okey_txt := "Gösterge: %s   ·   Okey: %s   ·   Ortada: %d" % [
		TileFactory.describe(table.indicator_value),
		TileFactory.describe(table.okey_value),
		table.draw_count(),
	]
	var eval := seats[0].rack.evaluate_hand(table.okey_value)
	var stats_txt := "Per: %d  ·  Boşta: %d taş  ·  Çalınan: %d  ·  El Zaferi: %d" % [
		eval["sets"], eval["unmatched"], stolen, rounds_won
	]
	var mode_txt := "⚡ KARANLIK" if _blackout_timer > 0.0 else ("🕶️ GÖZLÜK" if table.glasses_worn else CafePreferences.tile_speed)
	hud.update_match_hud(turn_txt, _turn_timer / maxf(0.1, _turn_max), okey_txt, stats_txt, mode_txt, table.glasses_worn)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_Q:
		knock_table()
	elif event.keycode == KEY_S:
		_sort_rack()
	elif event.keycode == KEY_D and not camera.focused:
		# Note: In Masa view, D leans right while held, so only quick-draw if focused OR via HUD/click,
		# or if Shift+D / R is pressed; let's bind both R and focused-D to quick draw!
		pass
	if event.keycode == KEY_D and camera.focused:
		_quick_draw_tile()
	elif event.keycode == KEY_R:
		_quick_draw_tile()
	elif event.keycode == KEY_K:
		trigger_blackout(false)
	elif event.keycode == KEY_G:
		_try_finish_hand()


func _on_hud_action(action_id: String) -> void:
	match action_id:
		"focus":
			camera.set_focused(not camera.focused)
		"draw":
			_quick_draw_tile()
		"sort":
			_sort_rack()
		"knock":
			knock_table()
		"blackout":
			trigger_blackout(false)
		"finish":
			_try_finish_hand()


func _quick_draw_tile() -> void:
	if hand.held != null:
		hud.flash("Önce elindeki taşı ıstakaya bırak!", Color("d8bb85"))
		return
	var free_slot := seats[0].rack.nearest_free(Rack.SLOTS + 7)
	if free_slot < 0:
		hud.flash("Istakan tamamen dolu!", Color("d8bb85"))
		return
	var tile := table.pop_draw_tile()
	if tile == null:
		hud.flash("Ortada çekilecek taş kalmadı!", Color("d8bb85"))
		return
	seats[0].rack.put(tile, free_slot, true)
	_on_tile_drawn(tile, false)


func _sort_rack() -> void:
	if hand.held != null:
		hud.flash("Önce elindeki taşı bırak", Color("d8bb85"))
		return
	_sort_by_number = not _sort_by_number
	seats[0].rack.sort_tiles(_sort_by_number)
	var eval := seats[0].rack.evaluate_hand(table.okey_value)
	hud.flash("%s (%d Per hazır, %d taş boşta)" % [
		"Sayı / Grup sırası" if _sort_by_number else "Renk / Seri sırası",
		eval["sets"], eval["unmatched"]
	], Color("b9cfa6"))


func _on_tile_drawn(tile: Tile, from_discard: bool) -> void:
	var src := "Yandan alındı" if from_discard else "Ortadan çekildi"
	var is_okey := (tile.value == table.okey_value)
	hud.flash("%s: %s%s — Şimdi sağa 1 taş at [F]" % [
		src, TileFactory.describe(tile.value), " (★ OKEY GELDİ!)" if is_okey else ""
	], Color("ffd78a") if is_okey else Color("b9cfa6"))
	if turn_seat == 0 and turn_phase == Phase.DRAW:
		turn_phase = Phase.DISCARD
		_turn_timer = _turn_max


func _on_tile_discarded(tile: Tile) -> void:
	hud.flash("Taş atıldı: %s" % TileFactory.describe(tile.value), Color("d6ceb8"))
	if turn_seat == 0:
		_advance_turn()


func _on_finish_declared(_tile: Tile) -> void:
	_try_finish_hand()


func _try_finish_hand() -> void:
	var eval := seats[0].rack.evaluate_hand(table.okey_value)
	if eval["unmatched"] <= 2 or stolen >= 2:
		rounds_won += 1
		camera.jolt(0.022)
		for w in watchers:
			w.seat.buddy.gesture("No")
			w.seat.buddy.say("Vay arkadaş adam Okey açtı!", 3.2, Color("ffd78a"))
		hud.flash("🏆 OKEY! ELİ KAZANDIN! (Zafer: %d) — Yeni el dağıtılıyor..." % rounds_won, Color("ffd75e"))
		await get_tree().create_timer(2.6).timeout
		_deal()
	else:
		hud.flash("El açmak için taşların henüz tam per değil! (%d Per var, %d taş boşta — taş çal veya diz!)" % [
			eval["sets"], eval["unmatched"]
		], Color("e69d67"))


func _on_prop_used(prop_id: String, alt_action: bool) -> void:
	if _contest_active and prop_id == _contest_item:
		_contest_active = false
		table.set_contested_prop("")
		if _contest_seat_idx >= 0 and _contest_seat_idx < seats.size():
			var actor := seats[_contest_seat_idx]
			if actor.buddy:
				actor.buddy.gesture("Hit")
				actor.buddy.say("Vay anasını, ne el çabukluğu be!", 2.6, Color("ffe0b0"))
			hud.flash("⚡ ELİ ÇABUK! %s'den önce davranıp eşyayı kaptın!" % actor.display_name(), Color("ffaa22"))

	match prop_id:
		"tea_0":
			if alt_action:
				_spill_opponent_tea("tea_1")
			else:
				table.animate_drink("tea_0", camera.global_position)
				_sip_sound.global_position = camera.global_position
				_sip_sound.play()
				hand.exposure = 0.0
				hud.flash("🍵 Sıcak demli çaydan bir yudum aldın · Şüphe sıfırlandı!", Color("d4e6b5"))
		"tea_1", "tea_2", "tea_3":
			_spill_opponent_tea(prop_id)
		"coffee":
			if alt_action:
				var victim: Watcher = watchers.pick_random()
				victim.spill_distract(4.5)
				camera.jolt(0.015)
				hud.flash("☕ Kahve telvesini %s'in önüne sıçrattın! (4.5 sn kör oldu)" % victim.seat.display_name(), Color("f0b46e"))
			else:
				table.animate_drink("coffee", camera.global_position)
				_sip_sound.global_position = camera.global_position
				_sip_sound.play()
				hand.coffee_boost_timer = 12.0
				hud.flash("☕ Közde Türk Kahvesi içildi! 12 sn Hızlı El & Odak!", Color("f2ce85"))
		"leblebi":
			var target_w := _pick_target_watcher()
			if target_w != null:
				var head_pos := target_w.seat.head_anchor.global_position + Vector3(0, -0.05, 0)
				hud.flash("🥜 %s'in kafasına leblebi fırlattın!" % target_w.seat.display_name(), Color("f0c878"))
				table.launch_leblebi(head_pos, func() -> void:
					_bonk_sound.global_position = head_pos
					_bonk_sound.play()
					camera.jolt(0.010)
					target_w.hit_by_leblebi()
				)
		"ashtray":
			table.puff_smoke()
			hud.flash("💨 Masaya yoğun duman üfledin! 6.5 sn rakiplerin görüşü yarıya düştü!", Color("c9d4dc"))
			for w in watchers:
				if randf() < 0.5:
					w.seat.buddy.say("Öhö öhö! Duman altı ettin masayı!", 2.5, Color("d8dfe6"))
		"tespih":
			table.spin_tespih()
			_bonk_sound.global_position = seats[0].global_position
			_bonk_sound.play()
			if not watchers.is_empty():
				var w: Watcher = watchers.pick_random()
				w.distract(table.to_global(Vector3(-0.41, Table.TOP, 0.64)), 2.8)
			hud.flash("📿 Ateş kehribar tesbihi şaklattın · Rakipler eline baktı!", Color("f0b878"))
		"glasses":
			var on := table.toggle_glasses()
			for i in [1, 2, 3]:
				seats[i].rack.set_all_xray(on, table.okey_value)
			if on:
				hud.flash("🕶️ Kabadayı Gözlüğü takıldı! X-Ray aktif: Rakiplerin taşları görünüyor, Okey parlıyor!", Color("ffd78a"))
			else:
				hud.flash("🕶️ Kabadayı Gözlüğü masaya bırakıldı", Color("d8ceb8"))
		"magnifier":
			table.animate_magnifier(camera.global_position, 4.5)
			camera.magnifier_active = true
			_magnifier_timer = 4.5
			var w := _pick_target_watcher()
			if w != null:
				w.seat.rack.set_all_xray(true, table.okey_value)
				var r_tiles := w.seat.rack.get_tiles()
				var names: Array[String] = []
				for t in r_tiles.slice(0, 4):
					names.append(TileFactory.describe(t.value))
				hud.flash("🔍 Büyüteç [%s]: %s ... | İstediğin taşı tıkla ve çal!" % [
					w.seat.display_name(), ", ".join(names)
				], Color("a8e0dc"))
			else:
				hud.flash("🔍 Büyüteç elinde! Bir rakibin ıstakasına bakıp taşı çal", Color("a8e0dc"))
		"yazboz", "indicator_info":
			var eval := seats[0].rack.evaluate_hand(table.okey_value)
			hud.flash("📋 Yazboz: Gösterge %s → Okey %s  |  Elinde %d Per var, %d taş boşta" % [
				TileFactory.describe(table.indicator_value),
				TileFactory.describe(table.okey_value),
				eval["sets"], eval["unmatched"]
			], Color("f2d8a8"))


func _spill_opponent_tea(prop_id: String) -> void:
	var seat_idx := table.spill_tea(prop_id)
	if seat_idx >= 1 and seat_idx <= 3:
		camera.jolt(0.018)
		_bonk_sound.global_position = table.global_position
		_bonk_sound.play()
		var victim := watchers[seat_idx - 1]
		victim.spill_distract(5.4)
		hud.flash("🫗 %s'in çayını masaya devirdin! Çayı silerken taşlarını çal!" % victim.seat.display_name(), Color("ff9e6e"))


func _pick_target_watcher() -> Watcher:
	if watchers.is_empty():
		return null
	var cam_fwd := -camera.global_transform.basis.z
	var best: Watcher = watchers[0]
	var best_dot := -2.0
	for w in watchers:
		var dir := (w.seat.head_anchor.global_position - camera.global_position).normalized()
		var d := cam_fwd.dot(dir)
		if d > best_dot:
			best_dot = d
			best = w
	return best


func trigger_blackout(auto_triggered := false) -> void:
	if _blackout_timer > 0.0:
		return
	if not auto_triggered and _blackout_cooldown > 0.0:
		hud.flash("Şalter soğuyor (%.0f sn)" % _blackout_cooldown, Color("d8bb85"))
		return
	_blackout_cooldown = 18.0
	_blackout_timer = 5.5
	camera.jolt(0.014)
	_knock_sound.global_position = Vector3(0, 1.85, 0)
	_knock_sound.play()
	for w in watchers:
		if randf() < 0.7:
			w.seat.buddy.say("Ula elektrikler gitti! Taşlara mukayyet olun!", 3.2, Color("ffd978"))
	hud.flash("⚡ KARANLIKTA OKEY! 5.5 sn elektrikler kesildi — Karanlıkta taş çal!", Color("ffd966"))


func _on_banter_spoken(phrase: String) -> void:
	if watchers.is_empty():
		return
	var responder: Watcher = watchers.pick_random()
	var replies := {
		"Helal!": ["Eyvallah yeğenim!", "Bizde yanlış olmaz!", "Sağ olasın aslanım!"],
		"Yok artık!": ["Ne sandın ya!", "Okey bizim işimiz!", "Ağzın açık kalır öyle!"],
		"Nasıl ya?": ["Bilek işi bu bilek!", "Şans değil tecrübe!", "Taşlar beni seviyor!"],
		"Dayı sakin": ["Sakinim ula ben!", "Tansiyonumu çıkarma benim!", "Çay verin bana sakinleşeyim!"],
		"Çay koy!": ["Çaycı! Masaya dört demli çek!", "Taze kan gelsin masaya!", "Demli olsun usta!"],
		"Taş ver!": ["İşine bak yeğenim taş maş yok!", "Bekle sıran gelince atarız!", "Benden sana anca üçlü çıkar!"],
	}
	var pool: Array = replies.get(phrase, ["Okey değil muhabbet kazanır!"])
	await get_tree().create_timer(0.45).timeout
	if is_instance_valid(responder) and responder.seat.buddy:
		responder.seat.buddy.gesture("Laugh")
		responder.seat.buddy.say(pool.pick_random(), 2.6, Color("ffe8b8"))


func knock_table() -> bool:
	if hand.held != null:
		hud.flash("Önce elindeki taşı bırak", Color("d8bb85"))
		return false
	if _knock_cooldown > 0.0:
		hud.flash("Masaya vurmak için %.0f sn bekle" % _knock_cooldown, Color("d8bb85"))
		return false
	_knock_cooldown = KNOCK_COOLDOWN
	seats[0].knock_table()
	camera.jolt(0.038)
	_knock_sound.global_position = seats[0].to_global(Vector3(-0.30, Table.TOP + 0.03, 0.73))
	_knock_sound.play()

	# Pick an opponent with tiles to physically dislodge 1 tile onto the felt!
	var targets: Array[Watcher] = []
	for w in watchers:
		if is_instance_valid(w.seat) and is_instance_valid(w.seat.rack) and w.seat.rack.get_tiles().size() > 0:
			targets.append(w)
	if targets.is_empty():
		hud.flash("👊 Masaya vurdun! Rakipler sese döndü", Color("e5c48a"))
		return true

	var victim_w: Watcher = targets.pick_random()
	var victim_seat := victim_w.seat
	var dislodged_tile: Tile = victim_seat.rack.dislodge_random_tile(table)

	if dislodged_tile != null:
		victim_w.distract(_knock_sound.global_position, 4.0)
		if victim_seat.buddy:
			victim_seat.buddy.gesture("Hit")
			var lines := [
				"Ula masayı devirdin, taşım düştü!",
				"Yavaş be kardeşim, masayı kırdın taşım yuvarlandı!",
				"Ne vuruyorsun ula masaya, ödüm koptu!"
			]
			victim_seat.buddy.say(lines.pick_random(), 3.2, Color("ff9966"))
		hud.flash("👊 Masaya sert vurdun! %s'in taşı masaya yuvarlandı — HEMEN KAP!" % victim_seat.display_name(), Color("ffcc00"))

		# Victim attempts to retrieve it after 4.5 seconds if player doesn't snatch it
		get_tree().create_timer(4.5).timeout.connect(func():
			if is_instance_valid(dislodged_tile) and dislodged_tile.is_fallen:
				if is_instance_valid(victim_seat) and is_instance_valid(victim_seat.rack):
					victim_seat.rack.put_back_fallen(dislodged_tile)
					if victim_seat.buddy:
						victim_seat.buddy.say("Hah, taşımı aldım yerden!", 2.2, Color("d8ceb8"))
		)
	return true


func _on_tile_snatched(tile: Tile, from_rack: Node) -> void:
	stolen += 1
	hud.set_score(stolen, caught)
	camera.jolt(0.012)
	hud.flash("🖐️ Düşen taşı kaptın ve ıstakana gizledin: %s!" % TileFactory.describe(tile.value), Color("44ff88"))
	for w in watchers:
		if is_instance_valid(w.seat) and w.seat.rack == from_rack:
			if w.seat.buddy:
				w.seat.buddy.gesture("No")
				w.seat.buddy.say("Lan taşımı kaptı hırsız!", 2.8, Color("ff5544"))
			w.attention = 1.0
			break


func _check_blackout_theft() -> void:
	for w in watchers:
		if is_instance_valid(w.seat) and is_instance_valid(w.seat.rack):
			if w.seat.rack.get_tiles().size() < 14:
				if w.seat.buddy:
					w.seat.buddy.gesture("Hit")
					var lines := [
						"Lan elektrikler gidince kim yürüttü taşımı?!",
						"Ula göz gözü görmezken taşımı çalmışlar!",
						"Benim taş eksik ula! Masada hırsız var!"
					]
					w.seat.buddy.say(lines.pick_random(), 3.4, Color("ff5544"))
				w.attention = 1.0
				hud.flash("🚨 %s elektrikler kesilince taşının çalındığını fark etti!" % w.seat.display_name(), Color("ff6655"))


func _trigger_side_table_contest() -> void:
	if _contest_active or watchers.is_empty():
		return
	var choose_right := randf() < 0.5
	var actor := seats[1] if choose_right else seats[3] # Temel (right) or Rıfkı (left)
	var item_id := ("glasses" if randf() < 0.5 else "coffee") if choose_right else ("magnifier" if randf() < 0.5 else "tespih")
	var item_names := {
		"glasses": "Güneş Gözlüğü",
		"coffee": "Türk Kahvesi",
		"magnifier": "Büyüteç",
		"tespih": "Kehribar Tesbih",
	}
	var iname: String = item_names.get(item_id, "Eşya")

	_contest_active = true
	_contest_item = item_id
	_contest_seat_idx = 1 if choose_right else 3
	_contest_timer = 3.2
	table.set_contested_prop(item_id)

	if actor.buddy:
		actor.buddy.gesture("Reach")
		var lines := [
			"Ula ver bakayım şu %s'i!",
			"Hop, şu %s bana lazım!",
			"Şu %s'e bi el atayım!",
		]
		actor.buddy.say(lines.pick_random() % iname, 2.8, Color("ffd580"))

	hud.flash("⚡ DİKKAT: %s %s'a uzanıyor! ÖNCE SEN KAP! (3 sn)" % [actor.display_name(), iname], Color("ff7733"))



func _setup_sounds() -> void:
	# 1. Table Knock Sound
	var bytes := PackedByteArray()
	bytes.resize(4400 * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 71
	for i in 4400:
		var t := i / 22050.0
		var wave := (sin(TAU * 160 * t) * 0.65 + sin(TAU * 390 * t) * 0.18 + noise.randf_range(-0.12, 0.12)) * exp(-60 * t)
		if t > 0.065:
			var u := t - 0.065
			wave += (sin(TAU * 175 * u) * 0.55 + sin(TAU * 420 * u) * 0.15) * exp(-65 * u)
		bytes.encode_s16(i * 2, clampi(int(wave * 22000), -32768, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = bytes
	_knock_sound.stream = stream
	_knock_sound.volume_db = -5
	_knock_sound.max_distance = 8.0
	add_child(_knock_sound)

	# 2. Tea / Coffee Sip Sound
	var sip_bytes := PackedByteArray()
	sip_bytes.resize(5500 * 2)
	for i in 5500:
		var t := i / 22050.0
		var env := sin(clampf(t / 0.25, 0.0, 1.0) * PI)
		var s_wave := (noise.randf_range(-0.35, 0.35) + sin(TAU * (320.0 + t * 480.0) * t) * 0.25) * env
		sip_bytes.encode_s16(i * 2, clampi(int(s_wave * 16000), -32768, 32767))
	var sip_stream := AudioStreamWAV.new()
	sip_stream.format = AudioStreamWAV.FORMAT_16_BITS
	sip_stream.mix_rate = 22050
	sip_stream.data = sip_bytes
	_sip_sound.stream = sip_stream
	_sip_sound.volume_db = -8
	add_child(_sip_sound)

	# 3. Realistic Okey Tile Clack Sound
	var bonk_bytes := PackedByteArray()
	bonk_bytes.resize(4410 * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 93
	for i in 4410:
		var t := i / 44100.0
		var click := rng.randf_range(-0.8, 0.8) * exp(-550.0 * t)
		var ring := (sin(TAU * 1850.0 * t) * 0.45 + sin(TAU * 2950.0 * t) * 0.25) * exp(-190.0 * t)
		var wood := sin(TAU * 420.0 * t) * 0.35 * exp(-120.0 * t)
		var v := tanh((click + ring + wood) * 1.5)
		bonk_bytes.encode_s16(i * 2, clampi(int(v * 26000.0), -32768, 32767))
	var bonk_stream := AudioStreamWAV.new()
	bonk_stream.format = AudioStreamWAV.FORMAT_16_BITS
	bonk_stream.mix_rate = 44100
	bonk_stream.data = bonk_bytes
	_bonk_sound.stream = bonk_stream
	_bonk_sound.volume_db = -6
	add_child(_bonk_sound)


func _on_stole() -> void:
	stolen += 1
	hud.set_score(stolen, caught)
	hud.flash("🖐️ Taşı arakladın! Kimse çakmadı (%d çalınan)" % stolen, Color("bbc6a3"))


func _on_caught(by: Watcher) -> void:
	caught += 1
	camera.jolt(0.022)
	hud.set_score(stolen, caught)
	hud.flash("🚨 %s seni taş çalarken yakaladı! Taş geri döndü!" % by.seat.display_name(), Color("e67e62"))


func _deal() -> void:
	var deck: Array[Vector2i] = []
	for copy in 2:
		for color in COLOR_COUNT:
			for number in range(1, 14):
				deck.append(Vector2i(color, number))
		deck.append(Vector2i(TileFactory.FAKE_OKEY, 0))
	deck.shuffle()

	# Pick a non-Fake-Okey tile as the Indicator (Gösterge)
	var indicator := Vector2i(0, 7)
	for i in range(deck.size() - 1, -1, -1):
		if deck[i].x != TileFactory.FAKE_OKEY:
			indicator = deck[i]
			deck.remove_at(i)
			break

	for i in seats.size():
		var hand_tiles := deck.slice(0, 15 if i == 0 else 14)
		deck = deck.slice(hand_tiles.size())
		hand_tiles.sort()
		seats[i].rack.set_tiles(hand_tiles)

	table.show_pile(deck, indicator)
	turn_seat = 0
	turn_phase = Phase.DISCARD
	_turn_timer = _turn_max


func _capture(args: Dictionary) -> void:
	var path: String = args["screenshot"]
	camera.mouse_control = false
	camera.set_focused(args.has("focus"), true)
	camera.look(float(args.get("yaw", "0")), float(args.get("pitch", "-0.28")))
	hand.aim_override = get_viewport().get_visible_rect().size * Vector2(0.55, 0.42)
	if args.has("hold"):
		hand.grab(get_tree().get_nodes_in_group("tiles").filter(func(t: Tile) -> bool: return t.holder == seats[0].rack)[0])
	if args.has("caught"):
		_on_caught(watchers[0])
	if args.has("chaos"):
		_spill_opponent_tea("tea_2")
		_ai_perform_discard(1)
		_ai_perform_discard(3)
	if args.has("knock"):
		knock_table()
	if args.has("glasses"):
		_on_prop_used("glasses", false)
	if args.has("blackout"):
		trigger_blackout(true)
	if args.has("contest"):
		_trigger_side_table_contest()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Screenshot saved: ", path)
	get_tree().quit()


func _user_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		out[parts[0]] = parts[1] if parts.size() > 1 else ""
	return out
