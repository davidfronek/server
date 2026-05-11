# wURE Lite - Client

React + Vite + TypeScript frontend bez TanStack.

## Instalace

```bash
npm install
```

## Vývoj

```bash
npm run dev
```

Aplikace se spustí na `http://localhost:5173`.

## Build

```bash
npm run build
```

## Architektura

- **App.tsx** - hlavní komponenta, stav management
- **components/SimpleTable.tsx** - vlastní tabulka bez React Table
- **components/Icon.tsx** - SVG ikony
- **styles/** - CSS pro UI

## Vlastnosti

- Jednoduché state management (useState + useEffect)
- Fetch API pro komunikaci se serverem
- Řazení tabulky kliknutím na hlavičku
- Výběr více řádků
- Responsive design
