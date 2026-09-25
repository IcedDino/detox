// Detox support unlink review. Deploy as a web app from a Google account
// with Firestore IAM access to detox-c0790, then run installPollingTrigger().
const PROJECT_ID = 'detox-c0790';
const SUPPORT_EMAIL = 'nerqovaassist@gmail.com';
const WEB_APP_URL = 'https://script.google.com/macros/s/AKfycbwcAYbTIJ8F8_bpBWM02xiA_QXv9SNzTGhap4DGDCEzPIG_DxUUNt54pbhRUAvm-_juww/exec';
const DATABASE = `projects/${PROJECT_ID}/databases/(default)`;
const DOCUMENTS = `${DATABASE}/documents`;
const FIRESTORE_API = 'https://firestore.googleapis.com/v1/';
const TOKEN_LIFETIME_MS = 7 * 24 * 60 * 60 * 1000;
const EMAIL_COOLDOWN_MS = 10 * 60 * 1000;
const PAIR_REQUEST_TYPES = [
  'settings_unlock', 'zone_override', 'shield_pause',
  'unlink_sponsor', 'unlink_email',
];

function installPollingTrigger() {
  const triggers = ScriptApp.getProjectTriggers();
  if (!triggers.some(trigger =>
      trigger.getHandlerFunction() === 'processSupportUnlinkRequests_')) {
    ScriptApp.newTrigger('processSupportUnlinkRequests_')
      .timeBased().everyMinutes(5).create();
  }
  return `Listo: ${WEB_APP_URL}`;
}

function processSupportUnlinkRequests_() {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(1000)) return;
  try {
    for (const doc of pendingRequests_()) {
      try {
        sendReviewEmail_(doc, WEB_APP_URL);
      } catch (error) {
        console.error(`No se pudo enviar ${doc.name}: ${error}`);
      }
    }
  } finally {
    lock.releaseLock();
  }
}

function sendReviewEmail_(doc, webAppUrl) {
  const requestId = doc.name.split('/').pop();
  const request = decodeDocument_(doc);
  if (!validRequestId_(requestId) ||
      request.requesterUid !== requestId.slice(0, -'_admin_unlink'.length) ||
      request.status !== 'pending' || !request.updatedAt) return false;

  const revision = String(request.updatedAt);
  if (request.reviewNotificationRevision === revision &&
      request.reviewNotifiedAt) return false;
  const lastAttempt = Date.parse(request.reviewNotificationAt || '');
  if (Number.isFinite(lastAttempt) &&
      Date.now() - lastAttempt < EMAIL_COOLDOWN_MS) return false;
  if (MailApp.getRemainingDailyQuota() < 1) {
    throw new Error('Se agotó la cuota diaria de correo.');
  }

  const token = `${Utilities.getUuid()}${Utilities.getUuid()}`.replace(/-/g, '');
  const claimedAt = new Date().toISOString();
  const claim = updateWrite_(doc.name, {
    reviewTokenHash: stringValue_(hashToken_(token)),
    reviewTokenExpiresAt: timestampValue_(
      new Date(Date.now() + TOKEN_LIFETIME_MS).toISOString()),
    reviewNotificationRevision: stringValue_(revision),
    reviewNotificationAt: timestampValue_(claimedAt),
  }, ['reviewNotifiedAt'], doc.updateTime);
  const claimed = commit_([claim]);

  const name = String(request.requesterName || 'Usuario Detox').slice(0, 200);
  const email = String(request.requesterEmail || '').slice(0, 254);
  const message = String(request.message || '').slice(0, 2000);
  const approve = actionUrl_(webAppUrl, requestId, token, 'approve');
  const deny = actionUrl_(webAppUrl, requestId, token, 'deny');
  const text = [
    `Solicitante: ${name}`, `Correo: ${email}`,
    `UID: ${request.requesterUid}`, `Mensaje: ${message || '(sin mensaje)'}`,
    '', `Aceptar: ${approve}`, `Denegar: ${deny}`,
    '', 'Cada enlace abre una confirmación y vence en siete días.',
  ].join('\n');
  const html = `<p><strong>Solicitante:</strong> ${escapeHtml_(name)}<br>` +
    `<strong>Correo:</strong> ${escapeHtml_(email)}<br>` +
    `<strong>UID:</strong> ${escapeHtml_(request.requesterUid)}</p>` +
    `<p><strong>Mensaje:</strong> ${escapeHtml_(message || '(sin mensaje)')}</p>` +
    `<p><a href="${escapeHtml_(approve)}">Aceptar</a> · ` +
    `<a href="${escapeHtml_(deny)}">Denegar</a></p>` +
    '<p>El enlace abre una confirmación y vence en siete días.</p>';
  MailApp.sendEmail(SUPPORT_EMAIL,
    `Detox: solicitud de desvinculación de ${name}`, text,
    { htmlBody: html, name: 'Detox' });

  // A failed acknowledgement may cause one duplicate email after the cooldown.
  // The old token is invalidated by the retry, so it cannot apply twice.
  const claimedUpdateTime = claimed.writeResults[0].updateTime;
  commit_([updateWrite_(doc.name, {
    reviewNotifiedAt: timestampValue_(new Date().toISOString()),
  }, [], claimedUpdateTime)]);
  return true;
}

