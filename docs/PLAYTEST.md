# Testovací hraní: připojení a lagy

Návod pro hraní, při kterém zjišťujeme, proč se nejde připojit nebo proč se hra seká.
Hostovat bude kamarád, ostatní se připojí. Hra si sama zapisuje měření do záznamu (logu);
po hraní nám každý pošle svůj log.

## Před hraním
1. Všichni spusťte hru a nechte ji aktualizovat na stejnou verzi (vlevo dole v menu, např. „Verze 0.2.7“).
   Kdo má jinou verzi, toho hra do lobby nepustí.
2. Domluvte se, jak se spojíte:
   - **stejná Wi-Fi / síť**: hostitel pošle adresu z řádku „Stejná Wi-Fi / síť“,
   - **přes internet**: všichni mají zapnutý Tailscale (návod v README) a hostitel pošle adresu z řádku „Tailscale“.
3. Hostitel klikne na **Hostovat**, v lobby zkopíruje adresu tlačítkem **Kopírovat** a pošle ji ostatním
   (třeba přes Discord). Adresa obsahuje kód hry za `#`, bez něj se nikdo nepřipojí.
4. Ostatní adresu vloží do pole „Adresa od hostitele“ a kliknou **Připojit**.

## Během hraní
- Každý si v lobby vybere postavu a klikne **Potvrdit postavu**; hostitel spustí zápas, až mají všichni potvrzeno.
- Klávesa **F3** zobrazí vlevo dole FPS a ping.
- Když se hra zasekne, postava „skáče“ nebo se někdo odpojí, **poznamenejte si přibližný čas** (hodiny na počítači)
  a co se stalo. Podle času to v logu najdeme.
- Zahrajte aspoň 2–3 zápasy. Když se něco nepovede (nejde se připojit, vyhodí to), zkuste to znovu a poznamenejte si to.

## Po hraní: poslání logů
1. V hlavním menu klikněte na **Složka s logy**. Otevře se složka se soubory `godot.log`.
2. Pošlete **nejnovější `godot.log`**. Pokud jste hru během hraní zavřeli a znovu spustili,
   pošlete i starší soubory `godot<datum>.log` z doby hraní (hra jich drží 10).
3. Napište k tomu, kdo byl hostitel, jak jste byli připojení (Wi-Fi / Tailscale) a své poznámky s časy.

Kde složka je, kdyby tlačítko nefungovalo:
- Windows: `%APPDATA%\Godot\app_userdata\gun_game\logs`
- macOS: `~/Library/Application Support/Godot/app_userdata/gun_game/logs`
- Linux: `~/.local/share/godot/app_userdata/gun_game/logs`

## Co log obsahuje (a co ne)
Log **neobsahuje IP adresy ani jména hráčů** – adresy hra nahradí druhem (`<lan>`, `<tailscale>`, `<public>`).
Každý řádek začíná časem, takže jdou porovnat logy hostitele a hráčů:
- `[sys]` – verze hry, systém, grafická karta, obnovovací frekvence monitoru,
- `[conn]` – připojování: druh adresy, ověření, odmítnutí (s důvodem), jak dlouho trvalo připojení, odpojení,
- `[net]` – každých 5 s zápasu: ping, ztráta paketů, mezery mezi aktualizacemi od hostitele, korekce pohybu,
  FPS a záseky hry; u hostitele pro každého hráče to, jak plynule mu chodí vstupy,
- `client spike` – okamžitý záznam, když od hostitele 0,25 s nic nepřišlo.

## Pro vývojáře: jak log číst
- `client ... rtt=` je síťová odezva podle ENet, `ping=` je odezva vstupu (RTT + čekání na snapshot + fronta).
- `loss=` a `throttle=` (32/32 = plná rychlost) ukazují ztráty paketů na síti.
- `gaps>100ms`, `gap_max` a `client spike` = sekání vzdálených hráčů (pozdě doručené snapshoty).
- `hitches` a `tick_gap_max` = záseky samotného počítače (ne sítě).
- Hostitel: `starved` / `stalls` = od hráče nepřišly vstupy; `skipped` = hostitel dohání frontu vstupů.
