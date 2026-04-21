import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfExtractionService {
  Future<String?> pickAndExtractPdfText() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        return extractTextFromPdf(result.files.single.path!);
      }
    } catch (e) {
      print('Error picking PDF file: $e');
    }
    return null;
  }

  Future<String> extractTextFromPdf(String filePath) async {
    try {
      // Load the PDF document.
      final PdfDocument document = PdfDocument(inputBytes: File(filePath).readAsBytesSync());

      // Extract the text from all the pages.
      String text = PdfTextExtractor(document).extractText();

      // Dispose the document.
      document.dispose();

      return text;
    } catch (e) {
      print('Error extracting PDF text: $e');
      throw Exception('Failed to extract text from PDF document: $e');
    }
  }
}
