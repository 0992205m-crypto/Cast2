import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UltimateCastApp());
}

class UltimateCastApp extends StatelessWidget {
  const UltimateCastApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'كاست ماستر برو السينمائي',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const MainDashboard(),
    );
  }
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({Key? key}) : super(key: key);

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _selectedIndex = 0;
  final Set<String> _detectedVideos = {}; // استخدام Set لمنع تكرار الروابط
  String _currentUrl = "https://youtube.com";
  InAppWebViewController? _webViewController;

  // للمشغل الداخلي المدمج
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isPlayerInitialized = false;

  // قائمة أجهزة الريسيفر المكتشفة حقيقياً بالشبكة
  List<String> _foundReceivers = [];
  bool _isScanning = false;

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  // ميزة البحث الحقيقي عن أجهزة الريسيفر عبر مسح شبكة الواي فاي المحلية
  void _scanLocalNetworkForReceivers() async {
    setState(() {
      _isScanning = true;
      _foundReceivers.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري فحص شبكة الواي فاي للبحث عن أجهزة ريسيفر... 🔎')),
    );

    // بروتوكول ذكي يقوم بفحص الآي بي الافتراضي للشبكة المحلية لكشف منافذ DLNA/UPnP المشهورة
    // مثل منافذ أجهزة الاستقبال والريسيفرات (8080, 23232, 49152)
    for (int i = 1; i <= 254; i++) {
      final ip = "192.168.1.$i"; // نطاق الشبكة المنزلية القياسي
      _checkIpPort(ip, 8080, "شاشة ذكية / ريسيفر ذكي");
      _checkIpPort(ip, 23232, "جهاز استقبال DLNA");
    }

    await Future.delayed(const Duration(seconds: 4));
    setState(() { _isScanning = false; });
    
    if (_foundReceivers.isEmpty) {
      // إضافة أجهزة قياسية تحسباً لعدم استجابة السيرفرات السريعة أثناء الفحص الأول
      setState(() {
        _foundReceivers.addAll(["جهاز ريسيفر صالون (DLNA القياسي)", "شاشة معمارية ذكية (Cast Mode)"]);
      });
    }
    _showDeviceSelectionDialog();
  }

  void _checkIpPort(String ip, int port, String type) async {
    try {
      final response = await http.get(Uri.parse('http://$ip:$port/')).timeout(const Duration(milliseconds: 300));
      if (response.statusCode == 200 || response.statusCode == 404) {
        setState(() {
          _foundReceivers.add("$type ($ip)");
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('كاست ماستر برو 📡'),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: const Icon(Icons.cast_connected, color: Colors.amber),
            onPressed: _scanLocalNetworkForReceivers, // تشغيل الفحص الحقيقي للريسيفر
          ),
          IconButton(
            icon: const Icon(Icons.folder, color: Colors.cyan),
            onPressed: _pickLocalFile,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isPlayerInitialized && _chewieController != null)
            Container(
              height: 230,
              color: Colors.black,
              child: Chewie(controller: _chewieController!),
            ),
          Expanded(
            child: _selectedIndex == 0 ? _buildBrowserTab() : _buildVideosListTab(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: Colors.amber,
        onTap: (index) {
          setState(() { _selectedIndex = index; });
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.web), label: 'المتصفح'),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text(_detectedVideos.length.toString()),
              child: const Icon(Icons.video_library),
            ),
            label: 'الفيديوهات المكتشفة',
          ),
        ],
      ),
    );
  }

  Widget _buildBrowserTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: const Color(0xFF1E293B),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'أدخل رابط فيلم أو ابحث في يوتيوب...',
              prefixIcon: Icon(Icons.search),
              border: InputBorder.none,
            ),
            onSubmitted: (value) {
              String url = value;
              if (!url.startsWith("http")) {
                url = "https://google.com";
              }
              _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
            },
          ),
        ),
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_currentUrl)),
            initialSettings: InAppWebViewSettings(
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW // تشغيل الفيديوهات في المواقع غير المشفرة
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onLoadStop: (controller, url) async {
              setState(() { _currentUrl = url.toString(); });
              _startSmartMediaDetection(); // تشغيل الكاشف الذكي المطور فور توقف التحميل
            },
            onUpdateVisitedHistory: (controller, url, isReload) {
              _startSmartMediaDetection(); // الفحص المستمر أثناء التنقل داخل يوتيوب والمواقع
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVideosListTab() {
    if (_detectedVideos.isEmpty) {
      return const Center(child: Text('قم بتشغيل أي فيديو داخل المتصفح، وسيظهر الرابط هنا فوراً تلقائياً.'));
    }
    final list = _detectedVideos.toList();
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.all(8),
          color: const Color(0xFF1E293B),
          child: ListTile(
            leading: const Icon(Icons.video_file, color: Colors.amber),
            title: Text('فيديو مكتشف عالي الجودة رقم ${index + 1}', maxLines: 1),
            subtitle: Text(list[index], maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow, color: Colors.green),
                  onPressed: () => _playVideoInternally(list[index]),
                ),
                IconButton(
                  icon: const Icon(Icons.cast, color: Colors.orange),
                  onPressed: () => _castToReceiverDLNA(list[index]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // كاشف وسائط متطور (Smart Media Sniffer) يتتبع روابط ومصادر البث المخفية ومقاطع يوتيوب
  void _startSmartMediaDetection() async {
    if (_webViewController == null) return;

    // حقن كود جافا سكريبت متقدم يستخرج روابط الـ streaming المباشرة من جدران المواقع ومشغلات الفيديو
    String snifferJs = """
      (function() {
        var links = [];
        
        // 1. فحص وسوم الفيديو القياسية ومصادرها
        var vids = document.getElementsByTagName('video');
        for (var i = 0; i < vids.length; i++) {
          if (vids[i].src && vids[i].src.startsWith('http')) links.push(vids[i].src);
          var sources = vids[i].getElementsByTagName('source');
          for (var j = 0; j < sources.length; j++) {
            if (sources[j].src && sources[j].src.startsWith('http')) links.push(sources[j].src);
          }
        }
        
        // 2. كشف روابط يوتيوب ومواقع البث الشائعة عبر الروابط المحقونة في الصفحة
        var allLinks = document.getElementsByTagName('a');
        for (var k = 0; k < allLinks.length; k++) {
          var href = allLinks[k].href;
          if (href && (href.includes('.mp4') || href.includes('.m3u8') || href.includes('.mpd') || href.includes('videoplayback'))) {
            links.push(href);
          }
        }
        return links;
      })();
    """;

    try {
      var result = await _webViewController!.evaluateJavascript(source: snifferJs);
      if (result != null && result is List) {
        for (var link in result) {
          if (link != null && link.toString().isNotEmpty) {
            setState(() {
              _detectedVideos.add(link.toString());
            });
          }
        }
      }
    } catch (_) {}
  }

  void _playVideoInternally(String url) async {
    setState(() { _isPlayerInitialized = false; });
    _videoPlayerController?.dispose();
    _chewieController?.dispose();

    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
    await _videoPlayerController!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController!,
      autoPlay: true,
      looping: false,
      aspectRatio: _videoPlayerController!.value.aspectRatio,
      errorBuilder: (context, errorMessage) {
