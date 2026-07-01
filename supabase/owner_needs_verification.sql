-- Owner places need admin verification (only superadmin auto-verified)
-- Run this in Supabase SQL Editor

CREATE OR REPLACE FUNCTION set_place_verification_status()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
      AND role IN ('superadmin')
  ) THEN
    NEW.verification_status := 'verified';
    NEW.verified_at := NOW();
    NEW.verified_by := auth.uid();
  ELSE
    NEW.verification_status := 'pending';
    NEW.verified_at := NULL;
    NEW.verified_by := NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Also fix existing owner places that were auto-verified:
-- Set them back to pending so admin can review (skip if already reviewed)
UPDATE places
SET verification_status = 'pending',
    verified_at = NULL,
    verified_by = NULL
WHERE verification_status = 'verified'
  AND verified_by IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = places.verified_by
      AND profiles.role = 'owner'
  );
