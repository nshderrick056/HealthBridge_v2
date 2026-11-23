# Person 5: the script, snippet by snippet (13:00 to 14:45)

Topic: design system, layout tests, admin deactivate, quality and GitHub history. About 1 minute 45 seconds, roughly 250 spoken words. The full team script and the line numbers are in [VIDEO_SCRIPTS.md](VIDEO_SCRIPTS.md) (Person 5). Line numbers below were read at commit `fa712c6`.

**Assignment questions you answer:** how testing validates the app; how GitHub history shows collaboration.

## Order and timing

| Time | Show | Say (the short version) |
|---|---|---|
| 13:00 | `lib/core/widgets/widgets.dart`, lines 100-122 | the button |
| 13:20 | `lib/core/theme/app_theme.dart`, lines 17-26 | the contrast |
| 13:40 | `test/layout_test.dart`, lines 24-31 | the four sizes |
| 14:05 | `server/src/admin/routes.ts`, lines 120-128 | deactivate |
| 14:20 | terminal | analyze, tests, coverage, git history |

## 1. The button: `widgets.dart` lines 100-122 (20 seconds)

```dart
    final (bg, fg) = switch (_kind) {
      _ButtonKind.primary => (HbColors.ink, Colors.white),
      _ButtonKind.secondary => (HbColors.white, HbColors.ink),
      _ButtonKind.danger => (HbColors.red, Colors.white),
      _ButtonKind.light => (HbColors.white, HbColors.ink),
    };
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: SizedBox(
        width: double.infinity,
        height: 56,
```

**Say:** "Every screen uses one button, `HbButton`. A `switch` picks its colours for four kinds: primary, secondary, danger and light. It is always 56 pixels high, well above the Material minimum of 48, and when `onPressed` is null it fades to half opacity, so a disabled button looks disabled. One widget means one place to fix anything."

**Brief notes:** `switch` returns a pair `(background, foreground)`. `enabled` is just "has a callback". `SizedBox(height: 56)` is the tap-target size.

## 2. The colours: `app_theme.dart` lines 17-26 (20 seconds)

```dart
  /// Input and checkbox edges: 3.3:1 on the canvas, the minimum for a control's boundary.
  static const edge = Color(0xFF7E8A85);
  ...
  /// Secondary text on brand green (4.9:1).
  static const onBrand = Color(0xFFD7EAE3);
  static const red = Color(0xFFB3261E);

  /// Secondary text on the red (5:1).
  static const onRed = Color(0xFFFFE3E0);
```

**Say:** "Colours are named tokens in `HbColors`, not hex codes scattered around. The comments record the measured contrast: secondary text on brand green is 4.9 to 1, on red 5 to 1. The requirement is 4.5, so both pass. Control edges are 3.3 to 1, the minimum for a boundary."

**Brief notes:** `static const` means one shared value. The ratio in each comment is why that exact shade was chosen.

## 3. The layout test: `layout_test.dart` lines 24-31 (25 seconds)

```dart
const _sizes = {
  'small phone (320x568)': (Size(320, 568), 0.55),
  'large phone (430x932)': (Size(430, 932), 0.55),
  'landscape (844x390)': (Size(844, 390), 0.55),
  'landscape, extra large text': (Size(844, 390), 0.72),
};
```

**Say:** "This is how we prove the layout works. A widget test renders every main screen at four sizes: a small phone, a large phone, landscape, and landscape with the largest text setting. If any screen overflows even by a pixel, Flutter raises a `RenderFlex` error and the test fails. So small and large screens, and rotation, are checked every time we run the tests, not by eye."

**Brief notes:** each entry is a name, a screen size, and a text scale. The scale (0.55) compensates for the wide font used in tests, as the comment above the map explains.

## 4. Deactivate: `server/src/admin/routes.ts` lines 120-128 (15 seconds)

```ts
  router.patch('/users/:id', async (req, res) => {
    const { active } = z.object({ active: z.boolean() }).parse(req.body);
    const { ref } = await member(req.params.id);
    await ref.update({ active });
    await fb.auth.updateUser(ref.id, { disabled: !active });
    if (!active) await fb.auth.revokeRefreshTokens(ref.id);
```

**Say:** "On the admin side, deactivating a member does three things: it sets `active` to false in Firestore, disables the account in Firebase Authentication, and revokes their refresh tokens, so they are locked out immediately, not at their next sign-in. The input is validated with zod, and the whole router is limited to the admin role."

**Brief notes:** `z.object(...).parse` rejects a bad body before anything runs. `requireRole('admin')` is on line 25.

## 5. Quality and history: terminal (25 seconds)

Run these on camera and read the real results aloud:

```powershell
flutter analyze
flutter test --coverage
git shortlog -sn
```

**Say:** "`flutter analyze` reports [say the real result]. `flutter test` ran [real number] tests, with [real number] percent coverage; the server has its own tests on the Firebase emulators and the dashboard has its own. And `git shortlog` shows each member's commits across our branches, which matches the contribution tracker. Thank you for watching."

**Do not guess the numbers.** The earlier drafts said "129 tests" and "above 70 percent"; the 129 came from an earlier run, and coverage has not been measured. Run the commands the day before and use what they print.

## If you run long

Drop section 4, then shorten section 2 to one sentence.
