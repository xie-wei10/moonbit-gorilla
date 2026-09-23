import fs from 'node:fs/promises';
for(const [source,target] of [['web','engine'],['moonpromql','moonpromql-engine']])await fs.copyFile(new URL(`../_build/js/debug/build/cmd/${source}/${source}.js`,import.meta.url),new URL(`../web/${target}.mjs`,import.meta.url));
