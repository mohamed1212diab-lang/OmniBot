import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ui/widgets/flclash/liquid_glass.dart';
import 'package:ui/widgets/omni_glass.dart';
import 'package:ui/widgets/omni_menu.dart';
import 'package:ui/widgets/settings_ui.dart';
import 'package:ui/widgets/flclash/popup.dart';
import 'package:ui/widgets/glass_popup.dart';
import 'package:flutter/services.dart';
import 'package:ui/features/home/pages/chat/chat_page_models.dart';
import 'package:ui/l10n/l10n.dart';
import 'package:ui/l10n/legacy_text_localizer.dart';
import 'package:ui/services/agent_browser_session_service.dart';

class ChatBrowserOverlay extends StatefulWidget {
  const ChatBrowserOverlay({
    super.key,
    required this.snapshot,
    required this.onSnapshotChanged,
    required this.onClose,
    required this.onDragDelta,
    required this.onResizeLeftDelta,
    required this.onResizeRightDelta,
  });

  final ChatBrowserSessionSnapshot snapshot;
  final ValueChanged<ChatBrowserSessionSnapshot?> onSnapshotChanged;
  final VoidCallback onClose;
  final ValueChanged<Offset> onDragDelta;
  final ValueChanged<Offset> onResizeLeftDelta;
  final ValueChanged<Offset> onResizeRightDelta;

  @override
  State<ChatBrowserOverlay> createState() => _ChatBrowserOverlayState();
}

class _ChatBrowserOverlayState extends State<ChatBrowserOverlay> {
  static const double _actionButtonSize = 32;
  static const double _actionIconSize = 17;
  static const double _addressPillHeight = 36;

