import fs from "fs";
import * as toml from "smol-toml";
import bcrypt from "bcryptjs";
import { DbService } from "./dbService.js";
import { securityManager } from "../config/security.js";

export class ConfigService {
  private static configPaths = ["/etc/rbt/config.toml", "./rbt-config.toml"];

  static getDashboardConfig() {
    // Try to get from DB first
    const dbUser = DbService.getConfig("username", "");
    const dbPass = DbService.getConfig("password", "");
    
    if (dbUser && dbPass) {
      return { username: dbUser, password: dbPass, port: 3000 };
    }

    // Check if this is first-time setup
    const isFirstTime = this.isFirstTimeSetup();
    
    // Fallback to TOML and migrate to DB
    let config = { 
      username: "admin", 
      password: isFirstTime ? this.generateSecurePassword() : "admin", 
      port: 3000 
    };
    
    // Force password change on first login
    if (isFirstTime) {
      console.warn('⚠️  FIRST TIME SETUP: Please change the default password immediately!');
      console.warn('⚠️  Default password:', config.password);
    }
    for (const p of this.configPaths) {
      if (fs.existsSync(p)) {
        try {
          const content = fs.readFileSync(p, "utf-8");
          const parsed = toml.parse(content) as any;
          if (parsed.dashboard) {
            config = { ...config, ...parsed.dashboard };
            
            // Auto-hash password if it looks like plain text
            if (config.password && !config.password.startsWith("$2a$") && !config.password.startsWith("$2b$")) {
              config.password = bcrypt.hashSync(config.password, 10);
            }

            // Migrate to DB
            DbService.setConfig("username", config.username);
            DbService.setConfig("password", config.password);
          }
        } catch (e) {}
        break;
      }
    }
    return config;
  }

  private static isFirstTimeSetup(): boolean {
    // Check if this is first time by looking for existing configuration
    const dbUser = DbService.getConfig("username", "");
    const dbPass = DbService.getConfig("password", "");
    const hasExistingConfig = dbUser && dbPass;
    
    // Check TOML files too
    if (!hasExistingConfig) {
      for (const p of this.configPaths) {
        if (fs.existsSync(p)) {
          try {
            const content = fs.readFileSync(p, 'utf-8');
            const parsed = toml.parse(content) as any;
            if (parsed.dashboard && parsed.dashboard.password) {
              return false; // Has existing config
            }
          } catch (e) {}
        }
      }
    }
    
    return !hasExistingConfig;
  }

  private static generateSecurePassword(): string {
    const length = 16;
    const charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*';
    let password = '';
    for (let i = 0; i < length; i++) {
      password += charset.charAt(Math.floor(Math.random() * charset.length));
    }
    return password;
  }

  static validateAndUpdatePassword(currentPassword: string, newPassword: string): { success: boolean; error?: string } {
    const config = this.getDashboardConfig();
    
    // Verify current password
    const isCurrentValid = bcrypt.compareSync(currentPassword, config.password);
    if (!isCurrentValid) {
      return { success: false, error: "Current password is incorrect" };
    }
    
    // Validate new password strength
    const validation = securityManager.validatePassword(newPassword);
    if (!validation.valid) {
      return { success: false, error: validation.errors.join(', ') };
    }
    
    // Hash and save new password
    const hashedPassword = bcrypt.hashSync(newPassword, securityManager.getBcryptRounds());
    DbService.setConfig("password", hashedPassword);
    
    return { success: true };
  }

  static getLinks() {
    // Source of truth is now SQLite
    return DbService.getTunnels();
  }

  static getConfigPath() {
    if (fs.existsSync("/etc/rbt/config.toml")) {
      return "/etc/rbt/config.toml";
    }
    return "./rbt-config.toml";
  }

  static addLink(newLink: any) {
    DbService.addTunnel(newLink);
    this.syncToToml();
  }

  static removeLink(name: string) {
    DbService.removeTunnel(name);
    this.syncToToml();
  }

  static syncToToml() {
    const configPath = this.getConfigPath();
    const config = this.getDashboardConfig();
    const links = DbService.getTunnels();

    let newToml = `[dashboard]\nusername = "${config.username}"\npassword = "${config.password}"\nport = ${config.port}\n\n`;
    
    for (const link of links as any[]) {
      newToml += `[[links]]\n`;
      for (const [k, v] of Object.entries(link)) {
        if (k === 'id' || v === null || v === '') continue;
        newToml += `${k} = "${v}"\n`;
      }
      newToml += `\n`;
    }
    fs.writeFileSync(configPath, newToml);
  }
}
