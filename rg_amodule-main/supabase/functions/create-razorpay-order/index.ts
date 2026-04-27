// supabase/functions/create-razorpay-order/index.ts
// Creates a Razorpay order on the backend
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function isUuid(value: unknown): value is string {
  return typeof value === "string" && UUID_RE.test(value);
}

serve(async (req) => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const {
      amount_paise,
      customer_id,
      description,
      metadata,
    } = await req.json();

    // Razorpay credentials must be provided via function secrets.
    const RAZORPAY_KEY_ID = Deno.env.get("RAZORPAY_KEY_ID");
    const RAZORPAY_KEY_SECRET = Deno.env.get("RAZORPAY_KEY_SECRET");
    if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
      return new Response(
        JSON.stringify({ error: "Razorpay credentials are not configured" }),
        { status: 500, headers: corsHeaders },
      );
    }

    // Create basic auth header for Razorpay API
    const auth = btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`);

    // Create order via Razorpay API
    const razorpayResponse = await fetch("https://api.razorpay.com/v1/orders", {
      method: "POST",
      headers: {
        "Authorization": `Basic ${auth}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        amount: amount_paise,
        currency: "INR",
        receipt: (metadata?.app_order_id ?? customer_id ?? "app").toString().slice(0, 40),
        notes: metadata || {},
      }),
    });

    if (!razorpayResponse.ok) {
      const error = await razorpayResponse.text();
      console.error("Razorpay API error:", error);
      return new Response(
        JSON.stringify({ error: "Failed to create Razorpay order" }),
        { status: 400, headers: corsHeaders }
      );
    }

    const razorpayData = await razorpayResponse.json();

    // Store order in database for audit trail
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const appOrderId = metadata?.app_order_id;
    const payload: Record<string, unknown> = {
      transaction_type: "order",
      razorpay_order_id: razorpayData.id,
      amount_paise: amount_paise,
      payment_status: "initiated",
      razorpay_response: {
        ...razorpayData,
        app_order_id: appOrderId,
        description,
      },
    };

    if (isUuid(customer_id)) {
      payload.user_id = customer_id;
    }

    if (isUuid(appOrderId)) {
      payload.order_id = appOrderId;
    }

    const { error: dbError } = await supabase.from("payment_logs").insert(payload);

    if (dbError) {
      console.error("Database error:", dbError);
    }

    return new Response(
      JSON.stringify({
        order_id: razorpayData.id,
        amount_paise: amount_paise,
        currency: "INR",
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  } catch (error) {
    console.error("Error creating Razorpay order:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  }
});
