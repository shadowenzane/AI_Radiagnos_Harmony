import 'package:flutter/material.dart';
import 'config_storage.dart';
import 'constants.dart';

/// 默认检查方法偏好（ChangeNotifier）
///
/// 持久化用户在设置页选择的"默认查询条件（检查方法）"，
/// 主页启动时默认选中该检查方法。
class ExamPrefs extends ChangeNotifier {
  String _defaultExamType = kExamTypes.first;

  String get defaultExamType => _defaultExamType;

  Future<void> initialize() async {
    final saved = await ConfigStorage.loadDefaultExamType();
    if (saved.isNotEmpty && kExamTypes.contains(saved)) {
      _defaultExamType = saved;
    } else {
      _defaultExamType = kExamTypes.first;
    }
    notifyListeners();
  }

  Future<void> setDefaultExamType(String examType) async {
    if (_defaultExamType == examType) return;
    _defaultExamType = examType;
    await ConfigStorage.saveDefaultExamType(examType);
    notifyListeners();
  }
}