function doGet(e) {
  const input = e && e.parameter || {};
  const review = loadReview_(input);
  if (!review) return page_('Enlace vencido o ya utilizado',
    '<p>Solicita una nueva revisión desde la aplicación.</p>');
  const actionLabel = input.action === 'approve' ? 'Aceptar' : 'Denegar';
  const body = `<p><strong>Solicitante:</strong> ${escapeHtml_(review.requesterName)}` +
    `<br><strong>Correo:</strong> ${escapeHtml_(review.requesterEmail)}</p>` +
    `<p><strong>Mensaje:</strong> ${escapeHtml_(review.message || '(sin mensaje)')}</p>` +
    `<p>${input.action === 'approve'
      ? 'Al confirmar, se desvincularán ambas cuentas.'
      : 'Al confirmar, la solicitud quedará denegada.'}</p>`;
  return page_(`${actionLabel} desvinculación`, body, input);
}

function doPost(e) {
  const input = e && e.parameter || {};
  if (!validReviewInput_(input)) return page_('Enlace inválido',
    '<p>No se realizó ningún cambio.</p>');
  const replyMessage = String(input.replyMessage || '').trim();
  if (input.action === 'deny' &&
      (replyMessage.length === 0 || replyMessage.length > 1000)) {
    return page_('Escribe el motivo',
      '<p>Para denegar, escribe un motivo de hasta 1000 caracteres.</p>', input);
  }
  try {
    const result = decideReview_(input);
    const outcomes = {
      approved: ['Desvinculación aceptada', '<p>Las cuentas quedaron desvinculadas.</p>'],
      denied: ['Solicitud denegada', '<p>La solicitud quedó denegada.</p>'],
      stale: ['El vínculo cambió', '<p>El vínculo actual ya no coincide con la solicitud. Revisa Firestore.</p>'],
      closed: ['Enlace vencido o ya utilizado', '<p>No se realizó ningún cambio.</p>'],
    };
    const outcome = outcomes[result] || outcomes.closed;
    return page_(outcome[0], outcome[1]);
  } catch (error) {
    console.error(`No se pudo decidir ${input.requestId}: ${error}`);
    return page_('No se pudo procesar', '<p>Inténtalo de nuevo más tarde.</p>');
  }
}

function decideReview_(input) {
  const doc = getDocument_(`meta/admin/unlink_requests/${input.requestId}`);
  if (!readyReview_(doc, input.token)) return 'closed';
  if (input.action === 'deny') {
    const reason = String(input.replyMessage || '').trim();
    if (reason.length === 0 || reason.length > 1000) return 'invalid_reason';
    const now = new Date().toISOString();
    commit_([
      historyWrite_(doc, 'denied', reason, now),
      decisionWrite_(doc, 'denied', reason, now),
    ]);
    return 'denied';
  }

  const request = decodeDocument_(doc);
  const requesterUid = request.requesterUid;
  const sponsorUid = request.sponsorUid;
  if (!validUid_(requesterUid) || !validUid_(sponsorUid) ||
      input.requestId !== `${requesterUid}_admin_unlink` ||
      requesterUid === sponsorUid) return 'stale';
  const requester = getDocument_(`users/${requesterUid}`);
  const sponsor = getDocument_(`users/${sponsorUid}`);
  if (!requester || !sponsor ||
      decodeDocument_(requester).sponsorUid !== sponsorUid) return 'stale';

  const now = new Date().toISOString();
  const clearFields = [
    'sponsorUid', 'sponsorLinkedAt', 'settingsUnlockUntil',
    'zoneOverrideUntil', 'shieldPauseUntil', 'unlinkEmailCode',
    'unlinkEmailCodeExpiresAt', 'unlinkEmailRequestId',
  ];
  const writes = [
    updateWrite_(requester.name, { updatedAt: timestampValue_(now) },
      clearFields, requester.updateTime),
  ];
  const sponsorLinkedBack = decodeDocument_(sponsor).sponsorUid === requesterUid;
  writes.push(updateWrite_(sponsor.name,
    { updatedAt: timestampValue_(now) },
    sponsorLinkedBack ? clearFields : [], sponsor.updateTime));

  for (const type of PAIR_REQUEST_TYPES) {
    writes.push({ delete: documentName_(`meta/sponsor/unlock_requests/${requesterUid}_${type}`) });
    writes.push({ delete: documentName_(`meta/sponsor/unlock_requests/${sponsorUid}_${type}`) });
  }
  writes.push({ delete: documentName_(
    `meta/sponsor/link_requests/${requesterUid}_${sponsorUid}_sponsor`) });
  writes.push({ delete: documentName_(
    `meta/sponsor/link_requests/${sponsorUid}_${requesterUid}_sponsor`) });
  writes.push(historyWrite_(doc, 'approved', '', now));
  writes.push(decisionWrite_(doc, 'approved', '', now));
  commit_(writes);
  return 'approved';
}

