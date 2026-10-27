import {CARDS,CARD_BY_ID,validateCards} from './cards.js';
export const RULES=Object.freeze({HZ:30,REGULATION:180,OVERTIME:120,MAX_ENERGY:10,START_ENERGY:5,ENERGY_SECONDS:2.8,DOUBLE_AT:120,TRIPLE_AT:240,DEPLOY_SECONDS:0.85,TOWER_HP:720,SENTRY_HP:520,COMMAND_HP:1250,TOWER_DAMAGE:26,TOWER_RANGE:5.6,MAX_ENTITIES:96,GRID_W:18,GRID_H:32,MAX_PROJECTILES:160});
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
export function makeRng(seed){let s=(seed>>>0)||0x6d2b79f5;return ()=>{s=(s+0x6D2B79F5)>>>0;let t=s;t=Math.imul(t^(t>>>15),t|1);t^=t+Math.imul(t^(t>>>7),t|61);return ((t^(t>>>14))>>>0)/4294967296;};}
export function shuffleSeeded(items,rng){const a=items.slice();for(let i=a.length-1;i>0;i--){const j=Math.floor(rng()*(i+1));[a[i],a[j]]=[a[j],a[i]];}return a;}
export function createMatch(seed=1,opts={}){
 validateCards();const rng=makeRng(seed),deck=shuffleSeeded((opts.deck||['micro','falcon','vanguard','prowler','merc','weaver','wildclaw','starforge']).slice(0,8),rng),opponentDeck=shuffleSeeded((opts.opponentDeck||deck).slice(0,8),rng);
 const towers=[];for(const team of ['red','blue']){const y=team==='blue'?28:4;for(let lane=0;lane<2;lane++)towers.push({id:team+'-sentry-'+lane,team,lane,x:lane===0?4.5:13.5,y:team==='blue'?23:9,hp:RULES.SENTRY_HP,max:RULES.SENTRY_HP,kind:'sentry',attack:0});towers.push({id:team+'-command',team,lane:0.5,x:9,y,hp:RULES.COMMAND_HP,max:RULES.COMMAND_HP,kind:'command',awake:false,attack:0});}
 return {seed, rngState:seed>>>0||1,tick:0,elapsed:0,remaining:RULES.REGULATION,overtime:false,done:false,winner:null,draw:false,energy:{blue:RULES.START_ENERGY,red:RULES.START_ENERGY},energyTick:{blue:0,red:0},decks:{blue:deck,red:opponentDeck},hands:{blue:deck.slice(0,4),red:[]},next:{blue:deck[4],red:opponentDeck[4]},cycle:{blue:4,red:4},towers,units:[],effects:[],projectiles:[],events:[],nextId:1,nextProjectileId:1,stars:{blue:0,red:0},commands:[],opts:{normalized:true,...opts},rng};
}
export function energyRate(m){return m.elapsed>=240?3:m.elapsed>=120?2:1;}
export function deployZoneValid(team,card,x,y,m){
 if(card.kind==='spell')return x>=0&&x<RULES.GRID_W&&y>=0&&y<RULES.GRID_H;
 if(team==='blue'){if(y<16)return false; if(y<20)return false; if(y<23&&m.towers.some(t=>t.team==='red'&&t.kind==='sentry'&&t.lane===(x<9?0:1)&&t.hp>0))return false;return true;}
 if(y>15)return false;if(y>12)return false;if(y>9&&m.towers.some(t=>t.team==='blue'&&t.kind==='sentry'&&t.lane===(x<9?0:1)&&t.hp>0))return false;return true;
}
export function queueCommand(m,command){m.commands.push({...command,at:command.at??m.tick});}
function event(m,type,data={}){m.events.push({tick:m.tick,type,...data});if(m.events.length>64)m.events.shift();}
function addProjectile(m,team,from,to,card,damage){const style=card.id==='tower'||(card.range||0)>2?'bolt':'slash';m.effects.push({kind:'projectile',style,x:from.x,y:from.y,tx:to.x,ty:to.y,life:style==='slash'?.18:.28,maxLife:style==='slash'?.18:.28,team,card:card.id,damage});if(m.effects.length>140)m.effects.splice(0,m.effects.length-140);}
function damagePop(m,x,y,damage,team){m.effects.push({kind:'damage',x,y,life:.65,maxLife:.65,team,damage});if(m.effects.length>140)m.effects.splice(0,m.effects.length-140);}
function damageTower(m,t,dmg,attacker){if(t.hp<=0)return;t.hp=Math.max(0,t.hp-dmg);damagePop(m,t.x,t.y-0.7,dmg,attacker);if(t.kind==='command')t.awake=true;if(t.kind==='sentry'&&t.hp===0){m.stars[attacker]=(m.stars[attacker]||0)+1;const cmd=m.towers.find(x=>x.team===t.team&&x.kind==='command');if(cmd)cmd.awake=true;event(m,'tower-destroyed',{id:t.id,team:t.team,attacker});}else event(m,'tower-hit',{id:t.id,damage:dmg});if(t.kind==='command'&&t.hp===0){m.stars[attacker]=3;m.done=true;m.winner=attacker;event(m,'command-destroyed',{team:t.team,attacker});}}
function spawn(m,team,card,x,y,lane){if(m.units.length>=RULES.MAX_ENTITIES)return false;const count=card.count||1;for(let i=0;i<count;i++){if(m.units.length>=RULES.MAX_ENTITIES)break;const spread=(i-(count-1)/2)*0.28;m.units.push({id:m.nextId++,card:card.id,team,x:clamp(x+spread,0.5,17.5),y:clamp(y+spread,0.5,31.5),lane,hp:card.hp,max:card.hp,attack:0,age:0,deploy:RULES.DEPLOY_SECONDS,locked:null,anim:'spawn',animTime:0,life:card.lifetime||0,slow:0,stun:0,shield:0,lastTarget:null,beam:0,air:!!card.air,firstStrike:true,lastHitTick:-999});}event(m,'deploy',{team,card:card.id,x,y});return true;}
function castSpell(m,team,card,x,y){for(const u of m.units){if(u.team===team)continue;const d=Math.hypot(u.x-x,u.y-y);if(d<=card.splash+0.8)applyUnitDamage(m,u,card.damage,team,x,y,card.id);}for(const t of m.towers){if(t.team!==team&&Math.hypot(t.x-x,t.y-y)<=card.splash)damageTower(m,t,card.damage*0.45,team);}m.effects.push({kind:card.id,x,y,life:0.8,team});event(m,'spell',{team,card:card.id,x,y});}
function runCommands(m){m.commands.sort((a,b)=>a.at-b.at);while(m.commands.length&&m.commands[0].at<=m.tick){const c=m.commands.shift();if(m.done||!['blue','red'].includes(c.team))continue;const card=CARD_BY_ID[c.card];if(!card||m.energy[c.team]+1e-6<card.cost)continue;if(!deployZoneValid(c.team,card,c.x,c.y,m)){event(m,'invalid-deploy',{team:c.team,card:c.card});continue;}m.energy[c.team]=Math.max(0,m.energy[c.team]-card.cost);const deck=m.decks[c.team];const hand=m.hands[c.team];if(hand.length){const idx=hand.indexOf(c.card);if(idx>=0){hand.splice(idx,1);hand.push(deck[m.cycle[c.team]%deck.length]);m.cycle[c.team]++;}}if(card.kind==='spell')castSpell(m,c.team,card,c.x,c.y);else spawn(m,c.team,card,c.x,c.y,c.x<9?0:1);}}
function canTarget(card,target){
 if(card.targets==='buildings')return false;
 if(card.targets==='ground'&&target.air)return false;
 if(card.targets==='air'&&!target.air)return false;
 return true;
}
function nearestTarget(m,u,card){if(card.targets==='buildings')return null;if(u.locked){const old=m.units.find(x=>x.id===u.locked&&x.hp>0&&x.team!==u.team&&canTarget(card,x));if(old&&Math.hypot(old.x-u.x,old.y-u.y)<=card.aggro+card.range+1)return old;u.locked=null;}let best=null,bd=Infinity;for(const e of m.units){if(e.hp<=0||e.team===u.team||!canTarget(card,e))continue;const d=Math.hypot(e.x-u.x,e.y-u.y);if(d<=card.aggro&&d<bd){best=e;bd=d;}}if(best){u.locked=best.id;return best;}return null;}
function applyUnitDamage(m,target,rawDamage,team,sourceX,sourceY,cardId=''){
 if(!target||target.hp<=0)return 0;
 let damage=rawDamage;const fromFront=target.team==='blue'?sourceY<target.y:sourceY>target.y;
 if(target.card==='vanguard'&&fromFront)damage*=0.72;
 const dealt=Math.min(target.hp,damage);target.hp-=damage;target.lastHitTick=m.tick;target.anim='hit';target.animTime=0;
 if(cardId==='weaver')target.slow=Math.max(target.slow,1.4);
 if(cardId==='overload')target.stun=Math.max(target.stun,0.65);
 if(cardId==='cryo')target.stun=Math.max(target.stun,1.2);
 if(cardId==='arc')target.y=clamp(target.y+(team==='blue'?-0.7:0.7),0.5,31.5);
 event(m,'unit-hit',{id:target.id,team,damage:Math.round(dealt*10)/10,x:target.x,y:target.y,card:cardId});return dealt;
}
function fireProjectile(m,source,target,card,options={}){
 const p={id:m.nextProjectileId++,team:source.team,card:card.id||'tower',x:source.x,y:source.y,lastX:source.x,lastY:source.y,sx:source.x,sy:source.y,tx:target.x,ty:target.y,targetType:options.targetType||'unit',targetId:target.id,damage:options.damage??card.damage,splash:options.splash??card.splash??0,speed:options.speed||(card.id==='merc'?14:card.id==='falcon'?10:card.id==='forgeheart'?11:card.id==='tesla'?14:card.id==='tower'?12:8),life:2};
 m.projectiles.push(p);if(m.projectiles.length>RULES.MAX_PROJECTILES)m.projectiles.shift();event(m,'shot',{id:p.id,team:p.team,card:p.card,x:p.x,y:p.y,targetId:p.targetId});
}
function impactProjectile(m,p){
 const target=p.targetType==='tower'?m.towers.find(t=>t.id===p.targetId&&t.hp>0):m.units.find(u=>u.id===p.targetId&&u.hp>0),x=target?target.x:p.tx,y=target?target.y:p.ty;
 if(target&&p.targetType==='tower')damageTower(m,target,p.damage,p.team);else if(target)applyUnitDamage(m,target,p.damage,p.team,p.sx,p.sy,p.card);
 const primaryId=target&&p.targetType==='unit'?target.id:null;
 const splash=(e,factor,radius)=>{if(e.id!==primaryId&&e.team!==p.team&&e.hp>0&&Math.hypot(e.x-x,e.y-y)<=radius)applyUnitDamage(m,e,p.damage*factor,p.team,p.sx,p.sy,p.card);};
 if(p.splash>0)for(const e of m.units)splash(e,.55,p.splash);
 if(p.card==='aegis'||p.card==='stormwarden'){let count=0;for(const e of m.units.slice().sort((a,b)=>Math.hypot(a.x-x,a.y-y)-Math.hypot(b.x-x,b.y-y))){if(e.id!==primaryId&&e.team!==p.team&&e.hp>0&&Math.hypot(e.x-x,e.y-y)<=3){splash(e,p.card==='aegis'?.45:.5,3);if(++count>=(p.card==='aegis'?1:2))break;}}}
 if(p.card==='void')for(const e of m.units)splash(e,.35,1.8);
 m.effects.push({kind:p.card,x,y,life:.34,team:p.team,impact:true});event(m,'projectile-hit',{id:p.id,team:p.team,card:p.card,x,y});
}
function stepProjectiles(m,dt){
 const keep=[];for(const p of m.projectiles){p.life-=dt;const target=p.targetType==='tower'?m.towers.find(t=>t.id===p.targetId&&t.hp>0):m.units.find(u=>u.id===p.targetId&&u.hp>0),tx=target?target.x:p.tx,ty=target?target.y:p.ty;p.lastX=p.x;p.lastY=p.y;p.tx=tx;p.ty=ty;const dx=tx-p.x,dy=ty-p.y,d=Math.hypot(dx,dy),travel=p.speed*dt;
  if(d<=travel+.10||p.life<=0){p.x=tx;p.y=ty;impactProjectile(m,p);}else{p.x+=dx/d*travel;p.y+=dy/d*travel;keep.push(p);}}
 m.projectiles=keep;
}
function stepUnit(m,u,dt){
 const card=CARD_BY_ID[u.card];if(!card)return;u.age+=dt;u.animTime+=dt;
 if(u.deploy>0){u.deploy=Math.max(0,u.deploy-dt);u.anim='spawn';return;}
 if(u.stun>0){u.stun=Math.max(0,u.stun-dt);u.anim='hit';return;}
 if(u.slow>0)u.slow=Math.max(0,u.slow-dt);if(u.life>0){u.life-=dt;if(u.life<=0)u.hp=0;}
 if(card.kind==='building'){
  u.attack+=dt;const targets=m.units.filter(e=>e.team!==u.team&&e.hp>0&&canTarget(card,e)&&Math.hypot(e.x-u.x,e.y-u.y)<=card.range);
  const target=targets.sort((a,b)=>Math.hypot(a.x-u.x,a.y-u.y)-Math.hypot(b.x-u.x,b.y-u.y))[0];
  if(target&&u.attack>=Math.max(.3,card.hit)){fireProjectile(m,u,target,card);u.attack=0;u.anim='attack';u.animTime=0;u.lastTarget=target.id;}
  if(card.id==='beacon'&&Math.floor(u.age/5)>Math.floor((u.age-dt)/5))spawn(m,u.team,CARD_BY_ID.micro,u.x,u.y+(u.team==='blue'?-.7:.7),u.lane);return;
 }
 const target=nearestTarget(m,u,card);
 if(target){const dist=Math.hypot(target.x-u.x,target.y-u.y);
  if(dist<=card.range){u.attack+=dt;const interval=card.id==='wildclaw'&&u.hp/u.max<.35?card.hit*.68:Math.max(.28,card.hit);
   if(u.attack>=interval){if(card.range>1.5){if(card.id==='forgeheart')u.beam=u.lastTarget===target.id?Math.min(4,(u.beam||0)+1):0;fireProjectile(m,u,target,card,{damage:card.damage*(card.id==='forgeheart'?1+u.beam*.13:1)});}else{let damage=card.damage;if(card.id==='prowler'&&u.firstStrike){damage*=1.5;u.firstStrike=false;}applyUnitDamage(m,target,damage,u.team,u.x,u.y,card.id);if(card.id==='void')for(const e of m.units)if(e.id!==target.id&&e.team!==u.team&&e.hp>0&&Math.hypot(e.x-target.x,e.y-target.y)<=1.8)applyUnitDamage(m,e,damage*.35,u.team,u.x,u.y,card.id);}
    u.attack=0;u.anim='attack';u.animTime=0;u.lastTarget=target.id;}else if(u.anim!=='attack')u.anim='idle';return;
  }
  const speed=card.speed*(u.slow>0?.5:1),len=Math.max(.01,dist);u.x=clamp(u.x+(target.x-u.x)/len*speed*dt,.5,17.5);u.y=clamp(u.y+(target.y-u.y)/len*speed*dt,.5,31.5);u.anim='walk';return;
 }
 const towers=m.towers.filter(t=>t.team!==u.team&&t.hp>0&&(card.targets==='buildings'||!target)).sort((a,b)=>Math.hypot(a.x-u.x,a.y-u.y)-Math.hypot(b.x-u.x,b.y-u.y));
 const tower=towers.find(t=>t.kind==='sentry'&&t.lane===u.lane)||towers.find(t=>t.kind==='command'&&t.awake);
 if(tower&&Math.hypot(tower.x-u.x,tower.y-u.y)<=card.range){u.attack+=dt;if(u.attack>=Math.max(.28,card.hit)){if(card.range>1.5)fireProjectile(m,u,tower,card,{targetType:'tower'});else damageTower(m,tower,card.damage,u.team);u.attack=0;u.anim='attack';u.animTime=0;}return;}
 const goalY=u.team==='blue'?0:31;let gx=tower?tower.x:(u.lane===0?4.5:13.5);if(Math.abs(u.y-15.5)<2.5)gx=u.lane===0?4.5:13.5;
 const dx=gx-u.x,dy=goalY-u.y,len=Math.max(.01,Math.hypot(dx,dy)),speed=card.speed*(u.slow>0?.5:1);
 u.x=clamp(u.x+dx/len*speed*dt,.5,17.5);u.y=clamp(u.y+dy/len*speed*dt,.5,31.5);u.anim='walk';
}
function towerStep(m,dt)function towerStep(m,dt){for(const t of m.towers){if(t.hp<=0)continue;t.attack+=dt;const targets=m.units.filter(u=>u.team!==t.team&&u.hp>0&&Math.hypot(u.x-t.x,u.y-t.y)<=RULES.TOWER_RANGE).sort((a,b)=>Math.hypot(a.x-t.x,a.y-t.y)-Math.hypot(b.x-t.x,b.y-t.y));const target=targets[0];if(target&&t.attack>=1.0){addProjectile(m,t.team,t,target,{id:'tower'},RULES.TOWER_DAMAGE);target.hp-=RULES.TOWER_DAMAGE;damagePop(m,target.x,target.y,RULES.TOWER_DAMAGE,t.team);t.attack=0;target.anim='hit';target.animTime=0;if(t.kind==='command')t.awake=true;}}}
function finishClock(m){if(m.done)return;if(m.remaining>0)return;if(!m.overtime){if(m.stars.blue!==m.stars.red){m.done=true;m.winner=m.stars.blue>m.stars.red?'blue':'red';return;}m.overtime=true;m.remaining=RULES.OVERTIME;event(m,'overtime');return;}if(m.stars.blue!==m.stars.red){m.done=true;m.winner=m.stars.blue>m.stars.red?'blue':'red';return;}const lowest=team=>Math.min(...m.towers.filter(t=>t.team===team).map(t=>t.hp));if(lowest('blue')!==lowest('red')){m.done=true;m.winner=lowest('blue')>lowest('red')?'blue':'red';}else{m.done=true;m.draw=true;}}
export function stepMatch(m,dt=1/RULES.HZ){if(m.done)return m;m.tick++;m.elapsed+=dt;m.remaining=Math.max(0,m.remaining-dt);const rate=energyRate(m);for(const team of ['blue','red'])m.energy[team]=Math.min(RULES.MAX_ENERGY,m.energy[team]+dt*rate/RULES.ENERGY_SECONDS);runCommands(m);for(const u of m.units)stepUnit(m,u,dt);towerStep(m,dt);stepProjectiles(m,dt);m.units=m.units.filter(u=>u.hp>0&&u.y>=0&&u.y<=31);for(const e of m.effects)e.life-=dt;m.effects=m.effects.filter(e=>e.life>0);for(let i=0;i<m.units.length;i++){const a=m.units[i];for(let j=i+1;j<m.units.length;j++){const b=m.units[j];if(a.team===b.team&&Math.abs(a.y-b.y)<0.42&&Math.abs(a.x-b.x)<0.42&&a.deploy<=0&&b.deploy<=0){const push=a.id<b.id?0.08:-0.08;b.x=clamp(b.x+push,0.5,17.5);}}}finishClock(m);return m;}
export function stateHash(m){
 let h=2166136261;const str=JSON.stringify({tick:m.tick,remaining:+m.remaining.toFixed(5),energy:m.energy,stars:m.stars,
 towers:m.towers.map(t=>[t.id,Math.round(t.hp*100)/100]),
 units:m.units.map(u=>[u.id,u.card,u.team,Math.round(u.x*100)/100,Math.round(u.y*100)/100,Math.round(u.hp*100)/100,u.locked]).sort((a,b)=>a[0]-b[0]),
 projectiles:(m.projectiles||[]).map(p=>[p.id,p.card,p.team,Math.round(p.x*100)/100,Math.round(p.y*100)/100,p.targetId]).sort((a,b)=>a[0]-b[0]),cycle:m.cycle,hands:m.hands});
 for(let i=0;i<str.length;i++){h^=str.charCodeAt(i);h=Math.imul(h,16777619);}return (h>>>0).toString(16).padStart(8,'0');
}
export function runBot(m,team='red',difficulty=3){
 if(m.done||m.energy[team]<2)return;
 const level=Math.max(1,Math.min(8,Math.round(difficulty||1))),hand=m.hands[team];
 if(!hand.length){m.hands[team]=m.decks[team].slice(0,4);return;}
 const playable=hand.map(id=>CARD_BY_ID[id]).filter(c=>c&&c.cost<=m.energy[team]);if(!playable.length)return;
 const enemies=m.units.filter(u=>u.team!==team&&u.hp>0),allies=m.units.filter(u=>u.team===team&&u.hp>0),redSide=team==='red';
 const threat=[0,0],enemyTower=[0,0];
 for(const e of enemies){const lane=e.x<9?0:1;threat[lane]+=Math.max(0,redSide?16-e.y:e.y-16)+4;}
 for(const t of m.towers.filter(t=>t.team!==team&&t.kind==='sentry'))enemyTower[t.lane]+=t.hp;
 const threatened=threat[0]>0||threat[1]>0;
 const crowd=card=>{let best=0;for(const e of enemies){let n=0;for(const other of enemies)if(Math.hypot(e.x-other.x,e.y-other.y)<=card.splash+.8)n++;best=Math.max(best,n);}return best;};
 const scored=playable.map(card=>{
  let score=2;const count=crowd(card),weak=enemies.filter(e=>e.hp<card.damage*1.25).length;
  if(card.kind==='spell')score+=count>=4?7:count>=3?5:count>=2?2.8:-1.8;
  if((card.id==='overload'||card.id==='cryo')&&enemies.some(e=>e.attack>.5||e.anim==='attack'))score+=1.5;
  if(card.kind==='building')score+=threatened?4.2:1.5;
  if(card.targets==='buildings')score+=2+(enemyTower[0]+enemyTower[1]<1400?.7:0);
  if(['FRONTLINE','BRUISER'].includes(card.role)||card.id==='void')score+=threatened?4.5:2.1;
  if(['RANGED','GUNNER','ARTILLERY'].includes(card.role))score+=allies.some(a=>['vanguard','jade','void'].includes(a.card))?2.4:1.2;
  if(card.targets==='all'&&enemies.some(e=>e.air))score+=2;
  if(card.id==='starforge'&&enemies.length>=3)score+=2.5;
  if(card.id==='micro'&&enemies.some(e=>['void','jade'].includes(e.card)))score+=2;
  if(card.id==='prowler'&&enemies.some(e=>['falcon','merc','weaver','forgeheart'].includes(e.card)))score+=2;
  if(card.id==='beacon'&&allies.length<4)score+=1.7;
  if(card.cost<=3)score+=.5;if(card.cost>=6&&m.energy[team]<card.cost+1.5)score-=1.2;
  if(level>=6&&weak>=2&&card.damage>30)score+=1.4;if(level>=7&&threatened&&card.cost<=4)score+=1.1;
  return{card,score:score+m.rng()*(level>=6?.45:level>=3?1.15:2.2)};
 }).sort((a,b)=>b.score-a.score);
 const pool=level<=2?Math.min(3,scored.length):level<=4?Math.min(2,scored.length):1,choice=scored[Math.floor(m.rng()*pool)];if(!choice)return;
 let lane;
 if(level>=4){const hot=threat[0]>=threat[1]?0:1,weak=enemyTower[0]<=enemyTower[1]?0:1;lane=threatened&&m.rng()<.72?hot:(enemyTower[0]!==enemyTower[1]?weak:(m.rng()<.5?0:1));}else lane=m.rng()<.5?0:1;
 let x=lane===0?4.5:13.5,y=redSide?9:23;
 if(choice.card.kind==='spell'&&enemies.length){x=enemies.reduce((a,e)=>a+e.x,0)/enemies.length;y=enemies.reduce((a,e)=>a+e.y,0)/enemies.length;}
 else if(level>=3&&threatened){const t=enemies.filter(e=>redSide?e.y<14:e.y>18).sort((a,b)=>Math.hypot(a.x-x,a.y-y)-Math.hypot(b.x-x,b.y-y))[0];if(t){x=t.x;y=redSide?9:23;lane=t.x<9?0:1;}}
 x=Math.round(clamp(x+(level<=2?(m.rng()-.5)*4:(m.rng()-.5)*1.6),1,16));
 y=choice.card.kind==='spell'?Math.round(clamp(y,0,31)):(redSide?9:23);
 queueCommand(m,{team,card:choice.card.id,x,y,at:m.tick});
}
export function replay(seed,commands,ticks){const m=createMatch(seed);for(const c of commands)queueCommand(m,c);for(let i=0;i<ticks&&!m.done;i++)stepMatch(m);return {match:m,hash:stateHash(m)};}
