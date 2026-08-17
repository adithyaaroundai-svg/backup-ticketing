# 🔔 Notification System Flow Diagram

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         SUPABASE DATABASE                                │
│                      (chat_messages table)                               │
└────────────────────┬────────────────────────────────────────────────────┘
                     │
                     │ Realtime Subscription
                     │ (PostgreSQL Changes)
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      MAIN LAYOUT (main_layout.dart)                      │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │  _setupChatListener()                                          │     │
│  │  • Listens to support-chat channel                            │     │
│  │  • Listens to all-aroundtally channel                         │     │
│  │  • Filters by user ID and last-seen timestamp                 │     │
│  └────────────────────────────────────────────────────────────────┘     │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │  _setupCustomChannelListener()                                 │     │
│  │  • Single global subscription to chat_messages table          │     │
│  │  • Filters public channel messages                            │     │
│  │  • Excludes support-chat and all-aroundtally                  │     │
│  └────────────────────────────────────────────────────────────────┘     │
└──────────────────────────┬──────────────────────────────────────────────┘
                           │
                           │ Fires Events
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    CHAT PROVIDER (chat_provider.dart)                    │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │  DmConversationEngine._processMsgPayload()                     │     │
│  │  • Handles incoming DM messages                                │     │
│  │  • Checks if conversation is open                              │     │
│  │  • Fires dmNewMessageEventProvider.notify()                    │     │
│  └────────────────────────────────────────────────────────────────┘     │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Event Providers (Notifiers)                                    │    │
│  │  1. chatNewMessageEventProvider (support-chat)                  │    │
│  │  2. dmNewMessageEventProvider (direct messages)                 │    │
│  │  3. customChannelNewMessageEventProvider (custom channels)      │    │
│  │  4. allAroundTallyNewMessageEventProvider (all-aroundtally)     │    │
│  │                                                                  │    │
│  │  Each has:                                                       │    │
│  │  • notify(ChatMessage msg) - Triggers notification              │    │
│  │  • clear() - Dismisses notification                             │    │
│  │  • resetSession() - Clears on logout                            │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└──────────────────────────┬──────────────────────────────────────────────┘
                           │
                           │ State Changes
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│               CHAT TOAST OVERLAY (chat_toast_overlay.dart)               │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │  Watches all 4 event providers:                                │     │
│  │  • ref.watch(chatNewMessageEventProvider)                      │     │
│  │  • ref.watch(dmNewMessageEventProvider)                        │     │
│  │  • ref.watch(customChannelNewMessageEventProvider)             │     │
│  │  • ref.watch(allAroundTallyNewMessageEventProvider)            │     │
│  │                                                                 │     │
│  │  Priority Logic (highest to lowest):                           │     │
│  │  1. DM notifications                                            │     │
│  │  2. Custom channel notifications                               │     │
│  │  3. Support-chat notifications                                 │     │
│  │  4. All-AroundTally notifications                              │     │
│  │                                                                 │     │
│  │  Suppression Rules:                                             │     │
│  │  • Skip if on the same page as message source                  │     │
│  │  • Skip if conversation/channel is currently open              │     │
│  └────────────────────────────────────────────────────────────────┘     │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │  _ChatToast Widget                                             │     │
│  │  • Animated slide-up from bottom                               │     │
│  │  • Blue gradient with glassmorphism                            │     │
│  │  • User avatar + name + message preview                        │     │
│  │  • Channel badge (type + icon)                                 │     │
│  │  • Dismiss button (X)                                          │     │
│  │  • Auto-dismiss after 4 seconds                                │     │
│  │  • Click to navigate                                           │     │
│  └────────────────────────────────────────────────────────────────┘     │
└──────────────────────────┬──────────────────────────────────────────────┘
                           │
                           │ Parallel
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                 CHAT SOUND SERVICE (chat_sound_service.dart)             │
│  • playPing() - Standard notification sound                             │
│  • playMentionPing() - Special @mention sound                           │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Message Flow Example: Direct Message

```
┌────────────┐
│  User B    │ Sends DM: "Hello!"
└──────┬─────┘
       │
       ▼
┌────────────────────────────────────────────────┐
│  Supabase Database                             │
│  INSERT INTO chat_messages                     │
│  (sender_id: userB, receiver_id: userA, ...)   │
└──────────┬─────────────────────────────────────┘
           │
           │ Realtime Notification
           │
           ▼
┌───────────────────────────────────────────────────────┐
│  DmConversationEngine._handleMsgEvent()               │
│  → _processMsgPayload()                               │
│    • Validates: is incoming? conversation not open?   │
│    • Calls: dmNewMessageEventProvider.notify(msg)     │
│    • Calls: ChatSoundService.playPing()               │
└───────────┬───────────────────────────────────────────┘
            │
            │ State Update
            │
            ▼
┌──────────────────────────────────────────────┐
│  dmNewMessageEventProvider                   │
│  state = ChatMessage("Hello!")               │
└──────────┬───────────────────────────────────┘
           │
           │ Riverpod Notifies Listeners
           │
           ▼
┌─────────────────────────────────────────────────────┐
│  ChatToastOverlay.build()                           │
│  • Detects: dmNewMessage != null                    │
│  • Checks: not on /chat/dm/userB page               │
│  • Shows: _ChatToast widget with animation          │
└─────────────────────────────────────────────────────┘
           │
           │ User Interaction
           │
           ▼
┌─────────────────────────────────────────────────────┐
│  User A clicks notification                         │
│  → context.push('/chat/dm/userB')                   │
│  → dmNewMessageEventProvider.clear()                │
│                                                      │
│  OR                                                  │
│                                                      │
│  User A clicks X button                             │
│  → dmNewMessageEventProvider.clear()                │
│  → Notification dismisses without navigation        │
│                                                      │
│  OR                                                  │
│                                                      │
│  Auto-dismiss after 4 seconds                       │
│  → dmNewMessageEventProvider.clear()                │
└─────────────────────────────────────────────────────┘
```

