// Supabase Edge Function — Admin API (SERVICE ROLE)
// Semua aksi dilakukan dengan service_role; caller diverifikasi menjadi admin/superadmin.
// Panggil via: supabase.functions.invoke('admin-api', {body: {action, ...payload}})
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ALLOWED_ORIGIN = Deno.env.get("ALLOWED_ORIGIN") ?? "*";

const corsHeaders = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Headers": "authorization, content-type",
};

const client = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });

  // Verify JWT user
  const auth = req.headers.get("Authorization") ?? "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
  if (!token) return jsonError("Unauthorized: no token", 401);

  const { data: { user }, error: userErr } = await client.auth.getUser(token);
  if (userErr || !user) return jsonError("Unauthorized: invalid token", 401);

  // Check admin/superadmin role
  const { data: profile, error: profileErr } = await client
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single();

  if (profileErr || !profile || !(profile["role"] === "admin" || profile["role"] === "superadmin")) {
    return jsonError("Forbidden: admin access required", 403);
  }

  const actorId = user.id; // admin yang melakukan aksi (dicatat di request_handled_by)

  // Parse body
  const body = await req.json().catch(() => null) as { action: string; [key: string]: unknown } | null;
  if (!body?.action) return jsonError("Missing 'action' in request body", 400);

  try {
    switch (body.action) {
      case "owner_approve":
        await handleOwnerApprove(String(body.user_id), actorId);
        break;
      case "owner_reject":
        await handleOwnerReject(String(body.user_id), String(body.reason ?? ""), actorId);
        break;
      case "set_role":
        await handleSetRole(String(body.user_id), String(body.role), actorId);
        break;
      case "set_status":
        await handleSetStatus(String(body.user_id), String(body.status), actorId);
        break;
      case "place_verify":
        await handlePlaceVerify(body.place_id as number | string, actorId);
        break;
      case "place_reject":
        await handlePlaceReject(body.place_id as number | string, String(body.reason ?? ""), actorId);
        break;
      case "place_feature":
        await handlePlaceFeature(body.place_id as number | string, Boolean(body.is_featured));
        break;
      case "reviews_delete_by_user":
        await handleReviewsDeleteByUser(String(body.user_id));
        break;
      case "delete_user":
        await handleDeleteUser(String(body.user_id));
        break;
      default:
        return jsonError(`Unknown action: ${body.action}`, 400);
    }
    return new Response(JSON.stringify({ ok: true }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonError(msg, 500);
  }
});

async function handleOwnerApprove(userId: string, actorId: string) {
  const now = new Date().toISOString();

  // PII pengajuan ditutup: status diset approved lalu datanya dihapus.
  await client
    .from("owner_requests")
    .update({ status: "approved", rejection: null, handled_by: actorId, handled_at: now, updated_at: now })
    .eq("user_id", userId);

  const { error } = await client
    .from("profiles")
    .update({
      role: "owner",
      owner_request_status: "approved",
      owner_requested_at: null,
      owner_request_rejection: null,
    })
    .eq("id", userId);
  if (error) throw error;

  // Data PII tidak diperlukan lagi setelah disetujui — dikosongkan, bukan
  // dihapus, supaya penanda status di profiles tetap konsisten.
  await client
    .from("owner_requests")
    .update({ nama_umkm: "-", alamat: "-", phone: "-", note: null })
    .eq("user_id", userId);
}

async function handleOwnerReject(userId: string, reason: string, actorId: string) {
  const now = new Date().toISOString();
  const alasan = reason || "Tidak memenuhi syarat.";

  await client
    .from("owner_requests")
    .update({ status: "rejected", rejection: alasan, handled_by: actorId, handled_at: now, updated_at: now })
    .eq("user_id", userId);

  const { error } = await client
    .from("profiles")
    .update({
      owner_request_status: "rejected",
      owner_request_rejection: alasan,
      owner_requested_at: null,
    })
    .eq("id", userId);
  if (error) throw error;

  // Hapus PII pendaftar: alamat & nomor telepon tidak perlu disimpan lagi.
  await client
    .from("owner_requests")
    .update({ nama_umkm: "-", alamat: "-", phone: "-", note: null })
    .eq("user_id", userId);
}

async function handleSetRole(userId: string, role: string, actorId: string) {
  if (!["user", "owner", "admin", "superadmin"].includes(role)) {
    throw new Error(`Role tidak valid: ${role}`);
  }
  const { error } = await client
    .from("profiles")
    .update({ role, request_handled_at: new Date().toISOString(), request_handled_by: actorId })
    .eq("id", userId);
  if (error) throw error;
}

async function handleSetStatus(userId: string, status: string, actorId: string) {
  if (!["active", "banned"].includes(status)) {
    throw new Error(`Status tidak valid: ${status}`);
  }
  const { error } = await client
    .from("profiles")
    .update({ status, request_handled_at: new Date().toISOString(), request_handled_by: actorId })
    .eq("id", userId);
  if (error) throw error;
}

async function handlePlaceVerify(placeId: number | string, actorId: string) {
  const { error } = await client
    .from("places")
    .update({
      verification_status: "verified",
      verified_at: new Date().toISOString(),
      verified_by: actorId,
      rejection_reason: null,
    })
    .eq("id", placeId);
  if (error) throw error;
}

async function handlePlaceReject(placeId: number | string, reason: string, actorId: string) {
  const { error } = await client
    .from("places")
    .update({
      verification_status: "rejected",
      rejection_reason: reason || "Tidak memenuhi syarat.",
      verified_by: actorId,
    })
    .eq("id", placeId);
  if (error) throw error;
}

async function handlePlaceFeature(placeId: number | string, isFeatured: boolean) {
  const { error } = await client.from("places").update({ is_featured: isFeatured }).eq("id", placeId);
  if (error) throw error;
}

async function handleReviewsDeleteByUser(userId: string) {
  const { error } = await client.from("reviews").delete().eq("user_id", userId);
  if (error) throw error;
}

async function handleDeleteUser(userId: string) {
  // Hapus data turunan dulu, lalu akun auth-nya.
  await client.from("reviews").delete().eq("user_id", userId);
  await client.from("favorites").delete().eq("user_id", userId);
  await client.from("profiles").delete().eq("id", userId);
  const { error } = await client.auth.admin.deleteUser(userId);
  if (error) throw error;
}

function jsonError(msg: string, status: number): Response {
  return new Response(JSON.stringify({ error: msg }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}