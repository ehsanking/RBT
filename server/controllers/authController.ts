import { Request, Response } from "express";
import axios from "axios";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { z } from "zod";
import { ConfigService } from "../services/configService.js";
import { securityManager } from "../config/security.js";

const loginSchema = z.object({
  username: z.string().min(1, "Username is required").max(50, "Username too long"),
  password: z.string().min(securityManager.getMinPasswordLength(), `Password must be at least ${securityManager.getMinPasswordLength()} characters`),
  hcaptchaToken: z.string().optional(),
});

export class AuthController {
  static async login(req: Request, res: Response) {
    const config = ConfigService.getDashboardConfig();
    
    // Input Validation with Zod
    const validation = loginSchema.safeParse(req.body);
    if (!validation.success) {
      return res.status(400).json({ error: validation.error.issues[0].message });
    }

    const { username, password, hcaptchaToken } = validation.data;

    // Validate JWT secret is properly configured
    try {
      const jwtSecret = securityManager.getJwtSecret();
      if (!jwtSecret || jwtSecret.length < 32) {
        console.error('JWT secret not properly configured');
        return res.status(500).json({ error: "Authentication service not properly configured" });
      }
    } catch (error) {
      console.error('Security manager error:', error);
      return res.status(500).json({ error: "Authentication service unavailable" });
    }

    const hcaptchaSecret = process.env.HCAPTCHA_SECRET_KEY;
    if (hcaptchaSecret) {
      if (!hcaptchaToken) {
        return res.status(400).json({ error: "Captcha is required" });
      }
      try {
        const response = await axios.post(
          "https://hcaptcha.com/siteverify",
          `secret=${hcaptchaSecret}&response=${hcaptchaToken}`,
          { headers: { "Content-Type": "application/x-www-form-urlencoded" } }
        );
        if (!response.data.success) {
          return res.status(401).json({ error: "Invalid captcha" });
        }
      } catch (e) {
        console.error("hCaptcha verification error:", e);
        return res.status(500).json({ error: "Captcha verification failed" });
      }
    }

    // Password verification with Bcrypt
    const isPasswordValid = username === config.username && bcrypt.compareSync(password, config.password);

    if (isPasswordValid) {
      try {
        const jwtSecret = securityManager.getJwtSecret();
        const payload = { username: config.username };
        const options = { 
          expiresIn: securityManager.getJwtExpiresIn() as any
        };
        const token = jwt.sign(payload, jwtSecret, options);
        res.json({ success: true, token });
      } catch (error) {
        console.error('JWT signing error:', error);
        return res.status(500).json({ error: "Failed to create authentication token" });
      }
    } else {
      res.status(401).json({ error: "Invalid credentials" });
    }
  }
}
