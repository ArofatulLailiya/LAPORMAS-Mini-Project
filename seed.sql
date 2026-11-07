-- 1. DATA WILAYAH

INSERT INTO areas (
    village_name,
    district_name,
    regency_name,
    boundary_geojson
)
VALUES (
    'Keputih',
    'Sukolilo',
    'Surabaya',
    '{
        "type": "Polygon",
        "coordinates": [[
            [112.78, -7.30],
            [112.82, -7.30],
            [112.82, -7.26],
            [112.78, -7.26],
            [112.78, -7.30]
        ]]
    }'::jsonb
)
ON CONFLICT (village_name, district_name, regency_name)
DO NOTHING;


-- 2. DATA PENGGUNA

INSERT INTO users (full_name, email, password_hash, role)
VALUES
    (
        'Warga Demo',
        'warga.demo@lapormas.test',
        'DUMMY_HASH_NOT_FOR_LOGIN',
        'warga'
    ),
    (
        'Petugas Demo',
        'petugas.demo@lapormas.test',
        'DUMMY_HASH_NOT_FOR_LOGIN',
        'petugas'
    ),
    (
        'Admin Demo',
        'admin.demo@lapormas.test',
        'DUMMY_HASH_NOT_FOR_LOGIN',
        'admin'
    )
ON CONFLICT (email) DO NOTHING;


-- 3. DATA PROFIL PENGGUNA

INSERT INTO user_profiles (
    user_id,
    phone,
    address,
    area_id
)
SELECT
    u.user_id,
    '081234567890',
    'Alamat contoh, Keputih',
    a.area_id
FROM users u
CROSS JOIN areas a
WHERE u.email IN (
    'warga.demo@lapormas.test',
    'petugas.demo@lapormas.test',
    'admin.demo@lapormas.test'
)
AND a.village_name = 'Keputih'
AND a.district_name = 'Sukolilo'
AND a.regency_name = 'Surabaya'
ON CONFLICT (user_id)
DO NOTHING;


-- 4. DATA KATEGORI LAPORAN

INSERT INTO report_categories (category_name, description)
VALUES
    (
        'Jalan Rusak',
        'Kerusakan jalan di lingkungan masyarakat.'
    ),
    (
        'Sampah Menumpuk',
        'Penumpukan sampah yang mengganggu lingkungan.'
    ),
    (
        'Pohon Tumbang',
        'Pohon tumbang yang mengganggu akses atau membahayakan warga.'
    ),
    (
        'Lampu Jalan Mati',
        'Lampu penerangan jalan umum tidak berfungsi.'
    ),
    (
        'Saluran Air Tersumbat',
        'Saluran air yang tersumbat dan menghambat aliran air.'
    ),
    (
        'Banjir',
        'Genangan atau banjir di lingkungan masyarakat.'
    ),
    (
        'Kerusakan Fasilitas Umum',
        'Kerusakan fasilitas umum yang digunakan masyarakat.'
    )
ON CONFLICT (category_name) DO NOTHING;


-- 5. DATA STATUS LAPORAN

INSERT INTO report_statuses (status_name, description)
VALUES
    (
        'Dikirim',
        'Laporan berhasil dikirim oleh warga.'
    ),
    (
        'Diverifikasi',
        'Laporan sedang diperiksa oleh petugas.'
    ),
    (
        'Diproses',
        'Laporan sedang dalam proses penanganan.'
    ),
    (
        'Selesai',
        'Permasalahan telah selesai ditangani.'
    ),
    (
        'Ditolak',
        'Laporan tidak dapat ditindaklanjuti.'
    )
ON CONFLICT (status_name) DO NOTHING;


-- 6. DATA UNIT PENANGGUNG JAWAB

INSERT INTO responsible_units (
    unit_name,
    description,
    contact
)
VALUES
    (
        'Dinas Pekerjaan Umum',
        'Unit yang berkaitan dengan penanganan jalan rusak.',
        'Kontak contoh'
    ),
    (
        'Dinas Lingkungan Hidup',
        'Unit yang berkaitan dengan kebersihan dan lingkungan.',
        'Kontak contoh'
    ),
    (
        'Dinas Perhubungan',
        'Unit yang berkaitan dengan penerangan dan fasilitas jalan.',
        'Kontak contoh'
    ),
    (
        'Unit Pengelola Drainase',
        'Unit yang berkaitan dengan saluran air dan drainase.',
        'Kontak contoh'
    ),
    (
        'Badan Penanggulangan Bencana Daerah',
        'Unit yang berkaitan dengan penanganan banjir dan bencana.',
        'Kontak contoh'
    ),
    (
        'Unit Pengelola Fasilitas Umum',
        'Unit yang berkaitan dengan pemeliharaan fasilitas umum.',
        'Kontak contoh'
    )
ON CONFLICT (unit_name) DO NOTHING;


-- =====================================================
-- DATA CONTOH LAPORAN LAPORMAS
-- =====================================================

-- 1. MENAMBAHKAN LAPORAN BARU

INSERT INTO reports (
    user_id,
    category_id,
    status_id,
    area_id,
    title,
    description,
    location,
    latitude,
    longitude
)
SELECT
    u.user_id,
    c.category_id,
    s.status_id,
    a.area_id,
    'Jalan Rusak di Jalan Keputih',
    'Terdapat kerusakan pada permukaan jalan yang dapat mengganggu aktivitas pengguna jalan.',
    'Jalan Keputih, Kelurahan Keputih, Kecamatan Sukolilo, Surabaya',
    -7.2820000,
    112.7920000
FROM users u
CROSS JOIN report_categories c
CROSS JOIN report_statuses s
CROSS JOIN areas a
WHERE u.email = 'warga.demo@lapormas.test'
  AND c.category_name = 'Jalan Rusak'
  AND s.status_name = 'Dikirim'
  AND a.village_name = 'Keputih'
  AND a.district_name = 'Sukolilo'
  AND a.regency_name = 'Surabaya'
  AND NOT EXISTS (
      SELECT 1
      FROM reports r
      WHERE r.user_id = u.user_id
        AND r.title = 'Jalan Rusak di Jalan Keputih'
  );


-- 2. MENAMBAHKAN FOTO BUKTI LAPORAN

INSERT INTO report_images (
    report_id,
    image_url
)
SELECT
    r.report_id,
    'https://example.com/dummy-jalan-rusak.jpg'
FROM reports r
JOIN users u ON u.user_id = r.user_id
WHERE u.email = 'warga.demo@lapormas.test'
  AND r.title = 'Jalan Rusak di Jalan Keputih'
  AND NOT EXISTS (
      SELECT 1
      FROM report_images ri
      WHERE ri.report_id = r.report_id
  );


-- 3. MENAMBAHKAN RIWAYAT STATUS AWAL

INSERT INTO report_updates (
    report_id,
    updated_by,
    old_status_id,
    new_status_id,
    notes
)
SELECT
    r.report_id,
    u.user_id,
    NULL,
    s.status_id,
    'Status awal saat laporan dikirim oleh warga.'
FROM reports r
JOIN users u ON u.user_id = r.user_id
JOIN report_statuses s ON s.status_name = 'Dikirim'
WHERE u.email = 'warga.demo@lapormas.test'
  AND r.title = 'Jalan Rusak di Jalan Keputih'
  AND NOT EXISTS (
      SELECT 1
      FROM report_updates ru
      WHERE ru.report_id = r.report_id
        AND ru.notes = 'Status awal saat laporan dikirim oleh warga.'
  );


