import React from 'react';
import { safeFetch } from '../lib/webapi';

// Group interface based on expected response from /_api/groups
interface Group {
  id: string;
  displayName: string;
}

// Server Logic response structure
interface ServerLogicResponse {
  requestId: string;
  success: boolean;
  data: string; // JSON string that needs to be parsed
  serverLogicName: string;
}

// Parsed data structure from the data field
interface GroupsData {
  status: string;
  userEmail: string;
  groups: Group[];
}

const fetchGroups = async (): Promise<Group[]> => {
  const response = await safeFetch<ServerLogicResponse>({
    url: '/_api/serverlogics/groups'
  });

  if (!response.success) {
    throw new Error('Server logic request failed');
  }

  // Parse the JSON string in the data field
  const parsedData: GroupsData = JSON.parse(response.data);

  const groups: Group[] = parsedData.groups || [];
  return groups
    .filter((g: Group) => g.displayName)
    .sort((a, b) => a.displayName.localeCompare(b.displayName));
};

const Groups: React.FC = () => {
  const [groups, setGroups] = React.useState<Group[]>([]);
  const [loading, setLoading] = React.useState<boolean>(true);
  const [error, setError] = React.useState<string | null>(null);
  const [refetchTick, setRefetchTick] = React.useState<number>(0);

  React.useEffect(() => {
    let cancelled = false;
    const load = async () => {
      setLoading(true);
      setError(null);
      try {
        const data = await fetchGroups();
        if (!cancelled) {
          setGroups(data);
        }
      } catch (e: unknown) {
        if (!cancelled) {
          const message = e instanceof Error ? e.message : 'Failed to load groups';
          setError(message);
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    load();
    return () => { cancelled = true; };
  }, [refetchTick]);

  const onRefresh = () => setRefetchTick(t => t + 1);

  return (
    <div style={{ textAlign: 'left' }}>
      <h2>Groups</h2>
      <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center', flexWrap: 'wrap' }}>
        <button onClick={onRefresh} style={refreshButtonStyle} title="Refresh groups">Refresh</button>
        {loading && <span style={{ fontSize: '0.75rem', opacity: 0.8 }}>Loading...</span>}
        {!loading && !error && <span style={{ fontSize: '0.7rem', opacity: 0.7 }}>Showing {groups.length} group(s)</span>}
        {error && <span style={{ color: '#ff6b6b', fontSize: '0.75rem' }}>{error}</span>}
      </div>

      {!loading && groups.length === 0 && !error && (
        <p style={{ fontSize: '0.85rem', opacity: 0.8 }}>No groups found.</p>
      )}

      {error && !loading && (
        <div style={errorBoxStyle}>
          <strong>Error:</strong> {error}
        </div>
      )}

      <div style={groupsGridStyle}>
        {groups.map(group => (
          <div key={group.id} style={groupCardStyle}>
            <div style={groupNameStyle}>{group.displayName}</div>
            <div style={groupIdStyle}>ID: {group.id}</div>
          </div>
        ))}
      </div>
    </div>
  );
};

const refreshButtonStyle: React.CSSProperties = {
  background: 'linear-gradient(135deg,#646cff,#747bff)',
  color: '#fff',
  padding: '0.5rem 0.9rem',
  border: 'none',
  borderRadius: '6px',
  cursor: 'pointer',
  fontSize: '0.75rem',
  fontWeight: 500,
  letterSpacing: '0.5px',
  boxShadow: '0 2px 4px rgba(0,0,0,0.25)',
  transition: 'transform 0.2s ease, box-shadow 0.2s ease',
};

const errorBoxStyle: React.CSSProperties = {
  marginTop: '1rem',
  padding: '1rem',
  backgroundColor: '#fee',
  border: '1px solid #fcc',
  borderRadius: '6px',
  color: '#c33',
  fontSize: '0.85rem',
};

const groupsGridStyle: React.CSSProperties = {
  marginTop: '1.5rem',
  display: 'grid',
  gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
  gap: '1rem',
};

const groupCardStyle: React.CSSProperties = {
  padding: '1rem',
  backgroundColor: 'rgba(255, 255, 255, 0.05)',
  border: '1px solid rgba(255, 255, 255, 0.1)',
  borderRadius: '8px',
  transition: 'all 0.2s ease',
  cursor: 'default',
};

const groupNameStyle: React.CSSProperties = {
  fontSize: '1rem',
  fontWeight: 600,
  marginBottom: '0.5rem',
  color: '#646cff',
};

const groupIdStyle: React.CSSProperties = {
  fontSize: '0.75rem',
  opacity: 0.7,
  fontFamily: 'monospace',
};

export default Groups;
