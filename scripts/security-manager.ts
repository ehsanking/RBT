#!/usr/bin/env tsx
/**
 * RBT Security Management System
 * Comprehensive security features including certificate management, audit logging, and threat detection
 */

import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { execSync } from 'child_process';

interface CertificateInfo {
  domain: string;
  subject: string;
  issuer: string;
  validFrom: Date;
  validTo: Date;
  serialNumber: string;
  fingerprint: string;
  isValid: boolean;
  daysUntilExpiry: number;
}

interface SecurityAudit {
  id: string;
  timestamp: Date;
  type: 'certificate' | 'configuration' | 'access' | 'system';
  status: 'pass' | 'fail' | 'warning';
  findings: SecurityFinding[];
  score: number;
}

interface SecurityFinding {
  severity: 'info' | 'low' | 'medium' | 'high' | 'critical';
  category: string;
  description: string;
  recommendation: string;
  evidence?: string;
}

interface AuditLog {
  id: string;
  timestamp: Date;
  user: string;
  action: string;
  resource: string;
  result: 'success' | 'failure';
  ip?: string;
  userAgent?: string;
  details?: any;
}

interface SecurityPolicy {
  passwordPolicy: {
    minLength: number;
    requireUppercase: boolean;
    requireLowercase: boolean;
    requireNumbers: boolean;
    requireSpecialChars: boolean;
    maxAge: number; // days
    historySize: number;
  };
  sessionPolicy: {
    maxIdleTime: number; // minutes
    maxTotalTime: number; // minutes
    maxConcurrent: number;
    requireMFA: boolean;
  };
  accessPolicy: {
    maxLoginAttempts: number;
    lockoutDuration: number; // minutes
    requireStrongAuth: boolean;
    allowedIPs?: string[];
    blockedIPs?: string[];
  };
  certificatePolicy: {
    minKeyLength: number;
    validAlgorithms: string[];
    maxValidity: number; // days
    renewalThreshold: number; // days before expiry
  };
}

export class CertificateManager {
  private certDir: string;
  private caKeyPath: string;
  private caCertPath: string;

  constructor(certDir = '/etc/rbt/certs') {
    this.certDir = certDir;
    this.caKeyPath = path.join(certDir, 'ca-key.pem');
    this.caCertPath = path.join(certDir, 'ca-cert.pem');
    this.ensureDirectories();
  }

  private ensureDirectories(): void {
    if (!fs.existsSync(this.certDir)) {
      fs.mkdirSync(this.certDir, { recursive: true, mode: 0o700 });
    }
  }

  async generateCertificate(domain: string, options: {
    keyLength?: number;
    validity?: number;
    algorithm?: string;
    san?: string[];
  } = {}): Promise<CertificateInfo> {
    const {
      keyLength = 2048,
      validity = 365,
      algorithm = 'RSA',
      san = []
    } = options;

    try {
      const keyPath = path.join(this.certDir, `${domain}-key.pem`);
      const certPath = path.join(this.certDir, `${domain}-cert.pem`);
      const csrPath = path.join(this.certDir, `${domain}-csr.pem`);

      // Generate private key
      execSync(`openssl genrsa -out "${keyPath}" ${keyLength}`, { stdio: 'ignore' });
      
      // Create certificate config
      const configPath = path.join(this.certDir, `${domain}.cnf`);
      const configContent = this.generateCertConfig(domain, san);
      fs.writeFileSync(configPath, configContent);

      // Generate certificate signing request
      execSync(`openssl req -new -key "${keyPath}" -out "${csrPath}" -config "${configPath}"`, { stdio: 'ignore' });
      
      // Generate self-signed certificate (or use CA if available)
      if (fs.existsSync(this.caKeyPath) && fs.existsSync(this.caCertPath)) {
        // Sign with CA
        execSync(`openssl x509 -req -in "${csrPath}" -CA "${this.caCertPath}" -CAkey "${this.caKeyPath}" -out "${certPath}" -days ${validity} -extensions v3_req -extfile "${configPath}"`, { stdio: 'ignore' });
      } else {
        // Self-signed
        execSync(`openssl x509 -req -in "${csrPath}" -signkey "${keyPath}" -out "${certPath}" -days ${validity}`, { stdio: 'ignore' });
      }

      // Clean up CSR and config
      fs.unlinkSync(csrPath);
      fs.unlinkSync(configPath);

      // Set secure permissions
      fs.chmodSync(keyPath, 0o600);
      fs.chmodSync(certPath, 0o644);

      return this.getCertificateInfo(certPath);
    } catch (error) {
      throw new Error(`Failed to generate certificate for ${domain}: ${error}`);
    }
  }

