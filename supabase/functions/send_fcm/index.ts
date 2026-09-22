import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// We use the Firebase Admin SDK from npm to easily send FCM messages
import { initializeApp, cert, getApps } from "npm:firebase-admin/app"
import { getMessaging } from "npm:firebase-admin/messaging"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Use SERVICE_ROLE_KEY so Edge Function can read agent FCM tokens and channel memberships bypassing RLS
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    )

    // 1. Initialize Firebase Admin if not already initialized
    if (getApps().length === 0) {
      const serviceAccountStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
      if (!serviceAccountStr) {
        throw new Error('FIREBASE_SERVICE_ACCOUNT secret is not configured in Supabase Edge Functions')
      }
      const credentials = typeof serviceAccountStr === 'string' 
        ? JSON.parse(serviceAccountStr) 
        : serviceAccountStr
      initializeApp({
        credential: cert(credentials),
      })
    }

    // 2. Parse the Webhook payload from Postgres Trigger
    const payload = await req.json()
    const record = payload.record
    const tableName = payload.table || 'notifications'

    if (!record) {
      throw new Error('Invalid payload: missing record')
    }

    const messagesToSend: any[] = []

    // ── CASE A: Chat Message (DM or Channel) ───────────────────────────
    if (tableName === 'chat_messages') {
      const senderId = record.sender_id
      const senderName = record.sender_name || 'Someone'
      const content = record.content || 'Sent a message'
      const receiverId = record.receiver_id
      const channel = record.channel || 'support-chat'

      // Direct Message
      if (receiverId) {
        const { data: receiverData } = await supabase
          .from('agents')
          .select('fcm_token')
          .eq('id', receiverId)
          .single()

        if (receiverData?.fcm_token) {
          messagesToSend.push({
            title: senderName,
            body: content,
            data: {
              type: 'dm',
              partner_id: senderId,
              link: `/chat/dm/${senderId}`,
            },
            token: receiverData.fcm_token,
          })
        }
      } else {
        // Channel message: send to users with registered tokens (excluding sender)
        const { data: agents } = await supabase
          .from('agents')
          .select('id, fcm_token')
          .neq('id', senderId)
          .not('fcm_token', 'is', null)

        if (agents && agents.length > 0) {
          for (const agent of agents) {
            if (agent.fcm_token) {
              messagesToSend.push({
                title: `#${channel} • ${senderName}`,
                body: content,
                data: {
                  type: 'channel',
                  channel: channel,
                  link: `/chat`,
                },
                token: agent.fcm_token,
              })
            }
          }
        }
      }
    } 
    // ── CASE B: System Notification ────────────────────────────────────
    else {
      const recipientId = record.user_id
      if (!recipientId) {
        throw new Error('Missing record.user_id')
      }

      const { data: agentData } = await supabase
        .from('agents')
        .select('fcm_token')
        .eq('id', recipientId)
        .single()

      if (agentData?.fcm_token) {
        messagesToSend.push({
          title: record.title || 'New Notification',
          body: record.message || 'You have a new update in TallyCare',
          data: {
            type: record.type || 'system',
            link: record.link || '',
            notification_id: record.id || '',
          },
          token: agentData.fcm_token,
        })
      }
    }

    if (messagesToSend.length === 0) {
      console.log('No eligible FCM tokens found to deliver push notification.')
      return new Response(JSON.stringify({ success: true, count: 0 }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    // Send messages with high priority for heads-up and lock screen delivery
    let sentCount = 0
    for (const item of messagesToSend) {
      try {
        await getMessaging().send({
          notification: {
            title: item.title,
            body: item.body,
          },
          data: {
            ...item.data,
            title: item.title,
            body: item.body,
          },
          android: {
            priority: 'high',
            notification: {
              channelId: 'tallycare_high_importance_channel',
              sound: 'default',
              priority: 'max',
              defaultVibrateTimings: true,
              defaultSound: true,
              visibility: 'public',
            },
          },
          apns: {
            payload: {
              aps: {
                alert: {
                  title: item.title,
                  body: item.body,
                },
                sound: 'default',
                badge: 1,
                contentAvailable: true,
              },
            },
          },
          token: item.token,
        })
        sentCount++
      } catch (err) {
        console.error(`Error sending message to token ${item.token.substring(0, 10)}...:`, err)
      }
    }

    console.log(`Successfully sent ${sentCount}/${messagesToSend.length} push notifications`)

    return new Response(JSON.stringify({ success: true, sentCount }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error: any) {
    console.error('Error sending push notification:', error)
    return new Response(JSON.stringify({ error: error?.message || error }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
