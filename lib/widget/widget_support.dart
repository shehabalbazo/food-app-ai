import 'package:flutter/material.dart';
//Tekrarı engellemek için class

class AppWidget {
  
  static TextStyle boldTextFieldStyle() {
    return TextStyle(
      color: Colors.black,
      fontSize: 20.0,
      fontWeight: FontWeight.bold,
      fontFamily: 'Google_Sans_Flex',
    );
  }

  
  static TextStyle headlineTextFieldStyle() {
    return TextStyle(
      color: Colors.black,
      fontSize: 24.0,
      fontWeight: FontWeight.bold,
      fontFamily: 'Google_Sans_Flex',
    );
  }

  
  static TextStyle lightTextFieldStyle() {
    return TextStyle(
      color: Colors.black54,
      fontSize: 15.0,
      fontWeight: FontWeight.w500,
      fontFamily: 'Google_Sans_Flex',
    );
  }

  static TextStyle semiBoldTextFieldStyle() {
    return TextStyle(
      color: Colors.black,
      fontSize: 18.0,
      fontWeight: FontWeight.w500,
      fontFamily: 'Google_Sans_Flex',
    );
  }

}
