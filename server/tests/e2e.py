"""End-to-end smoke test for the Mokhtar backend. Run: python tests/e2e.py"""
import json
import urllib.request

B = "http://localhost:8000"


def call(method, path, body=None, token=None):
    req = urllib.request.Request(B + path, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    data = json.dumps(body).encode() if body is not None else None
    try:
        with urllib.request.urlopen(req, data) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())


def check(label, ok, detail=""):
    print(f"{'PASS' if ok else 'FAIL'}  {label}  {detail}")
    assert ok, label


# --- bootstrap building + manager ---
_, b = call("POST", "/buildings", {"name": "E2E Bldg", "monthly_fee": 50, "water_unit_price": 2.5})
bid = b["id"]
s, _ = call("POST", f"/buildings/{bid}/setup-manager",
            {"unit_number": "1", "resident_name": "Mokhtar", "phone": "0522222221"})
check("setup manager", s == 200)

s, inv = call("POST", f"/buildings/{bid}/bootstrap-code")
check("bootstrap code", s == 200, inv["code"])
s, login = call("POST", "/auth/login", {"phone": "0522222221", "code": inv["code"]})
check("manager login", s == 200 and login["role"] == "manager")
mgr = login["access_token"]

s, _ = call("POST", f"/buildings/{bid}/bootstrap-code")
check("bootstrap blocked after activation", s == 409)

# --- units ---
s, u2 = call("POST", f"/buildings/{bid}/units",
             {"unit_number": "2", "resident_name": "Um Khalil", "phone": "0522222222"}, mgr)
check("add unit 2", s == 200)

# --- finance: charge 50, pay 30 → balance -20 ---
call("POST", f"/buildings/{bid}/transactions",
     {"unit_id": u2["id"], "type": "charge", "amount": 50, "category": "monthly_fee"}, mgr)
call("POST", f"/buildings/{bid}/transactions",
     {"unit_id": u2["id"], "type": "payment", "amount": 30}, mgr)
call("POST", f"/buildings/{bid}/transactions",
     {"type": "expense", "amount": 200, "category": "elevator"}, mgr)
s, units = call("GET", f"/buildings/{bid}/units", token=mgr)
bal = [u for u in units if u["id"] == u2["id"]][0]["balance"]
check("balance after charge+payment = -20", bal == "-20.00", bal)

# --- meter round 1: first reading = baseline ---
s, r1 = call("POST", f"/buildings/{bid}/meter-rounds", {"month": "2026-09-01"}, mgr)
s, rd = call("POST", f"/meter-rounds/{r1['id']}/readings",
             {"unit_id": u2["id"], "current_value": 1000}, mgr)
check("first reading consumption=0 cost=0", rd["consumption"] == "0.00" and rd["cost"] == "0.00")

# --- meter round 2: 1035 → 35 units * 2.5 = 87.5 ---
s, r2 = call("POST", f"/buildings/{bid}/meter-rounds", {"month": "2026-10-01"}, mgr)
s, rd2 = call("POST", f"/meter-rounds/{r2['id']}/readings",
              {"unit_id": u2["id"], "current_value": 1035}, mgr)
check("consumption=35, cost=87.5",
      rd2["consumption"] == "35.00" and rd2["cost"] == "87.5000".rstrip("0") or rd2["cost"] == "87.50",
      f"{rd2['consumption']} {rd2['cost']}")

# --- issue round → charge applied ---
s, _ = call("POST", f"/meter-rounds/{r2['id']}/issue", token=mgr)
check("issue round", s == 200)
s, units = call("GET", f"/buildings/{bid}/units", token=mgr)
bal = [u for u in units if u["id"] == u2["id"]][0]["balance"]
check("balance after invoice = -107.5", bal in ("-107.50", "-107.5"), bal)

s, _ = call("POST", f"/meter-rounds/{r2['id']}/issue", token=mgr)
check("double-issue blocked", s == 409)

# --- validation: lower reading rejected ---
s, r3 = call("POST", f"/buildings/{bid}/meter-rounds", {"month": "2026-11-01"}, mgr)
s, err = call("POST", f"/meter-rounds/{r3['id']}/readings",
              {"unit_id": u2["id"], "current_value": 500}, mgr)
check("lower reading rejected (422)", s == 422)

# --- resident invite + login ---
s, inv2 = call("POST", "/auth/invite", {"phone": "0522222222"}, mgr)
check("manager issues invite", s == 200)
s, err = call("POST", "/auth/login", {"phone": "0522222222", "code": "000000"})
check("wrong code rejected (401)", s == 401)
s, rlogin = call("POST", "/auth/login", {"phone": "0522222222", "code": inv2["code"]})
check("resident login", s == 200 and rlogin["role"] == "resident")
res = rlogin["access_token"]

