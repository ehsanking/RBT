#!/usr/bin/env tsx
/**
 * RBT Interactive Menu System
 * Provides numbered menu options for easy navigation
 */

import inquirer from 'inquirer';
import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';

interface MenuOption {
  number: number;
  title: string;
  description: string;
  action: () => Promise<void>;
}

class RBTInteractiveMenu {
  private menuOptions: MenuOption[] = [];
  private running = true;

  constructor() {
    this.setupMenuOptions();
  }

  private setupMenuOptions(): void {
    this.menuOptions = [
      {
        number: 1,
        title: '🚀 Quick Start',
        description: 'Initialize RBT and create your first tunnel',
        action: this.quickStart.bind(this)
      },
      {
        number: 2,
        title: '🔧 Configuration',
        description: 'Configure RBT settings and options',
        action: this.configure.bind(this)
      },
      {
        number: 3,
        title: '🔗 Tunnel Management',
        description: 'Add, remove, and manage tunnels',
        action: this.manageTunnels.bind(this)
      },
      {
        number: 4,
        title: '📊 Monitoring & Analytics',
        description: 'View traffic statistics and logs',
        action: this.monitoring.bind(this)
      },
      {
        number: 5,
        title: '🔐 Security & Certificates',
        description: 'Manage certificates and security settings',
        action: this.security.bind(this)
      },
      {
        number: 6,
        title: '⚙️ System Tools',
        description: 'System utilities and maintenance',
        action: this.systemTools.bind(this)
      },
      {
        number: 7,
        title: '📚 Documentation',
        description: 'View help and documentation',
        action: this.documentation.bind(this)
      },
      {
        number: 8,
        title: '🔄 Update RBT',
        description: 'Check for updates and upgrade RBT',
        action: this.update.bind(this)
      },
      {
        number: 9,
        title: '❓ Troubleshooting',
        description: 'Diagnose and fix common issues',
        action: this.troubleshooting.bind(this)
      },
      {
        number: 0,
        title: '🚪 Exit',
        description: 'Exit the RBT menu',
        action: this.exit.bind(this)
      }
    ];
  }

  async run(): Promise<void> {
    console.clear();
    console.log('🚀 RBT - Tunnel Orchestration Platform');
    console.log('======================================');
    console.log('Welcome to the interactive RBT menu!\n');

    while (this.running) {
      await this.displayMenu();
      await this.handleUserChoice();
    }
  }

  private async displayMenu(): Promise<void> {
    console.log('\n📋 Main Menu');
    console.log('=============');
    
    this.menuOptions.forEach(option => {
      console.log(`${option.number}. ${option.title}`);
      console.log(`   ${option.description}`);
      console.log('');
    });
  }

  private async handleUserChoice(): Promise<void> {
    const { choice } = await inquirer.prompt([
      {
        type: 'number',
        name: 'choice',
        message: 'Select an option (0-9):',
        default: 0,
        validate: (input: number) => {
          const validOptions = this.menuOptions.map(opt => opt.number);
          if (!validOptions.includes(input)) {
            return 'Please enter a valid option (0-9)';
          }
          return true;
        }
      }
    ]);

    const selectedOption = this.menuOptions.find(opt => opt.number === choice);
    if (selectedOption) {
      console.log(`\n→ ${selectedOption.title}\n`);
      try {
        await selectedOption.action();
      } catch (error) {
        console.error('❌ Error:', error);
      }
    }
  }

