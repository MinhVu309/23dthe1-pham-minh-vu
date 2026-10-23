#!/usr/bin/env bash
# Hồi quy API cho hành vi Tuần 6-7 (thầy chấm). Chạy khi backend đang chạy:
#   docs/regression.sh [BASE_URL]
# Biến môi trường:
#   PHASE=baseline  -> GET api/PostApi KHÔNG cần đăng nhập (hành vi Tuần 6)
#   PHASE=upgrade   -> GET api/PostApi cần đăng nhập (mặc định, sau khi nâng cấp)
# Cần tài khoản admin1 / user1 (tự đăng ký nếu chưa có). Dữ liệu tạo ra sẽ được xóa lại.

BASE="${1:-http://localhost:5126}"
PHASE="${PHASE:-upgrade}"
J='Content-Type: application/json'
PASS=0; FAIL=0
CLEAN_PRODUCTS=(); CLEAN_CATEGORIES=(); CLEAN_POSTS=()

green(){ printf '\033[32m%s\033[0m' "$1"; }; red(){ printf '\033[31m%s\033[0m' "$1"; }
check(){ # $1=mô tả  $2=mong đợi  $3=thực tế
  if [ "$2" == "$3" ]; then PASS=$((PASS+1)); echo "  $(green PASS) $1"
  else FAIL=$((FAIL+1)); echo "  $(red FAIL) $1  (mong đợi: $2, thực tế: $3)"; fi
}
code(){ curl -s -o /dev/null -w '%{http_code}' "$@"; }
jget(){ python3 -c "import sys,json
try:
    d=json.load(sys.stdin)
    for k in sys.argv[1].split('.'):
        d = d[int(k)] if isinstance(d,list) else d.get(k)
    print('' if d is None else d)
except Exception: print('')" "$1"; }
login(){ curl -s -X POST "$BASE/api/Authenticate/login" -H "$J" -d "{\"username\":\"$1\",\"password\":\"$2\"}"; }
ensure_account(){ # $1 user $2 pass $3 role
  if [ "$(login "$1" "$2" | jget status)" != "True" ]; then
    curl -s -o /dev/null -X POST "$BASE/api/Authenticate/register" -H "$J" \
      -d "{\"username\":\"$1\",\"email\":\"$1@example.com\",\"password\":\"$2\",\"role\":\"$3\"}"
  fi
}
role_of(){ python3 -c "
import sys,base64,json
t=sys.stdin.read().strip().split('.')[1]; t+='='*(-len(t)%4)
print(json.loads(base64.urlsafe_b64decode(t)).get('http://schemas.microsoft.com/ws/2008/06/identity/claims/role',''))"; }
cleanup(){
  for id in "${CLEAN_POSTS[@]}"; do curl -s -o /dev/null -X DELETE "$BASE/api/PostApi/$id" -H "Authorization: Bearer $AT"; done
  for id in "${CLEAN_PRODUCTS[@]}"; do curl -s -o /dev/null -X DELETE "$BASE/api/ProductApi/$id" -H "Authorization: Bearer $AT"; done
  for id in "${CLEAN_CATEGORIES[@]}"; do curl -s -o /dev/null -X DELETE "$BASE/api/CategoryApi/$id" -H "Authorization: Bearer $AT"; done
}
trap cleanup EXIT

echo "Hồi quy Tuần 6-7  |  $BASE  |  PHASE=$PHASE"
if [ "$(code "$BASE/api/ProductApi")" == "000" ]; then echo "Backend chưa chạy ($BASE)"; exit 2; fi

ensure_account admin1 'Admin@12345' Admin
ensure_account user1 'User@12345' User
AT=$(login admin1 'Admin@12345' | jget token); UT=$(login user1 'User@12345' | jget token)
A="Authorization: Bearer $AT"; U="Authorization: Bearer $UT"

echo "== Đăng nhập / đăng ký / role"
check "login sai mật khẩu -> 401" 401 "$(code -X POST $BASE/api/Authenticate/login -H "$J" -d '{"username":"admin1","password":"sai"}')"
check "login sai trả status=false (bool)" False "$(curl -s -X POST $BASE/api/Authenticate/login -H "$J" -d '{"username":"admin1","password":"sai"}' | jget status)"
check "login admin1 -> status=true" True "$(login admin1 'Admin@12345' | jget status)"
check "token admin1 có role Admin" Admin "$(echo "$AT" | role_of)"
check "token user1 có role User" User "$(echo "$UT" | role_of)"
check "đăng ký trùng tên -> 400" 400 "$(code -X POST $BASE/api/Authenticate/register -H "$J" -d '{"username":"user1","email":"x@example.com","password":"User@12345"}')"
check "đăng ký mật khẩu yếu -> 400" 400 "$(code -X POST $BASE/api/Authenticate/register -H "$J" -d '{"username":"yeu1","email":"y@example.com","password":"123456"}')"
check "đăng ký role lạ -> 400" 400 "$(code -X POST $BASE/api/Authenticate/register -H "$J" -d '{"username":"la1","email":"l@example.com","password":"User@12345","role":"SuperAdmin"}')"

echo "== Sản phẩm (xem: đăng nhập; thêm/sửa/xóa: Admin)"
check "GET sản phẩm không token -> 401" 401 "$(code $BASE/api/ProductApi)"
check "GET sản phẩm token rác -> 401" 401 "$(code $BASE/api/ProductApi -H 'Authorization: Bearer abc.def.ghi')"
check "GET sản phẩm (User) -> 200" 200 "$(code $BASE/api/ProductApi -H "$U")"
check "GET sản phẩm (Admin) -> 200" 200 "$(code $BASE/api/ProductApi -H "$A")"
check "User POST sản phẩm -> 403" 403 "$(code -X POST $BASE/api/ProductApi -H "$J" -H "$U" -d '{"name":"x","price":1}')"
CAT=$(curl -s -X POST $BASE/api/CategoryApi -H "$J" -H "$A" -d '{"name":"HoiQuy DM","description":"tam"}'); CID=$(echo "$CAT" | jget id); CLEAN_CATEGORIES+=("$CID")
check "Admin POST danh mục -> có id" True "$([ -n "$CID" ] && echo True || echo False)"
PR=$(curl -s -w '|%{http_code}' -X POST $BASE/api/ProductApi -H "$J" -H "$A" -d "{\"name\":\"HoiQuy Ao Thun\",\"price\":150000,\"image\":\"Cap nhat sau\",\"description\":\"mo ta\",\"categoryId\":$CID}")
PID=$(echo "${PR%|*}" | jget id); CLEAN_PRODUCTS+=("$PID")
check "Admin POST sản phẩm -> 201" 201 "${PR##*|}"
check "sản phẩm trả categoryId + category.name" "HoiQuy DM" "$(echo "${PR%|*}" | jget category.name)"
check "GET {id} (User) -> 200" 200 "$(code $BASE/api/ProductApi/$PID -H "$U")"
check "tìm kiếm không phân biệt hoa thường" "HoiQuy Ao Thun" "$(curl -s "$BASE/api/ProductApi/search?name=HOIQUY%20AO" -H "$U" | jget 0.name)"
BODY="{\"id\":$PID,\"name\":\"HoiQuy Sua\",\"price\":175000,\"image\":\"\",\"description\":\"\",\"categoryId\":$CID}"
check "Admin PUT sản phẩm -> 204" 204 "$(code -X PUT $BASE/api/ProductApi/$PID -H "$J" -H "$A" -d "$BODY")"
check "PUT đã lưu" "HoiQuy Sua" "$(curl -s $BASE/api/ProductApi/$PID -H "$U" | jget name)"
check "PUT id lệch -> 400" 400 "$(code -X PUT $BASE/api/ProductApi/$PID -H "$J" -H "$A" -d '{"id":99999,"name":"x","price":1}')"
check "User DELETE sản phẩm -> 403" 403 "$(code -X DELETE $BASE/api/ProductApi/$PID -H "$U")"

echo "== Danh mục (xem: đăng nhập; thêm/sửa/xóa: Admin; xóa -> SetNull)"
check "GET danh mục (User) -> 200" 200 "$(code $BASE/api/CategoryApi -H "$U")"
check "User POST danh mục -> 403" 403 "$(code -X POST $BASE/api/CategoryApi -H "$J" -H "$U" -d '{"name":"x"}')"
BODY="{\"id\":$CID,\"name\":\"HoiQuy DM sua\"}"
check "Admin PUT danh mục -> 204" 204 "$(code -X PUT $BASE/api/CategoryApi/$CID -H "$J" -H "$A" -d "$BODY")"
check "User DELETE danh mục -> 403" 403 "$(code -X DELETE $BASE/api/CategoryApi/$CID -H "$U")"
check "Admin DELETE danh mục -> 204" 204 "$(code -X DELETE $BASE/api/CategoryApi/$CID -H "$A")"
check "xóa danh mục: sản phẩm về categoryId = null" "" "$(curl -s $BASE/api/ProductApi/$PID -H "$U" | jget categoryId)"
check "xóa danh mục: sản phẩm vẫn còn" 200 "$(code $BASE/api/ProductApi/$PID -H "$U")"
CLEAN_CATEGORIES=()
check "Admin DELETE sản phẩm -> 204" 204 "$(code -X DELETE $BASE/api/ProductApi/$PID -H "$A")"; CLEAN_PRODUCTS=()

echo "== Bài đăng Tuần 6 (News Feed)"
if [ "$PHASE" == "baseline" ]; then
  check "GET bài đăng không token -> 200 (Tuần 6)" 200 "$(code $BASE/api/PostApi)"
else
  check "GET bài đăng không token -> 401 (sau nâng cấp)" 401 "$(code $BASE/api/PostApi)"
fi
LIST=$(curl -s $BASE/api/PostApi -H "$U")
check "GET bài đăng (User) -> mảng" list "$(echo "$LIST" | python3 -c "import sys,json;print('list' if isinstance(json.load(sys.stdin),list) else 'khac')")"
FIELDS=$(echo "$LIST" | python3 -c "
import sys,json
d=json.load(sys.stdin)
need=['id','userName','userAvatar','content','image','createdAt','likeCount','commentCount']
print('ok' if d and all(all(k in p for k in need) for p in d) else 'thieu: '+str([k for k in need if d and k not in d[0]]))")
check "mỗi bài có đủ trường JSON cũ" ok "$FIELDS"
PO=$(curl -s -w '|%{http_code}' -X POST $BASE/api/PostApi -H "$J" -H "$U" -d '{"userName":"Ten Gia","userAvatar":"","content":"Bai hoi quy","image":"","likeCount":0,"commentCount":0}')
POID=$(echo "${PO%|*}" | jget id); CLEAN_POSTS+=("$POID")
check "User POST bài đăng -> 201" 201 "${PO##*|}"
CREATED=$(curl -s $BASE/api/PostApi/$POID -H "$U" | jget createdAt)
BODY="{\"id\":$POID,\"userName\":\"x\",\"content\":\"Da sua\",\"image\":\"\",\"likeCount\":0,\"commentCount\":0}"
check "chủ bài PUT bài đăng -> 204" 204 "$(code -X PUT $BASE/api/PostApi/$POID -H "$J" -H "$U" -d "$BODY")"
check "PUT đã lưu nội dung" "Da sua" "$(curl -s $BASE/api/PostApi/$POID -H "$U" | jget content)"
check "PUT giữ nguyên createdAt" "$CREATED" "$(curl -s $BASE/api/PostApi/$POID -H "$U" | jget createdAt)"
check "PUT id lệch -> 400" 400 "$(code -X PUT $BASE/api/PostApi/$POID -H "$J" -H "$U" -d '{"id":99999,"content":"x"}')"
check "chủ bài DELETE -> 204" 204 "$(code -X DELETE $BASE/api/PostApi/$POID -H "$U")"; CLEAN_POSTS=()
check "GET bài đã xóa -> 404" 404 "$(code $BASE/api/PostApi/$POID -H "$U")"

echo
echo "Kết quả: $(green "$PASS đạt"), $( [ $FAIL -gt 0 ] && red "$FAIL lỗi" || echo "0 lỗi")"
[ $FAIL -eq 0 ]
