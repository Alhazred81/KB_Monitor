#include "syrup_manager.h"
#include "NtfyClient.h"
#include "web_common.h"

extern NtfyClient ntfy;

static SyrupPairingEntry s_entries[MAX_SYRUP_ENTRIES];
static int s_entryCount = 0;
static const char* FILE_SYRUP_PAIRS = "/syrup_pairs.json";

// Segédfüggvény: bejegyzés keresése vagy létrehozása
static SyrupPairingEntry* findOrCreateEntry(const char* monitorId) {
    if (!monitorId || strlen(monitorId) == 0) return nullptr;

    for (int i = 0; i < s_entryCount; i++) {
        if (strcmp(s_entries[i].monitorId, monitorId) == 0) {
            return &s_entries[i];
        }
    }

    if (s_entryCount < MAX_SYRUP_ENTRIES) {
        SyrupPairingEntry* e = &s_entries[s_entryCount++];
        memset(e, 0, sizeof(SyrupPairingEntry));
        strncpy(e->monitorId, monitorId, sizeof(e->monitorId) - 1);
        strncpy(e->tankId, "ABC", sizeof(e->tankId) - 1); // Alapértelmezett első tartály
        e->state = SYRUP_GREEN;
        e->isAutoPaired = false;
        e->isRefilling = false;
        e->isPumpInterlocked = false;
        return e;
    }

    return nullptr;
}

// Konfiguráció betöltése Flash-ből
static void loadPairsFromFs() {
    if (!LittleFS.exists(FILE_SYRUP_PAIRS)) return;

    File f = LittleFS.open(FILE_SYRUP_PAIRS, FILE_READ);
    if (!f) return;

    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, f);
    f.close();

    if (!err && doc.is<JsonArray>()) {
        s_entryCount = 0;
        for (JsonObject obj : doc.as<JsonArray>()) {
            if (s_entryCount >= MAX_SYRUP_ENTRIES) break;
            SyrupPairingEntry* e = &s_entries[s_entryCount++];
            memset(e, 0, sizeof(SyrupPairingEntry));
            const char* mId = obj["monitor_id"] | "";
            const char* tId = obj["tank_id"] | "ABC";
            strncpy(e->monitorId, mId, sizeof(e->monitorId) - 1);
            strncpy(e->tankId, tId, sizeof(e->tankId) - 1);
            e->state = (SyrupState)(obj["state"] | (int)SYRUP_GREEN);
            e->isAutoPaired = obj["auto_paired"] | false;
            e->isPumpInterlocked = obj["interlocked"] | false;
        }
    }
}

// Konfiguráció mentése Flash-be
static void savePairsToFs() {
    File f = LittleFS.open(FILE_SYRUP_PAIRS, FILE_WRITE);
    if (!f) return;

    JsonDocument doc;
    JsonArray arr = doc.to<JsonArray>();

    for (int i = 0; i < s_entryCount; i++) {
        JsonObject obj = arr.add<JsonObject>();
        obj["monitor_id"] = s_entries[i].monitorId;
        obj["tank_id"] = s_entries[i].tankId;
        obj["state"] = (int)s_entries[i].state;
        obj["auto_paired"] = s_entries[i].isAutoPaired;
        obj["interlocked"] = s_entries[i].isPumpInterlocked;
    }

    serializeJson(doc, f);
    f.close();
}

void syrupManagerInit() {
    loadPairsFromFs();
    diagAdd("[SZIRUP] Szirupadagoló vezérlő és auto-párosító inicializálva.");
}

