const express = require("express");
const Websocket = require("ws");

const app = express();
const PORT = 9090;

const server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`Servidor iniciado na porta: ${PORT}`);
});

const client = new Websocket("ws://192.168.15.97:50000");

// Lista de sockets conectados ao servidor local
const sockets = new Set();

client.on("open", () => {
    console.log("Client conectado ao servidor 50000");
});

// Recebe do servidor externo e envia para TODOS os websockets conectados
client.on("message", (message) => {
    for (const socket of sockets) {
        if (socket.readyState === Websocket.OPEN) {
            socket.send(message);
        }
    }
});

client.on("error", (err) => {
    console.error("Erro client:", err);
});

const wss = new Websocket.Server({ server });

wss.on("connection", (socket) => {
    console.log("Cliente conectado na porta 9090");
    sockets.add(socket);

    socket.on("close", () => sockets.delete(socket));

    // Recebe do navegador/cliente → envia para o servidor externo
    socket.on("message", (message) => {
        try {
            JSON.parse(message);
            client.send(message);
        } catch (err) {
            console.error("JSON inválido", err);
        }
    });
});

