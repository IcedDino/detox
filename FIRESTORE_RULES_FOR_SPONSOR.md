# Firestore rules for sponsor requests

The app's Firestore rules are maintained in [`firestore.rules`](firestore.rules). The current support unlink request is written to `meta/admin/unlink_requests/{uid}_admin_unlink`. An authenticated requester can create a request or submit a new one after the previous request was decided; a pending request cannot be overwritten. The support mailbox receives an email with decision links through Google Apps Script. Decided requests are archived in `meta/admin/unlink_history/{uid}/decisions`, which only that user can read from the app.

Changes to `firestore.rules` do not take effect in the app until they are deployed to the Firebase project. After signing in with an account that can deploy rules, run:

```powershell
npx firebase-tools login
npx firebase-tools deploy --only firestore:rules --project detox-c0790
```

Then retry **Solicitar desvinculación a soporte** while signed in to the app. A successful request creates or updates the document under `meta/admin/unlink_requests`. If Firebase still returns `permission-denied`, confirm that the app is connected to `detox-c0790` and that the published Firestore rules include this collection path.
