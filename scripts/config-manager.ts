#!/usr/bin/env tsx
/**
 * RBT Configuration Manager
 * Advanced configuration management with validation, backup, and restore capabilities
 */

import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { execSync } from 'child_process';

interface ConfigValidation {
  isValid: boolean;
  errors: string[];
  warnings: string[];
}

interface ConfigBackup {
  timestamp: string;
  version: string;
  config: any;
  checksum: string;
}

interface SecurityConfig {
  jwtSecret: string;
  sessionTimeout: string;
  maxLoginAttempts: number;
  lockoutDuration: string;
  forceHttps: boolean;
  enableAuditLogging: boolean;
}

interface DashboardConfig {
  port: number;
  host: string;
  username: string;
  password: string;
  enableRateLimiting: boolean;
  rateLimitWindow: number;
  rateLimitMax: number;
}

interface TunnelDefaults {
  protocol: 'tcp' | 'udp';
  enableTLS: boolean;
  enableObfuscation: boolean;
  maxConnections: number;
  connectionTimeout: number;
  keepAlive: boolean;
  keepAliveInterval: number;
}

interface AdvancedConfig {
  security: SecurityConfig;
  dashboard: DashboardConfig;
  tunnelDefaults: TunnelDefaults;
  logging: {
    level: 'debug' | 'info' | 'warn' | 'error';
    file: string;
    maxSize: string;
    maxBackups: number;
    maxAge: number;
    enableCompression: boolean;
  };
  performance: {
    enableZeroCopy: boolean;
    enableBBR: boolean;
    tcpBufferSize: string;
    maxFileDescriptors: number;
    workerProcesses: number;
  };
  monitoring: {
    enableMetrics: boolean;
    metricsPort: number;
    enableHealthChecks: boolean;
    healthCheckInterval: number;
    enableAlerts: boolean;
    alertThresholds: {
      cpu: number;
      memory: number;
      disk: number;
      connections: number;
    };
  };
}

export class ConfigManager {
  private configPath: string;
  private backupPath: string;
  private currentConfig: any;
  private readonly defaults: AdvancedConfig = {
    security: {
      jwtSecret: '',
      sessionTimeout: '24h',
      maxLoginAttempts: 5,
      lockoutDuration: '15m',
      forceHttps: true,
      enableAuditLogging: true
    },
    dashboard: {
      port: 3000,
      host: '0.0.0.0',
      username: 'admin',
      password: '',
      enableRateLimiting: true,
      rateLimitWindow: 900000, // 15 minutes
      rateLimitMax: 100
    },
    tunnelDefaults: {
      protocol: 'tcp',
      enableTLS: false,
      enableObfuscation: false,
      maxConnections: 1000,
      connectionTimeout: 30000,
      keepAlive: true,
      keepAliveInterval: 30000
    },
    logging: {
      level: 'info',
      file: '/var/log/rbt/rbt.log',
      maxSize: '100MB',
      maxBackups: 10,
      maxAge: 30,
      enableCompression: true
    },
    performance: {
      enableZeroCopy: true,
      enableBBR: true,
      tcpBufferSize: '16MB',
      maxFileDescriptors: 65536,
      workerProcesses: 4
    },
    monitoring: {
      enableMetrics: true,
      metricsPort: 9090,
      enableHealthChecks: true,
      healthCheckInterval: 30000,
      enableAlerts: true,
      alertThresholds: {
        cpu: 80,
        memory: 85,
        disk: 90,
        connections: 5000
      }
    }
  };

  constructor(configPath: string = 'config.toml') {
    this.configPath = configPath;
    this.backupPath = path.join(path.dirname(configPath), 'backups');
    this.currentConfig = this.loadConfig();
  }

  /**
   * Load configuration from file
   */
  private loadConfig(): any {
    try {
      if (fs.existsSync(this.configPath)) {
        const content = fs.readFileSync(this.configPath, 'utf8');
        return this.parseToml(content);
      }
    } catch (error) {
      console.warn('Failed to load config, using defaults:', error);
    }
    return this.deepClone(this.defaults);
  }

