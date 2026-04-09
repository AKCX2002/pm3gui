/// 性能监控和分析工具
library;

import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';

class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._private();
  factory PerformanceMonitor() => _instance;

  PerformanceMonitor._private();

  final Map<String, Stopwatch> _timers = {};
  final List<PerformanceMetric> _metrics = [];

  /// 开始计时
  void start(String name) {
    if (_timers.containsKey(name)) {
      _timers[name]!.reset();
    } else {
      _timers[name] = Stopwatch()..start();
    }
  }

  /// 停止计时并记录指标
  void stop(String name, {String? category, Map<String, dynamic>? extra}) {
    final timer = _timers[name];
    if (timer == null) return;

    timer.stop();
    final metric = PerformanceMetric(
      name: name,
      duration: timer.elapsedMilliseconds,
      timestamp: DateTime.now(),
      category: category,
      extra: extra,
    );

    _metrics.add(metric);
    _timers.remove(name);

    // 输出性能指标
    if (kDebugMode) {
      print('PERF: $name - ${metric.duration}ms');
    }

    // 发送到开发者工具
    Timeline.timeSync('$name - ${metric.duration}ms', () {
      Timeline.instantSync('Performance Metric', arguments: {
        'name': name,
        'duration': metric.duration,
        'category': category,
        'extra': extra,
      });
    });
  }

  /// 执行带性能监控的操作
  Future<T> measure<T>(String name, Future<T> Function() operation,
      {String? category, Map<String, dynamic>? extra}) async {
    start(name);
    try {
      return await operation();
    } finally {
      stop(name, category: category, extra: extra);
    }
  }

  /// 执行带性能监控的同步操作
  T measureSync<T>(String name, T Function() operation,
      {String? category, Map<String, dynamic>? extra}) {
    start(name);
    try {
      return operation();
    } finally {
      stop(name, category: category, extra: extra);
    }
  }

  /// 获取性能指标列表
  List<PerformanceMetric> get metrics => List.unmodifiable(_metrics);

  /// 清除所有性能指标
  void clearMetrics() {
    _metrics.clear();
  }

  /// 导出性能指标
  String exportMetrics() {
    final buffer = StringBuffer();
    buffer.writeln('Performance Metrics:');
    buffer.writeln('====================');

    for (final metric in _metrics) {
      buffer.writeln(
          '${metric.timestamp}: ${metric.name} - ${metric.duration}ms');
      if (metric.category != null) {
        buffer.writeln('  Category: ${metric.category}');
      }
      if (metric.extra != null && metric.extra!.isNotEmpty) {
        buffer.writeln('  Extra: ${metric.extra}');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}

class PerformanceMetric {
  final String name;
  final int duration; // 毫秒
  final DateTime timestamp;
  final String? category;
  final Map<String, dynamic>? extra;

  PerformanceMetric({
    required this.name,
    required this.duration,
    required this.timestamp,
    this.category,
    this.extra,
  });

  @override
  String toString() {
    return '$name: ${duration}ms at $timestamp';
  }
}
