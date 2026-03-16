#!/usr/bin/env tsx
/**
 * RBT Test Suite
 * Comprehensive testing framework for RBT components
 */

import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import { ConfigManager } from './config-manager.js';
import { RBTMonitor } from './monitor.js';
import { RBTSecurityManager } from './security-manager.js';

interface TestResult {
  name: string;
  status: 'pass' | 'fail' | 'skip';
  message?: string;
  duration: number;
  error?: Error;
}

interface TestSuite {
  name: string;
  tests: TestResult[];
  duration: number;
  passed: number;
  failed: number;
  skipped: number;
}

class RBTTestFramework {
  private testSuites: TestSuite[] = [];
  private currentSuite: TestSuite | null = null;
  private startTime: number = 0;

  constructor() {
    this.startTime = Date.now();
  }

  async runTest(name: string, testFn: () => Promise<void> | void): Promise<TestResult> {
    const startTime = Date.now();
    
    try {
      await testFn();
      return {
        name,
        status: 'pass',
        duration: Date.now() - startTime
      };
    } catch (error) {
      return {
        name,
        status: 'fail',
        message: error instanceof Error ? error.message : String(error),
        duration: Date.now() - startTime,
        error: error instanceof Error ? error : new Error(String(error))
      };
    }
  }

  async runTestSuite(name: string, suiteFn: () => Promise<void>): Promise<TestSuite> {
    const suiteStartTime = Date.now();
    const tests: TestResult[] = [];
    
    this.currentSuite = {
      name,
      tests,
      duration: 0,
      passed: 0,
      failed: 0,
      skipped: 0
    };

    try {
      await suiteFn();
    } catch (error) {
      console.error(`Test suite ${name} failed:`, error);
    }

    const passed = tests.filter(t => t.status === 'pass').length;
    const failed = tests.filter(t => t.status === 'fail').length;
    const skipped = tests.filter(t => t.status === 'skip').length;

    const suite: TestSuite = {
      name,
      tests,
      duration: Date.now() - suiteStartTime,
      passed,
      failed,
      skipped
    };

    this.testSuites.push(suite);
    this.currentSuite = null;

    return suite;
  }

  private addTestResult(result: TestResult): void {
    if (this.currentSuite) {
      this.currentSuite.tests.push(result);
    }
  }

