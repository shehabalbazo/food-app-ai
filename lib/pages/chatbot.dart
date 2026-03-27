import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:food_delivery_app/pages/profile.dart';
import 'package:food_delivery_app/pages/bottomnav.dart';
import 'package:food_delivery_app/pages/order.dart' as app_pages;
import 'package:food_delivery_app/pages/wallet.dart';
import 'package:food_delivery_app/pages/home.dart';
import 'package:food_delivery_app/service/shared_pref.dart';

class ChatBot extends StatefulWidget {
  const ChatBot({super.key});

  @override
  State<ChatBot> createState() => _ChatBotState();
}

class _ChatBotState extends State<ChatBot> {
  // Controller للتحكم بحقل الكتابة (قراءة النص + مسحه)
  final TextEditingController _controller = TextEditingController();

  // قائمة الرسائل (Messages) التي ستظهر في الشاشة
  final List<_ChatMsg> _msgs = [
    // رسالة ترحيب ابتدائية من البوت
    _ChatMsg(
      text:
          "Hello! I'm your AI food assistant.\nYou can ask me in English,Turkish, or Arabic.\nHow can I help you today?", // نص الرسالة
      isUser: false, // false = رسالة من البوت (ليست من المستخدم)
      time: DateTime.now().subtract(
        const Duration(minutes: 1),
      ), // وقت الرسالة قبل دقيقة
    ),
  ];

  bool _isLeavingChat = false;

  bool get shouldShowFeedback {
    return _msgs.any((msg) => msg.isUser);
  }

  //دالة حفظ التقييم
  Future<void> saveFeedbackToFirebase({
    required double rating,
    required String comment,
  }) async {
    final userId = await SharedPreferenceHelper().getUserId();
    final userName = await SharedPreferenceHelper().getUserName();
    final userEmail = await SharedPreferenceHelper().getUserEmail();

    await FirebaseFirestore.instance.collection("assistant_feedback").add({
      "userId": userId ?? "",
      "userName": userName ?? "",
      "userEmail": userEmail ?? "",
      "rating": rating,
      "comment": comment,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> showFeedbackSheet() async {
    double selectedRating = 0;
    final TextEditingController feedbackController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      "Rate the Assistant",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "How was your experience?",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starIndex = index + 1;
                      return IconButton(
                        onPressed: () {
                          setModalState(() {
                            selectedRating = starIndex.toDouble();
                          });
                        },
                        icon: Icon(
                          Icons.star,
                          size: 34,
                          color: selectedRating >= starIndex
                              ? Colors.amber
                              : Colors.grey,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: feedbackController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "Write your feedback (optional)...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (selectedRating == 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please select a rating"),
                            ),
                          );
                          return;
                        }

                        await saveFeedbackToFirebase(
                          rating: selectedRating,
                          comment: feedbackController.text.trim(),
                        );

                        if (!mounted) return;

                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Colors.orangeAccent,
                            content: Text(
                              "Thanks for your feedback!",
                              style: TextStyle(
                                fontSize: 18.0,
                                color: Colors.black,
                                fontFamily: 'Google_Sans_Flex',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                      child: const Text("Submit"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> exitChat() async {
    if (_isLeavingChat) return;
    _isLeavingChat = true;

    if (shouldShowFeedback) {
      await showFeedbackSheet();
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => BottomNav()),
      (route) => false,
    );
  }

  Widget _quickButton(String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD6DFEA)),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
  }

  // عند إغلاق الصفحة يجب التخلص من الـcontroller لتجنب memory leak
  @override
  void dispose() {
    _controller.dispose(); // تحرير موارد controller
    super.dispose(); // استدعاء dispose الأساسي
  }

  Future<Map<String, dynamic>> askAI() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('chatWithAI');

      final history = _msgs.map((msg) {
        return {"role": msg.isUser ? "user" : "assistant", "content": msg.text};
      }).toList();

      final result = await callable.call({"messages": history});

      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      print("AI Error: $e");
      return {"reply": "Sorry, AI service is not available.", "action": null};
    }
  }

