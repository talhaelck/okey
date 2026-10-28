extends Node3D
## Prototype entry point: deals a shuffled okey set, wires the local camera, hand, opponents and HUD.
## Debug: `godot --path . -- --screenshot=<file.png> [--focus] [--yaw=<rad>] [--pitch=<rad>] [--hold] [--caught]`
## renders one frame and quits (--hold puts a tile from your rack in the glove first).

const COLOR_COUNT := 4

var hand := Hand.new()
var hud := Hud.new()
var post_fx := PostFx.new()
var watchers: Array[Watcher] = []
var stolen := 0
var caught := 0

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
	add_child(post_fx)
	add_child(hud)

	var args := _user_args()
	if args.has("screenshot"):
		_capture(args)
	else:
		camera.set_focused(false, true)


func _process(_delta: float) -> void:
	hud.show_crosshair(not camera.focused)
	hud.set_hint(hand.hint)


func _on_stole() -> void:
	stolen += 1
	hud.set_score(stolen, caught)
	hud.flash("Çaktırmadan aldın!", Color(0.45, 1.0, 0.5))


func _on_caught(_by: Watcher) -> void:
	caught += 1
	hud.set_score(stolen, caught)
	hud.flash("YAKALANDIN!", Color(1.0, 0.3, 0.25))


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
	camera.look(float(args.get("yaw", "0")), float(args.get("pitch", "-0.5")))
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
