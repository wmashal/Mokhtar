"""Seed a demo building for manual app testing. Run: python3 tests/seed_demo.py"""
import json
import urllib.request

B = "http://localhost:8000"


def call(method, path, body=None, token=None):
    req = urllib.request.Request(B + path, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    data = json.dumps(body).encode() if body is not None else None
    with urllib.request.urlopen(req, data) as r:
        return json.loads(r.read())


# --- building + manager ---
b = call("POST", "/buildings", {"name": "عمارة النور", "monthly_fee": 50, "water_unit_price": 2.5,
                                "electricity_unit_price": 0.65})
bid = b["id"]
call("POST", f"/buildings/{bid}/setup-manager",
     {"unit_number": "1", "resident_name": "أبو محمد (المختار)", "phone": "0500000001"})
code = call("POST", f"/buildings/{bid}/bootstrap-code")["code"]
mgr = call("POST", "/auth/login", {"phone": "0500000001", "code": code})["access_token"]

# --- units + residents ---
u2 = call("POST", f"/buildings/{bid}/units",
          {"unit_number": "2", "resident_name": "أبو أحمد", "phone": "0500000002"}, mgr)
u3 = call("POST", f"/buildings/{bid}/units",
          {"unit_number": "3", "resident_name": "أم سالم", "phone": "0500000003"}, mgr)

# --- monthly charges for this month (Sept 2026) ---
call("POST", f"/buildings/{bid}/charges/run", None, mgr)

# --- finance: payment + expenses ---
call("POST", f"/buildings/{bid}/transactions",
     {"unit_id": u2["id"], "type": "payment", "amount": 30, "note": "دفعة جزئية من القسط"}, mgr)
call("POST", f"/buildings/{bid}/transactions",
     {"type": "expense", "amount": 200, "category": "مصعد", "note": "صيانة دورية للمصعد"}, mgr)
call("POST", f"/buildings/{bid}/transactions",
     {"type": "expense", "amount": 80, "category": "تنظيف", "note": "تنظيف الدرج - أيلول"}, mgr)

# --- meter rounds: July baseline + August issued (real invoices) ---
r_jul = call("POST", f"/buildings/{bid}/meter-rounds", {"month": "2026-07-01"}, mgr)
for uid, val in [(1, 1000), (u2["id"], 1200), (u3["id"], 800)]:
    call("POST", f"/meter-rounds/{r_jul['id']}/readings", {"unit_id": uid, "current_value": val}, mgr)
call("POST", f"/meter-rounds/{r_jul['id']}/issue", None, mgr)

r_aug = call("POST", f"/buildings/{bid}/meter-rounds", {"month": "2026-08-01"}, mgr)
for uid, val in [(1, 1012), (u2["id"], 1241), (u3["id"], 822)]:
    call("POST", f"/meter-rounds/{r_aug['id']}/readings", {"unit_id": uid, "current_value": val}, mgr)
call("POST", f"/meter-rounds/{r_aug['id']}/issue", None, mgr)

# --- public meter (shared lighting electricity) ---
pm = call("POST", f"/buildings/{bid}/public-meters",
          {"name": "عداد كهرباء الإنارة", "meter_type": "electricity", "unit_price": 0.65}, mgr)
call("POST", f"/public-meters/{pm['id']}/readings", {"month": "2026-07-01", "current_value": 5000}, mgr)
call("POST", f"/public-meters/{pm['id']}/readings", {"month": "2026-08-01", "current_value": 5210}, mgr)

# --- meeting + announcement ---
call("POST", f"/buildings/{bid}/meetings",
     {"title": "اجتماع لمناقشة ترميم الدهان", "starts_at": "2026-09-14T18:00:00",
      "location": "مدخل العمارة", "agenda": "عرض الأسعار، التصويت على المقاول"}, mgr)
call("POST", f"/buildings/{bid}/announcements",
     {"body": "ستتم صيانة خزان المياه يوم الجمعة من 9 صباحاً حتى 12 ظهراً. الرجاء تخزين مياه."}, mgr)

# --- fresh login codes (unused) for app testing ---
mgr_code = call("POST", "/auth/invite", {"phone": "0500000001"}, mgr)["code"]
res_code = call("POST", "/auth/invite", {"phone": "0500000002"}, mgr)["code"]
res3_code = call("POST", "/auth/invite", {"phone": "0500000003"}, mgr)["code"]

print(json.dumps({"manager_code": mgr_code, "resident_code": res_code,
                  "resident3_code": res3_code}, ensure_ascii=False))
