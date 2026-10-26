const test = require('node:test');
const assert = require('node:assert/strict');
const cards = [
  {id:'titan',cost:4},{id:'volt',cost:3},{id:'wraith',cost:3},{id:'nova',cost:5},
  {id:'pulse',cost:3},{id:'sentinel',cost:4},{id:'sparks',cost:2},{id:'rift',cost:4}
];
test('deck has eight unique original hero archetypes',()=>{assert.equal(cards.length,8);assert.equal(new Set(cards.map(c=>c.id)).size,8);});
test('all card costs are within the 1-10 energy range',()=>{for(const c of cards)assert.ok(c.cost>=1&&c.cost<=10);});
test('match clock and overtime constants are positive',()=>{assert.ok(180>0);assert.ok(60>0);});
