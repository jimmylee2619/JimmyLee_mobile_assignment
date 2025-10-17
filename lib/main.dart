import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'photos/data/photo_api_client.dart';
import 'photos/data/photo_local_data_source.dart';
import 'photos/data/photo_repository.dart';
import 'photos/view/photo_page.dart';

void main() {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
  final repository = PhotoRepository(
    apiClient: PhotoApiClient(dio: dio),
    localDataSource: PhotoLocalDataSource(dio: dio),
  );
  runApp(PhotoApp(repository: repository));
}

/// Bootstraps the app and wires the photo repository into the widget tree.
class PhotoApp extends StatelessWidget {
  const PhotoApp({super.key, required this.repository});

  final PhotoRepository repository;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: repository,
      child: MaterialApp(
        title: 'Photo Gallery',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const PhotoPage(),
      ),
    );
  }
}
