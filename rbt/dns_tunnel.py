#!/usr/bin/env python3
"""
RBT DNS Tunneling Module - DNSTT Integration
Provides DNS tunneling capabilities for censorship resistance.
"""

import os
import json
import logging
import subprocess
import asyncio
import tempfile
import shutil
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from datetime import datetime
import socket
import threading
import time
import signal

class DNSTunnelManager:
    """Manages DNS tunneling using dnstt for censorship resistance"""
    
    def __init__(self):
        self.logger = self._setup_logger()
        self.config_dir = Path(__file__).parent / 'dns_tunnel_config'
        self.server_dir = self.config_dir / 'server'
        self.client_dir = self.config_dir / 'client'
        self.processes = {}
        self.tunnel_active = False
        self.config = {}
        
        # Create directories
        self.config_dir.mkdir(exist_ok=True)
        self.server_dir.mkdir(exist_ok=True)
        self.client_dir.mkdir(exist_ok=True)
        
    def _setup_logger(self) -> logging.Logger:
        """Setup logging configuration"""
        logger = logging.getLogger('dns_tunnel')
        logger.setLevel(logging.INFO)
        
        if not logger.handlers:
            handler = logging.StreamHandler()
            formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
            handler.setFormatter(formatter)
            logger.addHandler(handler)
            
        return logger
    
    def install_dnstt(self) -> bool:
        """Install dnstt from source"""
        try:
            self.logger.info("Installing dnstt...")
            
            # Check if Go is available
            if not self._check_go_installation():
                self.logger.error("Go is not installed. Please install Go first.")
                return False
            
            # Clone dnstt repository
            repo_url = "https://github.com/getlantern/dnstt"
            temp_dir = tempfile.mkdtemp()
            
            result = subprocess.run([
                'git', 'clone', '--depth', '1', repo_url, temp_dir
            ], capture_output=True, text=True)
            
            if result.returncode != 0:
                self.logger.error(f"Failed to clone dnstt: {result.stderr}")
                return False
            
            # Build server
            server_src = Path(temp_dir) / 'server'
            server_build_cmd = ['go', 'build', '-o', 'dnstt-server', '.']
            
            result = subprocess.run(
                server_build_cmd, 
                cwd=server_src,
                capture_output=True, 
                text=True
            )
            
            if result.returncode != 0:
                self.logger.error(f"Failed to build dnstt-server: {result.stderr}")
                return False
            
            # Build client
            client_src = Path(temp_dir) / 'client'
            client_build_cmd = ['go', 'build', '-o', 'dnstt-client', '.']
            
            result = subprocess.run(
                client_build_cmd,
                cwd=client_src,
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                self.logger.error(f"Failed to build dnstt-client: {result.stderr}")
                return False
            
            # Copy binaries to config directory
            server_bin = server_src / 'dnstt-server'
            client_bin = client_src / 'dnstt-client'
            
            shutil.copy2(server_bin, self.server_dir / 'dnstt-server')
            shutil.copy2(client_bin, self.client_dir / 'dnstt-client')
            
            # Make binaries executable
            os.chmod(self.server_dir / 'dnstt-server', 0o755)
            os.chmod(self.client_dir / 'dnstt-client', 0o755)
            
            # Copy source files for reference
            shutil.copytree(server_src, self.server_dir / 'src', dirs_exist_ok=True)
            shutil.copytree(client_src, self.client_dir / 'src', dirs_exist_ok=True)
            
            # Cleanup
            shutil.rmtree(temp_dir)
            
            self.logger.info("dnstt installed successfully")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to install dnstt: {e}")
            return False
    
    def _check_go_installation(self) -> bool:
        """Check if Go is installed and accessible"""
        try:
            result = subprocess.run(['go', 'version'], capture_output=True, text=True)
            return result.returncode == 0
        except FileNotFoundError:
            return False
    
    def generate_server_keys(self) -> Tuple[Optional[str], Optional[str]]:
        """Generate server keypair for dnstt"""
        try:
            self.logger.info("Generating dnstt server keys...")
            
            server_bin = self.server_dir / 'dnstt-server'
            if not server_bin.exists():
                self.logger.error("dnstt-server binary not found")
                return None, None
            
            privkey_file = self.server_dir / 'server.key'
            pubkey_file = self.server_dir / 'server.pub'
            
            # Generate keys
            cmd = [
                str(server_bin),
                '-gen-key',
                '-privkey-file', str(privkey_file),
                '-pubkey-file', str(pubkey_file)
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode != 0:
                self.logger.error(f"Key generation failed: {result.stderr}")
                return None, None
            
            # Read generated keys
            with open(privkey_file, 'r') as f:
                private_key = f.read().strip()
            
            with open(pubkey_file, 'r') as f:
                public_key = f.read().strip()
            
            self.logger.info("Server keys generated successfully")
            return private_key, public_key
            
        except Exception as e:
            self.logger.error(f"Key generation failed: {e}")
            return None, None
    
    def create_dns_zone_config(self, domain: str, server_ip: str) -> Dict:
        """Create DNS zone configuration for dnstt"""
        try:
            # Generate subdomain names
            tns_subdomain = f"tns.{domain}"  # Tunnel name server
            tunnel_subdomain = f"t.{domain}"  # Tunnel subdomain (short)
            
            config = {
                'domain': domain,
                'server_ip': server_ip,
                'tns_subdomain': tns_subdomain,
                'tunnel_subdomain': tunnel_subdomain,
                'dns_records': [
                    {
                        'type': 'A',
                        'name': tns_subdomain,
                        'value': server_ip,
                        'ttl': 300
                    },
                    {
                        'type': 'NS',
                        'name': tunnel_subdomain,
                        'value': tns_subdomain,
                        'ttl': 300
                    }
                ],
                'created_at': datetime.now().isoformat()
            }
            
            # Save configuration
            config_file = self.config_dir / 'dns_zone_config.json'
            with open(config_file, 'w') as f:
                json.dump(config, f, indent=2)
            
            self.logger.info(f"DNS zone configuration created for {domain}")
            return config
            
        except Exception as e:
            self.logger.error(f"Failed to create DNS zone config: {e}")
            return {}
    
    def start_server(self, domain: str, listen_port: int = 53) -> bool:
        """Start dnstt server"""
        try:
            self.logger.info(f"Starting dnstt server for {domain}")
            
            server_bin = self.server_dir / 'dnstt-server'
            privkey_file = self.server_dir / 'server.key'
            
            if not server_bin.exists():
                self.logger.error("dnstt-server binary not found")
                return False
            
            if not privkey_file.exists():
                self.logger.error("Server private key not found")
                return False
            
            # Create tunnel subdomain (short form)
            tunnel_domain = f"t.{domain}"
            
            # Build command
            cmd = [
                str(server_bin),
                '-udp', f':{listen_port}',
                '-privkey-file', str(privkey_file),
                tunnel_domain
            ]
            
            self.logger.info(f"Starting server with command: {' '.join(cmd)}")
            
            # Start server process
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            # Store process reference
            self.processes['server'] = process
            self.tunnel_active = True
            
            self.logger.info(f"dnstt server started on port {listen_port}")
            
            # Start monitoring thread
            monitor_thread = threading.Thread(target=self._monitor_server_process, args=(process,))
            monitor_thread.daemon = True
            monitor_thread.start()
            
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to start dnstt server: {e}")
            return False
    
    def _monitor_server_process(self, process: subprocess.Popen) -> None:
        """Monitor server process and handle output"""
        try:
            while self.tunnel_active and process.poll() is None:
                # Read stdout
                line = process.stdout.readline()
                if line:
                    self.logger.info(f"Server: {line.strip()}")
                
                # Read stderr
                error_line = process.stderr.readline()
                if error_line:
                    self.logger.error(f"Server Error: {error_line.strip()}")
                    
        except Exception as e:
            self.logger.error(f"Server monitoring error: {e}")
        finally:
            self.tunnel_active = False
            self.logger.info("Server process monitoring ended")
    
    def create_client_config(self, server_domain: str, public_key: str, 
                           local_socks_port: int = 9050) -> Dict:
        """Create client configuration for dnstt"""
        try:
            config = {
                'server_domain': server_domain,
                'public_key': public_key,
                'local_socks_port': local_socks_port,
                'tunnel_domain': f"t.{server_domain}",
                'dns_server': '1.1.1.1',  # Cloudflare DNS
                'timeout': 30,
                'mtu': 1500,
                'created_at': datetime.now().isoformat()
            }
            
            # Save client configuration
            client_config_file = self.client_dir / 'client_config.json'
            with open(client_config_file, 'w') as f:
                json.dump(config, f, indent=2)
            
            self.logger.info("Client configuration created")
            return config
            
        except Exception as e:
            self.logger.error(f"Failed to create client config: {e}")
            return {}
    
    def start_client(self, config_file: str = None) -> bool:
        """Start dnstt client"""
        try:
            if config_file is None:
                config_file = self.client_dir / 'client_config.json'
            
            if not Path(config_file).exists():
                self.logger.error("Client configuration file not found")
                return False
            
            # Load configuration
            with open(config_file, 'r') as f:
                config = json.load(f)
            
            self.logger.info(f"Starting dnstt client for {config['server_domain']}")
            
            client_bin = self.client_dir / 'dnstt-client'
            if not client_bin.exists():
                self.logger.error("dnstt-client binary not found")
                return False
            
            # Build command
            cmd = [
                str(client_bin),
                '-udp', f':{config.get("local_udp_port", 0)}',
                '-socks', f"127.0.0.1:{config['local_socks_port']}",
                config['public_key'],
                config['dns_server'],
                config['tunnel_domain']
            ]
            
            self.logger.info(f"Starting client with command: {' '.join(cmd)}")
            
            # Start client process
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            # Store process reference
            self.processes['client'] = process
            
            self.logger.info(f"dnstt client started, SOCKS proxy on port {config['local_socks_port']}")
            
            # Start monitoring thread
            monitor_thread = threading.Thread(target=self._monitor_client_process, args=(process,))
            monitor_thread.daemon = True
            monitor_thread.start()
            
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to start dnstt client: {e}")
            return False
    
    def _monitor_client_process(self, process: subprocess.Popen) -> None:
        """Monitor client process and handle output"""
        try:
            while process.poll() is None:
                # Read stdout
                line = process.stdout.readline()
                if line:
                    self.logger.info(f"Client: {line.strip()}")
                
                # Read stderr
                error_line = process.stderr.readline()
                if error_line:
                    self.logger.error(f"Client Error: {error_line.strip()}")
                    
        except Exception as e:
            self.logger.error(f"Client monitoring error: {e}")
        finally:
            self.logger.info("Client process monitoring ended")
    
    def test_tunnel_connectivity(self, socks_port: int = 9050) -> bool:
        """Test if the DNS tunnel is working"""
        try:
            self.logger.info("Testing DNS tunnel connectivity...")
            
            # Test SOCKS proxy
            import socks
            import socket
            
            # Configure SOCKS proxy
            socks.set_default_proxy(socks.SOCKS5, "127.0.0.1", socks_port)
            socket.socket = socks.socksocket
            
            # Test connection
            test_url = "http://www.google.com"
            import urllib.request
            
            response = urllib.request.urlopen(test_url, timeout=10)
            
            if response.status == 200:
                self.logger.info("DNS tunnel connectivity test successful")
                return True
            else:
                self.logger.error(f"Tunnel test failed with status: {response.status}")
                return False
                
        except Exception as e:
            self.logger.error(f"Tunnel connectivity test failed: {e}")
            return False
    
    def stop_tunnel(self) -> bool:
        """Stop DNS tunnel"""
        try:
            self.logger.info("Stopping DNS tunnel...")
            self.tunnel_active = False
            
            # Stop all processes
            for name, process in self.processes.items():
                if process and process.poll() is None:
                    self.logger.info(f"Terminating {name} process...")
                    process.terminate()
                    
                    # Wait for graceful shutdown
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        self.logger.warning(f"Force killing {name} process...")
                        process.kill()
                        process.wait()
            
            self.processes.clear()
            self.logger.info("DNS tunnel stopped")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to stop tunnel: {e}")
            return False
    
    def get_tunnel_status(self) -> Dict:
        """Get current tunnel status"""
        status = {
            'tunnel_active': self.tunnel_active,
            'processes': {},
            'config_loaded': False,
            'last_updated': datetime.now().isoformat()
        }
        
        # Check processes
        for name, process in self.processes.items():
            if process:
                status['processes'][name] = {
                    'pid': process.pid,
                    'running': process.poll() is None,
                    'returncode': process.returncode
                }
        
        # Check configuration
        config_file = self.config_dir / 'dns_zone_config.json'
        if config_file.exists():
            with open(config_file, 'r') as f:
                status['config'] = json.load(f)
                status['config_loaded'] = True
        
        return status
    
    def save_configuration(self, config: Dict) -> bool:
        """Save tunnel configuration"""
        try:
            config_file = self.config_dir / 'tunnel_config.json'
            with open(config_file, 'w') as f:
                json.dump(config, f, indent=2)
            
            self.config = config
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to save configuration: {e}")
            return False
    
    def load_configuration(self) -> Optional[Dict]:
        """Load tunnel configuration"""
        try:
            config_file = self.config_dir / 'tunnel_config.json'
            if config_file.exists():
                with open(config_file, 'r') as f:
                    self.config = json.load(f)
                return self.config
            return None
            
        except Exception as e:
            self.logger.error(f"Failed to load configuration: {e}")
            return None


class IranNetworkSimulator:
    """Simulates Iranian network conditions for testing"""
    
    def __init__(self):
        self.logger = logging.getLogger('iran_simulator')
        self.blocked_domains = [
            'youtube.com',
            'facebook.com',
            'twitter.com',
            'telegram.org',
            'instagram.com'
        ]
        self.dns_poisoning_patterns = [
            '10.10.34.34',
            '10.10.34.35',
            '127.0.0.1'
        ]
    
    def simulate_dns_poisoning(self, domain: str) -> bool:
        """Simulate DNS poisoning for blocked domains"""
        for blocked_domain in self.blocked_domains:
            if blocked_domain in domain.lower():
                return True
        return False
    
    def get_poisoned_response(self, domain: str) -> str:
        """Get a poisoned DNS response"""
        import random
        return random.choice(self.dns_poisoning_patterns)
    
    def test_dns_over_tls(self, dns_server: str = '1.1.1.1') -> bool:
        """Test DNS-over-TLS connectivity"""
        try:
            import ssl
            import socket
            
            # Test connection to DNS-over-TLS server
            context = ssl.create_default_context()
            with socket.create_connection((dns_server, 853), timeout=10) as sock:
                with context.wrap_socket(sock, server_hostname=dns_server) as ssock:
                    return True
                    
        except Exception as e:
            self.logger.error(f"DNS-over-TLS test failed: {e}")
            return False


async def main():
    """Main function for DNS tunneling"""
    import argparse
    
    parser = argparse.ArgumentParser(description='RBT DNS Tunnel Manager')
    parser.add_argument('--install', action='store_true', help='Install dnstt')
    parser.add_argument('--setup-server', action='store_true', help='Setup server configuration')
    parser.add_argument('--setup-client', action='store_true', help='Setup client configuration')
    parser.add_argument('--start-server', action='store_true', help='Start server')
    parser.add_argument('--start-client', action='store_true', help='Start client')
    parser.add_argument('--stop', action='store_true', help='Stop tunnel')
    parser.add_argument('--status', action='store_true', help='Show status')
    parser.add_argument('--test', action='store_true', help='Test tunnel connectivity')
    parser.add_argument('--domain', type=str, help='Domain name for tunnel')
    parser.add_argument('--server-ip', type=str, help='Server IP address')
    parser.add_argument('--socks-port', type=int, default=9050, help='SOCKS proxy port')
    
    args = parser.parse_args()
    
    # Create tunnel manager
    manager = DNSTunnelManager()
    
    try:
        if args.install:
            success = manager.install_dnstt()
            return 0 if success else 1
        
        if args.setup_server:
            if not args.domain or not args.server_ip:
                print("Error: --domain and --server-ip required for server setup")
                return 1
            
            config = manager.create_dns_zone_config(args.domain, args.server_ip)
            print(f"DNS zone configuration created for {args.domain}")
            print("Add these DNS records to your domain registrar:")
            for record in config.get('dns_records', []):
                print(f"  {record['type']} {record['name']} -> {record['value']} (TTL: {record['ttl']})")
            return 0
        
        if args.setup_client:
            if not args.domain:
                print("Error: --domain required for client setup")
                return 1
            
            # Generate server keys first
            privkey, pubkey = manager.generate_server_keys()
            if not pubkey:
                print("Error: Failed to generate server keys")
                return 1
            
            config = manager.create_client_config(args.domain, pubkey, args.socks_port)
            print(f"Client configuration created for {args.domain}")
            print(f"SOCKS proxy will be available on port {args.socks_port}")
            return 0
        
        if args.start_server:
            success = manager.start_server(args.domain if args.domain else "example.com")
            return 0 if success else 1
        
        if args.start_client:
            success = manager.start_client()
            return 0 if success else 1
        
        if args.test:
            success = manager.test_tunnel_connectivity(args.socks_port)
            return 0 if success else 1
        
        if args.stop:
            success = manager.stop_tunnel()
            return 0 if success else 1
        
        if args.status:
            status = manager.get_tunnel_status()
            print(json.dumps(status, indent=2))
            return 0
        
        # If no arguments, show help
        parser.print_help()
        return 0
        
    except KeyboardInterrupt:
        print("\nShutting down DNS tunnel...")
        manager.stop_tunnel()
        return 0
    except Exception as e:
        print(f"Error: {e}")
        return 1


if __name__ == '__main__':
    exit_code = asyncio.run(main())
    exit(exit_code)