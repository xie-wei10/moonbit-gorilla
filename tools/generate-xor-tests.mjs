import fs from 'node:fs';
const saved=JSON.parse(fs.readFileSync(new URL('../evidence/xor-reference-vectors.json',import.meta.url),'utf8'));
const selected=saved.cases.map((test,i)=>({test,reference:saved.reference[i]})).filter(({test})=>test.name==='empty'||test.name.startsWith('first ')&&test.name.endsWith(' 9218868437227405313')||test.name.startsWith('delta bucket ')&&test.name.endsWith('/1')||['xor window 0','xor window 31','xor window 32','xor window 63','timestamp wrap and reverse','seeded irregular 3'].includes(test.name));
const bytes=hex=>'b"'+hex.match(/../g).map(x=>'\\x'+x).join('')+'"';
const body=selected.map(({test,reference})=>{
  if(!reference.ok)throw Error(test.name);
  return `  // ${test.name}\n  {\n    let samples : Array[@gorilla.Sample] = [${test.samples.map(s=>`{timestamp: ${s.timestamp}L, bits: ${s.bits}UL}`).join(', ')}]\n    let expected = ${bytes(reference.hex)}\n    assert_eq(@gorilla.encode_xor(samples), expected)\n    assert_eq(@gorilla.decode_xor(expected), samples)\n  }`;
}).join('\n');
fs.writeFileSync(new URL('../xor_vectors_test.mbt',import.meta.url),`// Generated from saved unmodified Prometheus v0.314.0 reference bytes.\n///|\ntest "${selected.length} independent Prometheus vectors on every backend" {\n${body}\n}\n`);
console.log(`Generated ${selected.length} independent backend byte vectors`);