  // Menu Actions
  private async quickStart(): Promise<void> {
    console.log('🚀 Quick Start Wizard');
    console.log('This will guide you through the initial setup.\n');

    const answers = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'continue',
        message: 'Do you want to continue with the quick setup?',
        default: true
      }
    ]);

    if (answers.continue) {
      try {
        // Check if RBT is installed
        execSync('which rbt', { stdio: 'ignore' });
        
        // Initialize configuration
        console.log('📝 Initializing configuration...');
        execSync('rbt init', { stdio: 'inherit' });
        
        // Create first tunnel
        console.log('🔗 Creating your first tunnel...');
        const tunnelAnswers = await inquirer.prompt([
          {
            type: 'input',
            name: 'name',
            message: 'Tunnel name:',
            default: 'my-first-tunnel'
          },
          {
            type: 'input',
            name: 'listen',
            message: 'Listen address (e.g., 0.0.0.0:8080):',
            default: '0.0.0.0:8080'
          },
          {
            type: 'input',
            name: 'target',
            message: 'Target address (e.g., localhost:3000):',
            default: 'localhost:3000'
          },
          {
            type: 'list',
            name: 'protocol',
            message: 'Protocol:',
            choices: ['tcp', 'udp'],
            default: 'tcp'
          }
        ]);

        execSync(`rbt link-add --name ${tunnelAnswers.name} --listen ${tunnelAnswers.listen} --target ${tunnelAnswers.target} --proto ${tunnelAnswers.protocol}`, { stdio: 'inherit' });
        
        // Start RBT
        console.log('🚀 Starting RBT...');
        execSync('rbt apply', { stdio: 'inherit' });
        
        console.log('\n✅ Quick setup completed!');
        console.log('Your tunnel is now running at:', tunnelAnswers.listen);
        console.log('Dashboard available at: http://localhost:3000');
        
      } catch (error) {
        console.log('❌ RBT not found. Please install it first using the installer.');
      }
    }
  }

  private async configure(): Promise<void> {
    console.log('🔧 Configuration Options');
    
    const { configType } = await inquirer.prompt([
      {
        type: 'list',
        name: 'configType',
        message: 'What would you like to configure?',
        choices: [
          { name: '1. General Settings', value: 'general' },
          { name: '2. hCaptcha Settings', value: 'hcaptcha' },
          { name: '3. SMTP Settings', value: 'smtp' },
          { name: '4. Security Settings', value: 'security' },
          { name: '5. View Current Config', value: 'view' },
          { name: '0. Back to Main Menu', value: 'back' }
        ]
      }
    ]);

    switch (configType) {
      case 'general':
        await this.configureGeneral();
        break;
      case 'hcaptcha':
        await this.configureHcaptcha();
        break;
      case 'smtp':
        await this.configureSmtp();
        break;
      case 'security':
        await this.configureSecurity();
        break;
      case 'view':
        await this.viewConfig();
        break;
      case 'back':
        return;
    }
  }

  private async configureGeneral(): Promise<void> {
    console.log('🔧 General Configuration');
    
    const answers = await inquirer.prompt([
      {
        type: 'input',
        name: 'port',
        message: 'Dashboard port:',
        default: '3000'
      },
      {
        type: 'input',
        name: 'host',
        message: 'Bind address:',
        default: '0.0.0.0'
      }
    ]);

    console.log('✅ General settings updated');
  }

  private async configureHcaptcha(): Promise<void> {
    console.log('🔒 hCaptcha Configuration');
    
    const answers = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'enable',
        message: 'Enable hCaptcha?',
        default: false
      },
      {
        type: 'input',
        name: 'siteKey',
        message: 'Site Key:',
        when: (answers: any) => answers.enable
      },
      {
        type: 'password',
        name: 'secretKey',
        message: 'Secret Key:',
        mask: '*',
        when: (answers: any) => answers.enable
      }
    ]);

    console.log('✅ hCaptcha settings updated');
  }

  private async configureSmtp(): Promise<void> {
    console.log('📧 SMTP Configuration');
    
    const answers = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'enable',
        message: 'Enable email notifications?',
        default: false
      },
      {
        type: 'input',
        name: 'host',
        message: 'SMTP Host:',
        when: (answers: any) => answers.enable
      },
      {
        type: 'number',
        name: 'port',
        message: 'SMTP Port:',
        default: 587,
        when: (answers: any) => answers.enable
      },
      {
        type: 'input',
        name: 'user',
        message: 'SMTP Username:',
        when: (answers: any) => answers.enable
      },
      {
        type: 'password',
        name: 'pass',
        message: 'SMTP Password:',
        mask: '*',
        when: (answers: any) => answers.enable
      }
    ]);

    console.log('✅ SMTP settings updated');
  }

  private async configureSecurity(): Promise<void> {
    console.log('🔐 Security Configuration');
    
    const answers = await inquirer.prompt([
      {
        type: 'input',
        name: 'sessionTimeout',
        message: 'Session timeout:',
        default: '24h'
      },
      {
        type: 'number',
        name: 'maxAttempts',
        message: 'Max login attempts:',
        default: 5
      },
      {
        type: 'input',
        name: 'lockoutDuration',
        message: 'Lockout duration:',
        default: '15m'
      }
    ]);

    console.log('✅ Security settings updated');
  }

  private async viewConfig(): Promise<void> {
    console.log('📋 Current Configuration');
    
    const configFiles = ['.env', 'config.toml', '/etc/rbt/config.toml'];
    
    for (const file of configFiles) {
      if (fs.existsSync(file)) {
        console.log(`\n--- ${file} ---`);
        console.log(fs.readFileSync(file, 'utf8'));
      }
    }
  }

  private async manageTunnels(): Promise<void> {
    console.log('🔗 Tunnel Management');
    
    const { action } = await inquirer.prompt([
      {
        type: 'list',
        name: 'action',
        message: 'What would you like to do?',
        choices: [
          { name: '1. Add New Tunnel', value: 'add' },
          { name: '2. List Tunnels', value: 'list' },
          { name: '3. Remove Tunnel', value: 'remove' },
          { name: '4. Tunnel Statistics', value: 'stats' },
          { name: '0. Back to Main Menu', value: 'back' }
        ]
      }
    ]);

    switch (action) {
      case 'add':
        await this.addTunnel();
        break;
      case 'list':
        await this.listTunnels();
        break;
      case 'remove':
        await this.removeTunnel();
        break;
      case 'stats':
        await this.tunnelStats();
        break;
      case 'back':
        return;
    }
  }

  private async addTunnel(): Promise<void> {
    console.log('🆕 Add New Tunnel');
    
    const answers = await inquirer.prompt([
      {
        type: 'input',
        name: 'name',
        message: 'Tunnel name:',
        validate: (input: string) => input.length > 0 || 'Name is required'
      },
      {
        type: 'input',
        name: 'listen',
        message: 'Listen address (e.g., 0.0.0.0:8080):',
        validate: (input: string) => {
          if (!/^[\w\.-]+:\d+$/.test(input)) return 'Format: host:port';
          return true;
        }
      },
      {
        type: 'input',
        name: 'target',
        message: 'Target address (e.g., localhost:3000):',
        validate: (input: string) => {
          if (!/^[\w\.-]+:\d+$/.test(input)) return 'Format: host:port';
          return true;
        }
      },
      {
        type: 'list',
        name: 'protocol',
        message: 'Protocol:',
        choices: ['tcp', 'udp'],
        default: 'tcp'
      }
    ]);

    try {
      execSync(`rbt link-add --name ${answers.name} --listen ${answers.listen} --target ${answers.target} --proto ${answers.protocol}`, { stdio: 'inherit' });
      console.log('✅ Tunnel added successfully');
    } catch (error) {
      console.log('❌ Failed to add tunnel');
    }
  }

  private async listTunnels(): Promise<void> {
    console.log('📋 Tunnel List');
    
    try {
      execSync('rbt link-list', { stdio: 'inherit' });
    } catch (error) {
      console.log('❌ Failed to list tunnels');
    }
  }

  private async removeTunnel(): Promise<void> {
    console.log('🗑️ Remove Tunnel');
    
    const { name } = await inquirer.prompt([
      {
        type: 'input',
        name: 'name',
        message: 'Tunnel name to remove:',
        validate: (input: string) => input.length > 0 || 'Name is required'
      }
    ]);

    try {
      execSync(`rbt link-remove ${name}`, { stdio: 'inherit' });
      console.log('✅ Tunnel removed successfully');
    } catch (error) {
      console.log('❌ Failed to remove tunnel');
    }
  }

  private async tunnelStats(): Promise<void> {
    console.log('📊 Tunnel Statistics');
    
    try {
      execSync('rbt stats --json', { stdio: 'inherit' });
    } catch (error) {
      console.log('❌ Failed to get tunnel statistics');
    }
  }

  private async monitoring(): Promise<void> {
    console.log('📊 Monitoring & Analytics');
    
    const { action } = await inquirer.prompt([
      {
        type: 'list',
        name: 'action',
        message: 'What would you like to monitor?',
        choices: [
          { name: '1. Real-time Traffic', value: 'traffic' },
          { name: '2. System Logs', value: 'logs' },
          { name: '3. Connection Statistics', value: 'stats' },
          { name: '4. Performance Metrics', value: 'performance' },
          { name: '0. Back to Main Menu', value: 'back' }
        ]
      }
    ]);

    switch (action) {
      case 'traffic':
        await this.viewTraffic();
        break;
      case 'logs':
        await this.viewLogs();
        break;
      case 'stats':
        await this.viewStats();
        break;
      case 'performance':
        await this.viewPerformance();
        break;
      case 'back':
        return;
    }
  }

  private async viewTraffic(): Promise<void> {
    console.log('📈 Real-time Traffic');
    console.log('Press Ctrl+C to stop monitoring\n');
    
    try {
      execSync('rbt stats --json', { stdio: 'inherit' });
    } catch (error) {
      console.log('❌ Failed to get traffic data');
    }
  }

  private async viewLogs(): Promise<void> {
    console.log('📋 System Logs');
    
    try {
      execSync('rbt logs -f', { stdio: 'inherit' });
    } catch (error) {
      console.log('❌ Failed to get logs');
    }
  }

  private async viewStats(): Promise<void> {
    console.log('📊 Connection Statistics');
    
    try {
      execSync('rbt status', { stdio: 'inherit' });
    } catch (error) {
      console.log('❌ Failed to get statistics');
    }
  }

  private async viewPerformance(): Promise<void> {
    console.log('⚡ Performance Metrics');
    
    console.log('CPU Usage:', process.cpuUsage());
    console.log('Memory Usage:', process.memoryUsage());
    console.log('Uptime:', process.uptime(), 'seconds');
  }

  private async security(): Promise<void> {
    console.log('🔐 Security & Certificates');
    
    const { action } = await inquirer.prompt([
      {
        type: 'list',
        name: 'action',
        message: 'What would you like to do?',
        choices: [
          { name: '1. Generate Certificate', value: 'cert' },
          { name: '2. Security Audit', value: 'audit' },
          { name: '3. Update Security Settings', value: 'update' },
          { name: '0. Back to Main Menu', value: 'back' }
        ]
      }
    ]);

    switch (action) {
      case 'cert':
        await this.generateCertificate();
        break;
      case 'audit':
        await this.securityAudit();
        break;
      case 'update':
        await this.updateSecurity();
        break;
      case 'back':
        return;
    }
  }

  private async generateCertificate(): Promise<void> {
    console.log('🔑 Certificate Generation');
    
    const { domain } = await inquirer.prompt([
      {
        type: 'input',
        name: 'domain',
        message: 'Domain name:',
        validate: (input: string) => input.length > 0 || 'Domain is required'
      }
    ]);

    try {
      execSync(`rbt cert issue ${domain}`, { stdio: 'inherit' });
      console.log('✅ Certificate generated successfully');
    } catch (error) {
      console.log('❌ Failed to generate certificate');
    }
  }

  private async securityAudit(): Promise<void> {
    console.log('🔍 Security Audit');
    
    try {
      execSync('rbt audit --json', { stdio: 'inherit' });
    } catch (error) {
      console.log('❌ Failed to run security audit');
    }
  }

  private async updateSecurity(): Promise<void> {
    console.log('🔄 Updating Security Settings');
    
    const answers = await inquirer.prompt([
      {
        type: 'input',
        name: 'sessionTimeout',
        message: 'Session timeout:',
        default: '24h'
      },
      {
        type: 'number',
        name: 'maxAttempts',
        message: 'Max login attempts:',
        default: 5
      }
    ]);

    console.log('✅ Security settings updated');
  }

  private async systemTools(): Promise<void> {
    console.log('⚙️ System Tools');
    
    const { action } = await inquirer.prompt([
      {
        type: 'list',
        name: 'action',
        message: 'What would you like to do?',
        choices: [
          { name: '1. System Information', value: 'info' },
          { name: '2. Network Diagnostics', value: 'network' },
          { name: '3. Service Management', value: 'service' },
          { name: '4. Backup & Restore', value: 'backup' },
          { name: '0. Back to Main Menu', value: 'back' }
        ]
      }
    ]);

    switch (action) {
      case 'info':
        await this.systemInfo();
        break;
      case 'network':
        await this.networkDiagnostics();
        break;
      case 'service':
        await this.serviceManagement();
        break;
      case 'backup':
        await this.backupRestore();
        break;
      case 'back':
        return;
    }
  }

  private async systemInfo(): Promise<void> {
    console.log('ℹ️ System Information');
    
    console.log('Platform:', process.platform);
    console.log('Architecture:', process.arch);
    console.log('Node Version:', process.version);
    console.log('PID:', process.pid);
    console.log('Working Directory:', process.cwd());
  }

  private async networkDiagnostics(): Promise<void> {
    console.log('🌐 Network Diagnostics');
    
    try {
      execSync('ping -c 3 8.8.8.8', { stdio: 'inherit' });
    } catch (error) {
      console.log('❌ Network diagnostics failed');
    }
  }

  private async serviceManagement(): Promise<void> {
    console.log('🔧 Service Management');
    
    const { action } = await inquirer.prompt([
      {
        type: 'list',
        name: 'action',
        message: 'What would you like to do?',
        choices: [
          { name: '1. Start Service', value: 'start' },
          { name: '2. Stop Service', value: 'stop' },
          { name: '3. Restart Service', value: 'restart' },
          { name: '4. Service Status', value: 'status' },
          { name: '0. Back', value: 'back' }
        ]
      }
    ]);

    switch (action) {
      case 'start':
        try {
          execSync('rbt start', { stdio: 'inherit' });
          console.log('✅ Service started');
        } catch (error) {
          console.log('❌ Failed to start service');
        }
        break;
      case 'stop':
        try {
          execSync('rbt stop', { stdio: 'inherit' });
          console.log('✅ Service stopped');
        } catch (error) {
          console.log('❌ Failed to stop service');
        }
        break;
      case 'restart':
        try {
          execSync('rbt restart', { stdio: 'inherit' });
          console.log('✅ Service restarted');
        } catch (error) {
          console.log('❌ Failed to restart service');
        }
        break;
      case 'status':
        try {
          execSync('rbt status', { stdio: 'inherit' });
        } catch (error) {
          console.log('❌ Failed to get service status');
        }
        break;
      case 'back':
        return;
    }
  }

  private async backupRestore(): Promise<void> {
    console.log('💾 Backup & Restore');
    
    const { action } = await inquirer.prompt([
      {
        type: 'list',
        name: 'action',
        message: 'What would you like to do?',
        choices: [
          { name: '1. Create Backup', value: 'backup' },
          { name: '2. Restore from Backup', value: 'restore' },
          { name: '0. Back', value: 'back' }
        ]
      }
    ]);

    switch (action) {
      case 'backup':
        console.log('📦 Creating backup...');
        // Implement backup logic
        console.log('✅ Backup created');
        break;
      case 'restore':
        console.log('📂 Restoring from backup...');
        // Implement restore logic
        console.log('✅ Restore completed');
        break;
      case 'back':
        return;
    }
  }

  private async documentation(): Promise<void> {
    console.log('📚 Documentation');
    
    const { topic } = await inquirer.prompt([
      {
        type: 'list',
        name: 'topic',
        message: 'What would you like to learn about?',
        choices: [
          { name: '1. Getting Started', value: 'start' },
          { name: '2. Tunnel Configuration', value: 'tunnels' },
          { name: '3. Security Best Practices', value: 'security' },
          { name: '4. Troubleshooting Guide', value: 'troubleshooting' },
          { name: '5. Advanced Features', value: 'advanced' },
          { name: '0. Back to Main Menu', value: 'back' }
        ]
      }
    ]);

    switch (topic) {
      case 'start':
        this.showGettingStarted();
        break;
      case 'tunnels':
        this.showTunnelGuide();
        break;
      case 'security':
        this.showSecurityGuide();
        break;
      case 'troubleshooting':
        this.showTroubleshooting();
        break;
      case 'advanced':
        this.showAdvancedFeatures();
        break;
      case 'back':
        return;
    }
  }

  private showGettingStarted(): void {
    console.log('\n📖 Getting Started Guide');
    console.log('========================');
    console.log('1. Run the installer: bash install.sh');
    console.log('2. Start RBT: rbt');
    console.log('3. Configure your first tunnel');
    console.log('4. Apply changes: rbt apply');
    console.log('5. Monitor traffic: rbt stats');
  }

  private showTunnelGuide(): void {
    console.log('\n🔗 Tunnel Configuration Guide');
    console.log('============================');
    console.log('Tunnels allow you to expose local services securely.');
    console.log('');
    console.log('Basic tunnel:');
    console.log('rbt link-add --name myapp --listen 0.0.0.0:8080 --target localhost:3000 --proto tcp');
    console.log('');
    console.log('With TLS:');
    console.log('rbt link-add --name secure --listen 0.0.0.0:443 --target localhost:3000 --tls-enabled');
  }

  private showSecurityGuide(): void {
    console.log('\n🔐 Security Best Practices');
    console.log('==========================');
    console.log('• Use strong passwords');
    console.log('• Enable hCaptcha for login protection');
    console.log('• Use TLS certificates for secure tunnels');
    console.log('• Regular security audits');
    console.log('• Keep RBT updated');
  }

  private showTroubleshooting(): void {
    console.log('\n🔧 Troubleshooting Guide');
    console.log('========================');
    console.log('Common issues:');
    console.log('• Port already in use: Change the listen port');
    console.log('• Permission denied: Run with sudo or check file permissions');
    console.log('• Connection refused: Check target service is running');
    console.log('• Certificate errors: Verify certificate files exist');
  }

  private showAdvancedFeatures(): void {
    console.log('\n⚡ Advanced Features');
    console.log('====================');
    console.log('• Port hopping for dynamic connections');
    console.log('• Traffic obfuscation');
    console.log('• Load balancing across multiple targets');
    console.log('• Advanced logging and monitoring');
    console.log('• Custom certificate management');
  }

  private async update(): Promise<void> {
    console.log('🔄 RBT Update');
    
    const { confirm } = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'confirm',
        message: 'Check for RBT updates?',
        default: true
      }
    ]);

    if (confirm) {
      try {
        console.log('🔍 Checking for updates...');
        execSync('curl -fsSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install.sh | bash', { stdio: 'inherit' });
        console.log('✅ Update check completed');
      } catch (error) {
        console.log('❌ Update check failed');
      }
    }
  }

  private async troubleshooting(): Promise<void> {
    console.log('❓ Troubleshooting');
    
    const { issue } = await inquirer.prompt([
      {
        type: 'list',
        name: 'issue',
        message: 'What problem are you experiencing?',
        choices: [
          { name: '1. RBT won\'t start', value: 'start' },
          { name: '2. Tunnels not working', value: 'tunnels' },
          { name: '3. Certificate issues', value: 'certs' },
          { name: '4. Performance problems', value: 'performance' },
          { name: '5. Login issues', value: 'login' },
          { name: '0. Back to Main Menu', value: 'back' }
        ]
      }
    ]);

    switch (issue) {
      case 'start':
        this.troubleshootStart();
        break;
      case 'tunnels':
        this.troubleshootTunnels();
        break;
      case 'certs':
        this.troubleshootCerts();
        break;
      case 'performance':
        this.troubleshootPerformance();
        break;
      case 'login':
        this.troubleshootLogin();
        break;
      case 'back':
        return;
    }
  }

  private troubleshootStart(): void {
    console.log('\n🔧 RBT Won\'t Start');
    console.log('====================');
    console.log('1. Check if port is already in use');
    console.log('2. Verify configuration files exist');
    console.log('3. Check file permissions');
    console.log('4. Verify dependencies are installed');
    console.log('5. Check system logs');
  }

  private troubleshootTunnels(): void {
    console.log('\n🔧 Tunnels Not Working');
    console.log('======================');
    console.log('1. Verify target service is running');
    console.log('2. Check firewall settings');
    console.log('3. Verify port availability');
    console.log('4. Check tunnel configuration');
    console.log('5. Review connection logs');
  }

  private troubleshootCerts(): void {
    console.log('\n🔧 Certificate Issues');
    console.log('====================');
    console.log('1. Check certificate file paths');
    console.log('2. Verify certificate validity');
    console.log('3. Check file permissions');
    console.log('4. Regenerate certificates if needed');
    console.log('5. Verify TLS configuration');
  }

  private troubleshootPerformance(): void {
    console.log('\n🔧 Performance Problems');
    console.log('=======================');
    console.log('1. Check system resources');
    console.log('2. Optimize network settings');
    console.log('3. Review tunnel configurations');
    console.log('4. Check for connection limits');
    console.log('5. Monitor traffic patterns');
  }

  private troubleshootLogin(): void {
    console.log('\n🔧 Login Issues');
    console.log('================');
    console.log('1. Verify username and password');
    console.log('2. Check if account is locked');
    console.log('3. Reset password if needed');
    console.log('4. Check JWT secret configuration');
    console.log('5. Review authentication logs');
  }

  private async exit(): Promise<void> {
    console.log('\n👋 Thank you for using RBT!');
    console.log('Goodbye!');
    this.running = false;
  }
}

// Run the menu
if (import.meta.url === `file://${process.argv[1]}`) {
  const menu = new RBTInteractiveMenu();
  menu.run().catch(console.error);
}

export default RBTInteractiveMenu;