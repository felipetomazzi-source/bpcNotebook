import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { join, relative } from 'node:path';
import { bspContent, readUtf8 } from './sap-bytes.mjs';
const metadata=readUtf8('src/zbpc_notebook.wapa.xml');
const pages=[...metadata.matchAll(/<PAGENAME>([^<]+)<\/PAGENAME>/g)].map(m=>m[1]);
const mappings=readUtf8('webapp/UI5RepositoryPathMapping.xml');
const entries=[...mappings.matchAll(/<MappingEntry path="([^"]+)"[^>]*internal_rep_path="([^"]+)"/g)].map(m=>[m[1],m[2]]);
const map=new Map(entries);
const expected=new Set();
function walk(dir){for(const entry of readdirSync(dir,{withFileTypes:true})){
 const path=join(dir,entry.name);if(entry.isDirectory()){walk(path);continue;}
 const external=relative('webapp',path).replaceAll('\\','/');
 const internal=external==='UI5RepositoryPathMapping.xml'?external:map.get(external);
 if(!internal)throw Error('Missing UI5 repository mapping: '+external);
 if(!pages.includes(internal))throw Error('BSP metadata lacks page '+internal+'; import and serialize updated metadata in SAP.');
 const name='zbpc_notebook.wapa.'+internal.toLowerCase().replaceAll('/','_-');expected.add(name);
 let text=readUtf8(path);
 writeFileSync(join('src',name),bspContent(text),'utf8');
}}
walk('webapp');
for(const name of readdirSync('src').filter(n=>n.startsWith('zbpc_notebook.wapa.')&&n!=='zbpc_notebook.wapa.xml'))if(!expected.has(name))throw Error('Stale BSP resource: '+name);
if(pages.length!==expected.size || entries.length!==expected.size-1)throw Error('BSP metadata/mapping resource counts differ.');
console.log('Packed '+expected.size+' BSP resources; preserved SAP metadata and native sources.');
