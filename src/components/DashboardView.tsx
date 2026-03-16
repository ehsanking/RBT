import React, { useState } from 'react';
import { RefreshCw } from 'lucide-react';
import { toast } from 'sonner';
import { useTunnels } from '../hooks/useTunnels.js';
import { useTraffic } from '../hooks/useTraffic.js';
import { StatsCard } from './StatsCard.js';
import { TrafficChart } from './TrafficChart.js';
import { TunnelTable } from './TunnelTable.js';
import { AddTunnelForm } from './AddTunnelForm.js';
import { LogsView } from './LogsView.js';

interface DashboardViewProps {
  auth: { token: string };
  onLogout: () => void;
}

export function DashboardView({ auth, onLogout }: DashboardViewProps) {
  const { data, loading, fetchData, addTunnel, removeTunnel } = useTunnels(auth, onLogout);
  const { trafficData } = useTraffic(auth, onLogout);
  const [isAdding, setIsAdding] = useState(false);

  const handleRemove = async (name: string) => {
    if (confirm(`Are you sure you want to remove tunnel "${name}"?`)) {
      try {
        await removeTunnel(name);
        toast.success(`Tunnel "${name}" removed successfully`);
      } catch (e) {
        toast.error(`Failed to remove tunnel: ${String(e)}`);
      }
    }
  };

  return (
    <div className="space-y-8 animate-in fade-in duration-500">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-white">Live Dashboard</h2>
        <button onClick={fetchData} className="p-2 hover:bg-white/10 rounded-full transition-colors">
          <RefreshCw className={`w-5 h-5 text-gray-400 ${loading ? 'animate-spin' : ''}`} />
        </button>
      </div>

      <div className="grid lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 space-y-6">
          <div className="grid md:grid-cols-2 gap-6">
            <StatsCard connected={data?.connected} loading={loading} />
            <TrafficChart data={trafficData} />
          </div>
          
          <div>
            {isAdding && (
              <AddTunnelForm 
                onAdd={addTunnel} 
                onCancel={() => setIsAdding(false)} 
              />
            )}
            <TunnelTable 
              links={data?.links || []} 
              onRemove={handleRemove} 
              onAddClick={() => setIsAdding(!isAdding)} 
            />
          </div>
        </div>
        
        <div className="bg-white/5 border border-white/10 rounded-lg p-6">
          <h3 className="font-bold text-white mb-4">Live Logs</h3>
          <LogsView />
        </div>
      </div>
    </div>
  );
}
