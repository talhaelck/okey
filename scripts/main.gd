extends Node3D
## Prototype entry point: deals a shuffled okey set, wires the local camera, hand, opponents and HUD.
## Debug: `godot --path . -- --screenshot=<file.png> [--focus] [--yaw=<rad>] [--pitch=<rad>] [--hold] [--caught]`
## renders one frame and quits (--hold puts a tile from your rack in the glove first).

const COLOR_COUNT := 4

var hand := Hand.new()
var hud := Hud.new()
var watchers: Array[Watcher] = []
var stolen := 0
var caught := 0
const KNOCK_COOLDOWN := 8.0
var _knock_cooldown := 0.0
var _sort_by_number := false
var _knock_sound := AudioStreamPlayer3D.new()

@onready var camera: FocusCamera = $FocusCamera
@onready var table: Table = $Table
@onready var seats: Array[Seat] = [$Seats/Seat0, $Seats/Seat1, $Seats/Seat2, $Seats/Seat3]


func _ready() -> void:
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
	hud.camera = camera
	add_child(hud)
	_setup_knock_sound()

	var args := _user_args()
	if args.has("screenshot") and not get_parent().has_method("_home"):
		_capture(args)
	else:
		camera.set_focused(false, true)


func _process(delta: float) -> void:
	_knock_cooldown = maxf(0.0,_knock_cooldown-delta)
	hud.show_crosshair(not camera.focused)
	hud.set_hint(hand.hint)
	hud.set_table_state(watchers,camera.focused,_knock_cooldown,hand.exposure,hand.is_stealing(),hand.held != null)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not camera.focused and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.keycode == KEY_Q:
		knock_table()
	elif event.keycode == KEY_S:
		if hand.held != null:
			hud.flash("Önce elindeki taşı bırak",Color("d8bb85"))
		elif not camera.focused:
			hud.flash("Önce ıstakana odaklan",Color("d8bb85"))
		else:
			_sort_by_number = not _sort_by_number
			seats[0].rack.sort_tiles(_sort_by_number)
			hud.flash("Sayı sırası" if _sort_by_number else "Renk sırası",Color("b9cfa6"))


func knock_table() -> bool:
	if camera.focused:
		hud.flash("Önce masaya bak",Color("d8bb85"))
		return false
	if hand.held != null:
		hud.flash("Önce elindeki taşı bırak",Color("d8bb85"))
		return false
	if _knock_cooldown > 0.0:
		return false
	_knock_cooldown = KNOCK_COOLDOWN
	seats[0].knock_table()
	_knock_sound.global_position = seats[0].to_global(Vector3(-0.30,Table.TOP+0.03,0.73))
	_knock_sound.play()
	var candidates := watchers.duplicate()
	candidates.shuffle()
	for i in mini(2,candidates.size()):
		(candidates[i] as Watcher).distract(_knock_sound.global_position,1.8+i*0.25)
	return true


func _setup_knock_sound() -> void:
	var bytes := PackedByteArray()
	bytes.resize(4400*2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 71
	for i in 4400:
		var t := i/22050.0
		var wave := (sin(TAU*160*t)*0.65+sin(TAU*390*t)*0.18+noise.randf_range(-0.12,0.12))*exp(-60*t)
		if t > 0.065:
			var u := t-0.065
			wave += (sin(TAU*175*u)*0.55+sin(TAU*420*u)*0.15)*exp(-65*u)
		bytes.encode_s16(i*2,clampi(int(wave*22000),-32768,32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = bytes
	_knock_sound.stream = stream
	_knock_sound.volume_db = -5
	_knock_sound.max_distance = 8.0
	add_child(_knock_sound)


func _on_stole() -> void:
	stolen += 1
	hud.set_score(stolen, caught)
	hud.flash("Taş sende", Color("bbc6a3"))


func _on_caught(_by: Watcher) -> void:
	caught += 1
	hud.set_score(stolen, caught)
	hud.flash("Yakalandın", Color("d19375"))


func _deal() -> void:
	var deck: Array[Vector2i] = []
	for copy in 2:
		for color in COLOR_COUNT:
			for number in range(1, 14):
				deck.append(Vector2i(color, number))
		deck.append(Vector2i(TileFactory.FAKE_OKEY, 0))
	deck.shuffle()
	for i in seats.size():
		var hand_tiles := deck.slice(0, 15 if i == 0 else 14)
		deck = deck.slice(hand_tiles.size())
		hand_tiles.sort()
		seats[i].rack.set_tiles(hand_tiles)
	var indicator: Vector2i = deck.pop_back()
	table.show_pile(deck, indicator)


func _capture(args: Dictionary) -> void:
	var path: String = args["screenshot"]
	camera.mouse_control = false
	camera.set_focused(args.has("focus"), true)
	camera.look(float(args.get("yaw", "0")), float(args.get("pitch", "-0.15")))
	hand.aim_override = get_viewport().get_visible_rect().size * Vector2(0.55, 0.42)
	if args.has("hold"):
		hand.grab(get_tree().get_nodes_in_group("tiles").filter(func(t: Tile) -> bool: return t.holder == seats[0].rack)[0])
	if args.has("caught"):
		_on_caught(watchers[0])
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
