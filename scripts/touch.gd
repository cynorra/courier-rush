class_name TouchControls
extends CanvasLayer
## On-screen driving buttons. Each button presses a real input action, so keyboard and touch share the same path.

var _buttons: Array = []


func _ready() -> void:
    layer = 20
    var vp := get_viewport().get_visible_rect().size
    _add("left", Vector2(110, vp.y - 110), "<", 78.0)
    _add("right", Vector2(290, vp.y - 110), ">", 78.0)
    _add("forward", Vector2(vp.x - 120, vp.y - 130), "GO", 92.0)
    _add("back", Vector2(vp.x - 290, vp.y - 100), "BRK", 64.0)


func _add(action: String, pos: Vector2, text: String, radius: float) -> void:
    var tex := GradientTexture2D.new()
    tex.fill = GradientTexture2D.FILL_RADIAL
    tex.fill_from = Vector2(0.5, 0.5)
    tex.fill_to = Vector2(1.0, 0.5)
    tex.width = int(radius * 2.0)
    tex.height = int(radius * 2.0)
    var g := Gradient.new()
    g.offsets = PackedFloat32Array([0.0, 0.88, 0.94, 1.0])
    g.colors = PackedColorArray([
        Color(1, 1, 1, 0.20), Color(1, 1, 1, 0.20), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
    tex.gradient = g

    var btn := TouchScreenButton.new()
    btn.texture_normal = tex
    btn.position = pos - Vector2(radius, radius)
    btn.action = action
    btn.passby_press = true
    var shape := CircleShape2D.new()
    shape.radius = radius
    btn.shape = shape
    add_child(btn)

    var lbl := UI.label(text, int(radius * 0.5), Color(1, 1, 1, 0.9))
    lbl.position = pos - Vector2(radius * 0.5, radius * 0.35)
    lbl.custom_minimum_size = Vector2(radius, radius * 0.7)
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(lbl)
    _buttons.append(btn)


func release_all() -> void:
    for a in ["left", "right", "forward", "back"]:
        Input.action_release(a)