---

## Suppression Logic Flow

```
┌────────────────────────────────┐
│  New Message Arrives           │
└────────────┬───────────────────┘
             │
             ▼
     ┌───────────────────┐
     │ Is sender == me?  │──Yes──> ❌ SUPPRESS (no notification)
     └────────┬──────────┘
              │ No
              ▼
     ┌──────────────────────────────────┐
     │ Is conversation/channel open?    │──Yes──> ❌ SUPPRESS
     └────────┬─────────────────────────┘
              │ No
              ▼
     ┌──────────────────────────────────┐
     │ Am I on the same page?           │──Yes──> ❌ SUPPRESS
     └────────┬─────────────────────────┘
              │ No
              ▼
     ┌──────────────────────────────────┐
     │ Already notified for this msg?   │──Yes──> ❌ SUPPRESS
     └────────┬─────────────────────────┘
              │ No
              ▼
     ┌──────────────────────────────────┐
     │ Message older than last-seen?    │──Yes──> ❌ SUPPRESS
     └────────┬─────────────────────────┘
              │ No
              ▼
        ✅ SHOW NOTIFICATION + PLAY SOUND
```

---

## Priority System

When multiple notifications are pending simultaneously:

```
┌─────────────────────────────────────┐
│  Multiple Events in State:          │
│  • dmNewMessage = Message A         │
│  • customChannelNewMessage = Msg B  │
│  • chatNewMessage = Message C       │
│  • aroundTallyNewMessage = Msg D    │
└────────────┬────────────────────────┘
             │
             ▼
    ┌─────────────────────┐
    │ Priority Check:     │
    │ 1. DM (highest)     │
    │ 2. Custom Channel   │
    │ 3. Support-Chat     │
    │ 4. AroundTally      │
    └────────┬────────────┘
             │
             ▼
    ┌──────────────────────────────┐
    │ Show ONLY Message A (DM)     │
    │ Other notifications wait     │
    │ or are replaced              │
    └──────────────────────────────┘
```

---

## Session Management

```
┌────────────────────┐
│  User Login        │
└────────┬───────────┘
         │
         ▼
┌──────────────────────────────────┐
│  Event Providers Initialize      │
│  _notifiedIds = {} (empty)       │
└────────┬─────────────────────────┘
         │
         │ User receives messages
         │ Notifications accumulate in _notifiedIds
         │
         ▼
┌──────────────────────────────────┐
│  User Logout                     │
│  auth_provider.dart calls:       │
│  • ChatNewMessageEvent           │
│    .resetSession()               │
│  • DmNewMessageEvent             │
│    .resetSession()               │
│  • CustomChannelNewMessageEvent  │
│    .resetSession()               │
│  • AllAroundTallyNewMessageEvent │
│    .resetSession()               │
└────────┬─────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│  All _notifiedIds cleared        │
│  Fresh state for next login      │
└──────────────────────────────────┘
```

---

## Error Handling

```
┌────────────────────────────────┐
│  Realtime Message Arrives      │
└────────┬───────────────────────┘
         │
         ▼
  ┌─────────────────────┐
  │ Try Parse Message   │
  └──────┬──────────────┘
         │
         ├──Success──> Continue to notification logic
         │
         └──Error────> ┌────────────────────────────────┐
                       │ debugPrint() error message     │
                       │ Skip this notification         │
                       │ App continues normally          │
                       └────────────────────────────────┘
```

---

## Component Locations

```
📁 ticketing_host_new/
├── 📁 lib/
│   ├── 📁 core/
│   │   ├── 📁 design_system/
│   │   │   └── 📁 layout/
│   │   │       └── 📄 main_layout.dart
│   │   │           • _setupChatListener()
│   │   │           • _setupCustomChannelListener()
│   │   │
│   │   └── 📁 services/
│   │       └── 📄 chat_sound_service.dart
│   │           • playPing()
│   │           • playMentionPing()
│   │
│   └── 📁 features/
│       ├── 📁 auth/
│       │   └── 📁 presentation/
│       │       └── 📁 providers/
│       │           └── 📄 auth_provider.dart
│       │               • Calls resetSession() on logout
│       │
│       └── 📁 chat/
│           └── 📁 presentation/
│               ├── 📁 providers/
│               │   └── 📄 chat_provider.dart
│               │       • DmConversationEngine
│               │       • Event Providers (4 types)
│               │
│               └── 📁 widgets/
│                   └── 📄 chat_toast_overlay.dart
│                       • UI rendering
│                       • Priority logic
│                       • Navigation
```

---

## 🎯 Key Takeaways

1. **Single Source of Truth**: Supabase realtime is the only source of new messages
2. **Event-Driven**: All notifications flow through Riverpod state providers
3. **Smart Suppression**: Multiple layers prevent unwanted notifications
4. **Priority-Based**: Only one notification shown at a time, intelligently prioritized
5. **Session-Safe**: Clean state reset on logout prevents stale notifications
6. **Error-Tolerant**: Parse failures don't crash the app
7. **Performance-Optimized**: Minimal re-renders, efficient subscriptions

---

**Status:** ✅ System Architecture Complete & Verified
