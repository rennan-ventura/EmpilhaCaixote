// ========================
// Servidor Multiplayer Simples para Godot - ESTRUTURA OTIMIZADA
// ========================

// MAPAS DE GESTÃO MULTISALA
const boards = new Map(); // roomId → board
const turnTimers = new Map(); // roomId → { playerUuid: { timer, timeLeft } }
const blockedColumns = new Map(); // roomId → Set(col)
const otherColor = {}; // roomId → otherColor (por partida)

// Importa as dependências
const express = require("express"); // Framework para criar um servidor HTTP simples
const WebSocket = require("ws"); // Biblioteca para trabalhar com WebSockets
const { v4: uuidv4 } = require("uuid"); // Gera IDs únicos para identificar cada jogador

// Cria o app Express e inicia o servidor HTTP
const app = express();
const PORT = process.env.PORT || 9090;
const server = app.listen(PORT, () => {
	console.log(`Servidor iniciado na porta: ${PORT}`);
});

// Cria o servidor WebSocket em cima do servidor HTTP
const wss = new WebSocket.Server({ server });

// "rooms" é um Map que guarda todas as salas criadas
// cada sala tem um código e a lista de jogadores conectados
const rooms = new Map();

// Função que gera um código aleatório para a sala (ex: 8GJ9Q)
function generateRoomCode(length = 5) {
	const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
	let result = "";
	for (let i = 0; i < length; i++)
		result += chars.charAt(Math.floor(Math.random() * chars.length));
	return result;
}

// Lista de jogadores conectados
// Guarda posição (x,y) e a sala que pertence
const playerlist = {
	players: [],

	getAll: function () {
		return this.players;
	},

	get: function (uuid) {
		return this.players.find((player) => player.uuid === uuid);
	},

	// Adiciona um novo jogador ao playerlist
	add: function (uuid, roomCode) {
		// Descobre se é o primeiro jogador da sala
		const playersInRoom = this.getByRoom(roomCode);
		const isFirstPlayer = playersInRoom.length === 0;

		let turn = false;
		const a = Math.floor(Math.random() * 1000) % 2;
		const colors = ["red", "blue"];
		let b = "";
		// Define posição inicial para o jogador
		// Jogador 1 começa na esquerda, Jogador 2 na direita
		if (isFirstPlayer) {
			b = colors[a];
			otherColor = colors[1 - a];
		} else {
			b = otherColor;
		}
		if (b == "red") {
			turn = true;
		} else {
			turn = false;
		}

		let player = {
			uuid,
			room: roomCode,
			x: isFirstPlayer ? 550 : 700,
			y: 300,
			z: b,
			t: turn,
		};

		this.players.push(player);
		console.log(player);
		return player;
	},

	// Atualiza a posição de um jogador específico
	update: function (uuid, newX, newY) {
		const player = this.get(uuid);
		if (player) {
			player.x = newX;
			player.y = newY;
		}
	},

	// Remove jogador da lista quando ele sai
	remove: function (uuid) {
		this.players = this.players.filter((player) => player.uuid !== uuid);
	},

	// Retorna todos os jogadores de uma sala específica
	getByRoom: function (roomCode) {
		return this.players.filter((player) => player.room === roomCode);
	},

	// Muda o turno do jogador
	changeTurn: function (uuid) {
		const player = this.get(uuid);
		if (player) {
			player.t = !player.t;
		}
		startPlayerTurn(player.room, uuid);
	},
};

const BOX_SIZE = 64;
const COLS = 7;
const ROWS = 6;

function create_board() {
	return Array.from({ length: ROWS }, () => Array(COLS).fill(" "));
}

let board = create_board();

function addPiece(board, col, piece) {
	for (let row = board.length - 1; row >= 0; row--) {
		if (board[row][col] === " ") {
			board[row][col] = piece;
			return true;
		}
	}
	return false; // Column is full
}

function printBoard(board) {
	console.log("\n"); //
	for (let row of board) {
		console.log("| " + row.join(" | ") + " |");
	}
}

