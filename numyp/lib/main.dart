import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String apiBaseUrl = 'http://100.70.69.107:8000';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthController(NumypApiService()),
      child: const NumypApp(),
    ),
  );
}

class NumypApp extends StatelessWidget {
  const NumypApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Numyp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

// Models
enum CrowdLevel { low, medium, high }

CrowdLevel crowdLevelFromString(String value) {
  switch (value) {
    case 'low':
      return CrowdLevel.low;
    case 'high':
      return CrowdLevel.high;
    default:
      return CrowdLevel.medium;
  }
}

String crowdLevelToLabel(CrowdLevel level) {
  switch (level) {
    case CrowdLevel.low:
      return '空いてる';
    case CrowdLevel.medium:
      return '普通';
    case CrowdLevel.high:
      return '混んでる';
  }
}

class AuthorInfo {
  final String id;
  final String username;
  final String? iconUrl;

  AuthorInfo({required this.id, required this.username, this.iconUrl});

  factory AuthorInfo.fromJson(Map<String, dynamic> json) {
    return AuthorInfo(
      id: json['id'] as String,
      username: json['username'] as String,
      iconUrl: json['icon_url'] as String?,
    );
  }
}

class SkinInfo {
  final String id;
  final String name;
  final String imageUrl;

  SkinInfo({required this.id, required this.name, required this.imageUrl});

  factory SkinInfo.fromJson(Map<String, dynamic> json) {
    return SkinInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String,
    );
  }
}

class SpotStatus {
  final CrowdLevel crowdLevel;
  final int rating;

  SpotStatus({required this.crowdLevel, required this.rating});

  factory SpotStatus.fromJson(Map<String, dynamic> json) {
    return SpotStatus(
      crowdLevel: crowdLevelFromString(json['crowd_level'] as String),
      rating: json['rating'] as int,
    );
  }
}

class LocationInfo {
  final double lat;
  final double lng;

  LocationInfo({required this.lat, required this.lng});

