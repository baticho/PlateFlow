import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers/meal_plan_refresh_provider.dart';
import '../../../core/providers/shopping_list_count_provider.dart';
import '../../../core/providers/shopping_list_refresh_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../i18n/strings.g.dart';

class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});

  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen> {
  Map<String, dynamic>? _state;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Dio get _dio => ref.read(dioProvider);

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _dio.get('/api/v1/family/');
      if (mounted) setState(() { _state = res.data as Map<String, dynamic>; _loading = false; });
    } on DioException catch (e) {
      if (mounted) setState(() { _error = _detail(e); _loading = false; });
    }
  }

  String _detail(DioException e) {
    final d = e.response?.data;
    if (d is Map && d['detail'] is String) return d['detail'] as String;
    return e.message ?? 'Error';
  }

  /// Run an action that returns the new family state; family changes switch whose
  /// meal plan / shopping list / plan the user sees, so refresh those too.
  Future<void> _run(Future<Response> Function() action) async {
    setState(() => _busy = true);
    try {
      final res = await action();
      if (!mounted) return;
      setState(() => _state = res.data as Map<String, dynamic>);
      ref.invalidate(userProvider);
      ref.read(mealPlanRefreshProvider.notifier).state++;
      ref.read(shoppingListRefreshProvider.notifier).state++;
      await ref.read(shoppingListCountProvider.notifier).refresh();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_detail(e)), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String text, String action) async {
    final t = context.t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.family.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.family.title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: Text(t.common.retry)),
                ]))
              : AbsorbPointer(
                  absorbing: _busy,
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: _state!['family'] == null ? _noFamily(t) : _family(t, _state!['family'] as Map<String, dynamic>),
                  ),
                ),
    );
  }

  Widget _noFamily(Translations t) {
    final cs = Theme.of(context).colorScheme;
    final canCreate = _state!['can_create'] == true;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(t.family.intro, style: TextStyle(fontSize: 15, height: 1.45, color: cs.onSurfaceVariant)),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(t.family.create, style: const TextStyle(fontFamily: 'Lora', fontWeight: FontWeight.w600, fontSize: 18)),
              const SizedBox(height: 12),
              if (canCreate) ...[
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(labelText: t.family.namePlaceholder),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.group_add),
                  label: Text(t.family.create),
                  onPressed: () => _run(() => _dio.post('/api/v1/family/', data: {'name': _nameCtrl.text})),
                ),
              ] else ...[
                Text(t.family.createPremiumOnly, style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.star),
                  label: Text(t.family.upgrade),
                  onPressed: () => context.push('/subscription'),
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(t.family.join, style: const TextStyle(fontFamily: 'Lora', fontWeight: FontWeight.w600, fontSize: 18)),
              const SizedBox(height: 4),
              Text(t.family.joinHint, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              const SizedBox(height: 12),
              TextField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(labelText: t.family.code),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.login),
                label: Text(t.family.joinButton),
                onPressed: () {
                  if (_codeCtrl.text.trim().isEmpty) return;
                  _run(() => _dio.post('/api/v1/family/join', data: {'code': _codeCtrl.text.trim()}));
                },
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _family(Translations t, Map<String, dynamic> f) {
    final cs = Theme.of(context).colorScheme;
    final isOwner = f['is_owner'] == true;
    final members = (f['members'] as List).cast<Map<String, dynamic>>();
    final code = f['invite_code'] as String?;
    final slotsLeft = f['slots_left'] as int? ?? 0;
    final max = _state!['max_members'] ?? 4;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(f['name'] as String? ?? '',
            style: TextStyle(fontFamily: 'Lora', fontSize: 26, fontWeight: FontWeight.w600, color: cs.onSurface, height: 1.2)),
        const SizedBox(height: 8),
        Text(t.family.intro, style: TextStyle(color: cs.onSurfaceVariant)),
        if (isOwner && code != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(t.family.inviteTitle, style: const TextStyle(fontFamily: 'Lora', fontWeight: FontWeight.w600, fontSize: 18)),
                const SizedBox(height: 4),
                Text(t.family.inviteText, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                const SizedBox(height: 12),
                Center(
                  child: SelectableText(
                    code,
                    style: TextStyle(fontFamily: 'Lora', fontSize: 32, letterSpacing: 8, fontWeight: FontWeight.w600, color: cs.onSurface),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(t.family.share),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: t.family.shareMessage(code: code)));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.family.copied)));
                      }
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(t.family.newCode),
                    onPressed: () => _run(() => _dio.post('/api/v1/family/invite-code')),
                  ),
                ]),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Text(t.family.members, style: const TextStyle(fontFamily: 'Lora', fontWeight: FontWeight.w600, fontSize: 18)),
          const Spacer(),
          Text(t.family.slotsLeft(count: slotsLeft, max: max), style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ]),
        const SizedBox(height: 8),
        Card(
          child: Column(children: [
            for (final m in members)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: m['is_owner'] == true ? cs.tertiaryContainer : cs.surfaceContainerHigh,
                  child: Text(
                    ((m['full_name'] as String?) ?? '?').trim().isEmpty ? '?' : ((m['full_name'] as String).trim()[0]).toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontWeight: FontWeight.w600,
                      color: m['is_owner'] == true ? cs.onTertiaryContainer : cs.primary,
                    ),
                  ),
                ),
                title: Text('${m['full_name']}${m['is_me'] == true ? ' (${t.family.you})' : ''}'),
                subtitle: Text(m['is_owner'] == true ? t.family.owner : (m['email'] as String? ?? '')),
                trailing: isOwner && m['is_owner'] != true
                    ? IconButton(
                        tooltip: t.family.remove,
                        icon: Icon(Icons.person_remove, color: Theme.of(context).colorScheme.error),
                        onPressed: () async {
                          if (await _confirm(t.family.removeConfirm(name: m['full_name']), t.family.remove)) {
                            _run(() => _dio.delete('/api/v1/family/members/${m['id']}'));
                          }
                        },
                      )
                    : null,
              ),
            for (var i = 0; i < slotsLeft; i++)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: cs.surfaceContainerLow,
                  child: Icon(Icons.person_add_alt, color: cs.onSurfaceVariant),
                ),
                title: Text('—', style: TextStyle(color: cs.onSurfaceVariant)),
              ),
          ]),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          icon: Icon(isOwner ? Icons.group_off : Icons.logout),
          label: Text(isOwner ? t.family.dissolve : t.family.leave),
          onPressed: () async {
            final ok = await _confirm(isOwner ? t.family.dissolveConfirm : t.family.leaveConfirm,
                isOwner ? t.family.dissolve : t.family.leave);
            if (ok) _run(() => _dio.post('/api/v1/family/leave'));
          },
        ),
      ],
    );
  }
}
