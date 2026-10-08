import { readFileSync } from 'node:fs';
// Fatal UTF-8 decoding prevents replacement characters from hiding damaged input.
export function readUtf8(path){
 const bytes=readFileSync(path);
 return new TextDecoder('utf-8',{fatal:true,ignoreBOM:true}).decode(bytes);
}
export function bspContent(text){
 if(text.startsWith('\uFEFF'))throw Error('BSP input unexpectedly contains a BOM; preserve its convention explicitly.');
 const lines=text.split(/\r\n|\n/);
 if(lines.some(line=>line.includes('\r')))throw Error('Unsupported bare CR in BSP input');
 if(lines.some(line=>line.length>255))throw Error('WAPA line exceeds 255 characters');
 // A final empty split entry is intentional only when the input ends in a newline.
 return lines.map(line=>line.padEnd(255,' ')).join('\r\n');
}
export function gitBytes(bytes){
 return Buffer.from(new TextDecoder('utf-8',{fatal:true,ignoreBOM:true}).decode(bytes).replaceAll('\r\n','\n'),'utf8');
}