  factory LocationInfo.fromJson(Map<String, dynamic> json) {
    return LocationInfo(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

class ContentInfo {
  final String title;
  final String? description;
  final String? imageUrl;

  ContentInfo({required this.title, this.description, this.imageUrl});

  factory ContentInfo.fromJson(Map<String, dynamic> json) {
    return ContentInfo(
      title: json['title'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }
}

class Spot {
  final String id;
  final DateTime createdAt;
  final LocationInfo location;
  final ContentInfo content;
  final SpotStatus status;
  final AuthorInfo author;
  final SkinInfo skin;

  Spot({
    required this.id,
    required this.createdAt,
    required this.location,
    required this.content,
    required this.status,
    required this.author,
    required this.skin,
  });

  factory Spot.fromJson(Map<String, dynamic> json) {
    return Spot(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      location: LocationInfo.fromJson(json['location'] as Map<String, dynamic>),
      content: ContentInfo.fromJson(json['content'] as Map<String, dynamic>),
      status: SpotStatus.fromJson(json['status'] as Map<String, dynamic>),
      author: AuthorInfo.fromJson(json['author'] as Map<String, dynamic>),
      skin: SkinInfo.fromJson(json['skin'] as Map<String, dynamic>),
    );
  }
}

class UserWallet {
  final int coins;

  UserWallet(this.coins);

  factory UserWallet.fromJson(Map<String, dynamic> json) {
    return UserWallet(json['coins'] as int);
  }
}

class UserProfile {
  final String id;
  final String username;
  final String? iconUrl;
  final SkinInfo currentSkin;
  final UserWallet wallet;

  UserProfile({
    required this.id,
    required this.username,
    this.iconUrl,
    required this.currentSkin,
    required this.wallet,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String,
      iconUrl: json['icon_url'] as String?,
      currentSkin: SkinInfo.fromJson(
        json['current_skin'] as Map<String, dynamic>,
      ),
      wallet: UserWallet.fromJson(json['wallet'] as Map<String, dynamic>),
    );
  }
}

// API Service
class NumypApiService {
  final http.Client _client = http.Client();

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl$path'),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
        if (token != null) HttpHeaders.authorizationHeader: 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    _throwIfError(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _get(String path, {String? token}) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl$path'),
      headers: {
        if (token != null) HttpHeaders.authorizationHeader: 'Bearer $token',
      },
    );
    _throwIfError(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  void _throwIfError(http.Response response) {
    if (response.statusCode >= 400) {
      throw HttpException(
        'API Error ${response.statusCode}: ${response.body}',
        uri: response.request?.url,
      );
    }
  }

  Future<String> login(String username, String password) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/auth/login'),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/x-www-form-urlencoded',
      },
      body: {'username': username, 'password': password},
    );
    _throwIfError(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['access_token'] as String;
  }

  Future<void> signup(String username, String password) async {
    await _postJson('/auth/signup', {
      'username': username,
      'password': password,
    });
  }

  Future<UserProfile> fetchProfile(String token) async {
    final data = await _get('/users/me', token: token);
    return UserProfile.fromJson(data);
  }

  Future<List<Spot>> fetchSpots(String? token) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/spots'),
      headers: {
        if (token != null) HttpHeaders.authorizationHeader: 'Bearer $token',
      },
    );
    _throwIfError(response);
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => Spot.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Spot> fetchSpotDetail(String id, String? token) async {
    final data = await _get('/spots/$id', token: token);
    return Spot.fromJson(data);
  }

  Future<Spot> createSpot({
    required String token,
    required double lat,
    required double lng,
    required String title,
    String? description,
    CrowdLevel crowdLevel = CrowdLevel.medium,
    int rating = 3,
    String? imageBase64,
  }) async {
    final payload = {
      'lat': lat,
      'lng': lng,
      'title': title,
      'description': description,
      'crowd_level': _crowdLevelToString(crowdLevel),
      'rating': rating,
      'image_base64': imageBase64,
    };

    final data = await _postJson('/spots', payload, token: token);
    return Spot.fromJson(data);
  }

  String _crowdLevelToString(CrowdLevel level) {
    switch (level) {
      case CrowdLevel.low:
        return 'low';
      case CrowdLevel.medium:
        return 'medium';
      case CrowdLevel.high:
        return 'high';
    }
  }
}

// Auth Controller
class AuthController extends ChangeNotifier {
  final NumypApiService api;
  String? token;
  UserProfile? user;
  bool isLoading = false;
  String? error;

  AuthController(this.api) {
    _loadSavedToken();
  }

  Future<void> _loadSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('numyp_token');
    if (saved != null) {
      token = saved;
      await refreshProfile();
    }
  }

  Future<void> login(String username, String password) async {
    _setLoading(true);
    try {
      token = await api.login(username, password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('numyp_token', token!);
      await refreshProfile();
    } catch (e) {
      error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signup(String username, String password) async {
    _setLoading(true);
    try {
      await api.signup(username, password);
      await login(username, password);
    } catch (e) {
      error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshProfile() async {
    if (token == null) return;
    try {
      user = await api.fetchProfile(token!);
      error = null;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> logout() async {
    token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('numyp_token');
    notifyListeners();
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }
}

// UI
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        if (auth.token == null) {
          return const AuthScreen();
        }
        return HomeScreen(api: auth.api);
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isLogin = true;
  String username = '';
  String password = '';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? 'ログイン' : '新規登録')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'ユーザー名'),
                  onChanged: (v) => username = v,
                  validator: (v) => v == null || v.isEmpty ? '必須です' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'パスワード'),
                  obscureText: true,
                  onChanged: (v) => password = v,
                  validator: (v) =>
                      v == null || v.length < 4 ? '4文字以上必要です' : null,
                ),
                const SizedBox(height: 16),
                if (auth.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      auth.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                FilledButton(
                  onPressed: auth.isLoading
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          if (isLogin) {
                            await auth.login(username, password);
                          } else {
                            await auth.signup(username, password);
                          }
                        },
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isLogin ? 'ログイン' : '登録してログイン'),
                ),
                TextButton(
                  onPressed: () => setState(() => isLogin = !isLogin),
                  child: Text(isLogin ? 'アカウントを作成' : 'ログインに切り替え'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api});

  final NumypApiService api;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  List<Spot> spots = [];
  bool isLoading = false;
  Spot? selectedSpot;
  LatLng cameraPosition = const LatLng(35.681236, 139.767125);

  @override
  void initState() {
    super.initState();
    _loadSpots();
  }

  Future<void> _loadSpots() async {
    setState(() => isLoading = true);
    final auth = context.read<AuthController>();
    try {
      final data = await widget.api.fetchSpots(auth.token);
      setState(() {
        spots = data;
      });
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }

  Set<Marker> _buildMarkers() {
    return spots
        .map(
          (spot) => Marker(
            markerId: MarkerId(spot.id),
            position: LatLng(spot.location.lat, spot.location.lng),
            infoWindow: InfoWindow(title: spot.content.title),
            onTap: () => _openSpotDetail(spot.id),
          ),
        )
        .toSet();
  }

  Future<void> _openSpotDetail(String spotId) async {
    final auth = context.read<AuthController>();
    try {
      final detail = await widget.api.fetchSpotDetail(spotId, auth.token);
      setState(() => selectedSpot = detail);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        builder: (context) {
          final gestureInset = MediaQuery.of(context).systemGestureInsets.bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: gestureInset),
            child: SpotDetailSheet(spot: detail),
          );
        },
      );
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createSpot() async {
    final auth = context.read<AuthController>();
    if (auth.token == null) {
      _showError('スポット投稿にはログインが必要です');
      return;
    }

    final currentPosition = cameraPosition;

    if (!mounted) return;
    final created = await showModalBottomSheet<Spot>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        final keyboardInset = media.viewInsets.bottom;
        final gestureInset = media.systemGestureInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(
            bottom: keyboardInset + gestureInset,
          ),
          child: CreateSpotSheet(
            api: widget.api,
            token: auth.token!,
            initialPosition: currentPosition,
          ),
        );
      },
    );

    if (created != null) {
      setState(() {
        spots.add(created);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final media = MediaQuery.of(context);
    final bottomInset = media.viewPadding.bottom;
    final gestureInset = media.systemGestureInsets.bottom;
    final bottomSpacing = bottomInset + gestureInset;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Numyp マップ'),
        actions: [
          if (auth.user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: auth.user!.iconUrl != null
                        ? NetworkImage(auth.user!.iconUrl!)
                        : null,
                    child: auth.user!.iconUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.user!.username,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'コイン: ${auth.user!.wallet.coins}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          IconButton(
            onPressed: _loadSpots,
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
          ),
          IconButton(
            onPressed: auth.logout,
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
          ),
        ],
      ),
      body: SafeArea(
        // Ensure the map stays clear of gesture navigation areas.
        minimum: EdgeInsets.only(bottom: gestureInset),
        child: Stack(
          children: [
            GoogleMap(
              mapType: MapType.normal,
              myLocationEnabled: true,
              initialCameraPosition: CameraPosition(
                target: cameraPosition,
                zoom: 13,
              ),
              onMapCreated: (controller) => _mapController.complete(controller),
              markers: _buildMarkers(),
              onCameraMove: (pos) => cameraPosition = pos.target,
            ),
            if (isLoading) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomSpacing + 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.extended(
              heroTag: 'create',
              onPressed: _createSpot,
              icon: const Icon(Icons.add_location_alt),
              label: const Text('スポットを投稿'),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.extended(
              heroTag: 'recenter',
              onPressed: () async {
                final controller = await _mapController.future;
                await controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: cameraPosition, zoom: 15),
                  ),
                );
              },
              icon: const Icon(Icons.center_focus_strong),
              label: const Text('中心に移動'),
            ),
          ],
        ),
      ),
    );
  }
}

