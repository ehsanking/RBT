import React from 'react';
import { Wifi, WifiOff } from 'lucide-react';

interface StatsCardProps {
  connected: boolean | undefined;
  loading: boolean;
}

export function StatsCard({ connected, loading }: StatsCardProps) {
  return (
    <div className="p-6 rounded-xl bg-white/5 border border-white/10 space-y-4 col-span-1 md:col-span-3 lg:col-span-1">
      <div className="flex items-center justify-between">
        <h3 className="text-white font-medium text-lg">Network Status</h3>
        {connected ? (
          <Wifi className="w-6 h-6 text-emerald-400" />
        ) : (
          <WifiOff className="w-6 h-6 text-red-400" />
        )}
      </div>
      
      {loading && !connected ? (
        <div className="text-sm text-gray-400 animate-pulse">Checking connectivity...</div>
      ) : connected ? (
        <div>
          <div className="text-2xl font-bold text-emerald-400">Connected</div>
          <p className="text-sm text-gray-400 mt-1">International internet is reachable.</p>
        </div>
      ) : (
        <div>
          <div className="text-2xl font-bold text-red-400">Intranet Mode</div>
          <p className="text-sm text-red-300/80 mt-2 leading-relaxed">
            International connection is unavailable. Suggestion: Activate a tunnel using 'dnstt' and 'spilnet' with open DNS servers.
          </p>
        </div>
      )}
    </div>
  );
}
