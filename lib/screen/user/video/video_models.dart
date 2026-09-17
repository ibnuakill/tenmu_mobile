/// Model untuk fitur video pendek UMKM (tabel `place_videos`).
class PlaceVideo {
  final int id;
  final int placeId;
  final String ownerId;
  final String videoPath; // path di bucket 'videos'
  final String? thumbnailPath;
  final String? caption;
  final int views;
  final bool isActive;
  final DateTime createdAt;
  final Map<String, dynamic>? place; // hasil join `place:places`

  const PlaceVideo({
    required this.id,
    required this.placeId,
    required this.ownerId,
    required this.videoPath,
    this.thumbnailPath,
    this.caption,
    this.views = 0,
    this.isActive = true,
    required this.createdAt,
    this.place,
  });

  factory PlaceVideo.fromJson(Map<String, dynamic> json) {
    return PlaceVideo(
      id: (json['id'] as num).toInt(),
      placeId: (json['place_id'] as num).toInt(),
      ownerId: json['owner_id'] as String,
      videoPath: json['video_path'] as String,
      thumbnailPath: json['thumbnail_path'] as String?,
      caption: json['caption'] as String?,
      views: (json['views'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      place: json['place'] as Map<String, dynamic>?,
    );
  }

  String get placeName {
    final p = place;
    if (p == null) return 'Tempat';
    return (p['nama_tempat'] as String?)?.isNotEmpty == true
        ? p['nama_tempat'] as String
        : 'Tempat';
  }

  String get placeCategory => place?['category'] as String? ?? '';
}