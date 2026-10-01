"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const source = fs.readFileSync(path.join(__dirname, "..", "apps_script", "Code.gs"), "utf8");
const prefix = "projects/detox-c0790/databases/(default)/documents/";

test('Sponsor push routes a new link to the target and its answer to the requester', () => {
  const { context } = harness({});
  const request = {
    requesterUid: 'requester', targetUid: 'target', requesterName: 'Ana',
    targetName: 'Luis', status: 'pending',
  };
  const incoming = context.sponsorPushEvent_('link', request);
  assert.equal(incoming.uid, 'target');
  assert.equal(incoming.kind, 'link_pending');
  const accepted = context.sponsorPushEvent_('link', { ...request, status: 'accepted' });
  assert.equal(accepted.uid, 'requester');
  assert.equal(accepted.kind, 'link_accepted');
});

test('Sponsor push routes an unlock decision back to its requester', () => {
  const { context } = harness({});
  const request = {
    requesterUid: 'requester', sponsorUid: 'sponsor', requesterName: 'Ana',
    requestType: 'shield_pause', status: 'approved',
  };
  const event = context.sponsorPushEvent_('unlock', request);
  assert.equal(event.uid, 'requester');
  assert.equal(event.kind, 'unlock_approved');
  assert.equal(context.sponsorPushEvent_('unlock', { ...request, status: 'consumed' }), null);
});

test('Sponsor push sends a closed-app notification once per request revision', () => {
  const now = new Date().toISOString();
  const h = harness({
    'meta/sponsor/link_requests/requester_target_sponsor': {
      requesterUid: { stringValue: 'requester' },
      targetUid: { stringValue: 'target' },
      requesterName: { stringValue: 'Ana' },
      status: { stringValue: 'pending' },
      updatedAt: { timestampValue: now },
    },
    'users/target/push_tokens/device': {
      token: { stringValue: 'device-token' },
      locale: { stringValue: 'es' },
      foreground: { booleanValue: false },
      updatedAt: { timestampValue: now },
    },
  });
  h.context.processSponsorPush_();
  h.context.processSponsorPush_();
  assert.equal(h.pushes.length, 1);
  assert.equal(h.pushes[0].message.token, 'device-token');
  assert.equal(h.pushes[0].message.data.kind, 'link_pending');
});

