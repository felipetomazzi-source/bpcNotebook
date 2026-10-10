// Wrap changed long JavaScript lines at token boundaries for SAP's BSP serializer.
import {readFileSync,writeFileSync} from 'node:fs';
const path='webapp/model/Script.js',source=readFileSync(path,'utf8');
const lines=source.split(/\r\n|\n|\r/).flatMap(line=>{
 if(line.length<=255)return [line];
 let quoted='',escape=false,start=0,cut=-1,result=[];
 for(let i=0;i<line.length;i++){
  const c=line[i];
  if(quoted){if(escape)escape=false;else if(c==='\\')escape=true;else if(c===quoted)quoted='';}
  else if(c==='"'||c==="'")quoted=c;
  else if(c===' ')cut=i;
  if(i-start>=205&&cut>start){result.push(line.slice(start,cut));start=cut+1;cut=-1;}
 }
 result.push(line.slice(start));
 if(result.some(s=>s.length>255))throw Error('Cannot safely wrap long source line');
 return result;
});
writeFileSync(path,lines.join('\r\n'),'utf8');