  //دالة جلب المنتجات
  Future<String> searchFood(String userMessage) async {
    try {
      userMessage = userMessage.toLowerCase().trim();

      String cleanUserMessage = userMessage
          .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
          .trim();

      // الرد على التحية
      if (cleanUserMessage.contains("hi") ||
          cleanUserMessage.contains("hello") ||
          cleanUserMessage.contains("hey")) {
        return "Hello 👋 How can I help you today?";
      }

      List<String> collections = ["Pizza", "Burger", "Salad", "Ice-cream"];

      for (String col in collections) {
        var snapshot = await FirebaseFirestore.instance.collection(col).get();

        // البحث عن منتج محدد أولاً
        for (var doc in snapshot.docs) {
          var data = doc.data();

          String name = data["Name"].toString().toLowerCase().trim();

          String cleanName = name
              .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
              .trim();

          List<String> productWords = cleanName.split(" ");

          int matchedWords = 0;

          for (String word in productWords) {
            if (cleanUserMessage.contains(word)) {
              matchedWords++;
            }
          }

          if (matchedWords == productWords.length && productWords.isNotEmpty) {
            return "${data["Name"]} price is \$${data["Price"]}";
          }
        }

        // إذا طلب المستخدم عرض قائمة الكاتيجوري
        if (cleanUserMessage.contains(col.toLowerCase())) {
          String result = "$col Menu:\n\n";

          for (var doc in snapshot.docs) {
            var data = doc.data();

            result += "${data["Name"]} - \$${data["Price"]}\n";
          }

          return result;
        }
      }

      return "Sorry, I didn't understand that. Try asking about pizza, burger, salad or ice cream.";
    } catch (e) {
      return "Something went wrong while fetching data.";
    }
  }

  // دالة إرسال الرسالة عند الضغط على زر الإرسال أو Enter
  void _send() async {
    final text = _controller.text.trim();

    if (text.isEmpty) return;

    setState(() {
      _msgs.add(_ChatMsg(text: text, isUser: true, time: DateTime.now()));
    });

    _controller.clear();

    final result = await askAI();
    final String reply = result["reply"]?.toString() ?? "";
    final String? action = result["action"]?.toString();

    if (!mounted) return;

    setState(() {
      _msgs.add(_ChatMsg(text: reply, isUser: false, time: DateTime.now()));
    });

    if (action != null) {
      handleAction(action);
    }
  }

  // دالة لتنسيق الوقت بصيغة 12 ساعة (AM/PM)
  String _fmtTime(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12; // تحويل الساعة إلى نظام 12
    final m = t.minute.toString().padLeft(
      2,
      '0',
    ); // دقيقة بصيغة 2 رقم (مثلاً 03)
    final ap = t.hour >= 12 ? "PM" : "AM"; // تحديد AM أو PM حسب الساعة
    return "$h:$m $ap"; // إرجاع النص النهائي للوقت
  }

