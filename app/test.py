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

# 取得使用者資料
user = auth.get_user(uid)
user = auth.get_user_by_email(email)
user = auth.get_user_by_phone_number(phone)

# 批次取得使用者資料
result = auth.get_users([
    auth.UidIdentifier('uid1'),
    auth.EmailIdentifier('user2@example.com'),
    auth.PhoneIdentifier(+15555550003),
    auth.ProviderIdentifier('google.com', 'google_uid4')
])

# 建立新使用者
user = auth.create_user(
    email='user@example.com',
    email_verified=False,
    phone_number='+15555550100',
    password='secretPassword',
    display_name='John Doe',
    photo_url='http://www.example.com/12345678/photo.png',
    disabled=False)

# 更新使用者資料
user = auth.update_user()

# 刪除使用者
auth.delete_user(uid)
result = auth.delete_users(["uid1", "uid2", "uid3"])

# 列出所有使用者(more than 1000 users in memory at a time)
# 每批結果都包含使用者清單和下一個網頁權杖，用於列出下一批使用者。如果已列出所有使用者，則不會傳回 pageToken。
page = auth.list_users()
while page:
    for user in page.users:
        print('User: ' + user.uid)
    # Get next batch of users.
    page = page.get_next_page()

for user in auth.list_users().iterate_all():
    print('User: ' + user.uid)

# 驗證 ID 令牌
decoded_token = auth.verify_id_token(id_token)
uid = decoded_token['uid']