# Free support unlink by email

The app writes a pending request to `meta/admin/unlink_requests/{uid}_admin_unlink`. The Google Apps Script in [`apps_script/Code.gs`](apps_script/Code.gs) checks for pending requests every five minutes and emails `nerqovaassist@gmail.com` from the Google account that owns the script. No Firebase extension, SMTP password, or Blaze plan is needed.

The email contains **Aceptar** and **Denegar** links. Opening a link shows a confirmation page; only the confirmation submits the decision. Denial requires a written reason of up to 1000 characters. A link expires after seven days and can be used once. Approval checks the current link, removes it from both user documents, clears pair requests and temporary overrides, then records `approved` in one atomic Firestore commit. Denial records `denied` and the reason without changing the link. Every decision is copied to `meta/admin/unlink_history/{uid}/decisions/{revision}`, which the requester can read in the app. If the linked sponsor changed, approval is rejected. A requester cannot send another support request while one is pending. After a decision, a new request can be sent and the prior decision remains in history.

## Publish the Apps Script

1. Sign in to [Google Apps Script](https://script.google.com/) with a Google account that has **Firestore write access** to Firebase project `detox-c0790`. This account will send the email to the support mailbox, so it does not need to be `nerqovaassist@gmail.com`. If deploying with `clasp`, turn on **Google Apps Script API** in [Apps Script settings](https://script.google.com/home/usersettings).
2. Open the existing [Detox Soporte Desvinculacion script](https://script.google.com/d/1o1WUWZylnx2WiJRkr75ZnoRygIvfUwGno5dgB5cJhtShboVHQHwGn6s0/edit), which was created and uploaded with `clasp`.
3. In the editor, deploy as a **Web app**. Set **Execute as: Me** and **Who has access: Anyone**. The page is accessible by a long, single-use link sent only to support. Opening it does not change data; confirmation does.
4. In the script editor, run `installPollingTrigger` once and grant the requested Google permissions. This creates one time trigger, even if run twice. It uses the published web app URL automatically.
5. Send a request from the app. Within five minutes, check the support inbox. For an existing pending request, submit it again to update its timestamp. Test accepting and denying with separate requests.

The script uses `ScriptApp.getOAuthToken()` to access Firestore through Google's REST API as the deploying account. Keep that account's Firestore access limited to trusted support operators. The web app does not contain an API key or service account key. Do not forward decision links: possession of a valid link is sufficient to approve or deny.

To publish Firestore rule changes separately:

```powershell
npx firebase-tools deploy --only firestore:rules --project detox-c0790
```

The `mail` collection is no longer part of this flow and its client writes are denied in `firestore.rules`.
