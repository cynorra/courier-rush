class_name World
extends Node3D
## One delivery run: builds the arena, drives the job loop (pick up, deliver before the timer ends,
## protect the cargo) and reports a result dictionary when the run is over.

signal run_finished(result: Dictionary)
signal quit_requested

const ARENA := 140.0
const PICKUP_RADIUS := 6.5
const CELL := 11.0

var vehicle: Vehicle
var view: Node3D
var camera: Camera3D
var hud: Hud
var touch: TouchControls
var ground: StaticBody3D
var sun: DirectionalLight3D
var tuning: Dictionary = {}
var obstacles: Array[Vector3] = []

var state := "idle"  # idle, to_pickup, to_drop, over
var cargo_id := ""
var pickup_pos := Vector3.ZERO
var drop_pos := Vector3.ZERO
var marker: Node3D
var time_left := 0.0
var time_limit := 0.0
var integrity := 1.0
var base_reward := 0
var speed_hist: Array[float] = []
var impact_pending := false
var pause_layer: CanvasLayer


func setup(vehicle_id: String) -> void:
    tuning = Catalog.tuning(vehicle_id)
    _build_environment()
    _build_ground()
    _build_scenery()
    vehicle = _make_vehicle(vehicle_id)
    add_child(vehicle)
    vehicle.position = Vector3(0, 0, 0)
    vehicle.sphere.body_entered.connect(_on_sphere_hit)
    _build_camera()

    hud = Hud.new()
    add_child(hud)
    hud.pause_pressed.connect(_toggle_pause)
    hud.set_cash(Save.cash(), Save.level())

    touch = TouchControls.new()
    add_child(touch)

    if bool(Save.data["tutorial_done"]):
        _new_job()
    else:
        _show_tutorial()


# --- World building ----------------------------------------------------------

func _build_environment() -> void:
    var env := WorldEnvironment.new()
    env.environment = load("res://scenes/main-environment.tres")
    add_child(env)
    sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
    sun.shadow_enabled = bool(Save.data["shadows"])
    sun.directional_shadow_max_distance = 45.0
    add_child(sun)


func _build_ground() -> void:
    var size := ARENA * 2.0 + 90.0
    ground = StaticBody3D.new()
    var cs := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(size, 2.0, size)
    cs.shape = box
    cs.position = Vector3(0, -1.0, 0)
    ground.add_child(cs)
    var mi := MeshInstance3D.new()
    var pm := PlaneMesh.new()
    pm.size = Vector2(size, size)
    mi.mesh = pm
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.5, 0.72, 0.36)
    mi.material_override = mat
    ground.add_child(mi)
    add_child(ground)

    # Invisible walls around the arena.
    for i in 4:
        var wall := StaticBody3D.new()
        var wcs := CollisionShape3D.new()
        var wb := BoxShape3D.new()
        var horizontal := i < 2
        wb.size = Vector3(size, 12.0, 2.0) if horizontal else Vector3(2.0, 12.0, size)
        wcs.shape = wb
        var sgn := 1.0 if i % 2 == 0 else -1.0
        wall.position = Vector3(0, 6.0, sgn * (ARENA + 8.0)) if horizontal else Vector3(sgn * (ARENA + 8.0), 6.0, 0)
        wall.add_child(wcs)
        add_child(wall)


func _build_scenery() -> void:
    var forest_spots: Array[Vector3] = []
    var tent_spots: Array[Vector3] = []
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var steps := int(ARENA / CELL)
    for gx in range(-steps, steps + 1):
        for gz in range(-steps, steps + 1):
            var p := Vector3(gx * CELL + rng.randf_range(-2.0, 2.0), 0.0, gz * CELL + rng.randf_range(-2.0, 2.0))
            if Vector2(p.x, p.z).length() < 22.0:
                continue
            var edge := absf(p.x) > ARENA - CELL * 1.2 or absf(p.z) > ARENA - CELL * 1.2
            var roll := rng.randf()
            if edge or roll < 0.2:
                forest_spots.append(p)
            elif roll < 0.26:
                tent_spots.append(p)
    _scatter("res://models/decoration-forest.glb", forest_spots, Vector3(5.0, 6.0, 5.0))
    _scatter("res://models/decoration-tents.glb", tent_spots, Vector3(6.0, 3.0, 6.0))


## Draws many copies of a model with MultiMesh (cheap on phones) and gives each a box collider.
func _scatter(path: String, spots: Array[Vector3], collider_size: Vector3) -> void:
    if spots.is_empty():
        return
    var src: Node = (load(path) as PackedScene).instantiate()
    var parts: Array = []
    _collect_meshes(src, parts, Transform3D.IDENTITY)
    src.free()
    var xforms: Array[Transform3D] = []
    for p in spots:
        var b := Basis(Vector3.UP, deg_to_rad(90.0 * float(randi() % 4))).scaled(Vector3(0.75, 0.75, 0.75))
        xforms.append(Transform3D(b, p))
    for part in parts:
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = part["mesh"]
        mm.instance_count = xforms.size()
        for i in xforms.size():
            mm.set_instance_transform(i, xforms[i] * (part["xf"] as Transform3D))
        var mmi := MultiMeshInstance3D.new()
        mmi.multimesh = mm
        add_child(mmi)
    for p in spots:
        var body := StaticBody3D.new()
        var cs := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = collider_size
        cs.shape = bs
        cs.position = Vector3(0, collider_size.y * 0.5, 0)
        body.add_child(cs)
        body.position = p
        add_child(body)
        obstacles.append(p)


