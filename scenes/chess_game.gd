extends CanvasLayer

@export_category("Heart Assets Setup")
@export var full_heart: Texture2D

@export_category("Chess Individual Textures")
@export var pawn_tex: Texture2D
@export_category("Chess Individual Textures")
@export var knight_tex: Texture2D
@export_category("Chess Individual Textures")
@export var bishop_tex: Texture2D
@export_category("Chess Individual Textures")
@export var rook_tex: Texture2D
@export_category("Chess Individual Textures")
@export var queen_tex: Texture2D
@export_category("Chess Individual Textures")
@export var king_tex: Texture2D

@export_category("Chess Board Tile Textures")
@export var white_tile_tex: Texture2D
@export_category("Chess Board Tile Textures")
@export var dark_tile_tex: Texture2D
@export_category("Chess Board Tile Textures")
@export var board_border_tex: Texture2D

@onready var chess_grid = $CenterContainer/ChessBoardVisual/ChessGrid

var board_state: Array = []
var active_turn: String = "player"
var selected_tile: Vector2 = Vector2(-1, -1)
var game_over: bool = false

var white_king_moved: bool = false
var white_a_rook_moved: bool = false
var white_h_rook_moved: bool = false
var black_king_moved: bool = false
var black_a_rook_moved: bool = false
var black_h_rook_moved: bool = false

const PIECE_VALUES = { 0: 0, 1: 10, 2: 30, 3: 30, 4: 50, 5: 90, 6: 9000 }
var piece_textures: Dictionary = {}

# PERSPECTIVE OVERRIDE: Separate width and height dimensions to respect the 16x12 aspect ratio
const TILE_WIDTH: float = 96.0       # 16 pixels * 6x crisp scale
const TILE_HEIGHT: float = 72.0      # 12 pixels * 6x crisp scale

const BOARD_OFFSET_X: float = 96.0   # Adjust to match your board asset margins
const BOARD_OFFSET_Y: float = 144.0  # 24 pixels * 6x scale to align with the back stone stairs


func _ready() -> void:
	piece_textures = { 1: pawn_tex, 2: knight_tex, 3: bishop_tex, 4: rook_tex, 5: queen_tex, 6: king_tex }
	initialize_logical_matrix()
	generate_visual_grid_buttons()

func initialize_logical_matrix() -> void:
	# A perfect 8x8 grid matrix. 0 means an empty dungeon board square!
	board_state = [
		[-4, -2, -3, -5, -6, -3, -2, -4], # Row 0: Enemy Power Pieces
		[-1, -1, -1, -1, -1, -1, -1, -1], # Row 1: Enemy Pawns
		[ 0,  0,  0,  0,  0,  0,  0,  0], # Row 2: Empty
		[ 0,  0,  0,  0,  0,  0,  0,  0], # Row 3: Empty
		[ 0,  0,  0,  0,  0,  0,  0,  0], # Row 4: Empty
		[ 0,  0,  0,  0,  0,  0,  0,  0], # Row 5: Empty
		[ 1,  1,  1,  1,  1,  1,  1,  1], # Row 6: Player Pawns
		[ 4,  2,  3,  5,  6,  3,  2,  4]  # Row 7: Player Power Pieces
	]


