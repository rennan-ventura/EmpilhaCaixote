extends Node2D

# --- Configurações do Grid ---
const ROWS = 6
const COLS = 7
const CELL_SIZE = 64  # Tamanho em pixels de cada célula
const GRID_ORIGIN = Vector2(376, 281)  # Posição (0,0) na tela

# --- Peças e Boxes ---
var box_instance = preload("res://scripts/box.gd")
var boxes = []

var box_width = 64.0
var screen_width = 1200
var columns = 6
var left_offset = (screen_width - (columns * box_width)) / 2
var right_offset = left_offset + columns * box_width

# --- Board Visual (Matriz 2D que mapeia peças na tela) ---
var board_visual = []  # [row][col] = Node referente à peça naquela posição

var can_drop = true
var server_handle

@export var box: PackedScene = preload("res://scenes/box.tscn")

# ========================================
# INICIALIZAÇÃO
# ========================================

func _ready() -> void:
	var player_container = $PlayerContainer
	var mp_manager = get_node("/root/MultiplayerManager")
	if mp_manager and mp_manager.has_method("set_player_container"):
		mp_manager.set_player_container(player_container)
		print("✓ PlayerContainer registrado no MultiplayerManager")
	
	server_handle = get_node("/root/WebSocketClient")
	server_handle.connect("box_drop", Callable(self, "_on_box_drop"))
	
	# NOVO: Conectar ao signal de atualização do board
	server_handle.connect("update_board", Callable(self, "_on_update_board"))
	
	# Inicializa a matriz visual vazia
	initialize_board_visual()
	
	print("✓ Cenario pronto com grid 6x7")

func _process(_delta: float) -> void:
	pass

# ========================================
# INICIALIZAÇÃO DO GRID
# ========================================

func initialize_board_visual() -> void:
	"""Cria a matriz 2D vazia (6x7) para armazenar referências às peças"""
	board_visual.clear()
	for row in range(ROWS):
		var row_array = []
		for col in range(COLS):
			row_array.append(null)  # Sem peça inicialmente
		board_visual.append(row_array)
	print("✓ Board visual inicializado (6x7)")

# ========================================
# CALCULAR POSIÇÃO VISUAL
# ========================================

func get_cell_position(row: int, col: int) -> Vector2:
	"""Retorna a posição visual (em pixels) para uma célula [row][col]"""
	var pos_x = GRID_ORIGIN.x + (col * CELL_SIZE)
	var pos_y = GRID_ORIGIN.y + (row * CELL_SIZE)
	return Vector2(pos_x, pos_y)

# ========================================
# CRIAR E GERENCIAR PEÇAS
# ========================================

func create_piece(row: int, col: int, color: String) -> Node2D:
	"""Cria uma nova peça na posição [row][col] com a cor especificada"""
	var piece = box.instantiate()
	piece.position = get_cell_position(row, col)
	
	# Define a cor
	match color:
		"red":
			piece.modulate = Color.LIGHT_CORAL
		"blue":
			piece.modulate = Color.LIGHT_BLUE
		_:
			piece.modulate = Color.WHITE
	
	# Adiciona à cena
	add_child(piece)
	boxes.append(piece)
	return piece

func remove_piece_at(row: int, col: int) -> void:
	"""Remove a peça na posição [row][col]"""
	if row >= 0 and row < ROWS and col >= 0 and col < COLS:
		var piece = board_visual[row][col]
		if piece != null:
			piece.queue_free()
			board_visual[row][col] = null
			boxes.erase(piece)

func update_piece_position(piece: Node2D, row: int, col: int) -> void:
	if piece != null:
		var target_pos = get_cell_position(row, col)
		piece.position = target_pos

# ========================================
# ATUALIZAR BOARD COMPLETO (SERVIDOR)
# ========================================

