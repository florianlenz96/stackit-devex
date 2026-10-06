import { createRemoteJWKSet, jwtVerify } from 'jose';

// Prüft Access Tokens von Keycloak. Ohne Token ist der Request anonym (nur lesen).
export function createAuth(oidc) {
  const jwks = createRemoteJWKSet(new URL(oidc.jwksUrl));

  async function identify(req, _res, next) {
    const header = req.get('authorization') ?? '';
    const [scheme, token] = header.split(' ');
    req.user = null;

    if (scheme?.toLowerCase() !== 'bearer' || !token) return next();

    try {
      const { payload } = await jwtVerify(token, jwks, { issuer: oidc.issuer });
      // Keycloak setzt "azp" auf den Client, für den das Token ausgestellt wurde.
      if (payload.azp !== oidc.clientId) {
        return next(httpError(401, 'Token wurde für einen anderen Client ausgestellt'));
      }
      const roles = payload.realm_access?.roles ?? [];
      req.user = {
        sub: payload.sub,
        name: payload.name || payload.preferred_username || 'Anonym',
        isSpeaker: roles.includes(oidc.speakerRole),
      };
      return next();
    } catch {
      return next(httpError(401, 'Token ungültig oder abgelaufen'));
    }
  }

  function requireUser(req, _res, next) {
    if (!req.user) return next(httpError(401, 'Bitte zuerst anmelden'));
    return next();
  }

  function requireSpeaker(req, _res, next) {
    if (!req.user) return next(httpError(401, 'Bitte zuerst anmelden'));
    if (!req.user.isSpeaker) return next(httpError(403, 'Nur für die Speaker-Rolle'));
    return next();
  }

  return { identify, requireUser, requireSpeaker };
}

export function httpError(status, message) {
  const err = new Error(message);
  err.status = status;
  return err;
}
