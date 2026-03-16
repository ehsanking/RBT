# RBT Interactive Installation & Menu System

This document explains the new interactive installation and menu system for RBT (Tunnel Orchestration Platform).

## 🚀 Interactive Installation

The interactive installer will guide you through the RBT setup process, collecting all required configuration variables:

### Quick Start
```bash
# Make the installer executable
chmod +x install-interactive.sh

# Run the interactive installer
./install-interactive.sh
```

### What the Installer Collects

#### Required Variables:
- **Admin Username**: Default is 'admin', but you can choose any username (3+ characters)
- **Admin Password**: Must be at least 8 characters with uppercase, lowercase, numbers, and special characters
- **Dashboard Port**: Default is 3000, but you can choose any port between 1024-65535
- **JWT Secret**: Automatically generated 64-byte secure key (you can provide your own 32+ character secret)

#### Optional Variables:
- **hCaptcha Protection**: Enable/disable hCaptcha for login protection
  - Site Key: Your hCaptcha site key
  - Secret Key: Your hCaptcha secret key
- **Email Notifications**: Enable/disable SMTP for notifications
  - SMTP Host: Your SMTP server (e.g., smtp.gmail.com)
  - SMTP Port: Usually 587 for TLS
  - SMTP Username: Your email address
  - SMTP Password: Your email password or app password
  - Notification Email: Email address for receiving notifications

### Installation Process
1. **System Check**: Verifies Node.js is installed
2. **Dependency Installation**: Installs required npm packages
3. **Configuration Collection**: Interactive prompts for all settings
4. **File Generation**: Creates `.env` and `config.toml` files
5. **System Installation**: Runs the original RBT installation

## 📋 Interactive Menu System

The new interactive menu system provides a user-friendly numbered menu interface.

### Starting the Menu
```bash
# Using npm script
npm run rbt-menu

# Or directly with npx
npx tsx scripts/rbt-menu.ts

# Or if RBT is installed
rbt
```

### Menu Structure

#### Main Menu Options:
1. **🚀 Quick Start** - Initialize RBT and create your first tunnel
2. **🔧 Configuration** - Configure RBT settings and options
3. **🔗 Tunnel Management** - Add, remove, and manage tunnels
4. **📊 Monitoring & Analytics** - View traffic statistics and logs
5. **🔐 Security & Certificates** - Manage certificates and security settings
6. **⚙️ System Tools** - System utilities and maintenance
7. **📚 Documentation** - View help and documentation
8. **🔄 Update RBT** - Check for updates and upgrade RBT
9. **❓ Troubleshooting** - Diagnose and fix common issues
0. **🚪 Exit** - Exit the RBT menu

#### Configuration Submenu:
- **General Settings**: Port, bind address
- **hCaptcha Settings**: Enable/disable, site key, secret key
- **SMTP Settings**: Email notifications configuration
- **Security Settings**: Session timeout, login attempts
- **View Current Config**: Display current configuration

#### Tunnel Management Submenu:
- **Add New Tunnel**: Create a new tunnel with interactive prompts
- **List Tunnels**: Display all configured tunnels
- **Remove Tunnel**: Delete a tunnel by name
- **Tunnel Statistics**: View traffic and connection stats

#### Monitoring Submenu:
- **Real-time Traffic**: Live traffic monitoring
- **System Logs**: View and follow logs
- **Connection Statistics**: Connection metrics
- **Performance Metrics**: CPU, memory usage

#### Security Submenu:
- **Generate Certificate**: Create new TLS certificates
- **Security Audit**: Run security assessment
- **Update Security Settings**: Modify security parameters

#### System Tools Submenu:
- **System Information**: Platform, architecture, versions
- **Network Diagnostics**: Network connectivity tests
- **Service Management**: Start/stop/restart RBT service
- **Backup & Restore**: Configuration backup and restore

#### Documentation Submenu:
- **Getting Started**: Basic setup guide
- **Tunnel Configuration**: Advanced tunnel setup
- **Security Best Practices**: Security recommendations
- **Troubleshooting Guide**: Common issues and solutions
- **Advanced Features**: Power user features

#### Troubleshooting Submenu:
- **RBT Won't Start**: Startup issues
- **Tunnels Not Working**: Connection problems
- **Certificate Issues**: TLS/SSL problems
- **Performance Problems**: Performance optimization
- **Login Issues**: Authentication problems

## 🔧 Backend Integration

The interactive menu integrates with the RBT backend through:

### Command Execution
- Direct shell commands to `rbt` CLI
- API calls to the RBT server
- Configuration file manipulation

### Configuration Management
- Reads from `.env` and `config.toml` files
- Updates configuration through the ConfigService
- Validates settings before applying

### Security Features
- Password strength validation
- JWT secret generation
- Certificate management
- Security auditing

## 🛠️ Technical Details

### Requirements
- Node.js 16+ with TypeScript support
- RBT installed and configured
- Network access for updates and diagnostics

### File Structure
```
scripts/
├── interactive-installer.ts  # Interactive installation script
├── rbt-menu.ts               # Main interactive menu
└── setup-hcaptcha.ts         # hCaptcha configuration helper
```

### Error Handling
- Graceful fallbacks to built-in menu
- Comprehensive error messages
- Recovery suggestions
- Logging for debugging

## 🚀 Usage Examples

### Example 1: Quick Setup
```bash
# Run interactive installer
./install-interactive.sh

# Follow prompts to configure:
# - Admin credentials
# - Dashboard port
# - Optional hCaptcha and SMTP

# Start RBT menu
npm run rbt-menu

# Choose option 1 (Quick Start)
# Follow wizard to create first tunnel
```

### Example 2: Tunnel Management
```bash
# Start menu
npm run rbt-menu

# Choose option 3 (Tunnel Management)
# Choose option 1 (Add New Tunnel)

# Enter tunnel details:
# - Name: my-app-tunnel
# - Listen: 0.0.0.0:8080
# - Target: localhost:3000
# - Protocol: tcp
```

### Example 3: Security Configuration
```bash
# Start menu
npm run rbt-menu

# Choose option 2 (Configuration)
# Choose option 4 (Security Settings)

# Configure:
# - Session timeout: 24h
# - Max login attempts: 5
# - Certificate settings
```

## 📝 Notes

- The interactive installer creates secure defaults
- All passwords must meet complexity requirements
- Configuration files are automatically backed up
- The menu system provides contextual help
- Error messages include recovery suggestions

## 🔗 Related Documentation

- [RBT Main Documentation](README.md)
- [Installation Guide](INSTALL.md)
- [Configuration Reference](CONFIG.md)
- [Security Guide](SECURITY.md)