  late final TextEditingController _addressController;
  late final FocusNode _addressFocusNode;
  late final TextEditingController _promptController;
  String? _lastPromptRequestId;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(
      text: widget.snapshot.currentUrl,
    );
    _addressFocusNode = FocusNode()..addListener(_handleAddressFocusChanged);
    _promptController = TextEditingController(
      text: widget.snapshot.pendingDialog?.defaultValue ?? '',
    );
    _lastPromptRequestId = widget.snapshot.pendingDialog?.requestId;
  }

  @override
  void didUpdateWidget(covariant ChatBrowserOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_addressFocusNode.hasFocus &&
        _addressController.text != widget.snapshot.currentUrl) {
      _addressController.text = widget.snapshot.currentUrl;
    }
    final nextPromptId = widget.snapshot.pendingDialog?.requestId;
    if (_lastPromptRequestId != nextPromptId) {
      _lastPromptRequestId = nextPromptId;
      _promptController.text =
          widget.snapshot.pendingDialog?.defaultValue ?? '';
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _addressFocusNode.dispose();
    _promptController.dispose();
    super.dispose();
  }

  void _handleAddressFocusChanged() {
    if (_addressFocusNode.hasFocus) {
      _addressController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _addressController.text.length,
      );
    } else if (_addressController.text != widget.snapshot.currentUrl) {
      _addressController.text = widget.snapshot.currentUrl;
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    return Material(
      elevation: LiquidGlassScope.of(context) ? 0 : 18,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: OmniGlassSheet(
        backgroundColor: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Column(
              children: [
                _buildChrome(context, snapshot),
                if (snapshot.hasSslError)
                  _buildBanner(
                    icon: Icons.gpp_bad_rounded,
                    message: 'هذه الصفحة بها خطأ SSL، يُرجى توخي الحذر',
                    color: const Color(0xFFB42318),
                    background: const Color(0xFFFFF1F3),
                  ),
                if (snapshot.riskChallengeDetected)
                  _buildBanner(
                    icon: Icons.front_hand_rounded,
                    message: _riskChallengeMessage(snapshot),
                    color: const Color(0xFF92400E),
                    background: const Color(0xFFFFF7ED),
                  ),
                if (snapshot.externalOpenPrompt != null)
                  _buildExternalPrompt(snapshot.externalOpenPrompt!),
                if (snapshot.permissionPrompt != null)
                  _buildPermissionPrompt(snapshot.permissionPrompt!),
                if (snapshot.pendingDialog != null)
                  _buildDialogPrompt(snapshot.pendingDialog!),
                Expanded(
                  child: ColoredBox(
                    color: const Color(0xFFF4F7FB),
                    child: Platform.isAndroid
                        ? AndroidView(
                            viewType:
                                AgentBrowserSessionService.platformViewType,
                            creationParams: <String, dynamic>{
                              'workspaceId': snapshot.workspaceId,
                            },
                            creationParamsCodec: const StandardMessageCodec(),
                          )
                        : Center(
                            child: Text(
                              context.l10n.browserOverlayUnsupported,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF617390),
                              ),
                            ),
                          ),
                  ),
                ),
                _buildToolbar(snapshot),
              ],
            ),
            Positioned(
              left: 0,
              bottom: 6,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (details) =>
                    widget.onResizeLeftDelta(details.delta),
                child: const SizedBox(width: 32, height: 28),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 6,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (details) =>
                    widget.onResizeRightDelta(details.delta),
                child: const SizedBox(width: 32, height: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChrome(
    BuildContext context,
    ChatBrowserSessionSnapshot snapshot,
  ) {
    final iconColor = snapshot.hasSslError
        ? const Color(0xFFB42318)
        : (snapshot.currentUrl.startsWith('https://')
              ? const Color(0xFF067647)
              : const Color(0xFF617390));
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        gradient: LiquidGlassScope.of(context)
            ? null
            : const LinearGradient(
                colors: [Color(0xFFF8FBFF), Color(0xFFF3F7FD)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
        border: const Border(bottom: BorderSide(color: Color(0xFFE3EBF8))),
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) => widget.onDragDelta(details.delta),
            child: Container(
              width: 24,
              height: _addressPillHeight,
              alignment: Alignment.center,
              child: Container(
                width: 14,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF9BAECC),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _buildAddressPill(context, snapshot, iconColor)),
          const SizedBox(width: 6),
          _compactActionButton(
            onPressed: _handleToggleBookmark,
            tooltip: 'تبديل الإشارة المرجعية',
            icon: Icon(
              snapshot.isBookmarked
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              size: _actionIconSize,
              color: snapshot.isBookmarked
                  ? const Color(0xFFD97706)
                  : const Color(0xFF617390),
            ),
            backgroundColor: snapshot.isBookmarked
                ? const Color(0xFFFFF7ED)
                : Colors.white,
            borderColor: snapshot.isBookmarked
                ? const Color(0xFFF7D6A6)
                : const Color(0xFFD9E5F4),
          ),
          const SizedBox(width: 6),
          _compactActionButton(
            onPressed: snapshot.isLoading ? _handleStopLoading : _handleReload,
            tooltip: snapshot.isLoading
                ? 'إيقاف التحميل'
                : 'إعادة تحميل الصفحة',
            icon: Icon(
              snapshot.isLoading
                  ? Icons.close_rounded
                  : Icons.autorenew_rounded,
              size: _actionIconSize,
              color: const Color(0xFF617390),
            ),
          ),
          const SizedBox(width: 6),
          _compactActionButton(
            onPressed: widget.onClose,
            icon: const Icon(
              Icons.close_rounded,
              size: _actionIconSize,
              color: Color(0xFF9A3E4A),
            ),
            tooltip: context.l10n.browserOverlayClose,
            backgroundColor: const Color(0xFFFFF4F5),
            borderColor: const Color(0xFFF5D4DA),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressPill(
    BuildContext context,
    ChatBrowserSessionSnapshot snapshot,
    Color iconColor,
  ) {
    final isEditing = _addressFocusNode.hasFocus;
    final radius = BorderRadius.circular(999);
    final hintText = snapshot.title.trim().isEmpty
        ? context.l10n.browserOverlayTitle
        : snapshot.title;
    final primaryText = _addressPrimaryText(snapshot, hintText);
    final secondaryText = _addressSecondaryText(snapshot);
    final fieldDecoration = BoxDecoration(
      color: Colors.white,
      borderRadius: radius,
      border: Border.all(
        color: isEditing ? const Color(0xFFB7CAF2) : const Color(0xFFD9E5F4),
      ),
      boxShadow: [
        BoxShadow(
          color: isEditing ? const Color(0x142563EB) : const Color(0x08172B4D),
          blurRadius: isEditing ? 16 : 10,
          offset: const Offset(0, 4),
        ),
      ],
    );

    if (isEditing) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: _addressPillHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: fieldDecoration,
        child: Row(
          children: [
            Icon(
              snapshot.hasSslError
                  ? Icons.gpp_bad_rounded
                  : snapshot.currentUrl.startsWith('https://')
                  ? Icons.lock_rounded
                  : Icons.language_rounded,
              size: 15,
              color: iconColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _addressController,
                focusNode: _addressFocusNode,
                textInputAction: TextInputAction.go,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                onTapOutside: (_) => _addressFocusNode.unfocus(),
                onSubmitted: _handleAddressSubmitted,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF213147),
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: hintText,
                  hintStyle: const TextStyle(
                    color: Color(0xFF93A4BB),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final tooltipText = snapshot.currentUrl.trim().isEmpty
        ? hintText
        : snapshot.currentUrl.trim();

    return Tooltip(
      message: tooltipText,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: _addressFocusNode.requestFocus,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: _addressPillHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: fieldDecoration,
            child: Row(
              children: [
                Icon(
                  snapshot.hasSslError
                      ? Icons.gpp_bad_rounded
                      : snapshot.currentUrl.startsWith('https://')
                      ? Icons.lock_rounded
                      : Icons.language_rounded,
                  size: 15,
                  color: iconColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: primaryText,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF213147),
                          ),
                        ),
                        if (secondaryText.isNotEmpty)
                          TextSpan(
                            text: '   $secondaryText',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF7C8EA7),
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBanner({
    required IconData icon,
    required String message,
    required Color color,
    required Color background,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      color: background,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _riskChallengeMessage(ChatBrowserSessionSnapshot snapshot) {
    switch (snapshot.recommendedNextAction) {
      case 'wait_before_retrying_and_reduce_request_rate':
        return 'تم اكتشاف تجاوز حد الطلبات. تم إيقاف التشغيل التلقائي مؤقتًا؛ يُرجى الانتظار قبل المتابعة.';
      case 'stop_automatic_retry_and_use_manual_access':
        return 'تم رفض الوصول. تم إيقاف التشغيل التلقائي مؤقتًا؛ يُرجى المتابعة يدويًا.';
      default:
        return 'تم اكتشاف طلب تحقق. تم إيقاف التشغيل التلقائي مؤقتًا؛ يُرجى إكماله يدويًا للمتابعة.';
    }
  }

  Widget _buildExternalPrompt(BrowserExternalOpenPrompt prompt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFBEB),
        border: Border(bottom: BorderSide(color: Color(0xFFFDE68A))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'هل تريد فتح الرابط الخارجي؟',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF92400E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            prompt.target,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF7C2D12)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _secondaryActionButton(
                label: 'إلغاء',
                onPressed: () => _runCommand(
                  AgentBrowserSessionService.cancelExternalOpen(
                    prompt.requestId,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _primaryActionButton(
                label: 'فتح',
                onPressed: () => _runCommand(
                  AgentBrowserSessionService.confirmExternalOpen(
                    prompt.requestId,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionPrompt(BrowserPermissionPrompt prompt) {
    final resourceLabel = prompt.resources.isEmpty
        ? prompt.kind
        : prompt.resources.join(', ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F8FF),
        border: Border(bottom: BorderSide(color: Color(0xFFDCE7F5))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الصفحة تطلب إذنًا',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1D4ED8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${prompt.origin}\n$resourceLabel',
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _secondaryActionButton(
                label: 'رفض',
                onPressed: () => _runCommand(
                  AgentBrowserSessionService.denyPermission(prompt.requestId),
                ),
              ),
              const SizedBox(width: 8),
              _primaryActionButton(
                label: 'سماح',
                onPressed: () => _runCommand(
                  AgentBrowserSessionService.grantPermission(prompt.requestId),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDialogPrompt(BrowserDialogPrompt prompt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _dialogTitle(prompt.type),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            prompt.message,
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
          ),
          if (prompt.type == 'prompt') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _promptController,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'أدخل قيمة',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _secondaryActionButton(
                label: 'إلغاء',
                onPressed: () => _runCommand(
                  AgentBrowserSessionService.resolveDialog(
                    requestId: prompt.requestId,
                    accept: false,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _primaryActionButton(
                label: 'موافق',
                onPressed: () => _runCommand(
                  AgentBrowserSessionService.resolveDialog(
                    requestId: prompt.requestId,
                    accept: true,
                    promptValue: prompt.type == 'prompt'
                        ? _promptController.text
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(ChatBrowserSessionSnapshot snapshot) {
    return Container(
      height: 44,
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 7),
      decoration: BoxDecoration(
        color: LiquidGlassScope.of(context) ? null : const Color(0xFFF7F9FC),
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          _toolbarButton(
            icon: Icons.arrow_back_ios_new_rounded,
            enabled: snapshot.canGoBack,
            tooltip: 'رجوع',
            onPressed: () => _runCommand(AgentBrowserSessionService.goBack()),
          ),
          const SizedBox(width: 6),
          _toolbarButton(
            icon: Icons.arrow_forward_ios_rounded,
            enabled: snapshot.canGoForward,
            tooltip: 'تقدّم',
            onPressed: () =>
                _runCommand(AgentBrowserSessionService.goForward()),
          ),
          const SizedBox(width: 6),
          _toolbarButton(
            icon: Icons.add_rounded,
            tooltip: 'علامة تبويب جديدة',
            onPressed: () => _runCommand(AgentBrowserSessionService.newTab()),
          ),
          Expanded(
            child: Center(
              child: FlClashPopupSource(
                glass: false,
                color: Colors.white,
                shape: const StadiumBorder(),
                builder: (anchorContext) => InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => _showTabsMenu(anchorContext),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFD9E5F4)),
                      color: Colors.white,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.layers_outlined,
                          size: 16,
                          color: Color(0xFF42526B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.snapshot.tabs.length}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF213147),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          FlClashPopupSource(
            glass: false,
            color: Colors.white,
            shape: const CircleBorder(),
            builder: (anchorContext) => _toolbarButton(
              icon: Icons.more_horiz_rounded,
              tooltip: 'القائمة',
              onPressed: () => _showMenu(anchorContext),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbarButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
    bool enabled = true,
  }) {
    return _compactActionButton(
      onPressed: enabled ? onPressed : null,
      tooltip: tooltip,
      icon: Icon(icon, size: _actionIconSize, color: const Color(0xFF42526B)),
    );
  }

  Widget _compactActionButton({
    required Widget icon,
    VoidCallback? onPressed,
    String? tooltip,
    Color backgroundColor = Colors.white,
    Color borderColor = const Color(0xFFD9E5F4),
  }) {
    final enabled = onPressed != null;
    Widget child = AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.48,
      child: Material(
        color: enabled ? backgroundColor : const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Ink(
            width: _actionButtonSize,
            height: _actionButtonSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: enabled ? borderColor : const Color(0xFFE3EAF4),
              ),
            ),
            child: Center(child: icon),
          ),
        ),
      ),
    );
    if (tooltip != null) {
      child = Tooltip(message: tooltip, child: child);
    }
    return child;
  }

  Widget _secondaryActionButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return TextButton(onPressed: onPressed, child: Text(label));
  }

  Widget _primaryActionButton({
    required String label,
    VoidCallback? onPressed,
  }) {
    return FilledButton(onPressed: onPressed, child: Text(label));
  }

  String _dialogTitle(String type) {
    switch (type) {
      case 'alert':
        return 'تنبيه الصفحة';
      case 'confirm':
        return 'تأكيد الصفحة';
      case 'prompt':
        return 'إدخال الصفحة';
      default:
        return 'حوار الصفحة';
    }
  }

  String _addressPrimaryText(
    ChatBrowserSessionSnapshot snapshot,
    String fallback,
  ) {
    final url = snapshot.currentUrl.trim();
    if (url.isEmpty) {
      return fallback;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return url;
    }
    final host = uri.host.trim();
    if (host.isNotEmpty) {
      final normalizedHost = host.startsWith('www.') ? host.substring(4) : host;
      return uri.hasPort ? '$normalizedHost:${uri.port}' : normalizedHost;
    }
    if (uri.scheme.trim().isNotEmpty) {
      return '${uri.scheme.toLowerCase()}://';
    }
    return url;
  }

  String _addressSecondaryText(ChatBrowserSessionSnapshot snapshot) {
    final url = snapshot.currentUrl.trim();
    if (url.isEmpty) {
      return '';
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return '';
    }
    final buffer = StringBuffer();
    final path = uri.path.trim();
    if (path.isNotEmpty && path != '/') {
      buffer.write(path);
    }
    if (uri.hasQuery) {
      buffer.write('?${uri.query}');
    }
    if (uri.hasFragment) {
      buffer.write('#${uri.fragment}');
    }
    return buffer.toString();
  }

  Future<void> _handleAddressSubmitted(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await _runCommand(AgentBrowserSessionService.navigate(trimmed));
    _addressFocusNode.unfocus();
  }

  Future<void> _handleToggleBookmark() {
    return _runCommand(AgentBrowserSessionService.toggleBookmark());
  }

  Future<void> _handleReload() {
    return _runCommand(AgentBrowserSessionService.reload());
  }

  Future<void> _handleStopLoading() {
    return _runCommand(AgentBrowserSessionService.stopLoading());
  }

  Future<void> _runCommand(
    Future<ChatBrowserSessionSnapshot?> future, {
    bool showErrors = true,
  }) async {
    try {
      final next = await future;
      if (!mounted) {
        return;
      }
      if (next != null) {
        widget.onSnapshotChanged(next);
      }
    } on PlatformException catch (error) {
      if (!mounted || !showErrors) {
        return;
      }
      _showSnack(error.message ?? error.code);
    } catch (error) {
      if (!mounted || !showErrors) {
        return;
      }
      _showSnack(error.toString());
    }
  }

  Future<void> _showTabsMenu(BuildContext anchorContext) async {
    final snapshot = widget.snapshot;
    final anchor = glassPopupAnchorFromContext(anchorContext);
    if (anchor == null) return;
    final action = await showGlassPopup<(String, int?)>(
      context: context,
      sourceContext: anchorContext,
      anchor: anchor,
      preferBelow: false,
      child: Builder(
        builder: (popupContext) => OmniMenuSurface(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              for (final tab in snapshot.tabs)
                OmniMenuItem(
                  selected: tab.isActive,
                  leading: Icon(
                    tab.isActive
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                  ),
                  label: tab.title.trim().isEmpty ? tab.url : tab.title,
                  subtitle: tab.url,
                  trailing: IconButton(
                    tooltip: 'إغلاق علامة التبويب',
                    onPressed: () =>
                        Navigator.of(popupContext).pop(('close', tab.tabId)),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  onTap: () =>
                      Navigator.of(popupContext).pop(('select', tab.tabId)),
                ),
              OmniMenuItem(
                leading: const Icon(Icons.add_rounded),
                label: 'علامة تبويب جديدة',
                onTap: () => Navigator.of(popupContext).pop(('new', null)),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action.$1) {
      case 'close':
        await _runCommand(AgentBrowserSessionService.closeTab(action.$2!));
      case 'select':
        await _runCommand(AgentBrowserSessionService.selectTab(action.$2!));
      case 'new':
        await _runCommand(AgentBrowserSessionService.newTab());
    }
  }

  Future<void> _showMenu(BuildContext anchorContext) async {
    final snapshot = widget.snapshot;
    final anchor = glassPopupAnchorFromContext(anchorContext);
    if (anchor == null) return;
    final actions = [
      ('history', Icons.history_rounded, 'السجل'),
      ('bookmarks', Icons.bookmarks_rounded, 'الإشارات المرجعية'),
      ('downloads', Icons.download_rounded, 'التنزيلات'),
      ('userscript', Icons.code_rounded, 'Userscript'),
      (
        'desktop',
        snapshot.isDesktopMode
            ? Icons.smartphone_rounded
            : Icons.desktop_windows_rounded,
        snapshot.isDesktopMode
            ? 'التبديل إلى وضع الجوال'
            : 'التبديل إلى وضع سطح المكتب',
      ),
      ('close', Icons.close_rounded, 'إغلاق علامة التبويب الحالية'),
      (
        'closeAll',
        Icons.tab_unselected_rounded,
        'إغلاق جميع علامات التبويب',
      ),
    ];
    final action = await showOmniMenu<String>(
      context: context,
      sourceContext: anchorContext,
      anchor: anchor,
      preferBelow: false,
      width: 300,
      items: [
        for (final (value, icon, label) in actions)
          OmniPopupMenuItem(
            value: value,
            child: Row(
              children: [
                Icon(icon),
                const SizedBox(width: OmniMenuStyle.iconGap),
                Expanded(child: Text(label)),
              ],
            ),
          ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'history':
        await _showHistorySheet();
      case 'bookmarks':
        await _showBookmarksSheet();
      case 'downloads':
        await _showDownloadsSheet();
      case 'userscript':
        await _showUserscriptSheet();
      case 'desktop':
        await _runCommand(AgentBrowserSessionService.toggleDesktopMode());
      case 'close':
        final activeTabId = snapshot.activeTabId;
        if (activeTabId != null) {
          await _runCommand(AgentBrowserSessionService.closeTab(activeTabId));
        }
      case 'closeAll':
        await _runCommand(
          AgentBrowserSessionService.closeAllTabs(
            snapshot.tabs.map((tab) => tab.tabId).toList(),
          ),
        );
    }
  }

  Future<void> _showHistorySheet() async {
    final entries = widget.snapshot.history;
    await showOmniGlassModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                'السجل',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (entries.isEmpty)
                _emptyState('لا يوجد سجل بعد'),
              ...entries.map((entry) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    entry.title.trim().isEmpty ? entry.url : entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    entry.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _runCommand(
                      AgentBrowserSessionService.openHistoryEntry(entry.url),
                    );
                  },
                );
              }),
              if (entries.isNotEmpty) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _runCommand(
                      AgentBrowserSessionService.clearHistory(),
                    );
                  },
                  child: Text('مسح السجل'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _showBookmarksSheet() async {
    final entries = widget.snapshot.bookmarks;
    await showOmniGlassModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                'الإشارات المرجعية',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (entries.isEmpty)
                _emptyState('لا توجد إشارات مرجعية بعد'),
              ...entries.map((entry) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    entry.title.trim().isEmpty ? entry.url : entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    entry.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _runCommand(
                        AgentBrowserSessionService.removeBookmark(entry.url),
                      );
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _runCommand(
                      AgentBrowserSessionService.navigate(entry.url),
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDownloadsSheet() async {
    final snapshot = widget.snapshot;
    await showOmniGlassModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                'التنزيلات',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'جارٍ ${snapshot.downloadSummary.activeCount} · فشل ${snapshot.downloadSummary.failedCount}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (snapshot.downloads.isEmpty)
                _emptyState('لا توجد مهام تنزيل بعد'),
              ...snapshot.downloads.map(
                (item) => _buildDownloadCard(context, item),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDownloadCard(BuildContext context, BrowserDownloadItem item) {
    final progress = item.progress;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: LiquidGlassScope.of(context)
          ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.24)
          : null,
      elevation: LiquidGlassScope.of(context) ? 0 : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              item.status,
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
            if (progress != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
            ],
            if ((item.errorMessage ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.errorMessage!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFB42318)),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item.canPause)
                  _actionChip(
                    label: 'إيقاف مؤقت',
                    onPressed: () => _runCommand(
                      AgentBrowserSessionService.pauseDownload(item.id),
                    ),
                  ),
                if (item.canResume)
                  _actionChip(
                    label: 'استئناف',
                    onPressed: () => _runCommand(
                      AgentBrowserSessionService.resumeDownload(item.id),
                    ),
                  ),
                if (item.canCancel)
                  _actionChip(
                    label: 'إلغاء',
                    onPressed: () => _runCommand(
                      AgentBrowserSessionService.cancelDownload(item.id),
                    ),
                  ),
                if (item.canRetry)
                  _actionChip(
                    label: 'إعادة المحاولة',
                    onPressed: () => _runCommand(
                      AgentBrowserSessionService.retryDownload(item.id),
                    ),
                  ),
                if (item.canOpenFile)
                  _actionChip(
                    label: 'فتح الملف',
                    onPressed: () => _runCommand(
                      AgentBrowserSessionService.openDownloadedFile(item.id),
                    ),
                  ),
                if (item.canOpenLocation)
                  _actionChip(
                    label: 'فتح المجلد',
                    onPressed: () => _runCommand(
                      AgentBrowserSessionService.openDownloadLocation(item.id),
                    ),
                  ),
                _actionChip(
                  label: 'حذف',
                  onPressed: () => _runCommand(
                    AgentBrowserSessionService.deleteDownload(
                      item.id,
                      deleteFile: item.canDeleteFile,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionChip({required String label, required VoidCallback onPressed}) {
    return ActionChip(label: Text(label), onPressed: onPressed);
  }

  Future<void> _showUserscriptSheet() async {
    final snapshot = widget.snapshot;
    final pendingInstall = snapshot.userscriptSummary.pendingInstall;
    await showOmniGlassModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                'Userscript',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (pendingInstall != null)
                _buildPendingUserscriptCard(pendingInstall),
              if (snapshot
                  .userscriptSummary
                  .currentPageMenuCommands
                  .isNotEmpty) ...[
                Text(
                  'قائمة الصفحة الحالية',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ...snapshot.userscriptSummary.currentPageMenuCommands.map((
                  command,
                ) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_circle_outline_rounded),
                    title: Text(command.title),
                    onTap: () => _runCommand(
                      AgentBrowserSessionService.invokeUserscriptMenuCommand(
                        command.commandId,
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],
              Text(
                'النصوص المثبّتة',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (snapshot.userscriptSummary.installedScripts.isEmpty)
                _emptyState('لا توجد نصوص مثبّتة'),
              ...snapshot.userscriptSummary.installedScripts.map(
                _buildUserscriptTile,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _handleInstallUserscriptFromUrl,
                icon: const Icon(Icons.link_rounded),
                label: Text('التثبيت من رابط'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await _runCommand(
                    AgentBrowserSessionService.importUserscriptFile(),
                  );
                },
                icon: const Icon(Icons.file_upload_outlined),
                label: Text('استيراد ملف .user.js محلي'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingUserscriptCard(BrowserUserscriptInstallPreview pending) {
    final blocked = pending.blockedGrants;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: LiquidGlassScope.of(context)
          ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.24)
          : const Color(0xFFF8FAFC),
      elevation: LiquidGlassScope.of(context) ? 0 : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pending.isUpdate
                  ? 'تحديث نص معلّق'
                  : 'تثبيت نص معلّق',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text('${pending.name} · ${pending.version}'),
            if (blocked.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'الأذونات غير المدعومة: ${blocked.join(', ')}',
                style: const TextStyle(fontSize: 12, color: Color(0xFFB42318)),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _secondaryActionButton(
                  label: 'إلغاء',
                  onPressed: () => _runCommand(
                    AgentBrowserSessionService.cancelUserscriptInstall(),
                  ),
                ),
                const SizedBox(width: 8),
                _primaryActionButton(
                  label: 'تأكيد',
                  onPressed: blocked.isNotEmpty
                      ? null
                      : () => _runCommand(
                          AgentBrowserSessionService.confirmUserscriptInstall(),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserscriptTile(BrowserUserscriptItem script) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: OmniSettingsSwitch(
        value: script.enabled,
        onToggle: (value) => _runCommand(
          AgentBrowserSessionService.setUserscriptEnabled(script.id, value),
        ),
      ),
      title: Text(script.name),
      subtitle: Text(
        [
          if (script.version.trim().isNotEmpty) script.version,
          if ((script.sourceUrl ?? '').trim().isNotEmpty) script.sourceUrl!,
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _runCommand(
              AgentBrowserSessionService.checkUserscriptUpdate(script.id),
            ),
            icon: const Icon(Icons.system_update_alt_rounded),
            tooltip: 'التحقق من وجود تحديث',
          ),
          IconButton(
            onPressed: () => _runCommand(
              AgentBrowserSessionService.deleteUserscript(script.id),
            ),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'حذف',
          ),
        ],
      ),
    );
  }

  Future<void> _handleInstallUserscriptFromUrl() async {
    final controller = TextEditingController();
    final result = await showOmniGlassCardSheet<String>(
      context: context,
      builder: (context) {
        return OmniGlassAlertDialog(
          title: Text('تثبيت نص من رابط'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'https://example.com/script.user.js',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: Text('تثبيت'),
            ),
          ],
        );
      },
    );
    if (result == null || result.isEmpty) {
      return;
    }
    await _runCommand(
      AgentBrowserSessionService.installUserscriptFromUrl(result),
    );
  }

  Widget _emptyState(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
