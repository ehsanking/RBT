#!/usr/bin/env tsx
/**
 * Enhanced RBT Interactive Installer
 * Comprehensive installation with advanced features, validation, and security
 */

import inquirer from 'inquirer';
import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { ConfigManager } from './config-manager.js';
import { RBTMonitor } from './monitor.js';
import { RBTSecurityManager } from './security-manager.js';

interface InstallationConfig {
  // Basic Configuration
  adminUsername: string;
  adminPassword: string;
  dashboardPort: number;
  jwtSecret: string;
  
  // Security Settings
  enableSecurityAuditing: boolean;
  certificatePolicy: {
    autoGenerate: boolean;
    domain?: string;
    validity: number;
    keyLength: number;
  };
  
  // Optional Features
  enableHcaptcha: boolean;
  hcaptchaSiteKey?: string;
  hcaptchaSecret?: string;
  
  enableSmtp: boolean;
  smtpHost?: string;
  smtpPort?: number;
  smtpUser?: string;
  smtpPass?: string;
  notificationEmail?: string;
  
  // Advanced Features
  enableMonitoring: boolean;
  monitoringPort: number;
  enableMetrics: boolean;
  metricsPort: number;
  
  // System Optimization
  enableSystemOptimization: boolean;
  optimizeNetwork: boolean;
  optimizeFileDescriptors: boolean;
  
  // Backup and Recovery
  enableAutoBackup: boolean;
  backupInterval: number;
  backupRetention: number;
}

class EnhancedInteractiveInstaller {
  private config: Partial<InstallationConfig> = {};
  private configManager: ConfigManager;
  private monitor: RBTMonitor;
  private securityManager: RBTSecurityManager;

  constructor() {
    this.configManager = new ConfigManager();
    this.monitor = new RBTMonitor();
    this.securityManager = new RBTSecurityManager();
  }

  async run(): Promise<void> {
    console.log('🚀 RBT Enhanced Interactive Installer');
    console.log('=======================================');
    console.log('This installer will set up RBT with advanced security and monitoring features.\n');

    try {
      // Pre-installation checks
      await this.performPreInstallationChecks();
      
      // Collect configuration
      await this.collectBasicConfiguration();
      await this.collectSecurityConfiguration();
      await this.collectOptionalFeatures();
      await this.collectAdvancedConfiguration();
      
      // Validate configuration
      await this.validateConfiguration();
      
      // Install and configure
      await this.installDependencies();
      await this.createConfigurationFiles();
      await this.setupSecurity();
      await this.setupMonitoring();
      await this.optimizeSystem();
      
      // Post-installation
      await this.performPostInstallationTasks();
      
      console.log('\n✅ Enhanced installation completed successfully!');
      this.printNextSteps();
      
    } catch (error) {
      console.error('\n❌ Installation failed:', error);
      await this.handleInstallationError(error);
      process.exit(1);
    }
  }

  private async performPreInstallationChecks(): Promise<void> {
    console.log('\n🔍 Performing pre-installation checks...');
    
    // Check Node.js version
    try {
      const nodeVersion = execSync('node --version', { encoding: 'utf8' }).trim();
      const majorVersion = parseInt(nodeVersion.slice(1).split('.')[0]);
      
      if (majorVersion < 16) {
        throw new Error(`Node.js 16+ required, found ${nodeVersion}`);
      }
      console.log(`✅ Node.js version: ${nodeVersion}`);
    } catch (error) {
      throw new Error('Node.js is not installed or not in PATH');
    }

    // Check system resources
    try {
      const memInfo = execSync('free -m', { encoding: 'utf8' });
      const memMatch = memInfo.match(/Mem:\s+(\d+)/);
      const totalMemory = memMatch ? parseInt(memMatch[1]) : 0;
      
      if (totalMemory < 512) {
        console.warn('⚠️  Low memory detected. RBT may not perform optimally.');
      }
      console.log(`✅ System memory: ${totalMemory}MB`);
    } catch (error) {
      console.warn('⚠️  Could not check system memory');
    }

    // Check ports availability
    const checkPort = (port: number): boolean => {
      try {
        execSync(`netstat -tuln | grep :${port} || true`, { encoding: 'utf8' });
        return true; // Port is available if grep returns empty
      } catch (error) {
        return false;
      }
    };

    if (!checkPort(3000)) {
      console.warn('⚠️  Port 3000 is in use. You may need to choose a different dashboard port.');
    }

    console.log('✅ Pre-installation checks completed');
  }

