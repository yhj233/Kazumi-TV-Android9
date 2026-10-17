class PlayerErrorMapper {
  const PlayerErrorMapper._();

  static String? toActionableMessage(
    Object error, {
    required bool isBuffering,
  }) {
    final message = error.toString();

    // 打不开 / 识别不了格式：签名过期、CDN 掐断连接或线路本身不可用。
    // 这类错误在网络流里很常见，之前只有处于缓冲态时才提示，
    // 结果是黑屏转圈但用户看不到任何原因，这里统一给出可操作提示。
    if (message.contains('Failed to recognize file format') ||
        message.contains('Failed to open') ||
        message.contains('ffurl_read returned')) {
      return '加载失败, 请尝试更换其他视频来源';
    }

    // 缺少对应解码器（典型：低端电视盒子没有 AV1 硬解，软解又跟不上）
    if (message.contains('Could not open codec') ||
        message.contains('No video decoder') ||
        message.contains('Failed to initialize a decoder') ||
        message.contains('Could not find decoder')) {
      return '本机不支持该视频编码, 请更换其他来源或线路';
    }

    return null;
  }
}
