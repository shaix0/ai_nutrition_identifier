from fastapi import FastAPI, Depends, Header, HTTPException
from firebase_admin import auth as firebase_auth
import firebase_admin
from firebase_admin import credentials

cred = credentials.Certificate("config/serviceAccountKey.json")
firebase_admin.initialize_app(cred)

app = FastAPI()

from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def _extract_bearer(auth_header: str) -> str:
    if not auth_header:
        raise HTTPException(status_code=401, detail="Authorization header missing")
    if not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid Authorization header")
    return auth_header.split("Bearer ")[1]

async def get_current_user(authorization: str = Header(...)):
    id_token = _extract_bearer(authorization)
    try:
        decoded_token = firebase_auth.verify_id_token(id_token)
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Token verification failed: {e}")

    is_admin = decoded_token.get("admin") is True
    return {"uid": decoded_token.get("uid"), "is_admin": is_admin, "claims": decoded_token}

async def admin_required(user=Depends(get_current_user)):
    if not user["is_admin"]:
        raise HTTPException(status_code=403, detail="Admin only")
    return user

@app.get("/admin")
async def admin_route(user=Depends(get_current_user)):
    if not user["is_admin"]:
        raise HTTPException(status_code=403, detail="Not an admin")
    return {"msg": "Welcome Admin!"}

@app.get("/admin-only")
async def admin_only(user=Depends(admin_required)):
    return {"msg": "Welcome Admin!"}
