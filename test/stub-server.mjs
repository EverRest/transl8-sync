// A small stand-in for the transl8 export endpoint, for the CI integration job.
// It answers every request with a fixed JSON file.
// The first line on stdout is the port. Set PORT to choose one.
import { createServer } from 'node:http';

const server = createServer((req, res) => {
  console.error(`${req.method} ${req.url} auth=${req.headers.authorization ? 'yes' : 'no'}`);
  res.writeHead(200, {
    'Content-Type': 'application/json',
    'Content-Disposition': 'attachment; filename="fr.json"',
  });
  res.end('{"hello":"bonjour"}');
});

server.listen(Number(process.env.PORT) || 0, '127.0.0.1', () => {
  console.log(server.address().port);
});
