-- ============================================================================
-- HARDENING: tabel notifications
-- ----------------------------------------------------------------------------
-- MASALAH: komentar di `lib/core/notification_center.dart` menyebut policy
-- INSERT tabel `notifications` terbuka. Artinya user mana pun bisa menyisipkan
-- notifikasi in-app ke user lain (spam / pesan palsu "akun Anda diblokir").
--
-- Perbaikan: user hanya boleh membuat notifikasi untuk dirinya sendiri, dan
-- hanya boleh membaca notifikasinya sendiri. Admin tetap bisa mengirim ke
-- siapa pun lewat service_role (edge function), yang melewati RLS.
-- ============================================================================

ALTER TABLE IF EXISTS public.notifications ENABLE ROW LEVEL SECURITY;

-- Hapus policy lama yang membuka akses (nama bisa berbeda-beda per deploy).
DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'notifications'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.notifications', pol.policyname);
  END LOOP;
END;
$$;

-- SELECT: hanya notifikasi milik sendiri
CREATE POLICY "notifications_select_own"
  ON public.notifications
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- INSERT: hanya untuk diri sendiri
CREATE POLICY "notifications_insert_own"
  ON public.notifications
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- INSERT: admin boleh mengirim ke user lain (broadcast in-app)
CREATE POLICY "notifications_insert_admin"
  ON public.notifications
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role IN ('admin', 'superadmin')
    )
  );

-- UPDATE: tandai sudah dibaca (hanya milik sendiri)
CREATE POLICY "notifications_update_own"
  ON public.notifications
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- DELETE: hanya milik sendiri
CREATE POLICY "notifications_delete_own"
  ON public.notifications
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);
