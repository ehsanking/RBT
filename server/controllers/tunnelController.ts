import { Request, Response } from "express";
import { z } from "zod";
import { ConfigService } from "../services/configService.js";
import { SystemService } from "../services/systemService.js";

const tunnelSchema = z.object({
  name: z.string().min(1, "Name is required"),
  protocol: z.enum(["tcp", "udp", "quic_tcp", "quic_udp"]),
  listen_host: z.string().min(1, "Listen host is required"),
  target_host: z.string().min(1, "Target host is required"),
  obfuscation: z.enum(["none", "chacha20", "aead"]).optional(),
  secret: z.string().optional(),
  port_hopping: z.string().optional(),
});

export class TunnelController {
  static async getStatus(req: Request, res: Response) {
    try {
      const isConnected = await SystemService.checkConnectivity();
      const links = ConfigService.getLinks();
      res.json({
        status: isConnected ? "operational" : "intranet_mode",
        connected: isConnected,
        links: links,
      });
    } catch (e) {
      res.status(500).json({ error: String(e) });
    }
  }

  static async addTunnel(req: Request, res: Response) {
    try {
      const validation = tunnelSchema.safeParse(req.body);
      if (!validation.success) {
        return res.status(400).json({ error: validation.error.issues[0].message });
      }
      ConfigService.addLink(validation.data);
      await SystemService.restartService();
      res.json({ success: true });
    } catch (e) {
      res.status(500).json({ error: String(e) });
    }
  }

  static async removeTunnel(req: Request, res: Response) {
    try {
      ConfigService.removeLink(req.params.name);
      await SystemService.restartService();
      res.json({ success: true });
    } catch (e) {
      res.status(500).json({ error: String(e) });
    }
  }
}
