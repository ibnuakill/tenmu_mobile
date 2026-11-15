-- ============================================================================
-- Seed 5 artikel contoh Portal UMKM Cirebon
-- Sumber: cirebonkab.go.id, tempo.co, detik.com, indonesia.travel, rri.co.id
-- Cover: Wikimedia Commons (URL absolut — didukung Article.getCoverUrl())
-- Idempotent: pakai ON CONFLICT (slug) DO NOTHING
-- ============================================================================

insert into public.articles
  (title, slug, excerpt, content, cover_image_path, category, kecamatan,
   is_published, published_at, author_id, view_count)
values
(
  'PKU Akbar Dorong UMKM Kabupaten Cirebon Tumbuh dan Naik Kelas',
  'pku-akbar-dorong-umkm-cirebon-naik-kelas',
  'Ratusan pelaku usaha ultra mikro Cirebon ikut Pengembangan Kapasitas Usaha (PKU) Akbar untuk memperkuat modal, literasi keuangan, dan akses pasar.',
  $md$Pelaku Usaha Mikro, Kecil, dan Menengah (UMKM) di Cirebon terus didorong naik kelas. Salah satu jalannya lewat kegiatan **Pengembangan Kapasitas Usaha (PKU) Akbar** yang digelar bersama PT Permodalan Nasional Madani (PNM) Cabang Cirebon.

## Bukan Sekadar Bertahan

Pemerintah Kabupaten Cirebon menekankan bahwa peran UMKM tidak hanya soal pertumbuhan ekonomi. UMKM juga menyerap tenaga kerja, menambah pendapatan keluarga, dan menguatkan ekonomi desa sampai kecamatan.

> "Mari kita ubah pola pikir dari sekadar bagaimana usaha tetap berjalan, menjadi bagaimana usaha bisa berkembang, naik kelas, membuka lapangan kerja, dan memiliki pasar yang lebih luas."

## Apa Saja yang Dilatih?

Peserta PKU Akbar menerima pendampingan teknis maupun non-teknis, antara lain:

- Pelatihan membatik dan kerajinan topeng
- Pengolahan kuliner khas Cirebon
- Literasi keuangan, termasuk memisahkan uang usaha dan pribadi
- Digitalisasi usaha dan pengemasan produk
- Fasilitasi perizinan serta sertifikasi halal

## Kenapa Penting untuk Cirebon?

Cirebon punya basis usaha ultra mikro yang besar, sebagian besar digerakkan perempuan nasabah program Mekaar dan ULaMM. Pendampingan berkelanjutan membuat pelaku usaha tidak berhenti sebagai perintis, tapi tumbuh mandiri dan siap bersaing di tingkat nasional.

## Cara Ikut Program serupa

1. Daftar sebagai nasabah/pelaku usaha binaan lewat kantor cabang PNM terdekat.
2. Ikuti rangkaian pelatihan rutin sepanjang tahun.
3. Manfaatkan pendampingan produk, kemasan, pemasaran, sampai sertifikasi halal.

*Sumber: [cirebonkab.go.id](https://cirebonkab.go.id/pku-akbar-dorong-umkm-kabupaten-cirebon-tumbuh-dan-naik-kelas/), [rri.co.id](https://rri.co.id/cirebon/ekonomi/umkm/2371213/pnm-gelar-pku-akbar-2026-250-umkm-didorong-naik-kelas), [radarcirebon.com](https://radarcirebon.disway.id/kabupaten-cirebon/read/208394/dorong-umkm-naik-kelas-bupati-imron-apresiasi-program-pku-pnm-di-kabupaten-cirebon)*$md$,
  'https://thumb.wikimedia.org/wikipedia/commons/thumb/f/fa/Heating_Batik_Wax_%28Malam%29_with_Canting_in_a_Traditional_Workshop%2C_Trusmi_Cirebon.jpg/1280px-Heating_Batik_Wax_%28Malam%29_with_Canting_in_a_Traditional_Workshop%2C_Trusmi_Cirebon.jpg',
  'event', 'kejaksan', true, now(), (select id from public.profiles where role = 'superadmin' limit 1), 128
),
(
  'Empal Gentong, Kuliner Legendaris Cirebon dari Gentong Tanah Liat',
  'empal-gentong-kuliner-legendaris-cirebon',
  'Dimasak di gentong tanah liat dengan kayu bakar sampai lima jam. Begini sejarah dan cara menikmati empal gentong yang sudah ada sejak abad ke-15.',
  $md$Kalau ada satu makanan yang paling mewakili Cirebon, **empal gentong** adalah jawabannya. Kuahnya mirip gulai — kental, berwarna kekuningan, beraroma rempah kuat — tapi cara memasaknya yang bikin beda.

## Dimasak di Gentong, Bukan Panci

Daging dan jeroan sapi dimasak di dalam **gentong tanah liat** di atas kayu bakar. Prosesnya bisa sampai lima jam. Karena api dan wadahnya tradisional, bumbu rempah meresap sempurna ke daging maupun ke kuahnya.

Seporsi empal gentong biasanya disajikan dengan:

- potongan daging sapi empuk (`empal`)
- jeroan sapi
- lontong atau nasi
- taburan bawang goreng dan kerupuk
- sambal dan acar sebagai pendamping

## Jejak Sejarah

Empal gentong diperkirakan sudah ada sejak **abad ke-15** dan dipercaya ikut berperan dalam penyebaran Islam di Cirebon. Dulu daging yang dipakai adalah daging kerbau, karena sapi dianggap hewan sakral bagi penganut Hindu yang saat itu masih banyak di Cirebon. Dari kuahnya yang berempah, hidangan ini jelas dipengaruhi masakan Arab dan India.

Salah satu penjual legendarisnya adalah **Empal Gentong H. Apud**, yang mulai berjualan pada 1994 dengan gentong tanah liat dipikul keliling pusat Kota Cirebon. Pada 2002 ia berinovasi menciptakan **empal asam**, mengganti santan dengan belimbing wuluh.

## Tips Menikmati

1. Datang sebelum jam makan siang — porsi populer cepat habis.
2. Minta kuah terpisah kalau tidak suka terlalu berminyak.
3. Coba juga **empal asam** untuk rasa yang lebih segar.

*Sumber: [tempo.co](https://www.tempo.co/gaya-hidup/singgah-ke-cirebon-saat-libur-lebaran-jangan-lupa-cicip-tiga-kuliner-lezat-dan-bersejarah-ini--67868), [travel.kompas.com](https://travel.kompas.com/read/2017/09/06/220400827/perjalanan-resep-empal-gentong-haji-apud-sejak-1994), [food.detik.com](https://food.detik.com/foto-kuliner/d-8659690/8-kuliner-legendaris-di-cirebon-yang-mantap-sejak-puluhan-tahun-ini-daftarnya)*$md$,
  'https://thumb.wikimedia.org/wikipedia/commons/thumb/0/0a/Indonesian_soup-Empal_Gentong-01.jpg/1280px-Indonesian_soup-Empal_Gentong-01.jpg',
  'kuliner', 'kejaksan', true, now(), (select id from public.profiles where role = 'superadmin' limit 1), 341
),
(
  'Nasi Jamblang: Berawal dari Sedekah untuk Buruh Jalan Raya Pos',
  'nasi-jamblang-sedekah-buruh-jalan-raya-pos',
  'Nasi bungkus daun jati yang murah meriah. Ternyata awalnya disajikan untuk buruh kerja paksa zaman Belanda yang membangun Jalan Raya Pos.',
  $md$**Nasi Jamblang** adalah nasi campur khas Cirebon yang harganya ramah kantong, tapi punya cerita panjang. Namanya diambil dari daerah Jamblang, Cirebon.

## Yang Bikin Beda: Daun Jati

Nasi putih panas dibungkus **daun jati**, bukan kertas minyak atau daun pisang. Aroma daun jati inilah yang membuat nasi jamblang punya wangi khas dan tidak cepat basi.

Isiannya bebas dipilih sendiri, dengan porsi kecil-kecil supaya bisa cicip banyak jenis lauk:

- sambal goreng, taoco, dan tempe
- tahu, ikan asin, dan cumi hitam (blakutak)
- sate kentang, paru, dan pepes

## Sejarahnya Bukan Cerita Manis

Keberadaan nasi jamblang berawal dari pembangunan **pabrik gula Gempol dan pabrik spirtus Palimanan** era kolonial Belanda sekitar 1847. Ada juga versi yang mengaitkannya dengan pembangunan **Jalan Raya Pos** Anyer–Panarukan yang melewati Cirebon dan menyerap banyak pekerja.

Waktu itu pekerja sulit mencari penjual nasi — ada anggapan bahwa menjual nasi itu terlarang. Karena itu **H. Abdulatif dan istrinya, Tan Piaw Lun (Mbah Pulung)**, membuat nasi bungkus daun jati beserta lauk-pauknya untuk dibagikan sebagai sedekah kepada para pekerja. Lama-lama pekerja memberi imbalan sekadarnya, dan sejak itu nasi jamblang jadi dagangan.

## Di Mana Menikmatinya?

Beberapa penjual legendaris yang sudah puluhan tahun berjualan antara lain **Nasi Jamblang Mang Dul** (berdiri sejak 1970) dan sejumlah warung di kawasan Jamblang. Pilih langsung lauknya di depan, lalu bayar sesuai yang diambil.

*Sumber: [tempo.co](https://www.tempo.co/gaya-hidup/asal-usul-nasi-jamblang-khas-cirebon-awalnya-disajikan-untuk-buruh-pembuat-jalan-daendels--164848), [cnnindonesia.com](https://www.cnnindonesia.com/gaya-hidup/20231128131811-267-1029985/15-rekomendasi-makanan-khas-cirebon-legendaris), [food.detik.com](https://food.detik.com/foto-kuliner/d-8659690/8-kuliner-legendaris-di-cirebon-yang-mantap-sejak-puluhan-tahun-ini-daftarnya)*$md$,
  'https://thumb.wikimedia.org/wikipedia/commons/thumb/4/42/Nasi_Jamblang_%2853275432023%29.jpg/1280px-Nasi_Jamblang_%2853275432023%29.jpg',
  'kuliner', 'harjamukti', true, now(), (select id from public.profiles where role = 'superadmin' limit 1), 267
),
(
  'Keraton Kasepuhan, Jejak Kesultanan Cirebon Sejak 1529',
  'keraton-kasepuhan-jejak-kesultanan-cirebon',
  'Kompleks keraton berdinding bata merah peninggalan Sunan Gunung Jati, lengkap dengan Kereta Singa Barong. Tiket mulai Rp20.000.',
  $md$**Keraton Kasepuhan** adalah salah satu jejak paling utuh Kesultanan Cirebon. Didirikan pada **1529** oleh Pangeran Mas Zainul Arifin, kompleks ini dulu pusat pemerintahan sekaligus pusat dakwah Islam.

## Yang Bisa Dilihat

Bangunan kuno berdinding **bata merah** masih terawat baik dan kini difungsikan sebagai museum budaya. Koleksi andalannya:

- **Kereta Singa Barong** — kereta kencana peninggalan Sunan Gunung Jati
- senjata tradisional dan lukisan bersejarah
- arsitektur gabungan Jawa, Sunda, dan Islam
- halaman dan taman keraton yang asri

## Info Kunjungan

| Keterangan | Detail |
|---|---|
| Alamat | Kelurahan Kesepuhan, Kecamatan Lemahwungkuk, Kota Cirebon |
| Jam buka | Setiap hari, 08.00–17.00 WIB |
| Tiket | Mulai Rp20.000 per orang |

## Tips

1. Datang pagi supaya tidak kepanasan dan lebih leluasa memotret.
2. Pakai pemandu lokal kalau ingin tahu detail filosofi tiap bangunan.
3. Lanjut ke **Keraton Kanoman** yang hanya berjarak sekitar 600 meter.

*Sumber: [indonesia.travel](https://www.indonesia.travel/id/id/travel-ideas/heritage/tempat-bersejarah-di-cirebon), [idntimes.com](https://jabar.idntimes.com/travel/destination/destinasi-wisata-sejarah-di-cirebon-yang-wajib-dikunjungi-00-wrtcb-00c68x)*$md$,
  'https://thumb.wikimedia.org/wikipedia/commons/thumb/5/54/Keraton_Kasepuhan%2C_Cirebon_-_panoramio.jpg/1280px-Keraton_Kasepuhan%2C_Cirebon_-_panoramio.jpg',
  'wisata', 'lemahwungkuk', true, now(), (select id from public.profiles where role = 'superadmin' limit 1), 195
),
(
  'Gua Sunyaragi, Pesanggrahan Batu Karang Sultan Cirebon',
  'gua-sunyaragi-pesanggrahan-batu-karang',
  'Bangunan kuno dari batu karang di atas lahan 15 hektare. Dulu tempat bertapa keluarga keraton, sekarang cagar budaya yang instagramable.',
  $md$**Taman Sari Gua Sunyaragi** sering disebut sebagai satu-satunya bangunan kuno Cirebon yang terbuat dari **batu karang**. Lokasinya di Kelurahan Sunyaragi, Kecamatan Kesambi.

## Dibangun untuk Apa?

Gua Sunyaragi dibangun sekitar **1703** oleh Pangeran Karang Asem (versi lain menyebut Pangeran Kararangen, cicit Sunan Gunung Jati). Fungsinya:

- tempat **pertapaan** dan meditasi keluarga keraton
- tempat peristirahatan raja dan permaisuri
- lokasi pelatihan ilmu kanuragan dan persiapan strategi perang
- pesanggrahan bagi para sultan dan petinggi kerajaan

## Bentuknya

Kompleks seluas **15 hektare** ini terdiri dari dua area utama: area Pesanggrahan dan **10 gua** buatan yang dipahat dari batuan karang dan batu padas. Setiap gua punya nama dan makna filosofinya sendiri — menarik untuk ditelusuri sambil jalan santai.

## Info Kunjungan

- **Alamat:** Jalan By Pass Brigjen Dharsono, Sunyaragi, Kecamatan Kesambi, Kota Cirebon
- **Jam buka:** 08.00–17.00 WIB
- **Tiket:** mulai Rp15.000 per orang

## Tips

1. Pakai alas kaki nyaman — medannya bebatuan.
2. Datang sore untuk cahaya terbaik saat difoto.
3. Cocok dikombinasikan dengan wisata kuliner di pusat kota, sekitar 10 menit berkendara.

*Sumber: [indonesia.travel](https://www.indonesia.travel/id/id/travel-ideas/heritage/tempat-bersejarah-di-cirebon), [antaranews.com](https://jabar.antaranews.com/berita/586525/8-tempat-ngabuburit-seru-di-cirebon-wisata-religi-sejarah-dan-kuliner-dalam-satu-kota?page=all)*$md$,
  'https://thumb.wikimedia.org/wikipedia/commons/thumb/9/96/Sunyaragi_in_2021_03.jpg/1280px-Sunyaragi_in_2021_03.jpg',
  'hidden_gem', 'kesambi', true, now(), (select id from public.profiles where role = 'superadmin' limit 1), 88
)
on conflict (slug) do nothing;
