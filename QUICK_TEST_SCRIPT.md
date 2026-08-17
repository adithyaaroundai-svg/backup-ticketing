# 🧪 Quick Test Script - 5 Minute Verification

## Prerequisites
- 2 test users (User A and User B)
- 2 browser tabs or devices
- Volume turned ON

---

## Test 1: Channel Name Display (2 minutes)

### Steps:
1. **User A:** Login → Create custom channel "Quick Test Channel"
2. **User A:** Add User B as member
3. **User A:** Send message: "Testing 123"
4. **User B:** (on Dashboard or any page except the channel)

### ✅ Expected Result:
```
Notification appears:
- Shows: "# Quick Test Channel" (NOT a UUID)
- Shows User A's full name
- Sound plays
```

### ❌ If Failed:
- Check browser console for errors
- Verify `customChannelsProvider` is loaded
- Check database: `SELECT * FROM custom_channels WHERE name = 'Quick Test Channel'`

---

## Test 2: Private Channel Security (1 minute)

### Steps:
1. **User A:** Create PRIVATE channel "Secret Chat"
2. **User A:** Add ONLY User B (not User C)
3. **User A:** Send message: "This is private"
4. **User B:** Should see notification ✅
5. **User C:** Should NOT see notification ✅

### ✅ Expected Result:
```
User B: Notification appears with "# Secret Chat"
User C: NO notification (not a member)
```

### ❌ If Failed:
- Check `channel_members` table: `SELECT * FROM channel_members WHERE channel_id = '...'`
- Verify `is_private = true` in database
- Check browser console for membership validation logs

---

## Test 3: Sender Name Resolution (30 seconds)

### Steps:
1. **User A:** (Full name: "John Smith") sends message in any channel
2. **User B:** Receives notification

### ✅ Expected Result:
```
Notification shows:
- Avatar: "J" (first letter of John)
- Name: "John Smith" (full name, not user ID)
```

### ❌ If Failed:
- Check `agents` table: `SELECT id, full_name FROM agents WHERE id = '...'`
- Verify `agentsListProvider` is loaded
- Check browser console for errors

---

## Test 4: @Mention Sound (30 seconds)

### Steps:
1. **User A:** Send message: "@[User B Full Name] please check this"
2. **User B:** Listen for sound

### ✅ Expected Result:
```
User B hears: Special mention sound (different pitch/tone than regular ping)
```

### ❌ If Failed:
- Check browser audio permissions
- Verify message contains exact full name with @ symbol
- Check `ChatSoundService.playMentionPing()` is called

---

## Test 5: Regular Sound (30 seconds)

### Steps:
1. **User A:** Send message: "Hello everyone" (no @mention)
2. **User B:** Listen for sound

### ✅ Expected Result:
```
User B hears: Regular ping sound
```

### ❌ If Failed:
- Check browser audio permissions
- Verify `ChatSoundService.playPing()` is called
- Check device volume

---

## Test 6: Unread Counter (30 seconds)

### Steps:
1. **User A:** Send 3 messages in custom channel
2. **User B:** Check Chat icon badge in sidebar
3. **User B:** Open the custom channel
4. **User B:** Check badge again

### ✅ Expected Result:
```
Step 2: Badge shows "3" (or total including other channels)
Step 4: Badge decreases by 3 (custom channel unread cleared)
```

### ❌ If Failed:
- Check `customChannelUnreadCountProvider` in dev tools
- Verify `markCustomChannelAsRead()` is called when opening channel
- Check last_seen timestamp in browser storage

---

## Quick Verification Commands

### Check Channel in Database:
```sql
SELECT 
  id, 
  name, 
  is_private, 
  created_by
FROM custom_channels
WHERE name = 'Quick Test Channel';
```

### Check Channel Members:
```sql
SELECT 
  cm.channel_id,
  cm.user_id,
  a.full_name
FROM channel_members cm
JOIN agents a ON a.id = cm.user_id
WHERE cm.channel_id = '5c90b542-fe65-4f83-aec7-0806f588a589';
```

### Check Recent Messages:
```sql
SELECT 
  id,
  channel,
  sender_id,
  sender_name,
  content,
  created_at
FROM chat_messages
WHERE channel = '5c90b542-fe65-4f83-aec7-0806f588a589'
ORDER BY created_at DESC
LIMIT 5;
```

---

## Browser Console Checks

### 1. Check Custom Channels Provider:
```javascript
// Open DevTools → Console
// Type:
window.__RIVERPOD__
// Look for customChannelsProvider state
```

### 2. Check Agents List Provider:
```javascript
// Look for agentsListProvider state
// Verify full_name field is populated
```

