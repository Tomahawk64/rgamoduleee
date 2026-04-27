// supabase/functions/verify-razorpay-payment/index.ts
// Server-side verification of Razorpay payment signature

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const RAZORPAY_KEY_ID = Deno.env.get("RAZORPAY_KEY_ID") ?? "";
const RAZORPAY_KEY_SECRET = Deno.env.get("RAZORPAY_KEY_SECRET") ?? "";

async function verifyRazorpaySignature(
  razorpayOrderId: string,
  paymentId: string,
  signature: string,
): Promise<boolean> {
  try {
    const message = `${razorpayOrderId}|${paymentId}`;
    const key = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(RAZORPAY_KEY_SECRET),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"],
    );
    const signatureBytes = await crypto.subtle.sign(
      "HMAC",
      key,
      new TextEncoder().encode(message),
    );
    const computedSignature = Array.from(new Uint8Array(signatureBytes))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");
    return computedSignature === signature;
  } catch (error) {
    console.error("Signature verification error:", error);
    return false;
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
      return new Response(
        JSON.stringify({ error: "Razorpay credentials are not configured", verified: false }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const { order_id, payment_id, signature, app_order_id } = await req.json();

    if (!order_id || !payment_id || !signature) {
      return new Response(
        JSON.stringify({ error: "Missing required fields", verified: false }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const signatureValid = await verifyRazorpaySignature(
      order_id,
      payment_id,
      signature,
    );

    if (!signatureValid) {
      await supabase
        .from("payment_logs")
        .update({
          payment_status: "failed",
          razorpay_error: {
            message: "Signature verification failed",
            timestamp: new Date().toISOString(),
          },
        })
        .eq("razorpay_order_id", order_id);

      return new Response(
        JSON.stringify({
          verified: false,
          error: "Signature verification failed",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const auth = btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`);
    const paymentDetailsResponse = await fetch(
      `https://api.razorpay.com/v1/payments/${payment_id}`,
      {
        method: "GET",
        headers: {
          Authorization: `Basic ${auth}`,
          "Content-Type": "application/json",
        },
      },
    );

    if (!paymentDetailsResponse.ok) {
      return new Response(
        JSON.stringify({
          verified: false,
          error: "Failed to fetch payment details",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const paymentDetails = await paymentDetailsResponse.json();
    if (paymentDetails.status !== "captured") {
      return new Response(
        JSON.stringify({
          verified: false,
          error: `Payment status is ${paymentDetails.status}`,
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    let appOrderId: string | null =
      typeof app_order_id === "string" ? app_order_id : null;

    if (!appOrderId) {
      const { data: paymentLog } = await supabase
        .from("payment_logs")
        .select("order_id,razorpay_response")
        .eq("razorpay_order_id", order_id)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      if (paymentLog?.order_id) {
        appOrderId = paymentLog.order_id as string;
      } else if (
        paymentLog?.razorpay_response &&
        typeof paymentLog.razorpay_response === "object" &&
        "app_order_id" in paymentLog.razorpay_response
      ) {
        const candidate = (paymentLog.razorpay_response as Record<string, unknown>)
          .app_order_id;
        if (typeof candidate === "string" && candidate.length > 0) {
          appOrderId = candidate;
        }
      }
    }

    let updatedEntityType: "order" | "booking" | null = null;

    if (appOrderId) {
      const { data: orderData } = await supabase
        .from("orders")
        .update({
          payment_status: "completed",
          razorpay_order_id: order_id,
          razorpay_payment_id: payment_id,
          razorpay_signature: signature,
          payment_metadata: paymentDetails,
          payment_completed_at: new Date().toISOString(),
          status: "confirmed",
        })
        .eq("id", appOrderId)
        .select("id")
        .maybeSingle();

      if (orderData?.id) {
        updatedEntityType = "order";
      }
    }

    if (!updatedEntityType && appOrderId) {
      const { data: bookingData } = await supabase
        .from("bookings")
        .update({
          is_paid: true,
          payment_id: payment_id,
          razorpay_order_id: order_id,
          razorpay_payment_id: payment_id,
          razorpay_signature: signature,
          payment_metadata: paymentDetails,
          payment_status: "completed",
          payment_completed_at: new Date().toISOString(),
          status: "confirmed",
        })
        .eq("id", appOrderId)
        .select("id")
        .maybeSingle();

      if (bookingData?.id) {
        updatedEntityType = "booking";
      }
    }

    await supabase
      .from("payment_logs")
      .update({
        payment_status: "completed",
        razorpay_payment_id: payment_id,
        razorpay_response: paymentDetails,
        completed_at: new Date().toISOString(),
      })
      .eq("razorpay_order_id", order_id);

    const admins = await supabase
      .from("profiles")
      .select("id")
      .eq("role", "admin");

    if (admins.data && admins.data.length > 0) {
      const notifications = admins.data.map((admin) => ({
        user_id: admin.id,
        type: "payment_completed",
        title: "Payment Received",
        message: `Payment of Rs.${(paymentDetails.amount / 100).toFixed(2)} received`,
        data: {
          order_id: appOrderId,
          razorpay_order_id: order_id,
          entity_type: updatedEntityType,
          payment_id,
          amount_paise: paymentDetails.amount,
        },
        read: false,
      }));

      await supabase.from("notifications").insert(notifications);
    }

    if (!updatedEntityType) {
      return new Response(
        JSON.stringify({
          verified: true,
          warning: "Payment verified but no matching order/booking found",
          razorpay_order_id: order_id,
          payment_id,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    return new Response(
      JSON.stringify({
        verified: true,
        order_id: appOrderId,
        razorpay_order_id: order_id,
        entity_type: updatedEntityType,
        payment_id,
        amount_rupees: (paymentDetails.amount / 100).toFixed(2),
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    console.error("Error verifying payment:", error);
    return new Response(
      JSON.stringify({ error: error.message, verified: false }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  }
});
