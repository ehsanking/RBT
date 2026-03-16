import { useState, useEffect } from 'react';
import { io } from 'socket.io-client';

export function useTraffic(auth: { token: string } | null, onLogout: () => void) {
  const [trafficData, setTrafficData] = useState<any[]>([]);

  useEffect(() => {
    if (!auth) return;

    const socket = io();

    socket.on('connect', () => {
      console.log('Connected to traffic WebSocket');
    });

    socket.on('traffic', (json) => {
      setTrafficData(prev => {
        const newData = [...prev, {
          time: new Date(json.timestamp).toLocaleTimeString([], { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' }),
          rx: json.rx / 1024 / 1024,
          tx: json.tx / 1024 / 1024
        }];
        return newData.slice(-20);
      });
    });

    socket.on('connect_error', (err) => {
      console.error('WebSocket error:', err);
    });

    return () => {
      socket.disconnect();
    };
  }, [auth]);

  return { trafficData };
}
