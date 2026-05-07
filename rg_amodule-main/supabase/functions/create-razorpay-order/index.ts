import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function isUuid(value: unknown): value is string {
  return typeof value === "string" && UUID_RE.test(value);
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const authorization = req.headers.get("Authorization") ?? "";

    const authClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authorization } },
    });
    const { data: authData, error: authError } = await authClient.auth.getUser();
    if (authError || !authData.user) return json({ error: "Unauthorized" }, 401);

    const { amount_paise, customer_id, description, metadata } = await req.json();
    if (!Number.isInteger(amount_paise) || amount_paise < 100 || amount_paise > 10_000_000) {
      return json({ error: "Invalid payment amount" }, 400);
    }
    if (customer_id && customer_id !== authData.user.id) {
      return json({ error: "Customer mismatch" }, 403);
    }

    const razorpayKeyId = Deno.env.get("RAZORPAY_KEY_ID");
    const razorpayKeySecret = Deno.env.get("RAZORPAY_KEY_SECRET");
    if (!razorpayKeyId || !razorpayKeySecret) {
      return json({ error: "Razorpay credentials are not configured" }, 500);
    }

    const appOrderId = metadata?.app_order_id;
    const receipt = (isUuid(appOrderId) ? appOrderId : authData.user.id).slice(0, 40);
    const razorpayResponse = await fetch("https://api.razorpay.com/v1/orders", {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${razorpayKeyId}:${razorpayKeySecret}`)}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        amount: amount_paise,
        currency: "INR",
        receipt,
        notes: {
          app_order_id: isUuid(appOrderId) ? appOrderId : undefined,
          user_id: authData.user.id,
          description: typeof description === "string" ? description.slice(0, 200) : undefined,
        },
      }),
    });

    if (!razorpayResponse.ok) {
      console.error("Razorpay API error:", await razorpayResponse.text());
      return json({ error: "Failed to create Razorpay order" }, 400);
    }

    const razorpayData = await razorpayResponse.json();
    if (serviceRoleKey) {
      const serviceClient = createClient(supabaseUrl, serviceRoleKey);
      const { error: dbError } = await serviceClient.from("payment_logs").insert({
        transaction_type: "order",
        razorpay_order_id: razorpayData.id,
        amount_paise,
        payment_status: "initiated",
        user_id: authData.user.id,
        order_id: isUuid(appOrderId) ? appOrderId : null,
        razorpay_response: { ...razorpayData, description },
      });
      if (dbError) console.error("Payment log insert failed:", dbError);
    }

    return json({
      order_id: razorpayData.id,
      amount_paise,
      currency: "INR",
    });
  } catch (error) {
    console.error("Error creating Razorpay order:", error);
    return json({ error: error instanceof Error ? error.message : "Unknown error" }, 500);
  }
});
