import 'package:flutter/material.dart';
import 'package:smartglass_flutter/core/models/domain/action_hub_result.dart';

class ActionHubTab extends StatelessWidget {
  final ActionHubResult? actionHubResult;

  const ActionHubTab({Key? key, this.actionHubResult}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (actionHubResult == null) {
      return const Center(
        child: Text(
          'No Action Hub Data Available',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final endpoint = actionHubResult!.actionEndpoint;
    final link = actionHubResult!.productLink;
    final image = actionHubResult!.imageUrl;

    return Center(
      child: Card(
        color: Colors.grey[900],
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Endpoint: $endpoint',
                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (image != null && image.isNotEmpty)
                Center(
                  child: Image.network(
                    image,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image, color: Colors.white54, size: 50),
                  ),
                ),
              const SizedBox(height: 12),
              if (link != null && link.isNotEmpty)
                SelectableText(
                  'Link: $link',
                  style: const TextStyle(color: Colors.lightBlue, decoration: TextDecoration.underline),
                ),
              if (link == null && image == null)
                Text(
                  'Payload: ${actionHubResult!.generatedPayload}',
                  style: const TextStyle(color: Colors.white54),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
