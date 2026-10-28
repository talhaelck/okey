extends Node3D
## Prototype entry point: deals a shuffled okey set to the four seats and drives the local camera.
## Debug: `godot --path . -- --screenshot=<file.png> [--focus]` renders one frame and quits.

const COLOR_COUNT := 4

@onready var camera: FocusCamera = $FocusCamera
@onready var table: Table = $Table
@onready var seats: Array[Seat] = [$Seats/Seat0, $Seats/Seat1, $Seats/Seat2, $Seats/Seat3]


func _ready() -> void:
	_deal()
	camera.attach_to_seat(seats[0])
	var args := _user_args()
	if args.has("screenshot"):
		_capture(args["screenshot"], args.has("focus"))
	else:
		camera.set_focused(false, true)


func _deal() -> void:
	var deck: Array[Vector2i] = []
	for copy in 2:
		for color in COLOR_COUNT:
			for number in range(1, 14):
				deck.append(Vector2i(color, number))
		deck.append(Vector2i(TileFactory.FAKE_OKEY, 0))
	deck.shuffle()
	for i in seats.size():
		var hand := deck.slice(0, 15 if i == 0 else 14)
		deck = deck.slice(hand.size())
		hand.sort()
		seats[i].rack.set_tiles(hand)
	var indicator: Vector2i = deck.pop_back()
	table.show_pile(deck, indicator)


func _capture(path: String, focused: bool) -> void:
	camera.mouse_control = false
	camera.set_focused(focused, true)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	for i in 20:
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
