# AroundTally Workflows & Supabase Schema

This document rebuilds the core documentation into a single reference for decision-makers and engineers. It explains _who_ uses the platform, _how_ each workflow executes across the Agent App, Customer Portal, and Tally Plugin, and _what_ Supabase objects underpin those flows. Use it as the “new README” any time you need to brief a teammate or stand up the stack in a fresh environment.

---

## 1. Surfaces & Personas

| Surface          | Primary Personas                                   | Description                                                                                                                           |
|------------------|----------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------|
| **Agent App**    | Admin, Support Head, Support Engineer, Accountant, Sales/Moderator | Flutter desktop/web shell with role-aware routing, dashboards, ticket consoles, billing widgets, and productivity modules.            |
| **Customer Portal** | Customer Admins (primary contacts), Customer Members (teammates) | Flutter web shell that exposes customer-only views for Dashboard, My Tickets, and My Profile; enforces ownership through Supabase Auth |
| **Tally Plugin** | Back-office finance and ops teams                   | .TDL plugin embedded in Tally Prime that posts tickets directly to Supabase via `rest/v1/rpc/create_ticket` using per-customer API keys |

### Persona Cheatsheet

| Persona         | Responsibilities | Default Landing View | Signature Actions |
|-----------------|------------------|----------------------|-------------------|
| **Admin**       | Governance, KPI review, feature toggles, settings | Admin dashboard | Adjust app/advanced settings, view reports, reassign tickets, approve overrides |
| **Support Head**| Queue health, SLA triage, escalation             | Support HQ dashboard | Split AMC vs. Normal queues, mass-assign, escalate breaches |
| **Support Engineer** | Ticket execution, commenting, service reports | My Tickets dashboard | Claim/unclaim tickets, log service reports, toggle statuses |
| **Accountant**  | Billing and reconciliation                        | Billing dashboard | Move tickets to `BillRaised`/`BillProcessed`, audit invoices |
| **Sales/Moderator** | Productivity widgets, deals backlog, announcements | Productivity dashboard | Update deals pipeline, publish wiki/articles, send notifications |
| **Customer Admin** | Manage company profile, raise tickets, monitor AMC/TSS | Portal dashboard | Create/reopen tickets, update company + accountant info, invite coworkers |
| **Customer Member** | Raise/track tickets, collaborate via comments | My Tickets | Submit issues, comment, reopen tickets (no profile editing) |

---

## 2. Detailed Workflows

### 2.1 Authentication & Session Priming

1. **Agent App** uses a custom RPC (`login_agent`) invoked via Riverpod notifier. Successful responses include `{success, agent}` and hydrate the `Agent` model with role metadata for routing.@lib/features/auth/presentation/providers/auth_provider.dart#8-72 @supabase/migrations/20250524000000_initial_schema.sql#151-183
2. **Customer Portal** relies on Supabase Auth email/password or OTP flows. After login, the client caches `customer_id`, `company_name`, and `role` in user metadata to ensure row filtering even when the page reloads.@lib/website/services/supabase_service.dart#117-210
3. **Shared State**: `GoRouter` inspects the signed-in agent’s role and advanced settings to decide which route to land on and which screens are permitted. Feature toggles (reports/wiki/deals/notifications) come from `app_settings`, while per-role visibility reads from `advancedSettings` (role permissions).@lib/main.dart#65-150 @lib/features/dashboard/domain/models/advanced_settings.dart#105-190

### 2.2 Ticket Intake (Customers & Tally)

1. **Customer Portal**  
   - Company admin/member selects “Create Ticket,” supplies metadata (category, priority).  
   - The portal writes to the `tickets` table with the currently cached `customer_id`.  
   - Result: Agent dashboards immediately see the new ticket via realtime subscriptions.

2. **Tally Plugin**  
   - User submits a support ticket within Tally Prime; plugin issues `POST /rest/v1/rpc/create_ticket`.  
   - Supabase validates the `x-tally-api-key` header through `get_customer_id_by_header`, guaranteeing the request is scoped to the right company.  
   - Function `create_ticket` deduplicates by `(customer_id, client_ticket_uuid)`, inserts the ticket, and writes an audit-log entry so agents can trace origin and payload.@supabase/migrations/20250524000000_initial_schema.sql#98-254

