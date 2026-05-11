# wURE Lite

Jednoduchá verze wURE aplikace bez TanStack frameworku.

## Struktura

```
wure-lite/
  client/          - React frontend (Vite + TypeScript)
    src/
      App.tsx      - hlavní komponenta
      main.tsx     - entry point
      components/
        Icon.tsx
        SimpleTable.tsx  - vlastní tabulková komponenta
      styles/
        index.css
        app.css
  server/          - Express backend (Oracle)
    src/
      index.js     - API server
```

## Instalace

```bash
# Client
cd client
npm install

# Server
cd server
npm install
```

## Spuštění

```bash
# Terminal 1: Client
cd client
npm run dev

# Terminal 2: Server
cd server
npm run dev
```

Aplikace bude dostupná na `http://localhost:5173`.

## Rozdíly od wURE

- ✅ **Bez React Query** - vlastní fetch + useState
- ✅ **Bez React Table** - vlastní SimpleTable komponenta
- ✅ **Bez TanStack** - pouze React 18
- ✅ **Zjednodušená logika** - základní CRUD operace
- ✅ **Stejný backend** - Express + Oracle

## Funkčnost

- Přihlášení/Odhlášení
- Zobrazení pravidel (BESIM_RULES tabulka)
- Řazení a výběr řádků
- Stránkování (základní)
