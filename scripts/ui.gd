class_name UI
extends RefCounted
## Small UI factory: consistent flat, rounded, dark-navy / orange look.

const NAVY := Color(0.09, 0.11, 0.2, 0.92)
const NAVY_SOFT := Color(0.15, 0.18, 0.3, 0.95)
const ORANGE := Color(1.0, 0.6, 0.15)
const GREEN := Color(0.2, 0.75, 0.45)
const RED := Color(0.9, 0.3, 0.3)
const WHITE := Color(1, 1, 1)
const MUTED := Color(0.72, 0.76, 0.88)


static func box(color: Color, radius: int = 14, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = color
    sb.set_corner_radius_all(radius)
    sb.border_color = border
    sb.set_border_width_all(border_w)
    sb.content_margin_left = 18
    sb.content_margin_right = 18
    sb.content_margin_top = 10
    sb.content_margin_bottom = 10
    return sb


static func label(text: String, size: int = 22, color: Color = WHITE) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.add_theme_constant_override("outline_size", 4)
    l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
    return l


static func button(text: String, color: Color = ORANGE, size: int = 26) -> Button:
    var b := Button.new()
    b.text = text
    b.focus_mode = Control.FOCUS_NONE
    b.custom_minimum_size = Vector2(240, 64)
    b.add_theme_font_size_override("font_size", size)
    b.add_theme_color_override("font_color", WHITE)
    b.add_theme_color_override("font_hover_color", WHITE)
    b.add_theme_color_override("font_pressed_color", WHITE)
    b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
    b.add_theme_stylebox_override("normal", box(color, 16))
    b.add_theme_stylebox_override("hover", box(color.lightened(0.1), 16))
    b.add_theme_stylebox_override("pressed", box(color.darkened(0.2), 16))
    b.add_theme_stylebox_override("disabled", box(color.darkened(0.45), 16))
    return b


static func panel(color: Color = NAVY) -> PanelContainer:
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel", box(color, 20))
    return p


static func bar(value: float, color: Color, width: float = 200.0) -> ProgressBar:
    var pb := ProgressBar.new()
    pb.min_value = 0.0
    pb.max_value = 1.0
    pb.value = value
    pb.show_percentage = false
    pb.custom_minimum_size = Vector2(width, 16)
    pb.add_theme_stylebox_override("background", box(Color(0, 0, 0, 0.45), 8))
    pb.add_theme_stylebox_override("fill", box(color, 8))
    return pb


static func spacer(h: float = 8.0) -> Control:
    var c := Control.new()
    c.custom_minimum_size = Vector2(0, h)
    return c
