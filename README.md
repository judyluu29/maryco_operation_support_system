# MaryCo IT Support System

An AI-assisted operation support chatbot and real-time administrative dashboard developed as a demonstration solution for a community-service organisation.

## Live Demo

* **Staff IT Support Chatbot:** [Open chatbot](https://maryco-it-support.netlify.app/)
* **IT Administration Dashboard:** [Open dashboard](https://maryco-it-dashboard.netlify.app/)
* Use the following read-only account to explore the dashboard:
- **Email:** `demo@maryco-portfolio.com`
- **Password:** `MaryCoDemo2026!`

## Project Overview

MaryCo IT Support is a two-part internal support system designed for non-technical and time-poor staff. It provides immediate troubleshooting assistance through an AI chatbot and allows unresolved issues to be converted into structured support tickets.

Submitted tickets are stored in Supabase and displayed on a separate administrative dashboard. IT staff can monitor incoming cases, change their status, review recurring support issues and manage workplace supply requests.

## Business Problem

* Limited time and technical knowledge: Staff are often non-technical and time-poor because their main responsibility is supporting vulnerable community members.
* Frequent routine IT issues: Staff regularly experience password, Microsoft 365, printer, laptop, Wi-Fi, VPN and shared-file problems that could often be resolved through guided self-service.
* Unnecessary pressure on IT resources: Routine questions require IT assistance, taking time away from serious hardware failures, network outages and security incidents.
* Inconsistent support requests: Requests may not include the affected device, location, issue details, troubleshooting already attempted or support required, making diagnosis slower.
* Difficulty prioritising incidents: Routine enquiries can become mixed with urgent incidents, making it harder to identify cases requiring immediate escalation.
* Limited case visibility: Without a central dashboard, IT staff cannot easily monitor open cases, ticket progress, priority levels or unresolved requests approaching their service-level timeframes.
* Limited operational insights: The organisation has difficulty identifying recurring issue categories, self-resolved enquiries and areas where staff may need additional guidance.
* Disconnected supply requests: Requests for toner, cables, chargers and other workplace equipment need to be recorded and tracked separately.

# Proposed Solution
This prototype demonstrates how an integrated chatbot and dashboard can:

* Provide immediate guidance for common IT issues
* Reduce repetitive support enquiries
* Standardise ticket collection
* Improve visibility of unresolved requests
* Support prioritisation and follow-up
* Identify recurring issues through dashboard insights

## Main Features

### IT Support Chatbot

* AI-assisted troubleshooting using Anthropic Claude
* Support for Microsoft 365, printers, laptops and Cisco AnyConnect
* Guidance for projectors, account security and workplace supplies
* Guided collection of issue information
* Automatic support-ticket creation
* Unique case references such as `MC-1001`
* Responsive interface for desktop and mobile devices
* Direct link to the administrative dashboard

### Administration Dashboard

* Supabase email and password authentication
* Role-based access through the `staff` table
* Real-time display of submitted support tickets
* Search and filtering by status and priority
* Ticket-status management
* Supply-request tracking
* Notification-rule management
* Operational insights and support trends
* Realtime updates with a polling fallback

### Automation

* Secure ticket submission through Supabase Edge Functions
* Hourly SLA checks using `pg_cron`
* Priority-based notification rules
* Email integration prototype using Google Apps Script
* External notification delivery disabled in the public demonstration

## Technology Stack

| Component               | Technology                     |
| ----------------------- | ------------------------------ |
| Frontend                | HTML, CSS and JavaScript       |
| Database                | Supabase PostgreSQL            |
| Authentication          | Supabase Auth                  |
| Access control          | PostgreSQL Row Level Security  |
| Realtime updates        | Supabase Realtime              |
| Backend functions       | TypeScript and Deno            |
| Artificial intelligence | Anthropic Claude API           |
| Scheduling              | Supabase `pg_cron`             |
| Notification prototype  | Google Apps Script and MailApp |
| Hosting                 | Netlify                        |
| Version control         | GitHub                         |

## Database Design

The Supabase PostgreSQL database contains the following tables:

| Table                | Purpose                                            |
| -------------------- | -------------------------------------------------- |
| `staff`              | Connects authenticated users to application roles  |
| `cases`              | Stores submitted support tickets                   |
| `queries`            | Stores chatbot enquiries resolved without a ticket |
| `orders`             | Stores workplace supply requests                   |
| `notification_rules` | Stores notification settings by priority           |
| `email_log`          | Records notification attempts                      |

## Edge Functions

| Function         | Purpose                                        |
| ---------------- | ---------------------------------------------- |
| `super-function` | Communicates securely with the Claude API      |
| `support-submit` | Validates and records support requests         |
| `sla-check`      | Checks unresolved cases against SLA conditions |

The `sla-hourly` scheduled job runs the SLA checker every hour.

## Security

* Dashboard users authenticate through Supabase Auth.
* Database access is controlled using Row Level Security.
* Anonymous development database policies are removed before deployment.
* The public demo account cannot modify staff account records.
* Claude and service-role credentials are stored in Supabase secrets.
* Secrets, passwords and webhook tokens are excluded from this repository.
* Frontend files contain only the browser-safe Supabase URL and publishable key.
* External email and Teams notifications are disabled for the public demo.
* All demonstration records are fictional and non-identifying.

## Project Structure

```text
maryco-it-support-system/
├── maryco-chatbot-secure.html
├── maryco-dashboard-auth.html
├── schema.sql
├── supabase/
│   ├── demo-security.sql
│   └── functions/
│       ├── super-function/
│       │   └── index.ts
│       ├── support-submit/
│       │   └── index.ts
│       └── sla-check/
│           └── index.ts
├── README.md
└── .gitignore
```

## Skills Demonstrated

* Business problem analysis
* User-focused solution design
* SQL database design
* Authentication and authorisation
* Row Level Security
* API integration
* AI chatbot integration
* Real-time dashboard development
* Workflow automation
* Testing and troubleshooting
* Cloud deployment
* Technical documentation

## Demonstration Limitations

* Demonstration data may be reset periodically.
* Email and Teams delivery are disabled to prevent external messages.
* The application is a prototype and is not intended to store sensitive information.

## Disclaimer

This is an independent demonstration prototype created for a G’dAI Hack Day project. It is not an official production system of Mary’s House Services and does not contain real client or organisational data.
