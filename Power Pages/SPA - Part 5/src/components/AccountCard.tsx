import React from 'react';
import './AccountCard.css';

export interface Account {
  accountid: string;
  name: string;
  telephone1?: string;
  websiteurl?: string;
  address1_city?: string;
  description?: string;
}

interface AccountCardProps {
  account: Account;
}

export const AccountCard: React.FC<AccountCardProps> = ({ account }) => {
  const { name, accountid, telephone1, websiteurl, address1_city, description } = account;

  return (
    <div className="account-card" data-id={accountid}>
      <div className="account-card-header">
        <h3 className="account-name">{name}</h3>
        {address1_city && (
          <span className="account-location" title="City">{address1_city}</span>
        )}
      </div>
      <div className="account-card-body">
        {description && <p className="account-description">{description}</p>}
        <ul className="account-meta">
          {telephone1 && (
            <li>
              <span className="meta-label">Phone:</span>
              <a href={`tel:${telephone1}`}>{telephone1}</a>
            </li>
          )}
          {websiteurl && (
            <li>
              <span className="meta-label">Website:</span>
              <a href={websiteurl} target="_blank" rel="noopener noreferrer">{websiteurl}</a>
            </li>
          )}
          <li>
            <span className="meta-label">ID:</span>
            <code className="account-id">{accountid}</code>
          </li>
        </ul>
      </div>
    </div>
  );
};
