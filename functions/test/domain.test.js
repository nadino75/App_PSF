'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { businessData, contentData, decision, identifier } = require('../domain');
const business = {nombre: 'Café', categoria: 'cafe', direccion: 'Calle 1', zona: 'Centro', telefono: '+59170000000', horarios: '09:00 a 18:00', descripcion: 'Café local', imagenes: []};
test('business validation rejects missing fields and invalid media', () => {
  assert.equal(businessData(business).nombre, 'Café');
  assert.throws(() => businessData({...business, telefono: 'abc'}));
  assert.throws(() => businessData({...business, nombre: ' '}));
  assert.throws(() => businessData({...business, imagenes: ['http://unsafe.test/a.jpg']}));
});
test('reviews require a pending state and a rejection reason', () => {
  assert.throws(() => decision({estado: 'aprobada'}, true, ''));
  assert.throws(() => decision({estado: 'retirada'}, true, ''));
  assert.throws(() => decision({estado: 'pendiente'}, false, '   '));
  assert.equal(decision({estado: 'pendiente'}, false, 'Corrige el horario').estado, 'rechazada');
});
test('expired advertisements cannot be published', () => {
  assert.throws(() => contentData({titulo: 'Oferta', descripcion: 'Oferta local', negocioId: 'cafe', vence: '2020-01-01'}, 'anuncio'));
});
test('identifiers cannot escape document paths', () => {
  assert.throws(() => identifier('../usuarios/admin'));
  assert.throws(() => identifier(''));
});
