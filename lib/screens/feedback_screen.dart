import 'package:flutter/material.dart';
import '../models.dart';
import '../services/local_store_service.dart';
import '../widgets/common_widgets.dart';

/// A real, submittable feedback form. There's no backend behind UrbanEx,
/// so "submit" stores the message on-device via SharedPreferences - the
/// same way everything else the app remembers is stored. An admin
/// account can then read it from the Admin dashboard's Feedback tab.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const _categories = ['Bug report', 'Feature request', 'General feedback'];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  String _category = _categories.last;
  bool _submitting = false;
  String? _error;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    LocalStoreService.instance.getCurrentUser().then((account) {
      if (mounted) setState(() => _signedIn = account != null);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final account = await LocalStoreService.instance.getCurrentUser();
      final entry = FeedbackEntry(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        category: _category,
        name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        message: _messageController.text.trim(),
        submittedAt: DateTime.now(),
        submittedByEmail: account?.email,
      );
      await LocalStoreService.instance.submitFeedback(entry);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — your feedback has been submitted.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Couldn't submit your feedback. Please try again.");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact & feedback')),
      bottomNavigationBar: const GlobalBottomNav(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              "Send us a bug report, a feature idea, or anything else — it goes straight to the team's review queue.",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              _signedIn
                  ? "You're signed in, so you'll get a notification here in the app if an admin replies."
                  : 'Sign in first if you want to be notified in-app when an admin replies.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),
            const Text('Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _categories.map((c) {
                return SelectableChip(label: c, selected: _category == c, onTap: () => setState(() => _category = c));
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Your name (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Your email (optional, for a reply)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _messageController,
              minLines: 5,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please write a message' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12.5)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                ),
              )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}




