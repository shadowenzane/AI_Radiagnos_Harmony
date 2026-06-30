import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../core/exam_prefs.dart';
import '../../../core/theme.dart';
import '../../../core/theme_prefs.dart';

/// 设置页：主题色、亮暗模式、字体族、字号缩放、关于
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<ThemePrefs>();
    final examPrefs = context.watch<ExamPrefs>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader(label: '外观', icon: Icons.palette_outlined),
          _ThemeColorSection(prefs: prefs),
          const SizedBox(height: 8),
          _ThemeModeSection(prefs: prefs),
          const SizedBox(height: 16),
          _SectionHeader(label: '字体', icon: Icons.text_fields),
          _FontFamilySection(prefs: prefs),
          const SizedBox(height: 8),
          _TextScaleSection(prefs: prefs),
          const SizedBox(height: 16),
          _SectionHeader(label: '检索', icon: Icons.search),
          _DefaultExamTypeSection(examPrefs: examPrefs),
          const SizedBox(height: 16),
          _SectionHeader(label: '快捷入口', icon: Icons.tune),
          ListTile(
            leading: Icon(Icons.smart_toy_outlined, color: scheme.primary),
            title: const Text('AI 模型配置'),
            subtitle: const Text('添加 / 编辑大模型 API'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/ai-config'),
          ),
          ListTile(
            leading: Icon(Icons.menu_book_outlined, color: scheme.primary),
            title: const Text('知识库配置'),
            subtitle: const Text('添加 / 编辑知识库 API'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/kb-config'),
          ),
          ListTile(
            leading: Icon(Icons.help_outline, color: scheme.primary),
            title: const Text('帮助文档'),
            subtitle: const Text('LLM / 知识库 API 获取与配置指南'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/help'),
          ),
          const SizedBox(height: 16),
          _SectionHeader(label: '关于', icon: Icons.info_outline),
          _AboutSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ---------- 关于区块 ----------
class _AboutSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        // 应用信息
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.medical_information,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(height: 12),
                const Text('AI_Radiagnos',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('版本 1.3.0 · AI 影像辅助诊断',
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text('三端通用（Android / iOS / HarmonyOS）',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 开发者信息
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.person_outline, color: scheme.primary),
                title: const Text('开发者'),
                subtitle: const Text('张兴文'),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.local_hospital_outlined,
                    color: scheme.primary),
                title: const Text('所属单位'),
                subtitle: const Text('楚雄州人民医院 · 医学影像中心'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 版权声明
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.copyright_outlined,
                        size: 18, color: scheme.primary),
                    const SizedBox(width: 6),
                    const Text('版权声明',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '© 2026 楚雄州人民医院 医学影像中心 张兴文。版权所有。\n'
                  '本软件仅供医学影像辅助诊断参考使用，不得用于直接临床诊断。\n'
                  '未经授权，不得复制、传播或用于商业用途。',
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant, height: 1.6),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 信息来源声明
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: scheme.tertiary),
                    const SizedBox(width: 6),
                    const Text('信息来源声明',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '本软件的诊断建议由 AI 大语言模型生成，知识库引用来自第三方知识库服务。\n\n'
                  '⚠ 重要提示：\n'
                  '• AI 生成的诊断建议仅供参考，不能替代专业医师的临床判断\n'
                  '• 最终诊断应由具有执业资格的影像科医师确认\n'
                  '• 知识库引用内容版权归原作者所有\n'
                  '• 使用者需自行验证信息准确性并承担临床决策责任',
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant, height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------- 区块标题 ----------
class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                color: scheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              )),
        ],
      ),
    );
  }
}

// ---------- 主题色 ----------
class _ThemeColorSection extends StatelessWidget {
  final ThemePrefs prefs;
  const _ThemeColorSection({required this.prefs});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('主题色', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('选择应用的主色调',
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).hintColor)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: ThemePresets.all.map((p) {
                final selected = prefs.themeSeedKey == p.key;
                return GestureDetector(
                  onTap: () => prefs.setThemeSeed(p.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: p.seed,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: p.seed.withValues(alpha: 0.35),
                          blurRadius: selected ? 8 : 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: selected
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 22)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              '当前：${ThemePresets.byKey(prefs.themeSeedKey).name}',
              style: TextStyle(
                  fontSize: 12, color: Theme.of(context).hintColor),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- 主题模式 ----------
class _ThemeModeSection extends StatelessWidget {
  final ThemePrefs prefs;
  const _ThemeModeSection({required this.prefs});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('显示模式', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto),
                  label: Text('跟随系统'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode),
                  label: Text('亮色'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode),
                  label: Text('暗色'),
                ),
              ],
              selected: {prefs.themeMode},
              onSelectionChanged: (s) => prefs.setThemeMode(s.first),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- 默认检查方法 ----------
class _DefaultExamTypeSection extends StatelessWidget {
  final ExamPrefs examPrefs;
  const _DefaultExamTypeSection({required this.examPrefs});

  @override
  Widget build(BuildContext context) {
    final current = kExamTypes.contains(examPrefs.defaultExamType)
        ? examPrefs.defaultExamType
        : kExamTypes.first;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('默认检查方法',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('主页启动时默认选中的查询条件',
                style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: current,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.medical_services_outlined),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: kExamTypes
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t, style: const TextStyle(fontSize: 14)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) examPrefs.setDefaultExamType(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- 字体族 ----------
class _FontFamilySection extends StatelessWidget {
  final ThemePrefs prefs;
  const _FontFamilySection({required this.prefs});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('字体族', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('应用到全 App',
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).hintColor)),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: FontFamilyPresets.all
                  .map((f) => ButtonSegment(
                        value: f.key,
                        label: Text(f.name),
                      ))
                  .toList(),
              selected: {prefs.fontFamilyKey},
              onSelectionChanged: (s) => prefs.setFontFamily(s.first),
            ),
            const SizedBox(height: 12),
            // 字体预览
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '影像表现：肝脏实质回声弥漫性增强，远场衰减，肝内管道显示不清。',
                style: TextStyle(
                  fontFamily:
                      FontFamilyPresets.byKey(prefs.fontFamilyKey).fontFamily,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- 字号 ----------
class _TextScaleSection extends StatelessWidget {
  final ThemePrefs prefs;
  const _TextScaleSection({required this.prefs});

  @override
  Widget build(BuildContext context) {
    final current = TextScalePresets.nearest(prefs.textScale);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('字号大小',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    current.name,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('拖动调整全 App 字号',
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).hintColor)),
            const SizedBox(height: 8),
            Slider(
              value: prefs.textScale,
              min: TextScalePresets.all.first.value,
              max: TextScalePresets.all.last.value,
              divisions: TextScalePresets.all.length - 1,
              label: current.name,
              onChanged: (v) => prefs.setTextScale(v),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: TextScalePresets.all
                  .map((p) => Text(p.name,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'AI 诊断建议：考虑脂肪肝可能。',
                style: TextStyle(
                  fontSize: 14 * prefs.textScale,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
