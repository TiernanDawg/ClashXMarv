import React, {useEffect, useRef, useState} from 'react';
import {SafeAreaView, View, Text, Pressable, StyleSheet, ScrollView, Dimensions} from 'react-native';
import {StatusBar} from 'expo-status-bar';

const WIDTH = Dimensions.get('window').width;
const CARDS = [
  {id:'titan',name:'TITAN',role:'VANGUARD',cost:4,hp:190,dmg:24,range:30,speed:10,color:'#6DE0FF',symbol:'T'},
  {id:'volt',name:'VOLT',role:'STRIKER',cost:3,hp:85,dmg:32,range:100,speed:15,color:'#FFD166',symbol:'ϟ'},
  {id:'wraith',name:'WRAITH',role:'ASSASSIN',cost:3,hp:75,dmg:38,range:25,speed:19,color:'#C5A3FF',symbol:'W'},
  {id:'nova',name:'NOVA',role:'BLASTER',cost:5,hp:110,dmg:42,range:120,speed:9,color:'#FF8B70',symbol:'✦'},
  {id:'pulse',name:'PULSE',role:'SUPPORT',cost:3,hp:100,dmg:17,range:85,speed:11,color:'#7DFFB3',symbol:'P'},
  {id:'sentinel',name:'SENTINEL',role:'GUARD',cost:4,hp:155,dmg:25,range:65,speed:9,color:'#9AB5FF',symbol:'S'},
  {id:'sparks',name:'SPARKS',role:'SWARM',cost:2,hp:48,dmg:13,range:24,speed:18,color:'#FFDC70',symbol:'✧'},
  {id:'rift',name:'RIFT',role:'CONTROLLER',cost:4,hp:105,dmg:27,range:105,speed:10,color:'#FF8AC8',symbol:'R'}
];
const INITIAL_TOWERS = () => [
  {id:'e-left',team:'enemy',lane:0,x:25,y:34,hp:420,max:420,kind:'side'},
  {id:'e-right',team:'enemy',lane:1,x:75,y:34,hp:420,max:420,kind:'side'},
  {id:'e-king',team:'enemy',lane:0.5,x:50,y:10,hp:700,max:700,kind:'king'},
  {id:'p-left',team:'player',lane:0,x:25,y:66,hp:420,max:420,kind:'side'},
  {id:'p-right',team:'player',lane:1,x:75,y:66,hp:420,max:420,kind:'side'},
  {id:'p-king',team:'player',lane:0.5,x:50,y:90,hp:700,max:700,kind:'king'}
];
const makeUnit = (card,team,lane,id) => ({id,card:card.id,team,lane,x:lane===0?25:75,y:team==='player'?79:21,hp:card.hp,max:card.hp,attack:0});
const fmt = n => Math.max(0,Math.ceil(n)).toString().padStart(2,'0');

