// Supabase Edge Function — kirim push notif via OneSignal
// Dipanggil dari client setelah admin approve place
// OneSignal REST API key disimpan sebagai secret — aman di server

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

interface NotificationPayload {
  placeId: number
  placeName: string
  /** If provided, push only to these OneSignal user IDs (targeted). Otherwise broadcast to All. */
  targetUserIds?: string[]
  /** 'new_place' = broadcast (admin approve), 'new_submission' = notify admins (owner add) */
  type?: 'new_place' | 'new_submission'
}

serve(async (req) => {
  // ── CORS ──────────────────────────────────────────────
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

  // ── Parse body ───────────────────────────────────────
  let body: NotificationPayload
  try {
    body = await req.json()
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const { placeId, placeName, targetUserIds, type } = body
  if (!placeId || !placeName) {
    return new Response(JSON.stringify({ error: 'placeId and placeName required' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // ── Secrets dari Supabase ────────────────────────────
  const appId = Deno.env.get('ONESIGNAL_APP_ID')
  const restApiKey = Deno.env.get('ONESIGNAL_REST_API_KEY')

  if (!appId || !restApiKey) {
    console.error('[send-notification] OneSignal credentials not configured')
    return new Response(JSON.stringify({ error: 'Server configuration error' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const isTargeted = targetUserIds && targetUserIds.length > 0

  const payload: Record<string, unknown> = {
    app_id: appId,
    headings: { en: isTargeted ? '📋 Tempat Baru Butuh Verifikasi' : '🏪 Tempat Baru di TenMu!' },
    contents: {
      en: isTargeted
        ? `${placeName} baru saja ditambahkan. Yuk verifikasi sekarang!`
        : `${placeName} sudah terverifikasi dan siap dikunjungi. Yuk lihat!`,
    },
    data: {
      type: type ?? 'new_place',
      place_id: placeId,
    },
    priority: 10,
  }

  if (isTargeted) {
    payload.include_external_user_ids = targetUserIds
  } else {
    payload.included_segments = ['All']
  }

  // ── Panggil OneSignal API ────────────────────────────
  const oneSignalRes = await fetch('https://onesignal.com/api/v1/notifications', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      Authorization: `Basic ${restApiKey}`,
    },
    body: JSON.stringify(payload),
  })

  const result = await oneSignalRes.json()
  console.log('[send-notification] OneSignal response:', JSON.stringify(result))

  if (!oneSignalRes.ok) {
    return new Response(JSON.stringify({ error: 'OneSignal API error', detail: result }), {
      status: 502,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  return new Response(JSON.stringify({ success: true, data: result }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
})
