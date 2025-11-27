

def get_user_profile(uid: str):
    """
    從 Firestore users/{uid} 取得性別、身高、體重、年齡。
    """
    doc_ref = db.collection("users").document(uid)
    doc = doc_ref.get()

    if not doc.exists:
        return None

    data = doc.to_dict()

    return {
        "gender": data.get("gender"),
        "height": data.get("height"),
        "weight": data.get("weight"),
        "age": data.get("age"),
    }


def update_user_profile(uid: str, gender: str, height: float, weight: float, age: int):
    """
    更新 users/{uid} 中的：性別、身高、體重、年齡
    """
    doc_ref = db.collection("users").document(uid)

    update_data = {
        "gender": gender,
        "height": height,
        "weight": weight,
        "age": age
    }

    doc_ref.set(update_data, merge=True)
    return True