export function getApiUrl() {
  return import.meta.env.VITE_API_URL as string | undefined;
}

export function getTenantId() {
  return localStorage.getItem('tenant_id');
}

export function getAuthToken() {
  return localStorage.getItem('auth_token');
}

export function getCompanyName() {
  return localStorage.getItem('company_name');
}

export function getUserRole() {
  return localStorage.getItem('user_role');
}

export function getUserEmail() {
  return localStorage.getItem('user_email');
}

export function clearSession() {
  localStorage.removeItem('auth_token');
  localStorage.removeItem('tenant_id');
  localStorage.removeItem('company_name');
  localStorage.removeItem('user_role');
  localStorage.removeItem('user_email');
}

export function tenantHeaders(extraHeaders: HeadersInit = {}) {
  const headers = new Headers(extraHeaders);
  const tenantId = getTenantId();
  const token = getAuthToken();
  if (token) {
    headers.set('Authorization', `Bearer ${token}`);
  }
  if (tenantId) {
    headers.set('X-Tenant-Id', tenantId);
  }
  return headers;
}

export function tenantFetch(input: RequestInfo | URL, init: RequestInit = {}) {
  return fetch(input, {
    ...init,
    headers: tenantHeaders(init.headers),
  });
}
