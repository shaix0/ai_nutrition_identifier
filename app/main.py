# main.py

from fastapi import FastAPI, Depends, Header, HTTPException
import firebase_admin
from firebase_admin import auth, credentials
from firebase_admin import firestore_async

from app.routes.auth import router as auth_router

# 初始化 Firebase Admin SDK
if not firebase_admin._apps:
    cred = credentials.Certificate("config/serviceAccountKey.json")
    default_app = firebase_admin.initialize_app(cred)
    db = firestore_async.client()

app = FastAPI()

from fastapi.middleware.cors import CORSMiddleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router, prefix="/auth")  # include the user router under /users path