func generate_visual_grid_buttons() -> void:
	for child in chess_grid.get_children(): child.queue_free()
	
	# LAYER 1: Draw the Board Borders Background first if it exists
	if board_border_tex:
		var border_rect = TextureRect.new()
		border_rect.texture = board_border_tex
		border_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# Dynamically adapt border scale to match squash math profiles
		border_rect.size = Vector2((TILE_WIDTH * 8) + (BOARD_OFFSET_X * 2), (TILE_HEIGHT * 8) + (BOARD_OFFSET_Y * 2))
		border_rect.position = Vector2.ZERO
		border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chess_grid.add_child(border_rect)
	
	# LAYER 2: Draw the Board Floor Tiles (Your custom 16x12 layout)
	for y in range(8):
		for x in range(8):
			var tile_pos = Vector2(BOARD_OFFSET_X + (x * TILE_WIDTH), BOARD_OFFSET_Y + (y * TILE_HEIGHT))
			var tile_sprite = TextureRect.new()
			tile_sprite.texture = white_tile_tex if (x + y) % 2 == 0 else dark_tile_tex
			tile_sprite.position = tile_pos
			tile_sprite.size = Vector2(TILE_WIDTH, TILE_HEIGHT) # Sets the tile to a 3D perspective rectangle
			tile_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tile_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			if (x + y) % 2 == 0:
				tile_sprite.modulate = Color("#f4eacc") # Warm Beige Tint
				
			chess_grid.add_child(tile_sprite)
			
	# LAYER 3: Draw Interactive Flat Selection Panels
	for y in range(8):
		for x in range(8):
			var tile_pos = Vector2(BOARD_OFFSET_X + (x * TILE_WIDTH), BOARD_OFFSET_Y + (y * TILE_HEIGHT))
			var btn = Button.new()
			btn.position = tile_pos
			btn.size = Vector2(TILE_WIDTH, TILE_HEIGHT) # Matches mouse clicks to squash rectangles
			
			var is_legal: bool = false
			if selected_tile != Vector2(-1, -1) and not game_over:
				is_legal = Vector2(x, y) in get_strict_legal_moves(selected_tile, board_state)
			
			if is_legal: btn.self_modulate = Color(0, 1, 0, 0.4)
			else: btn.flat = true
				
			btn.pressed.connect(_on_tile_clicked.bind(Vector2(x, y)))
			chess_grid.add_child(btn)

	# LAYER 4: Draw Overlapping Pieces (Preserving tall proportions)
	for y in range(8):
		for x in range(8):
			var pid = board_state[y][x]
			if pid == 0: continue
			
			var piece_pos = Vector2(BOARD_OFFSET_X + (x * TILE_WIDTH), BOARD_OFFSET_Y + (y * TILE_HEIGHT))
			var img = TextureRect.new()
			img.texture = piece_textures[abs(pid)]
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			
			# FIX: Keep pieces matching the width of the squares, but draw them taller 
			# so they stick out of their slots and overlap the rows behind them!
			img.size = Vector2(TILE_WIDTH, TILE_WIDTH * 1.5) 
			img.position = piece_pos - Vector2(0, (TILE_WIDTH * 1.5) - TILE_HEIGHT) 
			img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			img.modulate = Color("#f4eacc") if pid > 0 else Color("#ff4a4a")
			chess_grid.add_child(img)


func _on_tile_clicked(coords: Vector2) -> void:
	if active_turn != "player" or game_over: return
	var piece = board_state[coords.y][coords.x]
	
	if piece > 0:
		selected_tile = coords
		print("Selected piece at: ", coords)
		generate_visual_grid_buttons()
		return
		
	if selected_tile != Vector2(-1, -1):
		if coords in get_strict_legal_moves(selected_tile, board_state):
			execute_grid_move(selected_tile, coords)
			selected_tile = Vector2(-1, -1)
			
			if check_game_over_states(-1): return
			
			active_turn = "ai"
			trigger_ai_turn()
		else:
			print("Invalid Move or King remains in Check!")
			selected_tile = Vector2(-1, -1)
			generate_visual_grid_buttons()

func trigger_ai_turn() -> void:
	if game_over: return
	await get_tree().create_timer(0.5).timeout
	var best_move = minimax_decision(board_state, 2)
	if best_move.size() > 0:
		execute_grid_move(best_move["from"], best_move["to"])
		
	check_game_over_states(1)
	active_turn = "player"
func get_strict_legal_moves(pos: Vector2, current_board: Array) -> Array:
	var side = sign(current_board[pos.y][pos.x])
	var pseudo_moves = calculate_basic_piece_steps(pos, current_board)
	var strict_moves = []
	
	for target in pseudo_moves:
		var sim_board = clone_board(current_board)
		simulate_matrix_move(sim_board, pos, target)
		if not is_king_targeted(side, sim_board):
			strict_moves.append(target)
	return strict_moves

func is_king_targeted(side_sign: int, board: Array) -> bool:
	var king_pos = Vector2(-1, -1)
	for y in range(8):
		for x in range(8):
			if board[y][x] == (6 * side_sign):
				king_pos = Vector2(x, y)
				break
		if king_pos != Vector2(-1, -1): break
		
	if king_pos == Vector2(-1, -1): return true
	
	var opponent_sign = -side_sign
	for y in range(8):
		for x in range(8):
			if sign(board[y][x]) == opponent_sign:
				if king_pos in calculate_basic_piece_steps(Vector2(x, y), board):
					return true
	return false

