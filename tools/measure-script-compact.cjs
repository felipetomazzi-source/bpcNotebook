// Read-only size audit of authored Script files. Does not rewrite calculation sources.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
let Script;vm.runInNewContext(fs.readFileSync('webapp/model/Script.js','utf8'),{sap:{ui:{define:(_,f)=>Script=f()}},TextEncoder,TextDecoder,btoa,atob});
const directory=process.argv[2];if(!directory)throw Error('Supply directory containing .bns files');
const result=fs.readdirSync(directory).filter(n=>n.endsWith('.bns')).map(name=>{
 const source=fs.readFileSync(path.join(directory,name),'utf8');
 function size(text){try{return {characters:Script.compile(text).length};}catch(error){return {error:error.message,characters:error.generatedCharacters};}}
 const normalized=source.replaceAll('\r\n','\n');
 const defaults=normalized.replace(/for (\w+) in (\w+)\n((?:if initial\(\1\.[A-Z0-9_]+\)\n\1\.[A-Z0-9_]+ = "(?:[^"\\]|\\.)*"\nend\n)+)end/g,(full,row,table,body)=>{
  const pairs=[...body.matchAll(/if initial\(\w+\.([A-Z0-9_]+)\)\n\w+\.([A-Z0-9_]+) = ("(?:[^"\\]|\\.)*")\nend/g)];
  if(pairs.some(p=>p[1]!==p[2]))return full;
  return 'defaults '+table+' with '+pairs.map(p=>p[1]+' '+p[3]).join(', ');
 });
 return {name,authorCharacters:source.length,ordinary:size(source),compact:size(source.replace(/^script version 2(?=\r?\n)/,'script version 2 compact')),
  compactDefaults:size(defaults.replace(/^script version 2(?=\n)/,'script version 2 compact'))};
});
console.log(JSON.stringify(result,null,2));
