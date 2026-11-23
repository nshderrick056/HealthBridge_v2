# Files to bring into `main`, by person

These are the files that exist on the local `derrick` branch of the HealthBridge repo but are missing from, or different on, GitHub `main`. Each person adds their own files on their own branch and opens a pull request that someone else reviews.

Total: 118 files. NEW means not on `main` yet; CHG means the file on `main` is an older version.

## Person 1: Sign-in, accounts and the server core (26 files)

- CHG  `.gitignore`
- CHG  `analysis_options.yaml`
- CHG  `lib/core/auth/auth_service.dart`
- CHG  `lib/core/settings/settings.dart`
- CHG  `lib/presentation/auth/change_secret_controller.dart`
- CHG  `lib/presentation/auth/change_secret_screen.dart`
- CHG  `lib/presentation/auth/forgot_controller.dart`
- CHG  `lib/presentation/auth/forgot_screen.dart`
- CHG  `lib/presentation/auth/login_controller.dart`
- CHG  `lib/presentation/auth/login_screen.dart`
- CHG  `lib/presentation/profile/profile_screen.dart`
- CHG  `lib/presentation/settings/settings_screen.dart`
- CHG  `pubspec.lock`
- CHG  `pubspec.yaml`
- NEW  `server/api/index.ts`
- NEW  `server/src/accounts.ts`
- NEW  `server/src/app.ts`
- NEW  `server/src/auth/routes.ts`
- NEW  `server/src/env.ts`
- NEW  `server/src/firebase.ts`
- NEW  `server/src/http.ts`
- NEW  `server/src/index.ts`
- NEW  `server/src/middleware/auth.ts`
- NEW  `server/test/auth.test.ts`
- NEW  `server/test/emulator.ts`
- NEW  `test/presentation/controllers_test.dart`

Git steps (replace the branch name with yours):
```powershell
git switch -c person1-add-files origin/main
# copy these files from the complete project, then:
git add <the files above>
git commit -m "feat: add <short description of the group above>"
git push -u origin person1-add-files
```

## Person 2: Database, Firebase configuration, project setup and docs (25 files)

- NEW  `.firebaserc`
- NEW  `.github/workflows/ci.yml`
- NEW  `.github/workflows/release.yml`
- NEW  `PRODUCT.md`
- CHG  `README.md`
- NEW  `dashboard/.env.example`
- NEW  `dashboard/next.config.ts`
- NEW  `dashboard/package-lock.json`
- NEW  `dashboard/package.json`
- NEW  `dashboard/postcss.config.mjs`
- NEW  `dashboard/tsconfig.json`
- NEW  `dashboard/vitest.config.ts`
- NEW  `dashboard/vitest.setup.ts`
- CHG  `docs/ERD.md`
- NEW  `firebase.json`
- CHG  `firestore.indexes.json`
- CHG  `lib/data/README.md`
- CHG  `lib/data/db.g.dart`
- NEW  `server/.env.example`
- NEW  `server/.gitignore`
- NEW  `server/package-lock.json`
- NEW  `server/package.json`
- NEW  `server/tsconfig.json`
- NEW  `server/vercel.json`
- NEW  `server/vitest.config.ts`

Git steps (replace the branch name with yours):
```powershell
git switch -c person2-add-files origin/main
# copy these files from the complete project, then:
git add <the files above>
git commit -m "feat: add <short description of the group above>"
git push -u origin person2-add-files
```

## Person 3: Urgent alerts, SMS, sync and Android (29 files)

- CHG  `android/app/build.gradle.kts`
- NEW  `android/app/google-services.json`
- NEW  `android/app/src/main/kotlin/rw/healthbridge/health_bridge/MainActivity.kt`
- NEW  `android/app/src/managed/AndroidManifest.xml`
- NEW  `android/app/src/managed/kotlin/rw/healthbridge/health_bridge/SmsChannel.kt`
- NEW  `android/app/src/store/kotlin/rw/healthbridge/health_bridge/FlavorChannels.kt`
- CHG  `android/gradle.properties`
- CHG  `android/settings.gradle.kts`
- CHG  `lib/core/sms/codec.dart`
- CHG  `lib/data/repositories/urgent_repository.dart`
- CHG  `lib/presentation/record/sms_alert_sent_screen.dart`
- CHG  `lib/sync/background_sync.dart`
- CHG  `lib/sync/firestore_mapping.dart`
- CHG  `lib/sync/sync_engine.dart`
- CHG  `lib/sync/sync_service.dart`
- CHG  `lib/urgent/urgent_dispatcher.dart`
- CHG  `lib/urgent/urgent_sender.dart`
- CHG  `lib/urgent/urgent_service.dart`
- CHG  `server/src/devices/routes.ts`
- CHG  `server/src/sms/codec.ts`
- CHG  `server/src/sms/keystore.ts`
- CHG  `server/src/sms/webhook.ts`
- CHG  `server/src/visits/merge.ts`
- CHG  `server/test/sms-codec.test.ts`
- CHG  `server/test/sms.test.ts`
- CHG  `test/core/sms/codec_test.dart`
- CHG  `test/sync/sync_engine_test.dart`
- CHG  `test/urgent/urgent_dispatcher_test.dart`
- CHG  `test/urgent/urgent_sender_test.dart`

