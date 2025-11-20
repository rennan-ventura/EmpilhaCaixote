// ========================
// Servidor Multiplayer para EmpilhaCaixa (Connect Four) - Godot 4.5.1
// Versão Otimizada com Board por Sala, Timers, Poderes e Bloqueios
// ========================

// ========================================
// MAPAS DE GESTÃO MULTISALA
// ========================================
const boards = new Map(); // roomId → board (cada sala tem seu próprio)
const turnTimers = new Map(); // roomId → { playerUuid: { timer, timeLeft } }
const blockedColumns = new Map(); // roomId → Set(col) - colunas bloqueadas
const roomOtherColors = new Map(); // roomId → otherColor (cor do segundo jogador)

// ========================================
// DEPENDÊNCIAS
// ========================================
const express = require("express");
const WebSocket = require("ws");
const { v4: uuidv4 } = require("uuid");

// ========================================
// CONFIGURAÇÃO DO SERVIDOR
// ========================================
const app = express();
const PORT = 9090;
const server = app.listen(PORT, "0.0.0.0", () => {
	console.log(`✓ Servidor iniciado na porta: ${PORT}`);
});
const wss = new WebSocket.Server({ server });

// ========================================
// CONSTANTES
// ========================================
const ROWS = 6;
const COLS = 7;
const TURN_TIME_MAX = 15; // 15 segundos por turno
const BOX_SIZE = 64;

// ========================================
// ROOMS E PLAYERS
// ========================================
const rooms = new Map(); // roomId → { players: {uuid: socket} }

// ========================================
// FUNÇÕES DE UTILIDADE - BOARD
// ========================================

/**
 * Cria um novo tabuleiro vazio (6x7)
 */
function create_board() {
	return Array.from({ length: ROWS }, () => Array(COLS).fill(" "));
}

/**
 * Obtém o board da sala. Se não existir, cria um novo.
 */
function getBoardForRoom(roomId) {
	if (!boards.has(roomId)) {
		boards.set(roomId, create_board());
	}
	return boards.get(roomId);
}

/**
 * Limpa todos os dados de uma sala ao removê-la
 */
function cleanUpRoom(roomId) {
	boards.delete(roomId);
	turnTimers.delete(roomId);
	blockedColumns.delete(roomId);
	roomOtherColors.delete(roomId);
	console.log(`[Cleanup] Sala ${roomId} removida completamente.`);
}

/**
 * Adiciona uma peça ao tabuleiro
 */
function addPiece(board, col, piece) {
	if (col < 0 || col >= COLS) return false;
	for (let row = board.length - 1; row >= 0; row--) {
		if (board[row][col] === " ") {
			board[row][col] = piece;
			return true;
		}
	}
	return false; // Coluna cheia
}

/**
 * Imprime o board no console (debug)
 */
function printBoard(board) {
	console.log("\n=== BOARD ===");
	for (let row of board) {
		console.log("| " + row.join(" | ") + " |");
	}
	console.log("=============\n");
}

/**
 * Verifica se há vitória (4 em linha: horizontal, vertical ou diagonal)
 */
function checkWin(board, piece) {
	const rows = board.length;
	const cols = board[0].length;

	// Horizontal
	for (let r = 0; r < rows; r++) {
		for (let c = 0; c <= cols - 4; c++) {
			if (
				board[r][c] === piece &&
				board[r][c + 1] === piece &&
				board[r][c + 2] === piece &&
				board[r][c + 3] === piece
			) {
				return true;
			}
		}
	}

	// Vertical
	for (let c = 0; c < cols; c++) {
		for (let r = 0; r <= rows - 4; r++) {
			if (
				board[r][c] === piece &&
				board[r + 1][c] === piece &&
				board[r + 2][c] === piece &&
				board[r + 3][c] === piece
			) {
				return true;
			}
		}
	}

	// Diagonal descendente
	for (let r = 0; r <= rows - 4; r++) {
		for (let c = 0; c <= cols - 4; c++) {
			if (
				board[r][c] === piece &&
				board[r + 1][c + 1] === piece &&
				board[r + 2][c + 2] === piece &&
				board[r + 3][c + 3] === piece
			) {
				return true;
			}
		}
	}

	// Diagonal ascendente
	for (let r = 3; r < rows; r++) {
		for (let c = 0; c <= cols - 4; c++) {
			if (
				board[r][c] === piece &&
				board[r - 1][c + 1] === piece &&
				board[r - 2][c + 2] === piece &&
				board[r - 3][c + 3] === piece
			) {
				return true;
			}
		}
	}

	return false;
}

