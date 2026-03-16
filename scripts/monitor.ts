#!/usr/bin/env tsx
/**
 * RBT Monitoring and Analytics System
 * Comprehensive monitoring with real-time metrics, alerting, and performance tracking
 */

import { EventEmitter } from 'events';
import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';
import { promisify } from 'util';

interface SystemMetrics {
  cpu: {
    usage: number;
    cores: number;
    loadAverage: number[];
  };
  memory: {
    total: number;
    used: number;
    free: number;
    usage: number;
  };
  disk: {
    total: number;
    used: number;
    free: number;
    usage: number;
  };
  network: {
    bytesIn: number;
    bytesOut: number;
    packetsIn: number;
    packetsOut: number;
    errors: number;
    drops: number;
  };
  processes: {
    total: number;
    running: number;
    sleeping: number;
    zombie: number;
  };
}

interface TunnelMetrics {
  name: string;
  listen: string;
  target: string;
  protocol: string;
  connections: number;
  bytesIn: number;
  bytesOut: number;
  packetsIn: number;
  packetsOut: number;
  errors: number;
  uptime: number;
  status: 'active' | 'inactive' | 'error';
}

interface Alert {
  id: string;
  type: 'cpu' | 'memory' | 'disk' | 'network' | 'tunnel' | 'system';
  severity: 'info' | 'warning' | 'critical';
  message: string;
  timestamp: Date;
  value: number;
  threshold: number;
  acknowledged: boolean;
}

interface PerformanceMetrics {
  tunnelLatency: number;
  throughput: number;
  packetLoss: number;
  jitter: number;
  bandwidthUtilization: number;
}

class MetricsCollector {
  private isCollecting = false;
  private collectionInterval: NodeJS.Timeout | null = null;
  private readonly interval = 5000; // 5 seconds

  async collectSystemMetrics(): Promise<SystemMetrics> {
    try {
      const cpu = await this.collectCPUMetrics();
      const memory = await this.collectMemoryMetrics();
      const disk = await this.collectDiskMetrics();
      const network = await this.collectNetworkMetrics();
      const processes = await this.collectProcessMetrics();

      return {
        cpu,
        memory,
        disk,
        network,
        processes
      };
    } catch (error) {
      throw new Error(`Failed to collect system metrics: ${error}`);
    }
  }

  private async collectCPUMetrics(): Promise<SystemMetrics['cpu']> {
    try {
      const cpuInfo = execSync('cat /proc/cpuinfo | grep processor | wc -l', { encoding: 'utf8' });
      const cores = parseInt(cpuInfo.trim());
      
      const loadAvg = execSync('uptime', { encoding: 'utf8' });
      const loadMatch = loadAvg.match(/load average[s]?:\s*([\d.]+),?\s*([\d.]+),?\s*([\d.]+)/);
      const loadAverage = loadMatch ? [parseFloat(loadMatch[1]), parseFloat(loadMatch[2]), parseFloat(loadMatch[3])] : [0, 0, 0];
      
      // Simple CPU usage calculation
      const cpuUsage = Math.random() * 100; // Placeholder - should use proper CPU stats

      return {
        usage: cpuUsage,
        cores,
        loadAverage
      };
    } catch (error) {
      return {
        usage: 0,
        cores: 1,
        loadAverage: [0, 0, 0]
      };
    }
  }

  private async collectMemoryMetrics(): Promise<SystemMetrics['memory']> {
    try {
      const memInfo = execSync('free -b', { encoding: 'utf8' });
      const lines = memInfo.split('\n');
      const memLine = lines.find(line => line.startsWith('Mem:'));
      
      if (memLine) {
        const parts = memLine.split(/\s+/);
        const total = parseInt(parts[1]);
        const used = parseInt(parts[2]);
        const free = parseInt(parts[3]);
        const usage = total > 0 ? (used / total) * 100 : 0;

        return {
          total,
          used,
          free,
          usage
        };
      }
    } catch (error) {
      // Return dummy values on error
    }

    return {
      total: 0,
      used: 0,
      free: 0,
      usage: 0
    };
  }

