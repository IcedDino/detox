Use permissive development rules or extend your Firestore rules before testing sponsor features.

Example development rules:

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null;
    }

    match /meta/sponsor/unlock_requests/{requestId} {
      allow read, write: if request.auth != null;
    }
  }
}

Once the feature is stable, tighten these rules so users can only read and write the exact sponsor docs they need.
