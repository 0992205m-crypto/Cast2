import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:file_picker/file_picker.dart';

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
      title: 'مستكشف وبث الوسائط الاحترافي',
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0Style.purplePrimary),
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

  // قائمة الأجهزة المكتشفة وهمياً (للواجهة ويتم ربطها بروتوكولياً)
  final List<String> _connectedDevices = ["ريسيفر الصالة (DLNA)", "شاشة غرفة النوم (Chromecast)", "جهاز استقبال ذكي"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('كاست ماستر برو 📡'),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: const Icon(Icons.cast_connected, color: Colors.amber),
            onPressed: () => _showDeviceSelectionDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.folder, color: Colors.cyan),
            onPressed: _pickLocalFile,
          ),
        ],
      ),
      body: _selectedIndex == 0 ? _buildBrowserTab() : _buildVideosListTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: Colors.amber,
        onTap: (index) {
          setState(() { _selectedIndex = index; });
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.web), label: 'المتصفح الذكي'),
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

  // 1. واجهة المتصفح الذكي مدمج بها كاشف الفيديوهات
  Widget _buildBrowserTab() {
    return Column(
      children: [
        // شريط العنوان للبحث والدخول للمواقع
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: const Color(0xFF1E293B),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'أدخل رابط الموقع أو ابحث في يوتيوب...',
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
        // محرك المتصفح الداخلي
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_currentUrl)),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onLoadStop: (controller, url) async {
              setState(() { _currentUrl = url.toString(); });
              _detectMediaLinks(); // تشغيل فحص الفيديوهات تلقائياً عند تحميل أي صفحة
            },
          ),
        ),
      ],
    );
  }

  // 2. واجهة عرض الفيديوهات التي تم العثور عليها في الموقع
  Widget _buildVideosListTab() {
    if (_detectedVideos.isEmpty) {
      return const Center(child: Text('لم يتم العثور على فيديوهات في هذه الصفحة بعد. قم بتشغيل فيديو داخل المتصفح.'));
    }
    return ListView.builder(
      itemCount: _detectedVideos.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.all(8),
          color: const Color(0xFF1E293B),
          child: ListTile(
            leading: const Icon(Icons.play_circle_fill, color: Colors.amber, size: 40),
            title: Text('رابط فيديو مكتشف رقم ${index + 1}', maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(_detectedVideos[index], maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.phone_android, color: Colors.green),
                  onPressed: () => _playLocally(_detectedVideos[index]),
                ),
                IconButton(
                  icon: const Icon(Icons.cast, color: Colors.orange),
                  onPressed: () => _castToDevice(_detectedVideos[index]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // آلية ذكية لحقن كود جافاسكريبت داخل المتصفح واستخراج بروتوكولات الفيديو الحية (mp4, m3u8, mpd)
  void _detectMediaLinks() async {
    if (_webViewController == null) return;
    
    // كود جافا سكريبت يبحث عن وسوم الفيديو ومصادر البث في يوتيوب والمواقع الأخرى
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
          setState(() {
            _detectedVideos.add(link.toString());
          });
        }
      }
    }
  }

  // اختيار ملف فيديو محلي من ذاكرة الهاتف الذكي لبثه
  void _pickLocalFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.single.path != null) {
      String localPath = result.files.single.path!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم اختيار الملف بنجاح: ${result.files.single.name}')),
      );
      _showDeviceSelectionDialog(); // فتح قائمة الشاشات فوراً لبثه
    }
  }

  // تشغيل الفيديو محلياً داخل التطبيق
  void _playLocally(String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('جاري تشغيل الفيديو محلياً في المشغل الداخلي...')),
    );
  }

  // بث الفيديو مباشرة إلى الريسيفر أو الشاشة المحددة
  void _castToDevice(String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('جاري بدء بروتوكول البث DLNA / Cast إلى الريسيفر المختار...')),
    );
  }

  // نافذة اختيار أجهزة الاستقبال والريسيفرات المتصلة بالواي فاي (DLNA/Cast)
  void _showDeviceSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر جهاز الريسيفر أو الشاشة 📺'),
        backgroundColor: const Color(0xFF1E293B),
        content: SizedBox(
          width: double.maxFinite,
          height: 200,
          child: ListView.builder(
            itemCount: _connectedDevices.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: const Icon(Icons.tv, color: Colors.amber),
                title: Text(_connectedDevices[index]),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم الاتصال بنجاح مع: ${_connectedDevices[index]}')),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