  private async collectDiskMetrics(): Promise<SystemMetrics['disk']> {
    try {
      const diskInfo = execSync('df -B1 /', { encoding: 'utf8' });
      const lines = diskInfo.split('\n');
      const diskLine = lines.find(line => line.includes('/'));
      
      if (diskLine) {
        const parts = diskLine.split(/\s+/);
        const total = parseInt(parts[1]);
        const used = parseInt(parts[2]);
        const free = parseInt(parts[3]);
        const usage = total > 0 ? (used / total) * 100 : 0;

        return {
          total,
          used,
          free,
          usage
        };
      }
    } catch (error) {
      // Return dummy values on error
    }

    return {
      total: 0,
      used: 0,
      free: 0,
      usage: 0
    };
  }

  private async collectNetworkMetrics(): Promise<SystemMetrics['network']> {
    try {
      const netStat = execSync('cat /proc/net/dev', { encoding: 'utf8' });
      const lines = netStat.split('\n');
      let totalBytesIn = 0;
      let totalBytesOut = 0;
      let totalPacketsIn = 0;
      let totalPacketsOut = 0;
      let totalErrors = 0;
      let totalDrops = 0;

      for (const line of lines) {
        if (line.includes(':')) {
          const parts = line.split(/\s+/);
          if (parts.length > 10 && !parts[0].startsWith('lo')) {
            totalBytesIn += parseInt(parts[2]) || 0;
            totalBytesOut += parseInt(parts[10]) || 0;
            totalPacketsIn += parseInt(parts[3]) || 0;
            totalPacketsOut += parseInt(parts[11]) || 0;
            totalErrors += (parseInt(parts[4]) || 0) + (parseInt(parts[12]) || 0);
            totalDrops += (parseInt(parts[5]) || 0) + (parseInt(parts[13]) || 0);
          }
        }
      }

      return {
        bytesIn: totalBytesIn,
        bytesOut: totalBytesOut,
        packetsIn: totalPacketsIn,
        packetsOut: totalPacketsOut,
        errors: totalErrors,
        drops: totalDrops
      };
    } catch (error) {
      return {
        bytesIn: 0,
        bytesOut: 0,
        packetsIn: 0,
        packetsOut: 0,
        errors: 0,
        drops: 0
      };
    }
  }

  private async collectProcessMetrics(): Promise<SystemMetrics['processes']> {
    try {
      const psOutput = execSync('ps aux | wc -l', { encoding: 'utf8' });
      const total = parseInt(psOutput.trim()) - 1; // Subtract header line
      
      const running = parseInt(execSync('ps aux | grep -c "^[^ ]* [^ ]* [^ ]* R"', { encoding: 'utf8' }).trim() || '0');
      const sleeping = parseInt(execSync('ps aux | grep -c "^[^ ]* [^ ]* [^ ]* S"', { encoding: 'utf8' }).trim() || '0');
      const zombie = parseInt(execSync('ps aux | grep -c "^[^ ]* [^ ]* [^ ]* Z"', { encoding: 'utf8' }).trim() || '0');

      return {
        total,
        running,
        sleeping,
        zombie
      };
    } catch (error) {
      return {
        total: 0,
        running: 0,
        sleeping: 0,
        zombie: 0
      };
    }
  }

  async collectTunnelMetrics(): Promise<TunnelMetrics[]> {
    // This would integrate with RBT's actual tunnel monitoring
    // For now, return mock data
    return [
      {
        name: 'web-tunnel',
        listen: '0.0.0.0:8080',
        target: 'localhost:3000',
        protocol: 'tcp',
        connections: 42,
        bytesIn: 1048576,
        bytesOut: 2097152,
        packetsIn: 1024,
        packetsOut: 2048,
        errors: 0,
        uptime: 3600,
        status: 'active'
      },
      {
        name: 'api-tunnel',
        listen: '0.0.0.0:9090',
        target: 'localhost:8080',
        protocol: 'tcp',
        connections: 15,
        bytesIn: 524288,
        bytesOut: 1048576,
        packetsIn: 512,
        packetsOut: 1024,
        errors: 1,
        uptime: 1800,
        status: 'active'
      }
    ];
  }

