extends SceneTree
## Focused gameplay checks; no rendering benchmark or external assets.
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	game.get_node("FocusCamera").mouse_control = false
	root.add_child(game)
	game.hand.set_process(false)
	game.set_process(false)
	for w in game.watchers:
		w.set_process(false)
		w._state = Watcher.State.RACK
	var all_tiles := get_nodes_in_group("tiles")
	var local: Seat = game.seats[0]
	var own_ids: Array[int] = []
	for tile: Tile in all_tiles:
		if tile.holder == local.rack:
			own_ids.append(tile.get_instance_id())
	for mode in [true,false]:
		local.rack.sort_tiles(mode)
		var sorted_ids: Array[int] = []
		for tile: Tile in local.rack._slots:
			if tile != null:
				sorted_ids.append(tile.get_instance_id())
				check(tile.holder == local.rack,"Sort changed tile ownership")
		sorted_ids.sort()
		own_ids.sort()
		check(sorted_ids == own_ids,"Sort lost or duplicated a tile")
	game.camera.set_focused(false,true)
	check(game.knock_table(),"The ready knock did not start")
	var distracted := 0
	for w in game.watchers:
		if w._state == Watcher.State.DISTRACTED:
			distracted += 1
	check(distracted == 2,"Knock must distract exactly two opponents")
	check(not game.knock_table(),"Cooldown allowed a second immediate knock")
	for w in game.watchers:
		w._process(3.0)
		check(w._state != Watcher.State.DISTRACTED,"Distraction never ended")
	game.camera.set_focused(true,true)
	game._knock_cooldown = 0.0
	check(not game.knock_table(),"Rack focus should block table knocking")
	game.camera.set_focused(false,true)
	var victim: Seat = game.seats[1]
	var stolen: Tile = all_tiles.filter(func(t: Tile) -> bool: return t.holder == victim.rack)[0]
	var value := stolen.value
	game.hand.grab(stolen)
	check(not game.knock_table(),"A held tile should block knocking")
	stolen.global_position = local.rack.global_position + Vector3(0,0.12,0.15)
	for w in game.watchers:
		w._state = Watcher.State.RACK
	var witness: Watcher = game.watchers[0]
	witness._state = Watcher.State.LOOK
	witness.target = local
	check(witness.can_see(stolen.global_position,local),"The visible tile was outside the witness cone")
	game.hand._check_caught(0.10)
	check(game.hand.held == stolen and game.hand.exposure > 0.0,"The new reaction window caught instantly")
	witness._state = Watcher.State.RACK
	game.hand._check_caught(0.10)
	check(game.hand.exposure == 0.0,"Exposure did not decay outside an opponent's view")
	witness._state = Watcher.State.LOOK
	game.hand._check_caught(0.60)
	check(game.hand.held == null and stolen.holder == victim.rack,"Being caught failed to return the original tile")
	check(game.caught == 1 and game.stolen == 0,"Being caught changed the wrong score")
	check(stolen.value == value,"Being caught changed a tile's value")
	witness._state = Watcher.State.RACK
	game.hand.grab(stolen)
	game.hand._drop = {"rack":local.rack,"slot":local.rack.nearest_free(0)}
	game.hand.drop()
	check(stolen.holder == local.rack and game.stolen == 1,"A successful steal failed")
	check(get_nodes_in_group("tiles").size() == all_tiles.size(),"An action changed the total tile count")
	game.hud.set_table_state(game.watchers,true,0.0,0.5,true)
	check(not game.hud._risk.visible,"Rack view leaked opponent attention")
	game.hud.open_menu()
	check(paused and game.hud._menu.visible,"Pause menu did not pause the game")
	check(not game.hud._crosshair.visible,"Pause menu left the crosshair visible")
	game.hud.open_menu(true)
	check(game.hud._help_page.visible and not game.hud._pause_page.visible,"Controls page failed to open")
	game.hud.close_menu()
	check(not paused and not game.hud._menu.visible,"Resume did not close the menu")
	check(game._knock_sound.stream.get_length() > 0.19,"Knock audio was not created")
	print("TABLE_ACTIONS: ","PASS" if failures.is_empty() else JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
