import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/auth/auth_provider.dart';
import '../api/api_client.dart';

/// Opens the camera, uploads the shot to the server, returns its stored name
/// (null when cancelled or failed). Used for meter / bill / receipt photos.
Future<String?> pickAndUploadPhoto(BuildContext context, WidgetRef ref) async {
  final x = await ImagePicker()
      .pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 70);
  if (x == null) return null;
  try {
    final bytes = await x.readAsBytes();
    final res = await ref.read(apiClientProvider).post(
          '/photos',
          data: FormData.fromMap({
            'file': MultipartFile.fromBytes(bytes, filename: x.name),
          }),
        );
    return res.data['path'] as String;
  } catch (_) {
    return null;
  }
}

Map<String, String> _authHeaders(WidgetRef ref) {
  final token = ref.read(authProvider).value?.token;
  return token == null ? {} : {'Authorization': 'Bearer $token'};
}

/// Tap-to-zoom thumbnail for a server-stored photo (sends the auth token).
class PhotoThumb extends ConsumerWidget {
  const PhotoThumb({super.key, required this.name, this.size = 56});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = '$kApiBaseUrl/photos/$name';
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _PhotoViewer(url: url)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          headers: _authHeaders(ref),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: size,
            height: size,
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

class _PhotoViewer extends ConsumerWidget {
  const _PhotoViewer({required this.url});

  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(url, headers: _authHeaders(ref)),
        ),
      ),
    );
  }
}
