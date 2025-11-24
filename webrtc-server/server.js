const express = require('express');
const app = express();
const http = require('http').createServer(app);
const io = require('socket.io')(http, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

const PORT = 3000;

// Menyimpan daftar user yang online
let users = {};

io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  // Register user
  socket.on('register', (userId) => {
    users[userId] = socket.id;
    console.log(`User ${userId} registered with socket ${socket.id}`);
    
    // Kirim list user yang online ke semua client
    io.emit('users', Object.keys(users));
  });

  // Handle call offer
  socket.on('call-offer', (data) => {
    console.log(`Call offer from ${data.from} to ${data.to}`);
    const targetSocketId = users[data.to];
    if (targetSocketId) {
      io.to(targetSocketId).emit('call-offer', {
        from: data.from,
        offer: data.offer
      });
    }
  });

  // Handle call answer
  socket.on('call-answer', (data) => {
    console.log(`Call answer from ${data.from} to ${data.to}`);
    const targetSocketId = users[data.to];
    if (targetSocketId) {
      io.to(targetSocketId).emit('call-answer', {
        from: data.from,
        answer: data.answer
      });
    }
  });

  // Handle ICE candidates
  socket.on('ice-candidate', (data) => {
    const targetSocketId = users[data.to];
    if (targetSocketId) {
      io.to(targetSocketId).emit('ice-candidate', {
        from: data.from,
        candidate: data.candidate
      });
    }
  });

  // Handle call end
  socket.on('end-call', (data) => {
    const targetSocketId = users[data.to];
    if (targetSocketId) {
      io.to(targetSocketId).emit('call-ended', {
        from: data.from
      });
    }
  });

  // Handle disconnect
  socket.on('disconnect', () => {
    console.log('User disconnected:', socket.id);
    // Remove user dari list
    for (let userId in users) {
      if (users[userId] === socket.id) {
        delete users[userId];
        break;
      }
    }
    // Update list user
    io.emit('users', Object.keys(users));
  });
});

http.listen(PORT, () => {
  console.log(`Signaling server running on http://localhost:${PORT}`);
});