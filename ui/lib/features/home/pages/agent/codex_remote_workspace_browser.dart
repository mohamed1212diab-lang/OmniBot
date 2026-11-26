import 'package:ui/widgets/navigation/page_route.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ui/widgets/omni_circle_button.dart';
import 'package:flutter/services.dart';
import 'package:ui/features/home/pages/agent/codex_remote_file_preview_page.dart';
import 'package:ui/services/agent_runtime_service.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/widgets/omni_glass.dart';
import 'package:ui/widgets/omni_menu.dart';
import 'package:ui/utils/ui.dart';

class _RemoteWorkspaceBreadcrumbSegment {
  const _RemoteWorkspaceBreadcrumbSegment({
    required this.label,
    required this.path,
    required this.isCurrent,
  });

  final String label;
  final String path;
  final bool isCurrent;
}

enum _RemoteWorkspaceEntryAction { open, edit, rename, delete, copyPath }

class CodexRemoteWorkspaceBrowser extends StatefulWidget {
  const CodexRemoteWorkspaceBrowser({
    super.key,
    required this.workspacePath,
    this.agentId = 'codex-remote',
    this.allowFileMutations = true,
    this.remoteBridgeUrl = '',
    this.remoteBridgeToken = '',
    this.enableSystemBackHandler = true,
    this.translucentSurfaces = false,
    this.onCanGoUpChanged,
    this.showBreadcrumbHeader = true,
    this.showHeaderTitle = false,
  });

  final String workspacePath;
  final String agentId;
  final bool allowFileMutations;
  final String remoteBridgeUrl;
  final String remoteBridgeToken;
  final bool enableSystemBackHandler;
  final bool translucentSurfaces;
  final ValueChanged<bool>? onCanGoUpChanged;
  final bool showBreadcrumbHeader;
  final bool showHeaderTitle;

  @override
  State<CodexRemoteWorkspaceBrowser> createState() =>
      CodexRemoteWorkspaceBrowserState();
}

