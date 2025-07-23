# Release Permission Configuration

**Language / 语言:** [🇺🇸 English](#english) | [🇨🇳 中文](google_play_console_permission_ZH.md)

---

## API Access Setup Process

### Enable API in Google Cloud Console
You now need to log directly into Google Cloud Console, select or create a project, then search for and enable the Google Play Developer API in the library. API management has been unified to the Cloud platform.

### Create Service Account in Google Cloud Console
In the same Google Cloud project where you enabled the API, you can go to the "Credentials" page to create a Service Account and generate a JSON key file for authentication.

### Authorize Service Account in Play Console
This is the most critical change. You need to copy the email address of the newly created service account, then return to Google Play Console and go to the "Users and permissions" page:

Like inviting a new user, invite this service account.

In the permission settings, grant the service account necessary permissions, such as Administrator (all permissions), to ensure it has sufficient permissions to upload and manage applications.