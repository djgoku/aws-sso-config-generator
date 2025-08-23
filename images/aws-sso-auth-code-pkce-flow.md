# AWS CLI - AWS SSO Authorization Code Flow with PKCE (Default)

More information on how this is implemented https://github.com/aws/aws-cli/commit/130005af5ea6a75705ed528aaf06d533f449bef9

```mermaid
sequenceDiagram
    title AWS CLI - AWS SSO Authorization Code Flow with PKCE (Default) - Source: https://github.com/djgoku/aws-sso-config-generator
    participant User
    participant CLIApplication as CLI Application
    participant LocalWebServer as Local Web Server
    participant AWSSSO as AWS SSO OIDC Service

    User->>+CLIApplication: Initiates login
    CLIApplication->>+LocalWebServer: Starts local server
    Note over CLIApplication,LocalWebServer: The redirect_uri must be http://127.0.0.1:RANDOM_PORT/oauth/callback

    CLIApplication->>+AWSSSO: 1. Calls RegisterClient API
    Note right of CLIApplication: Params:<br/>- clientName: "my-cli-app"<br/>- clientType: "public"<br/>- grantTypes: ["authorization_code"]<br/>- redirectUris: ["http://127.0.0.1:RANDOM_PORT/oauth/callback"]<br/>- scopes: ["sso:account:access"]
    AWSSSO-->>-CLIApplication: Returns clientId & clientSecret

    CLIApplication->>User: Opens AWS SSO authorization URL in browser
    Note right of CLIApplication: Note: The URL's region must match the SSO region.<br/>Sample URL:<br/>https://oidc.us-east-1.amazonaws.com/authorize?<br/>response_type=code<br/>&client_id=a1b2c3d4<br/>&redirect_uri=http%3A%2F%2F127.0.0.1%3A12345%2Foauth%2Fcallback<br/>&scope=sso%3Aaccount%3Aaccess<br/>&state=xyz123<br/>&code_challenge=E9Mel...<br/>&code_challenge_method=S256

    User->>+AWSSSO: Authenticates via browser
    AWSSSO-->>-User: Redirects browser to the registered redirect_uri with an authorization code
    Note right of AWSSSO: The redirect path must be /oauth/callback.<br/>If not, the API may return InvalidRedirectUriException with error:<br/>"Requested client type must use loopback interface for redirect"
    Note right of AWSSSO: Source: https://github.com/djgoku/aws-sso-config-generator

    User->>+LocalWebServer: Browser is redirected to the local server
    LocalWebServer-->>-CLIApplication: Captures the authorization code
    deactivate LocalWebServer

    CLIApplication->>+AWSSSO: 2. Calls CreateToken API
    Note right of CLIApplication: Params:<br/>- grant_type: "authorization_code"<br/>- client_id<br/>- client_secret<br/>- code<br/>- redirect_uri<br/>- (PKCE) code_verifier
    AWSSSO-->>-CLIApplication: Returns access_token

    CLIApplication->>User: Login successful
```
