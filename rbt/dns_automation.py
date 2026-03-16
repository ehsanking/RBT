#!/usr/bin/env python3
"""
RBT DNS Automation Script
Automated DNS testing, selection, and monitoring for RBT project
"""

import asyncio
import json
import logging
import argparse
import sys
import os
from pathlib import Path
from datetime import datetime
import signal

# Add the current directory to Python path
sys.path.insert(0, str(Path(__file__).parent))

from dns_manager import DNSManager, DNSTester
from dns_tunnel import DNSTunnelManager

class RBTDNSAutomation:
    """Main automation system for RBT DNS management"""
    
    def __init__(self):
        self.logger = self._setup_logger()
        self.dns_manager = DNSManager()
        self.dns_tunnel = DNSTunnelManager()
        self.running = False
        
    def _setup_logger(self) -> logging.Logger:
        """Setup logging configuration"""
        logger = logging.getLogger('rbt_dns_automation')
        logger.setLevel(logging.INFO)
        
        if not logger.handlers:
            handler = logging.StreamHandler()
            formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
            handler.setFormatter(formatter)
            logger.addHandler(handler)
            
        return logger
    
    async def initialize(self, preferred_countries: list = None) -> bool:
        """Initialize the DNS automation system"""
        try:
            self.logger.info("Initializing RBT DNS Automation")
            
            # Initialize DNS manager with preferred countries
            if preferred_countries:
                self.logger.info(f"Using preferred countries: {preferred_countries}")
                # This would need to be implemented in DNSManager
                pass
            
            # Initialize DNS testing and selection
            await self.dns_manager.initialize()
            
            # Start monitoring
            self.dns_manager.start_monitoring()
            
            self.running = True
            self.logger.info("RBT DNS Automation initialized successfully")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to initialize DNS automation: {e}")
            return False
    
    def get_status(self) -> dict:
        """Get current system status"""
        dns_status = {
            'current_dns': self.dns_manager.current_dns,
            'backup_dns_count': len(self.dns_manager.backup_dns),
            'monitoring_active': self.dns_manager.monitoring,
            'tunnel_status': self.dns_tunnel.get_tunnel_status()
        }
        
        return {
            'running': self.running,
            'dns_status': dns_status,
            'timestamp': datetime.now().isoformat()
        }
    
    def print_status(self):
        """Print current status to console"""
        status = self.get_status()
        
        print("\n" + "="*60)
        print("RBT DNS AUTOMATION STATUS")
        print("="*60)
        
        if status['running']:
            print("✅ System Status: RUNNING")
        else:
            print("❌ System Status: STOPPED")
        
        dns_status = status['dns_status']
        
        if dns_status['current_dns']:
            current = dns_status['current_dns']
            print(f"🌐 Primary DNS: {current['ip']} ({current['name']})")
            print(f"📍 Location: {current['country']} - {current['city']}")
            print(f"⚡ Latency: {current['avg_latency']:.1f}ms")
            print(f"✨ Status: {current['status'].upper()}")
        else:
            print("❌ No DNS server selected")
        
        print(f"🔀 Backup DNS: {dns_status['backup_dns_count']} servers")
        print(f"📊 Monitoring: {'Active' if dns_status['monitoring_active'] else 'Inactive'}")
        
        tunnel_status = dns_status['tunnel_status']
        print(f"🚇 DNS Tunnel: {'Active' if tunnel_status['tunnel_active'] else 'Inactive'}")
        
        print(f"🕐 Last Update: {status['timestamp']}")
        print("="*60)
    
    async def test_dns_performance(self, servers: list = None) -> dict:
        """Test DNS performance and return results"""
        try:
            self.logger.info("Starting DNS performance test")
            
            # Use DNS tester from manager
            tester = self.dns_manager.tester
            
            if servers:
                # Test specific servers
                results = []
                for server in servers:
                    result = await tester.test_dns_server(server)
                    results.append(result)
            else:
                # Test all servers
                results = await tester.test_all_servers()
            
            # Select best servers
            best_servers = tester.select_best_servers(results, count=10)
            
            # Generate summary
            summary = {
                'total_tested': len(results),
                'successful': len([r for r in results if r['status'] in ['excellent', 'good']]),
                'failed': len([r for r in results if r['status'] in ['failed', 'error']]),
                'best_servers': best_servers[:5],
                'test_timestamp': datetime.now().isoformat()
            }
            
            self.logger.info(f"DNS test completed: {summary['successful']}/{summary['total_tested']} successful")
            return summary
            
        except Exception as e:
            self.logger.error(f"DNS performance test failed: {e}")
            return {'error': str(e)}
    
    def setup_dns_tunnel(self, domain: str, server_ip: str) -> bool:
        """Setup DNS tunnel for censorship resistance"""
        try:
            self.logger.info(f"Setting up DNS tunnel for {domain}")
            
            # Install dnstt if needed
            if not (self.dns_tunnel.server_dir / 'dnstt-server').exists():
                self.logger.info("Installing dnstt...")
                if not self.dns_tunnel.install_dnstt():
                    self.logger.error("Failed to install dnstt")
                    return False
            
            # Generate server keys
            privkey, pubkey = self.dns_tunnel.generate_server_keys()
            if not pubkey:
                self.logger.error("Failed to generate server keys")
                return False
            
            # Create DNS zone configuration
            dns_config = self.dns_tunnel.create_dns_zone_config(domain, server_ip)
            
            # Create client configuration
            client_config = self.dns_tunnel.create_client_config(domain, pubkey)
            
            self.logger.info("DNS tunnel setup completed successfully")
            return True
            
        except Exception as e:
            self.logger.error(f"DNS tunnel setup failed: {e}")
            return False
    
    def start_dns_tunnel_server(self, domain: str, port: int = 53) -> bool:
        """Start DNS tunnel server"""
        try:
            self.logger.info(f"Starting DNS tunnel server for {domain}")
            return self.dns_tunnel.start_server(domain, port)
        except Exception as e:
            self.logger.error(f"Failed to start DNS tunnel server: {e}")
            return False
    
    def start_dns_tunnel_client(self, socks_port: int = 9050) -> bool:
        """Start DNS tunnel client"""
        try:
            self.logger.info(f"Starting DNS tunnel client on port {socks_port}")
            return self.dns_tunnel.start_client(socks_port=socks_port)
        except Exception as e:
            self.logger.error(f"Failed to start DNS tunnel client: {e}")
            return False
    
    def test_dns_tunnel(self, socks_port: int = 9050) -> bool:
        """Test DNS tunnel connectivity"""
        try:
            self.logger.info("Testing DNS tunnel connectivity...")
            return self.dns_tunnel.test_tunnel_connectivity(socks_port)
        except Exception as e:
            self.logger.error(f"DNS tunnel test failed: {e}")
            return False
    
    def stop_dns_tunnel(self) -> bool:
        """Stop DNS tunnel"""
        try:
            self.logger.info("Stopping DNS tunnel...")
            return self.dns_tunnel.stop_tunnel()
        except Exception as e:
            self.logger.error(f"Failed to stop DNS tunnel: {e}")
            return False
    
    def shutdown(self):
        """Shutdown the automation system"""
        self.logger.info("Shutting down RBT DNS Automation")
        
        # Stop monitoring
        self.dns_manager.stop_monitoring()
        
        # Stop DNS tunnel
        self.dns_tunnel.stop_tunnel()
        
        self.running = False
        self.logger.info("RBT DNS Automation shutdown completed")


