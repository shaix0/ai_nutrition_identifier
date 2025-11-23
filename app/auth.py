# https://firebase.google.com/docs/auth/admin/custom-claims?hl=zh-tw#python_3

#import pyrebase
from fastapi import FastAPI, Header, HTTPException
import firebase_admin
from firebase_admin import auth, credentials

# 初始化 Firebase Admin SDK
if not firebase_admin._apps:
    cred = credentials.Certificate("config/serviceAccountKey.json")
    default_app = firebase_admin.initialize_app(cred)

app = FastAPI()

from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# 設定 Custom Claim：role = admin
def set_admin(uid):
    auth.set_custom_user_claims(uid, {'admin': True})
    print(f"✅ 已設定 {uid} 為管理員")
    user = auth.get_user(uid)
    print("目前使用者自訂權限：", user.custom_claims)

# set_admin('ID3KnaS0WTfrabSCwWuOPCOHMKX2')

# id_token comes from the client app (shown above)
@app.post("/verify_user")
async def verify_user(authorization: str = Header(...)):
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid Authorization header format")
    id_token = authorization.split("Bearer ")[1]

    try:
        decoded_token = auth.verify_id_token(id_token)
        uid = decoded_token['uid']
        return {"message": f"Hello, user {uid}! This is protected data."}
    except Exception as e:
        return {"status": "error", "message": str(e)}
        
@app.post("/protected")
async def protected_route(authorization: str = Header(None)):
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing Authorization header")

    # 取得 Bearer token
    try:
        scheme, token = authorization.split()
        if scheme.lower() != "bearer":
            raise ValueError("Invalid auth scheme")
    except:
        raise HTTPException(status_code=401, detail="Invalid Authorization header")

    try:
        # 驗證 ID Token
        decoded = auth.verify_id_token(token)

        uid = decoded.get("uid")
        is_admin = decoded.get("admin", False)

        return {
            "uid": uid,
            "admin": is_admin,
            "status": "verified"
        }

    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {str(e)}")
    
@app.get("/admin")
async def admin_route(authorization: str = Header(None)):
    print("Authorization header:", authorization)
    try:
        _, token = authorization.split()
        decoded = auth.verify_id_token(token)

        if not decoded.get("admin", False):
            raise HTTPException(status_code=403, detail="Not admin")

        return {"msg": "Welcome Admin!"}

    except:
        raise HTTPException(status_code=401, detail="Invalid token")
    
