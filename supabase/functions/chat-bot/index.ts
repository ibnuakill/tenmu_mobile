// Supabase Edge Function — TenMu AI Chat
// Memindahkan panggilan Gemini dari CLIENT ke SERVER agar GEMINI_API_KEY tidak
// bocor di aplikasi (sebelumnya berada di .env milik client — dapat
// disalahgunakan siapa pun).
//
// Alur:
//   1. Client POST { message, history? } — dengan Authorization JWT user.
//   2. Fungsi memuat tempat verified (limit 30, dari view places_with_ratings)
//      via Supabase-js dengan service_role (internal, aman).
//   3. Menyusun system prompt (cap 30 lokasi — hemat token).
//   4. Memanggil Gemini REST API dengan key dari secret server.
//   5. Kembali { reply, mentioned: [{ id, nama_tempat }] }.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ── Config ──────────────────────────────────────────────────
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
// Edge functions punya SUPABASE_URL & SUPABASE_SERVICE_ROLE_KEY otomatis
// (service_role menyimpan tabel db langsung; key tak bocor ke client).
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')
const MODEL = 'gemini-2.5-flash-lite'
const MAX_PLACES_IN_CONTEXT = 30

interface ChatBody {
  message?: string
  /** Messages sebelumnya dari sisi client (untuk multi-turn). */
  history?: { role: string; parts: string[] }[]
}

interface PlaceRow {
  id: number
  nama_tempat: string | null
  alamat: string | null
  category: string | null
  fasilitas: string | null
  avg_rating: number | null
  deskripsi: string | null
}

// ── Gemini REST call (tanpa SDK — minim dependensi) ────────
async function geminiChat(
  system: string,
  history: { role: string; parts: string[] }[],
  userText: string,
): Promise<string> {
  const contents = [
    ...history.map((m) => ({ role: m.role, parts: m.parts })),
    { role: 'user', parts: [{ text: userText }] },
  ]
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: system }] },
        contents,
        generationConfig: { temperature: 0.7, maxOutputTokens: 600 },
      }),
    },
  )
  if (!res.ok) {
    const err = await res.text()
    throw new Error(`Gemini HTTP ${res.status}: ${err.slice(0, 200)}`)
  }
  const data = await res.json()
  return data.candidates?.[0]?.content?.parts?.[0]?.text ?? ''
}

// ── Build system prompt ────────────────────────────────────
function buildSystemPrompt(places: PlaceRow[]): string {
  const sb: string[] = [
    'Kamu adalah TenMu AI, asisten cerdas untuk aplikasi TenMu — platform penemuan tempat UMKM, wisata, kuliner, cafe, hotel, dan oleh-oleh di Indonesia.',
    'Tugas UTAMA: bantu pengguna menemukan tempat yang sesuai kebutuhan mereka dari daftar yang diberikan.',
    'Jawab dalam Bahasa Indonesia yang ramah, santai, dan informatif.',
    'ATURAN KETAT:',
    '1. Kamu HANYA BOLEH menjawab pertanyaan seputar rekomendasi tempat, pariwisata, kuliner, jam operasional, rute, atau fasilitas dari tempat di dalam daftar.',
    '2. Jika pengguna bertanya hal di luar konteks aplikasi, tolak dengan halus dan ingatkan hanya asisten rekomendasi tempat.',
    '3. Saat merekomendasikan, WAJIB sebutkan nama PERSIS dari daftar. Jangan mengarang nama tempat yang tidak ada.',
    '4. Jika tidak ada tempat cocok, jujur bilang tidak ada dan sarankan kata kunci lain.',
    '',
    `=== DAFTAR TEMPAT TERSEDIA (${places.length} lokasi) ===`,
  ]
  for (const p of places) {
    const nama = p.nama_tempat ?? ''
    if (!nama) continue
    const parts = [nama]
    if (p.category) parts.push(`[${p.category}]`)
    if (p.alamat) parts.push(` • ${p.alamat}`)
    if (p.avg_rating != null) parts.push(` • ⭐${Number(p.avg_rating).toFixed(1)}`)
    if (p.fasilitas) parts.push(` • Fasilitas: ${p.fasilitas}`)
    const desc = (p.deskripsi ?? '').replaceAll('\n', ' ').slice(0, 80)
    if (desc) parts.push(` • ${desc}`)
    sb.push(parts.join(''))
  }
  return sb.join('\n')
}

// ── HTTP handler ───────────────────────────────────────────
serve(async (req) => {
  // CORS
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      },
    })
  }
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  let body: ChatBody
  try {
    body = await req.json()
  } catch {
    return jsonError('Invalid JSON', 400)
  }
  const message = (body.message ?? '').trim()
  if (!message) return jsonError('Message required', 400)

  // ── Auth: wajib JWT user (Authorization: Bearer ...) ────
  const auth = req.headers.get('Authorization') ?? ''
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : ''
  if (!token) return jsonError('Unauthorized', 401)

  try {
    // 1. Load places verified (atau lister row)
    const supabase: SupabaseClient = createClient(
      SUPABASE_URL,
      SERVICE_ROLE ?? '',
    )
    const { data: rows, error } = await supabase
      .from('places_with_ratings')
      .select(
        'id, nama_tempat, alamat, category, fasilitas, avg_rating, deskripsi',
      )
      .eq('verification_status', 'verified')
      .order('created_at', { ascending: false })
      .limit(MAX_PLACES_IN_CONTEXT)
    if (error) throw error
    const places = (rows as PlaceRow[] | null) ?? []

    // 2. Gemini call
    if (!GEMINI_API_KEY) {
      return new Response(
        JSON.stringify({ error: 'GEMINI_API_KEY not configured' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } },
      )
    }
    const reply = await geminiChat(
      buildSystemPrompt(places),
      body.history ?? [],
      message,
    )

    // 3. Extract mentioned place names from reply
    const lower = reply.toLowerCase()
    const mentioned = places
      .filter((p) => {
        const nama = (p.nama_tempat ?? '').toLowerCase()
        return nama.length > 2 && lower.includes(nama)
      })
      .slice(0, 5)
      .map((p) => ({ id: p.id, nama_tempat: p.nama_tempat }))

    return new Response(JSON.stringify({ reply, mentioned }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('[chat-bot]', err)
    return new Response(
      JSON.stringify({ error: 'AI service temporarily unavailable' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }
})

function jsonError(msg: string, status: number): Response {
  return new Response(JSON.stringify({ error: msg }), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}