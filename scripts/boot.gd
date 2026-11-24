extends Node
## App shell: owns the showroom background and every menu screen, starts and ends delivery runs.

const DAILY_REWARDS := [100, 150, 200, 300, 400, 600, 1000]
const FREE_CASH_AMOUNT := 200
const FREE_CASH_COOLDOWN := 600
const INTERSTITIAL_EVERY := 2

var ui_layer: CanvasLayer
var screen: Control
var screen_name := ""
var showroom: Node3D
var preview_node: Node3D
var preview_id := ""
var world: World
var garage_index := 0


func _ready() -> void:
    ui_layer = CanvasLayer.new()
    ui_layer.layer = 5
    add_child(ui_layer)
    _build_showroom(String(Save.data["truck"]))
    show_menu()
    if "--smoke" in OS.get_cmdline_user_args():
        _smoke_test()


## Headless CI check: builds every screen, then plays a short run, and prints SMOKE_OK or errors.
func _smoke_test() -> void:
    Save.data["tutorial_done"] = true
    show_garage()
    show_daily()
    show_awards()
    show_settings()
    show_result({"success": true, "reason": "", "cargo": "parcel", "base": 100, "integrity": 0.8, "pay": 100,
        "damage_penalty": 20, "time_bonus": 12, "streak_bonus": 5, "total": 97})
    show_result({"success": false, "reason": "failed_time", "cargo": "pizza", "base": 100, "integrity": 1.0,
        "pay": 0, "damage_penalty": 0, "time_bonus": 0, "streak_bonus": 0, "total": 0})
    start_run()
    Input.action_press("forward")
    get_tree().create_timer(6.0).timeout.connect(_smoke_done)


func _smoke_done() -> void:
    var info := "none"
    if world != null:
        info = "state=%s cargo=%s" % [world.state, world.cargo_id]
    print("SMOKE_OK ", info)
    get_tree().quit()


func _process(delta: float) -> void:
    if preview_node != null:
        preview_node.rotate_y(delta * 0.7)


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST and world == null and screen_name != "menu":
        show_menu()


# --- Showroom (3D background for menus) ------------------------------------------

func _build_showroom(vehicle_id: String) -> void:
    if showroom != null:
        showroom.queue_free()
    showroom = Node3D.new()
    add_child(showroom)
    var env := WorldEnvironment.new()
    env.environment = load("res://scenes/main-environment.tres")
    showroom.add_child(env)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
    light.shadow_enabled = true
    showroom.add_child(light)
    var floor_mi := MeshInstance3D.new()
    var pm := PlaneMesh.new()
    pm.size = Vector2(80, 80)
    floor_mi.mesh = pm
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.5, 0.72, 0.36)
    floor_mi.material_override = mat
    showroom.add_child(floor_mi)
    var cam := Camera3D.new()
    cam.position = Vector3(0, 2.6, 8.0)
    cam.fov = 38.0
    cam.h_offset = -1.7
    showroom.add_child(cam)
    cam.look_at(Vector3(0, 0.8, 0))
    cam.make_current()
    preview_node = null
    preview_id = ""
    preview(vehicle_id)


func preview(vehicle_id: String) -> void:
    if showroom == null:
        return
    if preview_node != null:
        preview_node.queue_free()
    var info := Catalog.vehicle(vehicle_id)
    preview_node = (load(info["model"]) as PackedScene).instantiate()
    showroom.add_child(preview_node)
    preview_id = vehicle_id


# --- Screen helpers ---------------------------------------------------------------

func _set_screen(name: String) -> Control:
    if screen != null:
        screen.queue_free()
    screen = Control.new()
    screen.set_anchors_preset(Control.PRESET_FULL_RECT)
    ui_layer.add_child(screen)
    screen_name = name
    return screen


