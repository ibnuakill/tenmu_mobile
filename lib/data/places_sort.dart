/// Urutan sort + pemetaannya ke nilai yang dikenali SQL.
///
/// Dipisah dari provider supaya bisa dites tanpa Supabase.
///
/// PENTING: RPC `get_places_paged` hanya mengenal `'distance' | 'rating' |
/// 'newest'`. Mengirim `SortMode.name` mentah (`'terdekat'`) membuat server
/// fallback ke urutan default — inilah bug "sort terdekat selalu terbaru".
enum SortMode { terbaru, terdekat, rating }

/// Nilai `p_sort` untuk RPC `get_places_paged`.
String sqlSortFor(SortMode sort) => switch (sort) {
  SortMode.terdekat => 'distance',
  SortMode.rating => 'rating',
  SortMode.terbaru => 'newest',
};

/// Label Indonesia untuk UI.
String labelForSort(SortMode sort) => switch (sort) {
  SortMode.terdekat => 'Terdekat',
  SortMode.rating => 'Rating tertinggi',
  SortMode.terbaru => 'Terbaru',
};