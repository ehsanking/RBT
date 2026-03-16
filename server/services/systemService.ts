import { exec, spawn } from "child_process";
import util from "util";
import nodemailer from "nodemailer";

const execAsync = util.promisify(exec);

export class SystemService {
  static logStream: any = null;

  static startLogStream(io: any) {
    if (this.logStream) return;
    
    // Assuming 'rbt' is the command to run the service
    this.logStream = spawn("rbt", ["logs", "-f"]);

    this.logStream.stdout.on("data", (data: Buffer) => {
      io.emit("log", data.toString());
    });
  }

  static async sendNotification(tunnelName: string, message: string) {
    if (!process.env.SMTP_HOST) return;
    
    const transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: Number(process.env.SMTP_PORT),
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });

    await transporter.sendMail({
      from: '"RBT Monitor" <monitor@rbt.local>',
      to: process.env.NOTIFICATION_EMAIL,
      subject: `Alert: Tunnel ${tunnelName} Down`,
      text: message,
    });
  }

  static async getTrafficStats(): Promise<{ rx: number, tx: number }> {
    try {
      const { stdout } = await execAsync("rbt stats --json");
      const data = JSON.parse(stdout);
      return { rx: data.rx_bytes, tx: data.tx_bytes };
    } catch (e) {
      return { rx: 0, tx: 0 };
    }
  }

  static async checkConnectivity(): Promise<boolean> {
    try {
      const { stdout } = await execAsync("curl -I -m 2 http://cp.cloudflare.com/generate_204");
      return stdout.includes("204 No Content");
    } catch (e) {
      return false;
    }
  }

  static async restartService() {
    try {
      await execAsync("systemctl restart rbt");
    } catch (e) {
      // Ignore if not running systemd
    }
  }
}
