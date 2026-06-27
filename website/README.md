# NammaNanban Website (Next.js)

## Run locally

```bash
npm install
npm run dev
```

## Validation

```bash
npm run lint
npm run build
```

## Static APK management

- Keep your deployable APK file inside `website/public/apk/`.
- During the static build, the download page automatically links to the APK found in that folder.
- If multiple APK files exist, the build prefers `mobilepos-latest.apk`, then `NammaNanban.apk`, then the first APK name alphabetically.
- Replace the APK, rebuild, and redeploy to publish a new version.

## Environment variables

- `NEXT_PUBLIC_GA_MEASUREMENT_ID` - Enables GA4 page/event tracking.
- `NEXT_PUBLIC_CONTACT_FORM_ENDPOINT` - Optional custom contact endpoint for static deployments.

## Deployment notes

Build a Tomcat-ready static export:

```bash
npm run build:tomcat
```

After build, static files are generated in `website/out`.

Create and deploy WAR from `website/out`:

```bash
cd out
jar -cvf NammaNanban.war .
cp NammaNanban.war <tomcat>/webapps/
```

After deployment the APK download URL is:

`/NammaNanban/apk/<your-apk-file>.apk`

Example Nginx location:

```nginx
location /apk/ {
  types { application/vnd.android.package-archive apk; }
  add_header Content-Disposition "attachment";
}
```
