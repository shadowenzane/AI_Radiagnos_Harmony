import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/note_data.dart';
import '../services/note_pdf_service.dart';

/// 已保存笔记仓库（ChangeNotifier）
///
/// 管理 PDF 笔记文件 + 元信息列表：
/// - PDF 文件存于 应用文档目录/notes/
/// - 元信息列表持久化到 SharedPreferences（JSON）
class NotesRepo extends ChangeNotifier {
  static const String _kNotesKey = 'saved_notes_v1';
  final _uuid = const Uuid();

  List<NoteMeta> _notes = [];
  List<NoteMeta> get notes => List.unmodifiable(_notes);

  /// 初始化：从本地加载元信息列表
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kNotesKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        _notes = list.map((e) => NoteMeta.fromJson(e as Map<String, dynamic>)).toList();
        // 校验文件是否真实存在，清理已丢失的记录
        final dir = await _notesDir();
        _notes = _notes.where((n) {
          final f = File('${dir.path}/${n.fileName}');
          return f.existsSync();
        }).toList();
        if (_notes.length != list.length) {
          await _persist();
        }
      } catch (_) {
        _notes = [];
      }
    }
    notifyListeners();
  }

  /// 保存笔记：生成 PDF + 写元信息
  ///
  /// 返回保存的 NoteMeta，失败抛异常。
  Future<NoteMeta> saveNote(NoteData data) async {
    // 1. 生成 PDF 并保存
    final filePath = await NotePdfService.generateAndSave(data);
    final file = File(filePath);
    final fileSize = await file.length();
    final fileName = filePath.split(Platform.pathSeparator).last;

    // 2. 构造元信息
    final meta = NoteMeta(
      id: _uuid.v4(),
      diseaseName: data.diseaseName,
      examType: data.examType,
      keywords: data.keywords,
      savedAt: data.searchTime,
      description: data.description,
      fileName: fileName,
      fileSize: fileSize,
    );

    // 3. 持久化
    _notes = [meta, ..._notes];
    await _persist();
    notifyListeners();
    return meta;
  }

  /// 删除笔记（元信息 + PDF 文件）
  Future<void> deleteNote(String id) async {
    final meta = _notes.where((n) => n.id == id).firstOrNull;
    if (meta == null) return;
    // 删除文件
    try {
      final dir = await _notesDir();
      final file = File('${dir.path}/${meta.fileName}');
      if (file.existsSync()) await file.delete();
    } catch (_) {}
    _notes = _notes.where((n) => n.id != id).toList();
    await _persist();
    notifyListeners();
  }

  /// 获取笔记 PDF 文件路径
  Future<String?> getNoteFilePath(String id) async {
    final meta = _notes.where((n) => n.id == id).firstOrNull;
    if (meta == null) return null;
    final dir = await _notesDir();
    final file = File('${dir.path}/${meta.fileName}');
    return file.existsSync() ? file.path : null;
  }

  /// 通过系统分享/打开 PDF
  Future<void> shareNote(String id) async {
    final path = await getNoteFilePath(id);
    if (path == null) return;
    await Share.shareXFiles([XFile(path)], text: 'AI_Radiagnos 笔记');
  }

  /// 笔记数量
  int get count => _notes.length;

  Future<Directory> _notesDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final notesDir = Directory('${dir.path}/notes');
    if (!notesDir.existsSync()) {
      await notesDir.create(recursive: true);
    }
    return notesDir;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _notes.map((n) => n.toJson()).toList();
    await prefs.setString(_kNotesKey, jsonEncode(jsonList));
  }
}
