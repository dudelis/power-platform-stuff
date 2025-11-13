import React from 'react';
import './Profile.css';

interface ShellAjaxPromise<T> {
  done: (cb: (response: T) => void) => ShellAjaxPromise<T>;
  fail: (cb: (xhr: unknown, status: string, error: string) => void) => ShellAjaxPromise<T>;
  always: (cb: () => void) => ShellAjaxPromise<T>;
}

interface Shell {
  ajaxSafePost: <T = unknown>(settings: {
    type?: string;
    url: string;
    data?: unknown;
    contentType?: string;
  }) => ShellAjaxPromise<T>;
}

interface ContactData {
  firstname?: string;
  lastname?: string;
  fullname?: string;
  emailaddress1?: string;
  contactid?: string;
  'account.name'?: string;
  'account.address1_line1'?: string;
  'account.address1_city'?: string;
  'account.address1_stateorprovince'?: string;
  'account.address1_postalcode'?: string;
  'account.address1_country'?: string;
}

interface FlowResponse {
  output?: string;
  body?: string;
  [key: string]: unknown;
}

const FLOW_TRIGGER_URL = "/_api/cloudflow/v1.0/trigger/5479072c-77c0-f011-8542-000d3a553118";

const Profile: React.FC = () => {
  const [loading, setLoading] = React.useState<boolean>(false);
  const [error, setError] = React.useState<string | null>(null);
  const [contactData, setContactData] = React.useState<ContactData | null>(null);
  const [rawResponse, setRawResponse] = React.useState<string>('');

  const loadProfile = async () => {
    setLoading(true);
    setError(null);
    setContactData(null);
    setRawResponse('');

    try {
      // Check if shell.ajaxSafePost is available
      const shell = (window as { shell?: Shell }).shell;
      if (!shell || typeof shell.ajaxSafePost !== 'function') {
        throw new Error('shell.ajaxSafePost is not available');
      }

      // Call flow using shell.ajaxSafePost
      // Note: Must NOT set contentType - let jQuery handle it as form-urlencoded
      const response = await new Promise<FlowResponse>((resolve, reject) => {
        shell.ajaxSafePost<FlowResponse>({
          type: "POST",
          url: FLOW_TRIGGER_URL,
          data: { eventData: JSON.stringify({}) }
        })
          .done((res) => {
            resolve(res);
          })
          .fail((_xhr, status, error) => {
            reject(new Error(`Flow request failed: ${status} - ${error}`));
          });
      });

      console.log("Flow response:", response);
      console.log("Response type:", typeof response);
      console.log("Response.output type:", typeof response.output);

      // Parse the JSON structure
      let parsedData: ContactData | null = null;

      // Handle case where entire response might be a JSON string
      let actualResponse: FlowResponse = response;
      if (typeof response === 'string') {
        try {
          actualResponse = JSON.parse(response) as FlowResponse;
          console.log("Parsed string response to object:", actualResponse);
        } catch (e) {
          console.warn("Could not parse string response", e);
        }
      }

      if (actualResponse.output) {
        try {
          // Parse: response.output is a JSON string
          const parsed = JSON.parse(actualResponse.output);
          parsedData = parsed as ContactData;
          console.log("Parsed contact data:", parsedData);
        } catch (e) {
          console.warn("Could not parse output field", e);
          console.error("Parse error:", e);
        }
      } else if (actualResponse.body) {
        try {
          parsedData = JSON.parse(actualResponse.body) as ContactData;
        } catch (e) {
          console.warn("Could not parse body field", e);
        }
      }

      if (parsedData) {
        setContactData(parsedData);
        console.log("Contact data set successfully", parsedData);
      } else {
        console.warn("No parsed data available, using raw response");
        setContactData(actualResponse as unknown as ContactData);
      }

      setRawResponse(JSON.stringify(actualResponse, null, 2));
    } catch (e: unknown) {
      const message = e instanceof Error ? e.message : 'Failed to load profile';
      setError(message);
      console.error("Profile load error:", e);
    } finally {
      setLoading(false);
    }
  };

  React.useEffect(() => {
    loadProfile();
  }, []);

  return (
    <div className="profile-page">
      <h2>Profile</h2>

      <div className="profile-actions">
        <button
          onClick={loadProfile}
          disabled={loading}
          className="refresh-button"
        >
          {loading ? 'Loading...' : 'Refresh Profile'}
        </button>
      </div>

      {error && (
        <div className="profile-error">
          <strong>Error:</strong> {error}
        </div>
      )}

      {loading && !contactData && (
        <div className="profile-loading">Loading your profile data...</div>
      )}

      {contactData && (
        <div className="profile-content">
          <section className="profile-section contact-info">
            <h3>Contact Information</h3>
            <div className="info-grid">
              {contactData.fullname && (
                <div className="info-item">
                  <label>Full Name</label>
                  <span>{contactData.fullname}</span>
                </div>
              )}
              {contactData.firstname && (
                <div className="info-item">
                  <label>First Name</label>
                  <span>{contactData.firstname}</span>
                </div>
              )}
              {contactData.lastname && (
                <div className="info-item">
                  <label>Last Name</label>
                  <span>{contactData.lastname}</span>
                </div>
              )}
              {contactData.emailaddress1 && (
                <div className="info-item">
                  <label>Email</label>
                  <a href={`mailto:${contactData.emailaddress1}`}>{contactData.emailaddress1}</a>
                </div>
              )}
              {contactData.contactid && (
                <div className="info-item">
                  <label>Contact ID</label>
                  <code>{contactData.contactid}</code>
                </div>
              )}
            </div>
          </section>

          {contactData['account.name'] && (
            <section className="profile-section account-info">
              <h3>Account Information</h3>
              <div className="info-grid">
                <div className="info-item">
                  <label>Company</label>
                  <span>{contactData['account.name']}</span>
                </div>
                {contactData['account.address1_line1'] && (
                  <div className="info-item full-width">
                    <label>Address</label>
                    <span>
                      {contactData['account.address1_line1']}
                      {contactData['account.address1_city'] && `, ${contactData['account.address1_city']}`}
                      {contactData['account.address1_stateorprovince'] && `, ${contactData['account.address1_stateorprovince']}`}
                      {contactData['account.address1_postalcode'] && ` ${contactData['account.address1_postalcode']}`}
                      {contactData['account.address1_country'] && (
                        <><br />{contactData['account.address1_country']}</>
                      )}
                    </span>
                  </div>
                )}
              </div>
            </section>
          )}

          <details className="raw-response">
            <summary>View Raw Response</summary>
            <pre>{rawResponse}</pre>
          </details>
        </div>
      )}
    </div>
  );
};

export default Profile;
