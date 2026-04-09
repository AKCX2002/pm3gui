/// PM3 图形界面应用入口
///
/// 该应用是一个基于 Flutter 的 Proxmark3 设备图形界面，提供以下功能：
/// - 设备连接与管理
/// - 终端命令执行
/// - 卡片数据查看与分析
/// - 转储文件管理与比较
/// - Mifare 卡片操作
/// - 低频卡片操作
/// - 设置管理
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/ui/theme.dart';
import 'package:pm3gui/ui/home_page.dart';

/// 应用入口函数
///
/// 初始化应用并提供全局状态管理
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const PM3GuiApp(),
    ),
  );
}

/// 应用根组件
///
/// 负责应用的主题管理和页面导航
class PM3GuiApp extends StatelessWidget {
  const PM3GuiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PM3 图形界面',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme(),
      // 应用主页面
      home: const HomePage(),
    );
  }
}