function checkWin(board, piece) {
	const rows = board.length;
	const cols = board[0].length;
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

//==========================================
// Turnos e temporizadores
//==========================================

//Turno do jogador: inicia o timer
function startPlayerTurn(roomId, playerUuid) {
	// Cancela timers antigos se houver
	if (turnTimers.has(roomId) && turnTimers.get(roomId)[playerUuid]?.timer) {
		clearTimeout(turnTimers.get(roomId)[playerUuid].timer);
	}
	// Inicia tempo do jogador
	if (!turnTimers.has(roomId)) turnTimers.set(roomId, {});
	turnTimers.get(roomId)[playerUuid] = {
		timeLeft: TURN_TIME_MAX,
		timer: setTimeout(() => {
			// Tempo acabou, notifica a sala/jogador
			onPlayerTurnTimeout(roomId, playerUuid);
		}, TURN_TIME_MAX * 1000),
	};

	// Notifica os jogadores do tempo atual
	sendTimeUpdate(roomId, playerUuid, TURN_TIME_MAX);
}

function sendTimeUpdate(roomId, playerUuid, timeLeft) {
	const room = rooms.get(roomId);
	if (room) {
		for (const clientUuid in room.players) {
			room.players[clientUuid].send(
				JSON.stringify({
					cmd: "turn_time_update",
					content: {
						uuid: playerUuid,
						timeLeft: timeLeft,
					},
				})
			);
		}
	}
}

function onPlayerTurnTimeout(roomId, playerUuid) {
	// Notifica todos os jogadores que o tempo do playerUuid acabou
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
	// Encontra o outro jogador na sala e habilita o turno para ele
	const players = playerlist.getByRoom(roomId);

	// Desativa o turno do jogador que perdeu o tempo
	const losingPlayer = playerlist.get(playerUuid);
	if (losingPlayer) losingPlayer.t = false;

	// Encontra o outro jogador e ativa o turno dele
	const nextPlayer = players.find((p) => p.uuid !== playerUuid);
	if (nextPlayer) {
		nextPlayer.t = true;
		// Opcional: notifica todos sobre quem é o novo jogador do turno
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

//==========================================
//Poderes
//==========================================

//Limpar a ultima linha do tabuleiro
function clearLastLine(board) {
	return [
		Array(7).fill(" "), // Nova linha vazia no topo
		...board.slice(0, 5), // Linhas 0-4 agora ocupam as posições 1-5
	];
}

//Eliminar uma caixa específica
function eliminateBox(board) {
	const row = Math.floor(Math.random() * ROWS);
	const col = Math.floor(Math.random() * COLS);
	// Verifica se a posição existe e se há uma peça
	if (row < 0 || row >= board.length || col < 0 || col >= board[0].length)
		return false;
	if (board[row][col] === " ") return false; // Sem peça para eliminar

	// Elimina a peça no local indicado
	for (let r = row; r > 0; r--) {
		// Todas as peças acima descem uma linha
		board[r][col] = board[r - 1][col];
	}
	// O topo (linha 0) vira vazio
	board[0][col] = " ";
	return board;
}

//Diminuir o tempo do oponente
function reduceOpponentTime(roomId, opponentUuid) {
	if (!turnTimers.has(roomId) || !turnTimers.get(roomId)[opponentUuid])
		return;

	// Reduz o tempo pela metade
	const old = turnTimers.get(roomId)[opponentUuid];

	// Cancela timer antigo
	if (old.timer) clearTimeout(old.timer);

	// Atualiza tempo
	old.timeLeft = Math.floor(old.timeLeft / 2);
	if (old.timeLeft <= 0) {
		onPlayerTurnTimeout(roomId, opponentUuid);
		return;
	}

	// Recria timer com novo tempo restant
	old.timer = setTimeout(() => {
		onPlayerTurnTimeout(roomId, opponentUuid);
	}, old.timeLeft * 1000);

	// Atualiza no mapa e avisa todos jogadores
	turnTimers.get(roomId)[opponentUuid] = old;
	sendTimeUpdate(roomId, opponentUuid, old.timeLeft);
}

//Bloqueia uma coluna específica
function blockColumn(roomId, col) {
	if (!blockedColumns.has(roomId)) {
		blockedColumns.set(roomId, new Set());
	}
	blockedColumns.get(roomId).add(col);
}

//Desbloqueia uma coluna específica
function unblockColumn(roomId, col) {
	if (blockedColumns.has(roomId)) {
		blockedColumns.get(roomId).delete(col);
	}
}

//==========================================
// Evento disparado quando um cliente conecta
// ========================================
wss.on("connection", (socket) => {
	const uuid = uuidv4(); // Gera ID único para o cliente
	socket.uuid = uuid;
	console.log(`Cliente conectado: ${uuid}`);

	// Envia o UUID para o cliente assim que ele conecta
	socket.send(
		JSON.stringify({
			cmd: "joined_server",
			content: { uuid: uuid },
		})
	);

	// ========================================
	// Recebe mensagens do cliente
	// ========================================
	socket.on("message", (message) => {
		let data;
		try {
			data = JSON.parse(message.toString());
			console.log("Data.CMD: ", data.cmd);
			console.log("Data.content: ", data.content);
		} catch (err) {
			console.error("Erro ao parsear mensagem:", err);
			return;
		}

		switch (data.cmd) {
			case "box_drop": {
				const room = rooms.get(socket.roomId);
				const requestingplayer = playerlist.get(uuid);
				if (!requestingplayer.t) {
					break;
				}
				console.log("Column", data.content);
				const px = Math.floor(data.content.pos_x / BOX_SIZE);
				console.log("Coluna", px);

				// Impede se a coluna estiver bloqueada
				if (
					blockedColumns.has(socket.roomId) &&
					blockedColumns.get(socket.roomId).has(px)
				) {
					socket.send(
						JSON.stringify({
							cmd: "column_blocked",
							content: { col: px },
						})
					);
					break; // Impede jogada!
				}

				const box_info = { x: data.content, z: requestingplayer.z };
				if (room) {
					for (const clientUuid in room.players) {
						const client = room.players[clientUuid];
						playerlist.changeTurn(clientUuid);
						if (client.readyState === WebSocket.OPEN) {
							client.send(
								JSON.stringify({
									cmd: "box_drop",
									content: box_info,
								})
							);
						}
					}
					addPiece(board, px, requestingplayer.z);
					console.log(checkWin(board, requestingplayer.z));
					printBoard(board);
				}
				break;
			}

			case "create_room": {
				// Gera novo código e cria sala
				const newRoomId = generateRoomCode();
				socket.roomId = newRoomId;
				rooms.set(newRoomId, { players: {} });
				rooms.get(newRoomId).players[uuid] = socket;

				// Adiciona o jogador à lista
				const newPlayer = playerlist.add(uuid, newRoomId);

				console.log(`Sala ${newRoomId} criada pelo jogador ${uuid}`);

				// Responde ao cliente com o código da sala
				socket.send(
					JSON.stringify({
						cmd: "room_created",
						content: { code: newRoomId },
					})
				);

				// Manda o jogador spawnar a si mesmo
				socket.send(
					JSON.stringify({
						cmd: "spawn_local_player",
						content: { player: newPlayer },
					})
				);
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

				// Adiciona o jogador na sala
				socket.roomId = roomCode;
				roomToJoin.players[uuid] = socket;

				const newPlayer = playerlist.add(uuid, socket.roomId);

				console.log(`Jogador ${uuid} entrou na sala ${socket.roomId}`);

				// Informa o jogador que entrou com sucesso
				socket.send(
					JSON.stringify({
						cmd: "room_joined",
						content: { code: socket.roomId },
					})
				);

				// Spawna o jogador local no cliente
				socket.send(
					JSON.stringify({
						cmd: "spawn_local_player",
						content: { player: newPlayer },
					})
				);

				// Envia a lista dos jogadores já existentes na sala
				const roomPlayers = playerlist
					.getByRoom(socket.roomId)
					.filter((p) => p.uuid !== uuid);

				socket.send(
					JSON.stringify({
						cmd: "spawn_network_players",
						content: { players: roomPlayers },
					})
				);

				// Avisa os jogadores antigos que entrou um novo player
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

				// Quando há 2 jogadores na sala, começa o jogo
				if (Object.keys(roomToJoin.players).length === 2) {
					console.log(
						`Sala ${socket.roomId} atingiu o número de jogadores. Começando o jogo!`
					);
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
				}
				break;
			}

			case "position": {
				// Atualiza posição do jogador no servidor
				playerlist.update(uuid, data.content.x, data.content.y);
				const room = rooms.get(socket.roomId);
				if (room) {
					// Repassa para os outros jogadores da sala
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
										uuid: uuid,
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
				// Repassa a mensagem de chat para todos os jogadores na sala
				const room = rooms.get(socket.roomId);
				if (room) {
					for (const clientUuid in room.players) {
						const client = room.players[clientUuid];
						if (client.readyState === WebSocket.OPEN) {
							client.send(
								JSON.stringify({
									cmd: "new_chat_message",
									content: {
										uuid: uuid,
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
				// Limpa a última linha do tabuleiro
				board = clearLastLine(board);
				const room = rooms.get(socket.roomId);
				if (room) {
					for (const clientUuid in room.players) {
						const client = room.players[clientUuid];
						if (client.readyState === WebSocket.OPEN) {
							client.send(
								JSON.stringify({
									cmd: "bottom_line_cleared",
									content: { newBoard: board },
								})
							);
						}
					}
					printBoard(board);
				}
				break;
			}
			case "eliminate_box": {
				// Elimina uma caixa aleatória do tabuleiro
				board = eliminateBox(board);
				const room = rooms.get(socket.roomId);
				if (room) {
					for (const clientUuid in room.players) {
						const client = room.players[clientUuid];
						if (client.readyState === WebSocket.OPEN) {
							client.send(
								JSON.stringify({
									cmd: "box_eliminated",
									content: { newBoard: board },
								})
							);
						}
					}
					printBoard(board);
				}
				break;
			}
			case "reduce_opponent_time": {
				// Reduz o tempo do oponente pela metade
				reduceOpponentTime(socket.roomId, data.content.targetUuid);
				break;
			}
			case "block_column": {
				// Bloqueia uma coluna específica
				const col = data.content.col; // Coluna recebida do cliente/poder
				blockColumn(socket.roomId, col);
				break;
			}
		}
	});

	//========================================
	// Evento disparado quando o cliente desconecta
	//========================================
	socket.on("close", () => {
		console.log(`Cliente desconectado: ${uuid}`);

		playerlist.remove(uuid);

		const room = rooms.get(socket.roomId);
		if (room) {
			delete room.players[uuid];

			// Avisa os outros jogadores que alguém saiu
			for (const clientUuid in room.players) {
				const client = room.players[clientUuid];
				if (client.readyState === WebSocket.OPEN) {
					client.send(
						JSON.stringify({
							cmd: "player_disconnected",
							content: { uuid: uuid },
						})
					);
				}
			}

			// Remove a sala se ela ficou vazia
			if (Object.keys(room.players).length === 0) {
				rooms.delete(socket.roomId);
				console.log(`Sala ${socket.roomId} vazia e removida.`);
				board = create_board();
			}
		}
	});
});
