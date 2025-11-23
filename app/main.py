# main.py
'''
from app.router import router
from fastapi import FastAPI, Depends, Header, HTTPException

# 確保 Firebase Admin SDK 已在 app.auth 中初始化
import app.auth  # side-effect: initializes firebase_admin (uses config/serviceAccountKey.json)
from firebase_admin import auth as firebase_auth

app = FastAPI()


def _extract_bearer(auth_header: str) -> str:
	if not auth_header:
		raise HTTPException(status_code=401, detail="Authorization header missing")
	if not auth_header.startswith("Bearer "):
		raise HTTPException(status_code=401, detail="Invalid Authorization header format")
	return auth_header.split("Bearer ", 1)[1]


async def get_current_user(authorization: str = Header(...)):
	"""Dependency to verify Firebase ID token and return identity + admin flag.

	Returns a dict: {"uid": ..., "is_admin": bool, "claims": decoded_token}
	"""
	id_token = _extract_bearer(authorization)
	try:
		decoded_token = firebase_auth.verify_id_token(id_token)
	except Exception as e:
		raise HTTPException(status_code=401, detail=f"Token verification failed: {e}")

	uid = decoded_token.get("uid")
	# Custom claims example: {'admin': True}
	is_admin = False
	# common places to find admin info: custom claim 'admin' or 'role' claim
	if isinstance(decoded_token.get("admin"), bool):
		is_admin = decoded_token.get("admin")
	elif decoded_token.get("role") == "admin":
		is_admin = True

	return {"uid": uid, "is_admin": is_admin, "claims": decoded_token}


@app.get("/whoami")
async def whoami(user=Depends(get_current_user)):
	return {"uid": user["uid"], "is_admin": user["is_admin"], "claims": user["claims"]}


@app.get("/admin-only")
async def admin_only(user=Depends(get_current_user)):
	if not user["is_admin"]:
		raise HTTPException(status_code=403, detail="Admin access required")
	return {"message": f"Welcome admin {user['uid']}"}


app.include_router(router)

'''

# main.py

from app.router import router
from fastapi import FastAPI, Depends, Header, HTTPException

import app.auth  # side-effect: initializes firebase_admin
from firebase_admin import auth as firebase_auth

app = FastAPI()


def _extract_bearer(auth_header: str) -> str:
    if not auth_header:
        raise HTTPException(status_code=401, detail="Authorization header missing")
    if not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid Authorization header format")
    return auth_header.split("Bearer ", 1)[1]


async def get_current_user(authorization: str = Header(...)):
    """
    Verify Firebase ID token and return:
    {
        "uid": "...",
        "is_admin": true/false,
        "claims": {...}
    }
    """
    id_token = _extract_bearer(authorization)

    try:
        decoded_token = firebase_auth.verify_id_token(id_token)
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Token verification failed: {e}")

    uid = decoded_token.get("uid")

    # ===========================
    # 🔥 Custom Claims 檢查重點
    # ===========================
    # Firebase Admin SDK 設置的 { admin: true }會出現在 decoded_token
    claims = decoded_token

    is_admin = bool(claims.get("admin", False))

    return {"uid": uid, "is_admin": is_admin, "claims": claims}


@app.get("/whoami")
async def whoami(user=Depends(get_current_user)):
    """
    回傳完整資訊，確認 custom claims 是否成功設定。
    """
    return {
        "uid": user["uid"],
        "is_admin": user["is_admin"],
        "claims": user["claims"],  # 你可以在這裡看到 {"admin": true}
    }


@app.get("/admin-only")
async def admin_only(user=Depends(get_current_user)):
    """
    僅限 admin 用戶
    """
    if not user["is_admin"]:
        raise HTTPException(status_code=403, detail="Admin access required")

    return {"message": f"Welcome admin {user['uid']}"}



