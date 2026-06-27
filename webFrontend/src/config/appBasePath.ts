const DEFAULT_APP_BASE_PATH = '/webapp'

const normalizeAppBasePath = (value: string | undefined) => {
  const trimmed = value?.trim()
  if (!trimmed) {
    return DEFAULT_APP_BASE_PATH
  }

  const normalized = trimmed.replace(/^\/+|\/+$/g, '')
  return normalized ? `/${normalized}` : '/'
}

export const appBasePath = normalizeAppBasePath(import.meta.env.VITE_APP_BASE_PATH)
export const appBaseUrl = appBasePath === '/' ? '/' : `${appBasePath}/`
