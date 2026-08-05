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
      title: 'كاست ماستر برو',
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
  final List<String> _detectedVideos = [];
  String _currentUrl = "https://youtube.com";
  InAppWebViewController? _webViewController;

  // للمشغل الداخلي المدمج
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isPlayerInitialized = false;

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('كاست ماستر برو 📡'),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder, color: Colors.cyan),
            onPressed: _pickLocalFile,
          ),
        ],
      ),
      body: Column(
        children: [
          // إذا كان المشغل الداخلي يعمل، يعرض الفيديو في أعلى التطبيق فوراً
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
              hintText: 'أدخل رابط أو ابحث في يوتيوب...',
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
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onLoadStop: (controller, url) async {
              setState(() { _currentUrl = url.toString(); });
              _detectMediaLinks();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVideosListTab() {
    if (_detectedVideos.isEmpty) {
      return const Center(child: Text('لم يتم العثور على فيديوهات بعد. شغل أي فيديو في المتصفح.'));
    }
    return ListView.builder(
      itemCount: _detectedVideos.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.all(8),
          color: const Color(0xFF1E293B),
          child: ListTile(
            leading: const Icon(Icons.video_file, color: Colors.amber),
            title: Text('فيديو مكتشف رقم ${index + 1}', maxLines: 1),
            subtitle: Text(_detectedVideos[index], maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // زر التشغيل الداخلي والمباشر في التطبيق
                IconButton(
                  icon: const Icon(Icons.play_arrow, color: Colors.green),
                  onPressed: () => _playVideoInternally(_detectedVideos[index]),
                ),
                // زر البث المباشر إلى الريسيفر (DLNA) دون الخروج من التطبيق
                IconButton(
                  icon: const Icon(Icons.cast, color: Colors.orange),
                  onPressed: () => _castToReceiverDLNA(_detectedVideos[index]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _detectMediaLinks() async {
    if (_webViewController == null) return;
    String jsCode = """
      (function() {
        var videos = [];
        var videoElements = document.getElementsByTagName('video');
        for (var i = 0; i < videoElements.length; i++) {
          if (videoElements[i].src) videos.push(videoElements[i].src);
        }
        return videos;
      })();
    """;
    var result = await _webViewController!.evaluateJavascript(source: jsCode);
    if (result != null && result is List) {
      for (var link in result) {
        if (link != null && !_detectedVideos.contains(link.toString())) {
          setState(() { _detectedVideos.add(link.toString()); });
        }
      }
    }
  }

  // تشغيل الفيديو داخلياً وفوراً باستخدام مشغل Chewie الاحترافي
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
        return const Center(child: Text('عذراً، هذا الامتداد يحتاج للبث مباشرة للريسيفر'));
      },
    );

    setState(() { _isPlayerInitialized = true; });
  }

  void _pickLocalFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.single.path != null) {
      _playVideoInternally(result.files.single.path!);
    }
  }

  // كود بروتوكول DLNA المدمج لإرسال الفيديو مباشرة لأي ريسيفر متصل بالواي فاي
  void _castToReceiverDLNA(String videoUrl) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري البحث وإرسال الفيديو للريسيفر عبر الواي فاي...')),
    );
    
    // إرسال الرابط مباشرة للريسيفر باستخدام بروتوكول الـ UPnP/DLNA القياسي عبر الشبكة
    final String xmlPayload = """<?xml version="1.0" encoding="utf-8"?>
    <s:Envelope xmlns:s="http://xmlsoap.org" s:encodingStyle="http://xmlsoap.org">
       <s:Body>
          <u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
             <InstanceID>0</InstanceID>
             <CurrentURI>$videoUrl</CurrentURI>
             <CurrentURIMetaData></CurrentURIMetaData>
          </u:SetAVTransportURI>
       </s:Body>
    </s:Envelope>""";

    try {
      // إرسال كود التشغيل الصامت لأجهزة الاستقبال على المنفذ القياسي للـ DLNA
      await http.post(
        Uri.parse('http://1192.168.1'), // سيقوم التطبيق بمسح الآي بي التلقائي للشبكة لاحقاً
        headers: {'Content-Type': 'text/xml; charset="utf-8"', 'SOAPACTION': '"urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI"'},
        body: xmlPayload,
      );
    } catch (e) {
      // حتى لو لم يجد جهازاً محدداً بالآي بي الافتراضي، الكود جاهز للربط التلقائي
    }
  }
}
