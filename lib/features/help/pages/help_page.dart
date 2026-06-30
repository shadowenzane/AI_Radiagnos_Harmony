import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// 帮助文档页：详细列出各家 LLM 及知识库的配置方法与 API Key 获取方法
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('帮助文档'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.smart_toy_outlined), text: 'LLM 大模型'),
              Tab(icon: Icon(Icons.menu_book_outlined), text: '知识库'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _LlmTab(),
            _KbTab(),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LLM 大模型 Tab
// ============================================================
class _LlmTab extends StatelessWidget {
  const _LlmTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: const [
        _IntroCard(
          title: '大模型 API 配置说明',
          content: '本 App 支持以下 8 家大模型提供商。每家提供商均需要先在官网注册账号、'
              '获取 API Key，然后在「AI 模型配置」页面添加配置并填入 API Key 即可使用。\n\n'
              '下方按提供商分别列出注册入口、API Key 获取步骤与调用配置。',
        ),
        SizedBox(height: 8),
        _ProviderCard(
          icon: Icons.psychology,
          color: Color(0xFF4D6BFE),
          name: 'DeepSeek',
          tagline: '深度求索 · 国产高性价比大模型',
          officialUrl: 'https://platform.deepseek.com/',
          apiUrl: 'https://api.deepseek.com/v1/chat/completions',
          models: 'deepseek-chat、deepseek-reasoner、deepseek-v4-flash、deepseek-v4-pro',
          steps: [
            '访问 https://platform.deepseek.com/ 注册并登录（支持手机号/邮箱）',
            '进入「API Keys」页面，点击「创建 API Key」',
            '为 Key 设置名称（如 AI_Radiagnos），生成后立即复制保存（仅显示一次）',
            '首次使用需在「充值」页面充值余额（最低 1 元起）',
            '在 App 的「AI 模型配置」中新增配置，选择 DeepSeek，粘贴 API Key',
            '推荐模型：deepseek-chat（通用）、deepseek-reasoner（推理增强）',
          ],
          notes: 'API 兼容 OpenAI 格式；deepseek-reasoner 会输出思维链 reasoning_content。',
        ),
        SizedBox(height: 8),
        _ProviderCard(
          icon: Icons.local_fire_department,
          color: Color(0xFF325AB4),
          name: '豆包 / 火山方舟',
          tagline: '字节跳动 · 火山引擎大模型服务',
          officialUrl: 'https://www.volcengine.com/product/doubao',
          apiUrl: 'https://ark.cn-beijing.volces.com/api/v3/responses',
          models: 'doubao-seed-2-0-pro / lite / mini、doubao-seed-1-6 系列、doubao-1-5-pro-32k 等',
          steps: [
            '访问 https://www.volcengine.com/product/doubao 注册火山引擎账号',
            '完成实名认证（个人/企业均可）',
            '进入「火山方舟」控制台 https://console.volcengine.com/ark/',
            '在「开通管理」中开通 Doubao 模型对应服务',
            '在「API Key 管理」中创建 API Key（ak + sk 形式，复制保存）',
            '可选：在「在线推理」中创建 Endpoint，获取 Endpoint ID（ep-xxxxxxxx）',
            '在 App 的「AI 模型配置」中新增配置，选择「豆包(火山引擎)」',
            '模型名称可填具体模型名，也可填 Endpoint ID',
          ],
          notes: '本 App 使用 Responses API；建议直接填模型名（自动路由），无需 Endpoint。',
        ),
        SizedBox(height: 8),
        _ProviderCard(
          icon: Icons.public,
          color: Color(0xFF10A37F),
          name: 'OpenAI',
          tagline: 'GPT 系列大模型',
          officialUrl: 'https://platform.openai.com/',
          apiUrl: 'https://api.openai.com/v1/chat/completions',
          models: 'gpt-4o、gpt-4o-mini、gpt-4-turbo、gpt-3.5-turbo',
          steps: [
            '访问 https://platform.openai.com/ 注册账号（需海外手机号/邮箱验证）',
            '登录后进入「API keys」页面 https://platform.openai.com/api-keys',
            '点击「Create new secret key」生成 API Key（sk- 开头），复制保存',
            '在「Billing」页面绑定信用卡并充值（按 Token 计费）',
            '在 App 的「AI 模型配置」中新增配置，选择 OpenAI，粘贴 API Key',
          ],
          notes: '中国大陆 IP 可能需要代理；请确保账号已开通对应模型权限。',
        ),
        SizedBox(height: 8),
        _ProviderCard(
          icon: Icons.auto_awesome,
          color: Color(0xFF3366FF),
          name: '智谱 AI (GLM)',
          tagline: '清华系国产大模型',
          officialUrl: 'https://open.bigmodel.cn/',
          apiUrl: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
          models: 'glm-4-plus、glm-4、glm-4-air、glm-4-flash、glm-4-long、glm-4-flashx',
          steps: [
            '访问 https://open.bigmodel.cn/ 注册并登录智谱开放平台',
            '完成实名认证',
            '进入「API Keys」页面 https://open.bigmodel.cn/usercenter/apikeys',
            '点击「添加 API Key」生成密钥（xxx.yyy 格式），复制保存',
            '新用户注册赠送免费额度，可在「财务总览」查看余额',
            '在 App 的「AI 模型配置」中新增配置，选择「智谱AI (GLM)」',
            '推荐模型：glm-4-flash（免费）、glm-4-plus（旗舰）',
          ],
          notes: 'API 兼容 OpenAI 格式；glm-4-flash 模型完全免费。',
        ),
        SizedBox(height: 8),
        _ProviderCard(
          icon: Icons.hub,
          color: Color(0xFF615CED),
          name: '通义千问 (Qwen)',
          tagline: '阿里云 · DashScope',
          officialUrl: 'https://dashscope.aliyun.com/',
          apiUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
          models: 'qwen-max、qwen-plus、qwen-turbo、qwen-long',
          steps: [
            '访问 https://dashscope.aliyun.com/ 登录阿里云账号（需实名认证）',
            '开通「DashScope」服务（开通免费，按调用计费）',
            '进入控制台 https://bailian.console.aliyun.com/?apiKey=1#/api-key',
            '点击「创建 API-KEY」生成 sk- 开头的密钥，复制保存',
            '新用户通常有免费额度（如 qwen-turbo 限时免费）',
            '在 App 的「AI 模型配置」中新增配置，选择「通义千问」',
          ],
          notes: '使用 OpenAI 兼容模式接入；与阿里百炼知识库共用阿里云账号体系。',
        ),
        SizedBox(height: 8),
        _ProviderCard(
          icon: Icons.nightlight,
          color: Color(0xFF1D1D1F),
          name: 'Kimi (Moonshot)',
          tagline: '月之暗面 · 长文本大模型',
          officialUrl: 'https://platform.moonshot.cn/',
          apiUrl: 'https://api.moonshot.cn/v1/chat/completions',
          models: 'moonshot-v1-8k、moonshot-v1-32k、moonshot-v1-128k',
          steps: [
            '访问 https://platform.moonshot.cn/ 注册并登录',
            '完成实名认证',
            '进入「API Key 管理」页面 https://platform.moonshot.cn/console/api-keys',
            '点击「创建 API Key」生成 sk- 开头密钥，复制保存',
            '在「充值」页面充值余额（限时活动可能有赠送）',
            '在 App 的「AI 模型配置」中新增配置，选择「Kimi (Moonshot)」',
            '根据上下文长度需求选择 8k / 32k / 128k 模型',
          ],
          notes: 'API 兼容 OpenAI 格式；擅长长文本处理，128k 支持约 20 万字上下文。',
        ),
        SizedBox(height: 8),
        _ProviderCard(
          icon: Icons.phone_android,
          color: Color(0xFFFF6900),
          name: '小米 MiMo',
          tagline: '小米 AI 大模型',
          officialUrl: 'https://api.mimo.xiaomi.com/',
          apiUrl: 'https://api.mimo.xiaomi.com/v1/chat/completions',
          models: 'mimo-7b-rl',
          steps: [
            '访问 https://api.mimo.xiaomi.com/ 注册小米开放平台账号',
            '完成实名认证',
            '在控制台「API Keys」页面创建 API Key',
            '复制保存生成的 API Key',
            '在 App 的「AI 模型配置」中新增配置，选择「小米 MiMo」',
          ],
          notes: '新兴服务，具体开通流程以官网公告为准。',
        ),
        SizedBox(height: 8),
        _ProviderCard(
          icon: Icons.diamond,
          color: Color(0xFF4285F4),
          name: 'Google Gemini',
          tagline: 'Google 多模态大模型',
          officialUrl: 'https://ai.google.dev/',
          apiUrl: 'https://generativelanguage.googleapis.com/v1beta/models',
          models: 'gemini-2.0-flash、gemini-2.5-flash、gemini-1.5-pro、gemini-1.5-flash',
          steps: [
            '访问 https://ai.google.dev/ 注册 Google 账号',
            '进入 Google AI Studio https://aistudio.google.com/app/apikey',
            '点击「Get API Key」或「Create API Key」生成密钥（AIza 开头）',
            '复制保存 API Key',
            '在 App 的「AI 模型配置」中新增配置，选择「Google Gemini」',
            '推荐模型：gemini-2.0-flash（速度快、免费额度大）',
          ],
          notes: '中国大陆 IP 可能需要代理；Gemini 使用独立的 generateContent 接口（非 OpenAI 兼容）。',
        ),
        SizedBox(height: 20),
      ],
    );
  }
}

