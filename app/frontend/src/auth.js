import Keycloak from 'keycloak-js';

const cfg = window.ASKIT_CONFIG ?? {};

// Keycloak läuft unter derselben Domain (/auth). Dadurch funktioniert der stille SSO-Check
// ohne Third-Party-Cookies und wir brauchen nur ein Zertifikat und einen DNS-Eintrag.
export const keycloak = new Keycloak({
  url: cfg.keycloakUrl ?? `${window.location.origin}/auth`,
  realm: cfg.keycloakRealm ?? 'askit',
  clientId: cfg.keycloakClientId ?? 'askit-frontend',
});

export async function initAuth() {
  try {
    await keycloak.init({
      onLoad: 'check-sso',
      pkceMethod: 'S256',
      checkLoginIframe: false,
      silentCheckSsoRedirectUri: `${window.location.origin}/silent-check-sso.html`,
    });
  } catch (err) {
    // App bleibt lesbar, auch wenn Keycloak gerade nicht erreichbar ist.
    console.warn('Keycloak nicht erreichbar, weiter ohne Login', err);
  }
  return keycloak.authenticated === true;
}

export async function accessToken() {
  if (!keycloak.authenticated) return null;
  try {
    await keycloak.updateToken(30);
  } catch {
    await keycloak.login();
  }
  return keycloak.token;
}

export function displayName() {
  const t = keycloak.tokenParsed ?? {};
  return t.name || t.preferred_username || 'Angemeldet';
}

export const login = () => keycloak.login();
export const logout = () => keycloak.logout({ redirectUri: window.location.origin });
