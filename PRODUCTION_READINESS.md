
# SNOOP — Production readiness notes

This package contains implementation work, but **must not be treated as a verified production release** until the device/build/backend checks below pass.

## Implemented in this revision
- Local daily reminder notifications using `flutter_local_notifications`, scheduled as inexact alarms, recurring daily and reconciled on app startup.
- Android notification permission request, notification channel and reboot/time/timezone/package-replaced receivers.
- Persistent profile settings and an editable profile dialog.
- Theme selection persisted locally; dark mode uses Material dark color scheme, but custom palette/components still need a full contrast/accessibility audit before release.
- Supabase client bootstrap via build-time `--dart-define` values (no secrets embedded).
- Supabase metadata upsert adapter and persistent idempotent retry queue for attendance/memory metadata.
- UUID IDs for newly created attendance and memory records to match the SQL schema.
- Backend remains optional; app should remain locally usable if it is unconfigured/offline.

## Configure
```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_OR_PUBLISHABLE_KEY
```
Only the public anon/publishable key belongs in the client. Never place `service_role`, Google client secrets, refresh tokens, or private keys in Flutter code or `--dart-define`.

Run `bash setup.sh` first if Android platform files have not been generated. The generated `android/app/src/main/AndroidManifest.xml` is overwritten by `android_overrides/AndroidManifest.xml`.

## Important limits / still required before release
1. **Supabase authentication UI and account lifecycle** (sign-in/sign-up/password reset/session-expiry UI) is not wired into the screens. Backend sync only operates for an authenticated Supabase session; otherwise records remain queued locally.
2. **Google Drive upload is not implemented.** `documentations` metadata sync is not a photo upload. Implement a Supabase Edge Function using Google OAuth/service-account credentials stored as server secrets, validate the caller's JWT and ownership, enforce MIME/size limits, and return the Drive file ID/URL. Do not put Drive credentials in the app.
3. Offline retry queue uses SharedPreferences JSON as a transitional low-volume queue. For production use SQLite/Drift, transactional writes, migration/versioning, background retry with connectivity/work manager, and queue observability.
4. Local notification delivery varies by Android version and OEM battery policy. Android 13+ permission must be granted. Inexact alarms may be delayed. Test force-stop, reboot, timezone changes, app update, denied permission, and battery saver. Exact-alarm permission is intentionally not requested.
5. Profile values are local-only and are not currently upserted to `profiles`. Schedule and reminder remote sync is not wired. Schedule is still a repeating local template, not a date-specific calendar.
6. Check-in coordinates are captured in the camera flow, but the attendance record schema adapter currently syncs only timestamps/status; coordinates are associated with the documentation row. Validate the desired privacy/retention policy before release.
7. App drawer now has heuristic categories based on package/label; OEM-specific packages may be classified as “Lainnya”. Native launcher behavior and app visibility must be tested on physical Android devices and current target SDK.
8. Delete-memory currently removes metadata from local storage; ensure the corresponding photo file and remote Drive object are deleted once uploads are implemented.
9. Add tests (timezone boundaries, late tolerance boundary, duplicate attendance, checkout state, queue retries, RLS isolation, notification scheduling), crash reporting, privacy policy, data export/deletion, app signing, CI build, accessibility checks, and Play Console Data safety declaration.

## Release verification checklist
- `flutter analyze` has zero errors and reviewed warnings.
- `flutter test` passes; add unit/widget/integration coverage for business rules.
- Build and test release APK/AAB on Android 13, 14 and 15 devices.
- Run SQL in a staging Supabase project and test RLS using two different accounts.
- Test no-network, expired session, permission denied, storage full, camera cancellation, and repeated taps.
- Confirm attendance business rules with the internship/workplace owner and timezone.
- Review privacy, consent for camera/location, retention, and Google Drive sharing permissions.
