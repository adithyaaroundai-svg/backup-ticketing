# TallyCare Application Overview

This document explains how the two delivery surfaces — the **agentic application** and the **customer web portal** — work from a user and operations standpoint. It focuses entirely on behaviors, workflows, and capabilities so you can brief clients without referencing implementation artifacts.

## 1. Agentic Application (Desktop/Mobile)

### How it works
The agentic application is the control center for admins, support leads, engineers, accountants, and revenue planners. Users log in with their assigned role, which immediately determines which dashboards, navigation items, and actions are available. Day-to-day work happens inside role-specific dashboards (`Support Head`, `Support`, `Accountant`, `Admin`) plus the Tickets, Customers, Billing, and Productivity sections, so every user lands on the workflow they need without hunting for screens.

### Core Features

1. **Role-conscious login and access**
   - Credential verification automatically maps agents to their role so the navigation bar surfaces only their permitted features, preventing accidental access while keeping compliance simple.

2. **Operational dashboards**
   - Dashboards highlight SLA-sensitive queues (e.g., unclaimed tickets, AMC priority work) and provide refresh/action buttons so agents can jump right into high-priority items without losing context.

3. **Ticket triage and lifecycle management**
   - A dedicated Tickets console lets teams toggle between “my work,” unassigned tickets, and pending/resolved alert tabs, with a split view that distinguishes AMC (priority) customers from standard accounts.
   - Ticket detail views confirm assignments with inline feedback, while assignment selectors only expose eligible agents based on their role, streamlining collaboration.

4. **Customer and billing visibility**
   - Customer master data, including AMC status, contact points, and billing flags, is accessible through list/detail forms. The Billing view lets accountants tie ticket work to invoices, providing traceability from service to revenue.
   - Productivity modules (notifications, wiki references, deals) are available when enabled, keeping non-ticket work and announcements within the same experience.

5. **Extendable architecture**
   - Clean separation between UI, domain logic, and data access lets this surface grow new dashboards, analytics widgets, or integrations without disrupting the flows agents already rely on.

### Role-based dashboards

Each agent role lands on a tailored dashboard:

- **Admin**: sees high-level KPIs for live queue size, AMC coverage, and today’s throughput. KPI cards are paired with a live ticket board that exposes SLA health buckets and ticket urgency, plus quick actions for reports, global tickets, and app settings so decision-makers can act or reroute teams.
- **Support Head**: defaults to the primary agent dashboard with modules for unclaimed cards, split Normal vs. AMC queues, and action buttons that refresh data or jump straight into the unclaimed view. It surfaces customers with AMC status so leaders can flag priority work while keeping an eye on backlog.
- **Support Engineer**: receives personal statistics (assigned tickets, response-time alerts, resolved today) alongside list previews for active work and the unclaimed queue. Floating action buttons enable support staff to raise new service tickets and claim high-priority ones quickly.
- **Accountant**: focuses on billing. The dashboard surfaces pending bills, recently processed collections, and average pending age, along with filters to slice tickets by priority/customer and tabs for pending vs. completed billing cases. It keeps billing context close to finance-related ticket flows.

## 2. Customer Web Portal

### How it works
The portal is a customer-facing Flutter web shell. External companies log in with their company name (or claim a pre-provisioned account), and the layout anchors to a persistent sidebar plus a responsive header. Each page communicates with Supabase so the portal can show only that customer’s tickets, profile, and metadata, keeping the experience locked to their organization.

### Core Features

1. **Customer-first authentication**
   - Customers authenticate via email/password or OTP, and the portal automatically remembers their company identity, so navigation and ticket history reload instantly after a page refresh.
   - Registration and account claiming workflows walk users from company verification to password creation, with helpful messages when an account already exists.

2. **Guided portal shell**
   - The fixed sidebar lists Dashboard, My Tickets, and My Profile, while the header allows refreshing data and showing context-specific actions like “Create Ticket.” A profile panel surfaces company initials, email, and a logout button that clears sessions.

3. **Dashboard and ticket hero**
   - The dashboard aggregates six recent tickets in a responsive grid, adds navigation cards for open/closed tickets, and keeps a “Create Ticket” button visible so customers can raise issues quickly.

4. **Full ticket lifecycle for customers**
    - Customers can raise new issues with optional metadata (category, priority), view their open/closed lists, and reopen resolved tickets — the portal enforces ownership so they only see and update their own requests.

5. **Profile and account servicing**
    - “My Profile” lets customers update company name, contacts, and notification prefs. The portal reflects updates immediately while persisting changes centrally so internal agents have accurate data for coordination.

### Customer portal roles and permissions

- **Primary contacts / company admins**: can raise tickets on behalf of their organization, unlock billing or AMC requests, view every historical ticket, and maintain profile details (company name, contact info, accountant details). They typically manage the portal experience for their team.
- **Secondary users / coworkers**: they inherit visibility into the same ticket list but have lighter controls, focusing on opening new tickets, commenting on existing ones, and monitoring resolutions without editing company profile or billing specifics.

## 3. Shared Experience Notes

- Both surfaces connect to the same Supabase backend, ensuring tickets, customers, and agents stay synchronized in real time.
- The agentic application uses reactive state streams so dashboards update as soon as new tickets arrive, while the portal employs direct service calls optimized for customer ownership and caching.

## 4. Future Documentation Opportunities

- Document migration/seed expectations (`supabase/migrations` and `supabase/seed.sql`) and API surface for Supabase functions (`login_agent` RPC, password reset RPC).
- Expand README to include portal-specific screens, flows, and security considerations (e.g., why RLS is disabled on the tickets table for the portal).
