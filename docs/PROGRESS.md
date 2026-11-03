# Stav projektu

## Kde jsme skončili
Milník M0 je hotový:
- plán je schválený ([docs/PLAN.md](PLAN.md));
- vývojové prostředí je připravené (`tools/setup_env.sh` stáhne Godot do `.tools/`, verze 4.7.2).

Rozpracováno: nic.
Git repozitář: zatím neexistuje. Vytvoří se v M1.

## Další krok
**Celý milník M1** podle promptu **P1** v [docs/PLAN.md](PLAN.md) (sekce P):
- kostra projektu
- lokální pohyb
- CI se ZIP buildy

Než začneš, ověř, že `tools/godot --version` vrací 4.7.2. Uživatel musí mít GitHub repo (veřejné) nebo přihlášený `gh`. Pokud nic z toho není, zeptej se.

## Aktuální stav
- **Milník:** M0
- **Funguje:** lokální Godot 4.7.2 přes `tools/godot` (ověřeno na macOS arm64).
- **Hra:** zatím nic.

## Poslední změny
- **2026-11-03:**
  - vytvořen `docs/PLAN.md`;
  - přidány `tools/setup_env.sh` a `tools/godot` (připnutý Godot v `.tools/`, kontrola SHA512), `.gitignore` (`.tools/`), `CLAUDE.md` a tento soubor;
  - zapsán protokol „přečti si progress a pokračuj“ (CLAUDE.md).

## Co je potřeba udělat
1. M1: kostra projektu, lokální pohyb, CI build se ZIPy.
2. M2: síťové jádro (lobby, handshake, synchronizace pohybu).
3. M3: souboj = MVP (`v0.1.0`).

Ostatní milníky viz PLAN.md, sekce K.

## Známé problémy
- `gh` CLI není nainstalované. Je potřeba buď pro vytvoření repa, nebo pro ruční release.
- Otevřené otázky: veřejné repo? Veřejná IPv4, nebo CGNAT u hostitele? (PLAN.md, sekce O)

## Stav testů
- `tools/setup_env.sh` a `tools/godot --headless --version` → `4.7.2.stable.official.ed1daf0bf` (macOS arm64).
- Hra zatím netestována (neexistuje).

## Rozhodnutí
- **Godot 4.7.2 + GDScript:** nejmenší buildy, export všech platforem z Linuxu.
- **Připnutý Godot v `.tools/` místo venv:** projekt nemá Python ani jiné závislosti, jedinou závislostí je engine.
- **Host-autoritativní listen server, ENet:** jednoduché, bez serveru.
- **Vlastní snapshot 30 Hz místo MultiplayerSynchronizer:** kontrola nad interpolací a velikostí zpráv.
- **MVP připojení:** IP + UPnP, záloha Tailscale, později noray kódy.
- **Rolling prerelease tag `dev`** (ne `latest`), protože /releases/latest ukazuje jen stabilní verze.
- **Hlavní platforma Windows:** kamarádi hrají hlavně na Windows. macOS build je v CI, testy jen podle možností.