  async collectPerformanceMetrics(): Promise<PerformanceMetrics> {
    // Mock performance metrics
    return {
      tunnelLatency: Math.random() * 50 + 10, // 10-60ms
      throughput: Math.random() * 1000 + 100, // 100-1100 Mbps
      packetLoss: Math.random() * 0.1, // 0-0.1%
      jitter: Math.random() * 5, // 0-5ms
      bandwidthUtilization: Math.random() * 100 // 0-100%
    };
  }

  startCollecting(): void {
    if (this.isCollecting) return;
    
    this.isCollecting = true;
    this.collectionInterval = setInterval(async () => {
      try {
        const systemMetrics = await this.collectSystemMetrics();
        const tunnelMetrics = await this.collectTunnelMetrics();
        const performanceMetrics = await this.collectPerformanceMetrics();
        
        // Emit metrics for consumers
        this.emit('metrics', {
          system: systemMetrics,
          tunnels: tunnelMetrics,
          performance: performanceMetrics,
          timestamp: new Date()
        });
      } catch (error) {
        console.error('Error collecting metrics:', error);
      }
    }, this.interval);
  }

  stopCollecting(): void {
    this.isCollecting = false;
    if (this.collectionInterval) {
      clearInterval(this.collectionInterval);
      this.collectionInterval = null;
    }
  }
}

class AlertManager extends EventEmitter {
  private alerts: Alert[] = [];
  private thresholds = {
    cpu: 80,
    memory: 85,
    disk: 90,
    network: 1000,
    tunnel: 100
  };

  constructor() {
    super();
    this.startAlertMonitoring();
  }

  setThreshold(type: keyof typeof this.thresholds, value: number): void {
    this.thresholds[type] = value;
  }

  private startAlertMonitoring(): void {
    // Listen for metrics and check thresholds
    this.on('metrics', (metrics: any) => {
      this.checkThresholds(metrics);
    });
  }

  private checkThresholds(metrics: any): void {
    const { system, tunnels } = metrics;

    // CPU threshold
    if (system.cpu.usage > this.thresholds.cpu) {
      this.createAlert('cpu', 'warning', 
        `CPU usage is ${system.cpu.usage.toFixed(1)}% (threshold: ${this.thresholds.cpu}%)`,
        system.cpu.usage, this.thresholds.cpu);
    }

    // Memory threshold
    if (system.memory.usage > this.thresholds.memory) {
      this.createAlert('memory', 'warning',
        `Memory usage is ${system.memory.usage.toFixed(1)}% (threshold: ${this.thresholds.memory}%)`,
        system.memory.usage, this.thresholds.memory);
    }

    // Disk threshold
    if (system.disk.usage > this.thresholds.disk) {
      this.createAlert('disk', 'critical',
        `Disk usage is ${system.disk.usage.toFixed(1)}% (threshold: ${this.thresholds.disk}%)`,
        system.disk.usage, this.thresholds.disk);
    }

    // Tunnel connection threshold
    tunnels.forEach((tunnel: TunnelMetrics) => {
      if (tunnel.connections > this.thresholds.tunnel) {
        this.createAlert('tunnel', 'warning',
          `Tunnel ${tunnel.name} has ${tunnel.connections} connections (threshold: ${this.thresholds.tunnel})`,
          tunnel.connections, this.thresholds.tunnel);
      }
    });
  }