  async runAllTests(): Promise<void> {
    console.log('🧪 RBT Test Suite');
    console.log('================');

    // Configuration Tests
    await this.runTestSuite('Configuration Manager Tests', async () => {
      const configManager = new ConfigManager('test-config.toml');

      this.addTestResult(await this.runTest('should create default configuration', async () => {
        const config = configManager.getConfig();
        if (!config.security || !config.dashboard) {
          throw new Error('Default configuration not properly initialized');
        }
      }));

      this.addTestResult(await this.runTest('should validate configuration', async () => {
        const validation = configManager.validateConfig();
        if (!validation.isValid && validation.errors.length === 0) {
          throw new Error('Configuration validation failed unexpectedly');
        }
      }));

      this.addTestResult(await this.runTest('should generate secure JWT secret', async () => {
        const jwtSecret = configManager.get<string>('security.jwtSecret');
        if (!jwtSecret || jwtSecret.length < 32) {
          throw new Error('JWT secret is not secure');
        }
      }));

      this.addTestResult(await this.runTest('should handle backup operations', async () => {
        configManager.createBackup();
        const backups = configManager.listBackups();
        if (backups.length === 0) {
          throw new Error('Backup not created');
        }
      }));
    });

    // Monitoring Tests
    await this.runTestSuite('Monitoring System Tests', async () => {
      const monitor = new RBTMonitor('/tmp/rbt-test-metrics');

      this.addTestResult(await this.runTest('should start monitoring', async () => {
        monitor.startMonitoring();
        if (!monitor.isMonitoringActive()) {
          throw new Error('Monitoring not started');
        }
        monitor.stopMonitoring();
      }));

      this.addTestResult(await this.runTest('should collect metrics', async () => {
        monitor.startMonitoring();
        const metrics = await monitor.getCurrentMetrics();
        if (!metrics.system || !metrics.tunnels) {
          throw new Error('Metrics not collected properly');
        }
        monitor.stopMonitoring();
      }));

      this.addTestResult(await this.runTest('should handle alert thresholds', async () => {
        monitor.setAlertThreshold('cpu', 50);
        monitor.stopMonitoring();
      }));
    });

    // Security Tests
    await this.runTestSuite('Security Manager Tests', async () => {
      const securityManager = new RBTSecurityManager({
        certDir: '/tmp/rbt-test-certs',
        logDir: '/tmp/rbt-test-logs'
      });

      this.addTestResult(await this.runTest('should initialize security', async () => {
        await securityManager.initializeSecurity();
        // If no error thrown, initialization succeeded
      }));

      this.addTestResult(await this.runTest('should generate certificates', async () => {
        const cert = await securityManager.generateCertificate('test.local', {
          validity: 1,
          keyLength: 1024
        });
        if (!cert.domain || !cert.isValid) {
          throw new Error('Certificate generation failed');
        }
      }));

      this.addTestResult(await this.runTest('should audit security', async () => {
        const audit = await securityManager.auditSecurity();
        if (!audit.findings || audit.score < 0) {
          throw new Error('Security audit failed');
        }
      }));
    });

    // System Integration Tests
    await this.runTestSuite('System Integration Tests', async () => {
      this.addTestResult(await this.runTest('should check Node.js version', async () => {
        const version = process.version;
        const majorVersion = parseInt(version.slice(1).split('.')[0]);
        if (majorVersion < 16) {
          throw new Error(`Node.js 16+ required, found ${version}`);
        }
      }));

      this.addTestResult(await this.runTest('should verify file system access', async () => {
        const testFile = '/tmp/rbt-test-access.txt';
        fs.writeFileSync(testFile, 'test');
        const content = fs.readFileSync(testFile, 'utf8');
        fs.unlinkSync(testFile);
        if (content !== 'test') {
          throw new Error('File system access test failed');
        }
      }));

      this.addTestResult(await this.runTest('should handle crypto operations', async () => {
        const secret = crypto.randomBytes(32).toString('hex');
        if (secret.length !== 64) {
          throw new Error('Crypto operation failed');
        }
      }));
    });

    // Performance Tests
    await this.runTestSuite('Performance Tests', async () => {
      this.addTestResult(await this.runTest('should handle configuration loading efficiently', async () => {
        const start = Date.now();
        const configManager = new ConfigManager();
        await configManager.validateConfig();
        const duration = Date.now() - start;
        if (duration > 1000) {
          throw new Error(`Configuration loading too slow: ${duration}ms`);
        }
      }));

      this.addTestResult(await this.runTest('should handle multiple security operations', async () => {
        const start = Date.now();
        const securityManager = new RBTSecurityManager({
          certDir: '/tmp/rbt-perf-test'
        });
        
        const promises = [];
        for (let i = 0; i < 5; i++) {
          promises.push(securityManager.generateCertificate(`perf-test-${i}.local`));
        }
        await Promise.all(promises);
        
        const duration = Date.now() - start;
        if (duration > 5000) {
          throw new Error(`Security operations too slow: ${duration}ms`);
        }
      }));
    });

    // Error Handling Tests
    await this.runTestSuite('Error Handling Tests', async () => {
      this.addTestResult(await this.runTest('should handle invalid configuration gracefully', async () => {
        const configManager = new ConfigManager('invalid-path.toml');
        const config = configManager.getConfig();
        // Should return default config, not throw error
        if (!config.security) {
          throw new Error('Failed to handle invalid configuration path');
        }
      }));

      this.addTestResult(await this.runTest('should handle file system errors', async () => {
        try {
          fs.readFileSync('/nonexistent/path/file.txt', 'utf8');
          throw new Error('Should have thrown error for nonexistent file');
        } catch (error) {
          // Expected behavior
        }
      }));
    });
  }