export default function App() {
  const [screen,setScreen] = useState('battle');
  const [energy,setEnergy] = useState(5);
  const [enemyEnergy,setEnemyEnergy] = useState(5);
  const [units,setUnits] = useState([]);
  const [towers,setTowers] = useState(INITIAL_TOWERS());
  const [time,setTime] = useState(180);
  const [selected,setSelected] = useState(0);
  const [next,setNext] = useState(4);
  const [message,setMessage] = useState('DEPLOY A HERO');
  const [result,setResult] = useState('');
  const idRef = useRef(0);
  const aiRef = useRef(4);
  const cardsInHand = [CARDS[selected%8],CARDS[(selected+1)%8],CARDS[(selected+2)%8],CARDS[(selected+3)%8]];
  const deploy = (card,lane,team='player') => {
    if(team==='player' && energy<card.cost) {setMessage('NOT ENOUGH ENERGY');return;}
    if(team==='player') {setEnergy(v=>v-card.cost);setSelected(v=>(v+1)%8);setNext(v=>(v+1)%8);setMessage(card.name+' DEPLOYED');}
    else setEnemyEnergy(v=>Math.max(0,v-card.cost));
    setUnits(v=>[...v,makeUnit(card,team,lane,++idRef.current)]);
  };
  const reset = () => {setUnits([]);setTowers(INITIAL_TOWERS());setEnergy(5);setEnemyEnergy(5);setTime(180);setSelected(0);setNext(4);setResult('');setMessage('DEPLOY A HERO');aiRef.current=4;};
  useEffect(()=>{
    if(result || screen!=='battle') return;
    const timer=setInterval(()=>{
      setTime(t=>{if(t<=1){setResult('TIME UP');return 0;}return t-1;});
      setEnergy(e=>Math.min(10,e+(time<=60?0.28:0.17)));
      setEnemyEnergy(e=>Math.min(10,e+(time<=60?0.28:0.17)));
      aiRef.current-=0.25;
      if(aiRef.current<=0){
        const playable=CARDS.filter(c=>c.cost<=enemyEnergy);
        if(playable.length){const c=playable[Math.floor(Math.random()*playable.length)];deploy(c,Math.random()<0.5?0:1,'enemy');}
        aiRef.current=2.5+Math.random()*3.5;
      }
      setUnits(prev=>{
        let arr=prev.map(u=>({...u,hp:u.hp,attack:u.attack+0.25}));
        const dead=new Set();
        arr.forEach((u,i)=>{
          if(u.hp<=0)return;
          const enemies=arr.filter(v=>v.team!==u.team&&v.lane===u.lane&&Math.abs(v.y-u.y)<9&&v.hp>0);
          const target=enemies.sort((a,b)=>Math.abs(a.y-u.y)-Math.abs(b.y-u.y))[0];
          const card=CARDS.find(c=>c.id===u.card);
          if(target && Math.abs(target.y-u.y)<(card.range>50?12:5)){
            if(u.attack>=1){target.hp-=card.dmg;u.attack=0;}
          }else{
            const opposingTowers=towers.filter(t=>t.team!==(u.team)&&t.hp>0&&t.kind==='side'&&t.lane===u.lane);
            const tower=opposingTowers[0];
            if(tower && Math.abs(tower.y-u.y)<8){if(u.attack>=1){setTowers(ts=>ts.map(t=>t.id===tower.id?{...t,hp:t.hp-card.dmg}:t));u.attack=0;}}
            else u.y += (u.team==='player'?-1:1)*card.speed*0.25;
          }
        });
        arr=arr.filter(u=>u.hp>0&&u.y>3&&u.y<97);
        return arr;
      });
      setTowers(ts=>ts.map(t=>{
        if(t.hp<=0)return t;
        const target=units.find(u=>u.team!==t.team&&Math.abs(u.x-t.x)<17&&Math.abs(u.y-t.y)<10);
        if(target && Math.random()<0.22)return {...t,hp:t.hp-15};
        return t;
      }));
    },250);
    return ()=>clearInterval(timer);
  },[result,screen,time,enemyEnergy,towers,units]);
  useEffect(()=>{
    if(!result)return;
    const p=towers.filter(t=>t.team==='player').reduce((s,t)=>s+Math.max(0,t.hp),0);
    const e=towers.filter(t=>t.team==='enemy').reduce((s,t)=>s+Math.max(0,t.hp),0);
    setResult(p===e?'DRAW':p>e?'VICTORY':'DEFEAT');
  },[result==='TIME UP']);
  const totalEnemy=towers.filter(t=>t.team==='enemy').reduce((s,t)=>s+t.hp,0);
  const totalPlayer=towers.filter(t=>t.team==='player').reduce((s,t)=>s+t.hp,0);
  const playCard=(card)=>deploy(card,0);
  return <SafeAreaView style={s.safe}><StatusBar style="light"/><View style={s.top}>
    <View><Text style={s.brand}>CLASH<Text style={{color:'#F4B94D'}}>X</Text>MARV</Text><Text style={s.sub}>HERO ARENA // PROTOTYPE</Text></View>
    <View style={s.timer}><Text style={s.timerText}>{fmt(Math.floor(time/60))}:{fmt(time%60)}</Text><Text style={s.timerSub}>{time<=60?'OVERTIME ENERGY':'BATTLE TIME'}</Text></View>
  </View>
  {screen==='roster'?<ScrollView contentContainerStyle={s.roster}><Text style={s.section}>HERO DATABASE</Text>{CARDS.map(c=><View key={c.id} style={s.rosterCard}><View style={[s.avatar,{borderColor:c.color}]}><Text style={[s.avatarText,{color:c.color}]}>{c.symbol}</Text></View><View style={{flex:1}}><Text style={s.cardName}>{c.name}</Text><Text style={s.cardRole}>{c.role} · {c.hp} HP · {c.dmg} DMG</Text></View><Text style={s.cost}>{c.cost}◆</Text></View>)}<Pressable style={s.mainBtn} onPress={()=>setScreen('battle')}><Text style={s.mainBtnText}>RETURN TO ARENA</Text></Pressable></ScrollView>:<>
  <View style={s.stats}><Text style={s.statText}>ENEMY CORE <Text style={{color:'#FF7979'}}>{Math.max(0,totalEnemy)}</Text></Text><Text style={s.statText}>YOUR CORE <Text style={{color:'#6DE0FF'}}>{Math.max(0,totalPlayer)}</Text></Text></View>
  <View style={s.arena}>
    <View style={s.enemyZone}/><View style={s.river}/><View style={s.bridgeLeft}/><View style={s.bridgeRight}/><View style={s.laneLine}/>
    <Text style={s.zoneLabel}>OPPONENT TERRITORY</Text><Text style={[s.zoneLabel,{top:'53%',color:'#83DDF6'}]}>YOUR TERRITORY</Text>
    {towers.map(t=><View key={t.id} style={[s.tower,{left:(t.x-7)+'%',top:(t.y-4)+'%',width:t.kind==='king'?52:42,height:t.kind==='king'?48:40,borderColor:t.team==='player'?'#65DDF7':'#FF727D',opacity:t.hp>0?1:0.25}]}><Text style={s.towerSymbol}>{t.kind==='king'?'♛':'◆'}</Text><View style={s.hpBack}><View style={[s.hpFill,{width:(Math.max(0,t.hp)/t.max*100)+'%',backgroundColor:t.team==='player'?'#65DDF7':'#FF727D'}]}/></View></View>)}
    {units.map(u=>{const c=CARDS.find(x=>x.id===u.card);return <View key={u.id} style={[s.unit,{left:(u.x-4)+'%',top:(u.y-3)+'%',borderColor:c.color,backgroundColor:u.team==='player'?'#102B40':'#401D2A'}]}><Text style={[s.unitText,{color:c.color}]}>{c.symbol}</Text><View style={s.unitHp}><View style={{height:3,width:Math.max(0,u.hp/u.max*100)+'%',backgroundColor:c.color}}/></View></View>})}
    <Pressable style={s.leftLane} onPress={()=>{}}/><Pressable style={s.rightLane} onPress={()=>{}}/>
    {result?<View style={s.overlay}><Text style={s.result}>{result}</Text><Text style={s.overlaySub}>BATTLE SUMMARY</Text><Pressable style={s.mainBtn} onPress={reset}><Text style={s.mainBtnText}>PLAY AGAIN</Text></Pressable></View>:null}
  </View>
  <View style={s.bottom}><View style={s.energyRow}><Text style={s.energyLabel}>ENERGY</Text><View style={s.energyBar}>{Array.from({length:10},(_,i)=><View key={i} style={[s.energyCell,{backgroundColor:energy>=i+1?'#B58AFF':'#342846'}]}/>)}</View><Text style={s.energyNum}>{Math.floor(energy)}/10</Text></View>
    <Text style={s.hint}>{message} · TAP A CARD, THEN CHOOSE A LANE</Text>
    <View style={s.hand}>{cardsInHand.map((c,i)=><Pressable key={c.id} onPress={()=>{if(energy<c.cost){setMessage('NOT ENOUGH ENERGY');return;}setMessage('CHOOSE A LANE FOR '+c.name);setSelected((selected+i)%8);}} style={[s.handCard,{borderColor:c.color,backgroundColor:'#171C2A'}]}><Text style={[s.costSmall,{color:'#C7A8FF'}]}>{c.cost}◆</Text><Text style={[s.handSymbol,{color:c.color}]}>{c.symbol}</Text><Text style={s.handName}>{c.name}</Text><Text style={s.handRole}>{c.role}</Text><Pressable style={s.deployBtn} onPress={()=>{if(energy>=c.cost)deploy(c,Math.random()<0.5?0:1);else setMessage('NOT ENOUGH ENERGY')}}><Text style={s.deployText}>DEPLOY</Text></Pressable></Pressable>)}</View>
    <View style={s.footer}><Pressable onPress={()=>setScreen('roster')}><Text style={s.footerBtn}>HERO DATABASE</Text></Pressable><Text style={s.footerMid}>AI OPPONENT · LOCAL MATCH</Text><Pressable onPress={reset}><Text style={s.footerBtn}>RESTART</Text></Pressable></View>
  </View></>}
  </SafeAreaView>;
}
const s=StyleSheet.create({
safe:{flex:1,backgroundColor:'#0B0E17'},top:{height:65,paddingHorizontal:18,flexDirection:'row',justifyContent:'space-between',alignItems:'center',borderBottomWidth:1,borderColor:'#262B3C'},brand:{fontSize:23,fontWeight:'900',letterSpacing:1.5,color:'#F1F4FA'},sub:{fontSize:8,color:'#8790A8',letterSpacing:2,marginTop:2},timer:{alignItems:'flex-end'},timerText:{color:'#F5F6FA',fontSize:25,fontWeight:'900',fontVariant:['tabular-nums']},timerSub:{fontSize:8,color:'#F4B94D',letterSpacing:1.3},
stats:{height:30,flexDirection:'row',justifyContent:'space-between',paddingHorizontal:18,alignItems:'center'},statText:{fontSize:9,fontWeight:'800',color:'#A9B1C5',letterSpacing:1},
arena:{flex:1,marginHorizontal:9,borderRadius:12,overflow:'hidden',borderWidth:1,borderColor:'#343A50',backgroundColor:'#111B27',minHeight:250},enemyZone:{position:'absolute',top:0,left:0,right:0,height:'49%',backgroundColor:'#281B2A'},river:{position:'absolute',top:'47%',height:'7%',left:0,right:0,backgroundColor:'#173B54',borderTopWidth:1,borderBottomWidth:1,borderColor:'#2B6B8D'},bridgeLeft:{position:'absolute',top:'46%',left:'13%',height:'9%',width:'24%',backgroundColor:'#6C5A54',borderWidth:1,borderColor:'#B09A81'},bridgeRight:{position:'absolute',top:'46%',left:'63%',height:'9%',width:'24%',backgroundColor:'#6C5A54',borderWidth:1,borderColor:'#B09A81'},laneLine:{position:'absolute',left:'49.5%',top:0,bottom:0,width:1,backgroundColor:'#3D4659'},zoneLabel:{position:'absolute',top:'2%',left:0,right:0,textAlign:'center',fontSize:8,letterSpacing:2,color:'#A18B9E',fontWeight:'800'},
tower:{position:'absolute',alignItems:'center',justifyContent:'center',borderWidth:2,borderRadius:8,backgroundColor:'#1A2231',shadowColor:'#000',shadowOpacity:.5,shadowRadius:4},towerSymbol:{fontSize:20,color:'#E8ECF6'},hpBack:{position:'absolute',bottom:-6,left:1,right:1,height:4,backgroundColor:'#3A2630',borderRadius:3,overflow:'hidden'},hpFill:{height:4},unit:{position:'absolute',width:34,height:34,borderWidth:2,borderRadius:17,alignItems:'center',justifyContent:'center'},unitText:{fontWeight:'900',fontSize:17},unitHp:{position:'absolute',bottom:-5,left:1,right:1,height:3,backgroundColor:'#323344',overflow:'hidden'},leftLane:{position:'absolute',top:'57%',bottom:0,left:0,width:'48%',backgroundColor:'transparent'},rightLane:{position:'absolute',top:'57%',bottom:0,right:0,width:'48%',backgroundColor:'transparent'},
bottom:{paddingHorizontal:10,paddingTop:6,paddingBottom:5},energyRow:{height:22,flexDirection:'row',alignItems:'center',gap:7},energyLabel:{color:'#A8B0C3',fontSize:9,fontWeight:'800',letterSpacing:1},energyBar:{flex:1,flexDirection:'row',gap:3},energyCell:{height:8,flex:1,borderRadius:2},energyNum:{color:'#E9DFFF',fontSize:11,fontWeight:'900',width:30,textAlign:'right'},hint:{color:'#929BB0',fontSize:8,letterSpacing:1,textAlign:'center',marginVertical:5},hand:{height:135,flexDirection:'row',gap:6},handCard:{flex:1,borderWidth:1,borderRadius:8,paddingTop:5,alignItems:'center',overflow:'hidden'},costSmall:{fontSize:9,fontWeight:'900',alignSelf:'flex-start',marginLeft:5},handSymbol:{fontSize:26,fontWeight:'900',marginTop:0},handName:{fontSize:9,color:'#F1F4FB',fontWeight:'900',letterSpacing:.5},handRole:{fontSize:6,color:'#8E98B0',marginTop:2},deployBtn:{position:'absolute',bottom:0,left:0,right:0,height:24,backgroundColor:'#34314A',alignItems:'center',justifyContent:'center'},deployText:{color:'#E9DFFF',fontSize:8,fontWeight:'900',letterSpacing:1},footer:{height:26,flexDirection:'row',alignItems:'center',justifyContent:'space-between'},footerBtn:{color:'#B7A0EE',fontSize:8,fontWeight:'900',letterSpacing:.5},footerMid:{color:'#646E84',fontSize:7,letterSpacing:.5},roster:{padding:18,gap:10},section:{color:'#F4B94D',fontSize:13,fontWeight:'900',letterSpacing:2,marginBottom:6},rosterCard:{height:65,borderRadius:9,borderWidth:1,borderColor:'#30384C',backgroundColor:'#141A28',flexDirection:'row',alignItems:'center',padding:9,gap:12},avatar:{height:42,width:42,borderWidth:1.5,borderRadius:8,alignItems:'center',justifyContent:'center'},avatarText:{fontSize:22,fontWeight:'900'},cardName:{color:'#F4F5FA',fontSize:13,fontWeight:'900',letterSpacing:1},cardRole:{color:'#909AB0',fontSize:9,marginTop:3},cost:{color:'#C6A4FF',fontWeight:'900'},mainBtn:{marginTop:14,backgroundColor:'#C2A0FF',padding:14,borderRadius:8,alignItems:'center'},mainBtnText:{color:'#171321',fontWeight:'900',letterSpacing:1.5},overlay:{position:'absolute',top:0,left:0,right:0,bottom:0,backgroundColor:'rgba(8,10,18,0.87)',alignItems:'center',justifyContent:'center'},result:{color:'#F4B94D',fontSize:36,fontWeight:'900',letterSpacing:3},overlaySub:{color:'#A7B0C4',fontSize:10,letterSpacing:2,marginTop:8}
});