/**
 * Verifica se há empate (tabuleiro cheio)
 */
function checkTie(board) {
	return board.every((row) => row.every((cell) => cell !== " "));
}

// ========================================
// PLAYERLIST - GESTÃO DE JOGADORES
// ========================================
const playerlist = {
	players: [],

	getAll: function () {
		return this.players;
	},

	get: function (uuid) {
		return this.players.find((p) => p.uuid === uuid);
	},

	add: function (uuid, roomCode) {
		const playersInRoom = this.getByRoom(roomCode);
		const isFirstPlayer = playersInRoom.length === 0;
		let turn = false;
		const colors = ["red", "blue"];
		const colorIndex = Math.floor(Math.random() * 2);
		let playerColor = colors[colorIndex];

		if (isFirstPlayer) {
			roomOtherColors.set(roomCode, colors[1 - colorIndex]);
		} else {
			playerColor = roomOtherColors.get(roomCode);
			turn = playerColor === "red";
		}

		const player = {
			uuid,
			room: roomCode,
			x: isFirstPlayer ? 550 : 700,
			y: 300,
			z: playerColor,
			t: turn,
		};

		this.players.push(player);
		console.log(
			`[Player] ${uuid} adicionado à sala ${roomCode} com cor ${playerColor}`
		);
		return player;
	},

	update: function (uuid, newX, newY) {
		const player = this.get(uuid);
		if (player) {
			player.x = newX;
			player.y = newY;
		}
	},

	remove: function (uuid) {
		this.players = this.players.filter((p) => p.uuid !== uuid);
	},

	getByRoom: function (roomCode) {
		return this.players.filter((p) => p.room === roomCode);
	},
};

// ========================================
// TURNOS E TIMERS
// ========================================

/**
 * Inicia o timer de turno para um jogador
 */
function startPlayerTurn(roomId, playerUuid) {
	if (turnTimers.has(roomId) && turnTimers.get(roomId)[playerUuid]?.timer) {
		clearTimeout(turnTimers.get(roomId)[playerUuid].timer);
	}

	if (!turnTimers.has(roomId)) {
		turnTimers.set(roomId, {});
	}

	turnTimers.get(roomId)[playerUuid] = {
		timeLeft: TURN_TIME_MAX,
		timer: setTimeout(() => {
			onPlayerTurnTimeout(roomId, playerUuid);
		}, TURN_TIME_MAX * 1000),
	};

	sendTimeUpdate(roomId, playerUuid, TURN_TIME_MAX);
	console.log(
		`[Timer] Turno iniciado para ${playerUuid} na sala ${roomId}: ${TURN_TIME_MAX}s`
	);
}

/**
 * Envia atualização de tempo para todos na sala
 */
function sendTimeUpdate(roomId, playerUuid, timeLeft) {
	const room = rooms.get(roomId);
	if (room) {
		for (const clientUuid in room.players) {
			room.players[clientUuid].send(
				JSON.stringify({
					cmd: "turn_time_update",
					content: { uuid: playerUuid, timeLeft },
				})
			);
		}
	}
}

/**
 * Chamado quando o tempo de turno acaba
 */
function onPlayerTurnTimeout(roomId, playerUuid) {
	console.log(`[Timeout] Tempo acabou para ${playerUuid} na sala ${roomId}`);

	const room = rooms.get(roomId);
	if (room) {
		for (const clientUuid in room.players) {
			room.players[clientUuid].send(
				JSON.stringify({
					cmd: "turn_timeout",
					content: { uuid: playerUuid },
				})
			);
		}
	}

	// Passa o turno para o outro jogador
	const players = playerlist.getByRoom(roomId);
	const losingPlayer = playerlist.get(playerUuid);

	if (losingPlayer) losingPlayer.t = false;

	const nextPlayer = players.find((p) => p.uuid !== playerUuid);
	if (nextPlayer) {
		nextPlayer.t = true;
		startPlayerTurn(roomId, nextPlayer.uuid);

		if (room) {
			for (const clientUuid in room.players) {
				room.players[clientUuid].send(
					JSON.stringify({
						cmd: "turn_changed",
						content: { uuid: nextPlayer.uuid },
					})
				);
			}
		}
	}
}

