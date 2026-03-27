// استيراد Firebase Authentication لتسجيل الدخول
import 'package:firebase_auth/firebase_auth.dart';

// استيراد أدوات Flutter الأساسية
import 'package:flutter/material.dart';
import 'package:food_delivery_app/admin/admin_login.dart';

// صفحات التنقل بعد تسجيل الدخول
import 'package:food_delivery_app/pages/bottomnav.dart';

// تغيير كلمة المرور
import 'package:food_delivery_app/pages/forgotpassword.dart';

//انتقال الى sign up
import 'package:food_delivery_app/pages/signup.dart';

// خدمات قاعدة البيانات و Shared Preferences
import 'package:food_delivery_app/service/database.dart';
import 'package:food_delivery_app/service/shared_pref.dart';

// ستايلات مخصصة للتطبيق
import 'package:food_delivery_app/widget/widget_support.dart';

// صفحة تسجيل الدخول (Stateful لأن فيها تغيير حالة)
class LogIn extends StatefulWidget {
  const LogIn({super.key});

  @override
  State<LogIn> createState() => _LogInState();
}

class _LogInState extends State<LogIn> {
  // متغيرات لتخزين الإيميل وكلمة المرور
  String email = "", password = "";

  // Controllers لقراءة القيم من TextFormField
  TextEditingController useremailcontroller = TextEditingController();
  TextEditingController userpasswordcontroller = TextEditingController();

  // مفتاح الفورم للتحقق (validation)
  final _formkey = GlobalKey<FormState>();

  // دالة تسجيل الدخول
  userLogin() async {
    try {
      // تسجيل الدخول باستخدام Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      // جلب المستخدم الحالي
      User user = FirebaseAuth.instance.currentUser!;

      // تحديث معلومات المستخدم من Firebase
      await user.reload();
      user = FirebaseAuth.instance.currentUser!;

      // التحقق هل الإيميل مؤكد أم لا
      if (!user.emailVerified) {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orangeAccent,
            content: Text(
              "Please verify your email first",
              style: TextStyle(
                fontSize: 18.0,
                color: Colors.black,
                fontFamily: 'Google_Sans_Flex',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        return;
      }

      // جلب معلومات المستخدم من Firestore حسب الإيميل
      var userInfo = await DatabaseMethods().getUserByEmail(
        useremailcontroller.text.trim(),
      );

      // تخزين بيانات المستخدم محلياً
      await SharedPreferenceHelper().saveUserId(user.uid);
      await SharedPreferenceHelper().saveUserName(userInfo["Name"]);
      await SharedPreferenceHelper().saveUserEmail(userInfo["Email"]);
      await SharedPreferenceHelper().saveUserWallet(userInfo["Wallet"]);

      // تأكد أن الصفحة ما انلغت
      if (!mounted) return;

      // الانتقال للصفحة الرئيسية مع حذف صفحة تسجيل الدخول
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BottomNav()),
      );
    } on FirebaseAuthException catch (e) {
      String message = "Email or password is incorrect!";

      if (e.code == 'invalid-credential') {
        message = "Email or password is incorrect!";
      } else if (e.code == 'invalid-email') {
        message = "Please enter a valid email";
      } else if (e.code == 'user-not-found') {
        message = "No user found with this email";
      } else if (e.code == 'wrong-password') {
        message = "Wrong password";
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            message,
            style: TextStyle(
              fontSize: 18.0,
              color: Colors.black,
              fontFamily: 'Google_Sans_Flex',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        // لمنع overflow عند فتح الكيبورد
        child: Container(
          child: Stack(
            children: [
              // الجزء العلوي مع التدرج اللوني
              Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height / 2.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFff5c30), Color(0xFFe74b1a)],
                  ),
                ),
              ),

              // الكرت الأبيض تحت
              Container(
                margin: EdgeInsets.only(
                  top: MediaQuery.of(context).size.height / 3,
                ),
                height: MediaQuery.of(context).size.height / 2,
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40.0),
                    topRight: Radius.circular(40.0),
                  ),
                ),
              ),

              // المحتوى الرئيسي
              Container(
                margin: EdgeInsets.only(top: 60.0, left: 20.0, right: 20.0),
                child: Column(
                  children: [
                    // لوجو التطبيق
                    Center(
                      child: Image.asset(
                        "images/logo.png",
                        width: MediaQuery.of(context).size.width / 1.5,
                        fit: BoxFit.cover,
                      ),
                    ),

                    SizedBox(height: 50.0),

                    // كرت تسجيل الدخول
                    Material(
                      elevation: 5.0,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: EdgeInsets.only(left: 20.0, right: 20.0),
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height / 2,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Form(
                          key: _formkey,
                          child: Column(
                            children: [
                              SizedBox(height: 30.0),

                              // عنوان Login
                              Text(
                                "Login",
                                style: AppWidget.headlineTextFieldStyle(),
                              ),

                              SizedBox(height: 30.0),

                              // حقل الإيميل
                              TextFormField(
                                controller: useremailcontroller,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please Enter Email';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  hintText: 'Email',
                                  hintStyle: AppWidget.semiBoldTextFieldStyle(),
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                              ),

                              SizedBox(height: 30.0),

                              // حقل كلمة المرور
                              TextFormField(
                                controller: userpasswordcontroller,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please Enter Password';
                                  }
                                  return null;
                                },
                                obscureText: true, // إخفاء كلمة المرور
                                decoration: InputDecoration(
                                  hintText: 'Password',
                                  hintStyle: AppWidget.semiBoldTextFieldStyle(),
                                  prefixIcon: Icon(Icons.password_outlined),
                                ),
                              ),

                              SizedBox(height: 20.0),

                              // نسيت كلمة المرور
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ForgotPassword(),
                                    ),
                                  );
                                },
                                child: Container(
                                  alignment: Alignment.topRight,
                                  child: Text(
                                    "Forgot Password?",
                                    style: AppWidget.semiBoldTextFieldStyle(),
                                  ),
                                ),
                              ),

                              SizedBox(height: 50.0),

                              // زر تسجيل الدخول
                              GestureDetector(
                                onTap: () {
                                  if (_formkey.currentState!.validate()) {
                                    setState(() {
                                      email = useremailcontroller.text;
                                      password = userpasswordcontroller.text;
                                    });
                                    userLogin(); // تنفيذ تسجيل الدخول
                                  }
                                },
                                child: Material(
                                  elevation: 5.0,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    width: 200,
                                    decoration: BoxDecoration(
                                      color: Color(0xffff5722),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Center(
                                      child: Text(
                                        "LOGIN",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18.0,
                                          fontFamily: 'Google_Sans_Flex',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: 20.0),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 30.0),
                    // الانتقال لصفحة التسجيل
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?  ",
                          style: AppWidget.semiBoldTextFieldStyle(),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => SignUp()),
                            );
                          },
                          child: Text(
                            "Sign up",
                            style: TextStyle(
                              color: Color(0xffff5722),
                              fontSize: 18.0,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Google_Sans_Flex',
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 15.0),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "You are an admin?  ",
                          style: AppWidget.semiBoldTextFieldStyle(),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminLogin(),
                              ),
                            );
                          },
                          child: Text(
                            "Login",
                            style: TextStyle(
                              color: Color(0xffff5722),
                              fontSize: 18.0,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Google_Sans_Flex',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
