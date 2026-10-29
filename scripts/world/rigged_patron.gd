class_name RiggedPatron
extends Node3D
## Mixamo animation retargeting and seat/table presentation, with no tile ownership changes.
const KINDS := ["gozluklu", "tespihli", "yasli"]
const BONE := "mixamorig_"
# Uniform whole-character fit keeps the authored head, hands and bone proportions.
const SEATED_TORSO_HEIGHT := 0.34
const SEATED_UPPER_HEIGHT := 0.655
const SEATED_HIP_OFFSET := Vector3(0,0.09,-0.075)
var skeleton: Skeleton3D
var player := AnimationPlayer.new()
var body: Node3D
var yaw := 0.0
var reaction := 0.0
var lean := 0.0
var laughter := 0.0
var wiping := 0.0
var _time := 0.0
var _turn: Tween
var _presentation: Presentation
var rack: Rack
var presented_hands: Dictionary = {}
var rest_surface_height := Table.TOP-Seat.SEAT_TOP
var rest_edge := -(Seat.CHAIR_DISTANCE-Table.SIZE*.5)
var rest_half_width := .36

func build(kind: String) -> void:
 body = load("res://assets/models/dayi_rig/dayi_%s.glb" % kind).instantiate()
 body.rotation.y = PI
 add_child(body)
 skeleton = body.find_children("*", "Skeleton3D", true, false)[0]
 var owner_seat := get_parent().get_parent() as Seat
 if owner_seat:
  rack = owner_seat.rack
 body.add_child(player)
 var source: Node = load("res://assets/models/dayi_rig/anim/seated_idle.glb").instantiate()
 var source_player: AnimationPlayer = source.find_children("*", "AnimationPlayer", true, false)[0]
 var clip := source_player.get_animation("seated_idle").duplicate() as Animation
 var skel_path := String(body.get_path_to(skeleton))
 for track in range(clip.get_track_count()-1,-1,-1):
  var path := clip.track_get_path(track)
  var bone := String(path.get_name(path.get_name_count()-1))
  var keep := skeleton.find_bone(bone)>=0 and (clip.track_get_type(track)==Animation.TYPE_ROTATION_3D or (clip.track_get_type(track)==Animation.TYPE_POSITION_3D and bone==BONE+"Hips"))
  if keep:
   clip.track_set_path(track,NodePath(skel_path+":"+bone))
  else:
   clip.remove_track(track)
 clip.loop_mode = Animation.LOOP_LINEAR
 var library := AnimationLibrary.new()
 library.add_animation("seated_idle",clip)
 player.add_animation_library("",library)
 source.free()
 # Fit the animated seated body uniformly, then align the hips with the chair.
 player.play("seated_idle")
 player.seek(0,true)
 var seated_height := bone_local("HeadTop_End").y-bone_local("Hips").y
 body.scale *= SEATED_UPPER_HEIGHT/maxf(seated_height,0.25)
 body.position -= bone_local("Hips")-SEATED_HIP_OFFSET
 _add_footrest()
 _presentation = Presentation.new()
 _presentation.patron = self
 skeleton.add_child(_presentation)

func _add_footrest() -> void:
 var left := bone_local("LeftToeBase")
 var right := bone_local("RightToeBase")
 var top := minf(left.y,right.y)-0.022
 if top+Seat.SEAT_TOP<0.085:
  return
 var wood := SurfaceStyle.textured(Color("463326"))
 var centre := (left+right)*0.5
 var width := absf(left.x-right.x)+0.13
 var rest := Node3D.new()
 rest.name = "ChairFootrest"
 add_child(rest)
 SurfaceStyle.box(rest,Vector3(width,0.026,0.14),Vector3(centre.x,top-0.013,centre.z+0.025),wood,0.008)
 for side in [-1,1]:
  SurfaceStyle.rod(rest,Vector3(side*0.19,-Seat.SEAT_TOP+0.05,-0.16),Vector3(side*width*0.34,top-0.03,centre.z+0.04),0.018,wood)

func bone_local(name: String) -> Vector3:
 var idx := skeleton.find_bone(BONE+name)
 return to_local(skeleton.to_global(skeleton.get_bone_global_pose(idx).origin))

