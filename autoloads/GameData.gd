extends Node

# ─────────────────────────────────────────────
#  GameData.gd  —  Autoload "GameData"
#  État global partagé entre toutes les scènes.
#  C'est le "cerveau" du jeu : il ne dessine rien, il ne gère aucun
#  bouton, il stocke juste la partie en cours (joueurs, scores, tour)
#  et les règles communes à tous les modes. Toutes les scènes
#  (MainMenu, Game, WinScreen) lisent/écrivent dans cet objet unique
#  via "GameData.xxx" car c'est un Autoload (singleton global).
# ─────────────────────────────────────────────

enum GameMode { MODE_301, MODE_501, CRICKET, FREE_SCORE }

# Les 7 numéros valables au Cricket : 15 à 20 + le Bull (25).
# Un lancer sur un autre numéro (1-14) ne compte pour rien en Cricket.
const CRICKET_NUMBERS: Array[int] = [15, 16, 17, 18, 19, 20, 25]

# ── Paramètres de la partie ──────────────────
var game_mode: GameMode = GameMode.MODE_501
var player_names: Array[String] = []

# Règle "sortie double" (301/501 uniquement) : si activée, un joueur ne
# peut gagner qu'en terminant exactement sur un double (D1..D20 ou Bull
# double = 50). Réglée depuis MainMenu, non réinitialisée par setup_game()
# pour qu'elle survive à un "Rejouer" (comme game_mode/player_names).
var double_out: bool = false

# ── État en cours ────────────────────────────
var players: Array[Dictionary] = []
var current_player_index: int  = 0
var round_number: int          = 1
var game_over: bool            = false
var winner_index: int          = -1

# ─────────────────────────────────────────────
#  Initialisation d'une partie
# ─────────────────────────────────────────────
## Appelée une seule fois par MainMenu.gd quand on clique sur "Jouer".
## Construit le tableau `players` avec un Dictionary par joueur contenant
## tous les compteurs nécessaires à TOUS les modes (même ceux non utilisés
## par le mode choisi restent à 0, ça évite les erreurs de clé manquante).
func setup_game(mode: GameMode, names: Array[String]) -> void:
	print("[GameData] setup_game() -> mode=%s, joueurs=%s" % [GameMode.keys()[mode], names])

	game_mode             = mode
	player_names          = names.duplicate()
	current_player_index  = 0
	round_number          = 1
	game_over             = false
	winner_index          = -1
	players.clear()

	# Le score de départ ne sert qu'aux modes 301/501 (compte à rebours).
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
		# Toutes les "marques" Cricket démarrent à 0 (rien de fermé).
		for n in CRICKET_NUMBERS:
			p["cricket_marks"][n] = 0
		players.append(p)

	print("[GameData] Partie prête : %d joueurs, score de départ = %d" % [players.size(), starting_score])

# ─────────────────────────────────────────────
#  Accesseurs
# ─────────────────────────────────────────────
func get_current_player() -> Dictionary:
	return players[current_player_index]

## Fait passer la main au joueur suivant. Comme les joueurs sont dans un
## tableau, on boucle avec un modulo (%) : après le dernier joueur, on
## revient à l'index 0, et c'est ce retour à 0 qui signale une nouvelle
## "manche" (round_number += 1).
func next_player() -> void:
	current_player_index = (current_player_index + 1) % players.size()
	if current_player_index == 0:
		round_number += 1
		print("[GameData] Nouvelle manche : %d" % round_number)

	print("[GameData] Au tour de : %s" % get_current_player()["name"])

# ─────────────────────────────────────────────
#  Utilitaires Cricket
# ─────────────────────────────────────────────

## Règle du Cricket : un numéro est "fermé" par un joueur dès qu'il a 3
## marques dessus (une marque = un simple, une double compte 2, une
## triple compte 3). Une fois qu'UN joueur a fermé un numéro, celui-ci
## ne lui rapporte plus de points, sauf si TOUS les adversaires l'ont
## aussi fermé (sinon il continue à marquer des points contre eux).
## Cette fonction sert justement à savoir si "tout le monde a fermé" un
## numéro donné, pour arrêter de compter les points dessus pour tout le monde.
func all_players_closed(number: int) -> bool:
	for p in players:
		if p["cricket_marks"].get(number, 0) < 3:
			return false
	return true

## Condition de victoire au Cricket : le joueur `idx` doit avoir fermé
## les 7 numéros ET avoir un score de points au moins égal à celui de
## chaque adversaire (sinon la partie continue même s'il a tout fermé,
## car il pourrait être derrière au score).
func cricket_win(idx: int) -> bool:
	var p := players[idx]
	# Condition 1 : tous les numéros doivent être fermés (3 marques chacun)
	for n in CRICKET_NUMBERS:
		if p["cricket_marks"][n] < 3:
			return false
	# Condition 2 : son score doit être >= à celui de tous les adversaires
	for i in players.size():
		if i != idx and players[i]["cricket_score"] > p["cricket_score"]:
			return false

	print("[GameData] cricket_win() -> %s remplit les conditions de victoire !" % p["name"])
	return true

# ─────────────────────────────────────────────
#  Réinitialisation (rejouer avec mêmes joueurs)
# ─────────────────────────────────────────────
## Relance une partie identique (même mode, mêmes joueurs, scores remis
## à zéro) : appelée depuis le bouton "Rejouer" de WinScreen.
func replay() -> void:
	print("[GameData] replay() -> on relance une partie avec les mêmes joueurs")
	setup_game(game_mode, player_names)
