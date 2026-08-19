// Supabase Edge Function — TenMu AI Chat
// Panggilan Gemini dari SERVER (GEMINI_API_KEY di secret, tak bocor ke client).
//
// Alur:
//   1. Client POST { message, history? } dengan Authorization JWT user.
//   2. Fungsi verifikasi JWT -> userId, lalu muat konteks pengguna
//      (nama, kota, tempat favorit) + daftar tempat verified (limit 40).
//   3. Susun system prompt: asisten umum yang BISA tanya-jawab apa saja,
//      tapi rekomendasi tempat wajib grounded ke daftar yang diberikan.
//   4. Panggil Gemini REST API.
//   5. Kembali { reply, mentioned: [{ id, nama_tempat }] }.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ── Config ──────────────────────────────────────────────────
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')
const MODEL = 'gemini-2.5-flash-lite'
const MAX_PLACES_IN_CONTEXT = 40

interface ChatBody {
  message?: string
  /** Pesan sebelumnya dari client (multi-turn + personalisasi). */
  history?: { role: string; parts: (string | { text: string })[] }[]
}

interface PlaceRow {
  id: number
  nama_tempat: string | null
  alamat: string | null
  category: string | null
  fasilitas: string | null
  avg_rating: number | null
  review_count: number | null
  harga_teks: string | null
  min_price: number | null
  max_price: number | null
  jam_buka: string | null
  jam_tutup: string | null
  nomor_telepon: string | null
  deskripsi: string | null
}

// ── Gemini REST call (tanpa SDK — minim dependensi) ────────
async function geminiChat(
  system: string,
  history: { role: string; parts: (string | { text: string })[] }[],
  userText: string,
): Promise<string> {
  // Normalisasi: Gemini wajib parts = array objek {text}, bukan string.
  // Buang pesan kosong, paksa role user/model, dan pastikan urutan valid:
  //   a) dimulai dari peran 'user' (pesan sapaan 'model' di awal dibuang),
  //   b) peran bergantian (dua pesan berurutan yang sama digabung).
  const merged: { role: 'user' | 'model'; parts: { text: string }[] }[] = []
  for (const m of history) {
    const parts = m.parts
      .map((p) => (typeof p === 'string' ? { text: p } : p))
      .filter((p) => (p.text ?? '').trim())
    if (parts.length === 0) continue
    const role: 'user' | 'model' = m.role === 'user' ? 'user' : 'model'
    const last = merged[merged.length - 1]
    if (last && last.role === role) last.parts.push(...parts)
    else merged.push({ role, parts })
  }
  while (merged.length && merged[0].role !== 'user') merged.shift()

  const contents = [
    ...merged,
    { role: 'user' as const, parts: [{ text: userText }] },
  ]
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: system }] },
        contents,
        generationConfig: { temperature: 0.7, maxOutputTokens: 700 },
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

// ── Konteks pengguna: nama, kota, favorit ──────────────────
async function loadUserContext(
  supabase: SupabaseClient,
  userId: string,
): Promise<{ nama: string; kota: string; favNames: string[] }> {
  const { data: profile } = await supabase
    .from('profiles')
    .select('full_name, nama, city')
    .eq('id', userId)
    .maybeSingle()
  const nama = profile?.full_name || profile?.nama || ''
  const kota = profile?.city || ''

  let favNames: string[] = []
  try {
    const { data: favRows } = await supabase
      .from('favorites')
      .select('umkm_id, places(nama_tempat)')
      .eq('user_id', userId)
      .limit(20)
    favNames = (favRows ?? [])
      .map((r) => (r.places as { nama_tempat?: string } | null)?.nama_tempat)
      .filter((n): n is string => !!n)
  } catch (_) {
    // favorit gagal dimuat — jangan gagalkan seluruh chat
  }
  return { nama, kota, favNames }
}

// ── Bersihkan markdown Gemini → teks polos (biar tak ada ** di chat) ──
function cleanMarkdown(text: string): string {
  return text
    .replace(/\*\*(.+?)\*\*/gs, '$1')
    .replace(/\*(.+?)\*/gs, '$1')
    .replace(/`(.+?)`/gs, '$1')
    .replace(/^[*•]\s/gm, '• ')
}

