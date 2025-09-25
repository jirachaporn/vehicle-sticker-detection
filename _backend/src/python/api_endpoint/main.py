# main.py - FastAPI application for Automated Vehicle Tagging System
from fastapi import FastAPI
from .routes_overview import router as overview_router
from .detection import router as detection_router

app = FastAPI(title="Automated Vehicle Tagging System API")

app.include_router(overview_router,detection_router)

@app.get("/")
def root():
    return {"message": "Automated Vehicle Tagging System API is running!!!"}






# uvicorn src.python.api_endpoint.main:app --reload