# Person 1: the script, snippet by snippet (5:00 to 7:00)

Topic: authentication, SharedPreferences, and why we chose Riverpod. About 2 minutes, roughly 260 spoken words. The team script and the on-camera app steps for sign-in are in [VIDEO_SCRIPTS.md](VIDEO_SCRIPTS.md). Line numbers below were read at commit `fa712c6`.

**Assignment question you answer:** why this state management is appropriate.

## Order and timing

| Time | Show | Say (the short version) |
|---|---|---|
| 5:00 | spoken only | why Riverpod |
| 5:15 | `lib/presentation/auth/login_controller.dart`, lines 43-57 | one controller, three methods |
| 5:40 | same file, lines 125-127 | validation |
| 5:55 | `server/src/auth/routes.ts`, lines 51-65 | lockout and the custom token |
| 6:35 | `lib/core/settings/settings.dart`, lines 49-63 and 77-80 | SharedPreferences |

## 0. Why Riverpod (15 seconds)

**Say:** "I did authentication and local preferences. We chose Riverpod because state is compile-checked, can be tested without a `BuildContext`, and rebuilds only the widgets that watch it. We use no `setState` anywhere."

## 1. One controller, three sign-in methods: `login_controller.dart` lines 43-57 (25 seconds)

```dart
class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  AuthService get _auth => ref.read(authServiceProvider);

  void choose(LoginMethod method) => state = LoginState(method: method);

  /// Phone + PIN, or email + password.
  Future<void> submit(String id, String secret) => _run(
    id,
    () => state.method == LoginMethod.email
        ? _auth.signInWithEmail(id.trim(), secret)
        : _auth.signInWithPin(normalizePhone(id), secret),
  );
```

**Say:** "Sign-in is one `Notifier`, `LoginController`. Its state holds the chosen method, whether it is busy, and any error. `submit` runs the email path or the PIN path. The screen only calls this; it holds no sign-in logic. On success the session provider is set, and the root widget swaps the sign-in screen for the app."

**Brief notes:** `build()` gives the starting state. `ref.read` fetches the auth service (it is not watched, because we only call it). `choose` replaces the state with a new method, which also clears any old error.

## 2. Validation: `login_controller.dart` lines 125-127 (15 seconds)

```dart
String? validatePin(String? v) =>
    requiredField(v) ??
    (RegExp(r'^\d{4,6}$').hasMatch(v!.trim()) ? null : 'PIN is 4 to 6 digits');
```

**Say:** "Validators are plain functions. `validatePin` returns null when the input is fine, or a short polite message when it is not, 'PIN is 4 to 6 digits'. The form calls it, so nothing is sent to the server until the input is valid."

**Brief notes:** `??` chains: if the field is empty it returns 'Required', otherwise it checks the pattern. The same style is used for phone, email and password.

## 3. The server: `server/src/auth/routes.ts` lines 51-65 (40 seconds)

```ts
    if (cred.lockedUntil && (cred.lockedUntil as Timestamp).toMillis() > Date.now()) {
      throw new HttpError(429, 'too_many_attempts');
    }
    if (!(await verify(cred.pinHash, given))) {
      const locks = (cred.failedLogins ?? 0) + 1 >= MAX_FAILED_LOGINS;
      await credRef.update(
        locks
          ? { failedLogins: 0, lockedUntil: Timestamp.fromMillis(Date.now() + LOCK_MS) }
          : { failedLogins: FieldValue.increment(1) },
      );
      throw unauthorized();
    }
    if (cred.failedLogins || cred.lockedUntil) await credRef.update({ failedLogins: 0, lockedUntil: null });
    const claims = { role: user.role, hc: user.healthCenterId };
    res.json({ customToken: await fb.auth.createCustomToken(user.id, claims) });
```

**Say:** "The PIN is checked on our server, never in the app. The PIN is stored only as an Argon2 hash, in a collection that clients cannot read. If the account is locked, the server answers 429. A wrong PIN counts a failure, and the fifth one locks the account for 15 minutes. A right PIN clears the counters and the server returns a Firebase custom token carrying custom claims: the role and the health centre. The security rules and the dashboards read those claims. Forgotten PINs use a one-time code, valid for 30 minutes with five tries."

**Brief notes:** `MAX_FAILED_LOGINS` is 5 (line 19). A wrong PIN and an unknown phone number both return the same `unauthorized()`, so an attacker cannot tell which numbers exist.

## 4. SharedPreferences: `settings.dart` lines 49-63 and 77-80 (35 seconds)

```dart
  @override
  AppSettings build() {
    final p = ref.watch(sharedPreferencesProvider);
    final remember = p.getBool(_remember) ?? false;
    return AppSettings(
      textSize:
          TextSize.values.asNameMap()[p.getString(_textSize)] ??
          TextSize.normal,
      defaultVisitType:
          VisitType.values.asNameMap()[p.getString(_visitType)] ??
          VisitType.maternal,
      rememberLogin: remember,
      savedLoginId: remember ? p.getString(_loginId) : null,
    );
  }

  Future<void> setTextSize(TextSize size) async {
    state = _with(textSize: size);
    await _prefs.setString(_textSize, size.name);
  }
```

**Say:** "Three preferences are saved: text size, default visit type, and remember login with the saved phone number. When the app starts, `build()` reads them back, with a safe default if one is missing. That is why they survived the restart you saw. When the user changes a setting, `setTextSize` first updates the state, so the screen changes at once, then writes it to SharedPreferences. Turning remember login off also deletes the saved number."

**Brief notes:** preferences are stored by enum name (a string), so a renamed value falls back to the default instead of crashing. The PIN is never saved.

## Hand-off

"[Name] shows the data side with the Firebase Console." (A one-sentence hand-off, then stop.)

## If you run long

Drop the Forgot-PIN sentence, then the validator section.
