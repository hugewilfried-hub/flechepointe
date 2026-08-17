extends Control

# ─────────────────────────────────────────────
#  MainMenu.gd
#  Écran de configuration avant de lancer une partie : choix du mode,
#  du nombre de joueurs et de leurs noms. Ne touche à GameData qu'au
#  moment de démarrer (_on_start) : tant qu'on est sur cet écran, tout
#  est stocké dans des variables locales (_mode, _player_count).
# ─────────────────────────────────────────────

const GAME_SCENE := "res://scenes/Game.tscn"

@onready var btn_301:           Button        = $VBoxContainer/mode_box/btn_301
@onready var btn_501:           Button        = $VBoxContainer/mode_box/btn_501
@onready var btn_cricket:       Button        = $VBoxContainer/mode_box/bnt_cricket
@onready var btn_free:          Button        = $VBoxContainer/mode_box/bnt_free
@onready var double_out_row:    HFlowContainer = $VBoxContainer/double_out_row
@onready var chk_double_out:    Button        = $VBoxContainer/double_out_row/chk_double_out
@onready var btn_minus:         Button        = $VBoxContainer/joueur_row/btn_minus
@onready var btn_plus:          Button        = $VBoxContainer/joueur_row/btn_plus
@onready var lbl_count:         Label         = $VBoxContainer/joueur_row/lbl_count
@onready var names_container:   VBoxContainer = $VBoxContainer/VBoxContainer
@onready var btn_start:         Button        = $VBoxContainer/btn_start

var _mode: GameData.GameMode = GameData.GameMode.MODE_501
var _player_count: int = 2
var _double_out: bool = false
var _switch_knob: ImageTexture

const MIN_PLAYERS := 2
const MAX_PLAYERS := 8

# ─────────────────────────────────────────────
func _ready() -> void:
	SafeArea.apply_bottom_spacer($VBoxContainer)

	btn_301.pressed.connect(func(): _set_mode(GameData.GameMode.MODE_301))
	btn_501.pressed.connect(func(): _set_mode(GameData.GameMode.MODE_501))
	btn_cricket.pressed.connect(func(): _set_mode(GameData.GameMode.CRICKET))
	btn_free.pressed.connect(func(): _set_mode(GameData.GameMode.FREE_SCORE))

	btn_minus.pressed.connect(func(): _change_count(-1))
	btn_plus.pressed.connect(func():  _change_count(+1))
	btn_start.pressed.connect(_on_start)
	chk_double_out.toggled.connect(_on_double_out_toggled)

	# Pré-remplir si on revient du WinScreen (rejouer)
	if GameData.player_names.size() >= 2:
		_player_count = GameData.player_names.size()
		_mode         = GameData.game_mode
		_double_out   = GameData.double_out

	chk_double_out.button_pressed = _double_out
	_refresh_double_out_style()
	_rebuild_names()
	_refresh_mode_buttons()
	_refresh_count_label()

# ─────────────────────────────────────────────
#  Mode de jeu
# ─────────────────────────────────────────────
func _set_mode(mode: GameData.GameMode) -> void:
	print("[MainMenu] Mode sélectionné : %s" % GameData.GameMode.keys()[mode])
	_mode = mode
	_refresh_mode_buttons()

func _refresh_mode_buttons() -> void:
	for btn in [btn_301, btn_501, btn_cricket, btn_free]:
		btn.theme_type_variation = &"SegButton"

	match _mode:
		GameData.GameMode.MODE_301:     btn_301.theme_type_variation     = &"SegButtonSelected"
		GameData.GameMode.MODE_501:     btn_501.theme_type_variation     = &"SegButtonSelected"
		GameData.GameMode.CRICKET:      btn_cricket.theme_type_variation = &"SegButtonSelected"
		GameData.GameMode.FREE_SCORE:   btn_free.theme_type_variation    = &"SegButtonSelected"

	# La sortie double n'a de sens qu'en 301/501 (compte à rebours).
	double_out_row.visible = (_mode == GameData.GameMode.MODE_301 or _mode == GameData.GameMode.MODE_501)

