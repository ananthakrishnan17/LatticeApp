# NammaNanban Web Frontend

## Local development

```bash
npm install
npm run dev
```

During local Vite development, API requests are sent directly to the configured
backend base URL (`VITE_API_BASE_URL`, then `http://localhost:8080`). Ensure
your backend CORS settings allow requests from the frontend origin.

The app base path is configurable through `VITE_APP_BASE_PATH`. This repository's
production build defaults to `/webapp`, and `.env.production` points API requests
to `http://18.60.200.156`.

## Validation

```bash
npm run lint
npm run build
```

## Tomcat deployment

Build a Tomcat-ready webapp inside `webFrontend/src/main/webapp`:

```bash
npm run build:tomcat
```

Then deploy `webFrontend/src/main/webapp` as an exploded webapp (or package it as a WAR) in Tomcat.
Use Tomcat 10+ (Jakarta EE namespace).
Deploy it under the context path configured by `VITE_APP_BASE_PATH` (currently `/webapp` in `.env.production`).

`public/WEB-INF/web.xml` is copied into the build output so Tomcat serves `index.html` as the SPA entry page.

## Static-only deployment notes

- This module is the supported path for Tomcat static WAR deployment.
- Do not use `website` admin routes (`/admin`, `/admin/login`, `/api/admin/*`) in static-only hosting.
