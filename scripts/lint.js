import {spawnSync} from 'node:child_process';
const files=['src/cards.js','src/sim.js','scripts/simulate.js','scripts/generate-audio.js','scripts/verify-audio.js','tests/mechanics.test.js'];
for(const file of files){const r=spawnSync(process.execPath,['--check',file],{encoding:'utf8'});if(r.status!==0){process.stderr.write(r.stderr||r.stdout);process.exit(r.status||1);} }
console.log('Syntax checks passed for '+files.length+' JavaScript files (JSX is checked by Expo export).');