  /**
   * Parse TOML content (simplified parser)
   */
  private parseToml(content: string): any {
    const result: any = this.deepClone(this.defaults);
    const lines = content.split('\n');
    let currentSection = '';

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;

      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        currentSection = trimmed.slice(1, -1);
        continue;
      }

      const [key, value] = trimmed.split('=').map(s => s.trim());
      if (key && value) {
        this.setNestedValue(result, `${currentSection}.${key}`, this.parseValue(value));
      }
    }

    return result;
  }

  /**
   * Parse TOML value
   */
  private parseValue(value: string): any {
    value = value.replace(/^["']|["']$/g, ''); // Remove quotes
    
    if (value === 'true') return true;
    if (value === 'false') return false;
    if (/^\d+$/.test(value)) return parseInt(value, 10);
    if (/^\d+\.\d+$/.test(value)) return parseFloat(value);
    if (/^\d+[smhd]$/.test(value)) return value; // Duration strings
    
    return value;
  }

  /**
   * Set nested object value
   */
  private setNestedValue(obj: any, path: string, value: any): void {
    const keys = path.split('.');
    let current = obj;
    
    for (let i = 0; i < keys.length - 1; i++) {
      if (!current[keys[i]]) current[keys[i]] = {};
      current = current[keys[i]];
    }
    
    current[keys[keys.length - 1]] = value;
  }

  /**
   * Deep clone object
   */
  private deepClone(obj: any): any {
    return JSON.parse(JSON.stringify(obj));
  }

  /**
   * Validate configuration
   */
  validateConfig(): ConfigValidation {
    const errors: string[] = [];
    const warnings: string[] = [];

    if (!this.currentConfig.security?.jwtSecret) {
      errors.push('JWT secret is required');
    }

    if (this.currentConfig.security?.jwtSecret?.length < 32) {
      warnings.push('JWT secret should be at least 32 characters');
    }

    if (!this.currentConfig.dashboard?.username) {
      errors.push('Dashboard username is required');
    }

    if (!this.currentConfig.dashboard?.password) {
      errors.push('Dashboard password is required');
    }

    if (this.currentConfig.dashboard?.port < 1024 || this.currentConfig.dashboard?.port > 65535) {
      errors.push('Dashboard port must be between 1024 and 65535');
    }

    if (this.currentConfig.monitoring?.enableMetrics && !this.currentConfig.monitoring?.metricsPort) {
      errors.push('Metrics port is required when metrics are enabled');
    }

    return {
      isValid: errors.length === 0,
      errors,
      warnings
    };
  }

  /**
   * Save configuration
   */
  saveConfig(): void {
    const validation = this.validateConfig();
    if (!validation.isValid) {
      throw new Error(`Invalid configuration: ${validation.errors.join(', ')}`);
    }

    // Create backup before saving
    this.createBackup();

    try {
      const tomlContent = this.generateToml();
      fs.writeFileSync(this.configPath, tomlContent, 'utf8');
      
      // Set appropriate permissions
      fs.chmodSync(this.configPath, 0o600);
      
      console.log('Configuration saved successfully');
    } catch (error) {
      throw new Error(`Failed to save configuration: ${error}`);
    }
  }

  /**
   * Generate TOML content
   */
  private generateToml(): string {
    const sections = [
      'security', 'dashboard', 'tunnelDefaults', 'logging', 'performance', 'monitoring'
    ];
    
    let content = '# RBT Configuration File\n';
    content += `# Generated on: ${new Date().toISOString()}\n\n`;

    for (const section of sections) {
      content += `[${section}]\n`;
      content += this.objectToToml(this.currentConfig[section], 0);
      content += '\n';
    }

    return content;
  }

  /**
   * Convert object to TOML format
   */
  private objectToToml(obj: any, indent: number = 0): string {
    let content = '';
    const spaces = '  '.repeat(indent);
    
    for (const [key, value] of Object.entries(obj)) {
      if (typeof value === 'object' && !Array.isArray(value)) {
        content += `${spaces}[${key}]\n`;
        content += this.objectToToml(value, indent + 1);
      } else {
        const formattedValue = this.formatTomlValue(value);
        content += `${spaces}${key} = ${formattedValue}\n`;
      }
    }
    
    return content;
  }

  /**
   * Format value for TOML
   */
  private formatTomlValue(value: any): string {
    if (typeof value === 'string') {
      if (value.includes(' ') || value.includes('\n')) {
        return `"${value.replace(/"/g, '\\"')}"`;
      }
      return value;
    }
    if (typeof value === 'boolean') return value ? 'true' : 'false';
    if (typeof value === 'number') return value.toString();
    return `"${value}"`;
  }

  /**
   * Create configuration backup
   */
  createBackup(): void {
    try {
      if (!fs.existsSync(this.backupPath)) {
        fs.mkdirSync(this.backupPath, { recursive: true });
      }

      const backup: ConfigBackup = {
        timestamp: new Date().toISOString(),
        version: '0.0.2',
        config: this.deepClone(this.currentConfig),
        checksum: this.generateChecksum()
      };

      const backupFile = path.join(this.backupPath, `config-${Date.now()}.json`);
      fs.writeFileSync(backupFile, JSON.stringify(backup, null, 2));
      
      console.log(`Configuration backup created: ${backupFile}`);
    } catch (error) {
      console.warn('Failed to create backup:', error);
    }
  }

  /**
   * Restore configuration from backup
   */
  restoreBackup(backupFile: string): void {
    try {
      if (!fs.existsSync(backupFile)) {
        throw new Error(`Backup file not found: ${backupFile}`);
      }

      const backup: ConfigBackup = JSON.parse(fs.readFileSync(backupFile, 'utf8'));
      
      // Verify checksum
      const currentChecksum = crypto.createHash('sha256')
        .update(JSON.stringify(backup.config))
        .digest('hex');
      
      if (currentChecksum !== backup.checksum) {
        throw new Error('Backup checksum mismatch - file may be corrupted');
      }

      this.currentConfig = backup.config;
      this.saveConfig();
      
      console.log('Configuration restored successfully');
    } catch (error) {
      throw new Error(`Failed to restore backup: ${error}`);
    }
  }

  /**
   * Generate configuration checksum
   */
  private generateChecksum(): string {
    return crypto.createHash('sha256')
      .update(JSON.stringify(this.currentConfig))
      .digest('hex');
  }

  /**
   * List available backups
   */
  listBackups(): string[] {
    try {
      if (!fs.existsSync(this.backupPath)) {
        return [];
      }

      return fs.readdirSync(this.backupPath)
        .filter(file => file.startsWith('config-') && file.endsWith('.json'))
        .sort()
        .reverse();
    } catch (error) {
      console.warn('Failed to list backups:', error);
      return [];
    }
  }

  /**
   * Get configuration value
   */
  get<T = any>(path: string): T | undefined {
    const keys = path.split('.');
    let current = this.currentConfig;
    
    for (const key of keys) {
      if (current[key] === undefined) return undefined;
      current = current[key];
    }
    
    return current as T;
  }

  /**
   * Set configuration value
   */
  set(path: string, value: any): void {
    this.setNestedValue(this.currentConfig, path, value);
  }

  /**
   * Get current configuration
   */
  getConfig(): any {
    return this.deepClone(this.currentConfig);
  }

  /**
   * Apply system optimizations
   */
  applySystemOptimizations(): void {
    try {
      console.log('Applying system optimizations...');

      // Increase file descriptors
      const maxFd = this.get<number>('performance.maxFileDescriptors') || 65536;
      execSync(`ulimit -n ${maxFd}`);

      // Enable BBR congestion control
      if (this.get<boolean>('performance.enableBBR')) {
        try {
          execSync('sysctl -w net.core.default_qdisc=fq', { stdio: 'ignore' });
          execSync('sysctl -w net.ipv4.tcp_congestion_control=bbr', { stdio: 'ignore' });
          console.log('BBR congestion control enabled');
        } catch (error) {
          console.warn('Failed to enable BBR:', error);
        }
      }

      // Optimize TCP settings
      if (this.get<string>('performance.tcpBufferSize')) {
        const bufferSize = this.get<string>('performance.tcpBufferSize');
        try {
          execSync(`sysctl -w net.core.rmem_max=${bufferSize}`, { stdio: 'ignore' });
          execSync(`sysctl -w net.core.wmem_max=${bufferSize}`, { stdio: 'ignore' });
          execSync(`sysctl -w net.ipv4.tcp_rmem="4096 87380 ${bufferSize}"`, { stdio: 'ignore' });
          execSync(`sysctl -w net.ipv4.tcp_wmem="4096 65536 ${bufferSize}"`, { stdio: 'ignore' });
          console.log(`TCP buffer size optimized to ${bufferSize}`);
        } catch (error) {
          console.warn('Failed to optimize TCP settings:', error);
        }
      }

      console.log('System optimizations applied successfully');
    } catch (error) {
      console.error('Failed to apply system optimizations:', error);
    }
  }

  /**
   * Generate sample configuration
   */
  generateSampleConfig(): void {
    const sampleConfig = {
      security: {
        jwtSecret: crypto.randomBytes(64).toString('base64'),
        sessionTimeout: '24h',
        maxLoginAttempts: 5,
        lockoutDuration: '15m',
        forceHttps: true,
        enableAuditLogging: true
      },
      dashboard: {
        port: 3000,
        host: '0.0.0.0',
        username: 'admin',
        password: '',
        enableRateLimiting: true,
        rateLimitWindow: 900000,
        rateLimitMax: 100
      },
      tunnelDefaults: {
        protocol: 'tcp' as const,
        enableTLS: false,
        enableObfuscation: false,
        maxConnections: 1000,
        connectionTimeout: 30000,
        keepAlive: true,
        keepAliveInterval: 30000
      },
      logging: {
        level: 'info' as const,
        file: '/var/log/rbt/rbt.log',
        maxSize: '100MB',
        maxBackups: 10,
        maxAge: 30,
        enableCompression: true
      },
      performance: {
        enableZeroCopy: true,
        enableBBR: true,
        tcpBufferSize: '16MB',
        maxFileDescriptors: 65536,
        workerProcesses: 4
      },
      monitoring: {
        enableMetrics: true,
        metricsPort: 9090,
        enableHealthChecks: true,
        healthCheckInterval: 30000,
        enableAlerts: true,
        alertThresholds: {
          cpu: 80,
          memory: 85,
          disk: 90,
          connections: 5000
        }
      }
    };

    this.currentConfig = sampleConfig;
    this.saveConfig();
    
    console.log('Sample configuration generated and saved');
  }
}

// Export singleton instance
export const configManager = new ConfigManager();

// CLI interface
if (import.meta.url === `file://${process.argv[1]}`) {
  const command = process.argv[2];
  const arg = process.argv[3];

  switch (command) {
    case 'validate':
      const validation = configManager.validateConfig();
      console.log('Validation result:', validation);
      break;
    
    case 'backup':
      configManager.createBackup();
      break;
    
    case 'restore':
      if (arg) {
        configManager.restoreBackup(arg);
      } else {
        console.error('Please specify backup file');
      }
      break;
    
    case 'list-backups':
      const backups = configManager.listBackups();
      console.log('Available backups:', backups);
      break;
    
    case 'optimize':
      configManager.applySystemOptimizations();
      break;
    
    case 'sample':
      configManager.generateSampleConfig();
      break;
    
    default:
      console.log('Usage: tsx config-manager.ts [validate|backup|restore|list-backups|optimize|sample]');
  }
}