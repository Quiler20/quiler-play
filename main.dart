import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuilerPlayApp());
}

const Color bg = Color(0xFF101014);
const Color panel = Color(0xFF1C1B24);
const Color purple = Color(0xFF9B5CFF);

class VideoItem {
  final String id;
  final String title;
  const VideoItem({required this.id, required this.title});

  String get url => 'https://www.youtube.com/watch?v=$id';

  Map<String, dynamic> toJson() => {'id': id, 'title': title};

  factory VideoItem.fromJson(Map<String, dynamic> json) => VideoItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Video de YouTube',
      );

  @override
  bool operator ==(Object other) => other is VideoItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class QuilerPlayApp extends StatelessWidget {
  const QuilerPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiler Play',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: purple,
          brightness: Brightness.dark,
          surface: panel,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panel,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController linkController = TextEditingController();
  int tab = 0;
  VideoItem? current;
  WebViewController? playerController;
  List<VideoItem> favorites = [];
  List<VideoItem> history = [];
  bool loading = true;
  String? message;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  @override
  void dispose() {
    searchController.dispose();
    linkController.dispose();
    super.dispose();
  }

  Future<void> _loadLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    favorites = _decodeList(prefs.getString('favorites'));
    history = _decodeList(prefs.getString('history'));
    if (!mounted) return;
    setState(() => loading = false);
  }

  List<VideoItem> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => VideoItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((v) => v.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'favorites', jsonEncode(favorites.map((v) => v.toJson()).toList()));
    await prefs.setString(
        'history', jsonEncode(history.map((v) => v.toJson()).toList()));
  }

  String? _extractVideoId(String input) {
    final value = input.trim();
    if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(value)) return value;
    try {
      final uri = Uri.parse(value);
      if (uri.host == 'youtu.be' || uri.host.endsWith('.youtu.be')) {
        final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
        if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) return id;
      }
      if (uri.host.contains('youtube.com') ||
          uri.host.contains('youtube-nocookie.com')) {
        String? id = uri.queryParameters['v'];
        if (id == null && uri.pathSegments.length >= 2) {
          final first = uri.pathSegments.first;
          if (['embed', 'shorts', 'live', 'v'].contains(first)) {
            id = uri.pathSegments[1];
          }
        }
        if (id != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) {
          return id;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _searchYouTube() async {
    final query = searchController.text.trim();
    if (query.isEmpty) {
      setState(() => message = 'Escribe qué video quieres buscar.');
      return;
    }
    final uri = Uri.https('www.youtube.com', '/results', {'search_query': query});
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      setState(() => message = 'No se pudo abrir YouTube en este dispositivo.');
    } else if (mounted) {
      setState(() => message =
          'Busca el video en YouTube, copia su enlace y pégalo abajo para reproducirlo aquí.');
    }
  }

  Future<void> _playPastedLink() async {
    final id = _extractVideoId(linkController.text);
    if (id == null) {
      setState(() => message =
          'Ese enlace no parece ser de un video de YouTube. Copia el enlace completo del video.');
      return;
    }
    final item = VideoItem(id: id, title: 'Video de YouTube');
    linkController.clear();
    await _play(item);
  }

  Future<void> _play(VideoItem item) async {
    final updated = <VideoItem>[item, ...history.where((v) => v.id != item.id)];
    history = updated.take(100).toList();
    current = item;
    message = null;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onWebResourceError: (error) {
          if (mounted) {
            setState(() => message =
                'No se pudo cargar el reproductor. Revisa internet o abre el video en YouTube.');
          }
        },
      ))
      ..loadHtmlString(_playerHtml(item.id), baseUrl: 'https://www.youtube.com');

    playerController = controller;
    await _saveLibrary();
    if (mounted) {
      setState(() {
        tab = 0;
        message = 'Si el video no inicia, toca el botón de reproducir del reproductor.';
      });
    }
  }

  String _playerHtml(String id) => '''
<!doctype html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
<style>
html,body{margin:0;padding:0;background:#000;width:100%;height:100%;overflow:hidden}
iframe{position:absolute;top:0;left:0;width:100%;height:100%;border:0}
</style>
</head>
<body>
<iframe
 src="https://www.youtube.com/embed/$id?playsinline=1&rel=0"
 title="YouTube video player"
 allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
 referrerpolicy="strict-origin-when-cross-origin"
 allowfullscreen>
</iframe>
</body>
</html>
''';

  Future<void> _toggleFavorite() async {
    final item = current;
    if (item == null) return;
    final exists = favorites.any((v) => v.id == item.id);
    setState(() {
      if (exists) {
        favorites.removeWhere((v) => v.id == item.id);
        message = 'Quitado de favoritos.';
      } else {
        favorites.insert(0, item);
        message = 'Guardado en favoritos.';
      }
    });
    await _saveLibrary();
  }

  Future<void> _openExternal(VideoItem item) async {
    final uri = Uri.parse(item.url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _videoList(List<VideoItem> items, String emptyText) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(emptyText, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, height: 1.5)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          color: panel,
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                'https://i.ytimg.com/vi/${item.id}/mqdefault.jpg',
                width: 88,
                height: 54,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 88, height: 54,
                  child: Icon(Icons.play_circle_outline, color: purple),
                ),
              ),
            ),
            title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: const Text('YouTube', style: TextStyle(color: Colors.white54)),
            onTap: () => _play(item),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'play') _play(item);
                if (value == 'external') _openExternal(item);
                if (value == 'remove') {
                  setState(() {
                    favorites.removeWhere((v) => v.id == item.id);
                    history.removeWhere((v) => v.id == item.id);
                  });
                  _saveLibrary();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'play', child: Text('Reproducir')),
                PopupMenuItem(value: 'external', child: Text('Abrir en YouTube')),
                PopupMenuItem(value: 'remove', child: Text('Quitar de la lista')),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _homeBody() {
    final isFavorite = current != null &&
        favorites.any((v) => v.id == current!.id);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Videos a tu manera',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Busca en YouTube y reproduce un video pegando su enlace.',
            style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 20),
        TextField(
          controller: searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _searchYouTube(),
          decoration: InputDecoration(
            hintText: 'Buscar videos en YouTube',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Buscar',
              icon: const Icon(Icons.arrow_forward, color: purple),
              onPressed: _searchYouTube,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: _searchYouTube,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Buscar en YouTube'),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Reproducir un enlace',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: linkController,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'Pega aquí el enlace de YouTube',
            prefixIcon: Icon(Icons.link),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _playPastedLink,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Reproducir video'),
          ),
        ),
        if (current != null) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text('Reproduciendo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                tooltip: isFavorite ? 'Quitar de favoritos' : 'Guardar favorito',
                onPressed: _toggleFavorite,
                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.pinkAccent : purple),
              ),
              IconButton(
                tooltip: 'Abrir en YouTube',
                onPressed: () => _openExternal(current!),
                icon: const Icon(Icons.open_in_new),
              ),
            ],
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: playerController == null
                  ? const Center(child: CircularProgressIndicator())
                  : WebViewWidget(controller: playerController!),
            ),
          ),
          const SizedBox(height: 8),
          Text(current!.title,
              style: const TextStyle(color: Colors.white70)),
        ],
        if (message != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(message!, style: const TextStyle(color: Colors.white70)),
          ),
        ],
        const SizedBox(height: 20),
        const Text(
          'Nota: Quiler Play no elimina anuncios de YouTube. La disponibilidad del reproductor depende de YouTube, la conexión y las restricciones del video.',
          style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.play_circle_fill, color: purple, size: 30),
            SizedBox(width: 8),
            Text('Quiler Play', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: tab,
              children: [
                _homeBody(),
                _videoList(favorites, 'Todavía no tienes favoritos. Reproduce un video y toca el corazón para guardarlo.'),
                _videoList(history, 'Aquí aparecerán los videos que reproduzcas.'),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Favoritos'),
          NavigationDestination(icon: Icon(Icons.history), selectedIcon: Icon(Icons.history), label: 'Historial'),
        ],
      ),
    );
  }
}