func turn_head(value: float, duration := 0.3) -> void:
 if _turn:
  _turn.kill()
 _turn = create_tween().set_trans(Tween.TRANS_SINE)
 _turn.tween_property(self,"yaw",clampf(value,-0.8,0.8),duration)

func gesture(kind: String) -> void:
 match kind:
  "No", "Hit": reaction = 0.9
  "Reach": lean = 0.10
  "Laugh": laughter = 1.4
  "Wipe": wiping = 3.0

func _process(delta: float) -> void:
 _time += delta
 reaction = maxf(0,reaction-delta)
 lean = maxf(0,lean-delta*0.25)
 laughter = maxf(0,laughter-delta)
 wiping = maxf(0,wiping-delta)

func hand_points(side: String) -> Array[Vector3]:
 var points: Array[Vector3] = []
 for idx in skeleton.get_bone_count():
  if skeleton.get_bone_name(idx).begins_with(BONE+side+"Hand"):
   points.append(to_local(skeleton.to_global(skeleton.get_bone_global_pose(idx).origin)))
 return points

func rack_penetration(point: Vector3) -> float:
 if not is_instance_valid(rack):
  return 0.0
 var p := rack.to_local(to_global(point))
 if absf(p.x)>Rack.LENGTH*0.5+0.035 or p.y < -0.025 or p.y>Rack.HEIGHT+0.055:
  return 0.0
 # Conservative bounds cover the rack, lips and the backs of its tiles.
 if p.z < -0.09 or p.z > 0.12:
  return 0.0
 return 0.12-p.z+0.018

class Presentation extends SkeletonModifier3D:
 var patron: RiggedPatron
 func _process_modification_with_delta(_delta: float) -> void:
  var s := get_skeleton()
  var right := (s.global_basis.inverse()*(patron.global_basis*Vector3.RIGHT)).normalized()
  for part: Array in [["Spine1",0.08],["Spine2",0.10],["Neck",-0.04]]:
   RigPatronIK.turn(s,s.find_bone(BONE+part[0]),right,float(part[1]))
  var laugh := sin(patron._time*13)*0.012*minf(1,patron.laughter)
  for part: Array in [["Spine",0.6],["Spine1",0.4]]:
   RigPatronIK.turn(s,s.find_bone(BONE+part[0]),right,-(patron.lean+laugh)*float(part[1]))
  var shake := sin(patron._time*22)*0.20*patron.reaction
  var up := (s.global_basis.inverse()*(patron.global_basis*Vector3.UP)).normalized()
  for part: Array in [["Spine1",0.15],["Spine2",0.2],["Neck",0.2],["Head",0.45]]:
   RigPatronIK.turn(s,s.find_bone(BONE+part[0]),up,(patron.yaw+shake)*float(part[1]))
  var to_patron := patron.global_transform.affine_inverse()*s.global_transform
  var to_skeleton := to_patron.affine_inverse()
  var felt := patron.rest_surface_height
  var edge := patron.rest_edge
  for side in ["Left","Right"]:
   var upper := s.find_bone(BONE+side+"Arm")
   var lower := s.find_bone(BONE+side+"ForeArm")
   var hand := s.find_bone(BONE+side+"Hand")
   if mini(upper,mini(lower,hand))<0:
    continue
   var hand_basis := s.get_bone_global_pose(hand).basis
   for attempt in 4:
    var points := patron.hand_points(side)
    var wrist: Vector3 = to_patron*s.get_bone_global_pose(hand).origin
    var shift := Vector3.ZERO
    if attempt==0:
     shift.x = signf(wrist.x)*(patron.rest_half_width-absf(wrist.x))
     shift.z = minf(0,edge-0.01-wrist.z)
     if patron.wiping>0:
      shift.x += sin(patron._time*5)*0.018
    var lowest := INF
    for p in points:
     lowest = minf(lowest,p.y)
    shift.y = maxf(0,felt+0.015-lowest)
    var back := 0.0
    for p in points:
     back = maxf(back,patron.rack_penetration(p+shift))
    shift.z += back
    if shift.length()<0.001:
     break
    RigPatronIK.reach(s,upper,lower,hand,to_skeleton*(wrist+shift))
    var pose := s.get_bone_global_pose(hand)
    pose.basis = hand_basis
    s.set_bone_global_pose(hand,pose)
   patron.presented_hands[side] = patron.hand_points(side)