func _margin(parent: Control, px: int = 24) -> MarginContainer:
    var m := MarginContainer.new()
    m.set_anchors_preset(Control.PRESET_FULL_RECT)
    m.mouse_filter = Control.MOUSE_FILTER_IGNORE
    m.add_theme_constant_override("margin_left", px)
    m.add_theme_constant_override("margin_right", px)
    m.add_theme_constant_override("margin_top", px)
    m.add_theme_constant_override("margin_bottom", px)
    parent.add_child(m)
    return m


func _toast_text(text: String, color: Color = UI.WHITE) -> void:
    var m := _margin(ui_layer, 90)
    m.add_theme_constant_override("margin_bottom", 0)
    var h := HBoxContainer.new()
    h.alignment = BoxContainer.ALIGNMENT_CENTER
    h.mouse_filter = Control.MOUSE_FILTER_IGNORE
    m.add_child(h)
    var l := UI.label(text, 30, color)
    l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    h.add_child(l)
    var tw := create_tween()
    tw.tween_interval(1.2)
    tw.tween_property(m, "modulate:a", 0.0, 0.5)
    tw.tween_callback(m.queue_free)


func _cash_chip(parent: Control) -> void:
    var m := _margin(parent, 16)
    var h := HBoxContainer.new()
    h.alignment = BoxContainer.ALIGNMENT_END
    h.mouse_filter = Control.MOUSE_FILTER_IGNORE
    m.add_child(h)
    var chip := UI.panel()
    chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    chip.add_child(UI.label("$%d" % Save.cash(), 30, UI.ORANGE))
    h.add_child(chip)


# --- Main menu ----------------------------------------------------------------------

func show_menu() -> void:
    var root := _set_screen("menu")
    if preview_id != String(Save.data["truck"]):
        preview(String(Save.data["truck"]))
    var m := _margin(root, 28)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 12)
    col.custom_minimum_size = Vector2(380, 0)
    m.add_child(col)

    var title := UI.label("COURIER RUSH", 54, UI.ORANGE)
    col.add_child(title)
    col.add_child(UI.label(Tr.t("level", [Save.level()]), 24, UI.MUTED))
    col.add_child(UI.spacer(10))

    var play := UI.button(Tr.t("play"), UI.GREEN, 36)
    play.custom_minimum_size = Vector2(340, 84)
    play.pressed.connect(start_run)
    col.add_child(play)

    var row1 := HBoxContainer.new()
    row1.add_theme_constant_override("separation", 12)
    var garage := UI.button(Tr.t("garage"), UI.ORANGE, 24)
    garage.custom_minimum_size = Vector2(164, 60)
    garage.pressed.connect(show_garage)
    var daily := UI.button(Tr.t("daily") + (" !" if _daily_claimable() else ""), UI.ORANGE, 24)
    daily.custom_minimum_size = Vector2(164, 60)
    daily.pressed.connect(show_daily)
    row1.add_child(garage)
    row1.add_child(daily)
    col.add_child(row1)

    var row2 := HBoxContainer.new()
    row2.add_theme_constant_override("separation", 12)
    var awards := UI.button(Tr.t("awards") + (" !" if _awards_claimable() > 0 else ""), UI.NAVY_SOFT, 24)
    awards.custom_minimum_size = Vector2(164, 60)
    awards.pressed.connect(show_awards)
    var settings := UI.button(Tr.t("settings"), UI.NAVY_SOFT, 24)
    settings.custom_minimum_size = Vector2(164, 60)
    settings.pressed.connect(show_settings)
    row2.add_child(awards)
    row2.add_child(settings)
    col.add_child(row2)

    var wait := _free_cash_wait_minutes()
    var free := UI.button(Tr.t("free_cash") if wait <= 0 else Tr.t("free_cash_wait", [wait]), UI.NAVY_SOFT, 20)
    free.custom_minimum_size = Vector2(340, 54)
    free.disabled = wait > 0
    free.pressed.connect(_on_free_cash)
    col.add_child(free)

    col.add_child(UI.label(Tr.t("stat_deliveries", [int(Save.data["deliveries"])]), 20, UI.MUTED))
    _cash_chip(root)


