-- ============================================================================
-- SUPABASE ADATBÁZIS: KAPTÁRTORNYOK TELJES SZABVÁNYOSÍTÁSA ÉS RENDBERAKÁSA
-- ============================================================================
-- Felhasználói előírás a kaptártornyok rétegrendjére:
-- 1. Mindegyik torony alsó része (alulról felfelé haladva):
--    - 1. Aljdeszka (bottom)
--    - 2. Pollengyűjtő (pollen_trap, dadant) [kikapcsolt állapotban]
--    - 3. Fészekfiók (brood_box, dadant)
-- 2. Mézgyűjtő család (1. Család / méz):
--    - 4 db 1/2 dadant méztéri fiók (honey, half_dadant)
--    - A tetejére Tető (roof, dadant)
-- 3. A többi család (2., 3., 4. Család / dajka / tartalék / propolisz):
--    - Fészekfiók fölé Tetőetető (feeder, dadant)
--    - A tetejére Tető (roof, dadant)
-- ============================================================================

-- 1. Táblák ellenőrzése
CREATE TABLE IF NOT EXISTS public.monitors (
    mac_address TEXT PRIMARY KEY,
    hive_number TEXT NOT NULL,
    status TEXT DEFAULT 'green',
    family_function TEXT DEFAULT 'gyujto_mez',
    protocol TEXT,
    daily_varroa_drop NUMERIC DEFAULT 0.0,
    temp NUMERIC DEFAULT 34.5,
    humidity NUMERIC DEFAULT 60.0,
    weight NUMERIC DEFAULT 35.0,
    swarm_index NUMERIC DEFAULT 0.0,
    feeding_mode TEXT DEFAULT 'off',
    feeding_max_liters NUMERIC DEFAULT 1.0,
    feeding_interval_hours INTEGER DEFAULT 6,
    feeding_interval_days INTEGER DEFAULT 1,
    feeding_stop_sunset_min INTEGER DEFAULT 90,
    feeding_portion_liters NUMERIC DEFAULT 0.2,
    feeder_level_percent NUMERIC DEFAULT 0.0,
    feeder_calib_empty_mm INTEGER DEFAULT 200,
    feeder_calib_full_mm INTEGER DEFAULT 30,
    feeder_raw_distance_mm INTEGER DEFAULT 120,
    notes TEXT,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW())
);

CREATE TABLE IF NOT EXISTS public.bodies (
    id BIGSERIAL PRIMARY KEY,
    monitor_mac TEXT REFERENCES public.monitors(mac_address) ON DELETE CASCADE,
    body_type TEXT NOT NULL DEFAULT 'dadant',
    body_function TEXT NOT NULL DEFAULT 'honey',
    position_index INTEGER NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW())
);

CREATE INDEX IF NOT EXISTS idx_bodies_mac ON public.bodies(monitor_mac);

-- 2. Monitors alaprekordok biztosítása
INSERT INTO public.monitors (mac_address, hive_number, status, family_function, feeding_mode, feeder_level_percent)
VALUES 
    ('AA:BB:CC:DD:EE:01', '1. Család (Méztermelő)', 'green', 'méz', 'off', 0.0),
    ('AA:BB:CC:DD:EE:02', '2. Család (Bővülő)', 'green', 'tartalék', 'auto_stim', 60.0),
    ('AA:BB:CC:DD:EE:03', '3. Család (Termelő)', 'green', 'propolisz', 'auto_stim', 60.0),
    ('AA:BB:CC:DD:EE:04', '4. Család (Dajka / Anyanevelő)', 'green', 'dajka', 'auto_stim', 60.0)
ON CONFLICT (mac_address) DO UPDATE SET 
    status = 'green',
    family_function = EXCLUDED.family_function;

-- 3. Meglévő bodies adatok törlése az érintett kaptárokhoz (tiszta újraépítés)
DELETE FROM public.bodies WHERE monitor_mac IN (
    'AA:BB:CC:DD:EE:01',
    'AA:BB:CC:DD:EE:02',
    'AA:BB:CC:DD:EE:03',
    'AA:BB:CC:DD:EE:04'
);

-- 4. 1. CSALÁD (MÉZGYŰJTŐ):
-- Aljdeszka + Pollengyűjtő (dadant) + Fészek (dadant) + 4x Méztér (1/2 dadant) + Tető (dadant)
INSERT INTO public.bodies (monitor_mac, body_type, body_function, position_index, is_active)
VALUES
    ('AA:BB:CC:DD:EE:01', 'bottom',      'bottom',      1, false),
    ('AA:BB:CC:DD:EE:01', 'dadant',      'pollen_trap', 2, false),
    ('AA:BB:CC:DD:EE:01', 'dadant',      'brood_box',   3, true),
    ('AA:BB:CC:DD:EE:01', 'half_dadant', 'honey',       4, true),
    ('AA:BB:CC:DD:EE:01', 'half_dadant', 'honey',       5, true),
    ('AA:BB:CC:DD:EE:01', 'half_dadant', 'honey',       6, true),
    ('AA:BB:CC:DD:EE:01', 'half_dadant', 'honey',       7, true),
    ('AA:BB:CC:DD:EE:01', 'dadant',      'roof',        8, false);

