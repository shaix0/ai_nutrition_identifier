# main.py

from fastapi import FastAPI, Depends, Header, HTTPException
import firebase_admin
from firebase_admin import auth, credentials
from firebase_admin import firestore_async

from app.routes.admin import router as admin_router
from app.routes.settings import router as settings_router

# 初始化 Firebase Admin SDK
if not firebase_admin._apps:
    cred = credentials.Certificate("config/serviceAccountKey.json")
    default_app = firebase_admin.initialize_app(cred)
    db = firestore_async.client()

app = FastAPI()

origins = [
    "http://localhost",
    "http://localhost:8080",
]

from fastapi.middleware.cors import CORSMiddleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(admin_router, prefix="/admin")  # include the user router under /users path
app.include_router(settings_router, prefix="/settings")  # include the settings router under /settings path