  private generateCertConfig(domain: string, san: string[]): string {
    return `[req]
default_bits = 2048
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]
C = US
ST = State
L = City
O = RBT Organization
OU = RBT Unit
CN = ${domain}

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
${san.map((name, index) => `DNS.${index + 1} = ${name}`).join('\n')}`;
  }

  async getCertificateInfo(certPath: string): Promise<CertificateInfo> {
    try {
      const certText = execSync(`openssl x509 -in "${certPath}" -text -noout`, { encoding: 'utf8' });
      
      const domainMatch = certText.match(/Subject:.*CN=([^,\n]+)/);
      const issuerMatch = certText.match(/Issuer: (.+)/);
      const serialMatch = certText.match(/Serial Number: (.+)/);
      const fingerprintMatch = certText.match(/SHA256 Fingerprint=([A-F0-9:]+)/);
      
      const validFromMatch = certText.match(/Not Before : (.+)/);
      const validToMatch = certText.match/Not After : (.+)/);
      
      if (!domainMatch || !validFromMatch || !validToMatch) {
        throw new Error('Invalid certificate format');
      }

      const validFrom = new Date(validFromMatch[1]);
      const validTo = new Date(validToMatch[1]);
      const now = new Date();
      const daysUntilExpiry = Math.ceil((validTo.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));

      return {
        domain: domainMatch[1].trim(),
        subject: domainMatch[0].replace('Subject: ', '').trim(),
        issuer: issuerMatch ? issuerMatch[1].trim() : 'Unknown',
        validFrom,
        validTo,
        serialNumber: serialMatch ? serialMatch[1].trim() : 'Unknown',
        fingerprint: fingerprintMatch ? fingerprintMatch[1].trim() : 'Unknown',
        isValid: daysUntilExpiry > 0,
        daysUntilExpiry
      };
    } catch (error) {
      throw new Error(`Failed to get certificate info: ${error}`);
    }
  }

  async generateCA(keyLength: number = 4096, validity: number = 3650): Promise<void> {
    try {
      const caKeyPath = path.join(this.certDir, 'ca-key.pem');
      const caCertPath = path.join(this.certDir, 'ca-cert.pem');

      // Generate CA private key
      execSync(`openssl genrsa -out "${caKeyPath}" ${keyLength}`, { stdio: 'ignore' });
      
      // Generate CA certificate
      execSync(`openssl req -new -x509 -key "${caKeyPath}" -out "${caCertPath}" -days ${validity} -subj "/C=US/ST=State/L=City/O=RBT CA/CN=RBT Root CA"`, { stdio: 'ignore' });

      fs.chmodSync(caKeyPath, 0o600);
      fs.chmodSync(caCertPath, 0o644);

      console.log('CA certificate generated successfully');
    } catch (error) {
      throw new Error(`Failed to generate CA: ${error}`);
    }
  }

  listCertificates(): CertificateInfo[] {
    const certificates: CertificateInfo[] = [];
    
    try {
      const files = fs.readdirSync(this.certDir);
      const certFiles = files.filter(file => file.endsWith('-cert.pem'));

      for (const certFile of certFiles) {
        const certPath = path.join(this.certDir, certFile);
        try {
          const info = this.getCertificateInfo(certPath);
          certificates.push(info);
        } catch (error) {
          console.warn(`Failed to read certificate ${certFile}:`, error);
        }
      }
    } catch (error) {
      console.error('Failed to list certificates:', error);
    }

    return certificates;
  }

  async revokeCertificate(domain: string): Promise<void> {
    try {
      const keyPath = path.join(this.certDir, `${domain}-key.pem`);
      const certPath = path.join(this.certDir, `${domain}-cert.pem`);

      if (fs.existsSync(keyPath)) {
        fs.unlinkSync(keyPath);
      }
      
      if (fs.existsSync(certPath)) {
        fs.unlinkSync(certPath);
      }

      console.log(`Certificate for ${domain} revoked`);
    } catch (error) {
      throw new Error(`Failed to revoke certificate: ${error}`);
    }
  }
}

