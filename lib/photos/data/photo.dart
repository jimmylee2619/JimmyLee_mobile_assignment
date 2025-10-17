import 'package:equatable/equatable.dart';

/// Domain model representing a photo fetched from the API.
class Photo extends Equatable {
  const Photo({
    required this.id,
    required this.url,
    required this.description,
    required this.location,
    required this.createdBy,
    required this.createdAt,
    required this.takenAt,
    this.localImagePath,
  });

  /// Unique identifier.
  final String id;

  /// Public URL for the photo asset.
  final String url;

  /// Human readable description.
  final String description;

  /// Location metadata recorded for the photo.
  final String location;

  /// Uploader or photographer name.
  final String createdBy;

  /// Timestamp when the record was created server-side.
  final DateTime createdAt;

  /// Timestamp when the photo was actually taken.
  final DateTime takenAt;

  /// Local file path after a successful download, if available.
  final String? localImagePath;

  /// Builds an instance from raw JSON.
  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'] as String,
      url: json['url'] as String,
      description: json['description'] as String? ?? '',
      location: json['location'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      takenAt: DateTime.parse(json['takenAt'] as String),
      localImagePath: json['localImagePath'] as String?,
    );
  }

  /// Serializes the model into JSON for testing or persistence.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'description': description,
      'location': location,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'takenAt': takenAt.toIso8601String(),
      'localImagePath': localImagePath,
    };
  }

  /// Creates a new instance with selectively overridden fields.
  Photo copyWith({
    String? id,
    String? url,
    String? description,
    String? location,
    String? createdBy,
    DateTime? createdAt,
    DateTime? takenAt,
    String? localImagePath,
    bool clearLocalImagePath = false,
  }) {
    return Photo(
      id: id ?? this.id,
      url: url ?? this.url,
      description: description ?? this.description,
      location: location ?? this.location,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      takenAt: takenAt ?? this.takenAt,
      localImagePath:
          clearLocalImagePath ? null : localImagePath ?? this.localImagePath,
    );
  }

  @override
  List<Object?> get props => [
    id,
    url,
    description,
    location,
    createdBy,
    createdAt,
    takenAt,
    localImagePath,
  ];
}