# --- resident permissions ---
s, _ = call("POST", f"/buildings/{bid}/transactions",
            {"type": "expense", "amount": 10}, res)
check("resident cannot add transaction (403)", s == 403)
s, txs = call("GET", f"/buildings/{bid}/transactions", token=res)
check("resident sees transparent statement", s == 200 and len(txs) >= 3, f"{len(txs)} txs")
s, _ = call("GET", "/units/1/statement", token=res)
check("resident cannot see other unit statement (403)", s == 403)
s, own = call("GET", f"/units/{u2['id']}/statement", token=res)
check("resident sees own statement", s == 200 and len(own) >= 2)

# --- code reuse blocked ---
s, _ = call("POST", "/auth/login", {"phone": "0522222222", "code": inv2["code"]})
check("code is one-time use (404 after burn)", s == 404)

# --- meetings + announcements ---
s, m = call("POST", f"/buildings/{bid}/meetings",
            {"title": "Elevator discussion", "starts_at": "2026-09-15T18:00:00",
             "location": "Lobby"}, mgr)
check("create meeting", s == 200)
s, _ = call("POST", f"/meetings/{m['id']}/rsvp", {"status": "attending"}, res)
check("resident RSVP", s == 200)
s, a = call("POST", f"/buildings/{bid}/announcements", {"body": "Cleaning day Friday"}, mgr)
check("announcement", s == 200)

# --- monthly charge job (idempotent, per-unit fee override) ---
s, unit_patch = call("PATCH", f"/units/{u2['id']}", {"monthly_fee": 60}, mgr)
check("set custom fee 60 for unit 2", s == 200 and unit_patch["monthly_fee"] == "60.00")

s, result = call("POST", f"/buildings/{bid}/charges/run?month=2026-09-01", token=mgr)
check("manual charge run", s == 200 and u2["id"] in result["charged"], str(result))

s, units = call("GET", f"/buildings/{bid}/units", token=mgr)
mgr_unit = [u for u in units if u["unit_number"] == "1"][0]
u2_now = [u for u in units if u["id"] == u2["id"]][0]
check("manager unit charged default 50", mgr_unit["balance"] == "-50.00", mgr_unit["balance"])
check("unit 2 charged custom 60 (was -107.5 → -167.5)",
      u2_now["balance"] == "-167.50", u2_now["balance"])

s, result2 = call("POST", f"/buildings/{bid}/charges/run?month=2026-09-01", token=mgr)
check("re-run same month is idempotent (all skipped)",
      s == 200 and result2["charged"] == [] and len(result2["skipped"]) == 2, str(result2))

s, result3 = call("POST", f"/buildings/{bid}/charges/run?month=2026-10-01", token=mgr)
check("next month charges again", s == 200 and len(result3["charged"]) == 2)

# --- user management ---
s, users = call("GET", f"/buildings/{bid}/users", token=mgr)
check("list users", s == 200 and len(users) == 2, f"{len(users)} users")
res_user = [u for u in users if u["role"] == "resident"][0]

s, promoted = call("PATCH", f"/users/{res_user['id']}/role", {"role": "manager"}, mgr)
check("promote resident to manager", s == 200 and promoted["role"] == "manager")

# newly promoted manager can now add transactions
s, res_login2 = call("POST", "/auth/invite", {"phone": "0522222222"}, mgr)
s, rl2 = call("POST", "/auth/login", {"phone": "0522222222", "code": res_login2["code"]})
res_mgr_token = rl2["access_token"]
s, _ = call("POST", f"/buildings/{bid}/transactions",
            {"type": "expense", "amount": 10, "note": "by co-manager"}, res_mgr_token)
check("co-manager can add transaction", s == 200)

s, demoted = call("PATCH", f"/users/{res_user['id']}/role", {"role": "resident"}, mgr)
check("demote back to resident", s == 200 and demoted["role"] == "resident")

# cannot demote self as last manager
s, err = call("PATCH", "/users/999/role", {"role": "resident"}, mgr)
check("nonexistent user 404", s == 404)
mgr_user_id = [u for u in users if u["role"] == "manager"][0]["id"]
s, err = call("PATCH", f"/users/{mgr_user_id}/role", {"role": "resident"}, mgr)
check("cannot demote last manager (409)", s == 409)