async def main():
    """Main function"""
    parser = argparse.ArgumentParser(description='RBT DNS Automation System')
    parser.add_argument('--init', action='store_true', help='Initialize DNS system')
    parser.add_argument('--status', action='store_true', help='Show system status')
    parser.add_argument('--test-dns', action='store_true', help='Test DNS performance')
    parser.add_argument('--setup-tunnel', action='store_true', help='Setup DNS tunnel')
    parser.add_argument('--start-server', action='store_true', help='Start tunnel server')
    parser.add_argument('--start-client', action='store_true', help='Start tunnel client')
    parser.add_argument('--test-tunnel', action='store_true', help='Test tunnel connectivity')
    parser.add_argument('--stop-tunnel', action='store_true', help='Stop DNS tunnel')
    parser.add_argument('--preferred-countries', type=str, help='Preferred countries (comma-separated)')
    parser.add_argument('--domain', type=str, help='Domain for DNS tunnel')
    parser.add_argument('--server-ip', type=str, help='Server IP for DNS tunnel')
    parser.add_argument('--socks-port', type=int, default=9050, help='SOCKS proxy port')
    
    args = parser.parse_args()
    
    # Create automation system
    automation = RBTDNSAutomation()
    
    try:
        if args.init:
            preferred_countries = None
            if args.preferred_countries:
                preferred_countries = [c.strip() for c in args.preferred_countries.split(',')]
            
            success = await automation.initialize(preferred_countries)
            return 0 if success else 1
        
        if args.status:
            automation.print_status()
            return 0
        
        if args.test_dns:
            results = await automation.test_dns_performance()
            print("\nDNS Performance Test Results:")
            print(f"Total tested: {results['total_tested']}")
            print(f"Successful: {results['successful']}")
            print(f"Failed: {results['failed']}")
            
            if results.get('best_servers'):
                print("\nBest DNS Servers:")
                for i, server in enumerate(results['best_servers'][:5], 1):
                    print(f"{i}. {server['ip']} ({server['name']}) - {server['avg_latency']:.1f}ms - {server['status']}")
            return 0
        
        if args.setup_tunnel:
            if not args.domain or not args.server_ip:
                print("Error: --domain and --server-ip required for tunnel setup")
                return 1
            success = automation.setup_dns_tunnel(args.domain, args.server_ip)
            return 0 if success else 1
        
        if args.start_server:
            if not args.domain:
                print("Error: --domain required for server start")
                return 1
            success = automation.start_dns_tunnel_server(args.domain)
            return 0 if success else 1
        
        if args.start_client:
            success = automation.start_dns_tunnel_client(args.socks_port)
            return 0 if success else 1
        
        if args.test_tunnel:
            success = automation.test_dns_tunnel(args.socks_port)
            return 0 if success else 1
        
        if args.stop_tunnel:
            success = automation.stop_dns_tunnel()
            return 0 if success else 1
        
        # If no arguments, show help
        parser.print_help()
        return 0
        
    except KeyboardInterrupt:
        print("\nShutting down...")
        automation.shutdown()
        return 0
    except Exception as e:
        print(f"Error: {e}")
        return 1


if __name__ == '__main__':
    # Handle graceful shutdown
    def signal_handler(sig, frame):
        print('\nReceived shutdown signal, exiting...')
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Run main function
    exit_code = asyncio.run(main())
    sys.exit(exit_code)