export class SecurityAuditor {
  private policies: SecurityPolicy;

  constructor(policies?: Partial<SecurityPolicy>) {
    this.policies = {
      passwordPolicy: {
        minLength: 8,
        requireUppercase: true,
        requireLowercase: true,
        requireNumbers: true,
        requireSpecialChars: true,
        maxAge: 90,
        historySize: 5,
        ...policies?.passwordPolicy
      },
      sessionPolicy: {
        maxIdleTime: 30,
        maxTotalTime: 480,
        maxConcurrent: 3,
        requireMFA: false,
        ...policies?.sessionPolicy
      },
      accessPolicy: {
        maxLoginAttempts: 5,
        lockoutDuration: 15,
        requireStrongAuth: true,
        ...policies?.accessPolicy
      },
      certificatePolicy: {
        minKeyLength: 2048,
        validAlgorithms: ['RSA', 'ECDSA', 'Ed25519'],
        maxValidity: 365,
        renewalThreshold: 30,
        ...policies?.certificatePolicy
      }
    };
  }

  async auditConfiguration(configPath: string): Promise<SecurityAudit> {
    const findings: SecurityFinding[] = [];
    
    try {
      const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      
      // Check JWT secret
      if (!config.security?.jwtSecret) {
        findings.push({
          severity: 'critical',
          category: 'Authentication',
          description: 'JWT secret is not configured',
          recommendation: 'Generate a secure JWT secret with at least 32 characters',
          evidence: 'Missing jwtSecret in configuration'
        });
      } else if (config.security.jwtSecret.length < 32) {
        findings.push({
          severity: 'high',
          category: 'Authentication',
          description: 'JWT secret is too short',
          recommendation: 'Use a JWT secret with at least 32 characters',
          evidence: `Current length: ${config.security.jwtSecret.length}`
        });
      }

      // Check password policy
      if (!config.security?.passwordPolicy) {
        findings.push({
          severity: 'medium',
          category: 'Access Control',
          description: 'Password policy is not configured',
          recommendation: 'Implement a strong password policy',
          evidence: 'Missing passwordPolicy configuration'
        });
      }

      // Check session security
      if (!config.security?.sessionTimeout) {
        findings.push({
          severity: 'medium',
          category: 'Session Management',
          description: 'Session timeout is not configured',
          recommendation: 'Set a reasonable session timeout (e.g., 24 hours)',
          evidence: 'Missing sessionTimeout configuration'
        });
      }

      // Check HTTPS enforcement
      if (config.security?.forceHttps === false) {
        findings.push({
          severity: 'medium',
          category: 'Transport Security',
          description: 'HTTPS is not enforced',
          recommendation: 'Enable HTTPS enforcement for all connections',
          evidence: 'forceHttps is set to false'
        });
      }

    } catch (error) {
      findings.push({
        severity: 'critical',
        category: 'Configuration',
        description: 'Failed to read configuration file',
        recommendation: 'Verify configuration file exists and is valid JSON',
        evidence: `Error: ${error}`
      });
    }

    return this.createAudit('configuration', findings);
  }

