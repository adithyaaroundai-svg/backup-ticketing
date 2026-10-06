import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const PIXEL_ID = Deno.env.get("META_PIXEL_ID") || "1694453372040389";
const TOKEN = Deno.env.get("META_CAPI_TOKEN") || Deno.env.get("METACAPITOKEN");
const WEBHOOK_SECRET = Deno.env.get("WEBHOOK_SECRET") || Deno.env.get("WEBHOOKSECRET");
const TEST_CODE = Deno.env.get("META_TEST_EVENT_CODE") || Deno.env.get("METATESTEVENTCODE");

// Status to Meta Event mapping
const EVENTS: Record<string, string> = {
  contacted: "Contact",
  qualified: "Qualified",
  negotiation: "Negotiation",
  won: "Won",
  win: "Won",
};

async function sha256(s: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function normalizePhone(p: string | null | undefined): string {
  let d = (p ?? "").replace(/\D/g, "").replace(/^0+/, "");
  if (d.length === 10) d = "91" + d;
  return d;
}

serve(async (req) => {
  // CORS / Options check
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-webhook-secret",
      },
    });
  }

  // Security verification
  if (WEBHOOK_SECRET) {
    const incomingSecret = req.headers.get("x-webhook-secret");
    if (incomingSecret !== WEBHOOK_SECRET) {
      console.warn("Unauthorized webhook call: header secret mismatch");
      return new Response(JSON.stringify({ error: "unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }
  }

  if (!TOKEN) {
    console.error("Missing META_CAPI_TOKEN environment variable");
    return new Response(JSON.stringify({ error: "Missing META_CAPI_TOKEN" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const payload = await req.json();
    const { type, record, old_record } = payload;

    // 1. Strictly ignore INSERT/DELETE - only trigger on UPDATE
    if (type !== "UPDATE" || !record) {
      return new Response(JSON.stringify({ message: "Ignored: not an UPDATE" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 2. Check pipeline type if specified (mobile-app-sales)
    const pipelineType = String(record.pipeline_type ?? "").toLowerCase().trim();
    if (pipelineType && pipelineType !== "mobile-app-sales") {
      return new Response(JSON.stringify({ message: `Ignored: pipeline is ${pipelineType}` }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 3. Status change check
    const newStatus = String(record.status ?? "").toLowerCase().trim();
    const oldStatus = String(old_record?.status ?? "").toLowerCase().trim();

    if (!newStatus || newStatus === oldStatus) {
      return new Response(JSON.stringify({ message: "Ignored: status unchanged" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const eventName = EVENTS[newStatus];
    if (!eventName) {
      return new Response(JSON.stringify({ message: `Ignored: status '${newStatus}' not mapped to an event` }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 4. Phone normalization and hashing (handles phone_number or phone)
    const rawPhone = record.phone_number || record.phone || "";
    const phone = normalizePhone(rawPhone);
    if (!phone) {
      console.warn(`Lead ${record.id} has no valid phone number`);
      return new Response(JSON.stringify({ message: "Ignored: no valid phone number" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const hashedPhone = await sha256(phone);

    // 5. Build user_data
    const userData: Record<string, unknown> = {
      ph: [hashedPhone],
    };

    // First name hash if customer_name exists
    if (record.customer_name) {
      const firstName = String(record.customer_name).trim().toLowerCase().split(/\s+/)[0];
      if (firstName) {
        userData.fn = [await sha256(firstName)];
      }
    }

    // WhatsApp referral ctwaclid if present
    if (record.ctwaclid) {
      userData.ctwaclid = record.ctwaclid;
    }

    // 6. Build custom_data
    const customData: Record<string, unknown> = {
      event_source: "crm",
      lead_event_source: "TallyCare",
      sales_channel: record.pipeline_type || "mobile-app-sales",
      lead_status: eventName,
      lead_id: String(record.id),
      source: record.source || "WhatsApp Ads",
    };

    // If deal won, attach amount in INR
    if (eventName === "Won" || newStatus === "won" || newStatus === "win") {
      const dealAmount = Number(record.amount ?? 0);
      if (dealAmount > 0) {
        customData.value = dealAmount;
        customData.currency = "INR";
      }
    }

    // 7. Assemble Meta CAPI Event
    const eventTime = Math.floor(Date.now() / 1000);
    const eventId = `${record.id}_${eventName.toLowerCase()}`;

    const eventData: Record<string, unknown> = {
      event_name: eventName,
      event_time: eventTime,
      action_source: "system_generated",
      event_id: eventId, // Deduplication
      user_data: userData,
      custom_data: customData,
    };

    const requestBody: Record<string, unknown> = {
      data: [eventData],
    };

    if (TEST_CODE) {
      requestBody.test_event_code = TEST_CODE;
    }

    console.log(`Sending Meta CAPI event: ${eventName} for Lead ID: ${record.id} (Phone: 91...${phone.slice(-4)})`);

    const metaUrl = `https://graph.facebook.com/v21.0/${PIXEL_ID}/events?access_token=${TOKEN}`;
    const metaRes = await fetch(metaUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(requestBody),
    });

    const metaResultText = await metaRes.text();
    console.log(`Meta response [${metaRes.status}]:`, metaResultText);

    return new Response(metaResultText, {
      status: metaRes.status,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err: any) {
    console.error("Error processing Meta CAPI webhook:", err);
    return new Response(JSON.stringify({ error: err.message || "Internal server error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