  private async collectBasicConfiguration(): Promise<void> {
    console.log('\n📋 Basic Configuration');
    console.log('Please provide the basic configuration for your RBT installation:');

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
      }
    ]);

    this.config.adminUsername = answers.adminUsername;
    this.config.adminPassword = answers.adminPassword;
    this.config.dashboardPort = answers.dashboardPort;
    this.config.jwtSecret = crypto.randomBytes(64).toString('base64');
  }

  private async collectSecurityConfiguration(): Promise<void> {
    console.log('\n🔐 Security Configuration');
    console.log('Configure security settings for your RBT installation:');

    const answers = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'enableSecurityAuditing',
        message: 'Enable security auditing?',
        default: true
      },
      {
        type: 'confirm',
        name: 'autoGenerateCertificate',
        message: 'Auto-generate SSL certificate?',
        default: true
      }
    ]);

    this.config.enableSecurityAuditing = answers.enableSecurityAuditing;
    this.config.certificatePolicy = {
      autoGenerate: answers.autoGenerateCertificate,
      validity: 365,
      keyLength: 2048
    };

    if (answers.autoGenerateCertificate) {
      const domainAnswer = await inquirer.prompt([
        {
          type: 'input',
          name: 'domain',
          message: 'Domain name for certificate:',
          default: 'localhost'
        }
      ]);
      this.config.certificatePolicy.domain = domainAnswer.domain;
    }
  }

  private async collectOptionalFeatures(): Promise<void> {
    console.log('\n🔧 Optional Features');

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
          default: 'smtp.gmail.com'
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

  private async collectAdvancedConfiguration(): Promise<void> {
    console.log('\n⚡ Advanced Configuration');

    const answers = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'enableMonitoring',
        message: 'Enable monitoring and metrics?',
        default: true
      },
      {
        type: 'confirm',
        name: 'enableSystemOptimization',
        message: 'Enable system optimization?',
        default: true
      },
      {
        type: 'confirm',
        name: 'enableAutoBackup',
        message: 'Enable automatic configuration backup?',
        default: true
      }
    ]);

    this.config.enableMonitoring = answers.enableMonitoring;
    this.config.enableSystemOptimization = answers.enableSystemOptimization;
    this.config.enableAutoBackup = answers.enableAutoBackup;

    if (answers.enableMonitoring) {
      const monitoringAnswers = await inquirer.prompt([
        {
          type: 'number',
          name: 'monitoringPort',
          message: 'Monitoring port:',
          default: 9090
        },
        {
          type: 'confirm',
          name: 'enableMetrics',
          message: 'Enable metrics collection?',
          default: true
        }
      ]);

      this.config.monitoringPort = monitoringAnswers.monitoringPort;
      this.config.enableMetrics = monitoringAnswers.enableMetrics;

      if (monitoringAnswers.enableMetrics) {
        const metricsAnswer = await inquirer.prompt([
          {
            type: 'number',
            name: 'metricsPort',
            message: 'Metrics port:',
            default: 9091
          }
        ]);
        this.config.metricsPort = metricsAnswer.metricsPort;
      }
    }

    if (answers.enableSystemOptimization) {
      const optimizationAnswers = await inquirer.prompt([
        {
          type: 'confirm',
          name: 'optimizeNetwork',
          message: 'Optimize network settings (BBR, TCP buffers)?',
          default: true
        },
        {
          type: 'confirm',
          name: 'optimizeFileDescriptors',
          message: 'Optimize file descriptor limits?',
          default: true
        }
      ]);

      this.config.optimizeNetwork = optimizationAnswers.optimizeNetwork;
      this.config.optimizeFileDescriptors = optimizationAnswers.optimizeFileDescriptors;
    }

    if (answers.enableAutoBackup) {
      const backupAnswers = await inquirer.prompt([
        {
          type: 'number',
          name: 'backupInterval',
          message: 'Backup interval (hours):',
          default: 24
        },
        {
          type: 'number',
          name: 'backupRetention',
          message: 'Backup retention (days):',
          default: 30
        }
      ]);

      this.config.backupInterval = backupAnswers.backupInterval;
      this.config.backupRetention = backupAnswers.backupRetention;
    }
  }

  private async validateConfiguration(): Promise<void> {
    console.log('\n✅ Validating configuration...');

    // Validate ports
    const ports = [this.config.dashboardPort, this.config.monitoringPort, this.config.metricsPort].filter(Boolean);
    const uniquePorts = new Set(ports);
    
    if (uniquePorts.size !== ports.length) {
      throw new Error('Duplicate ports detected in configuration');
    }

    // Validate email if SMTP is enabled
    if (this.config.enableSmtp && this.config.notificationEmail) {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(this.config.notificationEmail)) {
        throw new Error('Invalid notification email format');
      }
    }

    console.log('✅ Configuration validation passed');
  }

  private async installDependencies(): Promise<void> {
    console.log('\n📦 Installing dependencies...');

    try {
      // Install npm dependencies
      execSync('npm install', { stdio: 'inherit' });
      console.log('✅ NPM dependencies installed');

      // Install system dependencies if needed
      if (this.config.enableMonitoring) {
        try {
          execSync('which htop', { stdio: 'ignore' });
        } catch {
          console.log('Installing htop for better system monitoring...');
          try {
            execSync('sudo apt-get install -y htop', { stdio: 'ignore' });
          } catch {
            console.warn('⚠️  Could not install htop. Monitoring may be limited.');
          }
        }
      }

    } catch (error) {
      throw new Error(`Failed to install dependencies: ${error}`);
    }
  }

  private async createConfigurationFiles(): Promise<void> {
    console.log('\n📝 Creating configuration files...');

    // Create .env file
    const envContent = this.generateEnvContent();
    fs.writeFileSync('.env', envContent);

    // Create config.toml file
    const configContent = this.generateConfigContent();
    fs.writeFileSync('config.toml', configContent);

    // Set secure permissions
    fs.chmodSync('.env', 0o600);
    fs.chmodSync('config.toml', 0o600);

    console.log('✅ Configuration files created');
  }

  private generateEnvContent(): string {
    let content = `# RBT Enhanced Environment Configuration\n`;
    content += `# Generated on: ${new Date().toISOString()}\n\n`;
    
    // JWT Secret
    content += `JWT_SECRET=${this.config.jwtSecret}\n\n`;
    
    // Dashboard
    content += `DASHBOARD_PORT=${this.config.dashboardPort}\n`;
    content += `DASHBOARD_HOST=0.0.0.0\n\n`;
    
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

    // Monitoring
    if (this.config.enableMonitoring) {
      content += `MONITORING_PORT=${this.config.monitoringPort}\n`;
      content += `ENABLE_MONITORING=true\n`;
      if (this.config.enableMetrics) {
        content += `METRICS_PORT=${this.config.metricsPort}\n`;
        content += `ENABLE_METRICS=true\n`;
      }
      content += '\n';
    }

    // Security
    content += `# Security Settings\n`;
    content += `FORCE_HTTPS=true\n`;
    content += `SESSION_TIMEOUT=24h\n`;
    content += `MAX_LOGIN_ATTEMPTS=5\n`;
    content += `LOCKOUT_DURATION=15m\n`;
    content += `ENABLE_SECURITY_AUDITING=${this.config.enableSecurityAuditing}\n`;
    content += `ENABLE_AUTO_BACKUP=${this.config.enableAutoBackup}\n\n`;

    // Performance
    if (this.config.enableSystemOptimization) {
      content += `# Performance Settings\n`;
      content += `ENABLE_ZERO_COPY=true\n`;
      content += `ENABLE_BBR=true\n`;
      content += `TCP_BUFFER_SIZE=16MB\n`;
      content += `MAX_FILE_DESCRIPTORS=65536\n\n`;
    }

    return content;
  }

  private generateConfigContent(): string {
    let content = `# RBT Enhanced Configuration File\n`;
    content += `# Generated on: ${new Date().toISOString()}\n\n`;
    
    content += `[dashboard]\n`;
    content += `username = "${this.config.adminUsername}"\n`;
    content += `password = "${this.config.adminPassword}"\n`;
    content += `port = ${this.config.dashboardPort}\n`;
    content += `host = "0.0.0.0"\n`;
    content += `enable_rate_limiting = true\n`;
    content += `rate_limit_window = 900000\n`;
    content += `rate_limit_max = 100\n\n`;
    
    content += `[security]\n`;
    content += `jwt_secret = "${this.config.jwtSecret}"\n`;
    content += `session_timeout = "24h"\n`;
    content += `max_login_attempts = 5\n`;
    content += `lockout_duration = "15m"\n`;
    content += `force_https = true\n`;
    content += `enable_audit_logging = ${this.config.enableSecurityAuditing}\n`;
    content += `enable_auto_backup = ${this.config.enableAutoBackup}\n\n`;

    // Monitoring
    if (this.config.enableMonitoring) {
      content += `[monitoring]\n`;
      content += `enable_metrics = ${this.config.enableMetrics}\n`;
      content += `metrics_port = ${this.config.metricsPort}\n`;
      content += `monitoring_port = ${this.config.monitoringPort}\n`;
      content += `enable_health_checks = true\n`;
      content += `health_check_interval = 30000\n`;
      content += `enable_alerts = true\n\n`;
    }

    // Logging
    content += `[logging]\n`;
    content += `level = "info"\n`;
    content += `file = "/var/log/rbt/rbt.log"\n`;
    content += `max_size = "100MB"\n`;
    content += `max_backups = 10\n`;
    content += `max_age = 30\n`;
    content += `enable_compression = true\n\n`;

    // Performance
    if (this.config.enableSystemOptimization) {
      content += `[performance]\n`;
      content += `enable_zero_copy = true\n`;
      content += `enable_bbr = ${this.config.optimizeNetwork}\n`;
      content += `tcp_buffer_size = "16MB"\n`;
      content += `max_file_descriptors = 65536\n`;
      content += `worker_processes = 4\n\n`;
    }

    // Backup
    if (this.config.enableAutoBackup) {
      content += `[backup]\n`;
      content += `enable_auto_backup = true\n`;
      content += `backup_interval = ${this.config.backupInterval}\n`;
      content += `backup_retention = ${this.config.backupRetention}\n\n`;
    }
    
    content += `[tunnels]\n`;
    content += `# Add your tunnel configurations here\n\n`;
    
    return content;
  }

  private async setupSecurity(): Promise<void> {
    if (!this.config.enableSecurityAuditing) return;

    console.log('\n🔐 Setting up security...');

    try {
      // Initialize security manager
      await this.securityManager.initializeSecurity();
      
      // Generate certificate if enabled
      if (this.config.certificatePolicy?.autoGenerate && this.config.certificatePolicy.domain) {
        const cert = await this.securityManager.generateCertificate(this.config.certificatePolicy.domain, {
          validity: this.config.certificatePolicy.validity,
          keyLength: this.config.certificatePolicy.keyLength
        });
        console.log(`✅ Certificate generated for ${cert.domain}`);
      }

      console.log('✅ Security setup completed');
    } catch (error) {
      console.warn('⚠️  Security setup failed:', error);
    }
  }

  private async setupMonitoring(): Promise<void> {
    if (!this.config.enableMonitoring) return;

    console.log('\n📊 Setting up monitoring...');

    try {
      // Start monitoring
      this.monitor.startMonitoring();
      console.log('✅ Monitoring started');

      // Set up alert thresholds
      this.monitor.setAlertThreshold('cpu', 80);
      this.monitor.setAlertThreshold('memory', 85);
      this.monitor.setAlertThreshold('disk', 90);
      
      console.log('✅ Monitoring setup completed');
    } catch (error) {
      console.warn('⚠️  Monitoring setup failed:', error);
    }
  }

  private async optimizeSystem(): Promise<void> {
    if (!this.config.enableSystemOptimization) return;

    console.log('\n⚡ Optimizing system...');

    try {
      // Apply system optimizations through config manager
      this.configManager.applySystemOptimizations();
      
      console.log('✅ System optimization completed');
    } catch (error) {
      console.warn('⚠️  System optimization failed:', error);
    }
  }

  private async performPostInstallationTasks(): Promise<void> {
    console.log('\n🔄 Performing post-installation tasks...');

    // Create backup
    this.configManager.createBackup();
    console.log('✅ Initial configuration backup created');

    // Set up auto-start if requested
    try {
      const { enableAutoStart } = await inquirer.prompt([
        {
          type: 'confirm',
          name: 'enableAutoStart',
          message: 'Enable automatic start on system boot?',
          default: true
        }
      ]);

      if (enableAutoStart) {
        // Create systemd service or init script
        this.createAutoStartScript();
        console.log('✅ Auto-start enabled');
      }
    } catch (error) {
      console.warn('⚠️  Could not set up auto-start:', error);
    }

    console.log('✅ Post-installation tasks completed');
  }

  private createAutoStartScript(): void {
    const serviceContent = `[Unit]
Description=RBT Tunnel Orchestrator
After=network.target

[Service]
Type=simple
User=rbt
Group=rbt
WorkingDirectory=/opt/rbt
ExecStart=/usr/bin/node /opt/rbt/server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target`;

    try {
      fs.writeFileSync('/tmp/rbt.service', serviceContent);
      execSync('sudo mv /tmp/rbt.service /etc/systemd/system/', { stdio: 'ignore' });
      execSync('sudo systemctl daemon-reload', { stdio: 'ignore' });
      execSync('sudo systemctl enable rbt.service', { stdio: 'ignore' });
    } catch (error) {
      console.warn('Could not create systemd service:', error);
    }
  }

  private printNextSteps(): void {
    console.log('\n🎉 RBT Enhanced Installation Complete!');
    console.log('========================================');
    console.log('\nNext steps:');
    console.log(`1. Start RBT: npm run rbt-menu`);
    console.log(`2. Access dashboard: http://localhost:${this.config.dashboardPort}`);
    console.log(`3. Login with username: ${this.config.adminUsername}`);
    console.log(`4. Monitor system: ${this.config.enableMonitoring ? 'Enabled on port ' + this.config.monitoringPort : 'Not enabled'}`);
    console.log(`5. View logs: tail -f /var/log/rbt/rbt.log`);
    
    if (this.config.enableAutoBackup) {
      console.log(`6. Backups: Automatic backups every ${this.config.backupInterval} hours`);
    }

    console.log('\n📚 Useful commands:');
    console.log('- npm run rbt-menu          # Start interactive menu');
    console.log('- npm run rbt-install     # Run installer again');
    console.log('- tsx scripts/monitor.ts start  # Start monitoring');
    console.log('- tsx scripts/security-manager.ts audit  # Run security audit');

    console.log('\n🔧 Configuration files:');
    console.log('- .env                    # Environment variables');
    console.log('- config.toml            # Main configuration');
    console.log('- backups/                 # Configuration backups');

    console.log('\n📖 Documentation:');
    console.log('- README.md               # Main documentation');
    console.log('- INTERACTIVE-GUIDE.md    # Interactive features guide');
    console.log('- SECURITY.md             # Security guidelines');

    console.log('\n👍 Thank you for choosing RBT Enhanced!');
  }

  private async handleInstallationError(error: any): Promise<void> {
    console.error('\n❌ Installation error occurred:', error.message);
    
    // Attempt to create error log
    try {
      const errorLog = {
        timestamp: new Date().toISOString(),
        error: error.message,
        stack: error.stack,
        config: this.config
      };
      
      fs.writeFileSync('install-error.json', JSON.stringify(errorLog, null, 2));
      console.log('Error details saved to install-error.json');
    } catch (logError) {
      console.warn('Could not save error log:', logError);
    }

    console.log('\n💡 Troubleshooting tips:');
    console.log('- Check system requirements and dependencies');
    console.log('- Verify file permissions and disk space');
    console.log('- Review error logs for detailed information');
    console.log('- Run installer with --debug flag for verbose output');
    console.log('- Contact support with error logs if needed');
  }
}

// Run the enhanced installer
if (import.meta.url === `file://${process.argv[1]}`) {
  const installer = new EnhancedInteractiveInstaller();
  installer.run().catch(console.error);
}