function harness(initial, authUsers = {}) {
  const documents = new Map();
  let version = 0;
  for (const [key, fields] of Object.entries(initial)) {
    documents.set(prefix + key, {
      name: prefix + key,
      fields: structuredClone(fields),
      updateTime: new Date(2026, 0, 1, 0, 0, ++version).toISOString(),
    });
  }
  const sent = [];
  const pushes = [];
  const response = (code, body) => ({
    getResponseCode: () => code,
    getContentText: () => JSON.stringify(body),
  });
  const fetch = (url, options) => {
    if (url.includes('fcm.googleapis.com')) {
      pushes.push(JSON.parse(options.payload));
      return response(200, { name: 'sent' });
    }
    if (url.includes('identitytoolkit.googleapis.com')) {
      const uid = JSON.parse(options.payload).localId[0];
      return response(200, { users: [authUsers[uid] || { localId: uid }] });
    }
    const name = url.replace("https://firestore.googleapis.com/v1/", "");
    if (options.method === "get") {
      if (name.includes('/push_tokens?')) {
        const parent = name.split('?')[0] + '/';
        return response(200, { documents: [...documents.values()]
          .filter(doc => doc.name.startsWith(parent)) });
      }
      const doc = documents.get(name);
      return doc ? response(200, doc) : response(404, { error: "missing" });
    }
    const payload = JSON.parse(options.payload);
    if (name.endsWith(":runQuery")) {
      if (name.includes('/meta/sponsor:runQuery')) {
        const collection = payload.structuredQuery.from[0].collectionId;
        const cutoff = payload.structuredQuery.where.fieldFilter.value.timestampValue;
        return response(200, [...documents.values()].filter(doc =>
          doc.name.includes(`/meta/sponsor/${collection}/`) &&
          doc.fields.updatedAt?.timestampValue >= cutoff)
          .map(document => ({ document })));
      }
      if (payload.structuredQuery.from[0].collectionId === 'users') {
        const cutoff = payload.structuredQuery.where.fieldFilter.value.timestampValue;
        return response(200, [...documents.values()].filter(doc =>
          doc.fields.anonymousLastSeenAt?.timestampValue <= cutoff).map(document => ({ document })));
      }
      return response(200, [...documents.values()]
        .filter((doc) => doc.name.includes("/meta/admin/unlink_requests/") &&
          doc.fields.status?.stringValue === "pending")
        .map((document) => ({ document })));
    }
    assert.ok(name.endsWith(":commit"));
    for (const write of payload.writes) {
      if (!write.update) continue;
      const current = documents.get(write.update.name);
      if (write.currentDocument?.exists === false ? !!current :
        !current || current.updateTime !== write.currentDocument.updateTime) {
        return response(412, { error: { status: "FAILED_PRECONDITION" } });
      }
    }
    const writeResults = payload.writes.map((write) => {
      if (write.delete) {
        documents.delete(write.delete);
        return {};
      }
      const current = documents.get(write.update.name);
      const fields = write.updateMask
        ? { ...current.fields } : { ...write.update.fields };
      for (const field of write.updateMask?.fieldPaths || []) {
        if (field in write.update.fields) fields[field] = write.update.fields[field];
        else delete fields[field];
      }
      const updateTime = new Date(2026, 0, 1, 0, 0, ++version).toISOString();
      documents.set(write.update.name, {
        name: write.update.name, fields, updateTime,
      });
      return { updateTime };
    });
    return response(200, { writeResults });
  };
  let uuidNumber = 0;
  const context = vm.createContext({
    console,
    Date,
    LockService: { getScriptLock: () => ({
      tryLock: () => true, releaseLock: () => {},
    }) },
    ScriptApp: {
      getService: () => ({ getUrl: () => "https://script.google.com/macros/s/test/exec" }),
      getOAuthToken: () => "test-token",
    },
    Utilities: {
      DigestAlgorithm: { SHA_256: "SHA_256" },
      getUuid: () => `${String(++uuidNumber).padStart(8, "0")}-aaaa-bbbb-cccc-dddddddddddd`,
      computeDigest: (_algorithm, value) => [...crypto.createHash("sha256")
        .update(value).digest()],
    },
    MailApp: {
      getRemainingDailyQuota: () => 100,
      sendEmail: (...args) => sent.push(args),
    },
    UrlFetchApp: { fetch },
    HtmlService: { createHtmlOutput: (html) => ({
      html, setTitle(title) { this.title = title; return this; },
    }) },
  });
  vm.runInContext(source, context, { filename: "Code.gs" });
  return {
    context, documents, sent, pushes,
    doc: (key) => documents.get(prefix + key),
  };
}

test('Seven-day expiry removes both links only for inactive anonymous users', () => {
  const old = { timestampValue: new Date(Date.now() - 8 * 86400000).toISOString() };
  const recent = { timestampValue: new Date().toISOString() };
  const setup = {
    'users/anonymous': { sponsorUid: { stringValue: 'sponsor' }, anonymousLastSeenAt: old },
    'users/sponsor': { sponsorUid: { stringValue: 'anonymous' } },
    'users/recovered': { sponsorUid: { stringValue: 'other' }, anonymousLastSeenAt: old },
    'users/active': { sponsorUid: { stringValue: 'other' }, anonymousLastSeenAt: recent },
    'meta/sponsor/unlock_requests/anonymous_settings_unlock': { status: { stringValue: 'pending' } },
  };
  const h = harness(setup, { recovered: { email: 'linked@example.com' } });
  h.context.expireAnonymousSponsorLinks_();
  assert.equal(h.doc('users/anonymous').fields.sponsorUid, undefined);
  assert.equal(h.doc('users/sponsor').fields.sponsorUid, undefined);
  assert.equal(h.doc('users/recovered').fields.sponsorUid.stringValue, 'other');
  assert.equal(h.doc('users/active').fields.sponsorUid.stringValue, 'other');
  assert.equal(h.doc('meta/sponsor/unlock_requests/anonymous_settings_unlock'), undefined);
});

test('A concurrent foreground heartbeat prevents expiry of either side', () => {
  const h = harness({
    'users/anonymous': { sponsorUid: { stringValue: 'sponsor' } },
    'users/sponsor': { sponsorUid: { stringValue: 'anonymous' } },
  });
  const stale = structuredClone(h.doc('users/anonymous'));
  h.doc('users/anonymous').updateTime = new Date().toISOString();
  assert.throws(() => h.context.expireAnonymousSponsorLink_(stale));
  assert.equal(h.doc('users/anonymous').fields.sponsorUid.stringValue, 'sponsor');
  assert.equal(h.doc('users/sponsor').fields.sponsorUid.stringValue, 'anonymous');
});

