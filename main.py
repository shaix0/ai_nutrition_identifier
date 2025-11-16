# https://firebase.google.com/docs/auth/admin/custom-claims?hl=zh-tw#python_3

import firebase_admin
from firebase_admin import auth, credentials

# 初始化 Firebase Admin SDK
cred = credentials.Certificate("path/to/serviceAccountKey.json")
firebase_admin.initialize_app(cred)

# 設定 Custom Claim：role = admin
def set_admin(uid):
    auth.set_custom_user_claims(uid, {'role': 'admin'})
    print(f"✅ 已設定 {uid} 為管理員")

# 設定一般使用者
def set_user(uid):
    auth.set_custom_user_claims(uid, {'role': 'user'})
    print(f"✅ 已設定 {uid} 為一般使用者")

user = auth.get_user(uid)