extends Node

# ─────────────────────────────────────────────
#  GameData.gd  —  Autoload "GameData"
#  État global partagé entre toutes les scènes
# ─────────────────────────────────────────────

enum GameMode { MODE_301, MODE_501, CRICKET, FREE_SCORE }

const CRICKET_NUMBERS: Array[int] = [15, 16, 17, 18, 19, 20, 25]

# ── Paramètres de la partie ──────────────────
var game_mode: GameMode = GameMode.MODE_501
var player_names: Array[String] = []

# ── État en cours ────────────────────────────
var players: Array[Dictionary] = []
var current_player_index: int  = 0
var round_number: int          = 1
var game_over: bool            = false
var winner_index: int          = -1

# ─────────────────────────────────────────────
#  Initialisation d'une partie
# ─────────────────────────────────────────────
func setup_game(mode: GameMode, names: Array[String]) -> void:
	game_mode             = mode
	player_names          = names.duplicate()
	current_player_index  = 0
	round_number          = 1
	game_over             = false
	winner_index          = -1
	players.clear()

	var starting_score := 501
	if mode == GameMode.MODE_301:
		starting_score = 301

	for pname in names:
		var p: Dictionary = {
			"name":          pname,
			"score":         starting_score,  # 301 / 501
			"free_score":    0,               # Score libre
			"cricket_marks": {},              # {numéro: int 0..3}
			"cricket_score": 0,               # Points marqués en Cricket
			"history":       [],              # Historique des tours
		}
		for n in CRICKET_NUMBERS:
			p["cricket_marks"][n] = 0
		players.append(p)

# ─────────────────────────────────────────────
#  Accesseurs
# ─────────────────────────────────────────────
func get_current_player() -> Dictionary:
	return players[current_player_index]

func next_player() -> void:
	current_player_index = (current_player_index + 1) % players.size()
	if current_player_index == 0:
		round_number += 1

# ─────────────────────────────────────────────
#  Utilitaires Cricket
# ─────────────────────────────────────────────

## Renvoie true si TOUS les joueurs ont fermé ce numéro
func all_players_closed(number: int) -> bool:
	for p in players:
		if p["cricket_marks"].get(number, 0) < 3:
			return false
	return true

## Renvoie true si le joueur idx remplit les conditions de victoire Cricket
func cricket_win(idx: int) -> bool:
	var p := players[idx]
	# Tous les numéros fermés
	for n in CRICKET_NUMBERS:
		if p["cricket_marks"][n] < 3:
			return false
	# Score >= tous les adversaires
	for i in players.size():
		if i != idx and players[i]["cricket_score"] > p["cricket_score"]:
			return false
	return true

# ─────────────────────────────────────────────
#  Réinitialisation (rejouer avec mêmes joueurs)
# ─────────────────────────────────────────────
func replay() -> void:
	setup_game(game_mode, player_names)