// ── Build system prompt ────────────────────────────────────
function buildSystemPrompt(
  places: PlaceRow[],
  user: { nama: string; kota: string; favNames: string[] },
): string {
  const sb: string[] = [
    'Kamu adalah TenMu AI, asisten pribadi cerdas di aplikasi TenMu — platform penemuan tempat UMKM, kuliner, cafe, wisata, hotel, dan oleh-oleh di Indonesia.',
    'KEPRIBADIAN: ramah, santai, informatif, jawab dalam Bahasa Indonesia. Panggil pengguna dengan namanya bila tahu.',
    '',
    'KEBIJAKAN:',
    '1. Kamu BUKAN hanya mesin rekomendasi tempat. Kamu BISA menjawab pertanyaan umum apa pun (pengetahuan umum, tips, diskusi santai, dll) dengan bantuan pengetahuanmu.',
    '2. Untuk pertanyaan rekomendasi tempat: jawab HANYA berdasarkan daftar tempat yang diberikan di bawah. WAJIB sebutkan nama PERSIS dari daftar. JANGAN mengarang nama, alamat, jam buka, atau fasilitas.',
    '3. Jika tidak ada tempat cocok di daftar, katakan jujur tidak ada dan sarankan kata kunci lain.',
    '4. Jika pengguna bertanya tentang tempat di luar daftar, boleh jawab secara umum dari pengetahuanmu, tapi sampaikan bahwa tempat itu belum tersedia di TenMu.',
    '5. Gunakan konteks pengguna (nama, kota, tempat favorit, dan riwayat percakapan) agar jawaban terasa personal dan relevan.',
    '',
    `=== KONTEKS PENGGUNA ===`,
    `Nama: ${user.nama || '(tidak diketahui)'}`,
    `Kota: ${user.kota || '(tidak diketahui)'}`,
    `Tempat favorit: ${user.favNames.length ? user.favNames.join(', ') : '(belum ada)'}`,
    '',
    `=== DAFTAR TEMPAT TERSEDIA (${places.length} lokasi) ===`,
  ]
  for (const p of places) {
    const nama = p.nama_tempat ?? ''
    if (!nama) continue
    const parts = [nama]
    if (p.category) parts.push(`[${p.category}]`)
    if (p.alamat) parts.push(` • ${p.alamat}`)
    if (p.avg_rating != null) {
      const rating = Number(p.avg_rating).toFixed(1)
      parts.push(` • ⭐${rating}${p.review_count ? ` (${p.review_count} ulasan)` : ''}`)
    }
    if (p.harga_teks) parts.push(` • Harga: ${p.harga_teks}`)
    else if (p.min_price != null || p.max_price != null) {
      const r = (x: number | null) => (x == null ? '' : x.toLocaleString('id-ID'))
      parts.push(` • Harga: ${r(p.min_price)}-${r(p.max_price)}`)
    }
    if (p.jam_buka || p.jam_tutup) {
      parts.push(` • Jam: ${p.jam_buka ?? '?'}-${p.jam_tutup ?? '?'}`)
    }
    if (p.fasilitas) parts.push(` • Fasilitas: ${p.fasilitas}`)
    if (p.nomor_telepon) parts.push(` • Telp: ${p.nomor_telepon}`)
    const desc = (p.deskripsi ?? '').replaceAll('\n', ' ').slice(0, 60)
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

  // Ping ringan: tanpa Gemini, tanpa DB — cek ketersediaan fungsi saja.
  if (message === 'ping') {
    return new Response(JSON.stringify({ reply: 'pong', mentioned: [] }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // ── Auth: verifikasi JWT → userId ────────────────────────
  const auth = req.headers.get('Authorization') ?? ''
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : ''
  if (!token) return jsonError('Unauthorized', 401)

  const supabase: SupabaseClient = createClient(
    SUPABASE_URL,
    SERVICE_ROLE ?? '',
  )

  try {
    const { data: userData, error: userErr } = await supabase.auth.getUser(token)
    if (userErr || !userData.user) return jsonError('Unauthorized', 401)
    const userId = userData.user.id

    // 1. Konteks pengguna (nama, kota, favorit) — personalisasi
    const user = await loadUserContext(supabase, userId)

    // 2. Tempat verified (atau lister row)
    const { data: rows, error } = await supabase
      .from('places_with_ratings')
      .select(
        'id, nama_tempat, alamat, category, fasilitas, avg_rating, review_count, ' +
          'harga_teks, min_price, max_price, jam_buka, jam_tutup, nomor_telepon, deskripsi',
      )
      .eq('verification_status', 'verified')
      .order('created_at', { ascending: false })
      .limit(MAX_PLACES_IN_CONTEXT)
    if (error) throw error
    const places = (rows as PlaceRow[] | null) ?? []

    // 3. Gemini call
    if (!GEMINI_API_KEY) {
      return new Response(
        JSON.stringify({ error: 'GEMINI_API_KEY not configured' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } },
      )
    }
    const reply = cleanMarkdown(
      await geminiChat(
        buildSystemPrompt(places, user),
        body.history ?? [],
        message,
      ),
    )

    // 4. Extract mentioned place names from reply
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
