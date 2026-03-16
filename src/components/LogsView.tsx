import React from 'react';
import { useLogs } from '../hooks/useLogs.js';

export function LogsView() {
  const { logs } = useLogs();

  return (
    <div className="bg-black border border-white/10 rounded-lg p-4 h-96 overflow-y-auto font-mono text-xs text-gray-400">
      {logs.map((log, i) => (
        <div key={i} className="whitespace-pre-wrap">{log}</div>
      ))}
    </div>
  );
}