func check_game_over_states(side_sign: int) -> bool:
	var total_moves = 0
	for y in range(8):
		for x in range(8):
			if sign(board_state[y][x]) == side_sign:
				total_moves += get_strict_legal_moves(Vector2(x, y), board_state).size()
				
	if total_moves == 0:
		game_over = true
		if is_king_targeted(side_sign, board_state):
			var winner = "Computer AI Wins!" if side_sign == 1 else "You Win! Checkmate!"
			print("CHECKMATE! ", winner)
			display_end_popup(winner)
		else:
			print("STALEMATE! Game Drawn.")
			display_end_popup("Stalemate! Game Drawn.")
		return true
	return false

func display_end_popup(text_message: String) -> void:
	var win_label = Label.new()
	win_label.text = "\n\n" + text_message + "\n[Press ESC to Return]"
	win_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	win_label.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
	win_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_label.modulate = Color("#ffffff")
	add_child(win_label)

func minimax_decision(current_board: Array, depth: int) -> Dictionary:
	var moves = []
	for y in range(8):
		for x in range(8):
			if current_board[y][x] < 0:
				for target in get_strict_legal_moves(Vector2(x, y), current_board):
					moves.append({"from": Vector2(x, y), "to": target})
					
	if moves.size() == 0: return {}
	var best_move = moves[randi() % moves.size()]
	var best_score = -999999
	var alpha = -999999
	var beta = 999999
	
	moves.sort_custom(func(a, b): return abs(current_board[a["to"].y][a["to"].x]) > abs(current_board[b["to"].y][b["to"].x]))

	for m in moves:
		var temp_board = clone_board(current_board)
		simulate_matrix_move(temp_board, m["from"], m["to"])
		var score = minimax_value(temp_board, depth - 1, alpha, beta, false)
		if score > best_score:
			best_score = score
			best_move = m
		alpha = max(alpha, score)
	return best_move

func minimax_value(board: Array, depth: int, alpha: float, beta: float, is_ai_turn: bool) -> float:
	if depth == 0: return evaluate_board_fitness(board)
	var side = -1 if is_ai_turn else 1
	
	var moves = []
	for y in range(8):
		for x in range(8):
			if sign(board[y][x]) == side:
				for target in get_strict_legal_moves(Vector2(x, y), board):
					moves.append({"from": Vector2(x, y), "to": target})
					
	if moves.size() == 0: return evaluate_board_fitness(board)
	
	if is_ai_turn:
		var max_eval = -999999
		for m in moves:
			var next_board = clone_board(board)
			simulate_matrix_move(next_board, m["from"], m["to"])
			var evaluation = minimax_value(next_board, depth - 1, alpha, beta, false)
			max_eval = max(max_eval, evaluation)
			alpha = max(alpha, evaluation)
			if beta <= alpha: break
		return max_eval
	else:
		var min_eval = 999999
		for m in moves:
			var next_board = clone_board(board)
			simulate_matrix_move(next_board, m["from"], m["to"])
			var evaluation = minimax_value(next_board, depth - 1, alpha, beta, true)
			min_eval = min(min_eval, evaluation)
			beta = min(beta, evaluation)
			if beta <= alpha: break
		return min_eval

func evaluate_board_fitness(board: Array) -> float:
	var total_score: float = 0.0
	for y in range(8):
		for x in range(8):
			var pid = board[y][x]
			if pid == 0: continue
			var value = PIECE_VALUES[abs(pid)]
			var positional_bonus = 0.0
			if y >= 2 and y <= 5 and x >= 2 and x <= 5: positional_bonus += 1.5
			if abs(pid) == 1:
				positional_bonus += (y * 0.5) if sign(pid) == -1 else ((7 - y) * 0.5)
			if sign(pid) == -1: total_score += (value + positional_bonus)
			else: total_score -= (value + positional_bonus)
	return total_score

