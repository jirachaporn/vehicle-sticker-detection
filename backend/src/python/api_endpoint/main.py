# main.py - FastAPI application for Automated Vehicle Tagging System
import os
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .routes_overview import router as overview_router
from .detection import router as detection_router
from .routes_notifications import router as notifications_router
from .routes_table import router as table_router

from .email_permission import router as permission_router
from .routes_location import router as locations_router
from .router_email import router as email_router
from .router_camera import router as camera_router
from .routes_models import router as models_router
from .routes_notifications_permission import router as permissions_router


APP_ENV = os.getenv("APP_ENV", "Development for Programer").lower()
docs_url = None if APP_ENV == "production" else "/docs"
redoc_url = None if APP_ENV == "production" else "/redoc"

app = FastAPI(title="Automated Vehicle Tagging System API")

# Routers
app.include_router(overview_router, tags=["overview"])
app.include_router(detection_router, tags=["detection"])
app.include_router(notifications_router, tags=["notifications"])
app.include_router(table_router, prefix="/table", tags=["table"])
app.include_router(permission_router, prefix="/permission", tags=["permission"])
app.include_router(locations_router, tags=["locations"])
app.include_router(email_router, prefix="/email", tags=["email"])
app.include_router(camera_router, prefix="/camera", tags=["camera"])
app.include_router(models_router, tags=["models"])
app.include_router(permissions_router, tags=["permissions"])

@app.get("/")
def root():
    missing = []
    for key in ["API_KEY_MAIN_AI4THAI_OCR", 
                "SUPABASE_URL", "SUPABASE_SERVICE_ROLE", "SUPABASE_ANON_KEY","SUPABASE_FUNCTION_URL",
                "CLOUDINARY_URL","CLOUDINARY_NAME","CLOUDINARY_API_KEY","CLOUDINARY_API_SECRET",
                "EMAIL_ADDRESS","EMAIL_PASSWORD"]:
        if not os.getenv(key):
            missing.append(key)

    if missing and APP_ENV == "production":
        raise HTTPException(status_code=500, detail=f"Missing required env: {', '.join(missing)}")

    return {
        "message": "Automated Vehicle Tagging System API is running!",
        "env": APP_ENV,
        "missing_env_for_dev": missing if missing else None
    }

# uvicorn backend.src.python.api_endpoint.main:app --reload --host 0.0.0.0 --port 8000