func _free_cash_wait_minutes() -> int:
    var left := int(Save.data["free_cash_at"]) + FREE_CASH_COOLDOWN - int(Time.get_unix_time_from_system())
    return 0 if left <= 0 else int(ceil(float(left) / 60.0))


func _on_free_cash() -> void:
    Ads.show_rewarded(func(ok: bool):
        if ok:
            Save.data["free_cash_at"] = int(Time.get_unix_time_from_system())
            Save.add_cash(FREE_CASH_AMOUNT)
            _toast_text(Tr.t("reward_amount", [FREE_CASH_AMOUNT]), UI.GREEN)
        else:
            _toast_text(Tr.t("ad_unavailable"), UI.RED)
        show_menu())


# --- Runs ---------------------------------------------------------------------------

func start_run() -> void:
    if screen != null:
        screen.queue_free()
        screen = null
    if showroom != null:
        showroom.queue_free()
        showroom = null
        preview_node = null
    screen_name = "run"
    world = World.new()
    add_child(world)
    world.run_finished.connect(_on_run_finished)
    world.quit_requested.connect(_on_run_quit)
    world.setup(String(Save.data["truck"]))


func _close_world() -> void:
    if world != null:
        world.queue_free()
        world = null
    get_tree().paused = false
    Input.action_release("left")
    Input.action_release("right")
    Input.action_release("forward")
    Input.action_release("back")
    _build_showroom(String(Save.data["truck"]))


func _on_run_quit() -> void:
    _close_world()
    show_menu()


func _on_run_finished(result: Dictionary) -> void:
    _close_world()
    Save.data["runs"] = int(Save.data["runs"]) + 1
    if bool(result["success"]):
        Save.data["deliveries"] = int(Save.data["deliveries"]) + 1
        Save.data["streak"] = int(Save.data["streak"]) + 1
        Save.data["best_streak"] = maxi(int(Save.data["best_streak"]), int(Save.data["streak"]))
        Save.add_cash(int(result["total"]))
    else:
        Save.data["failed"] = int(Save.data["failed"]) + 1
        Save.data["streak"] = 0
        Save.save()
    show_result(result)


func show_result(result: Dictionary) -> void:
    var root := _set_screen("result")
    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_child(center)
    var panel := UI.panel()
    center.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    box.custom_minimum_size = Vector2(440, 0)
    panel.add_child(box)

    var ok := bool(result["success"])
    var title := UI.label(Tr.t("delivered") if ok else Tr.t(String(result["reason"])), 40, UI.GREEN if ok else UI.RED)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)

    if ok:
        _result_row(box, Tr.t("reward"), "$%d" % int(result["pay"]), UI.WHITE)
        _result_row(box, Tr.t("damage_penalty"), "-$%d" % int(result["damage_penalty"]), UI.RED)
        _result_row(box, Tr.t("time_bonus"), "+$%d" % int(result["time_bonus"]), UI.GREEN)
        _result_row(box, Tr.t("streak_bonus"), "+$%d" % int(result["streak_bonus"]), UI.GREEN)
        box.add_child(UI.spacer(6))
        _result_row(box, Tr.t("total"), "$%d" % int(result["total"]), UI.ORANGE)

        if not bool(result.get("doubled", false)) and int(result["total"]) > 0:
            var dbl := UI.button(Tr.t("double"), UI.ORANGE, 24)
            dbl.pressed.connect(func():
                Ads.show_rewarded(func(earned: bool):
                    if earned:
                        Save.add_cash(int(result["total"]))
                        result["doubled"] = true
                    else:
                        _toast_text(Tr.t("ad_unavailable"), UI.RED)
                    show_result(result)))
            box.add_child(dbl)
        elif bool(result.get("doubled", false)):
            var done := UI.label(Tr.t("reward_amount", [int(result["total"])]), 26, UI.GREEN)
            done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            box.add_child(done)

    var next := UI.button(Tr.t("next_job"), UI.GREEN, 28)
    next.pressed.connect(func(): _continue_after_run(true))
    box.add_child(next)
    var menu := UI.button(Tr.t("to_menu"), UI.NAVY_SOFT, 24)
    menu.pressed.connect(func(): _continue_after_run(false))
    box.add_child(menu)
    _cash_chip(root)


