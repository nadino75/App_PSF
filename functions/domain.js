'use strict';

class DomainError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}
function requireThat(condition, code, message) {
  if (!condition) throw new DomainError(code, message);
}
function text(value, field, max = 150, optional = false) {
  requireThat(typeof value === 'string', 'invalid-argument', `Campo inválido: ${field}.`);
  const result = value.trim();
  requireThat((optional || result.length > 0) && result.length <= max,
    'invalid-argument', `Revisa ${field} (máximo ${max} caracteres).`);
  return result;
}
function identifier(value) {
  requireThat(typeof value === 'string' && /^[a-zA-Z0-9_-]{1,128}$/.test(value),
    'invalid-argument', 'Identificador inválido.');
  return value;
}
function businessData(data) {
  requireThat(data && typeof data === 'object', 'invalid-argument', 'Faltan los datos.');
  const result = {};
  for (const key of ['nombre', 'categoria', 'direccion', 'zona', 'telefono', 'horarios']) {
    result[key] = text(data[key], key, key === 'horarios' ? 500 : 150);
  }
  result.descripcion = text(data.descripcion, 'descripción', 2000);
  requireThat(/^[+\d\s()-]{7,30}$/.test(result.telefono), 'invalid-argument', 'Teléfono inválido.');
  result.imagenes = data.imagenes ?? [];
  requireThat(Array.isArray(result.imagenes) && result.imagenes.length <= 6 &&
    result.imagenes.every(x => typeof x === 'string' && x.length < 2048 && x.startsWith('https://')),
    'invalid-argument', 'Las imágenes deben ser direcciones HTTPS (máximo seis).');
  return result;
}
function contentData(data, kind) {
  const result = {
    titulo: text(data?.titulo, 'título'),
    descripcion: text(data?.descripcion, 'descripción', 4000),
  };
  if (kind === 'anuncio') {
    result.negocioId = identifier(data.negocioId);
    const expires = Date.parse(data.vence);
    requireThat(Number.isFinite(expires) && expires > Date.now(), 'invalid-argument', 'El vencimiento debe ser futuro.');
    result.vence = new Date(expires).toISOString();
  }
  return result;
}
function decision(request, approve, reason) {
  requireThat(request.estado === 'pendiente', 'failed-precondition', 'Esta solicitud ya no está pendiente.');
  requireThat(typeof approve === 'boolean', 'invalid-argument', 'Decisión inválida.');
  return {
    estado: approve ? 'aprobada' : 'rechazada',
    motivo: text(reason ?? '', 'motivo', 1000, approve),
  };
}
function isAdmin(auth) {
  return auth && auth.token && auth.token.admin === true;
}
function isOwner(auth, ownerId) {
  return auth && auth.uid === ownerId;
}
function validateUserRole(auth, requiredRole) {
  // requiredRole puede ser 'user', 'owner', 'admin'
  if (requiredRole === 'admin') return isAdmin(auth);
  if (requiredRole === 'owner') return !!auth && !!auth.uid;
  return !!auth;
}
module.exports = { DomainError, requireThat, text, identifier, businessData, contentData, decision, isAdmin, isOwner, validateUserRole };
