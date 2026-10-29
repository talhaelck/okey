extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
 run.call_deferred()
func check(value: bool,message: String) -> void:
 if not value:
  failures.append(message)
  push_error(message)
func run() -> void:
 var expected: Array[String] = []
 expected.assign(RiggedPatron.KINDS)
 expected.sort()
 var previous: Array[String] = []
 for round_index in 24:
  var order := CafePreferences.patron_lineup("sabri")
  var sorted := order.duplicate()
  sorted.sort()
  check(sorted==expected,"Table roster must contain each new guest exactly once")
  if round_index>0:
   check(order!=previous,"Consecutive tables reused identical seating")
  previous=order.duplicate()
 var old_companion := CafePreferences.companion
 var menu: Node = load("res://scenes/coffeehouse.tscn").instantiate()
 root.add_child(menu)
 check(menu.PATRON_ORDER.size()==7,"Expected four existing and three additional cards")
 for kind in RiggedPatron.KINDS:
  CafePreferences.companion=kind
  menu._selected_card=kind
  menu._apply_companion()
  menu._characters()
  await process_frame
  check(menu.game.seats[0].character==kind,"Local selection did not apply: "+kind)
  check(menu.game.seats[0].get_node_or_null("LocalPlayerBody")==null,"New selected body obscures local camera")
  var rig: RiggedPatron = menu._preview_stage.get_children().filter(func(n):return n is RiggedPatron)[0]
  check(rig.player.is_playing(),"Idle animation not running: "+kind)
  check(rig.skeleton.get_bone_count()>40,"Skeleton missing: "+kind)
  check(rig.player.get_animation("seated_idle").get_track_count()>40,"Animation retargeting lost tracks")
  for seat in menu.game.seats.slice(1):
   if seat.character not in RiggedPatron.KINDS:
    continue
   var patron: RiggedPatron = seat.buddy._rigged
   check(patron!=null,"New opponent dispatched to wrong presenter")
   patron.player.seek(.5,true)
   patron._presentation._process_modification_with_delta(1.0/60)
   for side in ["Left","Right"]:
    check(patron.presented_hands.has(side),"Arm modifier did not run")
    for point: Vector3 in patron.presented_hands[side]:
     check(patron.rack_penetration(point)<.003,"Hand penetrates rack: "+seat.character)
     var world := patron.to_global(point)
     if absf(world.x)<.70 and absf(world.z)<.70:
      check(world.y>=Table.TOP-.007,"Hand penetrates tabletop: "+seat.character+" "+str(world))
   seat.buddy.look_toward(menu.game.seats[0].global_position)
   for reaction in ["No","Reach","Hit","Wipe","Laugh"]:
    seat.buddy.gesture(reaction)
  check(menu.game.seats.slice(1).all(func(s):return s.character in RiggedPatron.KINDS),"Legacy opponent leaked into new roster")
  var before_browsing: Array[String] = menu._opponent_order.duplicate()
  menu._apply_table()
  check(menu._opponent_order==before_browsing,"Menu browsing reshuffled current table")
 CafePreferences.companion="sabri"
 menu._apply_companion()
 await process_frame
 check(menu.game.seats.slice(1).all(func(s):return s.buddy._rigged!=null),"Old local selection changed opponents to legacy models")
 menu._selected_card="sabri"
 menu._characters()
 check(menu._preview_stage.get_children().any(func(n):return n is CafePatron),"Existing patrons were removed from preview")
 menu._play(false)
 check(menu.game.hud.visible and not menu.layer.visible,"Menu-to-game transition failed")
 menu.game.hud.open_menu()
 check(paused,"Pause failed")
 menu.game.hud.close_menu()
 check(not paused,"Resume failed")
 CafePreferences.companion=old_companion
 menu.free()
 await process_frame
 print("RIGGED_PATRONS: PASS" if failures.is_empty() else "RIGGED_PATRONS: FAIL "+str(failures))
 quit(0 if failures.is_empty() else 1)