func _result_row(parent: Control, left: String, right: String, color: Color) -> void:
    var row := HBoxContainer.new()
    var l := UI.label(left, 24, UI.MUTED)
    l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var r := UI.label(right, 26, color)
    row.add_child(l)
    row.add_child(r)
    parent.add_child(row)


func _continue_after_run(again: bool) -> void:
    var go := func():
        if again:
            start_run()
        else:
            show_menu()
    if int(Save.data["runs"]) % INTERSTITIAL_EVERY == 0:
        Ads.show_interstitial(go)
    else:
        go.call()


# --- Garage -------------------------------------------------------------------------

func show_garage() -> void:
    var root := _set_screen("garage")
    var ids: Array = []
    for v in Catalog.VEHICLES:
        ids.append(v["id"])
    if garage_index < 0 or garage_index >= ids.size():
        garage_index = ids.find(String(Save.data["truck"]))
        if garage_index < 0:
            garage_index = 0
    var id: String = ids[garage_index]
    var info := Catalog.vehicle(id)
    if preview_id != id:
        preview(id)

    var m := _margin(root, 28)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 10)
    col.custom_minimum_size = Vector2(460, 0)
    m.add_child(col)

    var nav := HBoxContainer.new()
    nav.add_theme_constant_override("separation", 10)
    var prev := UI.button("<", UI.NAVY_SOFT, 28)
    prev.custom_minimum_size = Vector2(64, 60)
    prev.pressed.connect(func():
        garage_index = (garage_index + ids.size() - 1) % ids.size()
        show_garage())
    var nxt := UI.button(">", UI.NAVY_SOFT, 28)
    nxt.custom_minimum_size = Vector2(64, 60)
    nxt.pressed.connect(func():
        garage_index = (garage_index + 1) % ids.size()
        show_garage())
    var name_l := UI.label(Tr.t(String(info["name"])), 32, UI.ORANGE)
    name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    nav.add_child(prev)
    nav.add_child(name_l)
    nav.add_child(nxt)
    col.add_child(nav)

    var tun := Catalog.tuning(id)
    _stat_row(col, Tr.t("power"), float(tun["power"]) / 2.0, UI.ORANGE)
    _stat_row(col, Tr.t("grip"), float(tun["grip"]) / 1.8, UI.GREEN)
    _stat_row(col, Tr.t("tough"), float(tun["armor"]) / 2.0, Color(0.4, 0.7, 1.0))

    var owned := Save.owns(id)
    var action: Button
    if not owned:
        action = UI.button("%s  $%d" % [Tr.t("buy"), int(info["price"])], UI.GREEN, 26)
        action.pressed.connect(func():
            if Save.spend(int(info["price"])):
                (Save.data["owned"] as Array).append(id)
                Save.data["truck"] = id
                Save.save()
            else:
                _toast_text(Tr.t("need_cash"), UI.RED)
            show_garage())
    elif String(Save.data["truck"]) == id:
        action = UI.button(Tr.t("equipped"), UI.NAVY_SOFT, 26)
        action.disabled = true
    else:
        action = UI.button(Tr.t("equip"), UI.GREEN, 26)
        action.pressed.connect(func():
            Save.data["truck"] = id
            Save.save()
            show_garage())
    col.add_child(action)

    if owned:
        for key in Catalog.UPGRADE_KEYS:
            _upgrade_row(col, id, String(key))

    var back := UI.button(Tr.t("back"), UI.NAVY_SOFT, 24)
    back.pressed.connect(show_menu)
    col.add_child(back)
    _cash_chip(root)


func _stat_row(parent: Control, label_text: String, value: float, color: Color) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    var l := UI.label(label_text, 20, UI.MUTED)
    l.custom_minimum_size = Vector2(130, 0)
    row.add_child(l)
    row.add_child(UI.bar(clampf(value, 0.0, 1.0), color, 260.0))
    parent.add_child(row)


