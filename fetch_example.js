const https = require('https');

https.get('https://example.com', (res) => {
  console.log(`Status code: ${res.statusCode}`);
  res.resume();
}).on('error', (err) => {
  console.error('Request failed:', err.message);
  process.exitCode = 1;
});
