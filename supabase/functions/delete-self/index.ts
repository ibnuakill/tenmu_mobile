// Supabase Edge Function — Hapus akun pengguna (self-service)
// Dipanggil langsung oleh client setelah login, tidak perlu admin.
// Menggunakan service_role untuk menghapus user & data terkait.
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
};

const client = createClient(SUPABASE_URL, SERVICE_ROLE, {
  auth: { persistSession: false },
});

serve(async (req) => {
  if (req.method === "OPTIONS")
    return new Response(null, { status: 204, headers: corsHeaders });

  if (req.method !== "POST")
    return jsonError("Method not allowed", 405);

  // Verify JWT — token dari client yang terautentikasi
  const auth = req.headers.get("Authorization") ?? "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
  if (!token) return jsonError("Unauthorized: no token", 401);

  const { data: { user }, error: userErr } = await client.auth.getUser(token);
  if (userErr || !user) return jsonError("Unauthorized: invalid token", 401);

  const userId = user.id;

  try {
    // 1. Hapus semua review yang ditulis user
    await client.from("reviews").delete().eq("user_id", userId);

    // 2. Hapus semua favorites (wishlist)
    await client.from("favorites").delete().eq("user_id", userId);

    // 3. Hapus data pengajuan owner (PII) — cascade dari profiles juga
    //    menghapusnya, ini untuk kejelasan.
    await client.from("owner_requests").delete().eq("user_id", userId);

    // 4. Hapus user dari auth (profiles ikut terhapus via ON DELETE CASCADE)
    const { error: deleteErr } = await client.auth.admin.deleteUser(userId);
    if (deleteErr) throw deleteErr;

    return new Response(
      JSON.stringify({ ok: true, message: "Akun berhasil dihapus" }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonError(msg, 500);
  }
});

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}