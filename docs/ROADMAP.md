# TallyCare - Updated Roadmap (Flutter Agent App Only)

## 📋 CURRENT STATUS: ~45% Complete

**IMPORTANT**: No client app needed. Clients raise tickets from Tally software directly (TDL team handles this).

---

## ✅ COMPLETED

### MVP Phase 1: Core Agent Features
- [x] Custom Authentication (username/password)
- [x] Ticket Dashboard with realtime Supabase streams
- [x] Ticket Details View
- [x] **Status Management** - Update ticket status (New → In Progress → Resolved)
- [x] **Basic Filtering** - Toggle between All/Open/Closed tickets
- [x] **Manual Assignment** - Assign tickets to agents
- [x] **Agent List** - Fetch and display all agents

---

## 🔨 PENDING FEATURES

### Phase 1: Tally-Specific Features (HIGH PRIORITY)
**Estimated Time: 4-5 hours**

#### A. AMC Status Tracking
- [ ] **Database Schema Update**
  - [ ] Add `amc_expiry_date` to customers table
  - [ ] Add `tss_expiry_date` to customers table
  - [ ] Add `tally_serial_no` to customers table
- [ ] **AMC Status Indicator**
  - [ ] Red/Green badge on ticket cards
  - [ ] "AMC Expired" warning in ticket detail
  - [ ] Auto-calculate AMC status (expired if < NOW())
- [ ] **AMC Radar Widget** (Dashboard)
  - [ ] Donut chart: Active vs Expired AMCs
  - [ ] Click to filter tickets by AMC status
  - [ ] Count of expired AMC tickets

#### B. Asset Intelligence
- [ ] Display Tally Serial Number in ticket detail
- [ ] Display TSS expiry date with color coding
- [ ] Show customer company name prominently
- [ ] Add "Customer Info" card in ticket detail

---

### Phase 2: Communication & Collaboration
**Estimated Time: 8-10 hours**

#### A. Comments System
- [ ] **Backend**: Use existing `ticket_comments` table
- [ ] **UI**: Chat-like interface in ticket detail
- [ ] **Add Comment**: Text field + send button
- [ ] **Display Comments**: Scrollable list with timestamps
- [ ] **Internal Notes**: Toggle for "internal only" comments (yellow highlight)
- [ ] **Realtime Updates**: Stream comments via Supabase
- [ ] **Author Display**: Show agent name/username

#### B. Attachments
- [ ] **Supabase Storage Setup**
  - [ ] Create `ticket-attachments` bucket
  - [ ] RLS policies for uploads
- [ ] **File Upload Widget**
  - [ ] Image picker (screenshots)
  - [ ] File picker (.imp, .log, .txt files)
  - [ ] Upload progress indicator
  - [ ] File size limit (10MB)
- [ ] **Attachment Viewer**
  - [ ] Image gallery/preview
  - [ ] Download button for logs
  - [ ] Delete attachment (admin only)

#### C. Canned Responses
- [ ] **Database**: Create `canned_responses` table
- [ ] **Admin UI**: Manage canned responses
- [ ] **Agent UI**: Dropdown in comment box
- [ ] **Insert Logic**: One-tap to add template text
- [ ] **Categories**: Group by issue type (TDL, Sync, License, etc.)

---

### Phase 3: Field Force Management
**Estimated Time: 12-15 hours**

#### A. Digital Job Card
- [ ] **Service Report Model**
  - [ ] Use existing `service_reports` table
  - [ ] Fields: solution_provided, time_spent, parts_used, remarks
- [ ] **Service Report Form**
  - [ ] Fill out when closing ticket
  - [ ] Required fields validation
- [ ] **PDF Generation**
  - [ ] Add `pdf` package
  - [ ] Template design (company letterhead)
  - [ ] Generate on ticket close
  - [ ] Email to client (optional)

#### B. Signature Capture
- [ ] **Signature Pad Widget**
  - [ ] Add `signature` package
  - [ ] Canvas for drawing
  - [ ] Clear/Redo buttons
  - [ ] Save as PNG to Supabase Storage
