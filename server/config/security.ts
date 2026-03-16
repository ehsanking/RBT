import crypto from 'crypto';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';

export interface SecurityConfig {
  jwtSecret: string;
  jwtExpiresIn: string;
  bcryptRounds: number;
  minPasswordLength: number;
  requireStrongPassword: boolean;
}

const SECURITY_CONFIG_PATH = '/etc/rbt/security.json';
const FALLBACK_CONFIG_PATH = './rbt-security.json';

export class SecurityManager {
  private static instance: SecurityManager;
  private config: SecurityConfig;

  private constructor() {
    this.config = this.loadOrCreateConfig();
  }

  static getInstance(): SecurityManager {
    if (!SecurityManager.instance) {
      SecurityManager.instance = new SecurityManager();
    }
    return SecurityManager.instance;
  }

  private loadOrCreateConfig(): SecurityConfig {
    const configPaths = [SECURITY_CONFIG_PATH, FALLBACK_CONFIG_PATH];
    
    for (const path of configPaths) {
      if (existsSync(path)) {
        try {
          const configData = JSON.parse(readFileSync(path, 'utf-8'));
          return this.validateConfig(configData);
        } catch (error) {
          console.warn(`Failed to load security config from ${path}:`, error);
        }
      }
    }

    // Generate new secure configuration
    return this.createSecureConfig();
  }

  private validateConfig(configData: any): SecurityConfig {
    if (!configData.jwtSecret || configData.jwtSecret.length < 32) {
      throw new Error('JWT secret must be at least 32 characters');
    }
    
    return {
      jwtSecret: configData.jwtSecret,
      jwtExpiresIn: configData.jwtExpiresIn || '24h',
      bcryptRounds: configData.bcryptRounds || 12,
      minPasswordLength: configData.minPasswordLength || 8,
      requireStrongPassword: configData.requireStrongPassword !== false
    };
  }

  private createSecureConfig(): SecurityConfig {
    const config: SecurityConfig = {
      jwtSecret: this.generateSecureSecret(),
      jwtExpiresIn: '24h',
      bcryptRounds: 12,
      minPasswordLength: 8,
      requireStrongPassword: true
    };

    this.saveConfig(config);
    return config;
  }

  private generateSecureSecret(): string {
    return crypto.randomBytes(64).toString('hex');
  }

  private saveConfig(config: SecurityConfig): void {
    const configPath = SECURITY_CONFIG_PATH;
    const configDir = dirname(configPath);
    
    try {
      if (!existsSync(configDir)) {
        mkdirSync(configDir, { recursive: true, mode: 0o700 });
      }
      
      writeFileSync(configPath, JSON.stringify(config, null, 2), { mode: 0o600 });
      console.log(`Security configuration saved to ${configPath}`);
    } catch (error) {
      console.warn('Failed to save to system path, using fallback:', error);
      writeFileSync(FALLBACK_CONFIG_PATH, JSON.stringify(config, null, 2), { mode: 0o600 });
    }
  }

  getJwtSecret(): string {
    return this.config.jwtSecret;
  }

  getJwtExpiresIn(): string {
    return this.config.jwtExpiresIn;
  }

  getBcryptRounds(): number {
    return this.config.bcryptRounds;
  }

  getMinPasswordLength(): number {
    return this.config.minPasswordLength;
  }

  isStrongPasswordRequired(): boolean {
    return this.config.requireStrongPassword;
  }

  validatePassword(password: string): { valid: boolean; errors: string[] } {
    const errors: string[] = [];

    if (password.length < this.config.minPasswordLength) {
      errors.push(`Password must be at least ${this.config.minPasswordLength} characters long`);
    }

    if (this.config.requireStrongPassword) {
      if (!/[A-Z]/.test(password)) {
        errors.push('Password must contain at least one uppercase letter');
      }
      if (!/[a-z]/.test(password)) {
        errors.push('Password must contain at least one lowercase letter');
      }
      if (!/[0-9]/.test(password)) {
        errors.push('Password must contain at least one number');
      }
      if (!/[!@#$%^&*]/.test(password)) {
        errors.push('Password must contain at least one special character (!@#$%^&*)');
      }
    }

    return {
      valid: errors.length === 0,
      errors
    };
  }
}

export const securityManager = SecurityManager.getInstance();