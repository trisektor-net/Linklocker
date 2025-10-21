// =============================================================================
// LINKLOCKER 4.0 – FINAL LINK EDITOR SCREEN
// RFP Compliance: §3.2.1 (User Dashboard), §3.2.2 (Lead Capture),
// §3.2.7 (Data Resilience), §3.2.9 (Accessibility)
// =============================================================================
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

final _sb = Supabase.instance.client;

class LinkEditorScreen extends StatefulWidget {
  const LinkEditorScreen({super.key});
  @override
  State<LinkEditorScreen> createState() => _LinkEditorScreenState();
}

class _LinkEditorScreenState extends State<LinkEditorScreen> {
  final List<Map<String, dynamic>> _links = [];
  bool _loading = true;
  bool _busy = false;
  String? _username;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = _sb.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      return;
    }
    await _ensureProfile(user.id, user.email);
    await _loadLinks();
  }

  Future<void> _ensureProfile(String uid, String? email) async {
    final prof =
        await _sb.from('profiles').select('username').eq('id', uid).maybeSingle();
    if (prof != null) {
      setState(() => _username = prof['username'] as String?);
      return;
    }
    final base = (email ?? 'user')
        .split('@')
        .first
        .replaceAll(RegExp('[^a-zA-Z0-9_]'), '_')
        .replaceAll(RegExp('_+'), '_')
        .replaceAll(RegExp('^_+|_+\$'), '');
    final suffix = Random().nextInt(9000) + 1000;
    final uname = '${base.isEmpty ? "user" : base}_$suffix';
    await _sb.from('profiles').upsert({
      'id': uid,
      'username': uname,
      'full_name': base.isEmpty ? 'User' : base,
      'locale': 'en',
      'is_public': true,
      'plan': 'free',
    });
    setState(() => _username = uname);
  }

  Future<void> _loadLinks() async {
    setState(() => _loading = true);
    final uid = _sb.auth.currentUser!.id;
    final data = await _sb
        .from('links')
        .select('id, title, url, icon, position, lead_capture, enabled')
        .eq('user_id', uid)
        .order('position', ascending: true);
    _links
      ..clear()
      ..addAll((data as List).cast<Map<String, dynamic>>());
    setState(() => _loading = false);
  }

  String _normalizeUrl(String raw) {
    var u = raw.trim();
    if (u.isEmpty) return u;
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'https://$u';
    return u;
  }

  bool _isValidUrl(String v) {
    final u = _normalizeUrl(v);
    final uri = Uri.tryParse(u);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color),
      );
  }

  Future<void> _addOrEdit({Map<String, dynamic>? existing}) async {
    if (_busy) return;
    final formKey = GlobalKey<FormState>();
    final titleCtl = TextEditingController(text: existing?['title'] ?? '');
    final urlCtl = TextEditingController(text: existing?['url'] ?? '');
    final iconCtl = TextEditingController(text: existing?['icon'] ?? '🔗');
    bool lead = existing?['lead_capture'] ?? false;
    bool enabled = existing?['enabled'] ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Add Link' : 'Edit Link'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: titleCtl,
              decoration: const InputDecoration(labelText: 'Title'),
              maxLength: 60,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title required' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: urlCtl,
              decoration: const InputDecoration(
                  labelText: 'URL (https://example.com)'),
              validator: (v) =>
                  (v == null || !_isValidUrl(v)) ? 'Enter valid URL' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: iconCtl,
              decoration: const InputDecoration(
                  labelText: 'Icon (emoji or short name)'),
              maxLength: 6,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: lead,
              onChanged: (v) => lead = v,
              title: const Text('Enable lead capture'),
            ),
            SwitchListTile(
              value: enabled,
              onChanged: (v) => enabled = v,
              title: const Text('Enabled'),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Save')),
        ],
      ),
    );

    if (ok != true) return;

    final uid = _sb.auth.currentUser!.id;
    final url = _normalizeUrl(urlCtl.text);
    final newItem = {
      'title': titleCtl.text.trim(),
      'url': url,
      'icon': iconCtl.text.trim().isEmpty ? '🔗' : iconCtl.text.trim(),
      'lead_capture': lead,
      'enabled': enabled,
    };

    setState(() => _busy = true);
    try {
      if (existing == null) {
        final temp = {
          ...newItem,
          'id': 'temp_${DateTime.now().microsecondsSinceEpoch}',
          'position': _links.length
        };
        setState(() => _links.add(temp));
        final inserted = await _sb
            .from('links')
            .insert({
              'user_id': uid,
              ...newItem,
              'position': _links.length - 1,
            })
            .select('id')
            .single();
        final idx = _links.indexWhere((e) => e['id'] == temp['id']);
        if (idx != -1) _links[idx]['id'] = inserted['id'];
        _snack('Link added');
      } else {
        final idx = _links.indexWhere((e) => e['id'] == existing['id']);
        final prev = Map<String, dynamic>.from(_links[idx]);
        setState(() => _links[idx] = {..._links[idx], ...newItem});
        try {
          await _sb.from('links').update(newItem).eq('id', existing['id']);
          _snack('Link updated');
        } catch (_) {
          setState(() => _links[idx] = prev);
          rethrow;
        }
      }
    } catch (e) {
      _snack('Save failed: $e', color: Colors.red);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = _links.removeAt(oldIndex);
    _links.insert(newIndex, moved);
    setState(() {});
    try {
      final start = min(oldIndex, newIndex), end = max(oldIndex, newIndex);
      for (int i = start; i <= end; i++) {
        if (_links[i]['position'] != i) {
          await _sb.from('links').update({'position': i}).eq('id', _links[i]['id']);
          _links[i]['position'] = i;
        }
      }
    } catch (_) {
      await _loadLinks();
      _snack('Reorder failed – list reloaded.', color: Colors.orange);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete link?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final idx = _links.indexWhere((e) => e['id'] == id);
    if (idx == -1) return;
    final removed = _links.removeAt(idx);
    setState(() {});
    try {
      await _sb.from('links').delete().eq('id', id);
      for (int i = 0; i < _links.length; i++) {
        if (_links[i]['position'] != i) {
          await _sb.from('links').update({'position': i}).eq('id', _links[i]['id']);
          _links[i]['position'] = i;
        }
      }
      _snack('Link deleted');
    } catch (e) {
      _links.insert(idx, removed);
      setState(() {});
      _snack('Delete failed: $e', color: Colors.red);
    }
  }

  Future<void> _toggle(int index, String field, bool val) async {
    if (index < 0 || index >= _links.length) return;
    final id = _links[index]['id'];
    final prev = _links[index][field];
    setState(() => _links[index][field] = val);
    try {
      await _sb.from('links').update({field: val}).eq('id', id);
    } catch (_) {
      setState(() => _links[index][field] = prev);
      _snack('Update failed', color: Colors.red);
    }
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in anytime.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) {
      await _sb.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uname = _username ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(uname.isEmpty ? 'Your Links' : 'Your Links – @$uname'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Analytics',
            onPressed: () => Navigator.pushNamed(context, '/analytics'),
          ),
          IconButton(
            tooltip: 'Public page',
            icon: const Icon(Icons.public),
            onPressed:
                _username == null ? null : () => _snack('Public page: /$uname'),
          ),
          IconButton(
              tooltip: 'Sign out',
              onPressed: _signOut,
              icon: const Icon(Icons.logout)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Add Link'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _links.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('No links yet.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _addOrEdit(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Link'),
                    )
                  ]),
                )
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: ReorderableListView.builder(
                    itemCount: _links.length,
                    onReorder: _reorder,
                    buildDefaultDragHandles: false,
                    proxyDecorator: (child, _, __) =>
                        Material(elevation: 8, child: child),
                    itemBuilder: (context, index) {
                      final l = _links[index];
                      return Card(
                        key: ValueKey(l['id']),
                        child: ListTile(
                          leading: Text((l['icon'] ?? '🔗').toString(),
                              style: const TextStyle(fontSize: 22)),
                          title: Text(l['title'] ?? '',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(l['url'] ?? '',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () async {
                            final url = _normalizeUrl(l['url'] ?? '');
                            final uri = Uri.tryParse(url);
                            if (uri != null && await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            } else {
                              _snack('Invalid URL', color: Colors.red);
                            }
                          },
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Tooltip(
                              message: 'Lead capture',
                              child: Switch(
                                value: (l['lead_capture'] ?? false) as bool,
                                onChanged: _busy
                                    ? null
                                    : (v) => _toggle(index, 'lead_capture', v),
                              ),
                            ),
                            Tooltip(
                              message: 'Enabled',
                              child: Switch(
                                value: (l['enabled'] ?? true) as bool,
                                onChanged: _busy
                                    ? null
                                    : (v) => _toggle(index, 'enabled', v),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Edit',
                              icon: const Icon(Icons.edit),
                              onPressed:
                                  _busy ? null : () => _addOrEdit(existing: l),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline),
                              onPressed:
                                  _busy ? null : () => _delete(l['id'] as String),
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding:
                                    EdgeInsets.symmetric(horizontal: 8.0),
                                child: Icon(Icons.drag_handle),
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