bool syrupRequestRefill(const char* monitorId, const char* preferredTankId) {
    if (!monitorId) return false;

    SyrupPairingEntry* entry = findOrCreateEntry(monitorId);
    if (!entry) {
        diagAdd("[SZIRUP] Hiba: Nem sikerült bejegyzést létrehozni monitorhoz: " + String(monitorId));
        return false;
    }

    uint32_t now = millis();

    // 1. RETESZ ELLENŐRZÉS: Villogó piros állapotban a szivattyú SEMMIKÉPP nem indulhat el!
    if (entry->isPumpInterlocked || entry->state == SYRUP_BLINKING_RED) {
        diagAdd("[SZIRUP BLOKKOLVA] " + String(monitorId) + " szivattyúzás TILTVA! Villogó piros vészretesz aktív.");
        return false;
    }

    // 2. SZTOJ ELLENŐRZÉS: Ha a monitor még SZTOJ várakozási idő alatt van
    if (entry->sztojUntilTime > now) {
        uint32_t remSec = (entry->sztojUntilTime - now) / 1000;
        diagAdd("[SZIRUP SZTOJ] " + String(monitorId) + " még várakozóban (" + String(remSec) + " mp van hátra).");
        return false;
    }

    // 3. ÜTKÖZÉSVIZSGÁLAT (COLLISION DETECTION):
    // Ha egy másik monitor éppen utántöltés alatt áll és auto-párosítás vagy adagolás zajlik:
    for (int i = 0; i < s_entryCount; i++) {
        if (&s_entries[i] != entry && s_entries[i].isRefilling) {
            // Ütközés van! Küldünk egy SZTOJ jelet a kérelmező monitornak (5 perc várakozás)
            entry->sztojUntilTime = now + (SYRUP_SZTOJ_DURATION_SEC * 1000UL);
            entry->state = SYRUP_ORANGE; // Narancs állapot: utántöltésre vár, várakoztatva
            strncpy(entry->errorMessage, "SZTOJ: Várakozás másik kaptár feltöltésére", sizeof(entry->errorMessage) - 1);

            diagAdd("[SZIRUP ÜTKÖZÉS] " + String(monitorId) + " kért töltést, de " +
                    String(s_entries[i].monitorId) + " éppen töltődik! SZTOJ küldve (5 perc).");

            // Ntfy értesítés az ütközésről és a sorbaállításról
            String ntfyMsg = "Ütközésvédelem: " + String(monitorId) + " kaptár várakozólistára (SZTOJ 5 perc) került, mert " +
                            String(s_entries[i].monitorId) + " töltése folyamatban van.";
            ntfy.send(ntfyMsg.c_str(), "Szirup SZTOJ Várakozó", NtfyPriority::Default);
            return false;
        }
    }

    // 4. HA NINCS ÜTKÖZÉS: Kijelöljük a tartályt (vagy megtartjuk a korábbi párosítást)
    if (preferredTankId && strlen(preferredTankId) > 0) {
        strncpy(entry->tankId, preferredTankId, sizeof(entry->tankId) - 1);
    } else if (strlen(entry->tankId) == 0) {
        strncpy(entry->tankId, "ABC", sizeof(entry->tankId) - 1);
    }

    // 5. SZIVATTYÚZÁS ÉS SZINTFIGYELÉS INDÍTÁSA
    entry->isRefilling = true;
    entry->refillStartTime = now;
    entry->initialDistanceMm = (entry->currentDistanceMm > 0) ? entry->currentDistanceMm : FEEDER_DEFAULT_EMPTY_MM;
    entry->state = SYRUP_ORANGE; // Narancs = folyamatban lévő utántöltés
    entry->sztojUntilTime = 0;
    entry->errorMessage[0] = '\0';

    diagAdd("[SZIRUP START] " + String(monitorId) + " utántöltés elindult -> Tartály: " +
            String(entry->tankId) + " | Kezdeti UH táv: " + String(entry->initialDistanceMm) + " mm");

    return true;
}

void syrupReportFeederLevel(const char* monitorId, uint16_t distanceMm) {
    if (!monitorId) return;
    SyrupPairingEntry* entry = findOrCreateEntry(monitorId);
    if (!entry) return;

    entry->currentDistanceMm = distanceMm;

    // Százalékos szint kiszámítása (FEEDER_DEFAULT_EMPTY_MM vs FULL_MM)
    uint16_t emptyMm = FEEDER_DEFAULT_EMPTY_MM;
    uint16_t fullMm = FEEDER_DEFAULT_FULL_MM;
    int pct = 0;
    if (emptyMm > fullMm) {
        if (distanceMm <= fullMm) pct = 100;
        else if (distanceMm >= emptyMm) pct = 0;
        else pct = (int)(((float)(emptyMm - distanceMm) / (float)(emptyMm - fullMm)) * 100.0f);
    }

    // Ha nincs reteszben és nem töltődik éppen, állapot frissítése szint szerint
    if (!entry->isPumpInterlocked && !entry->isRefilling && entry->sztojUntilTime <= millis()) {
        if (pct >= 50) {
            entry->state = SYRUP_GREEN;
        } else if (pct >= 20) {
            entry->state = SYRUP_YELLOW;
        } else if (pct > 5) {
            entry->state = SYRUP_ORANGE;
        } else {
            entry->state = SYRUP_RED;
        }
    }
}

