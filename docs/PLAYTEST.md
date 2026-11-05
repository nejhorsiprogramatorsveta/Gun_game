# Testovací hraní: připojení, Tailscale a lagy

Návod pro hraní, při kterém zjišťujeme, proč se nejde připojit nebo proč se hra seká.
Hostovat bude kamarád, ostatní se připojí. Hra si sama zapisuje měření do **jednoho logu**;
po hraní nám ho každý pošle.

## Před hraním
1. Všichni spusťte hru a nechte ji aktualizovat na stejnou verzi (vlevo dole v menu, např. „Verze 0.2.8“).
   Kdo má jinou verzi, toho hra do lobby nepustí.
2. Domluvte se, jak se spojíte:
   - **stejná Wi-Fi / síť**: hostitel pošle adresu z řádku „Stejná Wi-Fi / síť“,
   - **přes internet**: všichni mají zapnutý a přihlášený **Tailscale** (návod v README) a hostitel pošle adresu z řádku „Tailscale“.
3. Hostitel klikne na **Hostovat**, v lobby zkopíruje adresu tlačítkem **Kopírovat** a pošle ji ostatním
   (třeba přes Discord). Adresa obsahuje kód hry za `#`, bez něj se nikdo nepřipojí.
4. Ostatní adresu vloží do pole „Adresa od hostitele“ a kliknou **Připojit**.
5. Ovládání ukáže tlačítko **Ovládání** v menu; klávesy jde změnit v **Nastavení**.

## Během hraní
- Každý si v lobby vybere postavu a klikne **Potvrdit postavu**; hostitel spustí zápas, až mají všichni potvrzeno.
- Klávesa **F3** zobrazí vlevo dole FPS a ping.
- Když se hra zasekne, postava „skáče“ nebo se někdo odpojí, **poznamenejte si přibližný čas** (hodiny na počítači)
  a co se stalo. Podle času to v logu najdeme.
- Zahrajte aspoň 2–3 zápasy ve **stejném lobby** (po výsledcích se vracíte do lobby, nehostujte znovu).
  Když se něco nepovede (nejde se připojit, vyhodí to), zkuste to znovu a poznamenejte si to.

## Po hraní: poslání logu
1. **Nehostujte ani se znovu nepřipojujte** – nová online hra starý log přepíše.
2. V menu klikněte na **Nastavení → Složka s logem**. Otevře se složka se souborem **`last_game.log`**.
3. Pošlete ten jeden soubor a napište k němu, kdo byl hostitel, jak jste byli připojení (Wi-Fi / Tailscale)
   a své poznámky s časy.

Hra drží vždy jen **jeden log** – z poslední online hry (od kliknutí na Hostovat/Připojit až do další hry,
max. 4 MB). Starší logy maže sama, takže se na disku nic nehromadí. Trénink log nemaže.

Kde složka je, kdyby tlačítko nefungovalo:
- Windows: `%APPDATA%\Godot\app_userdata\gun_game\logs`
- macOS: `~/Library/Application Support/Godot/app_userdata/gun_game/logs`
- Linux: `~/.local/share/godot/app_userdata/gun_game/logs`

## Co log obsahuje (a co ne)
Log **neobsahuje IP adresy ani jména hráčů** – adresy hra nahradí druhem (`<lan>`, `<tailscale>`, `<public>`),
hráče označuje číslem slotu a postavou. Každý řádek začíná časem a hlavička obsahuje i čas UTC,
takže jdou porovnat logy hostitele a hráčů:
- `[sys]` – verze hry, systém, grafická karta, obnovovací frekvence, **stav Tailscale** a druhy adres
  na síťových rozhraních, ztráta fokusu okna (Alt+Tab),
- `[conn]` – připojování: druh cílové adresy, zda je ve stejné síti, upozornění na vypnutý Tailscale,
  ověření, odmítnutí (s důvodem), doba připojení, odpojení, ping v lobby každých 10 s, postavy a týmy ve slotech,
- `[match]` – pády a zabití (podle slotů),
- `[net]` – každých 5 s zápasu: ping, ztráta paketů, datový provoz, mezery mezi aktualizacemi od hostitele,
  plynulost vzdálených hráčů, korekce pohybu, FPS, záseky a paměť; u hostitele pro každého hráče, jak plynule
  mu chodí vstupy,
- `client spike` – okamžitý záznam, když od hostitele 0,25 s nic nepřišlo,
- `ERROR` / `WARNING` – chyby hry s časem a místem v kódu.

## Pro vývojáře: jak log číst
- `ping=` je odezva vstupu (RTT + čekání na snapshot + fronta), `rtt=` je čistá síťová odezva podle ENet.
- `loss=` a `throttle=` (32/32 = plná rychlost) ukazují ztráty paketů na síti; `up/down` kB/s a `pkts_*` provoz.
- `gaps>100ms`, `gap_max`, `client spike` a `interp_holds` (snímky × vzdálení hráči bez nových dat) = sekání vzdálených hráčů.
- `hitches` a `tick_gap_max` = záseky samotného počítače (ne sítě); `window lost focus` může vysvětlit záseky na Windows.
- Hostitel: `starved` / `stalls` = od hráče nepřišly vstupy; `skipped` = hostitel dohání frontu vstupů.
- `[conn] joining ... HINT: Tailscale address, but this computer has no Tailscale address` = hráč má vypnutý Tailscale.
- `same_subnet=no` u LAN adresy = hráč není ve stejné síti (host. Wi-Fi, jiný router, mobilní data).
