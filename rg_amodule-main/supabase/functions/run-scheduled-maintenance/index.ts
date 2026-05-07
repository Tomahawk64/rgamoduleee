import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.1";

serve(async (req) => {
  const expectedToken = Deno.env.get("MAINTENANCE_TOKEN");
  if (expectedToken && req.headers.get("x-maintenance-token") !== expectedToken) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  await supabase.rpc("expire_old_chat_sessions");

  const soon = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
  const now = new Date().toISOString();
  const { data: expiring } = await supabase
    .from("proof_videos")
    .select("id,user_id,booking_id,expires_at")
    .gt("expires_at", now)
    .lte("expires_at", soon);

  if (expiring?.length) {
    await supabase.from("notifications").insert(
      expiring.map((proof) => ({
        user_id: proof.user_id,
        title: "Proof video expiring soon",
        body: "Your special pooja proof video expires within 24 hours.",
        data: { booking_id: proof.booking_id, proof_id: proof.id },
      })),
    );
  }

  return new Response(JSON.stringify({ ok: true, expiring: expiring?.length ?? 0 }), {
    headers: { "Content-Type": "application/json" },
  });
});
