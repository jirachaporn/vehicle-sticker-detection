# api_endpoint/routes_location.py
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel
from typing import List, Optional
from ..api_service.locations import (
    get_locations,
    save_location,
    update_location,
    delete_location,
)

router = APIRouter()


# ---------- Models ----------
class LocationItem(BaseModel):
    locations_id: Optional[str]
    name: Optional[str]
    address: Optional[str]
    description: Optional[str]
    color: Optional[str]
    created_at: Optional[str]
    location_license: Optional[str]


class LocationCreateRequest(BaseModel):
    name: str
    owner_email: str
    address: Optional[str] = ""
    description: Optional[str] = ""
    color: Optional[str] = "#1565C0"


class LocationUpdateRequest(BaseModel):
    name: Optional[str] = None
    address: Optional[str] = None
    description: Optional[str] = None
    color: Optional[str] = None


# ---------- GET ----------
@router.get("/get_locations", response_model=List[LocationItem])
def get_locations_endpoint(user: str = Query(..., description="User email")):
    success, message, data = get_locations(user)
    if not success:
        raise HTTPException(status_code=500, detail=message)
    return data


# ---------- CREATE ----------
@router.post("/create_locations")
def create_location_endpoint(req: LocationCreateRequest):
    success, message, result = save_location(req.dict())
    if not success:
        raise HTTPException(status_code=400, detail=message)
    return {"message": message, **(result or {})}


# ---------- UPDATE ----------
@router.put("/locations/{location_id}")
def update_location_endpoint(location_id: str, req: LocationUpdateRequest):
    success, message = update_location(location_id, req.dict())
    if not success:
        status = 404 if message == "Location not found" else 500
        raise HTTPException(status_code=status, detail=message)
    return {"message": message}


# ---------- DELETE ----------
@router.delete("/locations/{location_id}")
def delete_location_endpoint(location_id: str):
    success, message = delete_location(location_id)
    if not success:
        status = 404 if message == "Location not found" else 500
        raise HTTPException(status_code=status, detail=message)
    return {"message": message}
