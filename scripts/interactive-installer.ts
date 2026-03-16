#!/usr/bin/env tsx
/**
 * Interactive RBT Installer
 * Collects required variables from user and creates configuration
 */

import inquirer from 'inquirer';
import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';

interface InstallationConfig {
  jwtSecret: string;
  adminUsername: string;
  adminPassword: string;
  dashboardPort: number;
  hcaptchaSiteKey?: string;
  hcaptchaSecret?: string;
  smtpHost?: string;
  smtpPort?: number;
  smtpUser?: string;
  smtpPass?: string;
  notificationEmail?: string;
  enableHcaptcha: boolean;
  enableSmtp: boolean;
}

class InteractiveInstaller {
  private config: Partial<InstallationConfig> = {};

  async run(): Promise<void> {
    console.log('🚀 RBT Interactive Installer');
    console.log('============================');
    console.log('This installer will help you configure RBT with secure settings.\n');

    try {
      // Collect required variables
      await this.collectRequiredVariables();
      
      // Collect optional variables
      await this.collectOptionalVariables();
      
      // Generate secure JWT secret if not provided
      if (!this.config.jwtSecret) {
        this.config.jwtSecret = this.generateSecureSecret();
      }

      // Create configuration files
      await this.createConfigurationFiles();
      
      // Run the installation
      await this.runInstallation();
      
      console.log('\n✅ Installation completed successfully!');
      console.log('\nNext steps:');
      console.log('1. Run: rbt');
      console.log('2. Login with your admin credentials');
      console.log('3. Start managing your tunnels!');
      
    } catch (error) {
      console.error('\n❌ Installation failed:', error);
      process.exit(1);
    }
  }

  private async collectRequiredVariables(): Promise<void> {
    console.log('\n📋 Required Configuration');
    console.log('Please provide the following required information:\n');

    const answers = await inquirer.prompt([
      {
        type: 'input',
        name: 'adminUsername',
        message: 'Admin username:',
        default: 'admin',
        validate: (input: string) => {
          if (input.length < 3) return 'Username must be at least 3 characters';
          if (!/^[a-zA-Z0-9_]+$/.test(input)) return 'Username can only contain letters, numbers, and underscores';
          return true;
        }
      },
      {
        type: 'password',
        name: 'adminPassword',
        message: 'Admin password:',
        mask: '*',
        validate: (input: string) => {
          if (input.length < 8) return 'Password must be at least 8 characters';
          if (!/(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])/.test(input)) {
            return 'Password must contain uppercase, lowercase, number, and special character';
          }
          return true;
        }
      },
      {
        type: 'password',
        name: 'confirmPassword',
        message: 'Confirm password:',
        mask: '*',
        validate: (input: string, answers: any) => {
          if (input !== answers.adminPassword) return 'Passwords do not match';
          return true;
        }
      },
      {
        type: 'number',
        name: 'dashboardPort',
        message: 'Dashboard port:',
        default: 3000,
        validate: (input: number) => {
          if (input < 1024 || input > 65535) return 'Port must be between 1024 and 65535';
          return true;
        }
      },
      {
        type: 'password',
        name: 'jwtSecret',
        message: 'JWT Secret (leave empty to generate automatically):',
        mask: '*',
        validate: (input: string) => {
          if (input && input.length < 32) return 'JWT secret must be at least 32 characters';
          return true;
        }
      }
    ]);

