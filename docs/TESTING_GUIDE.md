# 🧪 TallyCare - Complete Testing Guide

## 📋 Pre-Testing Checklist

### 1. Database Setup ✅
```sql
-- In Supabase Dashboard → SQL Editor
-- Step 1: Run migration
Execute: supabase/migrations/20250524000000_initial_schema.sql

-- Step 2: Run seed data
Execute: supabase/seed.sql
```

**What this creates:**
- 2 Test Customers (1 active AMC, 1 expired AMC)
- 2 Test Agents (admin, agent)
- Tables: customers, agents, tickets, ticket_comments, audit_log

### 2. Build Runner ✅
```bash
cd c:/Users/user/StudioProjects/ticketing_system
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Launch App ✅
```bash
flutter run -d windows
```

---

## 🎯 Test Scenarios

### **Test 1: Login & Authentication**
**Steps:**
1. Launch app
2. Enter username: `admin`
3. Enter password: `admin123`
4. Click Login

**Expected Result:**
- ✅ Successful login
- ✅ Redirect to Agent Dashboard
- ✅ See "TallyCare Agent Dashboard" title

---

### **Test 2: Dashboard - AMC Radar Widget**
**Steps:**
1. After login, observe dashboard
2. Look at right side of "Performance Overview"

**Expected Result:**
- ✅ See "AMC Radar" card
- ✅ Pie chart showing:
  - 1 Active AMC (green slice)
  - 1 Expired AMC (red slice)
- ✅ Legend shows counts
- ✅ "Sales Leads: 1 opportunity" box visible

---

### **Test 3: Ticket List with AMC Badges**
**Steps:**
1. Scroll down to "Recent Tickets"
2. Observe ticket cards

**Expected Result:**
- ✅ Each ticket shows AMC status icon:
  - Green checkmark = Active AMC
  - Red warning = Expired AMC
- ✅ Tickets display title, category, priority
- ✅ Status and priority chips visible

---

### **Test 4: Filter Functionality**
**Steps:**
1. Click "Open" filter chip
2. Observe ticket list
3. Click "Closed" filter chip
4. Click "All" filter chip

**Expected Result:**
- ✅ "Open" shows only New/Open/In Progress tickets
- ✅ "Closed" shows only Resolved/Closed tickets
- ✅ "All" shows all tickets
- ✅ Selected filter chip is highlighted

---

### **Test 5: Ticket Detail - Customer Info Card**
**Steps:**
1. Click any ticket from the list
2. Scroll down past ticket description
3. Observe "Customer Information" card

**Expected Result:**
- ✅ Company name displayed
- ✅ Tally Serial Number shown
- ✅ AMC Status card:
  - Shows "Active" or "Expired"
  - Displays expiry date
  - Color-coded (green/red)
  - Shows days remaining if < 30 days
- ✅ TSS Status card (similar to AMC)
- ✅ Contact details (person, phone, email)

---

### **Test 6: Status Update**
**Steps:**
1. In ticket detail, click 3-dot menu (top right)
2. Select "In Progress"
3. Wait for confirmation

**Expected Result:**
- ✅ Green snackbar: "Status updated to In Progress"
- ✅ Status chip updates immediately
- ✅ Go back to dashboard - status reflects change

---

### **Test 7: Agent Assignment**
**Steps:**
1. In ticket detail, click person icon (top right)
2. Dialog shows list of agents
3. Click an agent

**Expected Result:**
- ✅ Dialog shows "admin" and "agent" users
- ✅ Shows full name and role
- ✅ After selection: Green snackbar "Assigned to [name]"
- ✅ Dialog closes

---

### **Test 8: Comments System**
**Steps:**
1. In ticket detail, scroll to "Comments" section
2. Type a comment in text field
3. Click send button (floating action button)
4. Toggle "Internal Note" checkbox
5. Add another comment
6. Send

**Expected Result:**
- ✅ First comment appears in chat bubble
- ✅ Shows author name and timestamp
- ✅ Comment aligned based on current user
- ✅ Internal note has:
  - Orange background
  - Lock icon
  - "INTERNAL" badge
  - Orange border
- ✅ Comments appear in real-time
- ✅ Green snackbar: "Comment added successfully"

---

### **Test 9: Internal Notes**
**Steps:**
1. In comments section, check "Internal Note"
2. Add comment: "This is a private note"
3. Send

**Expected Result:**
- ✅ Comment has orange background
- ✅ Lock icon visible
- ✅ "INTERNAL" badge shown
- ✅ "Only visible to agents" subtitle displayed

---

### **Test 10: Real-time Updates**
**Steps:**
1. Keep ticket detail page open
2. In Supabase Dashboard, manually add a comment to `ticket_comments` table
3. Observe the app

**Expected Result:**
- ✅ New comment appears automatically
- ✅ No page refresh needed
- ✅ Supabase real-time stream working

---

## 🐛 Known Issues & Workarounds

### Issue 1: `@JsonKey` Warnings
**Status:** Cosmetic only, doesn't affect functionality
**Impact:** None - app works perfectly
**Fix:** These are Freezed code generation warnings, safe to ignore

### Issue 2: `authNotifierProvider` Undefined
**Status:** Will resolve after build_runner completes
**Impact:** None if build_runner was run
**Fix:** Run `flutter pub run build_runner build --delete-conflicting-outputs`

---

## 📊 Feature Checklist

| Feature | Status | Test Result |
|---------|--------|-------------|
| Login | ✅ Implemented | ⬜ Pass/Fail |
| Dashboard AMC Radar | ✅ Implemented | ⬜ Pass/Fail |
| AMC Badges on Tickets | ✅ Implemented | ⬜ Pass/Fail |
| Filter Chips | ✅ Implemented | ⬜ Pass/Fail |
| Customer Info Card | ✅ Implemented | ⬜ Pass/Fail |
| Status Updates | ✅ Implemented | ⬜ Pass/Fail |
| Agent Assignment | ✅ Implemented | ⬜ Pass/Fail |
| Comments System | ✅ Implemented | ⬜ Pass/Fail |
| Internal Notes | ✅ Implemented | ⬜ Pass/Fail |
| Real-time Updates | ✅ Implemented | ⬜ Pass/Fail |

---

## 🚀 Performance Testing

### Load Testing
1. **Create 50+ tickets** in Supabase
2. **Observe dashboard** - Should load smoothly
3. **Test filtering** - Should be instant (client-side)
4. **Test comments** - Real-time updates should be fast

### Expected Performance:
- Dashboard load: < 2 seconds
- Ticket detail load: < 1 second
- Comment submission: < 500ms
- Real-time updates: Instant

---

## 📱 UI/UX Testing

### Visual Checks:
- ✅ All text readable
- ✅ Colors consistent (green=good, red=warning, orange=internal)
- ✅ Icons appropriate
- ✅ Spacing comfortable
- ✅ Cards have elevation/shadows
- ✅ Buttons have hover states

### Responsive Design:
- ✅ Works on different window sizes
- ✅ Scrolling smooth
- ✅ No overflow errors
- ✅ Text wraps properly

---

## 🔒 Security Testing

### Authentication:
- ✅ Cannot access dashboard without login
- ✅ Wrong credentials show error
- ✅ Session persists on page refresh

### Data Access:
- ✅ Only see own organization's tickets
- ✅ RLS policies enforced
- ✅ Internal notes only visible to agents

---

## 📝 Test Report Template

```markdown
## Test Session Report
**Date:** [Date]
**Tester:** [Name]
**Build:** [Version]

### Tests Passed: X/10
### Tests Failed: X/10

### Failed Tests:
1. [Test Name] - [Reason] - [Screenshot]

### Bugs Found:
1. [Description] - [Severity: High/Medium/Low]

### Performance Notes:
- Dashboard load time: [X]s
- Comments load time: [X]s

### Recommendations:
1. [Suggestion]
```

---

## ✅ Sign-Off Criteria

**Ready for Production when:**
- ✅ All 10 test scenarios pass
- ✅ No critical bugs
- ✅ Performance acceptable
- ✅ UI/UX approved
- ✅ Security verified

---

**Happy Testing! 🎉**
