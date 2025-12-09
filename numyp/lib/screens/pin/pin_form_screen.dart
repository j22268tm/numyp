import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/pin.dart';
import '../../providers/pin_provider.dart';

class PinFormScreen extends ConsumerStatefulWidget {
  const PinFormScreen({super.key, this.pin});

  final Pin? pin;

  @override
  ConsumerState<PinFormScreen> createState() => _PinFormScreenState();
}

class _PinFormScreenState extends ConsumerState<PinFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.pin?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.pin?.description ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.pin != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'ピンを編集' : '新規ピン作成'),
        backgroundColor: AppColors.midnightBackground,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppColors.midnightBackground,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'タイトル',
                  prefixIcon: Icon(Icons.push_pin),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'タイトルを入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '説明 (任意)',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                maxLines: 4,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.magicGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(isEditing ? '更新する' : '保存する'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(pinProvider.notifier);
    if (widget.pin == null) {
      notifier.addPin(
        title: _titleController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
      );
    } else {
      notifier.updatePin(
        widget.pin!.copyWith(
          title: _titleController.text,
          description: _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text,
        ),
      );
    }
    Navigator.of(context).pop();
  }
}