class CodexRemoteWorkspaceBrowserState
    extends State<CodexRemoteWorkspaceBrowser> {
  static const double _itemHeight = 48;
  static const double _itemCornerRadius = 10;

  CodexRemoteDirectoryList? _listing;
  List<CodexRemoteDirectoryEntry> _entries = const [];
  String _rootPath = '';
  String _currentPath = '';
  bool _isLoading = true;
  bool _isReloading = false;
  String? _error;
  int _requestSerial = 0;

  bool get _isEnglish => Localizations.localeOf(context).languageCode == 'en';

  bool get canGoUp {
    final root = _normalizePath(_rootPath);
    final current = _normalizePath(_currentPath);
    return root.isNotEmpty && current.isNotEmpty && current != root;
  }

  Color _surfaceColor() => context.omniPalette.surfacePrimary;

  @override
  void initState() {
    super.initState();
    _rootPath = _normalizePath(widget.workspacePath.trim());
    _currentPath = _rootPath;
    _notifyCanGoUpChanged();
    unawaited(_loadDirectory(_currentPath));
  }

  @override
  void didUpdateWidget(covariant CodexRemoteWorkspaceBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspacePath == widget.workspacePath &&
        oldWidget.agentId == widget.agentId &&
        oldWidget.remoteBridgeUrl == widget.remoteBridgeUrl &&
        oldWidget.remoteBridgeToken == widget.remoteBridgeToken) {
      return;
    }
    _rootPath = _normalizePath(widget.workspacePath.trim());
    _currentPath = _rootPath;
    _entries = const [];
    _listing = null;
    _error = null;
    _notifyCanGoUpChanged();
    unawaited(_loadDirectory(_currentPath));
  }

  void _notifyCanGoUpChanged() {
    final callback = widget.onCanGoUpChanged;
    if (callback == null) return;
    final value = canGoUp;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      callback(value);
    });
  }

  Future<void> _loadDirectory(String path, {bool silent = false}) async {
    if (!mounted) return;
    final requestId = ++_requestSerial;
    setState(() {
      if (silent) {
        _isReloading = true;
      } else {
        _isLoading = true;
      }
      _error = null;
    });
    try {
      final listing = await AgentRuntimeService.listRemoteDirectories(
        agentId: widget.agentId,
        workspaceOwner: _listing?.workspaceOwner,
        remoteBridgeUrl: widget.remoteBridgeUrl,
        remoteBridgeToken: widget.remoteBridgeToken,
        remoteCwd: _rootPath,
        path: path.trim().isEmpty ? null : path,
      );
      if (!mounted || requestId != _requestSerial) return;
      final resolvedPath = _normalizePath(
        listing.path.isNotEmpty ? listing.path : path,
      );
      final requestedPath = _normalizePath(path);
      final resolvedRoot = _rootPath.isEmpty
          ? _normalizePath(
              (listing.cwd?.trim().isNotEmpty == true
                      ? listing.cwd
                      : resolvedPath) ??
                  resolvedPath,
            )
          : (requestedPath.isEmpty || requestedPath == _rootPath)
          ? (resolvedPath.isNotEmpty ? resolvedPath : _rootPath)
          : _rootPath;
      setState(() {
        _listing = listing;
        _rootPath = resolvedRoot;
        _currentPath = resolvedPath.isNotEmpty ? resolvedPath : resolvedRoot;
        _entries = listing.ok ? listing.entries : const [];
        _isLoading = false;
        _isReloading = false;
        _error = listing.ok
            ? null
            : (listing.error ??
                  'تعذّرت قراءة مساحة العمل البعيدة');
      });
      _notifyCanGoUpChanged();
    } catch (error) {
      if (!mounted || requestId != _requestSerial) return;
      setState(() {
        _isLoading = false;
        _isReloading = false;
        _error = error.toString();
      });
      _notifyCanGoUpChanged();
    }
  }

  Future<void> _reload() {
    return _loadDirectory(_currentPath, silent: true);
  }

  void openParentDirectory() {
    if (!canGoUp) return;
    final parent = _parentPath(_currentPath);
    if (parent == null || !_isInsideWorkspace(parent)) return;
    unawaited(_loadDirectory(parent));
  }

  void _openDirectory(CodexRemoteDirectoryEntry entry) {
    if (!entry.isDirectory) return;
    final path = _normalizePath(entry.path);
    if (!_isInsideWorkspace(path)) return;
    unawaited(_loadDirectory(path));
  }

  Future<void> _copyRemotePath(CodexRemoteDirectoryEntry entry) async {
    await Clipboard.setData(ClipboardData(text: entry.path));
    if (!mounted) return;
    showToast(
      'تم نسخ المسار البعيد',
      type: ToastType.success,
    );
  }

  Future<void> _openFileEntry(
    CodexRemoteDirectoryEntry entry, {
    bool startInEditMode = false,
  }) async {
    final workspaceOwner = _listing?.workspaceOwner;
    await Navigator.of(context).push(
      OmniPageRoute<void>(
        builder: (_) => CodexRemoteFilePreviewPage(
          agentId: widget.agentId,
          workspaceOwner: workspaceOwner,
          path: entry.path,
          title: entry.name,
          remoteBridgeUrl: widget.remoteBridgeUrl,
          remoteBridgeToken: widget.remoteBridgeToken,
          remoteCwd: _rootPath,
          startInEditMode: startInEditMode,
        ),
      ),
    );
    if (mounted) {
      unawaited(_reload());
    }
  }

  Future<void> _showEntryActionSheet(CodexRemoteDirectoryEntry entry) async {
    final listingRevision = _requestSerial;
    final palette = context.omniPalette;
    final isDirectory = entry.isDirectory;
    final action =
        await showOmniGlassModalBottomSheet<_RemoteWorkspaceEntryAction>(
          context: context,
          backgroundColor: _surfaceColor(),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          builder: (sheetContext) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: OmniMenuStyle.panelPadding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: palette.borderStrong,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                          fontFamily: 'PingFang SC',
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!isDirectory) ...[
                        _buildActionTile(
                          context: sheetContext,
                          icon: Icons.visibility_outlined,
                          label: 'فتح',
                          action: _RemoteWorkspaceEntryAction.open,
                        ),
                        _buildActionTile(
                          context: sheetContext,
                          icon: Icons.edit_outlined,
                          label: 'تحرير',
                          action: _RemoteWorkspaceEntryAction.edit,
                        ),
                      ],
                      if (widget.allowFileMutations &&
                          !(widget.agentId == 'na-cloud' && isDirectory))
                        _buildActionTile(
                          context: sheetContext,
                          icon: Icons.drive_file_rename_outline_rounded,
                          label: 'إعادة التسمية',
                          action: _RemoteWorkspaceEntryAction.rename,
                        ),
                      _buildActionTile(
                        context: sheetContext,
                        icon: Icons.copy_rounded,
                        label: 'نسخ المسار',
                        action: _RemoteWorkspaceEntryAction.copyPath,
                      ),
                      if (widget.allowFileMutations &&
                          !(widget.agentId == 'na-cloud' && isDirectory))
                        _buildActionTile(
                          context: sheetContext,
                          icon: Icons.delete_outline_rounded,
                          label: 'حذف',
                          action: _RemoteWorkspaceEntryAction.delete,
                          destructive: true,
                        ),
                      OmniMenuItem(
                        onTap: () => Navigator.of(sheetContext).pop(),
                        label: 'إلغاء',
                        leading: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
    if (!mounted || action == null || listingRevision != _requestSerial) return;
    switch (action) {
      case _RemoteWorkspaceEntryAction.open:
        await _openFileEntry(entry);
      case _RemoteWorkspaceEntryAction.edit:
        await _openFileEntry(entry, startInEditMode: true);
      case _RemoteWorkspaceEntryAction.rename:
        await _promptRenameEntry(entry);
      case _RemoteWorkspaceEntryAction.delete:
        await _confirmAndDeleteEntry(entry);
      case _RemoteWorkspaceEntryAction.copyPath:
        await _copyRemotePath(entry);
    }
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required _RemoteWorkspaceEntryAction action,
    bool destructive = false,
  }) {
    return OmniMenuItem(
      onTap: () => Navigator.of(context).pop(action),
      label: label,
      leading: Icon(icon),
      destructive: destructive,
    );
  }

  Future<void> _promptRenameEntry(CodexRemoteDirectoryEntry entry) async {
    final workspaceOwner = _listing?.workspaceOwner;
    final oldName = entry.name;
    final nextName = (await AppDialog.input(
      context,
      title: entry.isDirectory
          ? 'إعادة تسمية المجلد'
          : 'إعادة تسمية الملف',
      hintText: 'اسم جديد',
      initialValue: oldName,
      confirmText: 'حفظ',
      cancelText: 'إلغاء',
    ))?.trim();
    if (!mounted || nextName == null) return;
    final validationError = _validateEntryName(nextName);
    if (validationError != null) {
      showToast(validationError, type: ToastType.warning);
      return;
    }
    if (nextName == oldName) {
      showToast'الاسم لم يتغيّر';
      return;
    }
    final parentPath = _parentPath(entry.path);
    if (parentPath == null) {
      showToast(
        'فشلت إعادة التسمية: مسار غير صالح',
        type: ToastType.error,
      );
      return;
    }
    final destinationPath = '$parentPath/$nextName';
    try {
      final result = await AgentRuntimeService.moveRemotePath(
        agentId: widget.agentId,
        workspaceOwner: workspaceOwner,
        remoteBridgeUrl: widget.remoteBridgeUrl,
        remoteBridgeToken: widget.remoteBridgeToken,
        remoteCwd: _rootPath,
        path: entry.path,
        destinationPath: destinationPath,
      );
      if (result['ok'] != true) {
        throw StateError(result['error']?.toString() ?? 'rename failed');
      }
      showToast('تمت إعادة التسمية', type: ToastType.success);
      await _reload();
    } catch (error) {
      if (!mounted) return;
      showToast(
        'فشلت إعادة التسمية: $error',
        type: ToastType.error,
      );
    }
  }

  Future<void> _confirmAndDeleteEntry(CodexRemoteDirectoryEntry entry) async {
    final workspaceOwner = _listing?.workspaceOwner;
    final confirmed = await AppDialog.confirm(
      context,
      title: entry.isDirectory
          ? 'حذف المجلد'
          : 'حذف الملف',
      content: 'حذف "${entry.name}" من ${widget.agentId == 'na-cloud' ? 'التخزين السحابي' : 'الكمبيوتر البعيد'}؟ لا يمكن التراجع عن هذا الإجراء.',
      cancelText: 'إلغاء',
      confirmText: 'حذف',
      confirmButtonColor: const Color(0xFFE53935),
    );
    if (!mounted || confirmed != true) return;
    try {
      final result = await AgentRuntimeService.deleteRemotePath(
        agentId: widget.agentId,
        workspaceOwner: workspaceOwner,
        remoteBridgeUrl: widget.remoteBridgeUrl,
        remoteBridgeToken: widget.remoteBridgeToken,
        remoteCwd: _rootPath,
        path: entry.path,
        recursive: entry.isDirectory,
      );
      if (result['ok'] != true) {
        throw StateError(result['error']?.toString() ?? 'delete failed');
      }
      showToast(
        entry.isDirectory
            ? 'تم حذف المجلد'
            : 'تم حذف الملف',
        type: ToastType.success,
      );
      await _reload();
    } catch (error) {
      if (!mounted) return;
      showToast(
        'فشل الحذف: $error',
        type: ToastType.error,
      );
    }
  }

  String? _validateEntryName(String name) {
    if (name.trim().isEmpty) return 'الاسم مطلوب';
    if (name == '.' || name == '..') {
      return 'لا يمكن أن يكون الاسم . أو ..';
    }
    if (name.contains('/')) {
      return 'لا يمكن أن يحتوي الاسم على /';
    }
    if (name.contains('\\')) {
      return 'لا يمكن أن يحتوي الاسم على "\\"';
    }
    if (name.contains('\u0000')) {
      return 'يحتوي الاسم على أحرف غير صالحة';
    }
    return null;
  }

  String get _rootBreadcrumbLabel {
    final root = _normalizePath(_rootPath);
    if (root.isEmpty) {
      return 'مساحة العمل البعيدة';
    }
    return _entryNameFromPath(root).isEmpty ? root : _entryNameFromPath(root);
  }

  List<_RemoteWorkspaceBreadcrumbSegment> get _breadcrumbs {
    final root = _normalizePath(_rootPath);
    final current = _normalizePath(_currentPath);
    if (root.isEmpty || current.isEmpty) {
      return const <_RemoteWorkspaceBreadcrumbSegment>[];
    }
    if (!_isInsideWorkspace(current)) {
      return <_RemoteWorkspaceBreadcrumbSegment>[
        _RemoteWorkspaceBreadcrumbSegment(
          label: current,
          path: current,
          isCurrent: true,
        ),
      ];
    }

    final segments = <_RemoteWorkspaceBreadcrumbSegment>[
      _RemoteWorkspaceBreadcrumbSegment(
        label: _rootBreadcrumbLabel,
        path: root,
        isCurrent: current == root,
      ),
    ];
    if (current == root) return segments;

    final relative = current.substring(root.length);
    final parts = relative
        .split(RegExp(r'[/\\]+'))
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
    var runningPath = root;
    for (final part in parts) {
      runningPath = '$runningPath/$part';
      segments.add(
        _RemoteWorkspaceBreadcrumbSegment(
          label: part,
          path: runningPath,
          isCurrent: runningPath == current,
        ),
      );
    }
    return segments;
  }

  Widget _buildBreadcrumbHeader() {
    final palette = context.omniPalette;
    final breadcrumbs = _breadcrumbs;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showHeaderTitle) ...[
            Text(
              'مساحة العمل البعيدة',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              Expanded(
                child: breadcrumbs.isEmpty
                    ? Text(
                        'جارٍ تحميل مساحة العمل البعيدة...',
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textSecondary,
                        ),
                      )
                    : Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 2,
                        runSpacing: 4,
                        children: [
                          for (
                            var index = 0;
                            index < breadcrumbs.length;
                            index++
                          ) ...[
                            if (index > 0)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: palette.textTertiary,
                                ),
                              ),
                            _buildBreadcrumbChip(breadcrumbs[index]),
                          ],
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              OmniCircleButton(
                tooltip: 'إعادة التحميل',
                onPressed: _isLoading || _isReloading
                    ? null
                    : () => unawaited(_reload()),
                icon: Icons.refresh_rounded,
                foregroundColor: palette.textSecondary,
                iconWidget: _isReloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbChip(_RemoteWorkspaceBreadcrumbSegment segment) {
    final palette = context.omniPalette;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: segment.isCurrent
            ? null
            : () => unawaited(_loadDirectory(segment.path)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              segment.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: segment.isCurrent
                    ? FontWeight.w600
                    : FontWeight.w500,
                color: segment.isCurrent
                    ? palette.textPrimary
                    : palette.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntryNode({
    required CodexRemoteDirectoryEntry entry,
    required BorderRadius borderRadius,
  }) {
    final palette = context.omniPalette;
    final isDirectory = entry.isDirectory;
    final typeLabel = switch (entry.type) {
      'directory' => 'مجلد',
      'symlink' => 'رابط رمزي',
      'file' => 'ملف',
      _ => 'عنصر',
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surfaceColor(),
        borderRadius: borderRadius,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: isDirectory
              ? () => _openDirectory(entry)
              : () => unawaited(_openFileEntry(entry)),
          onLongPress: () => unawaited(_showEntryActionSheet(entry)),
          child: SizedBox(
            height: _itemHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    isDirectory
                        ? Icons.folder_outlined
                        : entry.type == 'symlink'
                        ? Icons.link_rounded
                        : Icons.insert_drive_file_outlined,
                    color: isDirectory
                        ? palette.accentPrimary
                        : palette.textPrimary,
                    size: 21,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: palette.textPrimary,
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          typeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.textTertiary,
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isDirectory
                        ? Icons.chevron_right_rounded
                        : Icons.copy_rounded,
                    color: palette.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusList({
    required String message,
    IconData? icon,
    VoidCallback? onRetry,
  }) {
    final palette = context.omniPalette;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: edgeToEdgeScrollPadding(context, EdgeInsets.zero),
      children: [
        SizedBox(
          height: 280,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 28, color: palette.textSecondary),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: Text'إعادة المحاولة',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final exists = _error == null;
    final itemCount = _entries.length;
    final body = RefreshIndicator(
      onRefresh: _reload,
      child: _isLoading && _listing == null
          ? _buildStatusList(
              message: 'جارٍ تحميل مساحة العمل البعيدة...',
            )
          : !exists
          ? _buildStatusList(
              message: _error!,
              icon: Icons.error_outline_rounded,
              onRetry: () => unawaited(_reload()),
            )
          : itemCount == 0
          ? _buildStatusList(
              message: 'الدليل البعيد الحالي فارغ',
              icon: Icons.folder_open_outlined,
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: edgeToEdgeScrollPadding(
                context,
                const EdgeInsets.fromLTRB(16, 12, 16, 16),
              ),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                final isFirst = index == 0;
                final isLast = index == itemCount - 1;
                final borderRadius = BorderRadius.vertical(
                  top: isFirst
                      ? const Radius.circular(_itemCornerRadius)
                      : Radius.zero,
                  bottom: isLast
                      ? const Radius.circular(_itemCornerRadius)
                      : Radius.zero,
                );
                return _buildEntryNode(
                  entry: _entries[index],
                  borderRadius: borderRadius,
                );
              },
            ),
    );

    final content = Column(
      children: [
        if (widget.showBreadcrumbHeader) _buildBreadcrumbHeader(),
        Expanded(child: body),
      ],
    );

    if (!widget.enableSystemBackHandler) {
      return content;
    }
    return PopScope(
      canPop: !canGoUp,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        openParentDirectory();
      },
      child: content,
    );
  }

  String _normalizePath(String path) {
    var normalized = path.trim();
    while (normalized.length > 1 &&
        (normalized.endsWith('/') || normalized.endsWith('\\'))) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  bool _isInsideWorkspace(String path) {
    final normalizedPath = _normalizePath(path);
    final normalizedRoot = _normalizePath(_rootPath);
    if (normalizedRoot.isEmpty || normalizedPath.isEmpty) {
      return false;
    }
    return normalizedPath == normalizedRoot ||
        normalizedPath.startsWith('$normalizedRoot/') ||
        normalizedPath.startsWith('$normalizedRoot\\');
  }

  String _entryNameFromPath(String path) {
    final normalizedPath = _normalizePath(path);
    final parts = normalizedPath
        .split(RegExp(r'[/\\]+'))
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    return parts.isEmpty ? normalizedPath : parts.last;
  }

  String? _parentPath(String path) {
    final normalizedPath = _normalizePath(path);
    final slashIndex = normalizedPath.lastIndexOf(RegExp(r'[/\\]'));
    if (slashIndex <= 0) return null;
    return normalizedPath.substring(0, slashIndex);
  }
}
