import type { IncomingMessage } from 'node:http'
import { defineConfig, loadEnv, type ProxyOptions } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

const DEV_PROXY_SUFFIX = '/__nn_dev_proxy__'
const BACKEND_API_PATHS = [
  '/auth',
  '/products',
  '/categories',
  '/customers',
  '/bills',
  '/users',
  '/owner',
  '/subscription',
  '/transactions',
  '/ec',
  '/swagger-ui',
  '/api-docs',
  '/actuator',
]
const DEFAULT_BACKEND_TARGET = 'http://localhost:8080'
const DEFAULT_APP_BASE_PATH = '/webapp'
const PROXY_TARGET_HEADER = 'x-nn-proxy-target'

const normalizeProxyTarget = (value: string) => value.trim().replace(/\/+$/, '')
const escapeRegExp = (value: string) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
const normalizeAppBasePath = (value: string | undefined) => {
  const trimmed = value?.trim()
  if (!trimmed) {
    return DEFAULT_APP_BASE_PATH
  }

  const normalized = trimmed.replace(/^\/+|\/+$/g, '')
  return normalized ? `/${normalized}` : '/'
}

const resolveDevProxyPrefixes = (appBasePath: string) =>
  appBasePath === '/' ? [DEV_PROXY_SUFFIX] : [DEV_PROXY_SUFFIX, `${appBasePath}${DEV_PROXY_SUFFIX}`]

const sanitizeProxyTarget = (value: string | string[] | undefined) => {
  const candidate = Array.isArray(value) ? value[0] : value
  if (!candidate) {
    return null
  }

  try {
    const url = new URL(candidate)
    if (!['http:', 'https:'].includes(url.protocol)) {
      return null
    }

    url.pathname = ''
    url.search = ''
    url.hash = ''
    return normalizeProxyTarget(url.toString())
  } catch {
    return null
  }
}

const createProxyOptions = (backendTarget: string): ProxyOptions => ({
  target: backendTarget,
  changeOrigin: true,
  configure: (proxy) => {
    proxy.on('proxyReq', (proxyReq) => {
      proxyReq.removeHeader('origin')
    })
  },
})

const createDynamicProxyOptions = (backendTarget: string, proxyPrefix: string): ProxyOptions =>
  ({
    target: backendTarget,
    changeOrigin: true,
    rewrite: (path) => path.replace(new RegExp(`^${escapeRegExp(proxyPrefix)}`), ''),
    router: (request: IncomingMessage) => sanitizeProxyTarget(request.headers[PROXY_TARGET_HEADER]) ?? backendTarget,
    configure: (proxy) => {
      proxy.on('proxyReq', (proxyReq) => {
        proxyReq.removeHeader('origin')
        proxyReq.removeHeader(PROXY_TARGET_HEADER)
      })
    },
  } as ProxyOptions)

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const backendTarget = normalizeProxyTarget(env.VITE_DEV_PROXY_TARGET || env.VITE_API_BASE_URL || DEFAULT_BACKEND_TARGET)
  const appBasePath = normalizeAppBasePath(env.VITE_APP_BASE_PATH)
  const devProxyPrefixes = resolveDevProxyPrefixes(appBasePath)

  return {
    base: appBasePath === '/' ? '/' : `${appBasePath}/`,
    plugins: [react(), tailwindcss()],
    build: {
      outDir: 'out',
    },
    server: {
      proxy: Object.fromEntries(
        [
          ...devProxyPrefixes.map((prefix) => [prefix, createDynamicProxyOptions(backendTarget, prefix)] as const),
          ...BACKEND_API_PATHS.map((path) => [
            path,
            createProxyOptions(backendTarget),
          ]),
        ],
      ),
    },
  }
})
