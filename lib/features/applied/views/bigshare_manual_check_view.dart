import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../data/models/ipo.dart';

class BigshareManualCheckView extends StatefulWidget {
  const BigshareManualCheckView({
    super.key,
    required this.ipo,
    required this.profileName,
  });

  final Ipo ipo;
  final String profileName;

  @override
  State<BigshareManualCheckView> createState() =>
      _BigshareManualCheckViewState();
}

class _BigshareManualCheckViewState extends State<BigshareManualCheckView> {
  static final Uri _bigshareUri =
      Uri.parse('https://ipo.bigshareonline.com/ipo_status.html');

  late final WebViewController _controller;
  int _progress = 0;
  String? _mainFrameError;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _progress = progress);
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() => _mainFrameError = null);
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _progress = 100);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame != true || !mounted) return;
            setState(() {
              _mainFrameError =
                  'Bigshare could not be loaded. Please check your connection and try again.';
            });
          },
          onSslAuthError: (error) {
            unawaited(error.cancel());
            if (!mounted) return;
            setState(() {
              _mainFrameError =
                  'Bigshare could not be opened securely on this device.';
            });
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;

            if (uri.scheme == 'about' || uri.scheme == 'data') {
              return NavigationDecision.navigate;
            }

            final isHttpsBigshare = uri.scheme == 'https' &&
                (uri.host == 'bigshareonline.com' ||
                    uri.host.endsWith('.bigshareonline.com'));

            return isHttpsBigshare
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(_bigshareUri);
  }

  Future<void> _reload() async {
    if (_mainFrameError != null) {
      setState(() {
        _mainFrameError = null;
        _progress = 0;
      });
      await _controller.loadRequest(_bigshareUri);
      return;
    }

    await _controller.reload();
  }

  Future<void> _goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: const Text('Bigshare allotment'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress / 100),
              )
            : null,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.55),
              border: Border(
                bottom: BorderSide(color: theme.dividerColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.ipo.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Manual check for ${widget.profileName}. Complete the check on Bigshare below.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _mainFrameError == null
                ? WebViewWidget(controller: _controller)
                : _LoadError(
                    message: _mainFrameError!,
                    onRetry: _reload,
                  ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.public_off_rounded,
              size: 42,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => unawaited(onRetry()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
