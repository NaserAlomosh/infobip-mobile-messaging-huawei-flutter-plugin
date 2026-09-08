import 'package:flutter/material.dart';
import '../setup/feature_readiness.dart';

class ReadinessCard extends StatelessWidget {
  const ReadinessCard({
    required this.readiness,
    required this.onOpen,
    this.children = const [],
    super.key,
  });
  final FeatureReadiness readiness;
  final VoidCallback? onOpen;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(readiness.name, style: Theme.of(context).textTheme.titleMedium),
          Text(readiness.isReady ? 'READY ✅' : 'NOT READY'),
          if (!readiness.isReady) ...[
            const Text('Missing:'),
            ...readiness.missing.map((r) => Text('• ${r.title}')),
          ],
          ...children,
          const SizedBox(height: 8),
          FilledButton(
            key: ValueKey('open-${readiness.name}'),
            onPressed: readiness.isReady ? onOpen : null,
            child: Text('Open ${readiness.name}'),
          ),
        ],
      ),
    ),
  );
}
