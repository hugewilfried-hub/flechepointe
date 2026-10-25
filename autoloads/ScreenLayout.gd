extends Node

# ─────────────────────────────────────────────
#  ScreenLayout.gd — Autoload "ScreenLayout"
#  Adapte l'appli à l'orientation de l'écran : portrait sur téléphone
#  (base 480x960), paysage sur grand écran type Samsung DeX 1920x1080
#  (base 1280x720, soit un zoom x1.5 pour rester lisible de loin).
#  Les scènes n'ont qu'à écouter `layout_changed` et appeler
#  is_landscape() / constrain_width().
# ─────────────────────────────────────────────

signal layout_changed(landscape: bool)

const PORTRAIT_BASE  := Vector2i(480, 960)
const LANDSCAPE_BASE := Vector2i(1280, 720)

var _landscape: bool = false

func _ready() -> void:
	var win := get_window()
	win.size_changed.connect(_update)
	_update()

func is_landscape() -> bool:
	return _landscape

## Choisit la base de mise à l'échelle selon que la fenêtre est plus large
## que haute, et prévient les scènes si l'orientation vient de changer.
func _update() -> void:
	var win  := get_window()
	var wsize: Vector2i = win.size
	var landscape := wsize.x > wsize.y
	win.content_scale_size = LANDSCAPE_BASE if landscape else PORTRAIT_BASE
	if landscape != _landscape:
		_landscape = landscape
		print("[ScreenLayout] Orientation -> %s" % ("paysage" if landscape else "portrait"))
		layout_changed.emit(landscape)

## Centre `control` (un Control ancré plein écran) dans une colonne de
## largeur max `max_width` : évite que menus et formulaires s'étirent sur
## toute la largeur d'un grand écran. `max_width <= 0` = pleine largeur.
func constrain_width(control: Control, max_width: float) -> void:
	if max_width <= 0.0:
		control.anchor_left  = 0.0
		control.anchor_right = 1.0
		control.offset_left  = 0
		control.offset_right = 0
	else:
		# Ancré au milieu : la largeur reste fixe même si la fenêtre est
		# redimensionnée.
		control.anchor_left  = 0.5
		control.anchor_right = 0.5
		control.offset_left  = -max_width / 2.0
		control.offset_right =  max_width / 2.0