// ========================================
// PODERES / HABILIDADES
// ========================================

/**
 * Remove a última linha do tabuleiro
 */
function clearLastLine(board) {
	return [
		Array(COLS).fill(" "), // Nova linha vazia no topo
		...board.slice(0, ROWS - 1), // Linhas 0-4 caem para 1-5
	];
}

/**
 * Elimina uma caixa aleatória (com seleção de linha/coluna aleatória)
 */
function eliminateBox(board) {
	const row = Math.floor(Math.random() * ROWS);
	const col = Math.floor(Math.random() * COLS);

	if (board[row][col] === " ") {
		return false; // Sem peça para eliminar
	}

	// Remove a peça e faz as acima caírem
	for (let r = row; r > 0; r--) {
		board[r][col] = board[r - 1][col];
	}
	board[0][col] = " ";

	return true;
}

/**
 * Reduz o tempo do oponente pela metade
 */
function reduceOpponentTime(roomId, opponentUuid) {
	if (!turnTimers.has(roomId) || !turnTimers.get(roomId)[opponentUuid]) {
		return;
	}

	const timerData = turnTimers.get(roomId)[opponentUuid];

	if (timerData.timer) {
		clearTimeout(timerData.timer);
	}

	timerData.timeLeft = Math.floor(timerData.timeLeft / 2);
	console.log(
		`[Poder] Tempo do ${opponentUuid} reduzido para ${timerData.timeLeft}s`
	);

	if (timerData.timeLeft <= 0) {
		onPlayerTurnTimeout(roomId, opponentUuid);
		return;
	}

	timerData.timer = setTimeout(() => {
		onPlayerTurnTimeout(roomId, opponentUuid);
	}, timerData.timeLeft * 1000);

	sendTimeUpdate(roomId, opponentUuid, timerData.timeLeft);
}

// ========================================
// BLOQUEIO DE COLUNAS
// ========================================

/**
 * Bloqueia uma coluna específica em uma sala
 */
function blockColumn(roomId, col) {
	if (!blockedColumns.has(roomId)) {
		blockedColumns.set(roomId, new Set());
	}
	blockedColumns.get(roomId).add(col);
	console.log(`[Bloqueio] Coluna ${col} bloqueada na sala ${roomId}`);
}

/**
 * Desbloqueia uma coluna específica
 */
function unblockColumn(roomId, col) {
	if (blockedColumns.has(roomId)) {
		blockedColumns.get(roomId).delete(col);
		console.log(`[Bloqueio] Coluna ${col} desbloqueada na sala ${roomId}`);
	}
}

/**
 * Verifica se uma coluna está bloqueada
 */
function isColumnBlocked(roomId, col) {
	return blockedColumns.has(roomId) && blockedColumns.get(roomId).has(col);
}

// ========================================
// UTILITÁRIOS GERAIS
// ========================================

/**
 * Gera código aleatório para a sala
 */
function generateRoomCode(length = 5) {
	const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
	let result = "";
	for (let i = 0; i < length; i++) {
		result += chars.charAt(Math.floor(Math.random() * chars.length));
	}
	return result;
}

/**
 * Envia o board atualizado para todos os jogadores da sala
 */
function broadcastBoardUpdate(roomId, board) {
	const room = rooms.get(roomId);
	if (room) {
		for (const clientUuid in room.players) {
			room.players[clientUuid].send(
				JSON.stringify({
					cmd: "update_board",
					content: { newBoard: board },
				})
			);
		}
	}
}

// ========================================
// WEBSOCKET - EVENTOS PRINCIPAIS
// ========================================

