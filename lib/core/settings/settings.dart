import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models.dart';

/// Must be overridden at startup with `await SharedPreferences.getInstance()`, like databaseProvider.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('override sharedPreferencesProvider'),
);

/// App-wide text size, on top of the phone's own font size setting.
enum TextSize {
  normal(1.0, 'Normal'),
  large(1.15, 'Large'),
  extraLarge(1.3, 'Extra large');

  const TextSize(this.scale, this.label);
  final double scale;
  final String label;
}

class AppSettings {
  const AppSettings({
    this.textSize = TextSize.normal,
    this.defaultVisitType = VisitType.maternal,
    this.rememberLogin = false,
    this.savedLoginId,
  });

  final TextSize textSize;

  /// Pre-selected on a new visit; a saved draft keeps its own type.
  final VisitType defaultVisitType;

  /// Pre-fills the login screen with the last phone or CHW ID (never the PIN).
  final bool rememberLogin;
  final String? savedLoginId;
}

/// The user's preferences, kept in SharedPreferences so they survive a restart.
class SettingsController extends Notifier<AppSettings> {
  static const _textSize = 'settings.textSize';
  static const _visitType = 'settings.defaultVisitType';
  static const _remember = 'settings.rememberLogin';
  static const _loginId = 'settings.loginId';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

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

  AppSettings _with({
    TextSize? textSize,
    VisitType? defaultVisitType,
    bool? rememberLogin,
    String? Function()? savedLoginId,
  }) => AppSettings(
    textSize: textSize ?? state.textSize,
    defaultVisitType: defaultVisitType ?? state.defaultVisitType,
    rememberLogin: rememberLogin ?? state.rememberLogin,
    savedLoginId: savedLoginId != null ? savedLoginId() : state.savedLoginId,
  );

  Future<void> setTextSize(TextSize size) async {
    state = _with(textSize: size);
    await _prefs.setString(_textSize, size.name);
  }

  Future<void> setDefaultVisitType(VisitType type) async {
    state = _with(defaultVisitType: type);
    await _prefs.setString(_visitType, type.name);
  }

  /// Turning it off forgets the saved ID straight away.
  Future<void> setRememberLogin(bool on) async {
    state = _with(rememberLogin: on, savedLoginId: on ? null : () => null);
    await _prefs.setBool(_remember, on);
    if (!on) await _prefs.remove(_loginId);
  }

  /// Called after a successful login.
  Future<void> loggedInAs(String id) async {
    if (!state.rememberLogin) return;
    final trimmed = id.trim();
    state = _with(savedLoginId: () => trimmed);
    await _prefs.setString(_loginId, trimmed);
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