  // بناء واجهة الصفحة
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await exitChat();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEFF5FF), // لون خلفية الشاشة
        // شريط العنوان AppBar
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await exitChat();
            },
          ),
          elevation: 0, // بدون ظل
          backgroundColor: Colors.white, // لون خلفية AppBar
          foregroundColor: Colors.black, // لون النص والأيقونات في AppBar
          titleSpacing: 0, // إزالة padding الافتراضي للعنوان
          // عنوان AppBar (Row: أيقونة + نص + Online)
          title: Row(
            children: [
              const SizedBox(width: 8), // مسافة يسار
              // دائرة أيقونة الروبوت (Widget مساعد)
              _circleIcon(
                icon: Icons.smart_toy_outlined, // شكل الأيقونة
                bg: const Color(0xFF2F6BFF), // لون الخلفية
                iconColor: Colors.white, // لون الأيقونة
                size: 40, // حجم الدائرة
              ),

              const SizedBox(width: 12), // مسافة بين الأيقونة والنص
              // عنوان + حالة Online
              Column(
                crossAxisAlignment: CrossAxisAlignment.start, // محاذاة لليسار
                children: const [
                  Text(
                    "AI Assistant", // عنوان المساعد
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 2), // مسافة صغيرة
                  // سطر الحالة (نقطة خضراء + Online)
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        color: Colors.green,
                        size: 10,
                      ), // نقطة خضراء
                      SizedBox(width: 6), // مسافة
                      Text(
                        "Online",
                        style: TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // أزرار اليمين في AppBar (الثلاث نقاط)
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == "clear_chat") {
                  setState(() {
                    _msgs.clear();
                    _msgs.add(
                      _ChatMsg(
                        text:
                            "Hello! I'm your AI food assistant.\nYou can ask me in English,Turkish, or Arabic.\nHow can I help you today?",
                        isUser: false,
                        time: DateTime.now(),
                      ),
                    );
                  });
                } else if (value == "about") {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("About Assistant"),
                      content: const Text(
                        "This AI assistant helps you:\n\n"
                        "• Find and order food 🍔🍕\n"
                        "• Navigate inside the app📱\n"
                        "• Access your account\n\n"
                        "You can chat in English, Turkish, or Arabic.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("OK"),
                        ),
                      ],
                    ),
                  );
                } else if (value == "close") {
                  await exitChat();
                }
              },

              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: "clear_chat",
                  child: Text("🧹 Clear Chat"),
                ),
                PopupMenuItem(value: "close", child: Text("🏠 Back to Home")),
                PopupMenuItem(
                  value: "about",
                  child: Text("🤖 About Assistant"),
                ),
              ],
            ),
          ],
        ),

        // جسم الصفحة: قائمة الرسائل + حقل الكتابة
        body: Column(
          children: [
            // Expanded حتى تأخذ قائمة الرسائل كل المساحة المتاحة
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ), // padding للرسائل
                itemCount: _msgs.length, // عدد الرسائل = طول القائمة
                itemBuilder: (context, i) {
                  final m = _msgs[i]; // الرسالة الحالية حسب الفهرس

                  // بناء شكل الرسالة عبر Widget مخصص
                  return _MessageRow(
                    text: m.text, // نص الرسالة
                    isUser: m.isUser, // هل هي رسالة مستخدم؟
                    timeText: _fmtTime(m.time), // تحويل الوقت إلى نص جاهز
                  );
                },
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFFEFF5FF),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _quickButton(
                      "👤 Profile",
                      () => sendQuickMessage("open profile"),
                    ),
                    _quickButton(
                      "🏠 Home",
                      () => sendQuickMessage("open home"),
                    ),
                    _quickButton(
                      "🍕 Pizza",
                      () => sendQuickMessage("open pizza"),
                    ),
                    _quickButton(
                      "🍔 Burger",
                      () => sendQuickMessage("open burger"),
                    ),
                    _quickButton(
                      "🥗 Salad",
                      () => sendQuickMessage("open salad"),
                    ),
                    _quickButton(
                      "🍨 Ice Cream",
                      () => sendQuickMessage("open ice cream"),
                    ),
                  ],
                ),
              ),
            ),

            // Widget خاص بأسفل الشاشة: TextField + زر إرسال
            _Composer(
              controller: _controller, // تمرير controller إلى الـComposer
              onSend: _send, // تمرير دالة الإرسال
            ),
          ],
        ),
      ),
    );
  }

  Future<void> sendQuickMessage(String text) async {
    setState(() {
      _msgs.add(_ChatMsg(text: text, isUser: true, time: DateTime.now()));
    });

    final result = await askAI();
    final String reply = result["reply"]?.toString() ?? "";
    final String? action = result["action"]?.toString();

    if (!mounted) return;

    setState(() {
      _msgs.add(_ChatMsg(text: reply, isUser: false, time: DateTime.now()));
    });

    if (action != null) {
      handleAction(action);
    }
  }

  void handleAction(String action) {
    if (action == "open_profile") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Profile()),
      );
    } else if (action == "open_home") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => BottomNav()),
      );
    } else if (action == "open_cart") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const app_pages.Order()),
      );
    } else if (action == "open_wallet") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => Wallet()),
      );
    } else if (action == "open_pizza") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const Home(initialCategory: "Pizza"),
        ),
      );
    } else if (action == "open_burger") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const Home(initialCategory: "Burger"),
        ),
      );
    } else if (action == "open_salad") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const Home(initialCategory: "Salad"),
        ),
      );
    } else if (action == "open_icecream") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const Home(initialCategory: "Ice-cream"),
        ),
      );
    }
  }
}

// Widget مسؤول عن حقل إدخال النص وزر الإرسال في الأسفل
class _Composer extends StatelessWidget {
  final TextEditingController controller; // controller الخاص بالكتابة
  final VoidCallback onSend; // دالة الإرسال (callback)

