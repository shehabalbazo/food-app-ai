import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_delivery_app/service/database.dart';
import 'package:food_delivery_app/service/shared_pref.dart';
import 'package:food_delivery_app/widget/widget_support.dart';

class Order extends StatefulWidget {
  const Order({super.key});

  @override
  State<Order> createState() => _OrderState();
}

class _OrderState extends State<Order> {
  String? id, wallet;
  int total = 0, amount2 = 0;

  Timer? _timer;

  void startTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        amount2 = total;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  getthesharedpref() async {
    id = await SharedPreferenceHelper().getUserId();
    wallet = await SharedPreferenceHelper().getUserWallet();
    if (!mounted) return;
    setState(() {});
  }

  ontheload() async {
    await getthesharedpref();
    if (id == null) return;
    foodStream = await DatabaseMethods().getFoodCart(id!);
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    ontheload();
    startTimer();
    super.initState();
  }

  Stream? foodStream;

  Widget foodCart() {
    return StreamBuilder(
      stream: foodStream,
      builder: (context, AsyncSnapshot snapshot) {
        return snapshot.hasData
            ? Builder(
                builder: (context) {
                  final docs = snapshot.data.docs as List;
                  int newTotal = 0;
                  for (final d in docs) {
                    newTotal += int.parse(d["Total"]);
                  }

                  // حدث total بشكل آمن
                  if (total != newTotal) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() {
                        total = newTotal;
                        amount2 = newTotal; // خليه يساوي total مباشرة
                      });
                    });
                  }

                  return ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: docs.length,
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      DocumentSnapshot ds = docs[index];
                      return Container(
                        margin: EdgeInsets.only(
                          left: 20.0,
                          right: 20.0,
                          bottom: 10.0,
                        ),
                        child: Material(
                          borderRadius: BorderRadius.circular(10),
                          elevation: 5.0,
                          child: Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  height: 90,
                                  width: 40,
                                  decoration: BoxDecoration(
                                    border: Border.all(),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(child: Text(ds["Quantity"])),
                                ),

                                SizedBox(width: 20.0),

                                ClipRRect(
                                  borderRadius: BorderRadius.circular(60),
                                  child: Image.network(
                                    ds["Image"],
                                    height: 90,
                                    width: 90,
                                    fit: BoxFit.cover,
                                  ),
                                ),

                                SizedBox(width: 20.0),

                                Column(
                                  children: [
                                    Text(
                                      ds["Name"],
                                      style: AppWidget.semiBoldTextFieldStyle(),
                                    ),
                                    Text(
                                      "\$" + ds["Total"],
                                      style: AppWidget.semiBoldTextFieldStyle(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              )
            : const Center(child: CircularProgressIndicator());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: EdgeInsets.only(top: 60.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              elevation: 2.0,
              child: Container(
                padding: EdgeInsets.only(bottom: 10.0),
                child: Center(
                  child: Text(
                    "Food Cart",
                    style: AppWidget.headlineTextFieldStyle(),
                  ),
                ),
              ),
            ),

            SizedBox(height: 20.0),

            Container(
              height: MediaQuery.of(context).size.height / 2,
              child: foodCart(),
            ),

            Spacer(),
            Divider(),

            Padding(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Total Price", style: AppWidget.boldTextFieldStyle()),
                  Text(
                    "\$" + total.toString(),
                    style: AppWidget.semiBoldTextFieldStyle(),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20.0),

            //الرصيد
            GestureDetector(
              onTap: () async {
                if (wallet == null || id == null) return;

                final currentWallet = int.tryParse(wallet!) ?? 0;
                final newAmount = currentWallet - total;

                if (newAmount < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Insufficient balance! Please add money to your wallet.",
                        style: TextStyle(
                          fontSize: 18.0,
                          color: Colors.orangeAccent,
                          fontFamily: 'Google_Sans_Flex',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                  return;
                }

                await DatabaseMethods().UpdateUserwallet(
                  id!,
                  newAmount.toString(),
                );
                await SharedPreferenceHelper().saveUserWallet(
                  newAmount.toString(),
                );

                setState(() {
                  wallet = newAmount.toString(); // لتحديث الشاشة مباشرة
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10.0),
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: EdgeInsets.only(left: 20.0, right: 20.0, bottom: 20.0),
                child: Center(
                  child: Text(
                    "CheckOut",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Google_Sans_Flex',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
