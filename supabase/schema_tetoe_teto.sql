-- ============================================================================
-- SUPABASE ADATBÁZIS SÉMA: KIZÁRÓLAG TETŐETETŐ & SZIRUPADAGOLÁS + KALIBRÁCIÓ
-- ============================================================================
-- Ez a szkript kizárólag a tetőetető szintméréssel, ultrahangos kalibrációval
-- és szirupadagolással kapcsolatos mezőket és táblákat adja hozzá az adatbázishoz.

-- 1. KAPTÁRMONITOROK (monitors) BŐVÍTÉSE AZ ETETŐ MEZŐKKEL
-- (Csak az etető adagolási mód, ultrahang kalibráció és szintmérési adatai)
ALTER TABLE public.monitors ADD COLUMN IF NOT EXISTS feeding_mode TEXT DEFAULT 'off';
ALTER TABLE public.monitors ADD COLUMN IF NOT EXISTS feeding_max_liters NUMERIC DEFAULT 1.0;
ALTER TABLE public.monitors ADD COLUMN IF NOT EXISTS feeding_interval_hours INTEGER DEFAULT 6;
ALTER TABLE public.monitors ADD COLUMN IF NOT EXISTS feeding_interval_days INTEGER DEFAULT 1;
ALTER TABLE public.monitors ADD COLUMN IF NOT EXISTS feeding_stop_sunset_min INTEGER DEFAULT 90;
ALTER TABLE public.monitors ADD COLUMN IF NOT EXISTS feeding_portion_liters NUMERIC DEFAULT 0.2;
ALTER TABLE public.monitors ADD COLUMN IF NOT EXISTS feeder_level_percent NUMERIC DEFAULT 0.0;
ALTER TABLE public.monitors ADD COLUMN IF NOT EXISTS feeder_calib_empty_mm INTEGER DEFAULT 200;
ALTER TABLE public.monitors ADD COLUMN IF NOT EXISTS feeder_calib_full_mm INTEGER DEFAULT 30;
ALTER TABLE public.monitors ADD COLUMN IF NOT EXISTS feeder_raw_distance_mm INTEGER DEFAULT 200;
ALTER TABLE public.monitors ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW());

-- 2. KAPTÁRTORONY ELEMEK TÁBLA (bodies)
-- Ide kerülnek a fészekfiókok, mézterek, és a TETŐETETŐ is!
CREATE TABLE IF NOT EXISTS public.bodies (
    id BIGSERIAL PRIMARY KEY,
    monitor_mac TEXT REFERENCES public.monitors(mac_address) ON DELETE CASCADE,
    body_type TEXT NOT NULL DEFAULT 'dadant',       -- pl. hunor, dadant, 1/2 dadant
    body_function TEXT NOT NULL DEFAULT 'honey',    -- brood_box, honey, feeder, roof_feeder, bottom, vent, roof, pollen_trap
    position_index INTEGER NOT NULL DEFAULT 1,     -- Magassági sorrend lentről felfelé
    is_active BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW())
);

-- Index a gyors torony-lekérdezéshez kaptáronként
CREATE INDEX IF NOT EXISTS idx_bodies_mac ON public.bodies(monitor_mac);

-- 3. KEZELÉSEK & ETETÉSI TÖRTÉNET (treatments)
CREATE TABLE IF NOT EXISTS public.treatments (
    id BIGSERIAL PRIMARY KEY,
    monitor_mac TEXT REFERENCES public.monitors(mac_address) ON DELETE CASCADE,
    treatment_type TEXT NOT NULL,                  -- 'Szirup etetés', 'Oxálsav', stb.
    scheduled_date DATE NOT NULL DEFAULT CURRENT_DATE,
    is_completed BOOLEAN NOT NULL DEFAULT false,
    dosage TEXT,                                   -- pl. '1.5 liter'
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW())
);

-- 4. ESEMÉNYNAPLÓ (history_logs)
CREATE TABLE IF NOT EXISTS public.history_logs (
    id BIGSERIAL PRIMARY KEY,
    monitor_mac TEXT REFERENCES public.monitors(mac_address) ON DELETE CASCADE,
    event_type TEXT NOT NULL,                      -- 'etetés', 'kalibráció', 'atkaellenőrzés'
    description TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW())
);

-- 5. KÖZPONTI SZIRUPSZIVATTYÚ ÉS TARTÁLY (syrup_pumps)
CREATE TABLE IF NOT EXISTS public.syrup_pumps (
    id TEXT PRIMARY KEY,
    tank_capacity_liters NUMERIC DEFAULT 100.0,
    total_pumped_liters NUMERIC DEFAULT 0.0,
    last_status TEXT DEFAULT 'Készenlét',
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW())
);

-- Kezdeti rekord a központi tartálynak ha még nincs
INSERT INTO public.syrup_pumps (id, tank_capacity_liters, total_pumped_liters, last_status)
VALUES ('PUMP_MAIN', 100.0, 0.0, 'Készenlétben (100L tele)')
ON CONFLICT (id) DO NOTHING;

-- 6. ANYÁK NYILVÁNTARTÁSA (queens)
CREATE TABLE IF NOT EXISTS public.queens (
    queen_number TEXT PRIMARY KEY,
    origin TEXT DEFAULT 'Ismeretlen',
    birth_year INTEGER DEFAULT 2026,
    status TEXT DEFAULT 'Aktív',
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW())
);

-- ============================================================================
-- JOGOSULTSÁGOK & BIZTONSÁG (ROW LEVEL SECURITY - RLS)
-- ============================================================================
-- Engedélyezzük az anonim kulcsos elérést (ESP32 és mobil app REST API hívásokhoz)

ALTER TABLE public.monitors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bodies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.treatments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.history_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.syrup_pumps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.queens ENABLE ROW LEVEL SECURITY;

-- Szabályok: Olvasás és írás engedélyezése az anon role számára
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Anon monitors read/write" ON public.monitors;
    CREATE POLICY "Anon monitors read/write" ON public.monitors FOR ALL TO anon USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Anon bodies read/write" ON public.bodies;
    CREATE POLICY "Anon bodies read/write" ON public.bodies FOR ALL TO anon USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Anon treatments read/write" ON public.treatments;
    CREATE POLICY "Anon treatments read/write" ON public.treatments FOR ALL TO anon USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Anon history read/write" ON public.history_logs;
    CREATE POLICY "Anon history read/write" ON public.history_logs FOR ALL TO anon USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Anon pumps read/write" ON public.syrup_pumps;
    CREATE POLICY "Anon pumps read/write" ON public.syrup_pumps FOR ALL TO anon USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Anon queens read/write" ON public.queens;
    CREATE POLICY "Anon queens read/write" ON public.queens FOR ALL TO anon USING (true) WITH CHECK (true);
END $$;
