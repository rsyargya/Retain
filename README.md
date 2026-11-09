# RETAIN: Telco Customer Churn Early Warning & Adaptive Retention System

Sistem terintegrasi berbasis **Machine Learning (XGBoost)**, **Explainable AI (SHAP)**, dan **Aplikasi Mobile (Flutter)** untuk mendeteksi risiko *customer churn* sedini mungkin, memberikan transparansi faktor risiko per akun pelanggan, dan menyimulasikan skenario penawaran retensi secara adaptif.

---

## 📌 Fitur Utama

1. **Early Warning Dashboard**:
   - Pemantauan metrik *Monthly Recurring Revenue* (MRR), total akun berisiko, dan rasio pelanggan aktif.
   - Distribusi kategori risiko pelanggan (*Low*, *Medium*, *High*, *Critical*).

2. **Explainable AI (XAI) Attribution**:
   - Transparansi faktor penyebab risiko pelanggan menggunakan nilai kontribusi marjinal **SHAP (*SHapley Additive exPlanations*)**.
   - Dilengkapi *talking points* dan rekomendasi negosiasi otomatis untuk tim retensi/sales.

3. **What-If Simulation Sandbox**:
   - Simulasi renegosiasi kontrak, penyesuaian tarif bulanan, dan metode pembayaran secara *real-time*.
   - Menghitung penurunan risiko churn (*risk reduction percentage*) dan estimasi probabilitas penerimaan tawaran (*acceptance probability*).

4. **Action Center & WhatsApp Retention Generator**:
   - Manajemen tiket penanganan retensi pelanggan (*Pending*, *In Progress*, *Resolved*).
   - Generator draf pesan penawaran retensi instan ke WhatsApp pelanggan.

---

## 🏗️ Arsitektur Sistem

```
┌────────────────────────────────────────────────────────┐
│               RETAIN Mobile App (Flutter)              │
│   Dashboard  │  Action Center  │  Simulation Sandbox   │
└───────────────────────────┬────────────────────────────┘
                            │ REST API (JSON / HTTP)
┌───────────────────────────▼────────────────────────────┐
│               RETAIN Backend (FastAPI)                 │
│   ├── REST API Controller (app/main.py)                │
│   ├── ML & SHAP Inference Engine (model_service.py)    │
│   │   ├── XGBoost Classifier (xgboost_model.pkl)       │
│   │   ├── Column Transformer (preprocessor.pkl)        │
│   │   └── Heuristic Offer Acceptance Engine            │
│   └── Database Layer (SQLite via SQLAlchemy)           │
└────────────────────────────────────────────────────────┘
```

---

## 📂 Struktur Direktori Proyek

```
retain/
├── docker-compose.yml          # Konfigurasi container Docker
├── .env.example                # Template variabel lingkungan
├── README.md                   # Dokumentasi instalasi dan panduan pengujian
│
├── retain_backend/             # Layanan API Backend & Model ML
│   ├── Dockerfile
│   ├── requirements.txt        # Dependensi Python
│   ├── app/
│   │   ├── main.py             # Entry point FastAPI & routing endpoint
│   │   ├── model_service.py    # Logika inferensi XGBoost & kalkulasi SHAP
│   │   ├── database.py         # Konfigurasi koneksi SQLite
│   │   ├── models_db.py        # Model ORM SQLAlchemy
│   │   └── schemas.py          # Validasi skema input/output Pydantic
│   ├── data/                   # Dataset sumber (Telco Churn)
│   ├── models/                 # Model biner terlatih (.pkl)
│   └── training/               # Script pelatihan model & seeder database
│
└── retain_mobile/              # Aplikasi Klien Mobile (Flutter)
    ├── pubspec.yaml            # Dependensi pustaka Flutter
    └── lib/
        ├── main.dart           # Entry point aplikasi Flutter
        ├── screens/            # Halaman Dashboard, Action Center, & Simulasi
        ├── widgets/            # Bottom sheet SHAP & komponen UI
        ├── services/           # HTTP Client Churn API
        ├── models/             # Data class model respons API
        └── theme/              # Tema antarmuka, warna risiko, & format Rupiah
```

---

## 🚀 Panduan Menjalankan Sistem

### 1. Menjalankan Backend API

#### Prasyarat:
- **Python 3.10+** (atau Docker)

#### Langkah Instalasi & Menjalankan:
```bash
# 1. Masuk ke direktori backend
cd retain_backend

# 2. Buat dan aktifkan virtual environment (opsional namun disarankan)
python -m venv venv
# Windows:
venv\Scripts\activate
# Linux/macOS:
# source venv/bin/activate

# 3. Pasang dependensi
pip install -r requirements.txt

# 4. Inisialisasi dan isi data awal database (seeding)
python training/seed_db.py

# 5. Jalankan server FastAPI
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Server backend akan aktif di:
- **API URL**: `http://localhost:8000`
- **Swagger Interactive Docs**: `http://localhost:8000/docs`

> *Alternatif menggunakan Docker:*
> ```bash
> docker-compose up --build
> ```

---

### 2. Menjalankan Mobile App (Flutter)

#### Prasyarat:
- **Flutter SDK 3.19+**
- Android Studio / VS Code dengan Android Emulator atau perangkat fisik yang terhubung via USB Debugging.

#### Langkah Menjalankan:
```bash
# 1. Masuk ke direktori mobile
cd retain_mobile

# 2. Unduh dependensi Flutter
flutter pub get

# 3. Jalankan aplikasi
flutter run
```

> **Catatan Koneksi Emulator/Perangkat ke Backend:**
> - Jika menggunakan **Android Emulator standar**, endpoint backend default otomatis mengarah ke `http://10.0.2.2:8000`.
> - Jika menggunakan **perangkat fisik Android**, pastikan smartphone dan komputer berada di jaringan Wi-Fi yang sama, lalu ubah konstanta `baseUrl` di `lib/services/churn_api.dart` dengan alamat IP lokal komputer Anda (contoh: `http://192.168.1.x:8000`).

---

## 🧪 Endpoint API Utama

| Method | Endpoint | Deskripsi |
|---|---|---|
| `GET` | `/api/v1/health` | Status kesehatan layanan backend & database |
| `GET` | `/api/v1/dashboard/stats` | Agregasi metrik MRR dan distribusi risiko churn |
| `GET` | `/api/v1/churn/alerts` | Daftar pelanggan berisiko tinggi (*churn alerts*) |
| `GET` | `/api/v1/actions` | Daftar tiket retensi pelanggan (*action items*) |
| `PATCH` | `/api/v1/actions/{id}` | Pembaruan status tiket penanganan retensi |
| `POST` | `/api/v1/simulate` | Inferensi simulasi What-If skenario retensi |
| `POST` | `/api/v1/explain` | Ekstraksi kontribusi SHAP marjinal pelanggan |

---

## 🛠️ Tech Stack

- **Machine Learning**: XGBoost, Scikit-Learn, SHAP, Pandas, NumPy
- **Backend API**: FastAPI, Uvicorn, Pydantic, SQLAlchemy, SQLite
- **Mobile Framework**: Flutter (Dart)
- **Containerization**: Docker & Docker Compose

