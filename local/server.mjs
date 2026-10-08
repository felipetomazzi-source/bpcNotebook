import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { resolve, extname, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Engine, demo, Fault } from './engine.mjs';

const root = resolve(fileURLToPath(new URL('../webapp', import.meta.url)));
export function createServer(engine = new Engine({file: resolve('.local/store.json')})) {
  const user = 'LOCAL_DEVELOPER';
  const server = http.createServer(async (req,res) => {
    const json = (status, value) => { res.writeHead(status, {'Content-Type':'application/json', 'Cache-Control':'no-store'}); res.end(JSON.stringify(value)); };
    try {
      const url = new URL(req.url, 'http://localhost');
      if (url.pathname === '/favicon.ico') { res.writeHead(204);res.end();return; }
      if (url.pathname.startsWith('/api/')) {
        let body = {};
        if (['POST','PUT'].includes(req.method)) {
          if (req.headers['x-bpc-notebook'] !== '1') throw new Fault(403,'CSRF','Required request header missing');
          if (req.headers.origin && req.headers.origin !== 'http://' + req.headers.host) throw new Fault(403,'ORIGIN','Cross-origin write refused');
          let raw = ''; for await (const chunk of req) { raw += chunk; if (raw.length > 2e6) throw new Fault(413,'SIZE','Request too large'); }
          try { body = JSON.parse(raw || '{}'); } catch { throw new Fault(400,'JSON','Invalid JSON'); }
        }
        const p = url.searchParams; const path = url.pathname.slice(4);
        let value;
        if (path === '/notebooks' && req.method === 'GET') value = engine.list(user);
        else if (path === '/notebooks' && req.method === 'POST') value = engine.create(body.demo ? demo() : body,user);
        else if (path === '/notebook' && req.method === 'GET') value = engine.get(p.get('id'),user);
        else if (path === '/notebook' && req.method === 'PUT') value = engine.save(body.id,body,user);
        else if (path === '/versions' && req.method === 'GET') value = engine.history(p.get('id'),user);
        else if (path === '/validate' && req.method === 'POST') value = engine.validate(body.notebookId,body.cellId,user);
        else if (path === '/runs' && req.method === 'POST') value = engine.submit(body,user);
        else if (path === '/runs' && req.method === 'GET') value = engine.runs(p.get('notebookId'),user);
        else if (path === '/run' && req.method === 'GET') value = engine.run(p.get('id'),user);
        else if (path === '/cancel' && req.method === 'POST') value = engine.cancel(body.id,user);
        else if (path === '/retry' && req.method === 'POST') value = engine.retry(body.id,body.idempotencyKey,user);
        else if (path === '/output' && req.method === 'GET') value = engine.preview(p.get('runId'),p.get('cellId'),Number(p.get('revision')),Number(p.get('offset')),Number(p.get('limit')),user);
        else throw new Fault(404,'ROUTE','Unknown endpoint');
        return json(req.method === 'POST' && path === '/runs' ? 202 : 200,value);
      }
      if (req.method !== 'GET') throw new Fault(405,'METHOD','Method not allowed');
      const path = resolve(root, '.' + decodeURIComponent(url.pathname === '/' ? '/index.html' : url.pathname));
      if (!path.startsWith(root + sep)) throw new Fault(403,'PATH','Invalid path');
      const bytes = await readFile(path);
      res.writeHead(200, {'Content-Type':({'.html':'text/html','.js':'text/javascript','.css':'text/css','.json':'application/json'})[extname(path)] || 'application/octet-stream'}); res.end(bytes);
    } catch (e) { json(e.status || (e.code === 'ENOENT' ? 404 : 500),{code:e.code || 'INTERNAL',message:e.status ? e.message : 'Request failed'}); }
  });
  return server;
}
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const server = createServer(); const port = Number(process.env.PORT || 4173);
  server.listen(port,'127.0.0.1',() => console.log(`BPC Notebook local simulation: http://127.0.0.1:${port}`));
}
