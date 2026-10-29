extends SceneTree
## Tea-only actions, disabled legacy controls, tile ownership and stable lighting.
func _initialize():run.call_deferred()
func run():
 var game=load("res://scenes/main.tscn").instantiate()
 game.get_node("FocusCamera").mouse_control=false
 root.add_child(game)
 game.set_process(false);game.hand.set_process(false)
 for w in game.watchers:
  w.set_process(false);w._state=Watcher.State.RACK
 assert(not game.has_method("knock_table"))
 assert(not game.has_method("trigger_blackout"))
 assert(game.table.props.size()==3)
 for p in game.table.props:assert(p.id in ["tea_1","tea_2","tea_3"])
 var energies=[]
 for entry in game.room._room_lights:energies.append(entry.light.light_energy)
 var hand_pos=game.seats[0].left_hand.position
 for key in [KEY_Q,KEY_K]:
  var event=InputEventKey.new();event.keycode=key;event.pressed=true
  game._unhandled_input(event)
 for action in ["knock","blackout","glasses","ashtray","leblebi"]:
  game._on_hud_action(action);game._on_prop_used(action,false)
 game._turn_timer=1000
 game._process(46.0)
 assert(game.seats[0].left_hand.position.is_equal_approx(hand_pos))
 for i in energies.size():assert(is_equal_approx(game.room._room_lights[i].light.light_energy,energies[i]))
 var tiles=get_nodes_in_group("tiles")
 var owners={}
 for tile in tiles:owners[tile.get_instance_id()]=[tile.holder,tile.value]
 for i in range(1,4):
  var prop=game.table.find_prop("tea_"+str(i))
  var picked=game.table.pick_prop(game.table.to_global(prop.pos)+Vector3.UP*.3,Vector3.DOWN,1.0)
  assert(not picked.is_empty() and picked.id==prop.id)
  game.hand._trigger_prop(prop,false)
  assert(prop.meta.cup.get_child_count()>=2)
  var watcher=game.watchers[i-1]
  assert(watcher._state==Watcher.State.WIPING)
  assert(prop.meta.spilled)
  var rack=game.seats[i].rack
  var animation=rack._tilt_tween
  assert(animation!=null and animation.is_running())
  game._on_prop_used(prop.id,true)
  assert(rack._tilt_tween==animation)
  animation.custom_step(.30)
  assert(rack.rotation.x<-.2)
  animation.custom_step(6.2)
  assert(absf(rack.rotation.x)<.001)
  watcher._process(6.2)
  assert(watcher._state==Watcher.State.RACK)
 for tile in tiles:
  var before=owners[tile.get_instance_id()]
  assert(tile.holder==before[0] and tile.value==before[1])
 assert(game.stolen==0 and game.caught==0)
 game.hud.open_menu();assert(paused)
 game.hud.close_menu();assert(not paused)
 print("TEA_ONLY_ACTIONS: PASS")
 game.free();quit()
