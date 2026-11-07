const express = require('express');
const cors = require('cors');
require('dotenv').config();

const pool = require('./db');
const reportRoutes = require('./routes/reports');

const app = express();

// Middleware
app.use(cors());
app.use(express.json());
app.use('/api/reports', reportRoutes);

// Route utama
app.get('/', (req, res) => {
    res.json({
        message: 'REST API LAPORMAS berhasil dijalankan!'
    });
});

// Route pengecekan database
app.get('/api/db-check', async (req, res) => {
    try {
        const result = await pool.query(
            'SELECT current_database() AS database_name'
        );

        res.json({
            message: 'Koneksi database berhasil!',
            database: result.rows[0].database_name
        });
    } catch (error) {
        console.error('Database error:', error.message);

        res.status(500).json({
            message: 'Koneksi database gagal.',
            error: error.message
        });
    }
});

// Menjalankan server
const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
    console.log(`Server LAPORMAS berjalan di http://localhost:${PORT}`);
});