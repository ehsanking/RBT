import React, { useState, useRef } from 'react';
import { Shield } from 'lucide-react';
import HCaptcha from '@hcaptcha/react-hcaptcha';
import { toast } from 'sonner';

interface LoginProps {
  onLogin: (token: string) => void;
}

export function Login({ onLogin }: LoginProps) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [hcaptchaToken, setHcaptchaToken] = useState<string | null>(null);
  const [error, setError] = useState('');
  const captchaRef = useRef<HCaptcha>(null);

  const ENABLE_HCAPTCHA = import.meta.env.VITE_ENABLE_HCAPTCHA === 'true';

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (ENABLE_HCAPTCHA && !hcaptchaToken) {
      toast.error('Please complete the captcha');
      setError('Please complete the captcha');
      return;
    }

    try {
      const res = await fetch('/api/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password, hcaptchaToken })
      });
      const data = await res.json();
      if (res.ok) {
        toast.success('Authenticated successfully');
        onLogin(data.token);
      } else {
        toast.error(data.error || 'Invalid credentials');
        setError(data.error || 'Invalid credentials');
        setHcaptchaToken(null);
        captchaRef.current?.resetCaptcha();
      }
    } catch (e) {
      toast.error('Connection error');
      setError('Connection error');
    }
  };

  const siteKey = import.meta.env.VITE_HCAPTCHA_SITE_KEY || '10000000-ffff-ffff-ffff-000000000001';

  return (
    <div className="flex items-center justify-center min-h-[60vh] animate-in zoom-in duration-300">
      <form onSubmit={handleSubmit} className="bg-white/5 border border-white/10 p-8 rounded-xl w-full max-w-md space-y-6 shadow-2xl">
        <div className="text-center space-y-2">
          <div className="w-16 h-16 bg-emerald-500/10 border border-emerald-500/20 rounded-full flex items-center justify-center mx-auto mb-4">
            <Shield className="w-8 h-8 text-emerald-400" />
          </div>
          <h2 className="text-2xl font-bold text-white">Dashboard Login</h2>
          <p className="text-sm text-gray-500">Secure access to RBT Orchestrator</p>
        </div>
        
        {error && <div className="p-3 bg-red-500/10 border border-red-500/20 text-red-400 text-sm rounded text-center">{error}</div>}
        
        <div className="space-y-4">
          <div>
            <label className="block text-xs text-gray-400 mb-1 uppercase tracking-wider font-bold">Username</label>
            <input 
              type="text" 
              value={username} 
              onChange={e => setUsername(e.target.value)}
              className="w-full bg-black/50 border border-white/10 rounded px-4 py-2.5 text-white focus:outline-none focus:border-emerald-500/50 transition-colors"
              placeholder="admin"
              required
            />
          </div>
          <div>
            <label className="block text-xs text-gray-400 mb-1 uppercase tracking-wider font-bold">Password</label>
            <input 
              type="password" 
              value={password} 
              onChange={e => setPassword(e.target.value)}
              className="w-full bg-black/50 border border-white/10 rounded px-4 py-2.5 text-white focus:outline-none focus:border-emerald-500/50 transition-colors"
              placeholder="••••••••"
              required
            />
          </div>
        </div>

        {ENABLE_HCAPTCHA && (
          <div className="flex justify-center py-2">
            <HCaptcha
              sitekey={siteKey}
              onVerify={(token) => setHcaptchaToken(token)}
              onExpire={() => setHcaptchaToken(null)}
              theme="dark"
              ref={captchaRef}
            />
          </div>
        )}
        
        <button type="submit" className="w-full bg-emerald-500 hover:bg-emerald-600 text-black font-bold py-3 rounded transition-all active:scale-[0.98] shadow-lg shadow-emerald-500/20">
          Authenticate
        </button>
      </form>
    </div>
  );
}