func _upgrade_row(parent: Control, vehicle_id: String, key: String) -> void:
    var lvl := Save.upgrade_level(vehicle_id, key)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    var l := UI.label("%s  %s" % [Tr.t(key), "#".repeat(lvl) + "-".repeat(Catalog.MAX_UPGRADE - lvl)], 20, UI.WHITE)
    l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(l)
    var btn: Button
    if lvl >= Catalog.MAX_UPGRADE:
        btn = UI.button(Tr.t("maxed"), UI.NAVY_SOFT, 18)
        btn.disabled = true
    else:
        var cost := Catalog.upgrade_cost(lvl)
        btn = UI.button("$%d" % cost, UI.ORANGE, 20)
        btn.pressed.connect(func():
            if Save.spend(cost):
                Save.set_upgrade_level(vehicle_id, key, lvl + 1)
            else:
                _toast_text(Tr.t("need_cash"), UI.RED)
            show_garage())
    btn.custom_minimum_size = Vector2(120, 46)
    row.add_child(btn)
    parent.add_child(row)


# --- Daily reward ---------------------------------------------------------------------

func _today_index() -> int:
    return int(Time.get_unix_time_from_system() / 86400.0)


func _daily_day() -> int:
    var last := int(Save.data.get("daily_idx", -100))
    var day := int(Save.data["daily_day"])
    if _today_index() - last > 1:
        day = 0
    return day % 7


func _daily_claimable() -> bool:
    return int(Save.data.get("daily_idx", -100)) != _today_index()


func show_daily() -> void:
    var root := _set_screen("daily")
    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_child(center)
    var panel := UI.panel()
    center.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    panel.add_child(box)

    var title := UI.label(Tr.t("daily_title"), 38, UI.ORANGE)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)
    var day := _daily_day()
    var sub := UI.label(Tr.t("daily_streak", [day + 1]), 22, UI.MUTED)
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(sub)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    for i in 7:
        var tile := UI.panel(UI.ORANGE if i == day else UI.NAVY_SOFT)
        var tv := VBoxContainer.new()
        tile.add_child(tv)
        var dl := UI.label(str(i + 1), 20, UI.WHITE)
        dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        var rl := UI.label("$%d" % int(DAILY_REWARDS[i]), 22, UI.WHITE)
        tv.add_child(dl)
        tv.add_child(rl)
        row.add_child(tile)
    box.add_child(row)

    var claim: Button
    if _daily_claimable():
        claim = UI.button(Tr.t("claim") + " $%d" % int(DAILY_REWARDS[day]), UI.GREEN, 28)
        claim.pressed.connect(func():
            Save.data["daily_idx"] = _today_index()
            Save.data["daily_day"] = day + 1
            Save.add_cash(int(DAILY_REWARDS[day]))
            show_daily())
    else:
        claim = UI.button(Tr.t("come_back"), UI.NAVY_SOFT, 22)
        claim.disabled = true
    box.add_child(claim)
    var back := UI.button(Tr.t("back"), UI.NAVY_SOFT, 24)
    back.pressed.connect(show_menu)
    box.add_child(back)
    _cash_chip(root)


# --- Awards -----------------------------------------------------------------------------

func _awards() -> Array:
    var d: Dictionary = Save.data
    return [
        {"id": "deliver1", "name": "aw_deliver1", "reward": 100, "cur": int(d["deliveries"]), "goal": 1},
        {"id": "deliver10", "name": "aw_deliver10", "reward": 250, "cur": int(d["deliveries"]), "goal": 10},
        {"id": "deliver50", "name": "aw_deliver50", "reward": 800, "cur": int(d["deliveries"]), "goal": 50},
        {"id": "deliver100", "name": "aw_deliver100", "reward": 2000, "cur": int(d["deliveries"]), "goal": 100},
        {"id": "earn1000", "name": "aw_earn1000", "reward": 200, "cur": int(d["earned"]), "goal": 1000},
        {"id": "earn10000", "name": "aw_earn10000", "reward": 1500, "cur": int(d["earned"]), "goal": 10000},
        {"id": "streak5", "name": "aw_streak5", "reward": 500, "cur": int(d["best_streak"]), "goal": 5},
        {"id": "trucks3", "name": "aw_trucks3", "reward": 600, "cur": (d["owned"] as Array).size(), "goal": 3},
    ]