    this.config.adminUsername = answers.adminUsername;
    this.config.adminPassword = answers.adminPassword;
    this.config.dashboardPort = answers.dashboardPort;
    this.config.jwtSecret = answers.jwtSecret;
  }

  private async collectOptionalVariables(): Promise<void> {
    console.log('\n🔧 Optional Configuration');
    console.log('Configure additional features (you can skip these):\n');

    const { enableHcaptcha } = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'enableHcaptcha',
        message: 'Enable hCaptcha protection?',
        default: false
      }
    ]);

    this.config.enableHcaptcha = enableHcaptcha;

    if (enableHcaptcha) {
      const hcaptchaAnswers = await inquirer.prompt([
        {
          type: 'input',
          name: 'hcaptchaSiteKey',
          message: 'hCaptcha Site Key:',
          validate: (input: string) => input.length > 0 || 'Site key is required'
        },
        {
          type: 'password',
          name: 'hcaptchaSecret',
          message: 'hCaptcha Secret Key:',
          mask: '*',
          validate: (input: string) => input.length > 0 || 'Secret key is required'
        }
      ]);

      this.config.hcaptchaSiteKey = hcaptchaAnswers.hcaptchaSiteKey;
      this.config.hcaptchaSecret = hcaptchaAnswers.hcaptchaSecret;
    }

    const { enableSmtp } = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'enableSmtp',
        message: 'Enable email notifications?',
        default: false
      }
    ]);

    this.config.enableSmtp = enableSmtp;

    if (enableSmtp) {
      const smtpAnswers = await inquirer.prompt([
        {
          type: 'input',
          name: 'smtpHost',
          message: 'SMTP Host:',
          validate: (input: string) => input.length > 0 || 'SMTP host is required'
        },
        {
          type: 'number',
          name: 'smtpPort',
          message: 'SMTP Port:',
          default: 587
        },
        {
          type: 'input',
          name: 'smtpUser',
          message: 'SMTP Username:',
          validate: (input: string) => input.length > 0 || 'SMTP username is required'
        },
        {
          type: 'password',
          name: 'smtpPass',
          message: 'SMTP Password:',
          mask: '*',
          validate: (input: string) => input.length > 0 || 'SMTP password is required'
        },
        {
          type: 'input',
          name: 'notificationEmail',
          message: 'Notification Email:',
          validate: (input: string) => {
            if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(input)) return 'Valid email required';
            return true;
          }
        }
      ]);

      this.config.smtpHost = smtpAnswers.smtpHost;
      this.config.smtpPort = smtpAnswers.smtpPort;
      this.config.smtpUser = smtpAnswers.smtpUser;
      this.config.smtpPass = smtpAnswers.smtpPass;
      this.config.notificationEmail = smtpAnswers.notificationEmail;
    }
  }

  private generateSecureSecret(): string {
    return crypto.randomBytes(64).toString('base64');
  }

  private async createConfigurationFiles(): Promise<void> {
    console.log('\n📝 Creating configuration files...');

    // Create .env file
    const envContent = this.generateEnvContent();
    fs.writeFileSync('.env', envContent);

    // Create config.toml file
    const configContent = this.generateConfigContent();
    fs.writeFileSync('config.toml', configContent);

    console.log('✅ Configuration files created');
  }

  private generateEnvContent(): string {
    let content = `# RBT Environment Configuration\n`;
    content += `# Generated on: ${new Date().toISOString()}\n\n`;
    
    // JWT Secret
    content += `JWT_SECRET=${this.config.jwtSecret}\n\n`;
    
    // Dashboard
    content += `DASHBOARD_PORT=${this.config.dashboardPort}\n\n`;
    
    // hCaptcha
    if (this.config.enableHcaptcha && this.config.hcaptchaSiteKey && this.config.hcaptchaSecret) {
      content += `VITE_HCAPTCHA_SITE_KEY=${this.config.hcaptchaSiteKey}\n`;
      content += `HCAPTCHA_SECRET_KEY=${this.config.hcaptchaSecret}\n\n`;
    } else {
      content += `# HCAPTCHA_SITE_KEY=your_site_key_here\n`;
      content += `# HCAPTCHA_SECRET_KEY=your_secret_key_here\n\n`;
    }
    
    // SMTP
    if (this.config.enableSmtp) {
      content += `SMTP_HOST=${this.config.smtpHost}\n`;
      content += `SMTP_PORT=${this.config.smtpPort}\n`;
      content += `SMTP_USER=${this.config.smtpUser}\n`;
      content += `SMTP_PASS=${this.config.smtpPass}\n`;
      content += `NOTIFICATION_EMAIL=${this.config.notificationEmail}\n\n`;
    } else {
      content += `# SMTP_HOST=smtp.gmail.com\n`;
      content += `# SMTP_PORT=587\n`;
      content += `# SMTP_USER=your_email@gmail.com\n`;
      content += `# SMTP_PASS=your_app_password\n`;
      content += `# NOTIFICATION_EMAIL=notifications@yourdomain.com\n\n`;
    }
    
    content += `# Security Settings\n`;
    content += `FORCE_HTTPS=true\n`;
    content += `SESSION_TIMEOUT=24h\n`;
    content += `MAX_LOGIN_ATTEMPTS=5\n`;
    content += `LOCKOUT_DURATION=15m\n`;
    
    return content;
  }

  private generateConfigContent(): string {
    let content = `# RBT Configuration File\n`;
    content += `# Generated on: ${new Date().toISOString()}\n\n`;
    
    content += `[dashboard]\n`;
    content += `username = "${this.config.adminUsername}"\n`;
    content += `password = "${this.config.adminPassword}"\n`;
    content += `port = ${this.config.dashboardPort}\n\n`;
    
    content += `[security]\n`;
    content += `jwt_secret = "${this.config.jwtSecret}"\n`;
    content += `session_timeout = "24h"\n`;
    content += `max_login_attempts = 5\n`;
    content += `lockout_duration = "15m"\n\n`;
    
    content += `[server]\n`;
    content += `host = "0.0.0.0"\n`;
    content += `port = ${this.config.dashboardPort}\n\n`;
    
    content += `[logging]\n`;
    content += `level = "info"\n`;
    content += `file = "/var/log/rbt/rbt.log"\n`;
    content += `max_size = "100MB"\n`;
    content += `max_backups = 10\n`;
    content += `max_age = 30\n\n`;
    
    content += `[tunnels]\n`;
    content += `# Add your tunnel configurations here\n\n`;
    
    return content;
  }

  private async runInstallation(): Promise<void> {
    console.log('\n🔧 Running installation...');
    
    // Run the original install script
    if (fs.existsSync('install.sh')) {
      execSync('bash install.sh', { stdio: 'inherit' });
    } else {
      console.log('⚠️  Original install.sh not found, skipping installation step');
    }
    
    console.log('✅ Installation completed');
  }
}

// Run the installer
if (import.meta.url === `file://${process.argv[1]}`) {
  const installer = new InteractiveInstaller();
  installer.run().catch(console.error);
}

export default InteractiveInstaller;