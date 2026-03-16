import express from "express";
import { createServer as createViteServer } from "vite";
import path from "path";
import { createServer } from "http";
import { Server } from "socket.io";
import apiRoutes from "./server/routes/api.js";
import { ConfigService } from "./server/services/configService.js";
import { TrafficController } from "./server/controllers/trafficController.js";
import { SystemService } from "./server/services/systemService.js";

async function startServer() {
  const app = express();
  const httpServer = createServer(app);
  const io = new Server(httpServer);

  app.use(express.json());

  // API Routes
  app.use("/api", apiRoutes);

  // WebSocket logic
  io.on("connection", (socket) => {
    console.log("Client connected to WebSocket");
    
    // Start log streaming
    SystemService.startLogStream(io);
    
    // Emit traffic data every 2 seconds to connected clients
    const trafficInterval = setInterval(async () => {
      try {
        const data = await TrafficController.getTrafficData();
        socket.emit("traffic", data);
      } catch (e) {}
    }, 2000);

    socket.on("disconnect", () => {
      clearInterval(trafficInterval);
    });
  });

  // Vite middleware for development
  if (process.env.NODE_ENV !== "production") {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: "spa",
    });
    app.use(vite.middlewares);
  } else {
    const distPath = path.join(process.cwd(), "dist");
    app.use(express.static(distPath));
    app.get("*", (req, res) => {
      res.sendFile(path.join(distPath, "index.html"));
    });
  }

  const config = ConfigService.getDashboardConfig();
  const PORT = 3000; // Port 3000 is mandatory

  httpServer.listen(PORT, "0.0.0.0", () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}

startServer();
