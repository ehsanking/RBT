import React, { useState } from 'react';
import { Download, FileCode2, Shield, Activity, Server, Terminal, CheckCircle2, Copy, Check } from 'lucide-react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { BrowserRouter, Routes, Route, Link, Navigate } from 'react-router-dom';
import { Toaster, toast } from 'sonner';
import { ThemeProvider } from './context/ThemeContext.js';
import { Navbar } from './components/Navbar.js';
import { Login } from './components/Login.js';
import { DashboardView } from './components/DashboardView.js';

const queryClient = new QueryClient();

export default function App() {
  const [auth, setAuth] = useState<{ token: string } | null>(() => {
    const saved = localStorage.getItem('rbt_auth');
    return saved ? JSON.parse(saved) : null;
  });

  const handleLogin = (token: string) => {
    const authData = { token };
    setAuth(authData);
    localStorage.setItem('rbt_auth', JSON.stringify(authData));
  };

  const handleLogout = () => {
    setAuth(null);
    localStorage.removeItem('rbt_auth');
  };

  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider>
        <BrowserRouter>
          <div className="min-h-screen bg-[#0a0a0a] text-gray-300 font-mono selection:bg-emerald-500/30 transition-colors">
            <Toaster position="top-right" theme="dark" richColors />
            <Navbar 
              isLoggedIn={!!auth} 
              onLogout={handleLogout} 
            />

            <main className="max-w-7xl mx-auto px-6 py-12">
              <Routes>
                <Route path="/" element={<OverviewView />} />
                <Route path="/architecture" element={<ArchitectureView />} />
                <Route path="/install" element={<InstallView />} />
                <Route 
                  path="/dashboard" 
                  element={auth ? <DashboardView auth={auth} onLogout={handleLogout} /> : <Login onLogin={handleLogin} />} 
                />
                <Route path="*" element={<Navigate to="/" replace />} />
              </Routes>
            </main>
          </div>
        </BrowserRouter>
      </ThemeProvider>
    </QueryClientProvider>
  );
}

function OverviewView() {
  return (
    <div className="space-y-12 animate-in fade-in duration-500">
      <header className="space-y-6 max-w-3xl">
        <h1 className="text-5xl font-bold text-white tracking-tight">
          Production-Grade <br/>
          <span className="text-transparent bg-clip-text bg-gradient-to-r from-emerald-400 to-cyan-400">
            Tunnel Orchestration
          </span>
        </h1>
        <p className="text-lg text-gray-400 leading-relaxed font-sans">
          RBT is a research-driven, engineering-focused server-to-server tunneling platform built around rstun. Designed for lawful infrastructure administration, controlled experimentation, and technical evaluation.
        </p>
        <div className="flex gap-4 pt-4">
          <Link to="/install" className="bg-emerald-500 hover:bg-emerald-400 text-black px-6 py-3 rounded font-medium flex items-center gap-2 transition-colors">
            <Download className="w-4 h-4" />
            Install RBT
          </Link>
          <Link to="/architecture" className="bg-white/5 hover:bg-white/10 border border-white/10 text-white px-6 py-3 rounded font-medium flex items-center gap-2 transition-colors">
            <FileCode2 className="w-4 h-4" />
            View Source
          </Link>
        </div>
      </header>

        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-6">
        <div className="p-6 rounded-xl bg-white/5 border border-white/10 space-y-4">
          <Shield className="w-6 h-6 text-emerald-400" />
          <h3 className="text-white font-medium text-lg">Anti-DPI Obfuscation</h3>
          <p className="text-sm text-gray-400 font-sans">AEAD-like traffic obfuscation masks packet headers, making tunnels invisible to Deep Packet Inspection (DPI) systems.</p>
        </div>
        <div className="p-6 rounded-xl bg-white/5 border border-white/10 space-y-4">
          <Activity className="w-6 h-6 text-cyan-400" />
          <h3 className="text-white font-medium text-lg">Dynamic Port Hopping</h3>
          <p className="text-sm text-gray-400 font-sans">Automatically evades port blocking by deterministically rotating listening ports using TOTP-based cryptographic synchronization.</p>
        </div>
        <div className="p-6 rounded-xl bg-white/5 border border-white/10 space-y-4">
          <Server className="w-6 h-6 text-blue-400" />
          <h3 className="text-white font-medium text-lg">QUIC UDP Datagrams</h3>
          <p className="text-sm text-gray-400 font-sans">Eliminates head-of-line blocking for UDP traffic (DNS, WireGuard) over high-loss networks using the Quinn QUIC implementation.</p>
        </div>
        <div className="p-6 rounded-xl bg-white/5 border border-white/10 space-y-4">
          <Terminal className="w-6 h-6 text-purple-400" />
          <h3 className="text-white font-medium text-lg">Zero-Copy TCP</h3>
          <p className="text-sm text-gray-400 font-sans">Linux kernel-level splice() integration and BBR congestion control for maximum throughput and minimum latency.</p>
        </div>
      </div>

      <div className="p-6 rounded-xl bg-red-500/10 border border-red-500/20 space-y-3">
        <h3 className="text-red-400 font-bold flex items-center gap-2">
          <Shield className="w-5 h-5" />
          Research & Responsible Use Disclaimer
        </h3>
        <p className="text-sm text-red-200/80 font-sans leading-relaxed">
          This project is intended strictly for lawful research, authorized infrastructure administration, and controlled testing. It must not be used to conceal malicious activity, evade monitoring, or bypass access controls. The author (EHSANKiNG) explicitly rejects misuse for covert operations or DPI evasion.
        </p>
      </div>
    </div>
  );
}

