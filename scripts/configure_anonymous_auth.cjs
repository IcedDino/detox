// Uses the existing Firebase CLI login without printing credentials.
const path = require('node:path');
const cliRoot = process.argv[2];
const apply = process.argv.includes('--apply');
const { configstore } = require(path.join(cliRoot, 'lib/configstore'));
const { requireAuth } = require(path.join(cliRoot, 'lib/requireAuth'));
const { Client } = require(path.join(cliRoot, 'lib/apiv2'));
(async () => {
  await requireAuth({ project: 'detox-c0790', user: configstore.get('user'), tokens: configstore.get('tokens') });
  const client = new Client({ urlPrefix: 'https://identitytoolkit.googleapis.com', apiVersion: 'v2' });
  const endpoint = '/projects/detox-c0790/config';
  if (apply) await client.patch(endpoint, { signIn: { anonymous: { enabled: true } } }, { queryParams: { updateMask: 'signIn.anonymous.enabled' } });
  const result = await client.get(endpoint);
  console.log(JSON.stringify({ anonymousEnabled: result.body.signIn?.anonymous?.enabled === true }));
})().catch(e => { console.error(e.message); process.exitCode = 1; });