func calculate_basic_piece_steps(pos: Vector2, board: Array) -> Array:
	var targets = []
	var pid = board[pos.y][pos.x]
	var team = sign(pid)
	var type = abs(pid)

	match type:
		1:
			var dir = -1 if team == 1 else 1
			if pos.y + dir >= 0 and pos.y + dir < 8 and board[pos.y + dir][pos.x] == 0:
				targets.append(Vector2(pos.x, pos.y + dir))
				if pos.y == (6 if team == 1 else 1) and board[pos.y + (dir * 2)][pos.x] == 0:
					targets.append(Vector2(pos.x, pos.y + (dir * 2)))
			for dx in [pos.x - 1, pos.x + 1]:
				if dx >= 0 and dx < 8 and pos.y + dir >= 0 and pos.y + dir < 8:
					if board[pos.y + dir][dx] != 0 and sign(board[pos.y + dir][dx]) != team:
						targets.append(Vector2(dx, pos.y + dir))
		2:
			for o in [Vector2(1,2),Vector2(1,-2),Vector2(-1,2),Vector2(-1,-2),Vector2(2,1),Vector2(2,-1),Vector2(-2,1),Vector2(-2,-1)]:
				var t = pos + o
				if t.x >= 0 and t.x < 8 and t.y >= 0 and t.y < 8:
					if board[t.y][t.x] == 0 or sign(board[t.y][t.x]) != team: targets.append(t)
		3: targets.append_array(slide(pos, [Vector2(1,1),Vector2(1,-1),Vector2(-1,1),Vector2(-1,-1)], team, board)) 
		4: targets.append_array(slide(pos, [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1)], team, board)) 
		5: targets.append_array(slide(pos, [Vector2(1,1),Vector2(1,-1),Vector2(-1,1),Vector2(-1,-1),Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1)], team, board)) 
		6:
			for d in [Vector2(1,1),Vector2(1,-1),Vector2(-1,1),Vector2(-1,-1),Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1)]:
				var t = pos + d
				if t.x >= 0 and t.x < 8 and t.y >= 0 and t.y < 8:
					if board[t.y][t.x] == 0 or sign(board[t.y][t.x]) != team: targets.append(t)
			if team == 1 and not white_king_moved:
				if not white_h_rook_moved and board[7][5] == 0 and board[7][6] == 0: targets.append(Vector2(6, 7))
				if not white_a_rook_moved and board[7][1] == 0 and board[7][2] == 0 and board[7][3] == 0: targets.append(Vector2(2, 7))
			elif team == -1 and not black_king_moved:
				if not black_h_rook_moved and board[0][5] == 0 and board[0][6] == 0: targets.append(Vector2(6, 0))
				if not black_a_rook_moved and board[0][1] == 0 and board[0][2] == 0 and board[0][3] == 0: targets.append(Vector2(2, 0))
	return targets

func slide(start: Vector2, dirs: Array, team: int, board: Array) -> Array:
	var list = []
	for d in dirs:
		var step = start + d
		while step.x >= 0 and step.x < 8 and step.y >= 0 and step.y < 8:
			var p = board[step.y][step.x]
			if p == 0: list.append(step)
			else:
				if sign(p) != team: list.append(step)
				break
			step += d
	return list

func simulate_matrix_move(board: Array, from: Vector2, to: Vector2) -> void:
	var p = board[from.y][from.x]
	board[from.y][from.x] = 0
	if p == 1 and to.y == 0: p = 5
	elif p == -1 and to.y == 7: p = -5
	board[to.y][to.x] = p

func execute_grid_move(from: Vector2, to: Vector2) -> void:
	var p = board_state[from.y][from.x]
	
	if abs(p) == 6: 
		if p == 6 and from == Vector2(4, 7):
			if to == Vector2(6, 7): 
				board_state[7][7] = 0
				board_state[7][5] = 4
			elif to == Vector2(2, 7): 
				board_state[7][0] = 0
				board_state[7][3] = 4
			white_king_moved = true
		elif p == -6 and from == Vector2(4, 0):
			if to == Vector2(6, 0): 
				board_state[0][7] = 0
				board_state[0][5] = -4
			elif to == Vector2(2, 0): 
				board_state[0][0] = 0
				board_state[0][3] = -4
			black_king_moved = true

	if p == 4: 
		if from == Vector2(0, 7): white_a_rook_moved = true
		if from == Vector2(7, 7): white_h_rook_moved = true
	elif p == -4: 
		if from == Vector2(0, 0): black_a_rook_moved = true
		if from == Vector2(7, 0): black_h_rook_moved = true

	board_state[from.y][from.x] = 0
	if p == 1 and to.y == 0: p = 5
	elif p == -1 and to.y == 7: p = -5
		
	board_state[to.y][to.x] = p
	generate_visual_grid_buttons()

func clone_board(original: Array) -> Array:
	var copy = []
	for row in original: copy.append(row.duplicate())
	return copy

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_cancel"): queue_free()
