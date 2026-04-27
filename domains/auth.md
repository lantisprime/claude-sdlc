---
slug: auth
last_reviewed: 2026-04-25
owner: platform-team
suggested_roles: [product, security]
---
# Authentication and Authorization

## Glossary

- **Authentication (AuthN)** — verifying who the user is. Produces an identity claim.
- **Authorization (AuthZ)** — verifying what the authenticated user is allowed to do. Separate concern from AuthN.
- **Access token** — short-lived credential proving identity/permissions. Should expire in minutes to hours.
- **Refresh token** — long-lived credential used to obtain new access tokens. Must be stored securely; rotation required.
- **OAuth 2.0** — authorization framework for delegated access. Not an authentication protocol on its own — use OIDC (OpenID Connect) on top for authentication.
- **PKCE** — Proof Key for Code Exchange. Required for public clients (SPAs, mobile apps) using the authorization code flow.
- **MFA / 2FA** — multi-factor / two-factor authentication. Adds a second verification step (TOTP, SMS, push notification, passkey).
- **Session fixation** — attack where an attacker plants a known session ID before login, then uses it after the user authenticates. Mitigated by rotating session IDs on privilege elevation.

## Typical NFRs

- Access token lifetime: 15 minutes to 1 hour for user-facing tokens; shorter for service-to-service.
- Refresh token rotation: issue a new refresh token on every use; invalidate the old one immediately.
- Session invalidation must propagate within a bounded time (define the bound). Token revocation lists or short-lived tokens are the two approaches.
- Failed login attempts must be rate-limited and logged.
- Password storage: bcrypt (cost factor ≥ 12), Argon2id, or scrypt. Never MD5, SHA-1, or unsalted SHA-2.

## Regulatory concerns

- **GDPR**: Identity data (email, name, device fingerprints) is personal data. Retention, deletion, and portability obligations apply. Data minimization: collect only what auth requires.
- **CCPA / CPRA**: Similar obligations for California residents. User deletion requests must propagate to auth data.
- **SOC 2 Type II (if applicable)**: Access control, MFA enforcement, and session management are typically in scope for CC6. This plugin does not deliver SOC 2 compliance — it surfaces the question.
- **HIPAA (if applicable)**: Automatic session timeout required. Audit log of all access to PHI systems required. Check with compliance before choosing session durations.

## Service-to-service auth

Inter-service authentication (machine-to-machine, sidecars, internal APIs) has a different risk profile from user-facing auth. If the change involves headers like `x-user-id`, `x-service-token`, or mTLS between services, several user-facing concerns (refresh token rotation, session invalidation propagation, MFA) do not apply. What does apply:

- **Credential scoping:** service tokens must be scoped to the minimum permissions required for the call. Wildcard permissions on service accounts are high risk.
- **Rotation policy:** service credentials must have a documented rotation interval. Unlike user sessions, there is no "user logs out" event to force expiry.
- **Token propagation:** verify that a service-level credential cannot be escalated by a downstream service to access resources beyond the original caller's permission boundary.
- **Audit trail:** service-to-service calls to sensitive resources require the same access logging as user-facing calls.

If the task is clearly service-to-service, treat questions about PKCE, MFA, JWKS caching, and session invalidation as not applicable. Note this explicitly in the plan's `## Domain context` section.

## Common pitfalls

- **Storing tokens in `localStorage`**: XSS-accessible. Prefer `HttpOnly` cookies for web. If using localStorage (e.g. for mobile web), understand the XSS risk surface.
- **Missing refresh token rotation**: A stolen refresh token is permanently valid. Rotate on every use; detect reuse (a reused invalidated token signals compromise).
- **Authorization checks only at the API gateway**: Gateway checks are coarse-grained. Each service or endpoint must enforce its own authorization for defense in depth.
- **Conflating authentication and authorization**: A valid session proves identity; it does not grant permission. Check both independently.
- **Implicit OAuth flow**: Deprecated. Access tokens in URL fragments are logged by servers and visible in browser history. Use authorization code + PKCE instead.
- **Missing state parameter in OAuth**: Without `state`, CSRF attacks can inject a malicious authorization code into a legitimate session.
- **Broad scopes on service tokens**: Service-to-service tokens with wildcard permissions. Scope tokens to the minimum required for the call.

## Stack notes

- **Auth0**: Use the Auth0 SDK rather than raw OIDC calls. Machine-to-machine tokens are cached by the SDK — don't request a new token on every call.
- **Okta**: Use PKCE for all SPA/mobile flows. Okta's event hooks enable real-time session revocation propagation.
- **AWS Cognito**: User pool tokens are JWT-based. Verify signatures against the JWKS endpoint, not by trusting the payload. Token expiry is enforced locally; revocation requires checking the token use endpoint.
- **Passport.js**: Strategy selection matters. `passport-local` handles password auth; OAuth flows need provider-specific strategies. Session serialization/deserialization must be implemented — it's not automatic.
- **NextAuth / Auth.js**: JWT vs database session is a meaningful choice. JWT sessions can't be revoked server-side without a blocklist; database sessions can.

## Security hotspots

- **Login endpoint**: Rate-limit by IP and by account. Log failed attempts. Don't reveal whether the email exists in error messages (use generic "invalid credentials").
- **Password reset flow**: Reset tokens must be single-use, time-limited (≤ 1 hour), and invalidated on use. Deliver only via the registered channel (email/SMS). Existing sessions should be invalidated on password change.
- **Token storage**: Where tokens live determines the attack surface. `HttpOnly` + `Secure` cookies protect against XSS; CSRF protection then becomes required.
- **JWKS endpoint caching**: Fetching JWKS on every request is slow and creates a dependency on the IdP. Cache with TTL; handle key rotation (the `kid` field identifies the signing key).
- **Privilege escalation points**: Any action that grants additional permissions (sudo mode, admin panel access, API key creation) requires fresh authentication, not just a valid session.
- **Service account credentials**: Must not be committed, must be rotated regularly, must be scoped to minimum necessary permissions.

## Scope must address

- Authentication mechanism: passwords, OAuth/OIDC, SSO, passkeys — or a combination
- Authorization model: RBAC, ABAC, ACL, or policy-based — and which system enforces it
- Token storage strategy and the security tradeoffs accepted
- Session invalidation scope: what triggers invalidation and how fast it propagates
- MFA requirement: mandatory, optional, or out of scope

## Questions plan must answer

- What is the authentication mechanism (passwords, OAuth/OIDC, SSO, passkeys)? (required: true)
- What is the authorization model (RBAC, ABAC, ACL, policy-based), and which system enforces it? (required: true)
- Where are access and refresh tokens stored, and what is the accepted XSS/CSRF risk tradeoff?
- What triggers session invalidation, and what is the maximum propagation delay?
- Is MFA required? If yes, what factors are supported (TOTP, SMS, passkey)?
- Are there service-to-service auth requirements? If yes, what credential type and rotation policy?
- Does this change touch any privilege escalation point (role grant, admin access, API key creation)?
