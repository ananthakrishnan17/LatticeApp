import DownloadPageClient from "@/app/download/DownloadPageClient";
import { getStaticApk } from "@/lib/server/apkManifest";

export default function DownloadPage() {
  const apk = getStaticApk();

  return <DownloadPageClient apkDownloadPath={apk.downloadPath} apkFileName={apk.fileName} />;
}