void syrupStopRefill(const char* monitorId, bool emergencyTimeout, const char* reason) {
    if (!monitorId) return;
    SyrupPairingEntry* entry = findOrCreateEntry(monitorId);
    if (!entry) return;

    entry->isRefilling = false;

    if (emergencyTimeout) {
        // VÉSZLEÁLLÍTÁS (TIMEOUT): Átlépés VILLOGÓ PIROSBA!
        entry->state = SYRUP_BLINKING_RED;
        entry->isPumpInterlocked = true; // SZIVATTYÚ TELJESEN LETILTVA!
        const char* err = reason ? reason : "Szintemelkedési timeout: nem emelkedik a szirup";
        strncpy(entry->errorMessage, err, sizeof(entry->errorMessage) - 1);

        diagAdd("[SZIRUP VÉSZLEÁLLÍTÁS] " + String(monitorId) + " leállítva! Ok: " + String(err) +
                " -> Szivattyú reteszelve (VILLOGÓ PIROS).");

        // NTFY VÉSZJELZÉS KÜLDÉSE (Sürgős prioritás)
        String ntfyTitle = "SZIRUP VÉSZLEÁLLÍTÁS: " + String(monitorId);
        String ntfyBody = "VÉSZLEÁLLÍTÁS! " + String(monitorId) + " kaptárnál a szivattyú (" +
                          String(entry->tankId) + ") jár, de a szirup szintje nem emelkedett (Timeout). " +
                          "A szivattyú leállítva és VILLOGÓ PIROS retesszel letiltva a csőtörés és szivárgás megelőzésére!";
        ntfy.send(ntfyBody.c_str(), ntfyTitle.c_str(), NtfyPriority::High);
    } else {
        // Normál sikeres feltöltés vagy kézi leállítás
        entry->state = SYRUP_GREEN;
        diagAdd("[SZIRUP STOP] " + String(monitorId) + " utántöltés befejeződött (OK).");
    }

    savePairsToFs();
}

bool syrupResetInterlock(const char* tankOrMonitorId) {
    if (!tankOrMonitorId) return false;
    bool found = false;

    for (int i = 0; i < s_entryCount; i++) {
        if (strcmp(s_entries[i].monitorId, tankOrMonitorId) == 0 ||
            strcmp(s_entries[i].tankId, tankOrMonitorId) == 0) {
            s_entries[i].isPumpInterlocked = false;
            s_entries[i].state = SYRUP_GREEN;
            s_entries[i].errorMessage[0] = '\0';
            found = true;
            diagAdd("[SZIRUP RETESZ FELOLDVA] " + String(s_entries[i].monitorId) + " / " +
                    String(s_entries[i].tankId) + " gazda által újra engedélyezve.");
        }
    }

    if (found) {
        savePairsToFs();
        ntfy.send("A szirup vészretesz (villogó piros) feloldva, a szivattyú újra üzemkész.",
                  "Szirup Retesz Törölve", NtfyPriority::Default);
    }
    return found;
}

