-- 1. TABEL AREAS
-- Menyimpan informasi wilayah

CREATE TABLE areas (
    area_id SERIAL PRIMARY KEY,
    village_name VARCHAR(100) NOT NULL,
    district_name VARCHAR(100) NOT NULL,
    regency_name VARCHAR(100) NOT NULL,
    boundary_geojson JSONB NOT NULL,

    CONSTRAINT uq_area_location
        UNIQUE (village_name, district_name, regency_name)
);


-- 2. TABEL USERS
-- Menyimpan akun warga, petugas, dan admin

CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role VARCHAR(20) NOT NULL
        CHECK (role IN ('warga', 'petugas', 'admin')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);


-- 3. TABEL USER_PROFILES
-- Menyimpan informasi tambahan pengguna

CREATE TABLE user_profiles (
    user_id INTEGER PRIMARY KEY,
    phone VARCHAR(20),
    address TEXT,
    area_id INTEGER NOT NULL,

    CONSTRAINT fk_user_profiles_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_user_profiles_area
        FOREIGN KEY (area_id)
        REFERENCES areas(area_id)
);


-- 4. TABEL REPORT_CATEGORIES
-- Menyimpan kategori permasalahan lingkungan

CREATE TABLE report_categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT
);


-- 5. TABEL REPORT_STATUSES
-- Menyimpan daftar status penanganan laporan

CREATE TABLE report_statuses (
    status_id SERIAL PRIMARY KEY,
    status_name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT
);


-- 6. TABEL RESPONSIBLE_UNITS
-- Menyimpan unit atau pihak penanggung jawab

CREATE TABLE responsible_units (
    unit_id SERIAL PRIMARY KEY,
    unit_name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    contact VARCHAR(100)
);


-- 7. TABEL REPORTS
-- Menyimpan laporan permasalahan dari warga

CREATE TABLE reports (
    report_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    category_id INTEGER NOT NULL,
    status_id INTEGER NOT NULL,
    area_id INTEGER NOT NULL,
    title VARCHAR(150) NOT NULL,
    description TEXT NOT NULL,
    location TEXT NOT NULL,

    latitude NUMERIC(10,7) NOT NULL
        CHECK (latitude BETWEEN -90 AND 90),

    longitude NUMERIC(10,7) NOT NULL
        CHECK (longitude BETWEEN -180 AND 180),

    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_reports_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id),

    CONSTRAINT fk_reports_category
        FOREIGN KEY (category_id)
        REFERENCES report_categories(category_id),

    CONSTRAINT fk_reports_status
        FOREIGN KEY (status_id)
        REFERENCES report_statuses(status_id),

    CONSTRAINT fk_reports_area
        FOREIGN KEY (area_id)
        REFERENCES areas(area_id)
);


-- 8. TABEL REPORT_IMAGES
-- Menyimpan foto atau bukti laporan

CREATE TABLE report_images (
    image_id SERIAL PRIMARY KEY,
    report_id INTEGER NOT NULL,
    image_url TEXT NOT NULL,
    uploaded_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_report_images_report
        FOREIGN KEY (report_id)
        REFERENCES reports(report_id)
        ON DELETE CASCADE
);


-- 9. TABEL REPORT_UPDATES
-- Menyimpan riwayat perubahan status laporan

CREATE TABLE report_updates (
    update_id SERIAL PRIMARY KEY,
    report_id INTEGER NOT NULL,
    updated_by INTEGER NOT NULL,
    old_status_id INTEGER,
    new_status_id INTEGER NOT NULL,
    notes TEXT,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_report_updates_report
        FOREIGN KEY (report_id)
        REFERENCES reports(report_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_report_updates_user
        FOREIGN KEY (updated_by)
        REFERENCES users(user_id),

    CONSTRAINT fk_report_updates_old_status
        FOREIGN KEY (old_status_id)
        REFERENCES report_statuses(status_id),

    CONSTRAINT fk_report_updates_new_status
        FOREIGN KEY (new_status_id)
        REFERENCES report_statuses(status_id)
);


-- 10. TABEL REPORT_ASSIGNMENTS
-- Menghubungkan laporan dengan unit penanggung jawab

CREATE TABLE report_assignments (
    assignment_id SERIAL PRIMARY KEY,
    report_id INTEGER NOT NULL,
    unit_id INTEGER NOT NULL,
    assigned_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    assignment_notes TEXT,

    CONSTRAINT fk_report_assignments_report
        FOREIGN KEY (report_id)
        REFERENCES reports(report_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_report_assignments_unit
        FOREIGN KEY (unit_id)
        REFERENCES responsible_units(unit_id),

    CONSTRAINT uq_report_unit
        UNIQUE (report_id, unit_id)
);