3. **Audit Trail**  
   - Every intake path results in `audit_log` rows with `action='ticket_created'`.  
   - Agents can replay payloads to debug duplicates or invalid requests.

### 2.3 Assignment & SLA Triage (Support Head)

1. Support Head views AMC vs. Normal queues with real-time counts.  
2. Selecting a ticket opens detail view with customer context, AMC/TSS badges, and assignment controls.  
3. Assigning an agent updates `tickets.assigned_to`, logging another audit event and pushing real-time updates to all dashboards.  
4. SLA widgets highlight overdue or soon-due tickets so the Support Head can escalate or reassign before breaches.

### 2.4 Ticket Execution (Support Engineer)

1. Support Engineer lands on “My Tickets” with filters for status (New, Open, In Progress, etc.).  
2. Actions available per ticket:  
   - **Claim**: If unassigned, sets `assigned_to` to the engineer’s UUID.  
   - **Update Status**: Moves through lifecycle (`New → Open → In Progress → Waiting for Customer → Resolved/Closed`).  
   - **Commenting**: Adds customer-facing or internal notes via `ticket_comments` with `internal` flag for private chatter.  
   - **Service Report**: Captures work summary, time, parts, and signature URLs for field jobs; stored in `service_reports`.@supabase_schema.txt#134-159
3. All actions surface instant feedback to the portal so customers can watch progress or reopen if needed.

### 2.5 Billing Loop (Accountant)

1. Accountant filters tickets awaiting billing.  
2. When billing is raised, status transitions to `BillRaised`; once payment is processed, `BillProcessed`. These statuses are part of the `tickets.status` enum to keep finance tracking in the same table as support work.@supabase_schema.txt#172-190
3. Billing activity can be mirrored in `audit_log` and optionally triggers downstream accounting exports.

### 2.6 Customer Self-Service Lifecycle

1. **Registration / Claiming**  
   - New customers register via portal; workflow creates Supabase Auth user, inserts `customers` row, and stores metadata / password references.  
   - Existing customers can “claim account” by verifying company name + email; the service updates password field and links Supabase Auth user to `customers.auth_user_id`.@lib/website/services/supabase_service.dart#226-335
2. **Dashboard & Ticket Views**  
   - Dashboard shows six most recent tickets, quick filters, and CTA to create new ones.  
   - Ticket detail lets customers comment, attach context, and reopen resolved tickets (when permitted by RLS/app logic).  
3. **Profile Management**  
   - “My Profile” writes updates to `customers` (contact info, accountant details, AMC/TSS fields), with optimistic cache updates so UI reflects changes instantly.@lib/website/services/supabase_service.dart#518-575
4. **Password Reset**  
   - Customers invoke password reset using the stored “secret email.” Custom RPC `reset_customer_password_by_secret_email` enforces secure rotation from portal UI without exposing Supabase dashboard access.@lib/website/services/supabase_service.dart#348-365

---

## 3. Supabase Schema Reference

### 3.1 Tables & Key Columns

| Table | Purpose | Notable Columns |
|-------|---------|-----------------|
| `customers` | Master record per company including AMC/TSS metadata and per-portal credentials. Also stores unique `api_key` for Tally plugin authentication. | `company_name`, `api_key`, `amc_expiry_date`, `tss_expiry_date`, `contact_*`, optional accountant & Tally license fields.@supabase/migrations/20250524000000_initial_schema.sql#11-35 |
| `agents` | Custom auth store for Agent App; used by `login_agent` RPC. | `username`, `password` (plaintext MVP), `role`, `full_name`.@supabase/migrations/20250524000000_initial_schema.sql#26-35 |
| `tickets` | Core ticket lifecycle entity, referencing both customers and agents. | `customer_id` FK, `client_ticket_uuid` for idempotency, `priority`, `status`, `assigned_to`, `sla_due`, timestamps.@supabase/migrations/20250524000000_initial_schema.sql#36-54 |
| `ticket_comments` | Customer/agent conversation plus internal notes. | `author`, `body`, `internal` flag for private notes.@supabase/migrations/20250524000000_initial_schema.sql#55-64 |
| `service_reports` | Field-service forms tied to tickets. | `solution_provided`, `time_spent_minutes`, `parts_used`, `customer_signature_url`, `agent_signature_url`.@supabase/migrations/20250524000000_initial_schema.sql#65-78 |
| `audit_log` | Immutable record of actions performed on tickets. | `action`, `payload` (JSON), `performed_by`, `created_at`.@supabase/migrations/20250524000000_initial_schema.sql#80-88 |