  async auditCertificates(certDir: string): Promise<SecurityAudit> {
    const findings: SecurityFinding[] = [];
    
    try {
      const certManager = new CertificateManager(certDir);
      const certificates = certManager.listCertificates();

      for (const cert of certificates) {
        // Check certificate validity
        if (!cert.isValid) {
          findings.push({
            severity: 'critical',
            category: 'Certificate',
            description: `Certificate for ${cert.domain} has expired`,
            recommendation: 'Renew the certificate immediately',
            evidence: `Expired on: ${cert.validTo.toISOString()}`
          });
        } else if (cert.daysUntilExpiry < this.policies.certificatePolicy.renewalThreshold) {
          findings.push({
            severity: 'warning',
            category: 'Certificate',
            description: `Certificate for ${cert.domain} is expiring soon`,
            recommendation: 'Plan certificate renewal',
            evidence: `Expires in ${cert.daysUntilExpiry} days`
          });
        }
      }

      if (certificates.length === 0) {
        findings.push({
          severity: 'info',
          category: 'Certificate',
          description: 'No certificates found',
          recommendation: 'Generate certificates for secure communication',
          evidence: 'No certificates in certificate directory'
        });
      }

    } catch (error) {
      findings.push({
        severity: 'high',
        category: 'Certificate',
        description: 'Failed to audit certificates',
        recommendation: 'Verify certificate directory and permissions',
        evidence: `Error: ${error}`
      });
    }

    return this.createAudit('certificate', findings);
  }

  async auditSystem(): Promise<SecurityAudit> {
    const findings: SecurityFinding[] = [];

    try {
      // Check file permissions
      const configFiles = ['/etc/rbt/config.toml', '/usr/local/bin/rbt'];
      for (const file of configFiles) {
        if (fs.existsSync(file)) {
          const stats = fs.statSync(file);
          const mode = stats.mode & parseInt('777', 8);
          
          if (file.includes('.toml') && (mode & parseInt('077', 8))) {
            findings.push({
              severity: 'medium',
              category: 'File Permissions',
              description: `Configuration file ${file} has overly permissive permissions`,
              recommendation: 'Set file permissions to 600 for configuration files',
              evidence: `Current permissions: ${mode.toString(8)}`
            });
          }
        }
      }

      // Check for security updates
      try {
        execSync('which apt', { stdio: 'ignore' });
        const updates = execSync('apt list --upgradable 2>/dev/null | grep -i security | wc -l', { encoding: 'utf8' });
        const securityUpdates = parseInt(updates.trim());
        
        if (securityUpdates > 0) {
          findings.push({
            severity: 'high',
            category: 'System Updates',
            description: `System has ${securityUpdates} pending security updates`,
            recommendation: 'Apply security updates immediately',
            evidence: `Security updates available: ${securityUpdates}`
          });
        }
      } catch (error) {
        // Ignore if apt is not available
      }

      // Check firewall status
      try {
        execSync('which ufw', { stdio: 'ignore' });
        const ufwStatus = execSync('ufw status | grep -i status', { encoding: 'utf8' });
        
        if (!ufwStatus.includes('active')) {
          findings.push({
            severity: 'high',
            category: 'Network Security',
            description: 'UFW firewall is not active',
            recommendation: 'Enable the firewall to protect against network attacks',
            evidence: 'UFW status: inactive'
          });
        }
      } catch (error) {
        // Ignore if ufw is not available
      }

    } catch (error) {
      findings.push({
        severity: 'medium',
        category: 'System',
        description: 'Failed to audit system security',
        recommendation: 'Verify system permissions and configuration',
        evidence: `Error: ${error}`
      });
    }

    return this.createAudit('system', findings);
  }

  private createAudit(type: SecurityAudit['type'], findings: SecurityFinding[]): SecurityAudit {
    const score = this.calculateSecurityScore(findings);
    
    return {
      id: crypto.randomUUID(),
      timestamp: new Date(),
      type,
      status: score >= 80 ? 'pass' : score >= 60 ? 'warning' : 'fail',
      findings,
      score
    };
  }

  private calculateSecurityScore(findings: SecurityFinding[]): number {
    if (findings.length === 0) return 100;
    
    const severityWeights = {
      info: 0,
      low: 5,
      medium: 10,
      high: 20,
      critical: 40
    };

    const totalPenalty = findings.reduce((sum, finding) => {
      return sum + (severityWeights[finding.severity] || 0);
    }, 0);

    return Math.max(0, 100 - totalPenalty);
  }
}

export class AuditLogger {
  private logDir: string;
  private maxLogSize: number;
  private maxLogFiles: number;

