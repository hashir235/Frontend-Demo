const http = require('http');

const server = http.createServer((req, res) => {
  if (req.url === '/api/auth/me') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      user: {
        id: 'emulator-check',
        fullName: 'Codex QA',
        email: 'qa@example.com',
      },
      expiresAt: '2027-03-10T00:00:00.000Z',
    }));
    return;
  }

  if (req.url === '/api/auth/logout') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end('{}');
    return;
  }

  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Not found' }));
});

server.listen(8080, '127.0.0.1');