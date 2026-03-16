import { Request, Response } from "express";
import { SystemService } from "../services/systemService.js";

export class TrafficController {
  static async getTrafficData() {
    const stats = await SystemService.getTrafficStats();
    return { ...stats, timestamp: Date.now() };
  }

  static async getTraffic(req: Request, res: Response) {
    const data = await this.getTrafficData();
    res.json(data);
  }
}
