# Personal AI Usage Charter for a DWP Engineer

## Using Public AI Assistants for Desktop and Endpoint Work

## Purpose

I use public AI assistants to improve speed, clarity, and consistency in my engineering work, not to replace professional judgement. I remain accountable for every prompt I send, every output I use, and every change I make in DWP environments.

## 1. Appropriate Uses of Public AI Assistants

I may use public AI tools for low-risk, general engineering support where no sensitive DWP information is disclosed. Appropriate uses include:

- Drafting PowerShell, batch, CMD, Bash, Intune remediation, detection, or packaging scripts from generic requirements.
- Rewriting or explaining my own non-sensitive scripts to improve readability, logging, error handling, or structure.
- Troubleshooting generic Windows desktop and endpoint issues using anonymised symptoms, error text, or event patterns.
- Creating checklists, rollout steps, test plans, rollback plans, and documentation templates for endpoint changes.
- Summarising public vendor guidance for Microsoft, Windows, Intune, Defender, SCCM, drivers, patching, or endpoint configuration.
- Generating examples for registry edits, scheduled tasks, services, file permissions, app deployment logic, or device compliance logic using fake names and dummy values.
- Asking for safer ways to validate changes, reduce blast radius, or improve script idempotency.

## 2. Uses That Are Not Appropriate

I will not use public AI assistants for any task that exposes sensitive DWP information or delegates security-critical judgement. This includes:

- Sharing production scripts, configs, logs, screenshots, tickets, inventories, hostnames, usernames, email addresses, IPs, device IDs, tenant details, or internal architecture if they are not fully sanitised.
- Entering end-user data, claimant data, colleague data, HR data, case data, support records, or any other personal or operationally sensitive information.
- Sharing credentials, secrets, API keys, tokens, certificates, private keys, recovery keys, or authentication flows.
- Asking AI to make final decisions on security controls, policy exceptions, incident handling, privileged access, or live production changes.
- Using AI output directly in production for device changes, packaging, login scripts, compliance baselines, remediation, or uninstall actions without review and testing.
- Treating AI answers as DWP policy, security approval, or authoritative technical guidance.

## 3. Data-Handling Rule: PII and Credentials

I will never paste end-user PII, credentials, secrets, or live environment identifiers into a public AI assistant. If I need help, I will first sanitise the prompt so it contains only the minimum technical context required. I will replace real names, usernames, device names, tenant details, file paths, registry values, ticket references, and error context with dummy placeholders unless those values are already public and non-sensitive. If I am unsure whether data is safe to share, I will treat it as not safe and keep it out of the prompt.

## 4. Generate Then Verify Rule

I will treat AI output as a draft, not a finished change. For any script, package, configuration, or system change, I will:

1. Read the output fully and understand what every command does.
2. Check for destructive actions, privilege requirements, network calls, persistence changes, data collection, and security impact.
3. Verify syntax, dependencies, paths, detection logic, exit codes, and rollback steps.
4. Test first in a safe, non-production environment or isolated test device.
5. Confirm expected and failure behaviour, including logging and error handling.
6. Use peer review or team review where the change is material, high-risk, or broad in scope.
7. Only promote to live use when I can explain and defend the change myself.

## Working Principle

Public AI is acceptable for generic drafting, explanation, and structured thinking on desktop and endpoint engineering tasks. It is not a place to put DWP-sensitive data, and it is not a substitute for verification, testing, or accountability.