class_name Hud
extends CanvasLayer
## In-run heads-up display: objective, timer, cargo integrity, compass arrow, toasts, pause button.

signal pause_pressed

class Arrow extends Control:
    var color := UI.ORANGE

    func _draw() -> void:
        var c := size * 0.5
        var pts := PackedVector2Array([
            c + Vector2(0, -size.y * 0.46),
            c + Vector2(size.x * 0.36, size.y * 0.38),
            c + Vector2(0, size.y * 0.18),
            c + Vector2(-size.x * 0.36, size.y * 0.38),
        ])
        draw_colored_polygon(pts, color)
        draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0, 0, 0, 0.6), 3.0)


var _cash: Label
var _level: Label
var _objective: Label
var _timer: Label
var _cargo_bar: ProgressBar
var _arrow: Arrow
var _dist: Label
var _toast: Label
var _toast_tween: Tween


func _ready() -> void:
    layer = 10
    var margin := MarginContainer.new()
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 16)
    add_child(margin)

    var top := HBoxContainer.new()
    top.mouse_filter = Control.MOUSE_FILTER_IGNORE
    margin.add_child(top)

    # Left: cash and level.
    var left := HBoxContainer.new()
    left.mouse_filter = Control.MOUSE_FILTER_IGNORE
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    top.add_child(left)
    var cash_panel := UI.panel()
    left.add_child(cash_panel)
    var lv := VBoxContainer.new()
    cash_panel.add_child(lv)
    _cash = UI.label("$0", 30, UI.ORANGE)
    _level = UI.label("", 18, UI.MUTED)
    lv.add_child(_cash)
    lv.add_child(_level)

    # Center: objective, timer, cargo bar, compass arrow, distance.
    var center := VBoxContainer.new()
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    center.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    center.alignment = BoxContainer.ALIGNMENT_BEGIN
    top.add_child(center)
    var info := UI.panel()
    center.add_child(info)
    var cv := VBoxContainer.new()
    info.add_child(cv)
    _objective = UI.label("", 22, UI.WHITE)
    _objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _timer = UI.label("--", 40, UI.WHITE)
    _timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _cargo_bar = UI.bar(1.0, UI.GREEN, 280.0)
    cv.add_child(_objective)
    cv.add_child(_timer)
    cv.add_child(_cargo_bar)
    _arrow = Arrow.new()
    _arrow.custom_minimum_size = Vector2(72, 72)
    _arrow.pivot_offset = Vector2(36, 36)
    _arrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    center.add_child(_arrow)
    _dist = UI.label("", 22, UI.WHITE)
    _dist.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    center.add_child(_dist)

    # Right: pause.
    var right := HBoxContainer.new()
    right.mouse_filter = Control.MOUSE_FILTER_IGNORE
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    right.alignment = BoxContainer.ALIGNMENT_END
    top.add_child(right)
    var pause := UI.button("II", UI.NAVY_SOFT, 26)
    pause.custom_minimum_size = Vector2(64, 64)
    pause.pressed.connect(func(): pause_pressed.emit())
    right.add_child(pause)

    # Toast in the middle of the screen.
    var toast_box := CenterContainer.new()
    toast_box.set_anchors_preset(Control.PRESET_FULL_RECT)
    toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(toast_box)
    _toast = UI.label("", 44, UI.WHITE)
    _toast.modulate.a = 0.0
    toast_box.add_child(_toast)


func set_cash(amount: int, level: int) -> void:
    _cash.text = "$%d" % amount
    _level.text = Tr.t("level", [level])


func set_objective(text: String, color: Color) -> void:
    _objective.text = text
    _arrow.color = color
    _arrow.queue_redraw()


func update_run(time_left: float, show_time: bool, integrity: float, dist: float, arrow_angle: float) -> void:
    _timer.text = ("%.1f" % maxf(time_left, 0.0)) if show_time else "--"
    _timer.add_theme_color_override("font_color", UI.RED if show_time and time_left < 10.0 else UI.WHITE)
    _cargo_bar.value = clampf(integrity, 0.0, 1.0)
    var fill := UI.box(UI.GREEN if integrity > 0.5 else (UI.ORANGE if integrity > 0.25 else UI.RED), 8)
    _cargo_bar.add_theme_stylebox_override("fill", fill)
    _arrow.rotation = arrow_angle
    _dist.text = "%d m" % int(dist)


func toast(text: String, color: Color = UI.WHITE) -> void:
    _toast.text = text
    _toast.add_theme_color_override("font_color", color)
    _toast.modulate.a = 1.0
    if _toast_tween:
        _toast_tween.kill()
    _toast_tween = create_tween()
    _toast_tween.tween_interval(1.0)
    _toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
