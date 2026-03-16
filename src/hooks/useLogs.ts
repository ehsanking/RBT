import React, { useState, useEffect } from 'react';
import { io } from 'socket.io-client';

export function useLogs() {
  const [logs, setLogs] = useState<string[]>([]);

  useEffect(() => {
    const socket = io();

    socket.on('log', (log: string) => {
      setLogs(prev => [...prev.slice(-99), log]);
    });

    return () => {
      socket.disconnect();
    };
  }, []);

  return { logs };
}
