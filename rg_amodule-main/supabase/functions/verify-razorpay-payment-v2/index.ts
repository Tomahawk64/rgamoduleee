import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

async function hmacHex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function timingSafeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let diff = 0;
  for (let index = 0; index < left.length; index += 1) {
    diff |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return diff === 0;
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed", verified: false }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const authorization = req.headers.get("Authorization") ?? "";

    const authClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authorization } },
    });
    const { data: authData, error: authError } = await authClient.auth.getUser();
    if (authError || !authData.user) return json({ error: "Unauthorized", verified: false }, 401);

    const { razorpay_order_id, razorpay_payment_id, razorpay_signature, app_payment_id } =
      await req.json();
    if (
      !isNonEmptyString(razorpay_order_id) ||
      !isNonEmptyString(razorpay_payment_id) ||
      !isNonEmptyString(razorpay_signature)
    ) {
      return json({ error: "Invalid verification payload", verified: false }, 400);
    }

    const secret = Deno.env.get("RAZORPAY_KEY_SECRET");
    if (!secret) return json({ error: "Razorpay secret not configured", verified: false }, 500);

    const expected = await hmacHex(secret, `${razorpay_order_id}|${razorpay_payment_id}`);
    const verified = timingSafeEqual(expected, razorpay_signature);

    if (app_payment_id && UUID_RE.test(app_payment_id) && serviceRoleKey) {
      const serviceClient = createClient(supabaseUrl, serviceRoleKey);
      await serviceClient
        .from("payments")
        .update({
          status: verified ? "captured" : "failed",
          razorpay_order_id,
          razorpay_payment_id,
          razorpay_signature,
          raw_payload: { verified, verified_at: new Date().toISOString() },
        })
        .eq("id", app_payment_id)
        .eq("user_id", authData.user.id);
    }

    return json({ verified });
  } catch (error) {
    return json(
      { error: error instanceof Error ? error.message : "Unknown error", verified: false },
      500,
    );
  }
});
