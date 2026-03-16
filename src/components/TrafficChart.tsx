import React from 'react';
import { Activity } from 'lucide-react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

interface TrafficChartProps {
  data: any[];
}

export function TrafficChart({ data }: TrafficChartProps) {
  return (
    <div className="p-6 rounded-xl bg-white/5 border border-white/10 space-y-4 col-span-1 md:col-span-3 lg:col-span-2">
      <h3 className="text-white font-medium text-lg flex items-center gap-2">
        <Activity className="w-5 h-5 text-cyan-400" />
        Live Traffic (MB/s)
      </h3>
      <div className="h-48 w-full">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={data} margin={{ top: 5, right: 0, left: -20, bottom: 0 }}>
            <defs>
              <linearGradient id="colorRx" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#10b981" stopOpacity={0.3}/>
                <stop offset="95%" stopColor="#10b981" stopOpacity={0}/>
              </linearGradient>
              <linearGradient id="colorTx" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3}/>
                <stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/>
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#ffffff10" vertical={false} />
            <XAxis dataKey="time" stroke="#ffffff50" fontSize={10} tickMargin={10} />
            <YAxis stroke="#ffffff50" fontSize={10} tickFormatter={(val) => val.toFixed(1)} />
            <Tooltip 
              contentStyle={{ backgroundColor: '#1a1a1a', borderColor: '#333', color: '#fff' }}
              itemStyle={{ color: '#fff' }}
              labelStyle={{ color: '#aaa' }}
            />
            <Area type="monotone" dataKey="rx" name="Download" stroke="#10b981" fillOpacity={1} fill="url(#colorRx)" />
            <Area type="monotone" dataKey="tx" name="Upload" stroke="#3b82f6" fillOpacity={1} fill="url(#colorTx)" />
          </AreaChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
