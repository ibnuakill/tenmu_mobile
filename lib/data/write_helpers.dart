/// Helpers untuk write operations yang cek jumlah baris yang berubah.
///
/// PostgREST mengembalikan HTTP 200 walau 0 baris terkena (mis. RLS, id tidak
/// ditemukan, atau kolom dilindungi trigger). Helper ini memaksa caller
/// memvalidasi hasil write → lempar exception kalau 0 baris.

/// Error saat PostgREST membalas 200 tapi 0 baris berubah.
class EmptyWriteException implements Exception {
  final String label;
  EmptyWriteException(this.label);
  @override
  String toString() => 'EmptyWriteException: $label (0 rows affected)';
}

/// Jalankan [call] (future PostgREST write yang return List<Map>) dan verifikasi
/// baris yang berubah > 0.
///
/// [label] dipakai di error message. Jika [requireRows] = false, skip cek
/// (berguna untuk write yang memang boleh 0 baris, mis. delete idempotent).
Future<List<Map<String, dynamic>>> verifiedWrite(
  Future<dynamic> call, {
  required String label,
  bool requireRows = true,
}) async {
  final res = await call;
  final rows = (res as List?)?.cast<Map<String, dynamic>>() ?? const [];
  if (requireRows && rows.isEmpty) {
    throw EmptyWriteException(label);
  }
  return rows;
}

/// Shortcut: `.insert(...).select('id')` → return list rows created.
Future<List<Map<String, dynamic>>> verifiedInsert(
  dynamic builder, {
  required String label,
}) async {
  return verifiedWrite(
    builder.select('id'),
    label: label,
    requireRows: true,
  );
}

/// Shortcut: `.update(...).eq(...).select('id')` → return list rows updated.
Future<List<Map<String, dynamic>>> verifiedUpdate(
  dynamic builder, {
  required String label,
}) async {
  return verifiedWrite(
    builder.select('id'),
    label: label,
    requireRows: true,
  );
}

/// Shortcut: `.delete().eq(...).select('id')` → return list rows deleted.
/// [requireRows] default false karena delete idempotent sering dipakai.
Future<List<Map<String, dynamic>>> verifiedDelete(
  dynamic builder, {
  required String label,
  bool requireRows = false,
}) async {
  return verifiedWrite(
    builder.select('id'),
    label: label,
    requireRows: requireRows,
  );
}