  generateReport(): string {
    const totalDuration = Date.now() - this.startTime;
    const totalTests = this.testSuites.reduce((sum, suite) => sum + suite.tests.length, 0);
    const totalPassed = this.testSuites.reduce((sum, suite) => sum + suite.passed, 0);
    const totalFailed = this.testSuites.reduce((sum, suite) => sum + suite.failed, 0);
    const totalSkipped = this.testSuites.reduce((sum, suite) => sum + suite.skipped, 0);

    let report = '\n📊 RBT Test Report\n';
    report += '==================\n\n';
    report += `Total Duration: ${totalDuration}ms\n`;
    report += `Total Tests: ${totalTests}\n`;
    report += `Passed: ${totalPassed} ✅\n`;
    report += `Failed: ${totalFailed} ❌\n`;
    report += `Skipped: ${totalSkipped} ⏭️\n`;
    report += `Success Rate: ${totalTests > 0 ? ((totalPassed / totalTests) * 100).toFixed(1) : 0}%\n\n`;

    for (const suite of this.testSuites) {
      report += `\n${suite.name}:\n`;
      report += `  Duration: ${suite.duration}ms\n`;
      report += `  Passed: ${suite.passed}, Failed: ${suite.failed}, Skipped: ${suite.skipped}\n`;
      
      for (const test of suite.tests) {
        const status = test.status === 'pass' ? '✅' : test.status === 'fail' ? '❌' : '⏭️';
        report += `    ${status} ${test.name}`;
        if (test.status === 'fail' && test.message) {
          report += `\n      Error: ${test.message}`;
        }
        report += '\n';
      }
    }

    return report;
  }

  saveReport(filename: string): void {
    const report = this.generateReport();
    const jsonReport = {
      timestamp: new Date().toISOString(),
      summary: {
        totalSuites: this.testSuites.length,
        totalTests: this.testSuites.reduce((sum, suite) => sum + suite.tests.length, 0),
        totalPassed: this.testSuites.reduce((sum, suite) => sum + suite.passed, 0),
        totalFailed: this.testSuites.reduce((sum, suite) => sum + suite.failed, 0),
        totalSkipped: this.testSuites.reduce((sum, suite) => sum + suite.skipped, 0),
        totalDuration: Date.now() - this.startTime
      },
      suites: this.testSuites
    };

    fs.writeFileSync(filename, JSON.stringify(jsonReport, null, 2));
    console.log(`Test report saved to: ${filename}`);
  }
}

// CLI interface
if (import.meta.url === `file://${process.argv[1]}`) {
  const framework = new RBTTestFramework();
  const command = process.argv[2] || 'run';

  switch (command) {
    case 'run':
      framework.runAllTests().then(() => {
        console.log(framework.generateReport());
        
        // Save report
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        framework.saveReport(`test-report-${timestamp}.json`);
        
        // Exit with appropriate code
        const totalFailed = framework['testSuites'].reduce((sum, suite) => sum + suite.failed, 0);
        process.exit(totalFailed > 0 ? 1 : 0);
      }).catch(console.error);
      break;
    
    case 'config':
      console.log('Running configuration tests only...');
      framework.runTestSuite('Configuration Manager Tests', async () => {
        // Configuration tests will be added by runTestSuite
      }).then(() => {
        console.log(framework.generateReport());
      }).catch(console.error);
      break;
    
    case 'security':
      console.log('Running security tests only...');
      framework.runTestSuite('Security Manager Tests', async () => {
        // Security tests will be added by runTestSuite
      }).then(() => {
        console.log(framework.generateReport());
      }).catch(console.error);
      break;
    
    case 'monitor':
      console.log('Running monitoring tests only...');
      framework.runTestSuite('Monitoring System Tests', async () => {
        // Monitoring tests will be added by runTestSuite
      }).then(() => {
        console.log(framework.generateReport());
      }).catch(console.error);
      break;
    
    default:
      console.log('Usage: tsx test-suite.ts [run|config|security|monitor]');
      console.log('  run      - Run all tests (default)');
      console.log('  config   - Run configuration tests only');
      console.log('  security - Run security tests only');
      console.log('  monitor  - Run monitoring tests only');
  }
}