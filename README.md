# TanStack Start - Basic Example

This is the basic TanStack Start example, demonstrating the fundamentals of building applications with TanStack Router and TanStack Start.

- [TanStack Router Docs](https://tanstack.com/router)

It is configured for automatic deployment to a VPS via GitHub Actions.

The current workflow builds the app in GitHub Actions, uploads the production artifacts to the VPS over SSH, and restarts the `pm2` process.

## Automatic deploy

Required GitHub repository secrets:

- `SSH_HOST` - the VPS host, for example `46.28.108.112`
- `SSH_USER` - SSH user on the VPS
- `SSH_PRIVATE_KEY` - private key authorized on the VPS

The workflow expects the application artifacts to live in `/var/www/server` on the VPS and to be managed by `pm2` under the process name `server`.

On the server, make sure these tools are installed:

- `node.js` with `npm`
- `pm2`

The first deployment will create `/var/www/server`, upload the built `.output` directory plus `package.json`, and start or restart the `pm2` process.

If `pm2` is not installed yet, install it once on the VPS with:

```sh
npm install -g pm2
```

## Start a new project based on this example

To start a new project based on this example, run:

```sh
npx gitpick TanStack/router/tree/main/examples/react/start-basic start-basic
```

## Getting Started

From your terminal:

```sh
pnpm install
pnpm dev
```

This starts your app in development mode, rebuilding assets on file changes.

## Build

To build the app for production:

```sh
pnpm build
```