# ─────────────────────────────────────────────
#  Nombre de joueurs
# ─────────────────────────────────────────────
## +1/-1 joueur, borné entre MIN_PLAYERS et MAX_PLAYERS. Reconstruit
## aussitôt les champs de nom (_rebuild_names) pour ajouter/retirer une ligne.
func _change_count(delta: int) -> void:
	_player_count = clamp(_player_count + delta, MIN_PLAYERS, MAX_PLAYERS)
	print("[MainMenu] Nombre de joueurs -> %d" % _player_count)
	_rebuild_names()
	_refresh_count_label()

func _on_double_out_toggled(pressed: bool) -> void:
	print("[MainMenu] Sortie double -> %s" % pressed)
	_double_out = pressed
	_refresh_double_out_style()

## Switch dessiné à la main (piste colorée + curseur) plutôt que de
## s'appuyer sur les icônes natives "on"/"off" d'un CheckButton : sur ce
## contrôle, les surcharges de thème par instance (icône ET stylebox liés
## à l'état coché) sont ignorées par le moteur au rendu — testé avec une
## icône identique forcée sur les deux états, toujours rendue différemment.
## `chk_double_out` est donc un Button en toggle_mode : sa piste (StyleBox)
## et son curseur (icône simple, sans dualité on/off) sont 100% sous notre
## contrôle, ce qui garantit un rendu strictement symétrique entre les
## deux états, seule la couleur de piste changeant (vert/rouge).
func _refresh_double_out_style() -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.35, 0.85, 0.45) if _double_out else Color(0.9, 0.35, 0.35)
	track.set_corner_radius_all(12)
	track.content_margin_left = 3
	track.content_margin_right = 3
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		chk_double_out.add_theme_stylebox_override(state, track)
	if _switch_knob == null:
		_switch_knob = _build_switch_knob()
	chk_double_out.icon = _switch_knob
	chk_double_out.expand_icon = false
	chk_double_out.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT if _double_out else HORIZONTAL_ALIGNMENT_LEFT

## Génère le curseur (petit disque blanc) du switch.
func _build_switch_knob(diameter: int = 18) -> ImageTexture:
	var image := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var radius := diameter / 2.0
	var center := Vector2(radius, radius)
	for y in diameter:
		for x in diameter:
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(center)
			image.set_pixel(x, y, Color(1, 1, 1, 1) if dist <= radius else Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(image)

func _refresh_count_label() -> void:
	lbl_count.text = str(_player_count)
	btn_minus.disabled = (_player_count <= MIN_PLAYERS)
	btn_plus.disabled  = (_player_count >= MAX_PLAYERS)

## Reconstruit la liste de champs "Joueur X" à partir de _player_count.
## Comme pour ScorePanel, on détruit tout et on recrée : plus simple à
## maintenir que d'ajouter/retirer une ligne au bon endroit.
func _rebuild_names() -> void:
	# Supprimer les anciens champs
	for child in names_container.get_children():
		child.queue_free()

	# Créer un LineEdit par joueur
	for i in _player_count:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER

		var lbl := Label.new()
		lbl.text             = "J%d" % (i + 1)
		lbl.custom_minimum_size = Vector2(28, 0)
		row.add_child(lbl)

		var edit := LineEdit.new()
		edit.name            = "Player%d" % i
		edit.placeholder_text = "Joueur %d" % (i + 1)
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Pré-remplir si on rejoue
		if i < GameData.player_names.size():
			edit.text = GameData.player_names[i]

		row.add_child(edit)
		names_container.add_child(row)

# ─────────────────────────────────────────────
#  Démarrage
# ─────────────────────────────────────────────
## Lit le texte de chaque LineEdit (nom vide -> "Joueur N" par défaut),
## initialise la partie dans GameData, puis change de scène vers Game.tscn.
## C'est le SEUL endroit où MainMenu écrit dans GameData.
func _on_start() -> void:
	var names: Array[String] = []
	for i in _player_count:
		var row  := names_container.get_child(i)
		var edit := row.get_node("Player%d" % i) as LineEdit
		var n    := edit.text.strip_edges()
		names.append(n if n != "" else "Joueur %d" % (i + 1))

	print("[MainMenu] Démarrage de la partie : mode=%s, joueurs=%s, sortie double=%s" % [GameData.GameMode.keys()[_mode], names, _double_out])
	GameData.double_out = _double_out
	GameData.setup_game(_mode, names)
	get_tree().change_scene_to_file(GAME_SCENE)
