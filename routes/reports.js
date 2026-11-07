const express = require('express');
const router = express.Router();
const pool = require('../db');

// =====================================================
// 1. GET - MENAMPILKAN SELURUH DATA LAPORAN
// =====================================================

router.get('/', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT
                r.report_id,
                r.title,
                r.description,
                r.location,
                r.latitude,
                r.longitude,
                r.created_at,
                r.updated_at,
                u.full_name AS reporter_name,
                c.category_name,
                s.status_name,
                a.village_name,
                a.district_name,
                a.regency_name
            FROM reports r
            JOIN users u
                ON r.user_id = u.user_id
            JOIN report_categories c
                ON r.category_id = c.category_id
            JOIN report_statuses s
                ON r.status_id = s.status_id
            JOIN areas a
                ON r.area_id = a.area_id
            ORDER BY r.created_at DESC
        `);

        res.status(200).json({
            message: 'Berhasil mengambil seluruh data laporan.',
            total: result.rows.length,
            data: result.rows
        });

    } catch (error) {
        console.error('GET reports error:', error.message);
        res.status(500).json({
            message: 'Terjadi kesalahan saat mengambil data laporan.',
            error: error.message
        });
    }
});


// =====================================================
// 2. POST - MENAMBAHKAN LAPORAN BARU
// =====================================================

router.post('/', async (req, res) => {
    const {
        user_id,
        category_id,
        area_id,
        title,
        description,
        location,
        latitude,
        longitude
    } = req.body;

    // Memeriksa data wajib
    if (
        user_id === undefined || user_id === null || user_id === '' ||
        category_id === undefined || category_id === null || category_id === '' ||
        area_id === undefined || area_id === null || area_id === '' ||
        !title || !description || !location ||
        latitude === undefined || latitude === null || latitude === '' ||
        longitude === undefined || longitude === null || longitude === ''
    ) {
        return res.status(400).json({
            message: 'Semua data wajib harus diisi.'
        });
    }

    // Memeriksa ID harus berupa bilangan bulat positif
    const ids = [user_id, category_id, area_id];

    if (!ids.every(value =>
        Number.isInteger(Number(value)) && Number(value) > 0
    )) {
        return res.status(400).json({
            message: 'user_id, category_id, dan area_id harus berupa ID positif.'
        });
    }

    // Memeriksa koordinat
    const lat = Number(latitude);
    const lng = Number(longitude);

    if (
        !Number.isFinite(lat) ||
        !Number.isFinite(lng) ||
        lat < -90 || lat > 90 ||
        lng < -180 || lng > 180
    ) {
        return res.status(400).json({
            message: 'Koordinat latitude atau longitude tidak valid.'
        });
    }

    let client;

    try {
        client = await pool.connect();
        await client.query('BEGIN');

        // Mengambil status awal laporan, yaitu Dikirim
        const statusResult = await client.query(
            `SELECT status_id
             FROM report_statuses
             WHERE status_name = 'Dikirim'`
        );

        if (statusResult.rows.length === 0) {
            await client.query('ROLLBACK');

            return res.status(500).json({
                message: 'Status awal Dikirim belum tersedia di database.'
            });
        }

        const status_id = statusResult.rows[0].status_id;

        // Menyimpan laporan baru
        const result = await client.query(
            `INSERT INTO reports (
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
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            RETURNING *`,
            [
                user_id,
                category_id,
                status_id,
                area_id,
                title,
                description,
                location,
                lat,
                lng
            ]
        );

        const newReport = result.rows[0];

        // Mencatat status awal ke riwayat laporan
        await client.query(
            `INSERT INTO report_updates (
                report_id,
                updated_by,
                old_status_id,
                new_status_id,
                notes
            )
            VALUES ($1, $2, NULL, $3, $4)`,
            [
                newReport.report_id,
                user_id,
                status_id,
                'Laporan dibuat oleh warga.'
            ]
        );

        await client.query('COMMIT');

        res.status(201).json({
            message: 'Laporan berhasil ditambahkan.',
            data: newReport
        });

    } catch (error) {
        if (client) {
            await client.query('ROLLBACK');
        }

        console.error('POST reports error:', error.message);

        res.status(error.code === '23503' ? 400 : 500).json({
            message: 'Gagal menambahkan laporan.',
            error: error.message
        });

    } finally {
        if (client) client.release();
    }
});


// =====================================================
// 3. GET BY ID - MENAMPILKAN LAPORAN BERDASARKAN ID
// =====================================================

router.get('/:id', async (req, res) => {
    const { id } = req.params;

    if (!/^[1-9]\d*$/.test(id)) {
        return res.status(400).json({
            message: 'ID laporan harus berupa bilangan bulat positif.'
        });
    }

    try {
        const result = await pool.query(
            `SELECT
                r.report_id,
                r.title,
                r.description,
                r.location,
                r.latitude,
                r.longitude,
                r.created_at,
                r.updated_at,
                u.full_name AS reporter_name,
                c.category_name,
                s.status_name,
                a.village_name,
                a.district_name,
                a.regency_name
            FROM reports r
            JOIN users u
                ON r.user_id = u.user_id
            JOIN report_categories c
                ON r.category_id = c.category_id
            JOIN report_statuses s
                ON r.status_id = s.status_id
            JOIN areas a
                ON r.area_id = a.area_id
            WHERE r.report_id = $1`,
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                message: 'Laporan tidak ditemukan.'
            });
        }

        res.status(200).json({
            message: 'Detail laporan berhasil ditemukan.',
            data: result.rows[0]
        });

    } catch (error) {
        console.error('GET reports by ID error:', error.message);
        res.status(500).json({
            message: 'Terjadi kesalahan saat mencari laporan.',
            error: error.message
        });
    }
});


// =====================================================
// 4. PUT - MEMPERBARUI DATA LAPORAN
// =====================================================

router.put('/:id', async (req, res) => {
    const { id } = req.params;

    const {
        category_id,
        status_id,
        area_id,
        title,
        description,
        location,
        latitude,
        longitude,
        updated_by
    } = req.body;

    if (!/^[1-9]\d*$/.test(id)) {
        return res.status(400).json({
            message: 'ID laporan harus berupa bilangan bulat positif.'
        });
    }

    // PUT menggunakan data lengkap laporan
    if (
        category_id === undefined || category_id === null || category_id === '' ||
        status_id === undefined || status_id === null || status_id === '' ||
        area_id === undefined || area_id === null || area_id === '' ||
        !title || !description || !location ||
        latitude === undefined || latitude === null || latitude === '' ||
        longitude === undefined || longitude === null || longitude === ''
    ) {
        return res.status(400).json({
            message: 'Lengkapi seluruh data laporan yang akan diperbarui.'
        });
    }

    const ids = [category_id, status_id, area_id];

    if (!ids.every(value =>
        Number.isInteger(Number(value)) && Number(value) > 0
    )) {
        return res.status(400).json({
            message: 'category_id, status_id, dan area_id harus berupa ID positif.'
        });
    }

    const lat = Number(latitude);
    const lng = Number(longitude);

    if (
        !Number.isFinite(lat) ||
        !Number.isFinite(lng) ||
        lat < -90 || lat > 90 ||
        lng < -180 || lng > 180
    ) {
        return res.status(400).json({
            message: 'Koordinat latitude atau longitude tidak valid.'
        });
    }

    let client;

    try {
        client = await pool.connect();
        await client.query('BEGIN');

        // Memeriksa apakah laporan tersedia
        const existingResult = await client.query(
            'SELECT * FROM reports WHERE report_id = $1',
            [id]
        );

        if (existingResult.rows.length === 0) {
            await client.query('ROLLBACK');

            return res.status(404).json({
                message: 'Laporan yang ingin diperbarui tidak ditemukan.'
            });
        }

        const oldReport = existingResult.rows[0];

        // Jika status berubah, updated_by wajib diisi
        if (Number(oldReport.status_id) !== Number(status_id)) {
            if (
                updated_by === undefined ||
                updated_by === null ||
                updated_by === '' ||
                !Number.isInteger(Number(updated_by)) ||
                Number(updated_by) <= 0
            ) {
                await client.query('ROLLBACK');

                return res.status(400).json({
                    message: 'updated_by wajib diisi ketika status laporan berubah.'
                });
            }
        }

        // Memperbarui data laporan
        const result = await client.query(
            `UPDATE reports
             SET
                category_id = $1,
                status_id = $2,
                area_id = $3,
                title = $4,
                description = $5,
                location = $6,
                latitude = $7,
                longitude = $8,
                updated_at = CURRENT_TIMESTAMP
             WHERE report_id = $9
             RETURNING *`,
            [
                category_id,
                status_id,
                area_id,
                title,
                description,
                location,
                lat,
                lng,
                id
            ]
        );

        // Mencatat perubahan status jika ada
        if (Number(oldReport.status_id) !== Number(status_id)) {
            await client.query(
                `INSERT INTO report_updates (
                    report_id,
                    updated_by,
                    old_status_id,
                    new_status_id,
                    notes
                )
                VALUES ($1, $2, $3, $4, $5)`,
                [
                    id,
                    updated_by,
                    oldReport.status_id,
                    status_id,
                    'Status laporan diperbarui.'
                ]
            );
        }

        await client.query('COMMIT');

        res.status(200).json({
            message: 'Laporan berhasil diperbarui.',
            data: result.rows[0]
        });

    } catch (error) {
        if (client) {
            await client.query('ROLLBACK');
        }

        console.error('PUT reports error:', error.message);

        res.status(error.code === '23503' ? 400 : 500).json({
            message: 'Gagal memperbarui laporan.',
            error: error.message
        });

    } finally {
        if (client) client.release();
    }
});


// =====================================================
// 5. DELETE - MENGHAPUS DATA LAPORAN
// =====================================================

router.delete('/:id', async (req, res) => {
    const { id } = req.params;

    if (!/^[1-9]\d*$/.test(id)) {
        return res.status(400).json({
            message: 'ID laporan harus berupa bilangan bulat positif.'
        });
    }

    try {
        const result = await pool.query(
            `DELETE FROM reports
             WHERE report_id = $1
             RETURNING *`,
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                message: 'Laporan yang ingin dihapus tidak ditemukan.'
            });
        }

        res.status(200).json({
            message: 'Laporan berhasil dihapus.',
            data: result.rows[0]
        });

    } catch (error) {
        console.error('DELETE reports error:', error.message);
        res.status(500).json({
            message: 'Terjadi kesalahan saat menghapus laporan.',
            error: error.message
        });
    }
});


// Mengekspor router
module.exports = router;
