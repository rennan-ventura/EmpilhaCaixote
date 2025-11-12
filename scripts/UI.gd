extends Control

@export var board_node: NodePath
var board: Board

const CELL_SIZE := 100
const COLUMNS := 7
const ROWS := 6

var sprite_empty := preload("res://sprites/caixa_vazia.png")
var sprite_player1 := preload("res://sprites/caixa_vermelha.png")
var sprite_player2 := preload("res://sprites/caixa_azul.png")

var offset_x := 0.0
var offset_y := 0.0

func _ready():
	board = get_node(board_node)
	board.connect("board_updated", Callable(self, "queue_redraw"))
	add_to_group("ui")
	set_process_input(true)
	# Centralize tabuleiro ao iniciar
	calculate_offset()
	queue_redraw()

func calculate_offset():
	# Usa tamanho da viewport para centralizar em qualquer resolução
	var viewport_size = get_viewport_rect().size
	offset_x = (viewport_size.x - COLUMNS * CELL_SIZE) / 2
	offset_y = (viewport_size.y - ROWS * CELL_SIZE) / 2

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		calculate_offset() # Garante centralização se a janela alterar de tamanho
		var col = int((event.position.x - offset_x) / CELL_SIZE)
		if col >= 0 and col < COLUMNS:
			board.place_piece(col)
			queue_redraw()

func _draw():
	calculate_offset()
	# Desenha tabuleiro
	draw_rect(Rect2(offset_x, offset_y, COLUMNS * CELL_SIZE, ROWS * CELL_SIZE), Color.DARK_BLUE, false, 5)
	# Desenha células/caixas
	for row in range(ROWS):
		for col in range(COLUMNS):
			var x = offset_x + col * CELL_SIZE
			var y = offset_y + row * CELL_SIZE
			var cell_val = board.board[row][col]
			var tex : Texture2D
			if cell_val == 1:
				tex = sprite_player1
			elif cell_val == 2:
				tex = sprite_player2
			else:
				tex = sprite_empty
			# Centraliza o sprite
			if tex:
				draw_texture_rect(tex, Rect2(x, y, CELL_SIZE, CELL_SIZE), false)

func on_game_over(player):
	show_modal_message("Jogador %d venceu!" % player)

func show_modal_message(msg):
	var dialog = AcceptDialog.new()
	dialog.dialog_text = msg
	add_child(dialog)
	dialog.popup_centered()