func _collect_meshes(n: Node, acc: Array, xf: Transform3D) -> void:
    var t := xf
    if n is Node3D:
        t = xf * (n as Node3D).transform
    if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
        acc.append({"mesh": (n as MeshInstance3D).mesh, "xf": t})
    for c in n.get_children():
        _collect_meshes(c, acc, t)


func _make_vehicle(id: String) -> Vehicle:
    var info := Catalog.vehicle(id)
    var v: Vehicle = (load(info["scene"]) as PackedScene).instantiate()
    if String(info["scene"]) == "res://scenes/vehicle.tscn":
        var container := v.get_node("Container")
        var old: Node3D = container.get_node("Model")
        var xf := old.transform
        var idx := old.get_index()
        container.remove_child(old)
        old.free()
        var model: Node3D = (load(info["model"]) as PackedScene).instantiate()
        model.name = "Model"
        container.add_child(model)
        container.move_child(model, idx)
        model.transform = xf
    v.power = float(tuning["power"])
    v.grip = float(tuning["grip"])
    return v


func _build_camera() -> void:
    view = Node3D.new()
    view.set_script(load("res://scripts/view.gd"))
    camera = Camera3D.new()
    camera.name = "Camera"
    camera.position = Vector3(0, 0, 16)
    camera.fov = 40.0
    camera.far = 160.0
    view.add_child(camera)
    view.set("target", vehicle)
    view.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-35.0), deg_to_rad(45.0), 0.0)), Vector3.ZERO)
    add_child(view)
    camera.make_current()


# --- Jobs ----------------------------------------------------------------------

func _random_free_point(origin: Vector3, min_d: float, max_d: float) -> Vector3:
    var limit := ARENA - 20.0
    var p := origin
    for i in 80:
        var ang := randf() * TAU
        var d := randf_range(min_d, max_d)
        p = origin + Vector3(cos(ang), 0.0, sin(ang)) * d
        p.x = clampf(p.x, -limit, limit)
        p.z = clampf(p.z, -limit, limit)
        var free := true
        for o in obstacles:
            if Vector2(o.x - p.x, o.z - p.z).length() < 9.0:
                free = false
                break
        if free and origin.distance_to(p) > min_d * 0.6:
            return p
    return p


func _new_job() -> void:
    cargo_id = Catalog.random_cargo(Save.level())
    var vp := vehicle.get_vehicle_position()
    pickup_pos = _random_free_point(vp, 35.0, 90.0)
    drop_pos = _random_free_point(pickup_pos, 70.0, 150.0)
    var dist := pickup_pos.distance_to(drop_pos)
    var cargo: Dictionary = Catalog.CARGOS[cargo_id]
    time_limit = dist / 11.0 * float(cargo["time"]) + 14.0
    base_reward = int((35.0 + dist * 0.8) * float(cargo["reward"]) * (1.0 + 0.04 * float(Save.level() - 1)))
    integrity = 1.0
    state = "to_pickup"
    _place_marker(pickup_pos, Color(1.0, 0.85, 0.2))
    hud.set_objective(Tr.t("pickup", [Tr.t(cargo["name"])]), Color(1.0, 0.85, 0.2))


func _place_marker(pos: Vector3, color: Color) -> void:
    if marker != null:
        marker.queue_free()
    marker = Node3D.new()
    marker.position = Vector3(pos.x, 0.05, pos.z)

    var beam := MeshInstance3D.new()
    var cyl := CylinderMesh.new()
    cyl.top_radius = 3.0
    cyl.bottom_radius = 3.0
    cyl.height = 30.0
    beam.mesh = cyl
    beam.position.y = 15.0
    var beam_mat := StandardMaterial3D.new()
    beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    beam_mat.albedo_color = Color(color, 0.26)
    beam.material_override = beam_mat
    marker.add_child(beam)

    var ring := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 5.6
    torus.outer_radius = 6.5
    ring.mesh = torus
    ring.position.y = 0.2
    var ring_mat := StandardMaterial3D.new()
    ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ring_mat.albedo_color = color
    ring.material_override = ring_mat
    marker.add_child(ring)
    add_child(marker)


# --- Frame loop ----------------------------------------------------------------

func _on_sphere_hit(body: Node) -> void:
    if body != ground:
        impact_pending = true


