import React from 'react';
import { Shield, Trash2, Server, Plus } from 'lucide-react';

interface TunnelTableProps {
  links: any[];
  onRemove: (name: string) => void;
  onAddClick: () => void;
}

export function TunnelTable({ links, onRemove, onAddClick }: TunnelTableProps) {
  return (
    <div className="p-6 rounded-xl bg-white/5 border border-white/10 space-y-4 col-span-1 md:col-span-3">
      <div className="flex items-center justify-between">
        <h3 className="text-white font-medium text-lg flex items-center gap-2">
          <Server className="w-5 h-5 text-emerald-400" />
          Active Tunnels ({links?.length || 0})
        </h3>
        <button 
          onClick={onAddClick}
          className="flex items-center gap-2 px-3 py-1.5 bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-400 rounded-lg transition-colors text-sm font-medium"
        >
          <Plus className="w-4 h-4" />
          Add Tunnel
        </button>
      </div>
      
      <div className="overflow-x-auto">
        <table className="w-full text-left text-sm">
          <thead>
            <tr className="text-gray-500 border-b border-white/10">
              <th className="pb-3 font-medium">Name</th>
              <th className="pb-3 font-medium">Protocol</th>
              <th className="pb-3 font-medium">Listen</th>
              <th className="pb-3 font-medium">Target</th>
              <th className="pb-3 font-medium">Obfuscation</th>
              <th className="pb-3 font-medium text-right">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-white/5">
            {links?.length === 0 && (
              <tr>
                <td colSpan={6} className="py-4 text-center text-gray-500">No tunnels configured.</td>
              </tr>
            )}
            {links?.map((link, i) => (
              <tr key={i} className="text-gray-300">
                <td className="py-3 font-medium text-white">{link.name}</td>
                <td className="py-3">
                  <span className="px-2 py-1 bg-white/5 rounded text-xs uppercase tracking-wider border border-white/10">
                    {link.protocol}
                  </span>
                </td>
                <td className="py-3 font-mono text-xs text-gray-400">{link.listen_host}</td>
                <td className="py-3 font-mono text-xs text-gray-400">{link.target_host}</td>
                <td className="py-3 text-xs">
                  {link.obfuscation ? (
                    <span className="text-emerald-400 flex items-center gap-1"><Shield className="w-3 h-3"/> {link.obfuscation}</span>
                  ) : (
                    <span className="text-gray-500">None</span>
                  )}
                </td>
                <td className="py-3 text-right">
                  <button 
                    onClick={() => onRemove(link.name)}
                    className="p-1.5 text-gray-500 hover:text-red-400 hover:bg-red-400/10 rounded transition-colors"
                    title="Remove Tunnel"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