Additional optional tables captured in `supabase_schema.txt` (e.g., `activities`, `contacts`, `deals`, `notifications`, `app_settings`, `role_permissions`) support extended CRM/productivity experiences and follow the same UUID + FK conventions.@supabase_schema.txt#1-191

### 3.2 Relationships

```
customers 1 ── * tickets ── * ticket_comments
         │            │
         │            └── * service_reports
         │
         └── * contacts / customer_notes / activities

agents 1 ── * tickets (assigned_to)
agents 1 ── * service_reports
agents 1 ── * audit_log (performed_by text in MVP)
```

Key characteristics:
- **Cascade Deletes**: Tickets cascade to comments/service reports to keep orphan data out when a customer is purged.  
- **Realtime**: Flutter clients subscribe to `tickets` and `ticket_comments` via Supabase realtime channels filtered by `created_by` or `customer_id`.@lib/website/services/supabase_service.dart#579-599
- **Idempotency**: Combination of `customer_id + client_ticket_uuid` prevents Tally plugin duplicates in unstable network conditions.

### 3.3 RPC Surface & Security

| RPC | Description | Security Notes |
|-----|-------------|----------------|
| `login_agent(p_username, p_password)` | Authenticates Agent App users, returns role metadata. | `security definer`; exposed to `anon` so Flutter client can call it directly. Replace plaintext passwords with hashes before production.@supabase/migrations/20250524000000_initial_schema.sql#151-183 |
| `create_ticket(...)` | Ingests tickets from Tally plugin, enforces API-key scoping, writes audit log, returns created ticket ID/status. | `security definer`; relies on `get_customer_id_by_header` reading `x-tally-api-key`.@supabase/migrations/20250524000000_initial_schema.sql#188-254 |
| `reset_customer_password_by_secret_email` | Lets portal users rotate passwords if they know the company-specific secret email. | Called through `SupabaseService.resetPasswordWithSecretEmail` so customer support can help without touching Supabase dashboard.@lib/website/services/supabase_service.dart#348-366 |

**Row-Level Security (MVP)**  
All core tables have RLS enabled but permissive policies granting `anon` full access for the MVP. Harden before production by:
1. Splitting Supabase service roles for Tally vs. portal vs. agent traffic.  
2. Replacing permissive policies with JWT-claim-aware policies (e.g., `auth.uid() = agents.auth_user_id`).  
3. Moving agent auth into Supabase Auth or custom JWT issuance so the Flutter app no longer transmits plaintext passwords.

---

## 4. Implementation Pointers

1. **Folder Structure**: See `README.md` section “Repository & Feature Structure” for how the Flutter project splits into `core/` and `features/*` directories with Clean Architecture slices.@README.md#98-115
2. **Configuration**: Update Supabase URL + anon key in `main.dart` (Agent App) and `SupabaseService.initialize()` (Portal). Externalize secrets via env files before shipping.@lib/main.dart#35-145 @lib/website/services/supabase_service.dart#4-52
3. **Build & Generate**: Run `flutter pub get` and `flutter pub run build_runner build --delete-conflicting-outputs` so Riverpod generators keep providers in sync (e.g., `auth_provider.g.dart`).@docs/TESTING_GUIDE.md#20-27
4. **Seeds**: Execute `supabase/migrations/20250524000000_initial_schema.sql`, then `supabase/seed.sql` (or `supabase/migrations/20251124000000_update_schema_and_seed.sql` if you need richer demo data).@docs/SETUP.md#3-10
5. **Tally Rollout**: Before distributing `tally/ticket_plugin.tdl`, inject the customer’s `api_key` so the plugin can call `create_ticket` on their behalf.@docs/SETUP.md#11-23

Use this document as the canonical reference whenever you need to understand how AroundTally’s workflows map onto Supabase tables and RPCs, or when you need to reproduce the platform in a new workspace.