func _physics_process(delta: float) -> void:
    if state != "to_pickup" and state != "to_drop":
        return
    var speed := vehicle.sphere.linear_velocity.length()
    speed_hist.append(speed)
    if speed_hist.size() > 5:
        speed_hist.pop_front()
    if impact_pending:
        impact_pending = false
        var drop: float = speed_hist[0] - speed
        if drop > 3.0:
            _damage(drop)
            if state == "over":
                return

    if state == "to_drop":
        time_left -= delta
        if time_left <= 0.0:
            _finish(false, "failed_time")
            return

    var target := pickup_pos if state == "to_pickup" else drop_pos
    var pos := vehicle.get_vehicle_position()
    if Vector2(pos.x - target.x, pos.z - target.z).length() < PICKUP_RADIUS:
        _arrived()


func _process(delta: float) -> void:
    if marker != null:
        marker.rotation.y += delta * 0.8
    if state != "to_pickup" and state != "to_drop":
        return
    var target := pickup_pos if state == "to_pickup" else drop_pos
    var pos := vehicle.get_vehicle_position()
    var to := target - pos
    to.y = 0.0
    var cam_fwd := -camera.global_transform.basis.z
    cam_fwd.y = 0.0
    var ang := 0.0
    if to.length() > 0.01 and cam_fwd.length() > 0.01:
        ang = cam_fwd.normalized().signed_angle_to(to.normalized(), Vector3.UP)
    hud.update_run(time_left, state == "to_drop", integrity, to.length(), -ang)


func _damage(drop: float) -> void:
    if state != "to_drop":
        return
    var cargo: Dictionary = Catalog.CARGOS[cargo_id]
    var dmg := clampf((drop - 3.0) * 0.045, 0.0, 0.6) * float(cargo["fragile"]) / float(tuning["armor"])
    integrity = maxf(integrity - dmg, 0.0)
    if bool(Save.data["vibration"]):
        Input.vibrate_handheld(70)
    if integrity <= 0.0:
        _finish(false, "failed_damage")


func _arrived() -> void:
    if state == "to_pickup":
        state = "to_drop"
        time_left = time_limit
        speed_hist.clear()
        _place_marker(drop_pos, Color(0.3, 1.0, 0.55))
        var cargo: Dictionary = Catalog.CARGOS[cargo_id]
        hud.set_objective(Tr.t("deliver", [Tr.t(cargo["name"])]), Color(0.3, 1.0, 0.55))
        hud.toast("+ " + Tr.t(cargo["name"]), Color(1.0, 0.85, 0.2))
    else:
        _finish(true, "")


func _finish(success: bool, reason: String) -> void:
    state = "over"
    touch.release_all()
    var result := {
        "success": success, "reason": reason, "cargo": cargo_id, "base": base_reward,
        "integrity": integrity, "pay": 0, "damage_penalty": 0, "time_bonus": 0, "streak_bonus": 0, "total": 0,
    }
    if success:
        var pay := int(round(float(base_reward) * (0.4 + 0.6 * integrity)))
        var time_bonus := int(time_left * 2.0)
        var streak_bonus := int(float(pay + time_bonus) * minf(0.5, 0.05 * float(int(Save.data["streak"]))))
        result["pay"] = base_reward
        result["damage_penalty"] = base_reward - pay
        result["time_bonus"] = time_bonus
        result["streak_bonus"] = streak_bonus
        result["total"] = pay + time_bonus + streak_bonus
        hud.toast(Tr.t("delivered"), UI.GREEN)
    else:
        hud.toast(Tr.t(reason), UI.RED)
    get_tree().create_timer(1.4).timeout.connect(func(): run_finished.emit(result))


# --- Tutorial & pause ----------------------------------------------------------

func _show_tutorial() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 40
    add_child(layer)
    var root := Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    layer.add_child(root)
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.55)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_child(dim)
    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_child(center)
    var panel := UI.panel()
    center.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    panel.add_child(box)
    for key in ["tut1", "tut2", "tut3"]:
        var l := UI.label(Tr.t(key), 26)
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        l.custom_minimum_size = Vector2(620, 0)
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        box.add_child(l)
    var ok := UI.button(Tr.t("got_it"), UI.GREEN)
    ok.pressed.connect(func():
        Save.data["tutorial_done"] = true
        Save.save()
        layer.queue_free()
        _new_job())
    box.add_child(ok)


func _toggle_pause() -> void:
    if state != "to_pickup" and state != "to_drop":
        return
    if pause_layer != null:
        _resume()
        return
    get_tree().paused = true
    touch.release_all()
    pause_layer = CanvasLayer.new()
    pause_layer.layer = 50
    pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(pause_layer)
    var root := Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    pause_layer.add_child(root)
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.6)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_child(dim)
    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_child(center)
    var panel := UI.panel()
    center.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    panel.add_child(box)
    var title := UI.label(Tr.t("pause"), 40, UI.ORANGE)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)
    var resume := UI.button(Tr.t("resume"), UI.GREEN)
    resume.pressed.connect(_resume)
    box.add_child(resume)
    var quit := UI.button(Tr.t("quit"), UI.RED)
    quit.pressed.connect(_quit)
    box.add_child(quit)


func _resume() -> void:
    get_tree().paused = false
    if pause_layer != null:
        pause_layer.queue_free()
        pause_layer = null


func _quit() -> void:
    _resume()
    quit_requested.emit()


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        _toggle_pause()