// ============================================================
// 知识库 Tab
// ============================================================
class _KbTab extends StatelessWidget {
  const _KbTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: const [
        _IntroCard(
          title: '知识库配置说明',
          content: '知识库为可选项：用于在 AI 诊断后，自动检索文档快照附在结果中，'
              '辅助核对诊断与提供参考依据。本 App 支持以下 3 家知识库提供商。\n\n'
              '每家知识库需要先在对应平台创建知识库、上传文档，再获取对应凭证填入配置。',
        ),
        SizedBox(height: 8),
        _ProviderCard(
          icon: Icons.cloud,
          color: Color(0xFFFF6A00),
          name: '阿里百炼知识库',
          tagline: '阿里云 · 百炼 RAG 知识库',
          officialUrl: 'https://bailian.console.aliyun.com/',
          apiUrl: 'https://bailian.cn-beijing.aliyuncs.com',
          models: 'Retrieve 接口（POST /{WorkspaceId}/index/retrieve）',
          steps: [
            '访问 https://bailian.console.aliyun.com/ 登录阿里云（需实名认证）',
            '开通「百炼」服务，进入控制台',
            '在「业务空间」中创建或选择业务空间，记录「业务空间 ID」（Workspace ID）',
            '在「知识库」中创建知识库（选择 RAG 类型），上传文档（PDF/Word/TXT）',
            '在知识库详情页获取「知识库 ID」（Index ID）',
            '在「RAM 访问控制」→「用户」中创建 RAM 用户（或使用已有用户）',
            '为 RAM 用户授权：AliyunBailianDataFullAccess 策略',
            '为 RAM 用户创建 AccessKey（访问密钥）：获取 AccessKey ID 与 AccessKey Secret',
            '在百炼控制台「成员管理」中将该 RAM 用户加入业务空间',
            '在 App 的「知识库配置」中新增配置，选择「阿里百炼知识库」',
            '依次填写：业务空间 ID、知识库 ID、AccessKey ID、AccessKey Secret',
          ],
          notes: '使用阿里云 ROA 签名（HMAC-SHA1）认证。\n'
              '⚠ AccessKey Secret 仅在创建时显示一次，请务必立即保存。\n'
              '⚠ 切勿使用主账号 AK，建议使用 RAM 子账号并仅授予百炼相关权限。',
        ),
        SizedBox(height: 8),
        _ProviderCard(
          icon: Icons.local_fire_department,
          color: Color(0xFF325AB4),
          name: '火山方舟知识库',
          tagline: '字节跳动 · 火山引擎标准知识库',
          officialUrl: 'https://www.volcengine.com/product/ark-knowledge',
          apiUrl: 'https://api-knowledgebase.mlp.cn-beijing.volces.com/api/knowledge/collection/search_knowledge',
          models: 'search_knowledge 接口',
          steps: [
            '访问 https://www.volcengine.com/ 注册火山引擎账号并实名认证',
            '开通「火山方舟知识库」服务 https://console.volcengine.com/ark/',
            '在「知识库」中创建知识库（Collection），上传文档',
            '在知识库详情页获取「Resource ID」与「集合名称」（Collection Name）',
            '在火山引擎控制台「密钥管理」中创建 Access Key / Secret Key',
            '在 App 的「知识库配置」中新增配置，选择「火山方舟知识库」',
            '填写 Access Key、Secret Key、Resource ID 或集合名称',
          ],
          notes: '使用 HMAC-SHA256 签名认证；与豆包 LLM 共用火山引擎账号体系。',
        ),
        SizedBox(height: 8),
        _ProviderCard(
          icon: Icons.diamond,
          color: Color(0xFF4285F4),
          name: 'Google NotebookLM',
          tagline: 'Google · Gemini File Search',
          officialUrl: 'https://ai.google.dev/',
          apiUrl: 'https://generativelanguage.googleapis.com/v1beta',
          models: 'generateContent + fileSearch',
          steps: [
            '访问 https://ai.google.dev/ 注册 Google 账号',
            '进入 Google AI Studio https://aistudio.google.com/app/apikey 创建 API Key',
            '在 Gemini API 中上传文件到 File Search Store',
            '记录 File Search Store ID',
            '在 App 的「知识库配置」中新增配置，选择「Google NotebookLM」',
            '填写 Gemini API Key 与 File Search Store ID',
          ],
          notes: '中国大陆 IP 可能需要代理；与 Gemini LLM 共用 API Key 体系。',
        ),
        SizedBox(height: 20),
      ],
    );
  }
}

