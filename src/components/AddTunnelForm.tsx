import React, { useState } from 'react';
import { toast } from 'sonner';

interface AddTunnelFormProps {
  onAdd: (tunnel: any) => Promise<boolean>;
  onCancel: () => void;
}

export function AddTunnelForm({ onAdd, onCancel }: AddTunnelFormProps) {
  const [newTunnel, setNewTunnel] = useState({
    name: '',
    protocol: 'tcp',
    listen_host: '0.0.0.0:8080',
    target_host: '127.0.0.1:80',
    obfuscation: 'none'
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const success = await onAdd(newTunnel);
      if (success) {
        toast.success(`Tunnel "${newTunnel.name}" added successfully`);
        onCancel();
      } else {
        toast.error('Failed to add tunnel');
      }
    } catch (e) {
      toast.error(`Error adding tunnel: ${String(e)}`);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="p-4 bg-black/30 rounded-lg border border-white/5 space-y-4 mb-4">
      <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
        <div>
          <label className="block text-xs text-gray-400 mb-1">Name</label>
          <input required type="text" value={newTunnel.name} onChange={e => setNewTunnel({...newTunnel, name: e.target.value})} className="w-full bg-white/5 border border-white/10 rounded px-3 py-1.5 text-sm text-white focus:outline-none focus:border-emerald-500/50" placeholder="my-tunnel" />
        </div>
        <div>
          <label className="block text-xs text-gray-400 mb-1">Protocol</label>
          <select value={newTunnel.protocol} onChange={e => setNewTunnel({...newTunnel, protocol: e.target.value})} className="w-full bg-[#1a1a1a] border border-white/10 rounded px-3 py-1.5 text-sm text-white focus:outline-none focus:border-emerald-500/50">
            <option value="tcp">TCP</option>
            <option value="udp">UDP</option>
            <option value="quic_tcp">QUIC (TCP)</option>
            <option value="quic_udp">QUIC (UDP)</option>
          </select>
        </div>
        <div>
          <label className="block text-xs text-gray-400 mb-1">Listen Host</label>
          <input required type="text" value={newTunnel.listen_host} onChange={e => setNewTunnel({...newTunnel, listen_host: e.target.value})} className="w-full bg-white/5 border border-white/10 rounded px-3 py-1.5 text-sm text-white focus:outline-none focus:border-emerald-500/50" placeholder="0.0.0.0:8080" />
        </div>
        <div>
          <label className="block text-xs text-gray-400 mb-1">Target Host</label>
          <input required type="text" value={newTunnel.target_host} onChange={e => setNewTunnel({...newTunnel, target_host: e.target.value})} className="w-full bg-white/5 border border-white/10 rounded px-3 py-1.5 text-sm text-white focus:outline-none focus:border-emerald-500/50" placeholder="127.0.0.1:80" />
        </div>
        <div>
          <label className="block text-xs text-gray-400 mb-1">Obfuscation</label>
          <select value={newTunnel.obfuscation} onChange={e => setNewTunnel({...newTunnel, obfuscation: e.target.value})} className="w-full bg-[#1a1a1a] border border-white/10 rounded px-3 py-1.5 text-sm text-white focus:outline-none focus:border-emerald-500/50">
            <option value="none">None</option>
            <option value="chacha20">ChaCha20</option>
          </select>
        </div>
      </div>
      <div className="flex justify-end gap-2">
        <button type="button" onClick={onCancel} className="px-4 py-1.5 text-sm text-gray-400 hover:text-white transition-colors">Cancel</button>
        <button type="submit" className="px-4 py-1.5 bg-emerald-500 hover:bg-emerald-600 text-white text-sm font-medium rounded transition-colors">Save Tunnel</button>
      </div>
    </form>
  );
}
