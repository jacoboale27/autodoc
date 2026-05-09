import 'package:flutter/services.dart';

class PlateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.toUpperCase();
    
    // Remove existing hyphens to recalculate
    text = text.replaceAll('-', '');
    
    // Limit to 7-8 characters (e.g. P123-456 or 1234-567)
    if (text.length > 8) {
      text = text.substring(0, 8);
    }
    
    var formatted = '';
    
    // Rule: If starts with a letter, hyphen after 4th char (e.g. P123-456)
    // If starts with a number, hyphen after 3rd char (e.g. 123-456)
    // BUT the user specifically asked: "cuando se pongan tres numeros se ponga un guión"
    // Let's assume they mean after the first block of characters.
    
    if (text.isNotEmpty) {
      bool startsWithLetter = RegExp(r'^[A-Z]').hasMatch(text);
      int hyphenIndex = startsWithLetter ? 4 : 3;
      
      if (text.length > hyphenIndex) {
        formatted = '${text.substring(0, hyphenIndex)}-${text.substring(hyphenIndex)}';
      } else {
        formatted = text;
      }
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
