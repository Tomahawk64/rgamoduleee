import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const encoder = new TextEncoder();
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function hex(buffer: ArrayBuffer): string {
  return [...new Uint8Array(buffer)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function hmac(key: ArrayBuffer | Uint8Array, value: string): Promise<ArrayBuffer> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    key,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return crypto.subtle.sign("HMAC", cryptoKey, encoder.encode(value));
}

async function sha256(value: string): Promise<string> {
  return hex(await crypto.subtle.digest("SHA-256", encoder.encode(value)));
}

function amzDate(now: Date): { stamp: string; short: string } {
  const iso = now.toISOString().replace(/[:-]|\.\d{3}/g, "");
  return { stamp: iso, short: iso.slice(0, 8) };
}

function encodePathPart(value: string): string {
  return encodeURIComponent(value).replace(/[!'()*]/g, (c) =>
    `%${c.charCodeAt(0).toString(16).toUpperCase()}`
  );
}

async function presignUrl(params: {
  method: "PUT" | "GET";
  endpoint: string;
  bucket: string;
  key: string;
  accessKeyId: string;
  secretAccessKey: string;
  contentType?: string;
  expiresSeconds: number;
}): Promise<string> {
  const now = new Date();
  const { stamp, short } = amzDate(now);
  const region = "auto";
  const service = "s3";
  const credentialScope = `${short}/${region}/${service}/aws4_request`;
  const host = new URL(params.endpoint).host;
  const canonicalUri = `/${params.bucket}/${params.key.split("/").map(encodePathPart).join("/")}`;
  const query = new URLSearchParams({
    "X-Amz-Algorithm": "AWS4-HMAC-SHA256",
    "X-Amz-Credential": `${params.accessKeyId}/${credentialScope}`,
    "X-Amz-Date": stamp,
    "X-Amz-Expires": String(params.expiresSeconds),
    "X-Amz-SignedHeaders": "host",
  });
  query.sort();
  const canonicalRequest = [
    params.method,
    canonicalUri,
    query.toString(),
    `host:${host}\n`,
    "host",
    "UNSIGNED-PAYLOAD",
  ].join("\n");
  const stringToSign = [
    "AWS4-HMAC-SHA256",
    stamp,
    credentialScope,
    await sha256(canonicalRequest),
  ].join("\n");
  const kDate = await hmac(encoder.encode(`AWS4${params.secretAccessKey}`), short);
  const kRegion = await hmac(kDate, region);
  const kService = await hmac(kRegion, service);
  const kSigning = await hmac(kService, "aws4_request");
  const signature = hex(await hmac(kSigning, stringToSign));
  query.set("X-Amz-Signature", signature);
  return `${params.endpoint}${canonicalUri}?${query.toString()}`;
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const authorization = req.headers.get("Authorization") ?? "";
    const authClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authorization } },
    });
    const { data: authData, error: authError } = await authClient.auth.getUser();
    if (authError || !authData.user) return json({ error: "Unauthorized" }, 401);

    const { folder, fileName, contentType, sizeBytes } = await req.json();
    if (!folder || !fileName || !contentType || typeof sizeBytes !== "number") {
      return json({ error: "Invalid upload request" }, 400);
    }
    if (sizeBytes > 314_572_800) {
      return json({ error: "File too large" }, 413);
    }

    const folderParts = String(folder).split("/");
    const uploadArea = folderParts[0];
    const resourceId = folderParts[1];
    if (!resourceId || !UUID_RE.test(resourceId) || !["chat", "proofs"].includes(uploadArea)) {
      return json({ error: "Invalid upload folder" }, 400);
    }
    if (uploadArea === "chat") {
      if (!["image/jpeg", "image/png", "image/webp"].includes(contentType)) {
        return json({ error: "Unsupported chat image type" }, 400);
      }
      const { data: session } = await authClient
        .from("chat_sessions")
        .select("id")
        .eq("id", resourceId)
        .maybeSingle();
      if (!session) return json({ error: "Chat session access denied" }, 403);
    }
    if (uploadArea === "proofs") {
      if (contentType !== "video/mp4") return json({ error: "Proof video must be MP4" }, 400);
      const { data: profile } = await authClient
        .from("profiles")
        .select("role")
        .eq("id", authData.user.id)
        .single();
      if (profile?.role !== "admin") return json({ error: "Proof uploads require admin access" }, 403);
    }

    const accountId = Deno.env.get("R2_ACCOUNT_ID");
    const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID");
    const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY");
    const bucket = Deno.env.get("R2_BUCKET");
    const publicBaseUrl = Deno.env.get("R2_PUBLIC_BASE_URL");
    if (!accountId || !accessKeyId || !secretAccessKey || !bucket) {
      return json({ error: "Cloudflare R2 is not configured" }, 500);
    }

    const safeName = String(fileName).replace(/[^a-zA-Z0-9._-]/g, "_");
    const key = `${uploadArea}/${resourceId}/${authData.user.id}/${crypto.randomUUID()}-${safeName}`;
    const endpoint = `https://${accountId}.r2.cloudflarestorage.com`;
    const uploadUrl = await presignUrl({
      method: "PUT",
      endpoint,
      bucket,
      key,
      accessKeyId,
      secretAccessKey,
      contentType,
      expiresSeconds: 900,
    });
    const downloadUrl = await presignUrl({
      method: "GET",
      endpoint,
      bucket,
      key,
      accessKeyId,
      secretAccessKey,
      expiresSeconds: 604800,
    });

    return json({
      uploadUrl,
      downloadUrl,
      publicUrl: publicBaseUrl ? `${publicBaseUrl.replace(/\/$/, "")}/${key}` : null,
      storageKey: key,
    });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Unknown error" }, 500);
  }
});
