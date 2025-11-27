# https://firebase.google.com/docs/auth/admin/custom-claims?hl=zh-tw#python_3

#import pyrebase
from fastapi import FastAPI, Header, HTTPException, Depends
from firebase_admin import auth, credentials
from fastapi import APIRouter, Header, HTTPException

router = APIRouter()

# 初始化 Firebase Admin SDK
'''
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
'''

# 設定 Custom Claim：role = admin
def set_admin(uid):
    auth.set_custom_user_claims(uid, {'admin': True})
    print(f"✅ 已設定 {uid} 為管理員")
    user = auth.get_user(uid)
    print("目前使用者自訂權限：", user.custom_claims)

# set_admin('ID3KnaS0WTfrabSCwWuOPCOHMKX2')

# id_token comes from the client app (shown above)
@router.post("/verify_user")
async def verify_user(authorization: str = Header(...)):
    token = _extract_token(authorization)

    try:
        decoded_token = auth.verify_id_token(token)
        return {
            "status": "verified",
            "uid": decoded_token["uid"],
        }
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {e}")

        
@router.post("/protected")
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

async def get_current_user(authorization: str = Header(...)):
    """
    - 驗證 Firebase ID Token
    - 回傳 uid、是否 admin、claims
    """
    id_token = _extract_token(authorization)
    try:
        decoded_token = auth.verify_id_token(id_token)
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Token verification failed: {e}")

    is_admin = decoded_token.get("admin") is True
    return {"uid": decoded_token.get("uid"), "is_admin": is_admin, "claims": decoded_token}

async def admin_required(user=Depends(get_current_user)):
    """
    - 依賴注入
    - 只有 admin 才能通過
    """
    if not user["is_admin"]:
        raise HTTPException(status_code=403, detail="Admin only")
    return user

@router.post("/admin")
async def admin_route(user=Depends(admin_required)):
    """
    - 只允許 admin 訪問
    - 回傳 admin 身份資訊
    """
    return {
        "status": "verified",
        "uid": user["uid"],
        "admin": user["is_admin"],
        "msg": "Welcome Admin!"
    }

#@router.post("/admin")
async def admin_route(authorization: str = Header(...)):
    print("Authorization header:", authorization)
    try:
        token = _extract_token(authorization)
        decoded = auth.verify_id_token(token)

        if not decoded.get("admin", False):
            raise HTTPException(status_code=403, detail="Not admin")

        return {"msg": "Welcome Admin!"}
        '''
        return {
            "status": "verified",
            "uid": uid,
            "admin": is_admin,
            "msg": "Welcome Admin!"
        }
        '''

    except:
        raise HTTPException(status_code=401, detail=f"Invalid token: {e}")
    
def _extract_token(authorization: str) -> str:
    try:
        scheme, token = authorization.split()
        if scheme.lower() != "bearer":
            raise ValueError("Invalid auth scheme")
        return token
    except:
        raise HTTPException(status_code=401, detail="Invalid Authorization header")