# deactivate user keeps unit + history
s, unit_after = call("DELETE", f"/users/{res_user['id']}", token=mgr)
check("deactivate user returns unit", s == 200 and unit_after["id"] == u2["id"])
s, users = call("GET", f"/buildings/{bid}/users", token=mgr)
check("user removed, unit stays", s == 200 and len(users) == 1)
s, still = call("GET", f"/units/{u2['id']}/statement", token=mgr)
check("financial history preserved", s == 200 and len(still) >= 3)

# --- dashboard ---
# manager dashboard
s, bdash = call("GET", f"/buildings/{bid}/dashboard", token=mgr)
check("building dashboard", s == 200 and "total_balance" in bdash, str(bdash.get("total_balance")))
check("dashboard has units breakdown", len(bdash.get("units", [])) == 2)

# resident dashboard (resident was deactivated; use manager's own unit view)
s, mdash = call("GET", f"/units/{u2['id']}/dashboard", token=mgr)
check("unit dashboard", s == 200 and "paid_this_month" in mdash, mdash.get("paid_this_month"))

# --- building config: update water price (manager) ---
s, bupd = call("PATCH", f"/buildings/{bid}", {"water_unit_price": 3.0}, mgr)
check("update water price", s == 200 and bupd["water_unit_price"] == "3.0000", bupd.get("water_unit_price"))

# --- resident meter history (manager views any unit) ---
s, hist = call("GET", f"/units/{u2['id']}/meter-readings", token=mgr)
check("meter history has 2 readings", s == 200 and len(hist) == 2, str(len(hist)))
check("history has month+consumption+cost",
      all(k in hist[0] for k in ("month", "previous_value", "current_value", "consumption", "cost")))

# --- public meter (shared electricity) ---
s, pm = call("POST", f"/buildings/{bid}/public-meters",
             {"name": "عداد كهرباء الإنارة", "meter_type": "electricity", "unit_price": 0.65}, mgr)
check("create public meter", s == 200 and pm["unit_price"] == "0.6500", pm.get("unit_price"))

s, pr1 = call("POST", f"/public-meters/{pm['id']}/readings",
              {"month": "2026-09-01", "current_value": 5000}, mgr)
check("first public reading = baseline (cost 0)", s == 200 and pr1["cost"] == "0.00", str(pr1))

s, pr2 = call("POST", f"/public-meters/{pm['id']}/readings",
              {"month": "2026-10-01", "current_value": 5200}, mgr)
check("public reading consumption=200, cost=130",
      s == 200 and pr2["consumption"] == "200.00" and pr2["cost"] == "130.00",
      f"{pr2.get('consumption')} {pr2.get('cost')}")

# fresh resident (new unit) for permission checks
s, u3 = call("POST", f"/buildings/{bid}/units",
             {"unit_number": "3", "resident_name": "Sara", "phone": "0533333333"}, mgr)
s, inv3 = call("POST", "/auth/invite", {"phone": "0533333333"}, mgr)
s, rl3 = call("POST", "/auth/login", {"phone": "0533333333", "code": inv3["code"]})
res3 = rl3["access_token"]

s, _ = call("PATCH", f"/buildings/{bid}", {"water_unit_price": 9.9}, res3)
check("resident cannot update building (403)", s == 403)

s, pml = call("GET", f"/buildings/{bid}/public-meters", token=res3)
check("resident sees public meters", s == 200 and len(pml) == 1 and len(pml[0]["readings"]) == 2)

s, _ = call("POST", f"/public-meters/{pm['id']}/readings",
            {"month": "2026-11-01", "current_value": 5300}, res3)
check("resident cannot add public reading (403)", s == 403)

s, _ = call("GET", "/units/1/meter-readings", token=res3)
check("resident cannot read other's history (403)", s == 403)

# public meter cost recorded as building expense
s, txs = call("GET", f"/buildings/{bid}/transactions", token=mgr)
elec = [t for t in txs if t["category"] == "electricity"]
check("public reading cost recorded as expense", len(elec) >= 1 and elec[0]["amount"] == "130.00", str(elec[:1]))

# --- electricity price is building-level config ---
s, bupd = call("PATCH", f"/buildings/{bid}", {"electricity_unit_price": 0.7}, mgr)
check("update electricity price", s == 200 and bupd["electricity_unit_price"] == "0.7000",
      bupd.get("electricity_unit_price"))

# propagates to existing electricity meters (raw-dict endpoint returns a number)
s, pml = call("GET", f"/buildings/{bid}/public-meters", token=mgr)
check("meter price updated from settings", float(pml[0]["unit_price"]) == 0.7, pml[0]["unit_price"])

