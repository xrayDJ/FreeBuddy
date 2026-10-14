"""Generates lib/l10n/app_{en,pl,it}.arb from one table: key -> (en, pl, it).

Edit the table below, then run:  python3 tool/gen_arb.py
One table keeps the three languages from drifting apart.
"""
import json
import pathlib
groups = [
 [
  ("appTitle", "FreeClip Buddy", "FreeClip Buddy", "FreeClip Buddy"),
 ], [
  ("leftBudShort", "Left", "Lewa", "Sinistra"),
  ("rightBudShort", "Right", "Prawa", "Destra"),
  ("caseShort", "Case", "Etui", "Custodia"),
 ], [
  ("pageHomeDisconnected", "FreeClip 2 not connected", "FreeClip 2 nie są połączone", "FreeClip 2 non connesse"),
  ("pageHomeDisconnectedDesc", "Take the clips out of the case, or connect them in Bluetooth settings.", "Wyjmij słuchawki z etui albo połącz je w ustawieniach Bluetooth.", "Togli le clip dalla custodia, oppure collegale dalle impostazioni Bluetooth."),
  ("pageHomeDisconnectedOpenSettings", "Open Bluetooth settings", "Otwórz ustawienia Bluetooth", "Apri impostazioni Bluetooth"),
  ("pageHomeConnecting", "Connecting…", "Łączenie…", "Connessione…"),
  ("pageHomeUnknown", "Unknown state", "Nieznany stan", "Stato sconosciuto"),
  ("pageHomeNoPermission", "The app needs Bluetooth permission to talk to your clips", "Aplikacja potrzebuje uprawnienia Bluetooth, aby rozmawiać ze słuchawkami", "L'app ha bisogno del permesso Bluetooth per comunicare con le clip"),
  ("pageHomeNoPermissionGrant", "Grant permission", "Przyznaj uprawnienie", "Concedi permesso"),
  ("pageHomeNoPermissionOpenSettings", "Open settings to grant it", "Otwórz ustawienia, aby je przyznać", "Apri le impostazioni per concederlo"),
  ("pageHomeBluetoothDisabled", "Bluetooth is off", "Bluetooth jest wyłączony", "Il Bluetooth è spento"),
  ("pageHomeBluetoothDisabledEnable", "Turn on", "Włącz", "Accendi"),
  ("pageHomeBluetoothDisabledOpenSettings", "Open Bluetooth settings", "Otwórz ustawienia Bluetooth", "Apri impostazioni Bluetooth"),
  ("pageHomeNotPaired", "No HUAWEI FreeClip 2 paired with this phone", "Brak sparowanych HUAWEI FreeClip 2", "Nessuna HUAWEI FreeClip 2 associata a questo telefono"),
  ("pageHomeNotPairedPairOpenSettings", "Pair them in Bluetooth settings", "Sparuj je w ustawieniach Bluetooth", "Associale dalle impostazioni Bluetooth"),
  ("pageHomeConnectedClosed", "Another app is talking to your clips", "Inna aplikacja rozmawia ze słuchawkami", "Un'altra app sta comunicando con le clip"),
  ("pageHomeConnectedClosedDesc", "Probably HUAWEI AI Life. Only one app at a time can do it - close it and connect again.", "Pewnie HUAWEI AI Life. Tylko jedna aplikacja naraz może to robić - zamknij ją i połącz ponownie.", "Probabilmente HUAWEI AI Life. Solo un'app alla volta può farlo: chiudila e riconnetti."),
  ("pageHomeConnectedClosedConnect", "Connect", "Połącz", "Connetti"),
  ("autoPause", "Auto pause", "Automatyczna pauza", "Pausa automatica"),
  ("autoPauseDesc", "Pause music when you take a clip off", "Wstrzymaj muzykę, gdy zdejmiesz słuchawkę", "Metti in pausa la musica quando togli una clip"),
 ], [
  ("pageHeadphonesSettingsTitle", "FreeClip 2 settings", "Ustawienia FreeClip 2", "Impostazioni FreeClip 2"),
  ("pageHeadphonesSettingsDoubleTap", "Double tap", "Podwójne dotknięcie", "Doppio tocco"),
  ("pageHeadphonesSettingsDoubleTapPlayPause", "Play/Pause", "Odtwórz/Pauza", "Riproduci/Pausa"),
  ("pageHeadphonesSettingsDoubleTapNextSong", "Next song", "Następny utwór", "Brano successivo"),
  ("pageHeadphonesSettingsDoubleTapPrevSong", "Previous song", "Poprzedni utwór", "Brano precedente"),
  ("pageHeadphonesSettingsDoubleTapAssist", "Voice assistant", "Asystent głosowy", "Assistente vocale"),
  ("pageHeadphonesSettingsDoubleTapNone", "Nothing", "Nic", "Nessuna azione"),
  ("pageHeadphonesSettingsLeftBud", "Left clip", "Lewa słuchawka", "Clip sinistra"),
  ("pageHeadphonesSettingsRightBud", "Right clip", "Prawa słuchawka", "Clip destra"),
  ("pageHeadphonesSettingsHold", "Touch and hold", "Przytrzymanie", "Tocco prolungato"),
 ], [
  ("freeClip2SectionGestures", "Gestures", "Gesty", "Gesti"),
  ("freeClip2SectionSound", "Sound", "Dźwięk", "Audio"),
  ("freeClip2SectionGeneral", "General", "Ogólne", "Generali"),
  ("freeClip2TripleTap", "Triple tap", "Potrójne dotknięcie", "Triplo tocco"),
  ("freeClip2BothBuds", "Both clips", "Obie słuchawki", "Entrambe le clip"),
  ("freeClip2Waiting", "Waiting for the clips…", "Czekam na słuchawki…", "In attesa delle clip…"),
  ("freeClip2VolumeUp", "Volume up", "Głośniej", "Alza volume"),
  ("freeClip2VolumeDown", "Volume down", "Ciszej", "Abbassa volume"),
  ("gestureActionUnknown", "Unknown action ({code})", "Nieznana akcja ({code})", "Azione sconosciuta ({code})"),
  ("freeClip2Swipe", "Swipe", "Przesunięcie", "Scorrimento"),
  ("freeClip2SwipeDesc", "Swipe up or down on a clip to:", "Przesuń palcem w górę lub w dół po słuchawce, aby:", "Scorri in su o in giù su una clip per:"),
  ("freeClip2SwipeVolume", "Change volume", "Zmienić głośność", "Regolare il volume"),
  ("freeClip2DoubleTapInCall", "Double tap during calls", "Podwójne dotknięcie podczas rozmów", "Doppio tocco durante le chiamate"),
  ("freeClip2HoldInCall", "Touch and hold during calls", "Przytrzymanie podczas rozmów", "Tocco prolungato durante le chiamate"),
  ("freeClip2InCallAnswer", "Answer / end call", "Odbierz / zakończ", "Rispondi / chiudi"),
  ("freeClip2DualConnect", "Dual connection", "Podwójne połączenie", "Doppia connessione"),
  ("freeClip2DualConnectDesc", "Stay connected to two devices at once", "Pozostań połączony z dwoma urządzeniami jednocześnie", "Resta connesso a due dispositivi insieme"),
  ("freeClip2LowLatency", "Low latency", "Niskie opóźnienie", "Bassa latenza"),
  ("freeClip2LowLatencyDesc", "For games and video - may reduce range and stability", "Do gier i wideo - może zmniejszyć zasięg i stabilność", "Per giochi e video: può ridurre portata e stabilità"),
  ("freeClip2SoundQuality", "Sound quality preference", "Preferencja jakości dźwięku", "Preferenza qualità audio"),
  ("freeClip2SoundQualityDesc", "Prefer a stable connection or better audio quality", "Priorytet dla stabilnego połączenia lub lepszej jakości dźwięku", "Privilegia una connessione stabile o una qualità audio migliore"),
  ("freeClip2SoundQualityConnectivity", "Prioritise connection", "Priorytet: połączenie", "Priorità alla connessione"),
  ("freeClip2SoundQualityQuality", "Prioritise sound quality", "Priorytet: jakość dźwięku", "Priorità alla qualità audio"),
 ], [
  ("settings", "Settings", "Ustawienia", "Impostazioni"),
  ("diagnosticsTitle", "Diagnostics", "Diagnostyka", "Diagnostica"),
  ("diagnosticsDesc", "Raw Bluetooth traffic, to debug gestures and settings", "Surowy ruch Bluetooth, do debugowania gestów i ustawień", "Traffico Bluetooth grezzo, per capire gesti e impostazioni"),
  ("diagnosticsCopy", "Copy log", "Kopiuj log", "Copia log"),
  ("diagnosticsCopied", "Copied to clipboard", "Skopiowano do schowka", "Copiato negli appunti"),
  ("diagnosticsReread", "Read everything again", "Odczytaj wszystko ponownie", "Rileggi tutto"),
  ("diagnosticsDeviceInfo", "Device", "Urządzenie", "Dispositivo"),
  ("diagnosticsNoInfo", "Not reported yet", "Jeszcze nie zgłoszono", "Non ancora ricevuto"),
  ("diagnosticsSend", "Send a command", "Wyślij komendę", "Invia un comando"),
  ("diagnosticsSendDesc", "Service and command: decimal or 0x hex. Params: id=hex bytes, e.g. \"1=ff 2=\" (empty value = read request).", "Usługa i komenda: dziesiętnie lub hex z 0x. Parametry: id=bajty hex, np. \"1=ff 2=\" (pusta wartość = odczyt).", "Servizio e comando: decimale o esadecimale con 0x. Parametri: id=byte esadecimali, es. \"1=ff 2=\" (valore vuoto = lettura)."),
  ("diagnosticsService", "Service", "Usługa", "Servizio"),
  ("diagnosticsCommand", "Command", "Komenda", "Comando"),
  ("diagnosticsParams", "Params", "Parametry", "Parametri"),
  ("diagnosticsSendBtn", "Send", "Wyślij", "Invia"),
  ("diagnosticsTraffic", "Traffic ({count} packets, newest first, tap to copy)", "Ruch ({count} pakietów, najnowsze na górze, dotknij, by skopiować)", "Traffico ({count} pacchetti, più recenti in alto, tocca per copiare)"),
  ("diagnosticsEmpty", "No packets yet", "Brak pakietów", "Ancora nessun pacchetto"),
  ("diagnosticsWriteReply", "write reply", "odpowiedź na zapis", "risposta alla scrittura"),
 ], [
  ("pageAboutTitle", "About", "O aplikacji", "Informazioni"),
  ("pageAboutVersion", "Version {version}", "Wersja {version}", "Versione {version}"),
  ("pageAboutIntro", "An open source companion app for HUAWEI FreeClip 2. No account, no ads, no tracking.", "Otwartoźródłowa aplikacja dla HUAWEI FreeClip 2. Bez konta, bez reklam, bez śledzenia.", "App open source per le HUAWEI FreeClip 2. Niente account, niente pubblicità, niente tracciamento."),
  ("pageAboutSource", "Source code", "Kod źródłowy", "Codice sorgente"),
  ("pageAboutCredits", "Built on the work of", "Zbudowane na pracy", "Basata sul lavoro di"),
  ("pageAboutCreditsFreeBuddy", "FreeBuddy by TheLastGimbus - the app this one is forked from", "FreeBuddy autorstwa TheLastGimbus - aplikacja, z której powstał ten fork", "FreeBuddy di TheLastGimbus, l'app da cui nasce questo fork"),
  ("pageAboutCreditsOpenFreebuds", "OpenFreebuds by melianmiko - the FreeClip 2 protocol details", "OpenFreebuds autorstwa melianmiko - szczegóły protokołu FreeClip 2", "OpenFreebuds di melianmiko, da cui viene il protocollo delle FreeClip 2"),
  ("pageAboutLicense", "Licensed under GPL-3.0, like both projects above.", "Licencja GPL-3.0, jak oba powyższe projekty.", "Licenza GPL-3.0, come entrambi i progetti sopra."),
  ("privacyPolicyTitle", "Privacy", "Prywatność", "Privacy"),
  ("privacyPolicyText", "This app collects nothing. There is no server and no analytics: everything stays between your phone and your clips.", "Ta aplikacja niczego nie zbiera. Nie ma serwera ani analityki: wszystko zostaje między telefonem a słuchawkami.", "Questa app non raccoglie nulla. Non c'è nessun server e nessuna analisi: tutto resta tra il telefono e le clip."),
  ("pageAboutOpenSourceLicensesBtn", "Open source licenses", "Licencje open source", "Licenze open source"),
 ], [
  ("pageIntroTitle", "Welcome to FreeClip Buddy", "Witaj w FreeClip Buddy", "Benvenuto in FreeClip Buddy"),
  ("pageIntroWhatIsThis", "Battery, gestures and settings of your HUAWEI FreeClip 2, without HUAWEI AI Life.", "Bateria, gesty i ustawienia HUAWEI FreeClip 2, bez HUAWEI AI Life.", "Batteria, gesti e impostazioni delle tue HUAWEI FreeClip 2, senza HUAWEI AI Life."),
  ("pageIntroPrivacy", "No account, no data collected. Everything stays on your phone.", "Bez konta i bez zbierania danych. Wszystko zostaje na telefonie.", "Nessun account, nessun dato raccolto. Tutto resta sul telefono."),
  ("pageIntroTip", "Tip: only one app at a time can talk to the clips. If nothing loads, close HUAWEI AI Life.", "Wskazówka: tylko jedna aplikacja naraz może rozmawiać ze słuchawkami. Jeśli nic się nie ładuje, zamknij HUAWEI AI Life.", "Suggerimento: solo un'app alla volta può comunicare con le clip. Se non si carica nulla, chiudi HUAWEI AI Life."),
  ("pageIntroQuit", "Let's go", "Zaczynamy", "Iniziamo"),
 ],
]
meta = {
  "gestureActionUnknown": {"placeholders": {"code": {"type": "int"}}},
  "diagnosticsTraffic": {"placeholders": {"count": {"type": "int"}}},
  "pageAboutVersion": {"placeholders": {"version": {"type": "String"}}},
}
out_dir = pathlib.Path(__file__).resolve().parent.parent / "lib" / "l10n"
keys = [k for g in groups for (k, *_) in g]
assert len(keys) == len(set(keys)), "duplicate key"
for i, lang in enumerate(["en", "pl", "it"]):
    parts = []
    for g in groups:
        lines = [f"  {json.dumps(k)}: {json.dumps(t[i], ensure_ascii=False)}" for (k, *t) in g]
        if lang == "en":
            lines += [f"  {json.dumps('@' + k)}: {json.dumps(m)}" for k, m in meta.items() if k in [x[0] for x in g]]
        parts.append(",\n".join(lines))
    text = "{\n" + ",\n\n".join(parts) + "\n}\n"
    json.loads(text)
    open(out_dir / f"app_{lang}.arb", "w", encoding="utf-8").write(text)
print(len(keys), "keys x 3 languages")