  constructor(logDir = '/var/log/rbt/audit', maxLogSize = 10 * 1024 * 1024, maxLogFiles = 10) {
    this.logDir = logDir;
    this.maxLogSize = maxLogSize;
    this.maxLogFiles = maxLogFiles;
    this.ensureDirectories();
  }

  private ensureDirectories(): void {
    if (!fs.existsSync(this.logDir)) {
      fs.mkdirSync(this.logDir, { recursive: true, mode: 0o700 });
    }
  }

  async logAccess(auditLog: Omit<AuditLog, 'id'>): Promise<void> {
    const logEntry: AuditLog = {
      id: crypto.randomUUID(),
      ...auditLog
    };

    const logFile = path.join(this.logDir, `audit-${new Date().toISOString().split('T')[0]}.json`);
    const logLine = JSON.stringify(logEntry) + '\n';

    try {
      fs.appendFileSync(logFile, logLine);
      this.rotateLogsIfNeeded();
    } catch (error) {
      console.error('Failed to write audit log:', error);
    }
  }

  private rotateLogsIfNeeded(): void {
    try {
      const files = fs.readdirSync(this.logDir)
        .filter(file => file.startsWith('audit-') && file.endsWith('.json'))
        .sort()
        .reverse();

      if (files.length > this.maxLogFiles) {
        const oldFiles = files.slice(this.maxLogFiles);
        for (const file of oldFiles) {
          fs.unlinkSync(path.join(this.logDir, file));
        }
      }

      // Check current log file size
      const currentFile = `audit-${new Date().toISOString().split('T')[0]}.json`;
      const currentPath = path.join(this.logDir, currentFile);
      
      if (fs.existsSync(currentPath) && fs.statSync(currentPath).size > this.maxLogSize) {
        // Rotate current file
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const rotatedPath = path.join(this.logDir, `audit-${timestamp}.json`);
        fs.renameSync(currentPath, rotatedPath);
      }
    } catch (error) {
      console.error('Failed to rotate logs:', error);
    }
  }

  getAuditLogs(startDate: Date, endDate: Date, filters: {
    user?: string;
    action?: string;
    result?: 'success' | 'failure';
  } = {}): AuditLog[] {
    const logs: AuditLog[] = [];
    
    try {
      const files = fs.readdirSync(this.logDir)
        .filter(file => file.startsWith('audit-') && file.endsWith('.json'))
        .sort();

      for (const file of files) {
        const filePath = path.join(this.logDir, file);
        const fileDate = new Date(file.replace('audit-', '').replace('.json', ''));
        
        if (fileDate >= startDate && fileDate <= endDate) {
          const content = fs.readFileSync(filePath, 'utf8');
          const lines = content.split('\n').filter(line => line.trim());
          
          for (const line of lines) {
            try {
              const log: AuditLog = JSON.parse(line);
              const logDate = new Date(log.timestamp);
              
              if (logDate >= startDate && logDate <= endDate) {
                if (this.matchesFilters(log, filters)) {
                  logs.push(log);
                }
              }
            } catch (error) {
              // Skip invalid log entries
            }
          }
        }
      }
    } catch (error) {
      console.error('Failed to read audit logs:', error);
    }

    return logs.sort((a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime());
  }

  private matchesFilters(log: AuditLog, filters: any): boolean {
    if (filters.user && log.user !== filters.user) return false;
    if (filters.action && log.action !== filters.action) return false;
    if (filters.result && log.result !== filters.result) return false;
    return true;
  }
}

export class RBTSecurityManager {
  private certificateManager: CertificateManager;
  private securityAuditor: SecurityAuditor;
  private auditLogger: AuditLogger;

  constructor(options: {
    certDir?: string;
    logDir?: string;
    policies?: Partial<SecurityPolicy>;
  } = {}) {
    this.certificateManager = new CertificateManager(options.certDir);
    this.securityAuditor = new SecurityAuditor(options.policies);
    this.auditLogger = new AuditLogger(options.logDir);
  }

