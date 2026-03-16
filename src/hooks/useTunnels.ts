import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

export function useTunnels(auth: { token: string } | null, onLogout: () => void) {
  const queryClient = useQueryClient();

  const getAuthHeader = () => {
    if (!auth) return {};
    return { 'Authorization': `Bearer ${auth.token}` };
  };

  const { data, isLoading: loading, refetch: fetchData } = useQuery({
    queryKey: ['tunnels'],
    queryFn: async () => {
      const res = await fetch('/api/status', { headers: getAuthHeader() });
      if (res.status === 401) {
        onLogout();
        throw new Error('Unauthorized');
      }
      if (!res.ok) throw new Error('Failed to fetch status');
      return res.json();
    },
    enabled: !!auth,
    refetchInterval: 10000, // Background refresh every 10s
  });

  const addTunnelMutation = useMutation({
    mutationFn: async (newTunnel: any) => {
      const res = await fetch('/api/tunnels', {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          ...getAuthHeader()
        },
        body: JSON.stringify(newTunnel)
      });
      if (!res.ok) throw new Error('Failed to add tunnel');
      return res.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tunnels'] });
    }
  });

  const removeTunnelMutation = useMutation({
    mutationFn: async (name: string) => {
      const res = await fetch(`/api/tunnels/${name}`, { 
        method: 'DELETE',
        headers: getAuthHeader()
      });
      if (!res.ok) throw new Error('Failed to remove tunnel');
      return res.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tunnels'] });
    }
  });

  return { 
    data, 
    loading, 
    fetchData, 
    addTunnel: addTunnelMutation.mutateAsync, 
    removeTunnel: removeTunnelMutation.mutateAsync 
  };
}
