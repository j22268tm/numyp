import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/theme.dart';
import '../../providers/api_client_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quest_provider.dart';

class QuestFormScreen extends ConsumerStatefulWidget {
  const QuestFormScreen({super.key, required this.initialLocation});

  final LatLng initialLocation;

  @override
  ConsumerState<QuestFormScreen> createState() => _QuestFormScreenState();
}

class _QuestFormScreenState extends ConsumerState<QuestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _detailController;
  late final TextEditingController _bountyController;
  bool _isSaving = false;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _detailController = TextEditingController();
    _bountyController = TextEditingController(text: '10');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailController.dispose();
    _bountyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('クエスト新規発注'),
        backgroundColor: colors.midnightBackground,
        foregroundColor: Colors.white,
      ),
      backgroundColor: colors.midnightBackground,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.cardSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.place_outlined, color: colors.magicGold),
                        const SizedBox(width: 8),
                        Text(
                          '発注位置',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.initialLocation.latitude.toStringAsFixed(6)}, ${widget.initialLocation.longitude.toStringAsFixed(6)}',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (user == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.cardSurface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, color: colors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'クエストを発注するにはログインが必要です',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              if (user == null) const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: '依頼タイトル',
                          prefixIcon: Icon(Icons.add_task_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _detailController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '依頼内容の詳細',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: (user == null || _isGenerating) ? null : _generateDraft,
                          icon: _isGenerating
                              ? SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.magicGold,
                                  ),
                                )
                              : Icon(Icons.auto_awesome, color: colors.magicGold),
                          label: Text(_isGenerating ? '生成中...' : 'AIで提案'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _bountyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '懸賞金（コイン）',
                          prefixIcon: Icon(Icons.monetization_on_outlined),
                        ),
                        validator: (value) {
                          final parsed = int.tryParse(value ?? '');
                          if (parsed == null || parsed <= 0) {
                            return '1以上の数値を入力してください';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (user == null || _isSaving) ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.magicGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.place_outlined),
                  label: const Text('この場所に発注する'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final context = this.context;
    final bounty = int.tryParse(_bountyController.text) ?? 10;

    setState(() => _isSaving = true);
    try {
      await ref.read(questControllerProvider.notifier).createQuest(
            title: _titleController.text.isEmpty ? '新しい依頼' : _titleController.text,
            description: _detailController.text.isEmpty ? 'ウォーカーに状況を確認してほしい' : _detailController.text,
            location: widget.initialLocation,
            bountyCoins: bounty,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('調査依頼ピンを作成しました')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('作成に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _generateDraft() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    if (_isGenerating) return;

    setState(() => _isGenerating = true);
    try {
      final client = ref.read(apiClientProvider);
      final draft = await client.generateQuestDraft(
        token: user.accessToken,
        lat: widget.initialLocation.latitude,
        lng: widget.initialLocation.longitude,
        hint: _titleController.text,
        currentTitle: _titleController.text,
        currentDescription: _detailController.text,
      );
      if (!mounted) return;
      _titleController.text = draft.title;
      _detailController.text = draft.description;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI提案の取得に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}