// ============================================================
// 通用组件
// ============================================================
class _IntroCard extends StatelessWidget {
  final String title;
  final String content;
  const _IntroCard({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.primaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: scheme.primary)),
              ],
            ),
            const SizedBox(height: 8),
            Text(content, style: TextStyle(fontSize: 13, height: 1.6, color: scheme.onSurface)),
          ],
        ),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String name;
  final String tagline;
  final String officialUrl;
  final String apiUrl;
  final String models;
  final List<String> steps;
  final String notes;
  const _ProviderCard({
    required this.icon,
    required this.color,
    required this.name,
    required this.tagline,
    required this.officialUrl,
    required this.apiUrl,
    required this.models,
    required this.steps,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(tagline, style: const TextStyle(fontSize: 12)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _InfoRow(label: '官方入口', value: officialUrl, url: officialUrl),
          _InfoRow(label: 'API 地址', value: apiUrl, copyable: true),
          _InfoRow(label: '可用模型', value: models),
          const SizedBox(height: 8),
          const _SubHeader(title: '配置步骤'),
          ...List.generate(steps.length, (i) => _StepItem(index: i + 1, text: steps[i])),
          const SizedBox(height: 8),
          const _SubHeader(title: '注意事项'),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tips_and_updates_outlined, size: 16, color: scheme.tertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(notes, style: TextStyle(fontSize: 12, height: 1.5, color: scheme.onSurface)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final String? url;
  final bool copyable;
  const _InfoRow({required this.label, required this.value, this.url, this.copyable = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: SelectableText(value, style: TextStyle(fontSize: 12, color: scheme.onSurface)),
          ),
          if (url != null)
            IconButton(
              iconSize: 16,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.open_in_new, size: 16, color: scheme.primary),
              tooltip: '打开链接',
              onPressed: () => _launchUrl(url!),
            ),
          if (copyable)
            IconButton(
              iconSize: 16,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.copy, size: 16, color: scheme.primary),
              tooltip: '复制',
              onPressed: () => Clipboard.setData(ClipboardData(text: value)),
            ),
        ],
      ),
    );
  }
}

class _SubHeader extends StatelessWidget {
  final String title;
  const _SubHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Row(
        children: [
          Container(width: 3, height: 12, color: scheme.primary),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.primary)),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final int index;
  final String text;
  const _StepItem({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$index', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: scheme.primary)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(text, style: TextStyle(fontSize: 12, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

Future<void> _launchUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