func _awards_claimable() -> int:
    var n := 0
    for a in _awards():
        if int(a["cur"]) >= int(a["goal"]) and not (Save.data["claimed"] as Array).has(a["id"]):
            n += 1
    return n


func show_awards() -> void:
    var root := _set_screen("awards")
    var m := _margin(root, 28)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 8)
    col.custom_minimum_size = Vector2(620, 0)
    m.add_child(col)
    col.add_child(UI.label(Tr.t("awards"), 38, UI.ORANGE))
    for a in _awards():
        var row := UI.panel(UI.NAVY_SOFT)
        var h := HBoxContainer.new()
        h.add_theme_constant_override("separation", 12)
        row.add_child(h)
        var done: bool = int(a["cur"]) >= int(a["goal"])
        var l := UI.label("%s  (%d/%d)" % [Tr.t(String(a["name"])), mini(int(a["cur"]), int(a["goal"])), int(a["goal"])], 20)
        l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        h.add_child(l)
        var claimed := (Save.data["claimed"] as Array).has(a["id"])
        var b: Button
        if claimed:
            b = UI.button(Tr.t("claimed"), UI.NAVY, 18)
            b.disabled = true
        elif done:
            b = UI.button("$%d" % int(a["reward"]), UI.GREEN, 20)
            var aid: String = a["id"]
            var rew: int = int(a["reward"])
            b.pressed.connect(func():
                (Save.data["claimed"] as Array).append(aid)
                Save.add_cash(rew)
                show_awards())
        else:
            b = UI.button("$%d" % int(a["reward"]), UI.NAVY, 18)
            b.disabled = true
        b.custom_minimum_size = Vector2(130, 44)
        h.add_child(b)
        col.add_child(row)
    var back := UI.button(Tr.t("back"), UI.NAVY_SOFT, 24)
    back.pressed.connect(show_menu)
    col.add_child(back)
    _cash_chip(root)


# --- Settings -----------------------------------------------------------------------------

func show_settings() -> void:
    var root := _set_screen("settings")
    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_child(center)
    var panel := UI.panel()
    center.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    box.custom_minimum_size = Vector2(460, 0)
    panel.add_child(box)
    var title := UI.label(Tr.t("settings"), 38, UI.ORANGE)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)

    var lang_btn := UI.button("%s: %s" % [Tr.t("language"), "TÜRKÇE" if Save.data["lang"] == "tr" else "ENGLISH"], UI.NAVY_SOFT, 24)
    lang_btn.pressed.connect(func():
        Save.data["lang"] = "en" if Save.data["lang"] == "tr" else "tr"
        Save.save()
        show_settings())
    box.add_child(lang_btn)
    box.add_child(_toggle("sound", func(): Save.apply_audio()))
    box.add_child(_toggle("vibration", func(): pass))
    box.add_child(_toggle("shadows", func(): pass))
    var credits := UI.label(Tr.t("credits"), 16, UI.MUTED)
    credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(credits)
    var back := UI.button(Tr.t("back"), UI.NAVY_SOFT, 24)
    back.pressed.connect(show_menu)
    box.add_child(back)


func _toggle(key: String, after: Callable) -> Button:
    var on := bool(Save.data[key])
    var b := UI.button("%s: %s" % [Tr.t(key), Tr.t("on") if on else Tr.t("off")], UI.GREEN if on else UI.NAVY_SOFT, 24)
    b.pressed.connect(func():
        Save.data[key] = not bool(Save.data[key])
        Save.save()
        after.call()
        show_settings())
    return b
