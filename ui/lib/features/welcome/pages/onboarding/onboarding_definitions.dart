import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Pages that make up the first-use tutorial flow.
enum TutorialPage {
  permissions,
  provider,
  providerSelection,
  providerConnection,
  modelInventory,
  primaryScenes,
  memoryScenes,
  completion,
}

/// Pages reachable through the dotted pagination footer, in order.
const List<TutorialPage> tutorialNavigationPages = <TutorialPage>[
  TutorialPage.permissions,
  TutorialPage.provider,
  TutorialPage.providerSelection,
  TutorialPage.providerConnection,
  TutorialPage.modelInventory,
  TutorialPage.primaryScenes,
  TutorialPage.memoryScenes,
];

/// A model provider the user can connect to.
class ProviderOption {
  const ProviderOption({
    required this.id,
    required this.label,
    required this.vendorKey,
    required this.baseUrl,
    required this.sourceType,
    required this.protocolType,
  });

  final String id;
  final String label;
  final String? vendorKey;
  final String baseUrl;
  final String sourceType;
  final String protocolType;
}

/// A background role that can be bound to a model.
class SceneDefinition {
  const SceneDefinition({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
  });

  final String id;
  final IconData icon;
  final String title;
  final String description;
}

const List<ProviderOption> providerOptions = <ProviderOption>[
  ProviderOption(
    id: 'deepseek',
    label: 'DeepSeek',
    vendorKey: 'deepseek',
    baseUrl: 'https://api.deepseek.com',
    sourceType: 'deepseek',
    protocolType: 'deepseek',
  ),
  ProviderOption(
    id: 'moonshot',
    label: 'Kimi',
    vendorKey: 'moonshot',
    baseUrl: 'https://api.moonshot.cn/v1',
    sourceType: 'moonshot',
    protocolType: 'openai_compatible',
  ),
  ProviderOption(
    id: 'mimo',
    label: 'Mimo',
    vendorKey: 'xiaomi',
    baseUrl: 'https://api.xiaomimimo.com/v1',
    sourceType: 'mimo',
    protocolType: 'openai_compatible',
  ),
  ProviderOption(
    id: 'openai',
    label: 'OpenAI',
    vendorKey: 'openai',
    baseUrl: 'https://api.openai.com/v1',
    sourceType: 'custom',
    protocolType: 'openai_compatible',
  ),
  ProviderOption(
    id: 'anthropic',
    label: 'Anthropic',
    vendorKey: 'anthropic',
    baseUrl: 'https://api.anthropic.com/v1',
    sourceType: 'custom',
    protocolType: 'anthropic',
  ),
  ProviderOption(
    id: 'custom',
    label: 'API متوافقة',
    vendorKey: null,
    baseUrl: '',
    sourceType: 'custom',
    protocolType: 'openai_compatible',
  ),
];

const List<SceneDefinition> sceneDefinitions = <SceneDefinition>[
  SceneDefinition(
    id: 'scene.dispatch.model',
    icon: LucideIcons.bot,
    title: 'الوكيل',
    description: 'يفهم مهمتك ويخطط لها وينفذها. اختر أقوى نموذج لديك.',
  ),
  SceneDefinition(
    id: 'scene.compactor.context.chat',
    icon: LucideIcons.messagesSquare,
    title: 'تلخيص المحادثة',
    description: 'يختصر المحادثات الطويلة دون أن يضيع معناها.',
  ),
  SceneDefinition(
    id: 'scene.memory.embedding',
    icon: LucideIcons.database,
    title: 'البحث في الذاكرة',
    description: 'يحفظ ذكرياتك بطريقة تسهِّل البحث فيها.',
  ),
  SceneDefinition(
    id: 'scene.memory.rollup',
    icon: LucideIcons.memoryStick,
    title: 'تلخيص الذاكرة',
    description: 'يلخّص ذكرياتك القديمة ويحذف المكرر منها.',
  ),
];
