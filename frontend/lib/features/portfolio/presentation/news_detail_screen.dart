import 'package:flutter/material.dart';

class NewsDetailScreen extends StatelessWidget {
  const NewsDetailScreen({super.key, required this.news});
  final Map<String, dynamic> news;

  @override
  Widget build(BuildContext context) {
    final title = news['title'] as String? ?? 'Новость';
    final description = news['description'] as String? ?? '';
    final fullText = news['full_text'] as String? ?? description;
    final source = news['source'] as String? ?? '';
    final date = news['date'] as String? ?? '';
    final market = news['market'] as String? ?? '';
    final url = news['url'] as String? ?? '';
    final text = fullText.trim().isNotEmpty ? fullText.trim() : description.trim();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 30),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, size: 32),
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    height: 1.35,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              '$source · $market · $date',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 22),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  text.isEmpty ? 'Текст новости временно недоступен.' : text,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.75),
                ),
              ),
            ),
            if (url.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Оригинал новости:', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              SelectableText(url, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ],
          ],
        ),
      ),
    );
  }
}
