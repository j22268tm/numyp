import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/spot.dart';
import '../../providers/api_client_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/spot_providers.dart';

class SpotFormScreen extends ConsumerStatefulWidget {
  const SpotFormScreen({super.key, this.spot, this.initialLocation});

  final Spot? spot;
  final LatLng? initialLocation;

  @override
  ConsumerState<SpotFormScreen> createState() => _SpotFormScreenState();
}

class _SpotFormScreenState extends ConsumerState<SpotFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late CrowdLevel _crowdLevel;
  late double _rating;
  bool _isSaving = false;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.spot?.content.title ?? '');
    _descriptionController = TextEditingController(text: widget.spot?.content.description ?? '');
    final initialLat = widget.initialLocation?.latitude ?? AppConstants.initialLatitude;
    final initialLng = widget.initialLocation?.longitude ?? AppConstants.initialLongitude;
    _latController = TextEditingController(
      text: (widget.spot?.location.latitude ?? initialLat).toString(),
    );
    _lngController = TextEditingController(
      text: (widget.spot?.location.longitude ?? initialLng).toString(),
    );
    _crowdLevel = widget.spot?.status.crowdLevel ?? CrowdLevel.medium;
    _rating = (widget.spot?.status.rating ?? 3).toDouble();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.spot != null;
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'スポットを編集' : '新規スポット作成'),
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
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _isGenerating ? null : _generateDescription,
                  icon:
                      _isGenerating
                          ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.auto_awesome),
                  label: const Text('AIで説明生成'),
                ),
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '説明 (任意)',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration: const InputDecoration(
                        labelText: '緯度',
                        prefixIcon: Icon(Icons.my_location),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      validator: (value) {
                        if (value == null || double.tryParse(value) == null) {
                          return '緯度を入力してください';
                        }
                        final lat = double.parse(value);
                        if (lat < -90 || lat > 90) {
                          return '緯度は-90〜90の範囲で入力してください';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngController,
                      decoration: const InputDecoration(
                        labelText: '経度',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      validator: (value) {
                        if (value == null || double.tryParse(value) == null) {
                          return '経度を入力してください';
                        }
                        final lng = double.parse(value);
                        if (lng < -180 || lng > 180) {
                          return '経度は-180〜180の範囲で入力してください';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<CrowdLevel>(
                      value: _crowdLevel,
                      decoration: const InputDecoration(
                        labelText: '混雑度',
                        prefixIcon: Icon(Icons.emoji_people),
                      ),
                      items: CrowdLevel.values
                          .map(
                            (level) => DropdownMenuItem(
                              value: level,
                              child: Text(level.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _crowdLevel = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('評価', style: TextStyle(color: colors.textSecondary)),
                        Slider(
                          value: _rating,
                          onChanged: (value) => setState(() => _rating = value),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          activeColor: colors.magicGold,
                          inactiveColor: Colors.white24,
                          label: _rating.toStringAsFixed(0),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.magicGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(isEditing ? '更新する' : '保存する'),
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
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    if (lat == null || lng == null) return;

    setState(() => _isSaving = true);
    final notifier = ref.read(spotsControllerProvider.notifier);
    try {
      if (widget.spot == null) {
        await notifier.createSpot(
          lat: lat,
          lng: lng,
          title: _titleController.text,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          crowdLevel: _crowdLevel,
          rating: _rating.round(),
        );
      } else {
        await notifier.updateSpot(
          id: widget.spot!.id,
          lat: lat,
          lng: lng,
          title: _titleController.text,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          crowdLevel: _crowdLevel,
          rating: _rating.round(),
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.spot == null ? 'スポットを追加しました' : 'スポットを更新しました')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _generateDescription() async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインしてください')),
      );
      return;
    }

    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('緯度/経度が不正です')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final client = ref.read(apiClientProvider);
      final description = await client.generateSpotDescription(
        token: user.accessToken,
        lat: lat,
        lng: lng,
        title: _titleController.text.isEmpty ? 'スポット' : _titleController.text,
        currentDescription: _descriptionController.text,
      );
      _descriptionController.text = description;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI生成に失敗しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}
