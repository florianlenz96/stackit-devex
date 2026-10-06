import { defineConfig } from 'vite';

// Lokal laufen Backend (8080) und Keycloak (8081) separat. Der Proxy bildet nach,
// was im Cluster der Ingress macht: alles unter einer Domain, /api und /auth werden weitergeleitet.
export default defineConfig({
  server: {
    port: 5173,
    proxy: {
      '/api': 'http://localhost:8080',
      '/auth': 'http://localhost:8081',
    },
  },
});