- [ ] **Attach to Service Report**
  - [ ] Link signature to ticket
  - [ ] Display in PDF

#### C. Offline Mode
- [ ] **Local Database**
  - [ ] Add `hive` or `drift` package
  - [ ] Cache tickets locally
  - [ ] Sync queue for offline actions
- [ ] **Offline Indicator**
  - [ ] Banner when no internet
  - [ ] Auto-sync when back online
  - [ ] Conflict resolution

---

### Phase 4: Advanced Analytics
**Estimated Time: 10-12 hours**

#### A. SLA Breach Monitor
- [ ] **SLA Rules Engine**
  - [ ] Define SLA times (Critical=4h, High=8h, Normal=24h)
  - [ ] Calculate `sla_due` timestamp on ticket creation
  - [ ] Auto-update based on priority
- [ ] **Countdown Timer Widget**
  - [ ] Red timer on dashboard for breaching tickets
  - [ ] Sort by "Time Remaining"
  - [ ] Alert notification for SLA breach

#### B. Revenue Radar
- [ ] **Expired AMC Tickets Widget**
  - [ ] Filter tickets where `amc_expiry_date < NOW()`
  - [ ] "Sales Lead" badge
  - [ ] Export to CSV for sales team
  - [ ] Revenue opportunity calculation

#### C. Agent Performance Dashboard
- [ ] **Metrics Calculation**
  - [ ] Average Resolution Time (TAT)
  - [ ] Tickets Closed Today/This Week
  - [ ] Tickets Assigned vs Resolved
  - [ ] First Response Time
- [ ] **Leaderboard Widget**
  - [ ] Bar chart of agent performance
  - [ ] Filter by date range
  - [ ] Top performer badge

#### D. Enhanced Dashboard Widgets
- [ ] **TAT Monitor** (already has placeholder)
  - [ ] Line chart: Average TAT over time
  - [ ] Compare this week vs last week
- [ ] **Category Breaker**
  - [ ] Pie chart: Tickets by category
  - [ ] Click to filter by category
- [ ] **Ticket Trends**
  - [ ] Line chart: Tickets created vs resolved
  - [ ] Daily/Weekly/Monthly views

---

### Phase 5: Admin Features
**Estimated Time: 6-8 hours**

- [ ] **Admin Dashboard** (separate from agent)
  - [ ] All analytics in one view
  - [ ] User management (add/remove agents)
  - [ ] Customer management
  - [ ] System settings
- [ ] **User Management**
  - [ ] Add/Edit/Delete agents
  - [ ] Role assignment (Admin/Agent)
  - [ ] Reset password
- [ ] **Customer Management**
  - [ ] Add/Edit customers
  - [ ] Update AMC/TSS dates
  - [ ] View customer ticket history
- [ ] **Reports**
  - [ ] Export tickets to Excel
  - [ ] Custom date range reports
  - [ ] Agent performance reports

---

## 📈 REVISED TOTAL ESTIMATED TIME

| Phase | Hours |
|-------|-------|
| ✅ MVP Phase 1 | 3-4 (DONE) |
| Phase 1: Tally Features | 4-5 |
| Phase 2: Communication | 8-10 |
| Phase 3: Field Force | 12-15 |
| Phase 4: Analytics | 10-12 |
| Phase 5: Admin | 6-8 |
| **TOTAL REMAINING** | **40-50 hours** |

---

## 🚀 RECOMMENDED EXECUTION ORDER

1. **✅ MVP Phase 1** - COMPLETED
2. **Phase 1: Tally Features** (NEXT) - Your differentiator
3. **Phase 2: Communication** - Critical for agent-client interaction
4. **Phase 4: Analytics** - Business intelligence
5. **Phase 3: Field Force** - Advanced features
6. **Phase 5: Admin** - Management features

---

## 🎯 NEXT IMMEDIATE TASK

**Implement Phase 1: Tally-Specific Features (AMC Tracking)**

This is your core value proposition - showing AMC status on tickets and identifying sales opportunities.

**Shall I start implementing AMC tracking now?**
