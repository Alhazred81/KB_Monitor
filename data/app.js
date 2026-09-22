// --- MÓD KAPCSOLÓ (SETUP / FIELD) ---
function toggleMode() {
  const isSetup = document.getElementById("setupToggle").checked;
  const mode = isSetup ? "setup" : "field";

  document.getElementById("labelSetup").classList.toggle("active", isSetup);
  document.getElementById("labelField").classList.toggle("active", !isSetup);

  fetch("/api/set_mode", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ mode: mode }),
  })
    .then((res) => res.json())
    .then((data) => {
      if (data.status !== "ok") alert("Hiba a mód mentésekor!");
    })
    .catch((err) => console.error("Hálózati hiba:", err));
}

// --- SEGÉDFÜGGVÉNYEK ---
function getColor(rssi) {
  if (rssi === 0 || rssi === undefined) return "var(--txt)";
  return rssi > -70 ? "var(--ok)" : rssi > -85 ? "var(--warn)" : "var(--err)";
}

// --- FŐ CIKLUS ---
document.addEventListener("DOMContentLoaded", () => {
  // 1. Setup / Field mód állapotának betöltése
  if (document.getElementById("setupToggle")) {
    fetch("/api/get_mode")
      .then((res) => res.json())
      .then((data) => {
        const isSetup = data.mode === "setup";
        document.getElementById("setupToggle").checked = isSetup;
        document
          .getElementById("labelSetup")
          .classList.toggle("active", isSetup);
        document
          .getElementById("labelField")
          .classList.toggle("active", !isSetup);
      })
      .catch((e) => console.log("Nem sikerült lekérni a módot.", e));
  }

  // 2. Beállítások betöltése (eredeti kód)
  fetch("/api/config")
    .then((response) => response.json())
    .then((data) => {
      if (document.getElementById("apPass")) {
        document.getElementById("apPass").value = data.apPass || "";
      }
      if (document.getElementById("ntfyTopic")) {
        document.getElementById("ntfyTopic").value = data.ntfyTopic || "";
      }
      if (document.getElementById("ntfyNickname")) {
        document.getElementById("ntfyNickname").value = data.ntfyNickname || "";
      }
    })
    .catch((err) => console.error("Hiba a konfiguráció betöltésekor: ", err));

  // 3. Mentés eseménykezelője (eredeti kód)
  const btnSave = document.getElementById("btnSave");
  if (btnSave) {
    btnSave.addEventListener("click", () => {
      btnSave.disabled = true;
      btnSave.innerText = "Mentés...";

      const payload = {
        apPass: document.getElementById("apPass")
          ? document.getElementById("apPass").value
          : "",
        ntfyTopic: document.getElementById("ntfyTopic")
          ? document.getElementById("ntfyTopic").value
          : "",
        ntfyNickname: document.getElementById("ntfyNickname")
          ? document.getElementById("ntfyNickname").value
          : "",
      };

      fetch("/api/config", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      })
        .then((res) => res.json())
        .then((data) => {
          if (data.status === "ok") {
            alert("Beállítások elmentve.");
          } else {
            alert("Hiba a mentés során.");
          }
        })
        .catch((err) => {
          console.error(err);
          alert("Hálózati hiba mentéskor.");
        })
        .finally(() => {
          btnSave.disabled = false;
          btnSave.innerText = "Mentés";
        });
    });
  }

  // 4. Ntfy teszt eseménykezelője (eredeti kód)
  const btnTestNtfy = document.getElementById("btnTestNtfy");
  if (btnTestNtfy) {
    btnTestNtfy.addEventListener("click", () => {
      const prio = parseInt(document.getElementById("testPriority").value) || 3;
      btnTestNtfy.disabled = true;
      btnTestNtfy.innerText = "Küldés folyamatban...";

      fetch("/api/test-ntfy", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ priority: prio }),
      })
        .then((res) => res.json())
        .then((data) => {
          if (data.status === "ok") {
            alert("Az értesítés sikeresen átment a modemen.");
          } else {
            alert(
              "Hiba történt az elküldés során. Ellenőrizd a modem logokat.",
            );
          }
        })
        .catch((err) => {
          console.error(err);
          alert("Hálózati hiba a szerverrel való kommunikációban.");
        })
        .finally(() => {
          btnTestNtfy.disabled = false;
          btnTestNtfy.innerText = "Teszt Üzenet Küldése";
        });
    });
  }

  // 5. Valós idejű műszerfal frissítő (RSSI és szenzorok)
  function updateDashboard() {
    fetch("/data")
      .then((res) => res.json())
      .then((d) => {
        // Ha létezik TX/RX RSSI mező a HTML-ben, beállítjuk az értéket és a színt
        const elTxRssi = document.getElementById("tx_rssi");
        if (elTxRssi && d.tx_rssi !== undefined) {
          elTxRssi.innerText = d.tx_rssi + " dBm";
          elTxRssi.style.color = getColor(d.tx_rssi);
        }

        const elRxRssi = document.getElementById("rx_rssi");
        if (elRxRssi && d.rx_rssi !== undefined) {
          elRxRssi.innerText = d.rx_rssi + " dBm";
          elRxRssi.style.color = getColor(d.rx_rssi);
        }
      })
      .catch((e) =>
        console.log(
          "Dashboard fetch hiba (lehet, hogy még nem létezik a végpont):",
          e,
        ),
      );
  }

  // Csak akkor indítjuk a folyamatos lekérdezést, ha olyan oldalon vagyunk, ahol szükség van rá
  if (
    document.getElementById("statusArea") ||
    document.getElementById("tx_rssi")
  ) {
    setInterval(updateDashboard, 5000);
    updateDashboard();
  }
});
