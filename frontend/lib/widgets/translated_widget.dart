import 'package:flutter/material.dart';
import '../services/app_localizations.dart';

/// Widget de base qui se reconstruit automatiquement
/// quand la langue change
mixin TranslatedWidget<T extends StatefulWidget> on State<T> {
  String tr(String key) => AppLocalizations.t(key);

  @override
  void initState() {
    super.initState();
    AppLocalizations.instance.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    AppLocalizations.instance.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }
}