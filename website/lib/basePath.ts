export const BASE_PATH = "/NammaNanban";

export function withBasePath(path: string) {
  if (!BASE_PATH) {
    return path;
  }

  if (path === "/") {
    return BASE_PATH;
  }

  return `${BASE_PATH}${path}`;
}

export function stripBasePath(pathname: string) {
  if (!BASE_PATH || !pathname.startsWith(BASE_PATH)) {
    return pathname || "/";
  }

  const strippedPath = pathname.slice(BASE_PATH.length);
  return strippedPath || "/";
}
