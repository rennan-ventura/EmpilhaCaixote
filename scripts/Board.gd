extends Node
class_name Board

const COLUMNS = 7
const ROWS = 6

var board: Array = []
var current_player := 1

signal board_updated

func _ready():
	for i in range(ROWS):
		board.append([])
		for j in range(COLUMNS):
			board[-1].append(0)
			
#Verifica se está o tabuleiro está cheio
func is_full() -> bool:
	for row in board:
		for cell in row:
			if cell == 0:
				return false
	return true

func place_piece(column: int) -> bool:
	for row in range(ROWS - 1, -1, -1):
		if board[row][column] == 0:
			board[row][column] = current_player
			emit_signal("board_updated")
			if check_win(row, column):
				get_tree().call_group("ui", "on_game_over", current_player)
			elif is_full():
				get_tree().call_group("ui", "on_game_over", 0) # 0 significa empate
			else:
				current_player = 3 - current_player
			return true
	return false

func check_win(row: int, col: int) -> bool:
	var player = board[row][col]
	var directions = [Vector2(1,0), Vector2(0,1), Vector2(1,1), Vector2(1,-1)]
	for d in directions:
		var count = 1
		for i in range(1,4):
			var r = row + int(d.y) * i
			var c = col + int(d.x) * i
			if r < 0 or r >= ROWS or c < 0 or c >= COLUMNS or board[r][c] != player:
				break
			count += 1
		for i in range(1,4):
			var r = row - int(d.y) * i
			var c = col - int(d.x) * i
			if r < 0 or r >= ROWS or c < 0 or c >= COLUMNS or board[r][c] != player:
				break
			count += 1
		if count >= 4:
			return true
	return false
