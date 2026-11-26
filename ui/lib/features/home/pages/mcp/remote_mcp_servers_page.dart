import 'package:ui/widgets/omni_adaptive_layout.dart';
import 'package:ui/widgets/flclash/page_activity.dart';
import 'package:flutter/material.dart';
import 'package:ui/widgets/omni_glass.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/models/remote_mcp_server.dart';
import 'package:ui/services/remote_mcp_config_service.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/utils/ui.dart';
import 'package:ui/widgets/common_app_bar.dart';
import 'package:ui/widgets/omni_glass_floating_action_button.dart';
import 'package:ui/widgets/settings_detail_sheet.dart';
import 'package:ui/widgets/settings_section_title.dart';
import 'package:ui/widgets/settings_ui.dart';

class RemoteMcpServersPage extends StatefulWidget {
  const RemoteMcpServersPage({super.key});

  @override
  State<RemoteMcpServersPage> createState() => _RemoteMcpServersPageState();
}

class _RemoteMcpServersPageState extends State<RemoteMcpServersPage>
    with FlClashPageLoadMixin {
  bool _loading = true;
  final Set<String> _busyIds = {};
  List<RemoteMcpServer> _servers = [];

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  Future<void> _loadServers() async {
    if (!await waitForPageReady() || !mounted) return;
    setState(() => _loading = true);
    try {
      final servers = await RemoteMcpConfigService.listServers();
      if (!await waitForPageReady() || !mounted) return;
      setState(() {
        _servers = servers;
        _loading = false;
      });
    } on PlatformException catch (e) {
      if (!await waitForPageReady() || !mounted) return;
      setState(() => _loading = false);
      showToast(
        e.message ??
            ('تعذّر تحميل أدوات MCP'),
        type: ToastType.error,
      );
    } catch (e) {
      if (!await waitForPageReady() || !mounted) return;
      setState(() => _loading = false);
      showToast(
        'تعذّر تحميل أدوات MCP',
        type: ToastType.error,
      );
    }
  }

  Future<void> _toggleServer(RemoteMcpServer server, bool enabled) async {
    _setBusy(server.id, true);
    try {
      final updated = await RemoteMcpConfigService.setServerEnabled(
        server.id,
        enabled,
      );
      if (!mounted) return;
      setState(() {
        _servers = _servers.map((item) {
          if (item.id != server.id) return item;
          return updated ?? item.copyWith(enabled: enabled);
        }).toList();
      });
    } catch (e) {
      showToast(
        'تعذّر التبديل',
        type: ToastType.error,
      );
    } finally {
      _setBusy(server.id, false);
    }
  }

  Future<void> _refreshTools(RemoteMcpServer server) async {
    _setBusy(server.id, true);
    try {
      final updated = await RemoteMcpConfigService.refreshServerTools(
        server.id,
      );
      if (!mounted) return;
      setState(() {
        _servers = _servers.map((item) {
          if (item.id != server.id) return item;
          return updated ?? item;
        }).toList();
      });
      showToast(
        'تم تحديث قائمة الأدوات',
      );
    } on PlatformException catch (e) {
      await _reloadServersSilently();
      showToast(
        e.message ??
            ('تعذّر التحديث'),
        type: ToastType.error,
      );
    } catch (_) {
      showToast(
        'تعذّر التحديث',
        type: ToastType.error,
      );
    } finally {
      _setBusy(server.id, false);
    }
  }

  Future<void> _reloadServersSilently() async {
    try {
      final servers = await RemoteMcpConfigService.listServers();
      if (!mounted) return;
      setState(() => _servers = servers);
    } catch (_) {
      // Preserve the operation error already shown to the user.
    }
  }

  Future<void> _deleteServer(RemoteMcpServer server) async {
    final confirmed = await showSettingsDetailSheet<bool>(
      context: context,
      builder: (sheetContext) => SettingsDetailSheet(
        title: 'حذف خدمة MCP',
        body: Text(
          'هل أنت متأكد من حذف "${server.name}"؟',
        ),
        actions: [
          TextButton(
            style: settingsDetailSheetActionStyle(sheetContext),
            onPressed: () => Navigator.of(sheetContext).pop(false),
            child: Text('إلغاء'),
          ),
          TextButton(
            style: settingsDetailSheetActionStyle(
              sheetContext,
              foregroundColor: AppColors.alertRed,
            ),
            onPressed: () => Navigator.of(sheetContext).pop(true),
            child: Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    _setBusy(server.id, true);
    try {
      await RemoteMcpConfigService.deleteServer(server.id);
      if (!mounted) return;
      setState(() {
        _servers.removeWhere((item) => item.id == server.id);
      });
      showToast(
        'تم الحذف',
      );
    } catch (e) {
      showToast(
        'تعذّر الحذف',
        type: ToastType.error,
      );
    } finally {
      _setBusy(server.id, false);
    }
  }

  Future<void> _showServerEditor({RemoteMcpServer? server}) async {
    final saved = await showOmniGlassBottomSheet<RemoteMcpServer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RemoteMcpServerEditorSheet(server: server),
    );

    if (saved == null) return;
    try {
      final result = await RemoteMcpConfigService.upsertServer(saved);
      if (result == null || !mounted) return;
      setState(() {
        final index = _servers.indexWhere((item) => item.id == result.id);
        if (index == -1) {
          _servers = [result, ..._servers];
        } else {
          _servers[index] = result;
        }
      });
      showToast(
        'تم الحفظ',
      );
    } catch (e) {
      showToast(
        'تعذّر الحفظ',
        type: ToastType.error,
      );
    }
  }

  void _setBusy(String id, bool busy) {
    if (!mounted) return;
    setState(() {
      if (busy) {
        _busyIds.add(id);
      } else {
        _busyIds.remove(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: CommonAppBar(
        title: 'أدوات MCP',
        primary: true,
      ),
      floatingActionButton: OmniGlassFloatingActionButton(
        builder: (context, glass) => FloatingActionButton(
          backgroundColor: glass ? Colors.transparent : palette.accentPrimary,
          foregroundColor: glass
              ? palette.textPrimary
              : Theme.of(context).colorScheme.onPrimary,
          elevation: glass ? 0 : 2,
          focusElevation: glass ? 0 : null,
          hoverElevation: glass ? 0 : null,
          highlightElevation: glass ? 0 : null,
          disabledElevation: glass ? 0 : null,
          onPressed: () => _showServerEditor(),
          child: const Icon(LucideIcons.plus),
        ),
      ),
      body: OmniContentWidth(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _servers.isEmpty
            ? _buildEmpty()
            : RefreshIndicator(
                onRefresh: _loadServers,
                child: ListView(
                  padding: edgeToEdgeScrollPadding(
                    context,
                    const EdgeInsets.fromLTRB(22, 12, 22, 32),
                  ),
                  children: [
                    SettingsSectionTitle(
                      label:
                          'الخدمات البعيدة',
                    ),
                    for (int index = 0; index < _servers.length; index++) ...[
                      _buildServerCard(_servers[index]),
                      if (index != _servers.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildEmpty() {
    final palette = context.omniPalette;
    return ListView(
      padding: edgeToEdgeScrollPadding(context, const EdgeInsets.all(24)),
      children: [
        const SizedBox(height: 120),
        Icon(LucideIcons.puzzle, size: 40, color: palette.textTertiary),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'لا توجد خدمات MCP بعيدة',
            style: TextStyle(fontSize: 15, color: palette.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildServerCard(RemoteMcpServer server) {
    final palette = context.omniPalette;
    final busy = _busyIds.contains(server.id);
    return OmniSettingsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      server.endpointUrl,
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              OmniSettingsSwitch(
                value: server.enabled,
                enabled: !busy,
                onToggle: (value) => _toggleServer(server, value),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(label: _healthLabel(server.lastHealth)),
              _MetaChip(
                label: 'الأدوات ${server.toolCount}',
              ),
              if ((server.lastError ?? '').isNotEmpty)
                _MetaChip(
                  label: server.lastError!,
                  color: AppColors.alertRed.withValues(alpha: 0.08),
                  textColor: AppColors.alertRed,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: busy ? null : () => _refreshTools(server),
                child: Text(
                  'تحديث الأدوات',
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: busy
                    ? null
                    : () => _showServerEditor(server: server),
                child: Text(
                  'تحرير',
                ),
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.alertRed,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: busy ? null : () => _deleteServer(server),
                child: Text(
                  'حذف',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _healthLabel(String health) {
    switch (health) {
      case 'healthy':
        return 'متصل';
      case 'error':
        return 'خطأ في الاتصال';
      default:
        return 'غير معروف';
    }
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String? hint;

  const _InputField({
    required this.controller,
    this.focusNode,
    required this.label,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: TextStyle(fontSize: 15, color: palette.textPrimary),
      decoration: omniSettingsInputDecoration(
        context,
        labelText: label,
        hintText: hint,
      ),
    );
  }
}

class _RemoteMcpServerEditorSheet extends StatefulWidget {
  const _RemoteMcpServerEditorSheet({this.server});

  final RemoteMcpServer? server;

  @override
  State<_RemoteMcpServerEditorSheet> createState() =>
      _RemoteMcpServerEditorSheetState();
}

class _RemoteMcpServerEditorSheetState
    extends State<_RemoteMcpServerEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _endpointController;
  late final TextEditingController _tokenController;
  final FocusNode _nameFocusNode = FocusNode();
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.server?.name ?? '');
    _endpointController = TextEditingController(
      text: widget.server?.endpointUrl ?? '',
    );
    _tokenController = TextEditingController(
      text: widget.server?.bearerToken ?? '',
    );
    _enabled = widget.server?.enabled ?? true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _nameFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _nameController.dispose();
    _endpointController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _close([RemoteMcpServer? value]) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(value);
  }

  void _submit() {
    final name = _nameController.text.trim();
    final endpoint = _endpointController.text.trim();
    if (name.isEmpty || endpoint.isEmpty) {
      showToast(
        'يُرجى إدخال الاسم والعنوان معًا',
        type: ToastType.error,
      );
      return;
    }
    _close(
      (widget.server ??
              const RemoteMcpServer(
                id: '',
                name: '',
                endpointUrl: '',
                bearerToken: '',
                enabled: true,
                lastHealth: 'unknown',
                toolCount: 0,
              ))
          .copyWith(
            name: name,
            endpointUrl: endpoint,
            bearerToken: _tokenController.text.trim(),
            enabled: _enabled,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: OmniGlassSheet(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.server == null
                      ? ('إضافة خدمة MCP')
                      : ('تحرير خدمة MCP'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                _InputField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  label: 'الاسم',
                ),
                const SizedBox(height: 12),
                _InputField(
                  controller: _endpointController,
                  label: 'رابط نقطة النهاية',
                  hint: 'https://example.com/mcp',
                ),
                const SizedBox(height: 12),
                _InputField(
                  controller: _tokenController,
                  label: 'رمز Bearer (اختياري)',
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'مفعّل',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: context.omniPalette.textPrimary,
                        ),
                      ),
                    ),
                    OmniSettingsSwitch(
                      value: _enabled,
                      onToggle: (value) => setState(() => _enabled = value),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: Text(
                      'حفظ',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;

  const _MetaChip({required this.label, this.color, this.textColor});

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? palette.surfaceSecondary,
        borderRadius: BorderRadius.circular(999),
        border: color == null && context.isDarkTheme
            ? Border.all(color: palette.borderSubtle)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: textColor ?? palette.textSecondary,
        ),
      ),
    );
  }
}