class SpotDetailSheet extends StatelessWidget {
  const SpotDetailSheet({super.key, required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            spot.content.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(spot.content.description ?? '説明なし'),
          const SizedBox(height: 8),
          Row(
            children: [
              Chip(
                label: Text(
                  '混雑度: ${crowdLevelToLabel(spot.status.crowdLevel)}',
                ),
              ),
              const SizedBox(width: 8),
              Chip(label: Text('評価: ${spot.status.rating}/5')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                backgroundImage: spot.author.iconUrl != null
                    ? NetworkImage(spot.author.iconUrl!)
                    : null,
                child: spot.author.iconUrl == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 8),
              Text('投稿者: ${spot.author.username}'),
            ],
          ),
          const SizedBox(height: 8),
          if (spot.content.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(spot.content.imageUrl!),
            ),
          const SizedBox(height: 8),
          Text('スキン: ${spot.skin.name}'),
          const SizedBox(height: 8),
          Text('投稿日時: ${spot.createdAt.toLocal()}'),
        ],
      ),
    );
  }
}

class CreateSpotSheet extends StatefulWidget {
  const CreateSpotSheet({
    super.key,
    required this.api,
    required this.token,
    required this.initialPosition,
  });

  final NumypApiService api;
  final String token;
  final LatLng initialPosition;

