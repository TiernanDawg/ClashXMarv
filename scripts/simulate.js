import {createMatch,stepMatch,queueCommand,runBot,stateHash} from '../src/sim.js';
import {CARDS} from '../src/cards.js';
import {performance} from 'node:perf_hooks';
const games=Number(process.env.MATCHES||1000),maxTicks=300*30;
const ARCHETYPES=[['micro','falcon','vanguard','prowler','merc','weaver','wildclaw','starforge'],['jade','void','aegis','stormwarden','micro','turret','photon','cryo'],['vanguard','falcon','weaver','forgeheart','turret','tesla','overload','arc'],['micro','prowler','merc','starforge','beacon','photon','cryo','aegis'],['jade','forgeheart','stormwarden','void','turret','tesla','beacon','arc']];
const stats=Object.fromEntries(CARDS.map(c=>[c.id,{used:0,wins:0}]));
const wins={blue:0,red:0,draw:0};let ticksTotal=0,peakEntities=0,usedEvents=0;const firstTowerKillSeconds=[];
const started=performance.now();
for(let g=0;g<games;g++){
 const m=createMatch(g+7919,{deck:ARCHETYPES[g%ARCHETYPES.length]}),seen=new Set(),killSeen=new Set(),usedByTeam={blue:[],red:[]};
 for(let t=0;t<maxTicks&&!m.done;t++){
  if(t%12===0){runBot(m,'blue',1+g%6);runBot(m,'red',1+(g+2)%6);}
  stepMatch(m);peakEntities=Math.max(peakEntities,m.units.length);
  for(const e of m.events){if(e.type==='tower-destroyed'||e.type==='command-destroyed'){const k=e.tick+'|'+e.type+'|'+e.id;if(!killSeen.has(k)){killSeen.add(k);if(firstTowerKillSeconds.length<games&&e.type==='tower-destroyed')firstTowerKillSeconds.push(e.tick/30);}}if(e.type!=='deploy')continue;const key=e.tick+'|'+e.team+'|'+e.card;if(seen.has(key))continue;seen.add(key);usedEvents++;if(stats[e.card])stats[e.card].used++;if(usedByTeam[e.team])usedByTeam[e.team].push(e.card);}
 }
 ticksTotal+=m.tick;
 if(m.draw)wins.draw++;else wins[m.winner||'draw']++;
 if(m.winner)for(const card of usedByTeam[m.winner])if(stats[card])stats[card].wins++;
}
const ms=performance.now()-started;
console.log(JSON.stringify({games,wins,averageMatchSeconds:Math.round(ticksTotal/games/30),firstTowerKillAverageSeconds:firstTowerKillSeconds.length?Math.round(firstTowerKillSeconds.reduce((a,b)=>a+b,0)/firstTowerKillSeconds.length):null,simulationTicks:ticksTotal,wallSeconds:+(ms/1000).toFixed(2),ticksPerSecond:Math.round(ticksTotal/(ms/1000)),peakEntities,deployments:usedEvents,cards:stats,finalSampleHash:stateHash(createMatch(7919))},null,2));