  private createAlert(
    type: Alert['type'],
    severity: Alert['severity'],
    message: string,
    value: number,
    threshold: number
  ): void {
    const alert: Alert = {
      id: crypto.randomUUID(),
      type,
      severity,
      message,
      timestamp: new Date(),
      value,
      threshold,
      acknowledged: false
    };

    this.alerts.push(alert);
    this.emit('alert', alert);

    // Keep only recent alerts
    if (this.alerts.length > 1000) {
      this.alerts = this.alerts.slice(-1000);
    }
  }

  getAlerts(): Alert[] {
    return [...this.alerts].reverse(); // Most recent first
  }

  getUnacknowledgedAlerts(): Alert[] {
    return this.alerts.filter(alert => !alert.acknowledged).reverse();
  }

  acknowledgeAlert(alertId: string): boolean {
    const alert = this.alerts.find(a => a.id === alertId);
    if (alert) {
      alert.acknowledged = true;
      return true;
    }
    return false;
  }

  clearAlerts(): void {
    this.alerts = [];
  }
}

class MetricsStorage {
  private dataDir: string;
  private maxStorageDays = 30;

  constructor(dataDir = '/var/lib/rbt/metrics') {
    this.dataDir = dataDir;
    this.ensureDataDirectory();
  }

  private ensureDataDirectory(): void {
    if (!fs.existsSync(this.dataDir)) {
      fs.mkdirSync(this.dataDir, { recursive: true });
    }
  }

  async storeMetrics(metrics: any): Promise<void> {
    const timestamp = new Date();
    const dateStr = timestamp.toISOString().split('T')[0];
    const filename = path.join(this.dataDir, `metrics-${dateStr}.json`);
    
    const entry = {
      timestamp: timestamp.toISOString(),
      metrics
    };

    let data: any[] = [];
    if (fs.existsSync(filename)) {
      try {
        const content = fs.readFileSync(filename, 'utf8');
        data = JSON.parse(content);
      } catch (error) {
        console.warn('Failed to read existing metrics file:', error);
      }
    }

    data.push(entry);

    // Keep only last 24 hours of data per file
    const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000);
    data = data.filter(item => new Date(item.timestamp) > cutoff);

    try {
      fs.writeFileSync(filename, JSON.stringify(data, null, 2));
    } catch (error) {
      console.error('Failed to store metrics:', error);
    }
  }

  async getMetrics(startTime: Date, endTime: Date): Promise<any[]> {
    const results: any[] = [];
    const current = new Date(startTime);

    while (current <= endTime) {
      const dateStr = current.toISOString().split('T')[0];
      const filename = path.join(this.dataDir, `metrics-${dateStr}.json`);
      
      if (fs.existsSync(filename)) {
        try {
          const content = fs.readFileSync(filename, 'utf8');
          const data = JSON.parse(content);
          
          const filtered = data.filter((item: any) => {
            const itemTime = new Date(item.timestamp);
            return itemTime >= startTime && itemTime <= endTime;
          });
          
          results.push(...filtered);
        } catch (error) {
          console.warn(`Failed to read metrics file ${filename}:`, error);
        }
      }

      current.setDate(current.getDate() + 1);
    }

    return results.sort((a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime());
  }

  cleanupOldData(): void {
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - this.maxStorageDays);

    try {
      const files = fs.readdirSync(this.dataDir);
      
      for (const file of files) {
        if (file.startsWith('metrics-') && file.endsWith('.json')) {
          const dateStr = file.replace('metrics-', '').replace('.json', '');
          const fileDate = new Date(dateStr);
          
          if (fileDate < cutoff) {
            const filepath = path.join(this.dataDir, file);
            fs.unlinkSync(filepath);
            console.log(`Deleted old metrics file: ${file}`);
          }
        }
      }
    } catch (error) {
      console.error('Failed to cleanup old metrics:', error);
    }
  }
}

export class RBTMonitor extends EventEmitter {
  private metricsCollector: MetricsCollector;
  private alertManager: AlertManager;
  private metricsStorage: MetricsStorage;
  private isMonitoring = false;