function decisionWrite_(doc, status, replyMessage, now) {
  const fields = {
    status: stringValue_(status),
    decidedAt: timestampValue_(now),
    updatedAt: timestampValue_(now),
  };
  if (status === 'denied') fields.replyMessage = stringValue_(replyMessage);
  return updateWrite_(doc.name, fields, [
    'reviewTokenHash', 'reviewTokenExpiresAt', 'reviewNotificationAt',
    'reviewNotificationRevision', 'reviewNotifiedAt',
    ...(status === 'approved' ? ['replyMessage'] : []),
  ], doc.updateTime);
}

function historyWrite_(doc, status, replyMessage, now) {
  const request = decodeDocument_(doc);
  const revision = String(request.createdAt || request.updatedAt || '');
  const decisionId = revision.replace(/[^0-9]/g, '');
  if (!validUid_(request.requesterUid) || !decisionId) {
    throw new Error('Solicitud sin identificador de historial.');
  }
  const fields = {
    requesterUid: stringValue_(request.requesterUid),
    requesterName: stringValue_(String(request.requesterName || '')),
    requesterEmail: stringValue_(String(request.requesterEmail || '')),
    sponsorUid: stringValue_(String(request.sponsorUid || '')),
    message: stringValue_(String(request.message || '')),
    status: stringValue_(status),
    createdAt: timestampValue_(revision),
    decidedAt: timestampValue_(now),
  };
  if (status === 'denied') fields.replyMessage = stringValue_(replyMessage);
  return {
    update: {
      name: documentName_(`meta/admin/unlink_history/${request.requesterUid}` +
        `/decisions/${decisionId}`),
      fields,
    },
    currentDocument: { exists: false },
  };
}

function loadReview_(input) {
  if (!validReviewInput_(input)) return null;
  const doc = getDocument_(`meta/admin/unlink_requests/${input.requestId}`);
  if (!readyReview_(doc, input.token)) return null;
  const data = decodeDocument_(doc);
  return {
    requesterName: String(data.requesterName || 'Usuario Detox'),
    requesterEmail: String(data.requesterEmail || ''),
    message: String(data.message || ''),
  };
}

function readyReview_(doc, token) {
  if (!doc) return false;
  const data = decodeDocument_(doc);
  return data.status === 'pending' &&
    constantTimeEqual_(hashToken_(token), data.reviewTokenHash || '') &&
    Date.parse(data.reviewTokenExpiresAt || '') > Date.now();
}

function validReviewInput_(input) {
  return validRequestId_(input.requestId) &&
    typeof input.token === 'string' && /^[a-f0-9]{64}$/.test(input.token) &&
    (input.action === 'approve' || input.action === 'deny');
}

function validUid_(uid) {
  return typeof uid === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(uid);
}

function validRequestId_(requestId) {
  return typeof requestId === 'string' &&
    /^[A-Za-z0-9_-]{1,128}_admin_unlink$/.test(requestId);
}

function actionUrl_(base, requestId, token, action) {
  return `${base}?requestId=${encodeURIComponent(requestId)}` +
    `&token=${encodeURIComponent(token)}&action=${encodeURIComponent(action)}`;
}

function hashToken_(token) {
  return Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, token)
    .map(byte => (byte & 255).toString(16).padStart(2, '0')).join('');
}

function constantTimeEqual_(left, right) {
  if (typeof right !== 'string' || left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index++) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return difference === 0;
}