  @override
  State<CreateSpotSheet> createState() => _CreateSpotSheetState();
}

class _CreateSpotSheetState extends State<CreateSpotSheet> {
  final _formKey = GlobalKey<FormState>();
  double? lat;
  double? lng;
  String title = '';
  String description = '';
  CrowdLevel crowdLevel = CrowdLevel.medium;
  double rating = 3;
  XFile? pickedImage;
  bool submitting = false;

  @override
  void initState() {
    super.initState();
    lat = widget.initialPosition.latitude;
    lng = widget.initialPosition.longitude;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() => pickedImage = image);
    }
  }

  String? _buildBase64() {
    if (pickedImage == null) return null;
    final extension = pickedImage!.path.toLowerCase();
    String mime = 'image/jpeg';
    if (extension.endsWith('.png')) mime = 'image/png';
    if (extension.endsWith('.webp')) mime = 'image/webp';
    final bytes = File(pickedImage!.path).readAsBytesSync();
    final encoded = base64Encode(bytes);
    return 'data:$mime;base64,$encoded';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (lat == null || lng == null) return;
    setState(() => submitting = true);
    try {
      final spot = await widget.api.createSpot(
        token: widget.token,
        lat: lat!,
        lng: lng!,
        title: title,
        description: description.isEmpty ? null : description,
        rating: rating.toInt(),
        crowdLevel: crowdLevel,
        imageBase64: _buildBase64(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(spot);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('投稿に失敗しました: $e')));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: lat?.toStringAsFixed(6),
                    decoration: const InputDecoration(labelText: '緯度'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => lat = double.tryParse(v),
                    validator: (v) => v == null || double.tryParse(v) == null
                        ? '数値を入力'
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: lng?.toStringAsFixed(6),
                    decoration: const InputDecoration(labelText: '経度'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => lng = double.tryParse(v),
                    validator: (v) => v == null || double.tryParse(v) == null
                        ? '数値を入力'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(labelText: 'タイトル'),
              onChanged: (v) => title = v,
              validator: (v) => v == null || v.isEmpty ? '必須項目です' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(labelText: '説明'),
              maxLines: 3,
              onChanged: (v) => description = v,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CrowdLevel>(
              value: crowdLevel,
              decoration: const InputDecoration(labelText: '混雑度'),
              items: CrowdLevel.values
                  .map(
                    (level) => DropdownMenuItem(
                      value: level,
                      child: Text(crowdLevelToLabel(level)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => crowdLevel = value!),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('評価'),
                Expanded(
                  child: Slider(
                    min: 1,
                    max: 5,
                    divisions: 4,
                    value: rating,
                    label: rating.toStringAsFixed(0),
                    onChanged: (v) => setState(() => rating = v),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('画像を選択'),
                ),
                const SizedBox(width: 8),
                if (pickedImage != null)
                  Expanded(
                    child: Text(
                      pickedImage!.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: submitting ? null : _submit,
              child: submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('スポットを投稿'),
            ),
          ],
        ),
      ),
    );
  }
}