function pending() {
  return {
    requesterUid: { stringValue: "requester" },
    requesterName: { stringValue: "<script>alert(1)</script>" },
    requesterEmail: { stringValue: "requester@example.com" },
    sponsorUid: { stringValue: "sponsor" },
    message: { stringValue: "Necesito salir" },
    status: { stringValue: "pending" },
    updatedAt: { timestampValue: "2026-09-25T18:00:00Z" },
  };
}

function getInput(h) {
  const url = h.sent[0][2].match(/Aceptar: (https:\/\/\S+)/)[1];
  return Object.fromEntries(new URL(url).searchParams.entries());
}

test("poll sends one escaped support email and GET only previews", () => {
  const h = harness({
    "meta/admin/unlink_requests/requester_admin_unlink": pending(),
    "users/requester": { sponsorUid: { stringValue: "sponsor" } },
    "users/sponsor": { sponsorUid: { stringValue: "requester" } },
  });
  h.context.processSupportUnlinkRequests_();
  h.context.processSupportUnlinkRequests_();
  assert.equal(h.sent.length, 1);
  assert.equal(h.sent[0][0], "nerqovaassist@gmail.com");
  assert.match(h.sent[0][3].htmlBody, /&lt;script&gt;/);
  const before = h.doc("users/requester").updateTime;
  const page = h.context.doGet({ parameter: getInput(h) });
  assert.match(page.html, /Confirmar aceptación/);
  assert.equal(h.doc("users/requester").updateTime, before);
});

test("approval unlinks both users atomically and cannot be replayed", () => {
  const h = harness({
    "meta/admin/unlink_requests/requester_admin_unlink": pending(),
    "users/requester": { sponsorUid: { stringValue: "sponsor" } },
    "users/sponsor": { sponsorUid: { stringValue: "requester" } },
    "meta/sponsor/link_requests/requester_sponsor_sponsor": {
      status: { stringValue: "accepted" },
    },
  });
  h.context.processSupportUnlinkRequests_();
  const input = getInput(h);
  assert.match(h.context.doPost({ parameter: input }).html, /cuentas quedaron desvinculadas/);
  assert.equal(h.doc("users/requester").fields.sponsorUid, undefined);
  assert.equal(h.doc("users/sponsor").fields.sponsorUid, undefined);
  assert.equal(h.doc("meta/sponsor/link_requests/requester_sponsor_sponsor"), undefined);
  assert.equal(h.doc("meta/admin/unlink_requests/requester_admin_unlink")
    .fields.status.stringValue, "approved");
  assert.equal(h.doc("meta/admin/unlink_history/requester/decisions/20260925180000")
    .fields.status.stringValue, "approved");
  assert.match(h.context.doPost({ parameter: input }).html, /No se realizó ningún cambio/);
});

test("denial leaves links; stale links and forged tokens do nothing", () => {
  const initial = {
    "meta/admin/unlink_requests/requester_admin_unlink": pending(),
    "users/requester": { sponsorUid: { stringValue: "sponsor" } },
    "users/sponsor": { sponsorUid: { stringValue: "requester" } },
  };
  const denied = harness(initial);
  denied.context.processSupportUnlinkRequests_();
  const deny = { ...getInput(denied), action: "deny" };
  assert.match(denied.context.doGet({ parameter: deny }).html, /textarea/);
  assert.match(denied.context.doPost({ parameter: deny }).html, /Escribe el motivo/);
  assert.equal(denied.doc("meta/admin/unlink_requests/requester_admin_unlink")
    .fields.status.stringValue, "pending");
  const reason = "No se comprobó la identidad.";
  assert.match(denied.context.doPost({ parameter: {
    ...deny, replyMessage: reason,
  } }).html, /solicitud quedó denegada/);
  assert.equal(denied.doc("users/requester").fields.sponsorUid.stringValue, "sponsor");
  assert.equal(denied.doc("meta/admin/unlink_requests/requester_admin_unlink")
    .fields.replyMessage.stringValue, reason);
  assert.equal(denied.doc("meta/admin/unlink_history/requester/decisions/20260925180000")
    .fields.replyMessage.stringValue, reason);

  const stale = harness(initial);
  stale.context.processSupportUnlinkRequests_();
  const input = getInput(stale);
  stale.doc("users/requester").fields.sponsorUid.stringValue = "someone-else";
  assert.match(stale.context.doPost({ parameter: input }).html, /vínculo actual ya no coincide/);
  assert.equal(stale.doc("users/requester").fields.sponsorUid.stringValue, "someone-else");
  assert.match(stale.context.doPost({ parameter: {
    ...input, token: "0".repeat(64),
  } }).html, /No se realizó ningún cambio/);
});
