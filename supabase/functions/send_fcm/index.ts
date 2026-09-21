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
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    )

    // 1. Initialize Firebase Admin if it's not already initialized
    if (getApps().length === 0) {
      // You MUST store your Firebase Service Account JSON string in Supabase Secrets
      // run: supabase secrets set FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}'
      const serviceAccountStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
      if (!serviceAccountStr) {
        throw new Error('FIREBASE_SERVICE_ACCOUNT secret is missing')
      }
      const serviceAccount = JSON.parse(serviceAccountStr)
      initializeApp({
        credential: cert(serviceAccount),
      })
    }

    // 2. Parse the Webhook payload from Postgres Trigger
    const payload = await req.json()
    const record = payload.record // The new row in the `notifications` table

    if (!record || !record.user_id) {
      throw new Error('Invalid payload: missing record or user_id')
    }

    // 3. Fetch the fcm_token for the recipient from the agents table
    const { data: agentData, error: agentError } = await supabase
      .from('agents')
      .select('fcm_token')
      .eq('id', record.user_id)
      .single()

    if (agentError) {
      throw new Error(`Error fetching agent: ${agentError.message}`)
    }

    const fcmToken = agentData?.fcm_token

    if (!fcmToken) {
      console.log(`No FCM token found for agent ${record.user_id}. Skipping notification.`)
      return new Response(JSON.stringify({ success: true, message: 'No FCM token' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    // 4. Construct the notification
    const message = {
      notification: {
        title: record.title || 'New Notification',
        body: record.message || 'You have a new update in TallyCare',
      },
      data: {
        type: record.type || 'system',
        link: record.link || '',
        notification_id: record.id || '',
      },
      token: fcmToken,
    }

    // 5. Send the notification via Firebase
    const response = await getMessaging().send(message)
    console.log('Successfully sent message:', response)

    return new Response(JSON.stringify({ success: true, response }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('Error sending push notification:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