  const _Composer({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false, // نحتاج SafeArea فقط للأسفل
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          16,
          10,
          16,
          14,
        ), // padding حول الـComposer
        decoration: const BoxDecoration(
          color: Color(0xFFEFF5FF), // نفس لون الخلفية
        ),
        child: Row(
          children: [
            // Expanded لجعل TextField يأخذ أغلب العرض
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                ), // padding داخل صندوق الكتابة
                decoration: BoxDecoration(
                  color: Colors.white, // خلفية بيضاء
                  borderRadius: BorderRadius.circular(16), // زوايا دائرية
                  border: Border.all(
                    color: const Color(0xFFE3E8F0),
                  ), // إطار خفيف
                ),
                child: TextField(
                  controller: controller, // ربط TextField بالـcontroller
                  textInputAction: TextInputAction.send, // زر Enter يصير Send
                  onSubmitted: (_) => onSend(), // عند الضغط Enter: أرسل
                  decoration: const InputDecoration(
                    hintText: "Type your message...", // نص داخل الحقل
                    border: InputBorder.none, // بدون border داخلي
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12), // مسافة بين الحقل والزر
            // زر الإرسال (Tap)
            GestureDetector(
              onTap: onSend, // عند الضغط: إرسال
              child: Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF2F6BFF), // لون الزر
                  borderRadius: BorderRadius.circular(16), // زوايا دائرية
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                ), // أيقونة الإرسال
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget مسؤول عن شكل كل رسالة (يمين/يسار + وقت + أيقونات)
class _MessageRow extends StatelessWidget {
  final String text; // نص الرسالة
  final bool isUser; // هل الرسالة من المستخدم؟
  final String timeText; // الوقت بصيغة نصية

  const _MessageRow({
    required this.text,
    required this.isUser,
    required this.timeText,
  });

  @override
  Widget build(BuildContext context) {
    // تحديد لون الفقاعة حسب المرسل
    final bubbleColor = isUser ? const Color(0xFF2F6BFF) : Colors.white;

    // تحديد لون النص حسب المرسل
    final textColor = isUser ? Colors.white : const Color(0xFF0F172A);

    // تحديد اتجاه الرسالة (يمين للمستخدم / يسار للبوت)
    final align = isUser ? MainAxisAlignment.end : MainAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14), // مسافة بين الرسائل
      child: Row(
        mainAxisAlignment: align, // محاذاة حسب المرسل
        crossAxisAlignment: CrossAxisAlignment.start, // بداية من الأعلى
        children: [
          // إذا الرسالة من البوت: أظهر أيقونة الروبوت على اليسار
          if (!isUser) ...[
            _circleIcon(
              icon: Icons.smart_toy_outlined,
              bg: const Color(0xFF2F6BFF),
              iconColor: Colors.white,
              size: 34,
            ),
            const SizedBox(width: 10),
          ],

          // Flexible لمنع overflow وللسماح للفقاعة بأخذ مساحة مناسبة
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start, // محاذاة الفقاعة + الوقت
              children: [
                // فقاعة النص
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                        color: Colors.black.withOpacity(0.06),
                      ),
                    ],
                  ),
                  child: Text(
                    text, // نص الرسالة
                    style: TextStyle(color: textColor, height: 1.25),
                  ),
                ),
                const SizedBox(height: 6),

                // وقت الرسالة تحت الفقاعة
                Text(
                  timeText,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // إذا الرسالة من المستخدم: أظهر أيقونة الشخص على اليمين
          if (isUser) ...[
            const SizedBox(width: 10),
            _circleIcon(
              icon: Icons.person,
              bg: const Color(0xFFEDE9FE),
              iconColor: const Color(0xFF7C3AED),
              size: 34,
            ),
          ],
        ],
      ),
    );
  }
}

// Widget مساعد لإنشاء أيقونة داخل دائرة (تُستخدم للروبوت وللمستخدم)
Widget _circleIcon({
  required IconData icon, // نوع الأيقونة
  required Color bg, // لون الخلفية
  required Color iconColor, // لون الأيقونة
  required double size, // حجم الدائرة
}) {
  return Container(
    height: size, // ارتفاع الدائرة
    width: size, // عرض الدائرة
    decoration: BoxDecoration(
      color: bg, // لون الخلفية
      shape: BoxShape.circle, // شكل دائري
    ),
    child: Icon(
      icon,
      color: iconColor,
      size: size * 0.55,
    ), // الأيقونة داخل الدائرة
  );
}

// Model يمثل الرسالة: نص + من المرسل + وقت
class _ChatMsg {
  final String text; // محتوى الرسالة
  final bool isUser; // true: user / false: bot
  final DateTime time; // وقت إرسال الرسالة

  _ChatMsg({required this.text, required this.isUser, required this.time});
}
