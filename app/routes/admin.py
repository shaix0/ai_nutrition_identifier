@router.get("/users")
async def list_all_users(user=Depends(admin_required)):
    """
    - 只有 admin 可以列出所有 Firebase 使用者
    """
    try:
        # 列出最多 1000 位使用者
        page = firebase_auth.list_users().iterate_all()
        users = []
        for u in page:
            users.append({
                "uid": u.uid,
                "email": u.email,
                "admin": u.custom_claims.get("admin") if u.custom_claims else False
            })
        return {"users": users}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to list users: {e}")