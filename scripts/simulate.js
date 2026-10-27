import {createMatch,stepMatch,queueCommand,runBot,stateHash} from '../src/sim.js';
import {CARDS} from '../src/cards.js';
import {performance} from 'node:perf_hooks';
const games=Number(process.env.MATCHES||1000),maxTicks=300*30;
const ARCHETYPES=[['micro','falcon','vanguard','prowler','merc','weaver','wildclaw','starforge'],['jade','void','aegis','stormwarden','micro','turret','photon','cryo'],['vanguard','falcon','weaver','forgeheart','turret','tesla','overload','arc'],['micro','prowler','merc','starforge','beacon','photon','cryo','aegis'],['jade','forgeheart','stormwarden','void','turret','tesla','beacon','arc']];
const stats=Object.fromEntries(CARDS.map(c=>[c.id,{used:0,matches:0,wins:0}]));
const wins={blue:0,red:0,draw:0};let ticksTotal=0,peakEntities=0,usedEvents=0;const towerKillSeconds=[];
const started=performance.now();
for(let g=0;g<games;g++){
 const m=createMatch(g+7919,{deck:ARCHETYPES[g%ARCHETYPES.length]}),seen=new Set(),killSeen=new Set(),usedByTeam={blue:new Set(),red:new Set()};
 for(let t=0;t<maxTicks&&!m.done;t++){
  if(t%12===0){runBot(m,'blue',1+g%6);runBot(m,'red',1+(g+2)%6);}
  stepMatch(m);peakEntities=Math.max(peakEntities,m.units.length);
  for(const e of m.events){if(e.type==='tower-destroyed'||e.type==='command-destroyed'){const k=e.tick+'|'+e.type+'|'+e.id;if(!killSeen.has(k)){killSeen.add(k);if(e.type==='tower-destroyed')towerKillSeconds.push(e.tick/30);}}if(e.type!=='deploy'&&e.type!=='spell')continue;const key=e.tick+'|'+e.team+'|'+e.card;if(seen.has(key))continue;seen.add(key);usedEvents++;if(stats[e.card])stats[e.card].used++;if(usedByTeam[e.team])usedByTeam[e.team].add(e.card);}
 }
 ticksTotal+=m.tick;
 if(m.draw)wins.draw++;else wins[m.winner||'draw']++;
 for(const team of ['blue','red'])for(const card of usedByTeam[team])if(stats[card]){stats[card].matches++;if(m.winner===team)stats[card].wins++;}
}
const stress=createMatch(987654);for(let i=0;i<60;i++){const team=i%2?'blue':'red',lane=Math.floor(i/2)%2;stress.units.push({id:stress.nextId++,card:'micro',team,x:lane===0?4.5:13.5,y:team==='blue'?23-(i%10):9+(i%10),lane,hp:40,max:40,attack:0,age:1,deploy:0,locked:null,anim:'walk',animTime:0,life:0,slow:0,stun:0,shield:0,lastTarget:null,beam:0});}const stressStart=performance.now();for(let i=0;i<300;i++)stepMatch(stress);const stressTicksPerSecond=Math.round(300/Math.max(0.001,(performance.now()-stressStart)/1000));
const ms=performance.now()-started;
console.log(JSON.stringify({games,wins,averageMatchSeconds:Math.round(ticksTotal/games/30),averageTowerKillSeconds:towerKillSeconds.length?Math.round(towerKillSeconds.reduce((a,b)=>a+b,0)/towerKillSeconds.length):null,simulationTicks:ticksTotal,wallSeconds:+(ms/1000).toFixed(2),ticksPerSecond:Math.round(ticksTotal/(ms/1000)),peakEntities,stressEntityCount:60,stressTicksPerSecond,deployments:usedEvents,cards:Object.fromEntries(Object.entries(stats).map(([id,s])=>[id,{...s,usageRatePercent:+(s.used/Math.max(1,usedEvents)*100).toFixed(2),matchWinRatePercent:+(s.wins/Math.max(1,s.matches)*100).toFixed(2)}])),finalSampleHash:stateHash(createMatch(7919))},null,2));