wss.on("connection", (socket) => {
	const uuid = uuidv4();
	socket.uuid = uuid;
	console.log(`[Conexão] Cliente conectado: ${uuid}`);

	// Envia UUID ao cliente
	socket.send(
		JSON.stringify({
			cmd: "joined_server",
			content: { uuid },
		})
	);

	// ====================================
	// RECEBE MENSAGENS DO CLIENTE
	// ====================================
	socket.on("message", (message) => {
		let data;
		try {
			data = JSON.parse(message.toString());
		} catch (err) {
			console.error("Erro ao parsear mensagem:", err);
			return;
		}

		const room = rooms.get(socket.roomId);
		const board = getBoardForRoom(socket.roomId);

		switch (data.cmd) {
			case "create_room": {
				const newRoomId = generateRoomCode();
				socket.roomId = newRoomId;
				rooms.set(newRoomId, { players: {} });
				boards.set(newRoomId, create_board());
				rooms.get(newRoomId).players[uuid] = socket;

				const newPlayer = playerlist.add(uuid, newRoomId);
				console.log(`[Sala] ${newRoomId} criada por ${uuid}`);

				socket.send(
					JSON.stringify({
						cmd: "room_created",
						content: { code: newRoomId },
					})
				);

				socket.send(
					JSON.stringify({
						cmd: "spawn_local_player",
						content: { player: newPlayer },
					})
				);

				// Inicia timer do primeiro jogador
				startPlayerTurn(newRoomId, uuid);
				break;
			}

			case "join_room": {
				const roomCode = data.content.code.toUpperCase();
				const roomToJoin = rooms.get(roomCode);

				if (!roomToJoin) {
					socket.send(
						JSON.stringify({
							cmd: "error",
							content: { msg: "Sala não encontrada." },
						})
					);
					return;
				}

				socket.roomId = roomCode;
				roomToJoin.players[uuid] = socket;
				const newPlayer = playerlist.add(uuid, roomCode);

				console.log(`[Sala] ${uuid} entrou em ${roomCode}`);

				socket.send(
					JSON.stringify({
						cmd: "room_joined",
						content: { code: roomCode },
					})
				);

				socket.send(
					JSON.stringify({
						cmd: "spawn_local_player",
						content: { player: newPlayer },
					})
				);

				const roomPlayers = playerlist
					.getByRoom(roomCode)
					.filter((p) => p.uuid !== uuid);
				socket.send(
					JSON.stringify({
						cmd: "spawn_network_players",
						content: { players: roomPlayers },
					})
				);

				for (const clientUuid in roomToJoin.players) {
					const client = roomToJoin.players[clientUuid];
					if (
						client !== socket &&
						client.readyState === WebSocket.OPEN
					) {
						client.send(
							JSON.stringify({
								cmd: "spawn_new_player",
								content: { player: newPlayer },
							})
						);
					}
				}

				// Quando há 2 jogadores, começa o jogo
				if (Object.keys(roomToJoin.players).length === 2) {
					console.log(`[Jogo] Iniciando em ${roomCode}`);
					for (const clientUuid in roomToJoin.players) {
						const client = roomToJoin.players[clientUuid];
						if (client.readyState === WebSocket.OPEN) {
							client.send(
								JSON.stringify({
									cmd: "start_game",
									content: {},
								})
							);
						}
					}

					// Inicia timer do segundo jogador
					const secondPlayer = playerlist
						.getByRoom(roomCode)
						.find((p) => p.uuid !== newPlayer.uuid);
					if (secondPlayer) {
						startPlayerTurn(roomCode, secondPlayer.uuid);
					}
				}
				break;
			}

			case "box_drop": {
				const requestingPlayer = playerlist.get(uuid);

				if (!requestingPlayer || !requestingPlayer.t) {
					console.log(`[Jogada] ${uuid} tentou jogar fora de turno`);
					break;
				}

				const px = Math.floor(data.content.pos_x / BOX_SIZE);

				// Valida coluna bloqueada
				if (isColumnBlocked(socket.roomId, px)) {
					socket.send(
						JSON.stringify({
							cmd: "column_blocked",
							content: { col: px },
						})
					);
					console.log(
						`[Bloqueio] ${uuid} tentou jogar em coluna bloqueada ${px}`
					);
					break;
				}

				// Adiciona a peça
				if (!addPiece(board, px, requestingPlayer.z)) {
					socket.send(
						JSON.stringify({
							cmd: "column_full",
							content: { col: px },
						})
					);
					break;
				}

				console.log(
					`[Jogada] ${uuid} (${requestingPlayer.z}) em coluna ${px}`
				);

				// Envia para todos os jogadores
				if (room) {
					for (const clientUuid in room.players) {
						room.players[clientUuid].send(
							JSON.stringify({
								cmd: "box_drop",
								content: {
									x: data.content,
									z: requestingPlayer.z,
								},
							})
						);
					}
				}

				// Verifica vitória
				if (checkWin(board, requestingPlayer.z)) {
					console.log(`[Vitória] ${requestingPlayer.z} venceu!`);
					if (room) {
						for (const clientUuid in room.players) {
							room.players[clientUuid].send(
								JSON.stringify({
									cmd: "game_over",
									content: { winner: requestingPlayer.z },
								})
							);
						}
					}
					break;
				}

				// Verifica empate
				if (checkTie(board)) {
					console.log(`[Empate] Tabuleiro cheio!`);
					if (room) {
						for (const clientUuid in room.players) {
							room.players[clientUuid].send(
								JSON.stringify({
									cmd: "game_over",
									content: { winner: "tie" },
								})
							);
						}
					}
					break;
				}

				// Troca de turno
				const players = playerlist.getByRoom(socket.roomId);
				requestingPlayer.t = false;
				const nextPlayer = players.find((p) => p.uuid !== uuid);

				if (nextPlayer) {
					nextPlayer.t = true;
					startPlayerTurn(socket.roomId, nextPlayer.uuid);

					if (room) {
						for (const clientUuid in room.players) {
							room.players[clientUuid].send(
								JSON.stringify({
									cmd: "turn_changed",
									content: { uuid: nextPlayer.uuid },
								})
							);
						}
					}
				}

				printBoard(board);
				break;
			}

			case "position": {
				playerlist.update(uuid, data.content.x, data.content.y);

				if (room) {
					for (const clientUuid in room.players) {
						const client = room.players[clientUuid];
						if (
							client !== socket &&
							client.readyState === WebSocket.OPEN
						) {
							client.send(
								JSON.stringify({
									cmd: "update_position",
									content: {
										uuid,
										x: data.content.x,
										y: data.content.y,
									},
								})
							);
						}
					}
				}
				break;
			}

			case "chat": {
				if (room) {
					for (const clientUuid in room.players) {
						const client = room.players[clientUuid];
						if (client.readyState === WebSocket.OPEN) {
							client.send(
								JSON.stringify({
									cmd: "new_chat_message",
									content: {
										uuid,
										msg: data.content.msg,
									},
								})
							);
						}
					}
				}
				break;
			}

			case "clear_bottom_line": {
				boards.set(socket.roomId, clearLastLine(board));
				broadcastBoardUpdate(socket.roomId, boards.get(socket.roomId));
				console.log(`[Poder] Linha removida em ${socket.roomId}`);
				break;
			}

			case "eliminate_box": {
				if (eliminateBox(board)) {
					broadcastBoardUpdate(socket.roomId, board);
					console.log(`[Poder] Caixa eliminada em ${socket.roomId}`);
				}
				break;
			}

			case "reduce_opponent_time": {
				const targetUuid = data.content.targetUuid;
				reduceOpponentTime(socket.roomId, targetUuid);
				console.log(`[Poder] Tempo reduzido para ${targetUuid}`);
				break;
			}

			case "block_column": {
				const col = data.content.col;
				blockColumn(socket.roomId, col);

				if (room) {
					for (const clientUuid in room.players) {
						room.players[clientUuid].send(
							JSON.stringify({
								cmd: "column_blocked_notify",
								content: { col },
							})
						);
					}
				}
				break;
			}

			case "unblock_column": {
				const col = data.content.col;
				unblockColumn(socket.roomId, col);
				break;
			}

			default: {
				console.log(`[Comando desconhecido] ${data.cmd}`);
			}
		}
	});

	// ====================================
	// DESCONEXÃO
	// ====================================
	socket.on("close", () => {
		console.log(`[Desconexão] Cliente ${uuid} desconectou`);
		playerlist.remove(uuid);

		const room = rooms.get(socket.roomId);
		if (room) {
			delete room.players[uuid];

			// Notifica outros jogadores
			for (const clientUuid in room.players) {
				const client = room.players[clientUuid];
				if (client.readyState === WebSocket.OPEN) {
					client.send(
						JSON.stringify({
							cmd: "player_disconnected",
							content: { uuid },
						})
					);
				}
			}

			// Remove sala se ficar vazia
			if (Object.keys(room.players).length === 0) {
				rooms.delete(socket.roomId);
				cleanUpRoom(socket.roomId);
			}
		}
	});
});

console.log("\n=== SERVIDOR INICIADO COM SUCESSO ===");
console.log("Comandos suportados:");
console.log("  - create_room");
console.log("  - join_room");
console.log("  - box_drop");
console.log("  - position");
console.log("  - chat");
console.log("  - clear_bottom_line");
console.log("  - eliminate_box");
console.log("  - reduce_opponent_time");
console.log("  - block_column");
console.log("  - unblock_column");
console.log("=====================================\n");
