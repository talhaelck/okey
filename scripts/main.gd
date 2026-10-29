extends Node3D
## Main 3D Kaotik Okey controller: 106-tile Okey rules, 4-player turn loop,
## tile interactions and tea spills that temporarily open an opponent rack.

const COLOR_COUNT := 4
enum Phase { DRAW, DISCARD }

var hand := Hand.new()
var hud := Hud.new()
var watchers: Array[Watcher] = []
var stolen := 0
var caught := 0
var rounds_won := 0
var player_room_seat := 0

var _sort_by_number := false


var turn_seat := 0
var turn_phase := Phase.DISCARD
var _turn_timer := 16.0
var _turn_max := 16.0
var _ai_step_done := false

var _bonk_sound := AudioStreamPlayer3D.new()

@onready var room: Node3D = $Room
@onready var camera: FocusCamera = $FocusCamera
@onready var table: Table = $Table
@onready var seats: Array[Seat] = [$Seats/Seat0, $Seats/Seat1, $Seats/Seat2, $Seats/Seat3]


func _ready() -> void:
	CafePreferences.restore()
	var chosen: String = CafePreferences.companion if CafePreferences.companion in CafePatron.KINDS or CafePreferences.companion in RiggedPatron.KINDS else "sabri"
	seats[0].set_character(chosen)
	var opp_kinds := CafePreferences.patron_lineup(chosen)
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

	hud.camera = camera
	add_child(hud)
	hud.banter_spoken.connect(_on_banter_spoken)
	hud.action_requested.connect(_on_hud_action)

	_setup_sounds()

	var args := _user_args()
	if not get_parent().has_method("_home"):
		randomize_player_place()
	if args.has("screenshot") and not get_parent().has_method("_home"):
		_capture(args)
	else:
		camera.set_focused(false, true)
		hud.flash("Masa Hazır! 15 taşın var — sağa 1 taş atarak [F] eli başlat", Color("ffd78a"))

func randomize_player_place() -> void:
	player_room_seat = CafePreferences.next_player_place()
	# Change the physical seat relative to the room. Keep the table's logical
	# coordinate frame stable for turn ownership, hidden tiles and hand targets.
	room.rotation.y = -player_room_seat * PI * .5
	camera.look(0,-.26)


func _process(delta: float) -> void:
	for w in watchers:
		w.vision_multiplier = 1.0
		if is_instance_valid(w.seat) and is_instance_valid(w.seat.rack):
			w.seat.rack.stealable_open = not w.is_watching(seats[0])
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


func _update_hud() -> void:
	hud.show_crosshair(not camera.focused)
	hud.set_hint(hand.hint)
	hud.set_table_state(watchers, camera.focused, 0.0, hand.exposure, hand.is_stealing(), hand.held != null)

	var is_draw := (turn_seat == 0 and turn_phase == Phase.DRAW)
	var holding_own := (hand.held != null)
	table.set_turn_guides(is_draw, holding_own)

	for w in watchers:
		var can_steal := (not w.is_watching(seats[0])) or w.vision_multiplier <= 0.45
		w.seat.rack.update_opponent_steal_visuals(can_steal, can_steal, w.seat.display_name(), w.attention_text())

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
	var mode_txt := CafePreferences.tile_speed
	hud.update_match_hud(turn_txt, _turn_timer / maxf(0.1, _turn_max), okey_txt, stats_txt, mode_txt, false)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_S:
		_sort_rack()
	elif event.keycode == KEY_D and not camera.focused:
		# Note: In Masa view, D leans right while held, so only quick-draw if focused OR via HUD/click,
		# or if Shift+D / R is pressed; let's bind both R and focused-D to quick draw!
		pass
	if event.keycode == KEY_D and camera.focused:
		_quick_draw_tile()
	elif event.keycode == KEY_R:
		_quick_draw_tile()
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


func _on_prop_used(prop_id: String, _alt_action: bool) -> void:
	if prop_id in ["tea_1", "tea_2", "tea_3"]:
		_spill_opponent_tea(prop_id)

func _spill_opponent_tea(prop_id: String) -> void:
	var seat_idx := table.spill_tea(prop_id)
	if seat_idx >= 1 and seat_idx <= 3:
		camera.jolt(0.018)
		_bonk_sound.global_position = table.global_position
		_bonk_sound.play()
		var victim := watchers[seat_idx - 1]
		victim.spill_distract(5.4)
		hud.flash("🫗 %s'in çayını masaya devirdin! Çayı silerken taşlarını çal!" % victim.seat.display_name(), Color("ff9e6e"))


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


func _setup_sounds() -> void:
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
