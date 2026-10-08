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
        // Channel / Group Message: query eligible recipients with registered FCM tokens
        const { data: agents } = await supabase
          .from('agents')
          .select('id, fcm_token, full_name, username')
          .neq('id', senderId)
          .not('fcm_token', 'is', null)

        if (!agents || agents.length === 0) {
          console.log('No eligible agents with FCM tokens found.')
          return new Response(JSON.stringify({ success: true, count: 0 }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
          })
        }

        const channelStr = String(channel || '').trim()
        const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(channelStr)
        const msgPreview = content.startsWith('__CALL_') ? 'Started a call' : content

        // 1. Check if this is a custom channel / group chat
        let customChannel: any = null
        if (isUuid) {
          const { data } = await supabase
            .from('custom_channels')
            .select('id, name, created_by')
            .eq('id', channelStr)
            .maybeSingle()
          customChannel = data
        } else if (
          channelStr &&
          channelStr !== 'support-chat' &&
          channelStr !== 'all-aroundtally' &&
          channelStr !== 'sales-channel' &&
          channelStr !== 'sales-team' &&
          channelStr !== 'mobile-app-sales'
        ) {
          const { data } = await supabase
            .from('custom_channels')
            .select('id, name, created_by')
            .eq('name', channelStr)
            .maybeSingle()
          customChannel = data
        }

        if (customChannel) {
          // GROUP CHAT: Fetch all members for this channel
          const { data: memberRows } = await supabase
            .from('channel_members')
            .select('user_id')
            .eq('channel_id', customChannel.id)

          const groupMemberIds = new Set<string>()
          if (memberRows) {
            for (const m of memberRows) {
              if (m.user_id) groupMemberIds.add(m.user_id)
            }
          }
          if (customChannel.created_by) {
            groupMemberIds.add(customChannel.created_by)
          }

          // ONLY group members receive the notification
          const recipients = agents.filter((agent) => groupMemberIds.has(agent.id))
          const displayChannelName = customChannel.name || channelStr

          console.log(`Group chat "${displayChannelName}" (${customChannel.id}): ${groupMemberIds.size} members, ${recipients.length} eligible recipients with FCM tokens`)

          for (const agent of recipients) {
            if (agent.fcm_token) {
              messagesToSend.push({
                title: `#${displayChannelName} • ${senderName}`,
                body: msgPreview,
                data: {
                  type: 'channel',
                  channel: customChannel.id,
                  channel_name: displayChannelName,
                  link: `/c/${customChannel.id}`,
                },
                token: agent.fcm_token,
              })
            }
          }
        } else {
          // 2. Built-in or system channels
          const channelName = channelStr.toLowerCase()
          const salesMemberIds = new Set([
            '14db36db-0cb9-44ef-8032-d9610b3bc797',
            'b77b3738-4dfc-4515-a1fd-d6fb170423f4',
            'd8aa6435-9e02-4bab-9acc-ae1f5f3d6a1c',
            '5a06a8df-97f1-4dbf-bc13-9724a3c779c1',
            'd9572a84-762b-4c8b-8ef5-7da0345e3ea8',
            '0a5aeeb8-9544-4dc8-920f-e26c192b0dd3',
            'f3b54de6-0372-4648-ad87-3e98089efc2d',
            'f398fe3a-ea5f-4f98-9720-b3e32e798a63', // Vismaya
          ])

          const isMobileAppSales = channelName === 'mobile-app-sales'
          const isSalesChannel =
            channelName === 'sales-channel' ||
            channelName === 'sales-team' ||
            channelName.includes('sales')
          const messageBody = String(content || '')
          const isLeadNotice =
            messageBody.includes('🎯 New Lead') || messageBody.includes('[LeadID:')

          if (isMobileAppSales) {
            const isAllowedMobileSales = (name: string) => {
              const lower = (name || '').toLowerCase()
              return (
                lower.includes('parvathy') ||
                lower.includes('parvathi') ||
                lower.includes('anjali') ||
                lower.includes('sidharth') ||
                lower.includes('rinsiya') ||
                lower.includes('athira') ||
                lower.includes('vismaya') ||
                lower.includes('marketing ai')
              )
            }
            const recipients = agents.filter((agent) =>
              isAllowedMobileSales(agent.full_name || agent.username || '')
            )
            for (const agent of recipients) {
              if (agent.fcm_token) {
                messagesToSend.push({
                  title: `#Mobile-App-Sales • ${senderName}`,
                  body: msgPreview,
                  data: {
                    type: 'channel',
                    channel: 'mobile-app-sales',
                    link: '/mobile-app-sales',
                  },
                  token: agent.fcm_token,
                })
              }
            }
          } else if (isSalesChannel || isLeadNotice) {
            const recipients = agents.filter((agent) => salesMemberIds.has(agent.id))
            for (const agent of recipients) {
              if (agent.fcm_token) {
                messagesToSend.push({
                  title: `#${channelStr} • ${senderName}`,
                  body: msgPreview,
                  data: {
                    type: 'channel',
                    channel: channelStr,
                    link: '/sales-channel',
                  },
                  token: agent.fcm_token,
                })
              }
            }
          } else if (channelName === 'support-chat' || channelName === 'all-aroundtally') {
            // Public global company channels
            const link = channelName === 'all-aroundtally' ? '/channel/all-aroundtally' : '/chat'
            for (const agent of agents) {
              if (agent.fcm_token) {
                messagesToSend.push({
                  title: `#${channelStr} • ${senderName}`,
                  body: msgPreview,
                  data: {
                    type: 'channel',
                    channel: channelStr,
                    link: link,
                  },
                  token: agent.fcm_token,
                })
              }
            }
          } else {
            console.log(
              `Channel "${channelStr}" is not a recognized public channel and not found in custom_channels. Skipped broadcast to avoid notifying non-members.`
            )
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
