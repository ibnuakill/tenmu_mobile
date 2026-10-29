// Supabase Edge Function — kirim push notif via OneSignal
// Dipakai untuk:
//   1) notifikasi tempat (admin approve / owner submit)
//   2) broadcast pesan dari admin ke user (in-app + push)
// OneSignal REST API key disimpan sebagai secret — aman di server.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface NotificationPayload {
  /** Mode broadcast admin */
  title?: string
  body?: string
  /** Mode notifikasi tempat (legacy) */
  placeId?: number
  placeName?: string
  /** Kalau diisi → kirim hanya ke user ini (OneSignal external_id = auth user id). Kosong → broadcast. */
  targetUserIds?: string[]
  type?: string
  /** Tautan yang dibuka saat notifikasi diketuk (mis. URL APK untuk type=update). */
  url?: string
}

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  // ── Otorisasi ────────────────────────────────────────
  // Tanpa blok ini, siapa pun yang memegang anon key (ikut ter-bundle di APK)
  // bisa mem-broadcast push ke SEMUA user. Jadi setiap panggilan wajib:
  //   1) punya JWT user yang valid, dan
  //   2) broadcast / kirim ke user lain hanya boleh admin,
  //      sedangkan notifikasi tempat hanya boleh pemilik tempat itu.
  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
  if (!supabaseUrl || !serviceKey) {
    console.error('[send-notification] Supabase env belum diset')
    return json({ error: 'Server configuration error' }, 500)
  }

  const authHeader = req.headers.get('Authorization') ?? ''
  const token = authHeader.replace(/^Bearer\s+/i, '').trim()
  if (!token) return json({ error: 'Unauthorized' }, 401)

  // Anon key bukan identitas user — tolak kalau dipakai sebagai token.
  if (anonKey && token === anonKey) {
    return json({ error: 'Unauthorized' }, 401)
  }

  const asUser = createClient(supabaseUrl, anonKey ?? serviceKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  })
  const { data: userData, error: userErr } = await asUser.auth.getUser(token)
  if (userErr || !userData?.user) {
    return json({ error: 'Unauthorized' }, 401)
  }
  const callerId = userData.user.id

  const admin = createClient(supabaseUrl, serviceKey)
  const { data: callerProfile } = await admin
    .from('profiles')
    .select('id, role')
    .eq('id', callerId)
    .maybeSingle()
  const callerRole = (callerProfile?.role ?? 'user') as string
  const isAdmin = callerRole === 'admin' || callerRole === 'superadmin'

  // ── Parse body ───────────────────────────────────────
  let body: NotificationPayload
  try {
    body = await req.json()
  } catch {
    return json({ error: 'Invalid JSON' }, 400)
  }

  const { title, body: message, placeId, placeName, targetUserIds, type } = body

  // Mode broadcast admin butuh title + body; mode tempat butuh placeId + placeName.
  const isBroadcast = !!(title && message)
  if (!isBroadcast && (!placeId || !placeName)) {
    return json({ error: 'title+body atau placeId+placeName wajib diisi' }, 400)
  }

  let ownsPlace = false
  if (isBroadcast) {
    // Broadcast / kirim pesan bebas = hak admin saja.
    if (!isAdmin) {
      console.warn(`[send-notification] tolak broadcast dari ${callerId} (${callerRole})`)
      return json({ error: 'Forbidden: khusus admin' }, 403)
    }
  } else if (!isAdmin) {
    // Notifikasi tempat: pemanggil harus pemilik tempat tersebut.
    const { data: place } = await admin
      .from('places')
      .select('id, owner_id')
      .eq('id', placeId as number)
      .maybeSingle()
    if (!place || place.owner_id !== callerId) {
      console.warn(`[send-notification] tolak notif tempat ${placeId} dari ${callerId}`)
      return json({ error: 'Forbidden: bukan pemilik tempat' }, 403)
    }
    ownsPlace = true
  }

  // Kirim ke user tertentu: admin bebas; pemilik tempat hanya untuk notifikasi
  // tempatnya sendiri (mis. memberi tahu admin soal pengajuan baru).
  if (!isAdmin && !ownsPlace && Array.isArray(targetUserIds) && targetUserIds.length > 0) {
    return json({ error: 'Forbidden: target user khusus admin' }, 403)
  }

  // ── Secrets ──────────────────────────────────────────
  const appId = Deno.env.get('ONESIGNAL_APP_ID')
  const restApiKey = Deno.env.get('ONESIGNAL_REST_API_KEY')
  if (!appId || !restApiKey) {
    console.error('[send-notification] OneSignal credentials not configured')
    return json({ error: 'Server configuration error' }, 500)
  }

  const ids = (targetUserIds ?? []).filter((v) => typeof v === 'string' && v.length > 0)
  const isTargeted = ids.length > 0

  const headings = isBroadcast
    ? title!
    : isTargeted
      ? '📋 Tempat Baru Butuh Verifikasi'
      : '🏪 Tempat Baru di TenMu!'
  const contents = isBroadcast
    ? message!
    : isTargeted
      ? `${placeName} baru saja ditambahkan. Yuk verifikasi sekarang!`
      : `${placeName} sudah terverifikasi dan siap dikunjungi. Yuk lihat!`

  const data: Record<string, unknown> = {
    type: type ?? (isBroadcast ? 'admin' : 'new_place'),
  }
  if (placeId) data.place_id = placeId
  // Diteruskan ke aplikasi; dipakai NotificationService untuk membuka tautan
  // saat notifikasi diketuk (mis. unduhan APK untuk type=update).
  if (body.url) data.url = body.url

  const base = {
    app_id: appId,
    headings: { en: headings },
    contents: { en: contents },
    data,
    priority: 10,
  }

  // ── Kirim: coba API baru (include_aliases), fallback ke legacy v1 ──
  async function sendModern() {
    const payload: Record<string, unknown> = { ...base, target_channel: 'push' }
    if (isTargeted) {
      payload.include_aliases = { external_id: ids }
    } else {
      payload.included_segments = ['Subscribed Users']
    }
    const res = await fetch('https://api.onesignal.com/notifications', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        Authorization: `Key ${restApiKey}`,
      },
      body: JSON.stringify(payload),
    })
    return { res, result: await res.json() }
  }

  async function sendLegacy() {
    const payload: Record<string, unknown> = { ...base }
    if (isTargeted) {
      payload.include_external_user_ids = ids
    } else {
      payload.included_segments = ['All']
    }
    const res = await fetch('https://onesignal.com/api/v1/notifications', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        Authorization: `Basic ${restApiKey}`,
      },
      body: JSON.stringify(payload),
    })
    return { res, result: await res.json() }
  }

  let { res, result } = await sendModern()
  console.log('[send-notification] modern:', res.status, JSON.stringify(result))

  if (!res.ok) {
    const retry = await sendLegacy()
    console.log('[send-notification] legacy:', retry.res.status, JSON.stringify(retry.result))
    res = retry.res
    result = retry.result
  }

  if (!res.ok) {
    return json({ error: 'OneSignal API error', detail: result }, 502)
  }

  return json({
    success: true,
    targeted: isTargeted,
    recipients: ids.length,
    data: result,
  })
})
