import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/windows_hotspot.dart';
import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/common/exception.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final hotspotSupportedProvider = Provider<bool>((ref) => Platform.isWindows);

final hotspotBackendProvider = Provider<HotspotBackend>(
  (ref) => WindowsHotspotBackend(
    tunName: ref.watch(
      patchClashConfigProvider.select((value) => value.tun.device),
    ),
  ),
);

final hotspotReadyProvider = Provider<bool>((ref) {
  return ref.watch(coreStatusProvider) == CoreStatus.connected &&
      ref.watch(isStartProvider) &&
      !ref.watch(suspendProvider) &&
      ref.watch(patchClashConfigProvider.select((value) => value.tun.enable)) &&
      ref.watch(patchClashConfigProvider.select((value) => value.mode)) ==
          Mode.rule;
});

final hotspotControllerProvider =
    NotifierProvider<HotspotController, HotspotSnapshot>(HotspotController.new);

class HotspotController extends Notifier<HotspotSnapshot> {
  Timer? _timer;
  Future<void> _queue = Future.value();
  int _pending = 0;
  bool? _desired;
  bool _disposed = false;
  int _revision = 0;
  int _settledRevision = 0;

  bool get _allowed =>
      ref.read(hotspotSupportedProvider) && !ref.read(safeModeProvider);

  @override
  HotspotSnapshot build() {
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
    });
    ref.listen(hotspotReadyProvider, (_, ready) {
      if (!ready && _desired == true) {
        unawaited(setEnabled(false));
      }
    });
    return const HotspotSnapshot();
  }

  void startMonitoring() {
    if (!_allowed || _timer != null) return;
    unawaited(refresh());
  }

  void _syncMonitoring() {
    if (_disposed) return;
    if (_desired != true && !state.managed) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(refresh());
    });
  }

  Future<void> setEnabled(bool enabled) {
    if (!_allowed) return Future.value();
    if (enabled && !ref.read(hotspotReadyProvider)) {
      state = state.copyWith(error: 'tun_required');
      return Future.value();
    }
    _desired = enabled;
    _revision++;
    final work = _enqueue(_drain);
    return work;
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    _pending++;
    final work = _queue.then((_) async {
      try {
        if (!_disposed) await operation();
      } finally {
        _pending--;
      }
    });
    _queue = work.onError((_, _) {});
    return work;
  }

  Future<void> _drain() async {
    while (!_disposed && _settledRevision != _revision) {
      final revision = _revision;
      final enabled = _desired!;
      state = state.copyWith(busy: true, error: '');
      try {
        final result = await ref
            .read(hotspotBackendProvider)
            .execute(enabled ? HotspotCommand.enable : HotspotCommand.disable);
        if (!_disposed) {
          state = result;
          if (enabled && result.error.isNotEmpty && revision == _revision) {
            _desired = false;
          }
        }
      } catch (_) {
        if (!_disposed) {
          state = state.copyWith(busy: false, error: 'operation_failed');
        }
      }
      _settledRevision = revision;
    }
    _syncMonitoring();
  }

  Future<void> refresh() async {
    if (!_allowed || _pending > 0 || _disposed) return;
    final revision = _revision;
    await _enqueue(() => _refresh(revision));
  }

  Future<void> _refresh(int revision) async {
    try {
      final backend = ref.read(hotspotBackendProvider);
      var result = await backend.execute(HotspotCommand.inspect);
      if (_disposed || revision != _revision) return;
      _desired ??= result.managed;
      if (result.managed && !ref.read(hotspotReadyProvider)) {
        result = await backend.execute(HotspotCommand.disable);
      } else if (result.managed && result.on && !result.throughTun) {
        result = await backend.execute(HotspotCommand.repair);
      } else if (result.managed && !result.on) {
        result = await backend.execute(HotspotCommand.disable);
      }
      if (!_disposed && revision == _revision) {
        state = result;
        _desired = result.managed;
        _syncMonitoring();
      }
    } catch (_) {
      if (!_disposed && revision == _revision) {
        state = state.copyWith(error: 'operation_failed');
      }
    }
  }

  Future<void> shutdown() async {
    if (!_allowed) return;
    _timer?.cancel();
    _timer = null;
    if (_pending > 0 || _desired == true || state.managed) {
      await setEnabled(false);
    }
    if (state.managed) {
      throw MessageException(currentAppLocalizations.hotspotStopFailed);
    }
  }
}
