extends Control

# ─────────────────────────────────────────────
#  DartboardInput.gd
#  Cible visuelle + détection des zones cliquées
#  Signal émis : dart_thrown(number, multiplier)
# ─────────────────────────────────────────────

signal dart_thrown(number: int, multiplier: int)

## Activer pour assombrir les numéros non-Cricket
@export var cricket_mode: bool = false

# Ordre des numéros sur une vraie cible (sens horaire depuis le haut)
const NUMBERS: Array[int] = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]

# ── Rayons (fraction du rayon total de la cible) ─────────────────────────────
const R_BULLSEYE  := 0.050  # Double Bull  (50 pts)
const R_BULL      := 0.110  # Single Bull  (25 pts)
const R_TRIPLE_S  := 0.390  # Début anneau Triple
const R_TRIPLE_E  := 0.455  # Fin   anneau Triple
const R_DOUBLE_S  := 0.670  # Début anneau Double
const R_DOUBLE_E  := 0.740  # Fin   anneau Double  ← bord jouable

# ── Couleurs ─────────────────────────────────────────────────────────────────
const COL_DARK    := Color(0.10, 0.10, 0.10)
const COL_LIGHT   := Color(0.88, 0.82, 0.72)
const COL_RED     := Color(0.82, 0.14, 0.10)
const COL_GREEN   := Color(0.10, 0.56, 0.22)
const COL_BG      := Color(0.06, 0.06, 0.06)
const COL_WIRE    := Color(0.55, 0.50, 0.35, 0.7)

var _center: Vector2
var _radius: float

# ─────────────────────────────────────────────
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_dims()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_dims()
		queue_redraw()

func _update_dims() -> void:
	_center = size / 2.0
	_radius = min(size.x, size.y) / 2.0 * 0.92

# ─────────────────────────────────────────────
#  Dessin
# ─────────────────────────────────────────────
func _draw() -> void:
	if _radius <= 0:
		return
	# Fond noir
	draw_circle(_center, _radius * (R_DOUBLE_E + 0.06), COL_BG)
	_draw_sectors()
	_draw_bull()
	_draw_wires()
	_draw_numbers()

func _draw_sectors() -> void:
	var seg := TAU / 20.0

	for i in 20:
		var a0 := -PI / 2.0 - seg / 2.0 + i * seg
		var a1 := a0 + seg
		var even := (i % 2 == 0)

		# Atténuation visuelle pour mode Cricket
		var is_cricket := NUMBERS[i] in GameData.CRICKET_NUMBERS
		var dim := 1.0
		if cricket_mode and not is_cricket:
			dim = 0.35

		var c_single: Color = (COL_DARK  if even else COL_LIGHT) * Color(dim, dim, dim, 1.0)
		var c_score:  Color = (COL_RED   if even else COL_GREEN)  * Color(dim, dim, dim, 1.0)

		# Simple intérieur
		_draw_annular_sector(_center, _radius * R_BULL,     _radius * R_TRIPLE_S, a0, a1, c_single)
		# Anneau Triple
		_draw_annular_sector(_center, _radius * R_TRIPLE_S, _radius * R_TRIPLE_E, a0, a1, c_score)
		# Simple extérieur
		_draw_annular_sector(_center, _radius * R_TRIPLE_E, _radius * R_DOUBLE_S, a0, a1, c_single)
		# Anneau Double
		_draw_annular_sector(_center, _radius * R_DOUBLE_S, _radius * R_DOUBLE_E, a0, a1, c_score)

func _draw_annular_sector(
		center: Vector2, r_in: float, r_out: float,
		a0: float, a1: float, color: Color) -> void:
	const STEPS := 12
	var pts := PackedVector2Array()
	pts.resize((STEPS + 1) * 2)
	for j in (STEPS + 1):
		var t: float = float(j) / float(STEPS)
		var a: float = lerp(a0, a1, t)
		pts[j]                         = center + Vector2(cos(a), sin(a)) * r_out
		pts[STEPS + 1 + (STEPS - j)]   = center + Vector2(cos(a), sin(a)) * r_in
	draw_colored_polygon(pts, color)

