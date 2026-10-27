import test from 'node:test';
import assert from 'node:assert/strict';
import {LADDER,STARTER_DECK,ladderTierIndex,ladderProgress,trophyDelta} from '../src/ladder.js';
import {createMatch,stepMatch,runBot,stateHash} from '../src/sim.js';
test('ladder thresholds increase and final tier is capped',()=>{assert.equal(ladderTierIndex(0),0);assert.equal(ladderTierIndex(119),0);assert.equal(ladderTierIndex(120),1);assert.equal(ladderTierIndex(2100),7);assert.equal(ladderTierIndex(99999),7);});
test('trophy gains/losses follow difficulty and draws are neutral',()=>{assert.equal(trophyDelta('win',1),26);assert.equal(trophyDelta('win',8),54);assert.equal(trophyDelta('loss',4),-16);assert.equal(trophyDelta('draw',8),0);assert.equal(ladderProgress(350).current.id,'silver');assert.ok(ladderProgress(350).ratio>0);});
test('rival decks each have eight unique cards and higher tiers raise difficulty',()=>{assert.equal(STARTER_DECK.length,8);for(const tier of LADDER){assert.equal(tier.deck.length,8,tier.name);assert.equal(new Set(tier.deck).size,8,tier.name);}for(let i=1;i<LADDER.length;i++)assert.ok(LADDER[i].difficulty>LADDER[i-1].difficulty);});
test('seeded matches reproduce state hashes and projectile paths',()=>{const opts={deck:STARTER_DECK,opponentDeck:LADDER[4].deck};const a=createMatch(91337,opts),b=createMatch(91337,opts);for(let tick=0;tick<900&&!a.done&&!b.done;tick++){if(tick%42===0){runBot(a,'red',5);runBot(b,'red',5);}stepMatch(a);stepMatch(b);}assert.equal(stateHash(a),stateHash(b));assert.deepEqual(a.projectiles,b.projectiles);});
