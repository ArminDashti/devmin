export type Channel = 'hotReload' | 'local' | 'localDocker' | 'serverDocker' | 'server'

export type ActionName =
  | 'enable'
  | 'disable'
  | 'install'
  | 'uninstall'
  | 'update'
  | 'reinstall'

export type EndpointLine = {
  channel: string
  url: string
  status: string
}

export type ChannelState = {
  enabled: boolean
  available: boolean
  reason?: string
}

export type ApplicationDTO = {
  id: string
  name: string
  role: string
  stem: string
  internalPort: number
  endpoints: EndpointLine[]
  channels: Record<string, ChannelState>
}

export type StackDTO = {
  stem: string
  type: string
  rootDir: string
  skipReason?: string
  applications: ApplicationDTO[]
}

export type ActionJob = {
  id: string
  stem: string
  appId?: string
  channel: string
  action: string
  status: 'running' | 'succeeded' | 'failed'
  output: string
  error?: string
  createdAt: string
  updatedAt: string
}

export type PlatformSettings = {
  localDocker: {
    network: string
    publishHost: string
    githubRoot: string
    deleteVolume: string
    deleteImage: string
  }
  serverDocker: {
    sshTarget: string
    volumeBase: string
    timeoutSec: number
  }
  server: {
    sshTarget: string
    deployRoot: string
    sshEnvKey: string
  }
}

// Legacy apps grid types (backward compatible)
export type RunMode = Channel | 'local' | 'server'

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

export function fetchStacks(): Promise<{ stacks: StackDTO[] }> {
  return apiFetch<{ stacks: StackDTO[] }>('/api/v1/stacks', {}, true)
}

export function fetchStack(stem: string): Promise<StackDTO> {
  return apiFetch<StackDTO>(`/api/v1/stacks/${encodeURIComponent(stem)}`, {}, true)
}

export function fetchApplication(appId: string): Promise<{ application: ApplicationDTO; stack: StackDTO }> {
  return apiFetch<{ application: ApplicationDTO; stack: StackDTO }>(
    `/api/v1/applications/${encodeURIComponent(appId)}`,
    {},
    true,
  )
}

export function postAction(body: {
  stem?: string
  appId?: string
  channel: Channel
  action: ActionName
}): Promise<ActionJob> {
  return apiFetch<ActionJob>('/api/v1/actions', {
    method: 'POST',
    body: JSON.stringify(body),
  }, true)
}

export function fetchAction(id: string): Promise<ActionJob> {
  return apiFetch<ActionJob>(`/api/v1/actions/${encodeURIComponent(id)}`, {}, true)
}

export function fetchSettings(): Promise<PlatformSettings> {
  return apiFetch<PlatformSettings>('/api/v1/settings', {}, true)
}

export function putSettings(body: PlatformSettings): Promise<PlatformSettings> {
  return apiFetch<PlatformSettings>('/api/v1/settings', {
    method: 'PUT',
    body: JSON.stringify(body),
  }, true)
}

export function fetchDockerParams(
  appId: string,
  target: 'local' | 'server',
): Promise<{ target: string; params: Record<string, string>; appId?: string }> {
  return apiFetch(
    `/api/v1/applications/${encodeURIComponent(appId)}/docker-params?target=${target}`,
    {},
    true,
  )
}

export function patchDockerParams(
  appId: string,
  target: 'local' | 'server',
  params: Record<string, string>,
): Promise<{ target: string; params: Record<string, string>; appId?: string }> {
  return apiFetch(`/api/v1/applications/${encodeURIComponent(appId)}/docker-params?target=${target}`, {
    method: 'PATCH',
    body: JSON.stringify(params),
  }, true)
}

export function fetchServerParams(
  appId: string,
): Promise<{ params: Record<string, string>; appId?: string }> {
  return apiFetch(
    `/api/v1/applications/${encodeURIComponent(appId)}/server-params`,
    {},
    true,
  )
}

export function patchServerParams(
  appId: string,
  params: Record<string, string>,
): Promise<{ params: Record<string, string>; appId?: string }> {
  return apiFetch(`/api/v1/applications/${encodeURIComponent(appId)}/server-params`, {
    method: 'PATCH',
    body: JSON.stringify(params),
  }, true)
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

export async function pollAction(jobId: string, onUpdate?: (job: ActionJob) => void): Promise<ActionJob> {
  for (let i = 0; i < 120; i++) {
    const job = await fetchAction(jobId)
    onUpdate?.(job)
    if (job.status !== 'running') return job
    await new Promise((r) => setTimeout(r, 1500))
  }
  return fetchAction(jobId)
}