func _draw_bull() -> void:
	var dim_bull := 1.0
	if cricket_mode:
		dim_bull = 1.0  # Bull toujours visible en Cricket
	draw_circle(_center, _radius * R_BULL,     COL_GREEN * Color(dim_bull, dim_bull, dim_bull, 1.0))
	draw_circle(_center, _radius * R_BULLSEYE, COL_RED)

func _draw_wires() -> void:
	# Lignes de séparation entre secteurs (fil métallique)
	var seg := TAU / 20.0
	for i in 20:
		var a := -PI / 2.0 - seg / 2.0 + i * seg
		var dir := Vector2(cos(a), sin(a))
		draw_line(_center + dir * (_radius * R_BULL),
				  _center + dir * (_radius * R_DOUBLE_E),
				  COL_WIRE, 1.0)
	# Cercles des anneaux
	for r_frac in [R_BULL, R_TRIPLE_S, R_TRIPLE_E, R_DOUBLE_S, R_DOUBLE_E]:
		_draw_circle_outline(_center, _radius * r_frac, COL_WIRE, 1.0)

func _draw_circle_outline(center: Vector2, radius: float, color: Color, width: float) -> void:
	const SEGS := 64
	for i in SEGS:
		var a0 := TAU * i / SEGS
		var a1 := TAU * (i + 1) / SEGS
		draw_line(center + Vector2(cos(a0), sin(a0)) * radius,
				  center + Vector2(cos(a1), sin(a1)) * radius,
				  color, width)

func _draw_numbers() -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = clamp(int(_radius * 0.135), 11, 30)
	var seg       := TAU / 20.0

	for i in 20:
		var angle  := -PI / 2.0 + i * seg
		var num_r  := _radius * (R_DOUBLE_E + 0.115)
		var pos    := _center + Vector2(cos(angle), sin(angle)) * num_r
		var text   := str(NUMBERS[i])
		var tw     := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

		var is_cricket := NUMBERS[i] in GameData.CRICKET_NUMBERS
		var col := Color.WHITE
		if cricket_mode and not is_cricket:
			col = Color(0.4, 0.4, 0.4)

		draw_string(font, pos - Vector2(tw / 2.0, -float(font_size) * 0.33),
					text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)

# ─────────────────────────────────────────────
#  Détection de clic / touch
# ─────────────────────────────────────────────
func _gui_input(event: InputEvent) -> void:
	var pressed := false
	var click_pos := Vector2.ZERO

	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed   = true
			click_pos = event.position
	elif event is InputEventScreenTouch:
		if event.pressed:
			pressed   = true
			click_pos = event.position

	if not pressed:
		return

	var result: Variant = _hit_test(click_pos)
	if result != null:
		accept_event()
		dart_thrown.emit(result["number"], result["multiplier"])

func _hit_test(pos: Vector2) -> Variant:
	var diff  := pos - _center
	var frac  := diff.length() / _radius
	var angle := atan2(diff.y, diff.x)

	# ── Zone Bull ────────────────────────────
	if frac <= R_BULLSEYE:
		return {"number": 25, "multiplier": 2}
	if frac <= R_BULL:
		return {"number": 25, "multiplier": 1}

	# ── Hors cible ───────────────────────────
	if frac > R_DOUBLE_E + 0.02:
		return null

	# ── Secteur numéroté ─────────────────────
	var seg        := TAU / 20.0
	var offset     := fposmod(angle + PI / 2.0 + seg / 2.0, TAU)
	var sector_idx := int(offset / seg) % 20
	var number     := NUMBERS[sector_idx]

	# ── Multiplicateur ───────────────────────
	var mult := 0
	if   frac <= R_TRIPLE_S: mult = 1
	elif frac <= R_TRIPLE_E: mult = 3
	elif frac <= R_DOUBLE_S: mult = 1
	elif frac <= R_DOUBLE_E: mult = 2

	if mult == 0:
		return null

	return {"number": number, "multiplier": mult}
