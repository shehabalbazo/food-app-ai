import 'package:flutter/material.dart';
import 'package:food_delivery_app/pages/signup.dart'; // صفحة التسجيل
import 'package:food_delivery_app/widget/content_model.dart'; // بيانات صفحات الـ onboarding
import 'package:food_delivery_app/widget/widget_support.dart'; // ستايلات النصوص
import 'package:shared_preferences/shared_preferences.dart';
import 'package:food_delivery_app/pages/login.dart';

class Onboard extends StatefulWidget {
  const Onboard({super.key});

  @override
  State<Onboard> createState() => _OnboardState();
}

class _OnboardState extends State<Onboard> {
  int currentIndex = 0; // مؤشر الصفحة الحالية
  late PageController _controller; // للتحكم بالتنقل بين الصفحات

  @override
  void initState() {
    // تهيئة PageController والبدء من الصفحة الأولى
    _controller = PageController(initialPage: 0);
    super.initState();
  }

  @override
  void dispose() {
    // التخلص من الـ controller لمنع تسريب الذاكرة
    _controller.dispose();
    super.dispose();
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // الجزء العلوي: صفحات الـ onboarding
          Expanded(
            child: PageView.builder(
              controller: _controller, // ربط الـ PageView بالـ controller
              itemCount: contents.length, // عدد الصفحات
              onPageChanged: (int index) {
                // تحديث رقم الصفحة الحالية
                setState(() {
                  currentIndex = index;
                });
              },
              itemBuilder: (_, i) {
                // محتوى كل صفحة
                return Padding(
                  padding: EdgeInsets.only(top: 40.0, left: 20.0, right: 20.0),
                  child: Column(
                    children: [
                      // صورة الصفحة
                      Image.asset(
                        contents[i].image,
                        height: 450,
                        width: MediaQuery.of(context).size.width,
                        fit: BoxFit.fill,
                      ),

                      SizedBox(height: 40.0),

                      // عنوان الصفحة
                      Text(
                        contents[i].title,
                        style: AppWidget.boldTextFieldStyle(),
                      ),

                      SizedBox(height: 20.0),

                      // وصف الصفحة
                      Text(
                        contents[i].description,
                        style: AppWidget.lightTextFieldStyle(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // النقاط (Indicators) أسفل الصفحات
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              contents.length,
              (index) => buildDot(index, context),
            ),
          ),

          // زر Next / Start
          GestureDetector(
            onTap: () async {
              if (currentIndex == contents.length - 1) {
                await completeOnboarding();

                if (!mounted) return;

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LogIn()),
                );
                return;    //اخر صفحة لازم تعمل return مشان ترسل بيانات انه شاف
              }

              _controller.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeIn,
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              height: 60,
              margin: EdgeInsets.all(40),
              width: double.infinity,
              child: Center(
                child: Text(
                  // تغيير النص حسب الصفحة
                  currentIndex == contents.length - 1 ? "Start" : "Next",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Google_Sans_Flex',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // دالة إنشاء النقاط أسفل الصفحة
  Container buildDot(int index, BuildContext context) {
    return Container(
      height: 10.0,
      // تكبير النقطة إذا كانت الصفحة الحالية
      width: currentIndex == index ? 18 : 7,
      margin: EdgeInsets.only(right: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: Colors.black38,
      ),
    );
  }
}
