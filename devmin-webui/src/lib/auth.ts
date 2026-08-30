export type RunMode = 'local' | 'localDocker' | 'server'

export type AppRow = {
  stem: string
  stack: string
  app: string
  apiApp: string
  webuiApp: string
  apiInternalPort: number
  webuiInternalPort: number
  localEnabled: boolean
  dockerEnabled: boolean
  publicEnabled: boolean
  localApiUrl: string
  localWebuiUrl: string
  localStatus: 'UP' | 'Down'
  dockerApiUrl: string
  dockerWebuiUrl: string
  dockerStatus: 'UP' | 'Down'
  publicApiUrl: string
  publicWebuiUrl: string
  publicStatus: 'UP' | 'Down'
  hasServerDeploy: boolean
  onLocal: boolean
  onDocker: boolean
  onServer: boolean
  skipReason: string | null
  actionInProgress: boolean
}

export type LoginResponse = {
  token: string
  username: string
}

export type PatchAppBody = {
  enabled: boolean
  runMode: RunMode
}

const TOKEN_KEY = 'devmin-token'
const USER_KEY = 'devmin-user'

export const API_BASE = (() => {
  const raw = import.meta.env.VITE_API_BASE_URL as string | undefined
  if (raw !== undefined && raw !== '') return raw.replace(/\/$/, '')
  return (import.meta.env.BASE_URL || '/').replace(/\/$/, '')
})()

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY)
}

export function getStoredUsername(): string | null {
  return localStorage.getItem(USER_KEY)
}

export function setSession(token: string, username: string): void {
  localStorage.setItem(TOKEN_KEY, token)
  localStorage.setItem(USER_KEY, username)
}

export function clearSession(): void {
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(USER_KEY)
}

async function apiFetch<T>(path: string, options: RequestInit = {}, auth = false): Promise<T> {
  const headers = new Headers(options.headers)
  if (!headers.has('Content-Type') && options.body) {
    headers.set('Content-Type', 'application/json')
  }
  if (auth) {
    const token = getToken()
    if (!token) throw new Error('Not authenticated')
    headers.set('Authorization', `Bearer ${token}`)
  }

  const response = await fetch(`${API_BASE}${path}`, { ...options, headers })
  if (!response.ok) {
    let message = `Request failed (${response.status})`
    try {
      const data = (await response.json()) as { error?: string }
      if (data.error) message = data.error
    } catch {
      /* ignore */
    }
    throw new Error(message)
  }
  return response.json() as Promise<T>
}

export function login(body: { username: string; password: string }): Promise<LoginResponse> {
  return apiFetch<LoginResponse>('/api/v1/auth/login', {
    method: 'POST',
    body: JSON.stringify(body),
  })
}

export function fetchApps(): Promise<{ apps: AppRow[] }> {
  return apiFetch<{ apps: AppRow[] }>('/api/v1/apps', {}, true)
}

export function patchApp(stem: string, body: PatchAppBody): Promise<AppRow> {
  return apiFetch<AppRow>(`/api/v1/apps/${encodeURIComponent(stem)}`, {
    method: 'PATCH',
    body: JSON.stringify(body),
  }, true)
}
