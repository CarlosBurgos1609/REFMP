import 'package:flutter/material.dart';

class Reload {
  static final Reload _instance = Reload._internal();

  factory Reload() {
    return _instance;
  }

  Reload._internal();

  final Map<String, ValueNotifier<bool>> _reloadNotifiers = {};

  ValueNotifier<bool> getNotifier(String key) {
    return _reloadNotifiers.putIfAbsent(key, () => ValueNotifier<bool>(false));
  }

  void refresh(String key) {
    if (_reloadNotifiers.containsKey(key)) {
      _reloadNotifiers[key]!.value = !_reloadNotifiers[key]!.value;
    }
  }

  Widget buildRefreshIndicator({required String key, required Widget child}) {
    return RefreshIndicator(
      onRefresh: () async {
        refresh(key);
      },
      child: child,
    );
  }
}
