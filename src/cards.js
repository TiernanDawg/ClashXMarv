const unit = (id,name,cost,role,palette,silhouette,hp,damage,range,speed,hit,targets='ground',count=1,extra={})=>({id,name,cost,role,palette,silhouette,hp,damage,range,speed,hit,targets,count,rarity:extra.rarity||'COMMON',kind:extra.kind||'troop',splash:extra.splash||0,aggro:extra.aggro||5,firstHit:extra.firstHit||0.25,ability:extra.ability||'',ultimate:extra.ultimate||null,animations:['spawn','idle','walk','attack','hit','death',...(extra.ability?['ability']:[])],...extra});
export const CARDS = [
unit('micro','Micro Squad',2,'SWARM',['#FFCF5A','#FF8E45'],'micro-squad',42,12,1.2,3.6,0.62,'ground',4),
unit('falcon','Falcon Archers',3,'RANGED',['#8DE5FF','#3D8DB7'],'falcon-archers',68,18,5.2,1.2,1.15,'all',2),
unit('vanguard','Vanguard Trooper',3,'FRONTLINE',['#76C8FF','#315C9B'],'vanguard-trooper',235,26,1.35,1.15,1.05,'ground',1,{ability:'Front shield reduces frontal damage'}),
unit('prowler','Night Prowler',3,'ASSASSIN',['#D8A1FF','#6339A4'],'night-prowler',108,43,1.25,2.8,1.1,'ground',1,{ability:'First strike deals bonus damage'}),
unit('merc','Rogue Merc',4,'GUNNER',['#FFC08D','#AD542E'],'rogue-merc',118,14,4.3,1.55,0.42,'all',1),
unit('weaver','Silk Weaver',4,'CONTROL',['#FF9FCF','#A73E80'],'silk-weaver',146,21,4.1,1.5,0.92,'all',1,{ability:'Hits slow targets'}),
unit('wildclaw','Wildclaw',4,'BRUISER',['#C4F58B','#518F42'],'wildclaw',278,35,1.45,1.5,1.12,'ground',1,{ability:'Frenzy at low health'}),
unit('starforge','Starforge Wing',4,'FLYING',['#A6A7FF','#6558D4'],'starforge-wing',132,29,4.2,1.9,1.25,'all',1,{splash:1.2,ability:'Splash energy burst'}),
unit('forgeheart','Forgeheart',5,'ARTILLERY',['#FF9C76','#B84F39'],'forgeheart',330,38,4.5,0.78,1.55,'all',1,{ability:'Beam ramps on same target'}),
unit('aegis','Aegis Captain',4,'HERO',['#8FE5FF','#297A9E'],'aegis-captain',260,34,3.8,1.35,1.05,'all',1,{rarity:'HERO',ability:'Ricocheting shield',ultimate:{name:'Shield Wall',cost:3,effect:'shield'}}),
unit('stormwarden','Stormwarden',5,'HERO',['#FFE17C','#B87A27'],'stormwarden',310,48,3.1,1.25,1.35,'all',1,{rarity:'HERO',ability:'Chain lightning',ultimate:{name:'Thunder Slam',cost:4,effect:'stun'}}),
unit('jade','Jade Titan',5,'HERO',['#9BF2B1','#25855B'],'jade-titan',620,62,1.25,0.72,1.75,'buildings',1,{rarity:'HERO',ability:'Siege specialist',ultimate:{name:'Rampage',cost:4,effect:'rage'}}),
unit('void','Void Tyrant',7,'HERO',['#D3A5FF','#5A2C91'],'void-tyrant',720,82,1.55,0.58,2.1,'ground',1,{rarity:'HERO',ability:'Gravity gauntlet',ultimate:{name:'Void Pulse',cost:5,effect:'pull'}}),
unit('photon','Photon Volley',3,'SPELL',['#FFF2A1','#F0A82D'],'photon-volley',1,62,4,0,0,'all',1,{kind:'spell',splash:2.6,rarity:'RARE'}),
unit('overload','Overload Pulse',2,'SPELL',['#9DF6FF','#25A3D1'],'overload-pulse',1,20,3,0,0,'all',1,{kind:'spell',splash:1.7,rarity:'RARE',ability:'Brief stun'}),
unit('arc','Arc Missile',4,'SPELL',['#FFAA86','#E65747'],'arc-missile',1,118,4.5,0,0,'all',1,{kind:'spell',splash:2.3,rarity:'RARE',ability:'Knockback'}),
unit('cryo','Cryo Blast',4,'SPELL',['#A9F2FF','#398DBD'],'cryo-blast',1,42,3.7,0,0,'all',1,{kind:'spell',splash:2.7,rarity:'RARE',ability:'Freeze'}),
unit('turret','Sentry Turret',3,'BUILDING',['#FFD08B','#A65D34'],'sentry-turret',260,24,5,0,0.85,'ground',1,{kind:'building',lifetime:38,rarity:'RARE'}),
unit('tesla','Tesla Node',4,'BUILDING',['#B2A5FF','#6245B7'],'tesla-node',210,37,4.4,0,0.9,'all',1,{kind:'building',lifetime:34,rarity:'RARE'}),
unit('beacon','Rally Beacon',5,'BUILDING',['#A9F5C0','#348F6A'],'rally-beacon',300,0,0,0,0,'ground',1,{kind:'building',lifetime:28,rarity:'EPIC',ability:'Spawns Micro Squad reinforcements'})
];
export const CARD_BY_ID = Object.fromEntries(CARDS.map(c=>[c.id,c]));
export const validateCards = () => {
 const ids=new Set(), palettes=new Set(), silhouettes=new Set();
 for(const c of CARDS){
  if(ids.has(c.id)||palettes.has(c.palette.join('|'))||silhouettes.has(c.silhouette)) throw new Error('Duplicate card identity, palette, or silhouette: '+c.id);
  ids.add(c.id);palettes.add(c.palette.join('|'));silhouettes.add(c.silhouette);
  for(const state of ['spawn','idle','walk','attack','hit','death']) if(!c.animations.includes(state)) throw new Error(c.id+' missing '+state+' animation');
  if(c.cost<1||c.cost>10||!c.hp||!c.palette.length) throw new Error('Invalid card schema: '+c.id);
 }
 return true;
};