-- 5. 2. CSALÁD (BŐVÜLŐ / TARTALÉK):
-- Aljdeszka + Pollengyűjtő (dadant) + Fészek (dadant) + Tetőetető (dadant) + Tető (dadant)
INSERT INTO public.bodies (monitor_mac, body_type, body_function, position_index, is_active)
VALUES
    ('AA:BB:CC:DD:EE:02', 'bottom', 'bottom',      1, false),
    ('AA:BB:CC:DD:EE:02', 'dadant', 'pollen_trap', 2, false),
    ('AA:BB:CC:DD:EE:02', 'dadant', 'brood_box',   3, true),
    ('AA:BB:CC:DD:EE:02', 'dadant', 'feeder',      4, true),
    ('AA:BB:CC:DD:EE:02', 'dadant', 'roof',        5, false);

-- 6. 3. CSALÁD (TERMELŐ / PROPOLISZ):
-- Aljdeszka + Pollengyűjtő (dadant) + Fészek (dadant) + Tetőetető (dadant) + Tető (dadant)
INSERT INTO public.bodies (monitor_mac, body_type, body_function, position_index, is_active)
VALUES
    ('AA:BB:CC:DD:EE:03', 'bottom', 'bottom',      1, false),
    ('AA:BB:CC:DD:EE:03', 'dadant', 'pollen_trap', 2, false),
    ('AA:BB:CC:DD:EE:03', 'dadant', 'brood_box',   3, true),
    ('AA:BB:CC:DD:EE:03', 'dadant', 'feeder',      4, true),
    ('AA:BB:CC:DD:EE:03', 'dadant', 'roof',        5, false);

-- 7. 4. CSALÁD (DAJKA / ANYANEVELŐ):
-- Aljdeszka + Pollengyűjtő (dadant) + Fészek (dadant) + Tetőetető (dadant) + Tető (dadant)
INSERT INTO public.bodies (monitor_mac, body_type, body_function, position_index, is_active)
VALUES
    ('AA:BB:CC:DD:EE:04', 'bottom', 'bottom',      1, false),
    ('AA:BB:CC:DD:EE:04', 'dadant', 'pollen_trap', 2, false),
    ('AA:BB:CC:DD:EE:04', 'dadant', 'brood_box',   3, true),
    ('AA:BB:CC:DD:EE:04', 'dadant', 'feeder',      4, true),
    ('AA:BB:CC:DD:EE:04', 'dadant', 'roof',        5, false);

-- 8. DINAMIKUS BLOKK: Bármely egyéb adatbázisban lévő kaptár tornyának automatikus rendbetétele
DO $$
DECLARE
    rec RECORD;
    is_honey_colony BOOLEAN;
BEGIN
    FOR rec IN SELECT mac_address, hive_number, family_function FROM public.monitors
               WHERE mac_address NOT IN ('AA:BB:CC:DD:EE:01', 'AA:BB:CC:DD:EE:02', 'AA:BB:CC:DD:EE:03', 'AA:BB:CC:DD:EE:04')
    LOOP
        DELETE FROM public.bodies WHERE monitor_mac = rec.mac_address;

        is_honey_colony := (
            LOWER(COALESCE(rec.family_function, '')) IN ('méz', 'mez', 'gyujto_mez', 'méztermelő') OR
            LOWER(rec.hive_number) LIKE '%méz%' OR
            LOWER(rec.hive_number) LIKE '%termelő%'
        );

        -- Alap torony (Aljdeszka + Pollengyűjtő + Fészekfiók)
        INSERT INTO public.bodies (monitor_mac, body_type, body_function, position_index, is_active)
        VALUES
            (rec.mac_address, 'bottom', 'bottom',      1, false),
            (rec.mac_address, 'dadant', 'pollen_trap', 2, false),
            (rec.mac_address, 'dadant', 'brood_box',   3, true);

        IF is_honey_colony THEN
            -- 4 db 1/2 dadant méztér + tető
            INSERT INTO public.bodies (monitor_mac, body_type, body_function, position_index, is_active)
            VALUES
                (rec.mac_address, 'half_dadant', 'honey', 4, true),
                (rec.mac_address, 'half_dadant', 'honey', 5, true),
                (rec.mac_address, 'half_dadant', 'honey', 6, true),
                (rec.mac_address, 'half_dadant', 'honey', 7, true),
                (rec.mac_address, 'dadant',      'roof',  8, false);
        ELSE
            -- Tetőetető + tető
            INSERT INTO public.bodies (monitor_mac, body_type, body_function, position_index, is_active)
            VALUES
                (rec.mac_address, 'dadant', 'feeder', 4, true),
                (rec.mac_address, 'dadant', 'roof',   5, false);
        END IF;
    END LOOP;
END $$;
