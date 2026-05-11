# wURE Lite - Server

Express.js backend pro wURE Lite aplikaci. Spravuje komunikaci s Oracle databází.

## Instalace

```bash
npm install
```

## Konfiguraci

Vytvořte `.env` soubor v adresáři `server/`:

```env
PORT=3001
ORACLE_USER=besim_user
ORACLE_PASSWORD=your_password
ORACLE_CONNECT_STRING=localhost:1521/ORCL
JWT_SECRET=replace_with_long_random_secret
LOG_LEVEL=info
NODE_ENV=development
```

`LOG_LEVEL` možnosti:
- `debug` - nejpodrobnější logování
- `info` - standardní provozní logy (výchozí)
- `error` - pouze chyby
- `silent` - bez logů

## Spuštění

```bash
npm run dev    # development s nodemon
npm start      # production
```

## API Endpointy

- `GET /api/health` - zdravotní kontrola
- `POST /api/auth/login` - přihlášení
- `GET /api/auth/me` - aktuální uživatel
- `POST /api/auth/logout` - odhlášení
- `GET /api/tables` - seznam všech BESIM_* tabulek
- `GET /api/records/:table` - načtení záznamů
