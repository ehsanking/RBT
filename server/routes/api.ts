import { Router } from "express";
import { AuthController } from "../controllers/authController.js";
import { TunnelController } from "../controllers/tunnelController.js";
import { TrafficController } from "../controllers/trafficController.js";
import { ConfigService } from "../services/configService.js";
import jwt from "jsonwebtoken";
import { securityManager } from "../config/security.js";

const router = Router();

// Auth middleware
const authMiddleware = (req: any, res: any, next: any) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader) {
    return res.status(401).json({ error: "Authorization header required" });
  }
  
  try {
    const [type, token] = authHeader.split(' ');
    if (type !== 'Bearer') {
      return res.status(401).json({ error: "Invalid authorization format" });
    }
    
    // Validate JWT secret is configured
    const jwtSecret = securityManager.getJwtSecret();
    if (!jwtSecret || jwtSecret.length < 32) {
      console.error('JWT secret not properly configured');
      return res.status(500).json({ error: "Authentication service not properly configured" });
    }
    
    const decoded = jwt.verify(token, jwtSecret);
    req.user = decoded;
    next();
  } catch (e) {
    console.error('JWT verification error:', e);
    res.status(401).json({ error: "Invalid or expired token" });
  }
};

router.post("/login", AuthController.login);

// Protected routes
router.use(authMiddleware);

router.get("/status", TunnelController.getStatus);
router.post("/tunnels", TunnelController.addTunnel);
router.delete("/tunnels/:name", TunnelController.removeTunnel);
router.get("/traffic", TrafficController.getTraffic);

export default router;
