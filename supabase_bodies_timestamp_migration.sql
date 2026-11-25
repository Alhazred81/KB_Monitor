-- Supabase migráció: Leszöktetés (24h) és Aljdeszka kontroll (3 nap) kezdési időbélyeg tárolása
-- Futtasd le a Supabase Dashboard -> SQL Editor felületén:

ALTER TABLE public.bodies
  ADD COLUMN IF NOT EXISTS status_updated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Meglévő aktív szöktetők / aljdeszkák kezdési idejének kitöltése (ha már van fenn szöktető):
UPDATE public.bodies
SET status_updated_at = COALESCE(status_updated_at, created_at, updated_at, now())
WHERE status_updated_at IS NULL
  AND (body_function = 'escapement' OR is_active = true);