function ArchitectureView() {
  return (
    <div className="space-y-8 animate-in fade-in duration-500">
      <h2 className="text-2xl font-bold text-white">Workspace Architecture</h2>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        <div className="space-y-4">
          <div className="p-4 rounded bg-black border border-white/10 font-mono text-sm text-gray-400">
            <div className="text-emerald-400 mb-2">RBT/</div>
            <div className="pl-4 border-l border-white/10 ml-2 space-y-1">
              <div>├── Cargo.toml</div>
              <div>├── crates/</div>
              <div className="pl-4 border-l border-white/10 ml-2 space-y-1 text-gray-500">
                <div className="text-gray-300">├── rbt-cli/ <span className="text-gray-600">// Frontend & UX</span></div>
                <div className="text-gray-300">├── rbt-config/ <span className="text-gray-600">// TOML State</span></div>
                <div className="text-gray-300">├── rbt-runtime/ <span className="text-gray-600">// Tokio Supervisor</span></div>
                <div className="text-gray-300">├── rbt-observability/ <span className="text-gray-600">// Telemetry</span></div>
                <div className="text-gray-300">├── rbt-cert/ <span className="text-gray-600">// ACME TLS</span></div>
                <div className="text-gray-300">└── rbt-service/ <span className="text-gray-600">// Systemd</span></div>
              </div>
              <div>└── install.sh</div>
            </div>
          </div>
        </div>
        <div className="space-y-6 font-sans">
          <p className="text-gray-400">
            The Rust source code has been generated and written to the container's file system. You can export the project as a ZIP file using the AI Studio interface to compile it locally.
          </p>
          <ul className="space-y-3">
            <li className="flex items-start gap-3 text-sm text-gray-300">
              <CheckCircle2 className="w-5 h-5 text-emerald-500 shrink-0" />
              <span><strong>rbt-cli</strong>: Handles clap-based argument parsing and terminal UX.</span>
            </li>
            <li className="flex items-start gap-3 text-sm text-gray-300">
              <CheckCircle2 className="w-5 h-5 text-emerald-500 shrink-0" />
              <span><strong>rbt-runtime</strong>: Asynchronous execution engine built on tokio. Manages subprocesses and exponential backoff.</span>
            </li>
            <li className="flex items-start gap-3 text-sm text-gray-300">
              <CheckCircle2 className="w-5 h-5 text-emerald-500 shrink-0" />
              <span><strong>rbt-config</strong>: Declarative state management with strict schema validation.</span>
            </li>
          </ul>
        </div>
      </div>
    </div>
  );
}

function InstallView() {
  const installCmd = "curl -fsSL https://raw.githubusercontent.com/EHSANKiNG/RBT/main/install.sh | bash";
  const [copied, setCopied] = useState(false);

  const copyToClipboard = () => {
    navigator.clipboard.writeText(installCmd);
    setCopied(true);
    toast.success("Command copied to clipboard!");
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="space-y-8 animate-in fade-in duration-500 max-w-3xl">
      <h2 className="text-2xl font-bold text-white">Installation</h2>
      <p className="text-gray-400 font-sans">
        Run the following command to install the RBT orchestrator on your Linux server.
      </p>
      <div className="relative group">
        <div className="absolute inset-0 bg-emerald-500/20 blur-xl rounded-lg opacity-0 group-hover:opacity-100 transition-opacity"></div>
        <div className="relative bg-black border border-white/10 rounded-lg p-4 flex items-center justify-between">
          <code className="text-emerald-400 text-sm break-all">{installCmd}</code>
          <button 
            onClick={copyToClipboard}
            className="p-2 ml-4 text-gray-400 hover:text-white transition-colors"
            title="Copy to clipboard"
          >
            {copied ? <Check className="w-5 h-5 text-emerald-400" /> : <Copy className="w-5 h-5" />}
          </button>
        </div>
      </div>

      <div className="space-y-4 pt-8">
        <h3 className="text-lg font-medium text-white">Quick Start (v0.0.2)</h3>
        <div className="bg-black border border-white/10 rounded-lg p-4 font-mono text-sm text-gray-400 space-y-2">
          <div className="text-gray-500"># 1. Add a TCP tunnel with Obfuscation & Port Hopping</div>
          <div><span className="text-emerald-400">rbt</span> link-add --name secure-tunnel --listen 0.0.0.0:10000 --target 127.0.0.1:22 --proto tcp</div>
          <div className="text-gray-500 mt-2"># (Edit /etc/rbt/config.toml to add 'obfuscation = "aead"' and 'port_hopping = "10000-20000"')</div>
          <br/>
          <div className="text-gray-500"># 2. Add a QUIC UDP tunnel for high-loss networks</div>
          <div><span className="text-emerald-400">rbt</span> link-add --name wg-tunnel --listen 0.0.0.0:51820 --target 127.0.0.1:51820 --proto udp</div>
          <br/>
          <div className="text-gray-500"># 3. Apply configuration and start supervisor</div>
          <div><span className="text-emerald-400">rbt</span> apply</div>
        </div>
      </div>
    </div>
  );
}