  constructor(dataDir?: string) {
    super();
    this.metricsCollector = new MetricsCollector();
    this.alertManager = new AlertManager();
    this.metricsStorage = new MetricsStorage(dataDir);

    // Connect components
    this.metricsCollector.on('metrics', (metrics: any) => {
      this.emit('metrics', metrics);
      this.alertManager.emit('metrics', metrics);
      this.metricsStorage.storeMetrics(metrics);
    });

    this.alertManager.on('alert', (alert: Alert) => {
      this.emit('alert', alert);
    });
  }

  startMonitoring(): void {
    if (this.isMonitoring) return;
    
    this.isMonitoring = true;
    this.metricsCollector.startCollecting();
    
    // Cleanup old data daily
    setInterval(() => {
      this.metricsStorage.cleanupOldData();
    }, 24 * 60 * 60 * 1000);

    this.emit('started');
    console.log('RBT monitoring started');
  }

  stopMonitoring(): void {
    this.isMonitoring = false;
    this.metricsCollector.stopCollecting();
    this.emit('stopped');
    console.log('RBT monitoring stopped');
  }

  getCurrentMetrics(): Promise<any> {
    return Promise.all([
      this.metricsCollector.collectSystemMetrics(),
      this.metricsCollector.collectTunnelMetrics(),
      this.metricsCollector.collectPerformanceMetrics()
    ]).then(([system, tunnels, performance]) => ({
      system,
      tunnels,
      performance,
      timestamp: new Date()
    }));
  }

  getAlerts(): Alert[] {
    return this.alertManager.getAlerts();
  }

  getUnacknowledgedAlerts(): Alert[] {
    return this.alertManager.getUnacknowledgedAlerts();
  }

  acknowledgeAlert(alertId: string): boolean {
    return this.alertManager.acknowledgeAlert(alertId);
  }

  getHistoricalMetrics(startTime: Date, endTime: Date): Promise<any[]> {
    return this.metricsStorage.getMetrics(startTime, endTime);
  }

  setAlertThreshold(type: string, value: number): void {
    this.alertManager.setThreshold(type as any, value);
  }

  isMonitoringActive(): boolean {
    return this.isMonitoring;
  }
}

// CLI interface
if (import.meta.url === `file://${process.argv[1]}`) {
  const monitor = new RBTMonitor();
  const command = process.argv[2];
  const arg1 = process.argv[3];
  const arg2 = process.argv[4];

  switch (command) {
    case 'start':
      monitor.startMonitoring();
      break;
    
    case 'stop':
      monitor.stopMonitoring();
      break;
    
    case 'status':
      console.log('Monitoring active:', monitor.isMonitoringActive());
      break;
    
    case 'metrics':
      monitor.getCurrentMetrics().then(metrics => {
        console.log('Current metrics:', JSON.stringify(metrics, null, 2));
      });
      break;
    
    case 'alerts':
      const alerts = monitor.getAlerts();
      console.log('Alerts:', JSON.stringify(alerts, null, 2));
      break;
    
    case 'acknowledge':
      if (arg1) {
        const result = monitor.acknowledgeAlert(arg1);
        console.log('Alert acknowledged:', result);
      } else {
        console.error('Please specify alert ID');
      }
      break;
    
    case 'history':
      if (arg1 && arg2) {
        const startTime = new Date(arg1);
        const endTime = new Date(arg2);
        monitor.getHistoricalMetrics(startTime, endTime).then(metrics => {
          console.log('Historical metrics:', JSON.stringify(metrics, null, 2));
        });
      } else {
        console.error('Please specify start and end dates (ISO format)');
      }
      break;
    
    case 'threshold':
      if (arg1 && arg2) {
        monitor.setAlertThreshold(arg1, parseFloat(arg2));
        console.log(`Alert threshold set: ${arg1} = ${arg2}`);
      } else {
        console.error('Please specify threshold type and value');
      }
      break;
    
    default:
      console.log('Usage: tsx monitor.ts [start|stop|status|metrics|alerts|acknowledge|history|threshold]');
  }
}