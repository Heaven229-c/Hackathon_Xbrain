# DocHub AI Frontend

React + TypeScript + Vite frontend for the W7 DocHub AI demo.

## Setup

```bash
npm install
copy .env.example .env
npm run dev
```

Set `VITE_API_URL` to the deployed API Gateway stage URL.

## Checks

```bash
npm run lint
npm run build
```

The UI primitives in `src/components/ui` are generated component wrappers, so the Fast Refresh export-only rule is disabled for that folder in `eslint.config.js`.
