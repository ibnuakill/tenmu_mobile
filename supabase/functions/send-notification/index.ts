// Supabase Edge Function — kirim push notif via OneSignal
// Dipakai untuk:
//   1) notifikasi tempat (admin approve / owner submit)
//   2) broadcast pesan dari admin ke user (in-app + push)
// OneSignal REST API key disimpan sebagai secret — aman di server.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

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