### 3. Check for Errors:
```javascript
// Filter console by "Error" or "error"
// Look for notification-related errors
```

---

## Expected Console Output (Normal)

### When notification fires:
```
✓ Custom channel notification received
✓ Channel ID: 5c90b542-fe65-4f83-aec7-0806f588a589
✓ Membership validated: true
✓ Showing notification for: Quick Test Channel
✓ Playing sound: ping / mentionPing
```

### If membership check fails:
```
⚠ Error processing custom channel notification: [error details]
✓ Fallback: Showing notification anyway
✓ Playing sound: ping
```

---

## Common Issues & Instant Fixes

### Issue 1: "Notification shows UUID"
**Instant Check:**
```dart
// In browser DevTools → Riverpod
// Check if customChannelsProvider.value contains the channel
```

**Quick Fix:**
- Refresh the page (channels may not be loaded yet)
- Check if channel exists in database

---

### Issue 2: "No notification appears"
**Instant Check:**
```javascript
// In browser console:
console.log('Current path:', window.location.pathname);
// Notification won't show if already on the channel page
```

**Quick Fix:**
- Navigate away from the channel page
- Check browser console for errors
- Verify Supabase realtime connection

---

### Issue 3: "No sound plays"
**Instant Check:**
```javascript
// In browser console:
ChatSoundService.playPing();
// Manually trigger sound
```

**Quick Fix:**
- Check browser audio permissions
- Turn up device volume
- Try in incognito mode (no extensions blocking audio)

---

### Issue 4: "Wrong sender name"
**Instant Check:**
```sql
SELECT id, full_name FROM agents WHERE id = 'sender-id-here';
```

**Quick Fix:**
- Verify `full_name` field is not empty in database
- Check if `agentsListProvider` is loaded
- Refresh the page

---

### Issue 5: "User C gets notification for private channel"
**Instant Check:**
```sql
SELECT * FROM channel_members 
WHERE channel_id = 'channel-id' AND user_id = 'user-c-id';
-- Should return 0 rows
```

**Quick Fix:**
- Verify channel `is_private = true`
- Check membership validation code is running (check console)
- User C should not be in `channel_members` table for this channel

---

## Performance Checks

### Notification Delay Test:
1. **User A:** Send message
2. **User B:** Start timer when sent
3. **User B:** Stop timer when notification appears

### ✅ Expected:
- **Public channels:** < 200ms
- **Private channels:** < 300ms (includes membership check)

### ❌ If Slower:
- Check network tab for slow queries
- Verify Supabase realtime is connected
- Check server load

---

## Success Criteria

After running all tests:
- ✅ Channel names display correctly (not UUIDs)
- ✅ Sender names display correctly (not IDs)
- ✅ Private channel security works (non-members don't get notifications)
- ✅ Sounds play for all notifications
- ✅ @Mention sound is different from regular sound
- ✅ Unread counter updates correctly
- ✅ No errors in browser console

---

## If Everything Passes

### Congratulations! 🎉

Your notification system is working correctly and ready for production.

**Next Steps:**
1. Monitor for 24 hours in production
2. Collect user feedback
3. Check error logs for any edge cases
4. Document any additional issues

---

## If Something Fails

### Don't Panic! 

1. Note which test failed
2. Check the "If Failed" section for that test
3. Run the database queries provided
4. Check browser console logs
5. Share error logs for debugging

---

## Emergency Rollback

If critical issues occur:

### Option 1: Disable Custom Channel Notifications
```dart
// In main_layout.dart, comment out:
// _setupCustomChannelListener(c);
```

### Option 2: Revert to Simple Mode
```dart
// In chat_toast_overlay.dart
// Replace channel name lookup with:
channelLabel = message.channel;  // Shows UUID but works

// Replace sender name lookup with:
senderName = message.senderName;  // May be empty but won't crash
```

---

## Test Completion Checklist

- [ ] Test 1: Channel name display - PASSED
- [ ] Test 2: Private channel security - PASSED
- [ ] Test 3: Sender name resolution - PASSED
- [ ] Test 4: @Mention sound - PASSED
- [ ] Test 5: Regular sound - PASSED
- [ ] Test 6: Unread counter - PASSED
- [ ] No errors in console
- [ ] Performance acceptable (<300ms)
- [ ] All users satisfied

---

**Total Test Time:** ~5 minutes  
**Critical Tests:** Tests 1, 2, 3 (must pass)  
**Nice-to-have Tests:** Tests 4, 5, 6 (should pass)

**Status:** Ready for Testing ✅
