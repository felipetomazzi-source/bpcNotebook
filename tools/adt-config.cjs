const fs=require('node:fs');
const path=require('node:path');
const {createRequire}=require('node:module');
module.exports=()=>{
  const base=process.env.BPC_ADT_TOOL_ROOT;
  if(!base)throw new Error('Set BPC_ADT_TOOL_ROOT to installed mcp-abap-abap-adt-api');
  const load=createRequire(path.join(base,'package.json'));
  load('dotenv').config({path:path.join(base,'.env'),quiet:true});
  if(process.argv.includes('--codex-env')){
    const config=fs.readFileSync(path.join(process.env.USERPROFILE,'.codex','config.toml'),'utf8');
    const section=config.split('[mcp_servers.adt.env]')[1]?.split(/^\[/m)[0];
    if(!section)throw new Error('Configured ADT environment not found');
    for(const line of section.split(/\r?\n/)){
      const m=line.match(/^\s*(SAP_[A-Z_]+)\s*=\s*(".*")\s*$/);
      if(m)process.env[m[1]]=JSON.parse(m[2]);
    }
  }
  const {ADTClient}=load('abap-adt-api');
  return new ADTClient(process.env.SAP_URL,process.env.SAP_USER,process.env.SAP_PASSWORD,process.env.SAP_CLIENT,process.env.SAP_LANGUAGE);
};
