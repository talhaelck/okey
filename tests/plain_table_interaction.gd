extends SceneTree
func _initialize():call_deferred("run")
func run():
	var game=load("res://scenes/main.tscn").instantiate()
	game.get_node("FocusCamera").mouse_control=false
	root.add_child(game)
	game.set_process(false)
	game.hand.set_process(false)
	assert(game.table.props.size()==3)
	assert(game.table._discard_glow_pad==null)
	assert(game.table.find_prop("glasses").is_empty())
	assert(game.table.find_prop("magnifier").is_empty())
	for i in 4:
		for p in [Vector3(.18,.75,.10),Vector3(.54,.75,.41),Table.DISCARD_SPOTS[0]]:
			assert(Table.is_in_discard_zone(p.rotated(Vector3.UP,i*PI*.5),i))
		for p in [Vector3(0,.75,0),Vector3(-.3,.75,.2),Vector3(.6,.75,.2),Vector3(.3,.75,.48)]:
			assert(not Table.is_in_discard_zone(p.rotated(Vector3.UP,i*PI*.5),i))
	var tile=game.table.pop_draw_tile()
	assert(tile!=null)
	assert(game.table.put_loose(tile,game.table.to_global(Vector3(.50,.75,.37)),0))
	assert(tile.holder==game.table and tile.is_discard and tile.discard_seat==0)
	assert(game.table.top_discard(0)==tile)
	var loose=game.table.pop_draw_tile()
	assert(loose!=null)
	assert(not game.table.put_loose(loose,game.table.to_global(Vector3(-.35,.75,.2)),0))
	assert(loose.holder==game.table and not loose.is_discard)
	assert(game.room.find_children("BackgroundGuest*","Node3D",false,false).size()==4)
	print("PLAIN_TABLE_INTERACTION_OK")
	game.free()
	quit()
