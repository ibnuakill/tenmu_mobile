// Supabase Edge Function — kirim push notif via OneSignal
// Dipanggil dari client setelah admin approve place
// OneSignal REST API key disimpan sebagai secret — aman di server

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

interface NotificationPayload {
  placeId: number
  placeName: string
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

  const { placeId, placeName } = body
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

  // ── Panggil OneSignal API ────────────────────────────
  const oneSignalRes = await fetch('https://onesignal.com/api/v1/notifications', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      Authorization: `Basic ${restApiKey}`,
    },
    body: JSON.stringify({
      app_id: appId,
      included_segments: ['All'],
      headings: { en: '🏪 Tempat Baru di TenMu!' },
      contents: {
        en: `${placeName} sudah terverifikasi dan siap dikunjungi. Yuk lihat!`,
      },
      data: {
        type: 'new_place',
        place_id: placeId,
      },
      priority: 10,
    }),
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
