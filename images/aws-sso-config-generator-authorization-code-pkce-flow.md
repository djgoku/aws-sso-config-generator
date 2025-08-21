# aws-sso-config-generator - AWS SSO Authorization Code Flow with PKCE (Default)

More information on how this is implemented https://github.com/aws/aws-cli/commit/130005af5ea6a75705ed528aaf06d533f449bef9

```mermaid
sequenceDiagram
    title aws-sso-config-generator - AWS SSO Authorization Code Flow with PKCE (Default) - Source: https://github.com/djgoku/aws-sso-config-generator
    participant User
    participant CLIApp as aws-sso-config-generator
    participant LocalServer as Local Bandit Server
    participant AWSSSO as AWS SSO OIDC Service

    User->>+CLIApp: Runs command (no --device-code)
    CLIApp->>+LocalServer: Starts local server
    Note over CLIApp,LocalServer: The redirect_uri must be http://127.0.0.1:RANDOM_PORT/oauth/callback

    CLIApp->>+AWSSSO: 1. Registers client
    Note right of CLIApp: Params:<br/>- clientName: "aws-sso-config-generator"<br/>- clientType: "public"<br/>- grantTypes: ["authorization_code"]<br/>- redirectUris: ["http://127.0.0.1:RANDOM_PORT/oauth/callback"]<br/>- scopes: ["sso:account:access"]
    AWSSSO-->>-CLIApp: Returns client_id & client_secret

    CLIApp->>+AWSSSO: 2. Starts authorization
    AWSSSO-->>-CLIApp: Returns full authorize_url (with PKCE challenge)
    Note right of CLIApp: Note: The URL's region must match the SSO region.<br/>Sample URL:<br/>https://oidc.us-east-1.amazonaws.com/authorize?<br/>response_type=code<br/>&client_id=a1b2c3d4<br/>&redirect_uri=http%3A%2F%2F127.0.0.1%3A12345%2Foauth%2Fcallback<br/>&scope=sso%3Aaccount%3Aaccess<br/>&state=xyz123<br/>&code_challenge=E9Mel...<br/>&code_challenge_method=S256

    User->>+AWSSSO: Logs in, grants consent via browser
    AWSSSO->>-User: Redirects browser to the registered redirect_uri with an authorization code
    Note right of AWSSSO: The redirect path must be /oauth/callback.<br/>If not, the API may return InvalidRedirectUriException with error:<br/>"Requested client type must use loopback interface for redirect"
    Note right of AWSSSO: Source: https://github.com/djgoku/aws-sso-config-generator

    User->>+LocalServer: Browser hits the local redirect URI
    LocalServer->>-CLIApp: Captures authorization_code and signals completion
    deactivate LocalServer

    CLIApp->>+AWSSSO: 3. Exchanges code for token
    Note right of CLIApp: Params:<br/>- grant_type: "authorization_code"<br/>- client_id<br/>- client_secret<br/>- code<br/>- redirect_uri<br/>- (PKCE) code_verifier
    AWSSSO-->>-CLIApp: Returns access_token

    CLIApp->>User: Login successful, proceeds to generate config
```
