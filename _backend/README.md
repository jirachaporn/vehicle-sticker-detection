# Automated Vehicle Tagging System (AVTS)

Automated Vehicle Tagging System for **vehicle parking authorization** that combines license plate recognition (OCR) and sticker detection.  
It uses **AI for Thai OCR**, **Supabase** (PostgreSQL + Storage), and **Cloudinary** to manage images, models, and detection logs.

---

## 🚀 Features
- Real-time vehicle detection using YOLO models.
- OCR via AI for Thai to read license plates.
- Cloud storage for detected images using Cloudinary.
- Database and file storage management with Supabase.
- Multi-location and model management (each parking location can have its own model).
- FastAPI backend with RESTful APIs for detection, logging, and statistics.

---

## ⚙️ Requirements
- Python 3.10+
- FastAPI
- Supabase Python client
- Cloudinary Python client
- Ultralytics YOLO (for detection)
- OpenCV (for video/image processing)

---
## 📦 Installation & Running
### Install dependencies
```bash
pip install -r requirements.txt
```
### 🔑 Environment Variables

Create a `.env` file in the root of the project with the following values:

```env
# OCR API key from AI for Thai
API_KEY_MAIN=your_ai_for_thai_api_key

# Supabase project URL (from Supabase Project Settings → API → Project URL)
SUPABASE_URL=https://your-project.supabase.co

# Supabase anonymous public key (from Supabase Project Settings → API → anon key)
SUPABASE_ANON_KEY=your_supabase_anon_key

# Supabase service role key (from Supabase Project Settings → API → service_role key, **keep secret**)
SUPABASE_SERVICE_ROLE=your_supabase_service_role_key

# Cloudinary connection string (from Cloudinary Dashboard → API Environment variable)
CLOUDINARY_URL=cloudinary://<api_key>:<api_secret>@<cloud_name>

# Supabase storage bucket name for storing models/images
SUPABASE_STORAGE_BUCKET=your_bucket_name
```
. . .