function escapeHtml_(value) {
  return String(value == null ? '' : value).replace(/[&<>"']/g, character => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[character]);
}

function page_(title, body, input) {
  let form = '';
  if (input) {
    const label = input.action === 'approve' ? 'aceptación' : 'denegación';
    const reasonField = input.action === 'deny'
      ? '<label for="replyMessage">Motivo de la denegación</label>' +
        '<textarea id="replyMessage" name="replyMessage" required ' +
        'maxlength="1000" rows="5"></textarea>'
      : '';
    form = `<form method="post" action="${escapeHtml_(WEB_APP_URL)}" target="_top">` +
      `<input type="hidden" name="requestId" value="${escapeHtml_(input.requestId)}">` +
      `<input type="hidden" name="token" value="${escapeHtml_(input.token)}">` +
      `<input type="hidden" name="action" value="${escapeHtml_(input.action)}">` +
      reasonField +
      `<button type="submit">Confirmar ${label}</button></form>`;
  }
  const html = `<!doctype html><html lang="es"><head><meta charset="utf-8">` +
    `<meta name="viewport" content="width=device-width,initial-scale=1">` +
    `<meta name="referrer" content="no-referrer"><title>${escapeHtml_(title)} · Detox</title>` +
    `<style>body{font:16px system-ui,sans-serif;background:#10131c;color:#f4f5f8;` +
    `margin:0;padding:2rem}main{max-width:36rem;margin:4rem auto;padding:2rem;` +
    `border:1px solid #394052;border-radius:1rem}h1{font-size:1.5rem}` +
    `p{line-height:1.5;overflow-wrap:anywhere}label{display:block;margin:1rem 0 .5rem}` +
    `textarea{box-sizing:border-box;width:100%;padding:.75rem;margin-bottom:1rem;` +
    `border:1px solid #677187;border-radius:.5rem;background:#1c2230;` +
    `color:#f4f5f8;font:inherit;resize:vertical}button{background:#9ae6b4;` +
    `color:#10131c;border:0;border-radius:.6rem;padding:.8rem 1.1rem;` +
    `font:inherit;font-weight:700;cursor:pointer}</style></head><body>` +
    `<main><h1>${escapeHtml_(title)}</h1>${body}${form}</main></body></html>`;
  return HtmlService.createHtmlOutput(html).setTitle(`${title} · Detox`);
}

function pendingRequests_() {
  const response = firestore_('post',
    `${DOCUMENTS}/meta/admin:runQuery`, {
      structuredQuery: {
        from: [{ collectionId: 'unlink_requests' }],
        where: { fieldFilter: {
          field: { fieldPath: 'status' }, op: 'EQUAL',
          value: { stringValue: 'pending' },
        } },
      },
    });
  return response.filter(item => item.document).map(item => item.document);
}

function getDocument_(path) {
  const url = `${FIRESTORE_API}${documentName_(path)}`;
  return firestore_('get', url, null, true);
}

function documentName_(path) {
  return `${DOCUMENTS}/${path}`;
}

function decodeDocument_(doc) {
  const result = {};
  for (const [key, value] of Object.entries(doc.fields || {})) {
    if ('stringValue' in value) result[key] = value.stringValue;
    else if ('timestampValue' in value) result[key] = value.timestampValue;
    else if ('integerValue' in value) result[key] = Number(value.integerValue);
  }
  return result;
}

function stringValue_(value) { return { stringValue: value }; }
function timestampValue_(value) { return { timestampValue: value }; }

function updateWrite_(name, fields, deletedFields, updateTime) {
  const fieldPaths = [...Object.keys(fields), ...deletedFields];
  return {
    update: { name, fields },
    updateMask: { fieldPaths },
    currentDocument: { updateTime },
  };
}

function commit_(writes) {
  return firestore_('post', `${DATABASE}/documents:commit`, { writes });
}

function firestore_(method, endpoint, body, allowMissing) {
  const options = {
    method,
    headers: { Authorization: `Bearer ${ScriptApp.getOAuthToken()}` },
    muteHttpExceptions: true,
  };
  if (body != null) {
    options.contentType = 'application/json';
    options.payload = JSON.stringify(body);
  }
  const response = UrlFetchApp.fetch(endpoint.startsWith('https:')
    ? endpoint : `${FIRESTORE_API}${endpoint}`, options);
  const code = response.getResponseCode();
  if (allowMissing && code === 404) return null;
  const content = response.getContentText();
  if (code < 200 || code >= 300) {
    throw new Error(`Firestore HTTP ${code}: ${content.slice(0, 500)}`);
  }
  return content ? JSON.parse(content) : {};
}