  async initializeSecurity(): Promise<void> {
    try {
      // Generate CA if it doesn't exist
      if (!fs.existsSync(this.certificateManager['caCertPath'])) {
        await this.certificateManager.generateCA();
        console.log('CA certificate generated');
      }

      // Run initial security audit
      const audit = await this.auditSecurity();
      console.log('Initial security audit completed:', audit.status);

      // Log security initialization
      await this.auditLogger.logAccess({
        timestamp: new Date(),
        user: 'system',
        action: 'security-initialize',
        resource: 'security-system',
        result: 'success'
      });

    } catch (error) {
      console.error('Failed to initialize security:', error);
      throw error;
    }
  }

  async generateCertificate(domain: string, options?: any): Promise<CertificateInfo> {
    const result = await this.certificateManager.generateCertificate(domain, options);
    
    await this.auditLogger.logAccess({
      timestamp: new Date(),
      user: 'admin',
      action: 'certificate-generate',
      resource: `certificate:${domain}`,
      result: 'success',
      details: { domain, ...options }
    });

    return result;
  }

  async auditSecurity(): Promise<SecurityAudit> {
    const configAudit = await this.securityAuditor.auditConfiguration('/etc/rbt/config.toml');
    const certAudit = await this.securityAuditor.auditCertificates(this.certificateManager['certDir']);
    const systemAudit = await this.securityAuditor.auditSystem();

    // Combine audits
    const combinedFindings = [
      ...configAudit.findings,
      ...certAudit.findings,
      ...systemAudit.findings
    ];

    const overallScore = Math.min(configAudit.score, certAudit.score, systemAudit.score);

    return {
      id: crypto.randomUUID(),
      timestamp: new Date(),
      type: 'system',
      status: overallScore >= 80 ? 'pass' : overallScore >= 60 ? 'warning' : 'fail',
      findings: combinedFindings,
      score: overallScore
    };
  }

  async logAccess(user: string, action: string, resource: string, result: 'success' | 'failure', details?: any): Promise<void> {
    await this.auditLogger.logAccess({
      timestamp: new Date(),
      user,
      action,
      resource,
      result,
      details
    });
  }

  getCertificateManager(): CertificateManager {
    return this.certificateManager;
  }

  getSecurityAuditor(): SecurityAuditor {
    return this.securityAuditor;
  }

  getAuditLogger(): AuditLogger {
    return this.auditLogger;
  }
}

// CLI interface
if (import.meta.url === `file://${process.argv[1]}`) {
  const securityManager = new RBTSecurityManager();
  const command = process.argv[2];
  const arg1 = process.argv[3];
  const arg2 = process.argv[4];

  switch (command) {
    case 'init':
      securityManager.initializeSecurity().then(() => {
        console.log('Security system initialized');
      }).catch(console.error);
      break;
    
    case 'generate-cert':
      if (arg1) {
        securityManager.generateCertificate(arg1).then(cert => {
          console.log('Certificate generated:', cert.domain);
        }).catch(console.error);
      } else {
        console.error('Please specify domain');
      }
      break;
    
    case 'audit':
      securityManager.auditSecurity().then(audit => {
        console.log('Security audit:', audit.status, `Score: ${audit.score}/100`);
        console.log('Findings:', audit.findings.length);
      }).catch(console.error);
      break;
    
    case 'list-certs':
      const certs = securityManager.getCertificateManager().listCertificates();
      console.log('Certificates:');
      certs.forEach(cert => {
        console.log(`- ${cert.domain}: ${cert.isValid ? 'Valid' : 'Invalid'} (${cert.daysUntilExpiry} days)`);
      });
      break;
    
    case 'logs':
      const startDate = arg1 ? new Date(arg1) : new Date(Date.now() - 24 * 60 * 60 * 1000);
      const endDate = arg2 ? new Date(arg2) : new Date();
      
      securityManager.getAuditLogger().getAuditLogs(startDate, endDate).then(logs => {
        console.log(`Found ${logs.length} audit logs`);
        logs.slice(-10).forEach(log => {
          console.log(`${log.timestamp}: ${log.user} ${log.action} ${log.resource} (${log.result})`);
        });
      }).catch(console.error);
      break;
    
    default:
      console.log('Usage: tsx security-manager.ts [init|generate-cert|audit|list-certs|logs]');
  }
}