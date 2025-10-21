// =============================================================================
// LinkLocker – Public Profile Screen (Responsive Production Version)
// =============================================================================
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PublicProfileScreen extends StatefulWidget {
  final String username;
  const PublicProfileScreen({super.key, required this.username});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _links = [];
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final supabase = Supabase.instance.client;
    try {
      final profile = await supabase
          .from('profiles')
          .select()
          .eq('username', widget.username)
          .maybeSingle();
      if (profile == null) {
        setState(() => _loading = false);
        return;
      }
      final links = await supabase
          .from('links')
          .select()
          .eq('user_id', profile['id'])
          .order('position');
      setState(() {
        _profile = profile;
        _links = List<Map<String, dynamic>>.from(links);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _logClick(String linkId) async {
    final s = Supabase.instance.client;
    await s.from('clicks').insert({'link_id': linkId, 'timestamp': DateTime.now().toIso8601String()});
  }

  Future<void> _submitLead(String linkId, String email) async {
    final s = Supabase.instance.client;
    await s.from('leads').insert({
      'link_id': linkId,
      'email': email,
      'consent': true,
      'timestamp': DateTime.now().toIso8601String()
    });
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Thank you!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.username)),
        body: const Center(child: Text('Profile not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('@${widget.username}')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          return GridView.count(
            crossAxisCount: isWide ? 2 : 1,
            padding: const EdgeInsets.all(16),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: _links.map((link) {
              final TextEditingController controller = TextEditingController();
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(link['title'] ?? '',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () async {
                          _logClick(link['id']);
                          final uri = Uri.parse(link['url']);
                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                        },
                        child: const Text('Visit'),
                      ),
                      if (link['lead_capture'] == true) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            labelText: 'Your email',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (v) =>
                              _submitLead(link['id'], controller.text.trim()),
                        )
                      ]
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}