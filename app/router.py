# router.py

from fastapi import APIRouter
from app.auth import verify_user

router = APIRouter()

@router.get("/")
def hello():
    """Hello world route to make sure the app is working correctly"""
    return {"msg": "Hello World!"}