# new electricity meter without explicit price inherits building price
s, pm2 = call("POST", f"/buildings/{bid}/public-meters", {"name": "عداد المصعد"}, mgr)
check("new meter inherits building electricity price", s == 200 and pm2["unit_price"] == "0.7000",
      pm2.get("unit_price"))

# --- photo upload: meter + bill attached to readings, viewable by all ---
def upload(path, token):
    boundary = "----e2eboundary"
    content = b"\xff\xd8\xff\xe0fake-jpeg-bytes"
    body = (
        f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="bill.jpg"\r\n'
        f"Content-Type: image/jpeg\r\n\r\n"
    ).encode() + content + f"\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request(B + path, data=body, method="POST")
    req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
    req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())

s, up1 = upload("/photos", mgr)
check("manager uploads meter photo", s == 200 and bool(up1.get("path")), str(up1))
meter_photo = up1["path"]
s, up2 = upload("/photos", mgr)
bill_photo = up2["path"]

s, _ = upload("/photos", res3)
check("resident cannot upload photos (403)", s == 403)

# public reading with meter + bill photos
s, pr3 = call("POST", f"/public-meters/{pm['id']}/readings",
              {"month": "2026-11-01", "current_value": 5300,
               "photo_path": meter_photo, "bill_photo_path": bill_photo}, mgr)
check("public reading with photos (cost at new price 100*0.7=70)",
      s == 200 and pr3["cost"] == "70.00" and pr3["photo_path"] == meter_photo
      and pr3["bill_photo_path"] == bill_photo, str(pr3))

# water reading with photos
s, r3 = call("POST", f"/buildings/{bid}/meter-rounds", {"month": "2026-12-01"}, mgr)
s, wr = call("POST", f"/meter-rounds/{r3['id']}/readings",
             {"unit_id": u2["id"], "current_value": 1100,
              "photo_path": meter_photo, "bill_photo_path": bill_photo}, mgr)
check("water reading stores photos", s == 200 and wr["photo_path"] == meter_photo
      and wr["bill_photo_path"] == bill_photo)

# every resident can view photos (transparency)
def get_photo(name, token):
    req = urllib.request.Request(f"{B}/photos/{name}")
    req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code

check("resident views meter photo", get_photo(meter_photo, res3) == 200)
check("resident views bill photo", get_photo(bill_photo, res3) == 200)
check("bad photo name rejected", get_photo("..%2F..%2Fetc", res3) in (400, 404))
check("missing photo 404", get_photo("nonexistent.jpg", res3) == 404)

# my history returns photo fields
s, hist = call("GET", f"/units/{u2['id']}/meter-readings", token=mgr)
dec = [h for h in hist if h["month"] == "2026-12-01"]
check("history includes bill photo", dec and dec[0]["bill_photo_path"] == bill_photo)

# --- transparency: building dashboard visible to residents ---
s, bd = call("GET", f"/buildings/{bid}/dashboard", token=res3)
check("resident sees building dashboard", s == 200 and "units" in bd)

# --- unit edit ---
s, ue = call("PATCH", f"/units/{u2['id']}",
             {"resident_name": "أبو أحمد المعدّل", "monthly_fee": 70}, mgr)
check("edit unit name + custom fee", s == 200 and ue["resident_name"] == "أبو أحمد المعدّل"
      and ue["monthly_fee"] == "70.00", str(ue))

s, _ = call("PATCH", f"/units/{u2['id']}", {"phone": "0522222221"}, mgr)
check("phone conflict rejected (409)", s == 409)

# phone change on a unit that still has a user (Sara) moves the login too
s, ue2 = call("PATCH", f"/units/{u3['id']}", {"phone": "0555555555"}, mgr)
check("phone change ok", s == 200 and ue2["phone"] == "0555555555")
s, users = call("GET", f"/buildings/{bid}/users", token=mgr)
check("user login moved to new phone",
      any(u["phone"] == "0555555555" for u in users), str([u["phone"] for u in users]))

# --- unit delete ---
s, _ = call("DELETE", f"/units/{u2['id']}", token=mgr)
check("unit with history cannot be deleted (409)", s == 409)

s, _ = call("DELETE", "/units/1", token=mgr)
check("last manager's unit cannot be deleted (409)", s == 409)

s, dl = call("DELETE", f"/units/{u3['id']}", token=mgr)
check("empty unit deleted", s == 200 and dl.get("ok") is True, str(dl))
s, units_after = call("GET", f"/buildings/{bid}/units", token=mgr)
check("unit gone from list", all(u["id"] != u3["id"] for u in units_after))
s, _ = call("GET", f"/buildings/{bid}", token=res3)
check("deleted unit's user token is dead (401)", s == 401)

print("\nAll tests passed.")
