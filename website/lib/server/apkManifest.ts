import fs from "node:fs";
import path from "node:path";

import { withBasePath } from "@/lib/basePath";

const DEFAULT_APK_FILE_NAME = "NammaNanban.apk";
const PREFERRED_APK_FILE_NAMES = ["mobilepos-latest.apk", DEFAULT_APK_FILE_NAME];
const PUBLIC_APK_DIR = path.join(process.cwd(), "public", "apk");

function pickApkFileName(apkFiles: string[]) {
  if (apkFiles.length === 0) {
    return DEFAULT_APK_FILE_NAME;
  }

  for (const preferredFileName of PREFERRED_APK_FILE_NAMES) {
    if (apkFiles.includes(preferredFileName)) {
      return preferredFileName;
    }
  }

  return apkFiles.sort((left, right) => left.localeCompare(right))[0];
}

export function getStaticApk() {
  try {
    const apkFiles = fs
      .readdirSync(PUBLIC_APK_DIR, { withFileTypes: true })
      .filter((entry) => entry.isFile() && entry.name.toLowerCase().endsWith(".apk"))
      .map((entry) => entry.name);

    const fileName = pickApkFileName(apkFiles);

    return {
      fileName,
      downloadPath: withBasePath(`/apk/${encodeURIComponent(fileName)}`),
    };
  } catch {
    return {
      fileName: DEFAULT_APK_FILE_NAME,
      downloadPath: withBasePath(`/apk/${encodeURIComponent(DEFAULT_APK_FILE_NAME)}`),
    };
  }
}
