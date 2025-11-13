import React from 'react';
import type { Account } from '../components/AccountCard';
import { AccountCard } from '../components/AccountCard';
import '../components/AccountCard.css';
import { safeFetch } from '../lib/webapi';

// Fetch accounts from Dataverse
// Assumptions: Endpoint exposes OData at /_api/accounts and supports $select and paging.
// Adjust field names or add $filter, $orderby as needed.
interface RawAccount {
  accountid: string;
  name: string;
  telephone1?: string;
  websiteurl?: string;
  address1_city?: string;
  description?: string;
  [key: string]: unknown;
}

const fetchAccounts = async (): Promise<Account[]> => {
  const data = await safeFetch<{ value?: RawAccount[] }>({
    url: '/_api/accounts?$select=name,accountid,telephone1,websiteurl,address1_city,description&$top=50'
  });
  const accountsRaw: RawAccount[] = (data.value || []) as RawAccount[];
  const mapped: Account[] = accountsRaw
    .map((a: RawAccount): Account => ({
      accountid: a.accountid,
      name: a.name,
      telephone1: a.telephone1,
      websiteurl: a.websiteurl,
      address1_city: a.address1_city,
      description: a.description,
    }))
    .filter((a: Account) => a.name)
    .sort((a, b) => a.name.localeCompare(b.name));
  return mapped;
};

const Accounts: React.FC = () => {
  const [accounts, setAccounts] = React.useState<Account[]>([]);
  const [loading, setLoading] = React.useState<boolean>(true);
  const [error, setError] = React.useState<string | null>(null);
  const [refetchTick, setRefetchTick] = React.useState<number>(0);

  React.useEffect(() => {
    let cancelled = false;
    const load = async () => {
      setLoading(true);
      setError(null);
      try {
        const data = await fetchAccounts();
        if (!cancelled) {
          setAccounts(data);
        }
      } catch (e: unknown) {
        if (!cancelled) {
          const message = e instanceof Error ? e.message : 'Failed to load accounts';
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
      <h2>Accounts</h2>
      <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center', flexWrap: 'wrap' }}>
        <button onClick={onRefresh} style={refreshButtonStyle} title="Refresh accounts">Refresh</button>
        {loading && <span style={{ fontSize: '0.75rem', opacity: 0.8 }}>Loading...</span>}
        {!loading && !error && <span style={{ fontSize: '0.7rem', opacity: 0.7 }}>Showing {accounts.length} account(s)</span>}
        {error && <span style={{ color: '#ff6b6b', fontSize: '0.75rem' }}>{error}</span>}
      </div>

      {!loading && accounts.length === 0 && !error && (
        <p style={{ fontSize: '0.85rem', opacity: 0.8 }}>No accounts found.</p>
      )}

      <div className="accounts-grid">
        {accounts.map(acc => <AccountCard key={acc.accountid} account={acc} />)}
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

export default Accounts;
