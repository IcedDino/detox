// Read execution status using the existing clasp login; never print tokens.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { OAuth2Client } = require(path.join(process.argv[2], 'node_modules/google-auth-library'));
(async () => {
  const auth = JSON.parse(fs.readFileSync(path.join(os.homedir(), '.clasprc.json'), 'utf8')).tokens.default;
  const client = new OAuth2Client(auth.client_id, auth.client_secret);
  client.setCredentials(auth);
  const scriptId = JSON.parse(fs.readFileSync('.clasp.json', 'utf8')).scriptId;
  const result = await client.request({
    url: 'https://script.googleapis.com/v1/processes:listScriptProcesses',
    params: { scriptId, pageSize: 20 },
  });
  console.log(JSON.stringify(result.data));
})().catch(error => { console.error(error.message); process.exitCode = 1; });
