# Security Policy

## Reporting a Vulnerability

Please do not open public GitHub issues for security vulnerabilities.

Send a private report to:

- `team@switchcodes.com`

Include:

- A clear description of the issue
- Steps to reproduce
- Affected component (`api`, `ui`, `app`, Docker, CI)
- Potential impact
- Suggested fix, if known

## Supported Versions

The default branch is the actively supported development line until formal
versioned releases are published.

## Secrets

Never commit:

- `.env` files with real values
- Stripe secret keys
- Google Maps API keys
- JWT secrets
- SMTP credentials
- Database dumps with personal data
