import 'package:flutter/material.dart';

import 'request_quote_screen.dart';

/// This screen was previously a static demo.
/// Keep route compatibility but render the real API-backed request flow.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RequestQuoteScreen();
  }
}