func update_board(new_board: Array) -> void:
	"""
	Sincroniza o board visual com a matriz recebida do servidor.
	new_board: Array 2D [row][col] com valores como "red", "blue", ou " " (vazio)
	"""
	print("✓ Atualizando board do servidor...")
	
	# Itera sobre cada célula da matriz
	for row in range(ROWS):
		for col in range(COLS):
			var cell_value = new_board[row][col]
			var current_piece = board_visual[row][col]
			
			if cell_value != " " and current_piece == null:
				# Célula tem uma peça, mas visualmente está vazia → CRIAR
				var new_piece = create_piece(row, col, cell_value)
				board_visual[row][col] = new_piece
				print("✓ Peça criada em [{row}][{col}] = {cell_value}")
				
			elif cell_value == " " and current_piece != null:
				# Célula está vazia, mas tem uma peça visualmente → REMOVER
				remove_piece_at(row, col)
				print("✓ Peça removida de [{row}][{col}]")
				
			elif cell_value != " " and current_piece != null:
				# Célula e peça visual existem → ATUALIZAR POSIÇÃO (segurança)
				update_piece_position(current_piece, row, col)

# ========================================
# CALLBACKS DE EVENTOS DO SERVIDOR
# ========================================

func _on_box_drop(data: Dictionary) -> void:
	"""Chamado quando uma caixa é solta pelo jogador"""
	_spawn_box(data["x"]["pos_x"], data["z"])

func _on_update_board(data: Dictionary) -> void:
	"""NOVO: Chamado quando servidor envia atualização completa do board (ex: após poder)"""
	var new_board = data.get("newBoard", [])
	if new_board.size() > 0:
		update_board(new_board)
		print("✓ Board atualizado do servidor")

func _spawn_box(data: int, color: String) -> void:
	"""Spawn de uma caixa caindo (movimento visual)"""
	var box_crate := box.instantiate()
	box_crate.position.x = data + left_offset
	box_crate.position.y = -200

	match color:
		"red":
			box_crate.modulate = Color.LIGHT_CORAL
		"blue":
			box_crate.modulate = Color.LIGHT_BLUE
		_:
			box_crate.modulate = Color.WHITE

	add_child(box_crate)
	boxes.append(box_crate)

# ========================================
# CONTROLES DO JOGADOR
# ========================================

func _check_falling():
	"""Verifica se há caixas caindo na tela"""
	if boxes.is_empty():
		can_drop = true
		return

	for b in boxes:
		if b.falling == true:
			can_drop = false
			return

	can_drop = true

func _unhandled_input(event):
	"""Detecta clique do mouse e envia para o servidor"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_check_falling()
				print("Pode dropar? {can_drop}")
				var local_pos = get_viewport().get_camera_2d().get_global_mouse_position()
				if(local_pos.x < left_offset or local_pos.x > right_offset):
					return
				if(!can_drop):
					return
				server_handle.send_message("box_drop", {"pos_x": snapped(local_pos.x - left_offset, 64)})

# ========================================
# BOTÕES / PODERES
# ========================================
func _on_eliminar_linha_pressed() -> void:
	server_handle.send_message("clear_bottom_line", {})

func _on_eliminar_caixa_pressed() -> void:
	server_handle.send_message("eliminate_box", {})

func _on_reduzir_tempo_pressed() -> void:
	server_handle.send_message("reduce_opponent_time", {})

func _on_bloquear_coluna_pressed() -> void:
	server_handle.send_message("block_column", {})
	
# ========================================
# Fim de jogo
# ========================================

func _on_game_over(data):
	var result  = data.get("winner")
	if result == "tie":
		pass #mostra tela de empate
	else:
		pass #mostra a tela com o nome do vencedor, comparar com o id local para mostrar a tela correta
	

# ========================================
# DEBUG
# ========================================

func print_board_state() -> void:
	"""Imprime o estado atual do board visual no console"""
	print("\n=== Estado do Board Visual ===")
	for row in range(ROWS):
		var row_str = ""
		for col in range(COLS):
			if board_visual[row][col] != null:
				row_str += "X "
			else:
				row_str += "· "
		print(row_str)
	print("==============================\n")