void syrupManagerLoop() {
    static unsigned long lastCheck = 0;
    unsigned long now = millis();
    if (now - lastCheck < 1000) return; // 1 másodpercenként fut
    lastCheck = now;

    for (int i = 0; i < s_entryCount; i++) {
        SyrupPairingEntry* e = &s_entries[i];

        // 1. TIMEOUT VIZSGÁLAT AKTÍV TÖLTÉS ALATT
        if (e->isRefilling) {
            unsigned long elapsedSec = (now - e->refillStartTime) / 1000;

            if (elapsedSec >= SYRUP_REFILL_TIMEOUT_SEC) {
                // Ellenőrizzük, hogy csökkent-e az ultrahang távolság (azaz emelkedett-e a szint)
                // Kisebb távolság = magasabb szint
                int riseMm = (int)e->initialDistanceMm - (int)e->currentDistanceMm;

                if (riseMm < SYRUP_MIN_RISE_MM) {
                    // NEM EMELKEDETT A SZIRUP SZINTJE -> VÉSZLEÁLLÍTÁS!
                    syrupStopRefill(e->monitorId, true, "Nem emelkedik a szirup szintje (Timeout)");
                } else {
                    // EMELKEDIK! -> Auto-párosítás sikeres megerősítése
                    if (!e->isAutoPaired) {
                        e->isAutoPaired = true;
                        diagAdd("[SZIRUP AUTO-PÁROSÍTÁS] " + String(e->monitorId) + " és " +
                                String(e->tankId) + " automatikusan összerendelve a szintemelkedés alapján!");
                        String msg = "Sikeres auto-párosítás: " + String(e->monitorId) + " kaptár <-> " +
                                     String(e->tankId) + " tartály összerendelve!";
                        ntfy.send(msg.c_str(), "Szirup Párosítás OK", NtfyPriority::Default);
                        savePairsToFs();
                    }

                    // Ha elérte a tele szintet (pl. <= FULL_MM + 5mm), leállítjuk
                    if (e->currentDistanceMm <= (FEEDER_DEFAULT_FULL_MM + 5)) {
                        syrupStopRefill(e->monitorId, false);
                    }
                }
            }
        }
    }
}

SyrupState syrupGetMonitorState(const char* monitorId) {
    if (!monitorId) return SYRUP_GREEN;
    for (int i = 0; i < s_entryCount; i++) {
        if (strcmp(s_entries[i].monitorId, monitorId) == 0) {
            return s_entries[i].state;
        }
    }
    return SYRUP_GREEN;
}

SyrupState syrupGetTankState(const char* tankId) {
    if (!tankId) return SYRUP_GREEN;
    // Ha a tartályhoz tartozó bármelyik monitor villogó pirosban van, a tartály is reteszelve van
    for (int i = 0; i < s_entryCount; i++) {
        if (strcmp(s_entries[i].tankId, tankId) == 0) {
            if (s_entries[i].state == SYRUP_BLINKING_RED || s_entries[i].isPumpInterlocked) {
                return SYRUP_BLINKING_RED;
            }
        }
    }
    return SYRUP_GREEN;
}

bool syrupIsPumpAllowed(const char* tankId) {
    if (!tankId) return true;
    for (int i = 0; i < s_entryCount; i++) {
        if (strcmp(s_entries[i].tankId, tankId) == 0) {
            if (s_entries[i].state == SYRUP_BLINKING_RED || s_entries[i].isPumpInterlocked) {
                return false; // Villogó pirosnál SZIGORÚAN TILTVA
            }
        }
    }
    return true;
}

const char* syrupGetPairedTank(const char* monitorId) {
    if (!monitorId) return "";
    for (int i = 0; i < s_entryCount; i++) {
        if (strcmp(s_entries[i].monitorId, monitorId) == 0) {
            return s_entries[i].tankId;
        }
    }
    return "";
}

bool syrupIsMonitorInSztoj(const char* monitorId, uint32_t* remainingSec) {
    if (!monitorId) return false;
    uint32_t now = millis();
    for (int i = 0; i < s_entryCount; i++) {
        if (strcmp(s_entries[i].monitorId, monitorId) == 0) {
            if (s_entries[i].sztojUntilTime > now) {
                if (remainingSec) {
                    *remainingSec = (s_entries[i].sztojUntilTime - now) / 1000;
                }
                return true;
            }
        }
    }
    return false;
}

String syrupGetStatusJson() {
    JsonDocument doc;
    JsonArray arr = doc.to<JsonArray>();

    uint32_t now = millis();
    for (int i = 0; i < s_entryCount; i++) {
        JsonObject obj = arr.add<JsonObject>();
        obj["monitor_id"] = s_entries[i].monitorId;
        obj["tank_id"] = s_entries[i].tankId;
        obj["state"] = (int)s_entries[i].state;
        obj["is_refilling"] = s_entries[i].isRefilling;
        obj["auto_paired"] = s_entries[i].isAutoPaired;
        obj["interlocked"] = s_entries[i].isPumpInterlocked;
        obj["sztoj_active"] = (s_entries[i].sztojUntilTime > now);
        obj["sztoj_remaining_sec"] = (s_entries[i].sztojUntilTime > now) ? (s_entries[i].sztojUntilTime - now) / 1000 : 0;
        obj["error"] = s_entries[i].errorMessage;
    }

    String output;
    serializeJson(doc, output);
    return output;
}
