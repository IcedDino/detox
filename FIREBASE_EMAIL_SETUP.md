# Firebase email unlink setup

This app writes unlink-code emails to the `mail` collection.

To send real emails automatically, install the Firebase Extension **Trigger Email** in your Firebase project and point it to an SMTP provider.

## Collection used
- `mail`

## Suggested setup
1. In Firebase Console, open **Extensions**.
2. Install **Trigger Email**.
3. Use `mail` as the collection name.
4. Configure your SMTP provider.
5. Deploy and test an unlink email from the Sponsor Center.

Without the extension, the app will still create the unlink code and write the email document, but no external email will actually be delivered.
