export const STARTER_DECK=['micro','falcon','vanguard','prowler','merc','weaver','wildclaw','starforge'];
export const LADDER=Object.freeze([
 {id:'rookie',name:'Rookie Yard',badge:'I',min:0,difficulty:1,rival:'Sparring Cadet',deck:['micro','falcon','vanguard','prowler','merc','weaver','wildclaw','starforge'],style:'Basic pushes and simple defense'},
 {id:'copper',name:'Copper Foundry',badge:'II',min:120,difficulty:2,rival:'Gatekeeper Juno',deck:['micro','falcon','vanguard','merc','weaver','turret','photon','cryo'],style:'Swarm pressure and area control'},
 {id:'silver',name:'Silver Circuit',badge:'III',min:300,difficulty:3,rival:'Circuit Warden',deck:['vanguard','falcon','weaver','forgeheart','turret','tesla','overload','arc'],style:'Ranged support behind a sturdy frontline'},
 {id:'gold',name:'Gold Bastion',badge:'IV',min:540,difficulty:4,rival:'Bastion Ace',deck:['micro','prowler','merc','starforge','beacon','photon','cryo','aegis'],style:'Fast pressure and reinforcement timing'},
 {id:'platinum',name:'Platinum Rift',badge:'V',min:840,difficulty:5,rival:'Rift Tactician',deck:['jade','forgeheart','stormwarden','void','turret','tesla','beacon','arc'],style:'Siege threats and layered defense'},
 {id:'diamond',name:'Diamond Spire',badge:'VI',min:1200,difficulty:6,rival:'Spire Champion',deck:['aegis','stormwarden','jade','falcon','turret','tesla','overload','photon'],style:'Counter-picks, spell value, and lane pressure'},
 {id:'master',name:'Master Orbit',badge:'VII',min:1620,difficulty:7,rival:'Orbit Grandmaster',deck:['micro','prowler','weaver','starforge','forgeheart','cryo','tesla','void'],style:'Quick responses and coordinated pushes'},
 {id:'legend',name:'Legend Crown',badge:'VIII',min:2100,difficulty:8,rival:'The Arena Legend',deck:['aegis','stormwarden','jade','void','tesla','forgeheart','arc','cryo'],style:'Elite deck and maximum tactical pressure'}
]);
export function ladderTierIndex(trophies=0){let index=0;for(let i=1;i<LADDER.length;i++)if(trophies>=LADDER[i].min)index=i;return index;}
export function trophyDelta(result,difficulty=1){const level=Math.max(1,Math.min(8,Math.round(difficulty)));if(result==='win')return 22+level*4;if(result==='loss')return -(8+level*2);return 0;}
export function ladderProgress(trophies=0){const index=ladderTierIndex(trophies),current=LADDER[index],next=LADDER[index+1]||null,points=Math.max(0,trophies-current.min),span=next?next.min-current.min:1;return{index,current,next,points,span,ratio:next?Math.max(0,Math.min(1,points/span)):1};}