Git steps (replace the branch name with yours):
```powershell
git switch -c person3-add-files origin/main
# copy these files from the complete project, then:
git add <the files above>
git commit -m "feat: add <short description of the group above>"
git push -u origin person3-add-files
```

## Person 4: Web dashboard frame, supervisor tests and history (20 files)

- NEW  `dashboard/app/(dashboard)/layout.tsx`
- NEW  `dashboard/app/api/[...path]/route.ts`
- NEW  `dashboard/app/api/auth/login/route.ts`
- NEW  `dashboard/app/api/auth/logout/route.ts`
- NEW  `dashboard/app/globals.css`
- NEW  `dashboard/app/layout.tsx`
- NEW  `dashboard/app/login/care-team.webp`
- NEW  `dashboard/app/login/page.tsx`
- NEW  `dashboard/app/page.tsx`
- NEW  `dashboard/components/LoginForm.tsx`
- NEW  `dashboard/components/NavLinks.tsx`
- NEW  `dashboard/components/Shell.tsx`
- NEW  `dashboard/components/icons.tsx`
- NEW  `dashboard/lib/client.ts`
- NEW  `dashboard/lib/proxy.ts`
- NEW  `dashboard/lib/session.ts`
- NEW  `dashboard/lib/types.ts`
- NEW  `dashboard/proxy.ts`
- NEW  `test/domain/history_test.dart`
- CHG  `test/presentation/role_screens_test.dart`

Git steps (replace the branch name with yours):
```powershell
git switch -c person4-add-files origin/main
# copy these files from the complete project, then:
git add <the files above>
git commit -m "feat: add <short description of the group above>"
git push -u origin person4-add-files
```

## Person 5: Design system, admin and fonts (18 files)

- CHG  `assets/fonts/Outfit-Bold.ttf`
- NEW  `assets/fonts/Outfit-LICENSE.txt`
- CHG  `assets/fonts/Outfit-Medium.ttf`
- CHG  `assets/fonts/Outfit-Regular.ttf`
- CHG  `assets/fonts/Outfit-SemiBold.ttf`
- NEW  `dashboard/app/fonts/Outfit-Bold.ttf`
- NEW  `dashboard/app/fonts/Outfit-LICENSE.txt`
- NEW  `dashboard/app/fonts/Outfit-Medium.ttf`
- NEW  `dashboard/app/fonts/Outfit-Regular.ttf`
- NEW  `dashboard/app/fonts/Outfit-SemiBold.ttf`
- CHG  `lib/core/api/api_client.dart`
- CHG  `lib/core/theme/app_theme.dart`
- CHG  `lib/core/widgets/widgets.dart`
- CHG  `lib/presentation/admin/admin_screens.dart`
- CHG  `lib/presentation/shell/app_shell.dart`
- CHG  `lib/presentation/shell/role_shells.dart`
- CHG  `server/src/admin/routes.ts`
- NEW  `server/test/admin.test.ts`

Git steps (replace the branch name with yours):
```powershell
git switch -c person5-add-files origin/main
# copy these files from the complete project, then:
git add <the files above>
git commit -m "feat: add <short description of the group above>"
git push -u origin person5-add-files
```

## Do not add
- `.claude/launch.json`, the generated `linux/`, `macos/` and `windows/` plugin files, and anything under `docs/report/` or the `docs/*SCRIPT*` files.
- Any `.env`, service-account key, `android/key.properties` or `.jks` file.

## Remove from `main`
- `analysis_after_db.txt`, `analysis_after_replacement.txt`, `analysis_step4.txt` (leftover output).
