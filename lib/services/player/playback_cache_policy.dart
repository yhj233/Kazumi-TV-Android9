import 'dart:async';
import 'dart:io';

import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/network/metered_network_service.dart';
import 'package:kazumi/services/player/low_memory_mode.dart';
import 'package:kazumi/utils/async_serial_queue.dart';
import 'package:media_kit/media_kit.dart';

class PlaybackCachePolicy {
  PlaybackCachePolicy({
    required bool Function() isLocalPlayback,
    required Player? Function() currentPlayer,
  })  : _isLocalPlayback = isLocalPlayback,
        _currentPlayer = currentPlayer;

  static const int _lowMemoryBufferSize = 2 * 1024 * 1024;
  static const int _defaultBufferSize = 1500 * 1024 * 1024;

  /// 回看缓存（demuxer-max-back-bytes）只影响向后拖动，对在线播放收益很低，
  /// 因此单独限制为前向缓存的一小部分，避免白白占用内存。
  static const int _seekbackDivisor = 4;

  static int? _readMemTotal() {
    try {
      final file = File('/proc/meminfo');
      if (!file.existsSync()) {
        return null;
      }
      for (final line in file.readAsLinesSync()) {
        if (!line.startsWith('MemTotal:')) {
          continue;
        }
        final kb = int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), ''));
        if (kb != null && kb > 0) {
          return kb * 1024;
        }
      }
    } catch (_) {
      // /proc 不可读（非 Linux 或权限受限）时忽略，退回默认容量
    }
    return null;
  }

  static final int? _totalRamBytes = _readMemTotal();

  /// 默认的 1.5 GB demuxer 缓存对电视盒子这类小内存设备是灾难：
  /// 一集 1080p 只有 300 MB 左右，mpv 会把它整集读进内存，
  /// 叠加软件解码后触发内存压力与交换，表现为长时间黑屏、画面卡死。
  ///
  /// 这里按物理内存 1/12 封顶（最少 64 MB、最多 512 MB），
  /// 只在 4 GB 以下的设备生效，桌面端行为保持不变。
  static int _capByDeviceMemory(int fallback) {
    final ram = _totalRamBytes;
    if (ram == null || ram <= 0 || ram >= 4 * 1024 * 1024 * 1024) {
      return fallback;
    }
    final cap =
        (ram ~/ 12).clamp(64 * 1024 * 1024, 512 * 1024 * 1024).toInt();
    return cap < fallback ? cap : fallback;
  }

  final bool Function() _isLocalPlayback;
  final Player? Function() _currentPlayer;
  final AsyncSerialQueue _writes = AsyncSerialQueue();

  StreamSubscription<void>? _settingsSubscription;

  bool get networkAutomatic =>
      LowMemoryMode.current == LowMemoryMode.auto &&
      !_isLocalPlayback() &&
      MeteredNetworkService.isMetered;

  int get bufferSize => LowMemoryMode.current.isEnabled(
        isMetered: MeteredNetworkService.isMetered,
        isLocalPlayback: _isLocalPlayback(),
      )
          ? _lowMemoryBufferSize
          : _capByDeviceMemory(_defaultBufferSize);

  int get seekbackSize => bufferSize ~/ _seekbackDivisor;

  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(0);


  void startWatching() {
    if (_settingsSubscription != null) {
      return;
    }
    _settingsSubscription = LowMemoryMode.watch().listen((_) => _onChanged());
    MeteredNetworkService.listenable.addListener(_onChanged);
  }

  void stopWatching() {
    MeteredNetworkService.listenable.removeListener(_onChanged);
    unawaited(_settingsSubscription?.cancel());
    _settingsSubscription = null;
  }

  Future<void> apply() async {
    final player = _currentPlayer();
    if (player == null) {
      return;
    }
    try {
      final pp = player.platform as NativePlayer;
      // A stale player's initialization must not block its replacement's writes.
      await pp.waitForPlayerInitialization;
      await _writes.run(() async {
        if (!identical(_currentPlayer(), player)) {
          return;
        }
        final size = bufferSize.toString();
        await pp.setProperty('demuxer-max-bytes', size);
        await pp.setProperty('demuxer-max-back-bytes', seekbackSize.toString());
        KazumiLogger().i(
          'PlaybackCachePolicy: demuxer cache '
          'max=${_mb(bufferSize)}MB back=${_mb(seekbackSize)}MB '
          '(MemTotal=${_totalRamBytes == null ? 'unknown' : '${_mb(_totalRamBytes!)}MB'})',
        );
      });
    } catch (e) {
      KazumiLogger().w(
        'PlaybackCachePolicy: failed to apply demuxer cache size',
        error: e,
      );
    }
  }

  void _onChanged() {
    unawaited(apply());
  }
}
