#!/usr/bin/env bash
# Kiểm thử tính năng mạng xã hội (bài đăng gắn tài khoản, thích, bình luận, upload, hồ sơ, thông báo, phân trang).
#   docs/social_tests.sh [BASE_URL]
# Cần backend đang chạy. Tự đăng ký admin1, user1, user2, user3; xóa lại dữ liệu đã tạo và khôi phục hồ sơ user1.

BASE="${1:-http://localhost:5126}"
HERE="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$HERE/../23DTHE1_pham_minh_vu"
UPLOADS_DIR="$BACKEND_DIR/wwwroot/uploads"
J='Content-Type: application/json'
PASS=0; FAIL=0
POSTS=(); UPLOADED=()
TMP="$(mktemp -d)"

green(){ printf '\033[32m%s\033[0m' "$1"; }; red(){ printf '\033[31m%s\033[0m' "$1"; }
check(){ if [ "$2" == "$3" ]; then PASS=$((PASS+1)); echo "  $(green PASS) $1"; else FAIL=$((FAIL+1)); echo "  $(red FAIL) $1  (mong đợi: $2, thực tế: $3)"; fi; }
jget(){ python3 -c "import sys,json
try:
    d=json.load(sys.stdin)
    for k in sys.argv[1].split('.'):
        d = d[int(k)] if isinstance(d,list) else d.get(k)
    print('' if d is None else d)
except Exception: print('')" "$1"; }
# api METHOD PATH TOKEN [BODY] -> R_CODE, R_BODY (body JSON truyền qua mảng tham số nên không lo lỗi dấu nháy)
api(){ local m="$1" p="$2" t="$3" b="${4:-}"; local a=(-s -w $'\n%{http_code}' -X "$m" "$BASE$p")
  [ -n "$t" ] && a+=(-H "Authorization: Bearer $t"); [ -n "$b" ] && a+=(-H "$J" -d "$b")
  local o; o=$(curl "${a[@]}"); R_CODE="${o##*$'\n'}"; R_BODY="${o%$'\n'*}"; }
login(){ curl -s -X POST "$BASE/api/Authenticate/login" -H "$J" -d "{\"username\":\"$1\",\"password\":\"$2\"}" | jget token; }
ensure(){ [ -z "$(login "$1" "$2")" ] && curl -s -o /dev/null -X POST "$BASE/api/Authenticate/register" -H "$J" -d "{\"username\":\"$1\",\"email\":\"$1@example.com\",\"password\":\"$2\",\"role\":\"$3\"}"; }
cleanup(){
  for id in "${POSTS[@]}"; do curl -s -o /dev/null -X DELETE "$BASE/api/PostApi/$id" -H "Authorization: Bearer $AT"; done
  # Chỉ xóa đúng các tệp test đã upload (tên ngẫu nhiên do server trả về); ${VAR:?} dừng lại nếu biến rỗng
  for f in "${UPLOADED[@]}"; do [ -n "$f" ] && rm -f "${UPLOADS_DIR:?}/${f:?}"; done
  [ -n "$T1" ] && [ -n "$ORIG1" ] && curl -s -o /dev/null -X PUT "$BASE/api/ProfileApi/me" -H "$J" -H "Authorization: Bearer $T1" -d "$(profile_body "$ORIG1")"
  [ -n "$TMP" ] && [ -d "$TMP" ] && rm -rf "${TMP:?}"
}
trap cleanup EXIT
# Thân PUT api/ProfileApi/me dựng từ một hồ sơ đã lưu ($1 = JSON của GET me); $2 (tùy chọn) = displayName thay thế
profile_body(){ python3 -c "
import sys,json
d=json.loads(sys.argv[1]); name=sys.argv[2] if len(sys.argv)>2 and sys.argv[2] else d.get('displayName') or ''
b={'displayName':name}
for k in ('avatarUrl','coverUrl','bio','phoneNumber'):
    if d.get(k): b[k]=d[k]
print(json.dumps(b))" "$1" "${2:-}"; }
# newpost TOKEN NỘI_DUNG -> id nằm trong biến NEWID. Không chạy trong $(...) vì subshell sẽ làm mất danh sách dọn dẹp POSTS.
newpost(){
  api POST /api/PostApi "$1" "$(python3 -c "import json,sys;print(json.dumps({'content':sys.argv[1]}))" "$2")"
  NEWID=$(echo "$R_BODY" | jget id); POSTS+=("$NEWID"); }

echo "Kiểm thử mạng xã hội  |  $BASE"
[ "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/ProductApi")" == "000" ] && { echo "Backend chưa chạy"; exit 2; }
ensure admin1 'Admin@12345' Admin; ensure user1 'User@12345' User; ensure user2 'User@12345' User; ensure user3 'User@12345' User
AT=$(login admin1 'Admin@12345'); T1=$(login user1 'User@12345'); T2=$(login user2 'User@12345'); T3=$(login user3 'User@12345')
api GET /api/ProfileApi/me "$T1"; U1=$(echo "$R_BODY" | jget id)
api GET /api/ProfileApi/me "$T2"; U2=$(echo "$R_BODY" | jget id)
api GET /api/ProfileApi/me "$T3"; U3=$(echo "$R_BODY" | jget id)
ORIG1=$(curl -s "$BASE/api/ProfileApi/me" -H "Authorization: Bearer $T1")   # hồ sơ gốc của user1, sẽ được khôi phục khi kết thúc
api PUT /api/ProfileApi/me "$T1" "$(profile_body "$ORIG1" user1)"             # chỉ đặt tên hiển thị = user1 cho bài test

echo "== Đăng nhập bắt buộc"
api GET /api/PostApi ""; check "GET bài đăng không token -> 401" 401 "$R_CODE"
api POST /api/PostApi "" '{"content":"x"}'; check "POST bài đăng không token -> 401" 401 "$R_CODE"
api POST /api/PostApi/1/like ""; check "thích không token -> 401" 401 "$R_CODE"
api GET /api/PostApi/1/comments ""; check "xem bình luận không token -> 401" 401 "$R_CODE"
api GET /api/ProfileApi/me ""; check "hồ sơ không token -> 401" 401 "$R_CODE"
api GET /api/NotificationApi ""; check "thông báo không token -> 401" 401 "$R_CODE"
api POST /api/UploadApi ""; check "upload không token -> 401" 401 "$R_CODE"

echo "== Bài đăng gắn tài khoản (server tự gán, bỏ qua giá trị client gửi)"
SPOOF=$(python3 -c "import json;print(json.dumps({'content':'Bai cua user1','image':'','userName':'HACKER','userAvatar':'https://evil.example/a.png','userId':'$U2','likeCount':999,'commentCount':999,'createdAt':'2000-01-01T00:00:00','id':12345}))")
api POST /api/PostApi "$T1" "$SPOOF"; P1=$(echo "$R_BODY" | jget id); POSTS+=("$P1")
check "user1 POST bài -> 201" 201 "$R_CODE"
check "userId = id user1 (bỏ qua userId client gửi)" "$U1" "$(echo "$R_BODY" | jget userId)"
check "userName = tên hiển thị user1 (không phải HACKER)" user1 "$(echo "$R_BODY" | jget userName)"
check "userAvatar không lấy từ client" "" "$(echo "$R_BODY" | jget userAvatar)"
check "likeCount bắt đầu từ 0" 0 "$(echo "$R_BODY" | jget likeCount)"
check "commentCount bắt đầu từ 0" 0 "$(echo "$R_BODY" | jget commentCount)"
check "id do server cấp (không phải 12345)" True "$([ "$P1" != "12345" ] && echo True || echo False)"
check "createdAt do server gán (không phải năm 2000)" True "$(echo "$R_BODY" | jget createdAt | python3 -c "import sys;print(sys.stdin.read().startswith('2026'))")"
check "chủ bài: canEdit = true" True "$(echo "$R_BODY" | jget canEdit)"
check "chủ bài: likedByMe = false" False "$(echo "$R_BODY" | jget likedByMe)"
api GET /api/PostApi/$P1 "$T2"; check "người khác: canEdit = false" False "$(echo "$R_BODY" | jget canEdit)"
api GET /api/PostApi/$P1 "$AT"; check "Admin: canEdit = true" True "$(echo "$R_BODY" | jget canEdit)"
api POST /api/PostApi "$T1" '{"content":"   ","image":""}'; check "bài rỗng -> 400" 400 "$R_CODE"
api POST /api/PostApi "$T1" '{"content":"x","image":"javascript:alert(1)"}'; check "ảnh scheme javascript: -> 400" 400 "$R_CODE"
api POST /api/PostApi "$T1" "$(python3 -c "import json;print(json.dumps({'content':'a'*2001}))")"; check "nội dung > 2000 ký tự -> 400" 400 "$R_CODE"

echo "== Sửa/xóa: chỉ chủ bài hoặc Admin"
api PUT /api/PostApi/$P1 "$T2" '{"content":"user2 sua bai user1"}'; check "user2 sửa bài của user1 -> 403" 403 "$R_CODE"
api DELETE /api/PostApi/$P1 "$T2"; check "user2 xóa bài của user1 -> 403" 403 "$R_CODE"
api GET /api/PostApi/$P1 "$T1"; check "bài chưa bị đổi sau khi bị từ chối" "Bai cua user1" "$(echo "$R_BODY" | jget content)"
api PUT /api/PostApi/$P1 "$AT" '{"content":"Admin sua bai"}'; check "Admin sửa bài của user1 -> 204" 204 "$R_CODE"
api GET /api/PostApi/$P1 "$T1"; check "Admin sửa đã lưu" "Admin sua bai" "$(echo "$R_BODY" | jget content)"
BEFORE=$(curl -s "$BASE/api/PostApi/$P1" -H "Authorization: Bearer $T1")
HACK=$(python3 -c "import json;print(json.dumps({'id':$P1,'content':'user1 sua','image':'','likeCount':500,'commentCount':500,'userId':'$U2','userName':'HACKER','createdAt':'1999-01-01T00:00:00'}))")
api PUT /api/PostApi/$P1 "$T1" "$HACK"; check "chủ bài sửa (kèm trường bị cấm) -> 204" 204 "$R_CODE"
api GET /api/PostApi/$P1 "$T1"
check "PUT đổi được content" "user1 sua" "$(echo "$R_BODY" | jget content)"
check "PUT không đổi likeCount" "$(echo "$BEFORE" | jget likeCount)" "$(echo "$R_BODY" | jget likeCount)"
check "PUT không đổi commentCount" "$(echo "$BEFORE" | jget commentCount)" "$(echo "$R_BODY" | jget commentCount)"
check "PUT không đổi userId" "$U1" "$(echo "$R_BODY" | jget userId)"
check "PUT không đổi createdAt" "$(echo "$BEFORE" | jget createdAt)" "$(echo "$R_BODY" | jget createdAt)"
api PUT /api/PostApi/$P1 "$T1" '{"id":999999,"content":"x"}'; check "PUT id lệch -> 400" 400 "$R_CODE"
api PUT /api/PostApi/999999 "$T1" '{"content":"x"}'; check "PUT bài không tồn tại -> 404" 404 "$R_CODE"
# Bài mẫu cũ (không có chủ): chỉ Admin
SEED=$(curl -s "$BASE/api/PostApi/3" -H "Authorization: Bearer $AT")
SEEDBODY=$(echo "$SEED" | python3 -c "import sys,json;d=json.load(sys.stdin);print(json.dumps({'content':d['content'],'image':d['image'] or ''}))")
api PUT /api/PostApi/3 "$T1" "$SEEDBODY"; check "user1 sửa bài mẫu (không có chủ) -> 403" 403 "$R_CODE"
api DELETE /api/PostApi/3 "$T1"; check "user1 xóa bài mẫu -> 403" 403 "$R_CODE"
api PUT /api/PostApi/3 "$AT" "$SEEDBODY"; check "Admin sửa bài mẫu -> 204" 204 "$R_CODE"
api GET /api/PostApi/3 "$T1"; check "bài mẫu: canEdit = false với user" False "$(echo "$R_BODY" | jget canEdit)"
check "bài mẫu vẫn giữ userName cũ" "$(echo "$SEED" | jget userName)" "$(echo "$R_BODY" | jget userName)"
check "bài mẫu: userId rỗng" "" "$(echo "$R_BODY" | jget userId)"

echo "== Thích (toggle, theo người)"
api GET /api/PostApi/$P1 "$T2"; BASE_LIKES=$(echo "$R_BODY" | jget likeCount)
api POST /api/PostApi/$P1/like "$T2"; check "user2 thích lần 1 -> liked=true" True "$(echo "$R_BODY" | jget liked)"; check "likeCount tăng 1" $((BASE_LIKES+1)) "$(echo "$R_BODY" | jget likeCount)"
api GET /api/PostApi/$P1 "$T2"; check "user2 xem: likedByMe = true" True "$(echo "$R_BODY" | jget likedByMe)"
api GET /api/PostApi/$P1 "$T1"; check "user1 xem: likedByMe = false" False "$(echo "$R_BODY" | jget likedByMe)"
api POST /api/PostApi/$P1/like "$T2"; check "user2 thích lần 2 -> liked=false (bỏ thích)" False "$(echo "$R_BODY" | jget liked)"; check "likeCount về lại" "$BASE_LIKES" "$(echo "$R_BODY" | jget likeCount)"
api POST /api/PostApi/$P1/like "$T2"; api POST /api/PostApi/$P1/like "$T1"
check "2 người thích -> likeCount = 2" 2 "$(echo "$R_BODY" | jget likeCount)"
api POST /api/PostApi/999999/like "$T1"; check "thích bài không tồn tại -> 404" 404 "$R_CODE"
api POST /api/PostApi/4/like "$T1"; check "bài mẫu: 21 + 1 = 22" 22 "$(echo "$R_BODY" | jget likeCount)"
api POST /api/PostApi/4/like "$T1"; check "bài mẫu: bỏ thích về 21" 21 "$(echo "$R_BODY" | jget likeCount)"
# 12 request thích song song của cùng một người: không được lỗi 500 và không được trùng dòng
newpost "$T1" "Bai thu thich song song"; LP=$NEWID
seq 1 12 | xargs -P 12 -I{} curl -s -o /dev/null -w '%{http_code}\n' -X POST "$BASE/api/PostApi/$LP/like" -H "Authorization: Bearer $T2" > "$TMP/par.txt"
check "12 lần thích song song: không có mã 500" 0 "$(grep -c '^500$' "$TMP/par.txt")"
api GET /api/PostApi/$LP "$T2"; check "sau thích song song: likeCount là 0 hoặc 1" True "$([ "$(echo "$R_BODY" | jget likeCount)" -le 1 ] && echo True || echo False)"

echo "== Bình luận"
api POST /api/PostApi/$P1/comments "$T2" '{"content":"Binh luan cua user2"}'; C1=$(echo "$R_BODY" | jget id)
check "user2 bình luận -> 201" 201 "$R_CODE"
check "bình luận: userName = tên hiển thị" user2 "$(echo "$R_BODY" | jget userName)"
check "bình luận: người viết canDelete = true" True "$(echo "$R_BODY" | jget canDelete)"
api POST /api/PostApi/$P1/comments "$T2" '{"content":"   "}'; check "bình luận rỗng -> 400" 400 "$R_CODE"
api POST /api/PostApi/$P1/comments "$T2" "$(python3 -c "import json;print(json.dumps({'content':'a'*501}))")"; check "bình luận > 500 ký tự -> 400" 400 "$R_CODE"
api POST /api/PostApi/999999/comments "$T2" '{"content":"x"}'; check "bình luận bài không tồn tại -> 404" 404 "$R_CODE"
api GET /api/PostApi/$P1/comments "$T3"; check "xem bình luận: có 1" 1 "$(echo "$R_BODY" | python3 -c "import sys,json;print(len(json.load(sys.stdin)))")"
check "người lạ (user3): canDelete = false" False "$(echo "$R_BODY" | jget 0.canDelete)"
api GET /api/PostApi/$P1/comments "$T1"; check "chủ bài (user1): canDelete = true" True "$(echo "$R_BODY" | jget 0.canDelete)"
api GET /api/PostApi/$P1 "$T1"; check "commentCount của bài = 1" 1 "$(echo "$R_BODY" | jget commentCount)"
api DELETE /api/PostApi/$P1/comments/$C1 "$T3"; check "người lạ xóa bình luận -> 403" 403 "$R_CODE"
api DELETE /api/PostApi/$P1/comments/$C1 "$T2"; check "chủ bình luận xóa -> 204" 204 "$R_CODE"
api POST /api/PostApi/$P1/comments "$T2" '{"content":"lan 2"}'; C2=$(echo "$R_BODY" | jget id)
api DELETE /api/PostApi/$P1/comments/$C2 "$T1"; check "chủ bài xóa bình luận của người khác -> 204" 204 "$R_CODE"
api POST /api/PostApi/$P1/comments "$T2" '{"content":"lan 3"}'; C3=$(echo "$R_BODY" | jget id)
api DELETE /api/PostApi/$P1/comments/$C3 "$AT"; check "Admin xóa bình luận -> 204" 204 "$R_CODE"
api DELETE /api/PostApi/$P1/comments/$C3 "$AT"; check "xóa bình luận không còn -> 404" 404 "$R_CODE"
api DELETE /api/PostApi/$P1/comments/$C1 "$T2"; check "xóa lại bình luận đã xóa -> 404" 404 "$R_CODE"

echo "== Thông báo (7 ngày gần nhất, không tính hành động của chính mình)"
newpost "$T1" "Bai de thu thong bao"; NP=$NEWID
api POST /api/PostApi/$NP/like "$T2" ; api POST /api/PostApi/$NP/comments "$T2" '{"content":"Noi dung thong bao"}'
api POST /api/PostApi/$NP/like "$T1"; api POST /api/PostApi/$NP/comments "$T1" '{"content":"tu binh luan"}'
api GET /api/NotificationApi "$T1"; NOTI="$R_BODY"
check "user1 nhận thông báo 'like' từ user2" 1 "$(echo "$NOTI" | python3 -c "import sys,json;print(sum(1 for n in json.load(sys.stdin) if n['type']=='like' and n['postId']==$NP and n['actorName']=='user2'))")"
check "user1 nhận thông báo 'comment' từ user2" 1 "$(echo "$NOTI" | python3 -c "import sys,json;print(sum(1 for n in json.load(sys.stdin) if n['type']=='comment' and n['postId']==$NP and n['actorName']=='user2' and n['commentContent']=='Noi dung thong bao'))")"
check "không có thông báo do chính user1 gây ra" 0 "$(echo "$NOTI" | python3 -c "import sys,json;print(sum(1 for n in json.load(sys.stdin) if n['actorId']=='$U1'))")"
api GET /api/NotificationApi "$T2"; check "user2 không có thông báo về bài của user1" 0 "$(echo "$R_BODY" | python3 -c "import sys,json;print(sum(1 for n in json.load(sys.stdin) if n['postId']==$NP))")"

echo "== Phân trang"
for i in 1 2 3; do newpost "$T1" "Trang $i"; done
api GET "/api/PostApi?page=1&pageSize=2" "$T1"; PG1="$R_BODY"
check "page=1&pageSize=2 -> 2 bài" 2 "$(echo "$PG1" | python3 -c "import sys,json;print(len(json.load(sys.stdin)['items']))")"
check "có totalCount" True "$(echo "$PG1" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['totalCount']>=2)")"
check "hasMore = true" True "$(echo "$PG1" | jget hasMore)"
api GET "/api/PostApi?page=2&pageSize=2" "$T1"
check "trang 2 không trùng trang 1" 0 "$(python3 -c "
import json,sys
a={p['id'] for p in json.loads(sys.argv[1])['items']}; b={p['id'] for p in json.loads(sys.argv[2])['items']}
print(len(a&b))" "$PG1" "$R_BODY")"
api GET "/api/PostApi?page=1&pageSize=500" "$T1"; check "pageSize quá lớn bị giới hạn 50" 50 "$(echo "$R_BODY" | jget pageSize)"
api GET "/api/PostApi?page=99999&pageSize=10" "$T1"; check "trang vượt quá -> items rỗng, hasMore=false" "0/False" "$(echo "$R_BODY" | python3 -c "import sys,json;d=json.load(sys.stdin);print(str(len(d['items']))+'/'+str(d['hasMore']))")"
api GET "/api/PostApi?page=0" "$T1"; check "page=0 -> 400" 400 "$R_CODE"
api GET "/api/PostApi?page=1&pageSize=0" "$T1"; check "pageSize=0 -> 400" 400 "$R_CODE"
api GET /api/PostApi "$T1"
check "không truyền page: trả MẢNG như cũ" list "$(echo "$R_BODY" | python3 -c "import sys,json;print('list' if isinstance(json.load(sys.stdin),list) else 'khac')")"
check "không truyền page: tối đa 50 bài" True "$(echo "$R_BODY" | python3 -c "import sys,json;print(len(json.load(sys.stdin))<=50)")"
check "sắp xếp mới nhất trước" True "$(echo "$R_BODY" | python3 -c "
import sys,json
d=[p['createdAt'] for p in json.load(sys.stdin)]
print(d==sorted(d,reverse=True))")"

echo "== Hồ sơ"
api GET /api/ProfileApi/me "$T1"
check "me: có email (riêng tư)" user1@example.com "$(echo "$R_BODY" | jget email)"
check "me: roles chứa User" User "$(echo "$R_BODY" | jget roles.0)"
BIG50=$(python3 -c "print('a'*51)")
api PUT /api/ProfileApi/me "$T1" "{\"displayName\":\"$BIG50\"}"; check "tên hiển thị > 50 ký tự -> 400" 400 "$R_CODE"
api PUT /api/ProfileApi/me "$T1" '{"displayName":"  "}'; check "tên hiển thị rỗng -> 400" 400 "$R_CODE"
api PUT /api/ProfileApi/me "$T1" "{\"displayName\":\"ok\",\"bio\":\"$(python3 -c "print('b'*201)")\"}"; check "bio > 200 ký tự -> 400" 400 "$R_CODE"
api PUT /api/ProfileApi/me "$T1" '{"displayName":"ok","avatarUrl":"javascript:alert(1)"}'; check "avatar scheme javascript: -> 400" 400 "$R_CODE"
api PUT /api/ProfileApi/me "$T1" '{"displayName":"ok","phoneNumber":"abc"}'; check "số điện thoại sai -> 400" 400 "$R_CODE"
api PUT /api/ProfileApi/me "$T1" '{"displayName":"User Mot","avatarUrl":"https://flutter.github.io/assets-for-api-docs/assets/widgets/owl.jpg","coverUrl":"https://flutter.github.io/assets-for-api-docs/assets/widgets/falcon.jpg","bio":"Xin chao","phoneNumber":"0901234567"}'
check "PUT me hợp lệ -> 200" 200 "$R_CODE"
check "PUT me đã lưu displayName" "User Mot" "$(echo "$R_BODY" | jget displayName)"
api GET /api/PostApi/$P1 "$T2"
check "bài cũ hiện TÊN MỚI của chủ bài (theo hồ sơ)" "User Mot" "$(echo "$R_BODY" | jget userName)"
check "bài cũ hiện AVATAR mới của chủ bài" "https://flutter.github.io/assets-for-api-docs/assets/widgets/owl.jpg" "$(echo "$R_BODY" | jget userAvatar)"
api GET /api/ProfileApi/$U1 "$T2"
check "hồ sơ công khai: displayName" "User Mot" "$(echo "$R_BODY" | jget displayName)"
check "hồ sơ công khai: có bio" "Xin chao" "$(echo "$R_BODY" | jget bio)"
check "hồ sơ công khai: KHÔNG có email" "" "$(echo "$R_BODY" | jget email)"
check "hồ sơ công khai: KHÔNG có phoneNumber" "" "$(echo "$R_BODY" | jget phoneNumber)"
check "hồ sơ công khai: KHÔNG có userName (tên đăng nhập)" "" "$(echo "$R_BODY" | jget userName)"
check "hồ sơ công khai: KHÔNG lộ passwordHash" "" "$(echo "$R_BODY" | jget passwordHash)"
api GET /api/ProfileApi/khong-co-user "$T1"; check "hồ sơ người không tồn tại -> 404" 404 "$R_CODE"
api GET "/api/ProfileApi/$U1/posts?page=1&pageSize=2" "$T2"
check "bài của user1: đúng 2 bài trang 1" 2 "$(echo "$R_BODY" | python3 -c "import sys,json;print(len(json.load(sys.stdin)['items']))")"
check "bài của user1: toàn bộ thuộc user1" 0 "$(echo "$R_BODY" | python3 -c "import sys,json;print(sum(1 for p in json.load(sys.stdin)['items'] if p['userId']!='$U1'))")"
api GET "/api/ProfileApi/$U3/posts" "$T1"; check "bài của người chưa đăng gì: rỗng" 0 "$(echo "$R_BODY" | jget totalCount)"
api GET "/api/ProfileApi/khong-co-user/posts" "$T1"; check "bài của người không tồn tại -> 404" 404 "$R_CODE"
api PUT /api/ProfileApi/me "$T1" "$(profile_body "$ORIG1")"; check "khôi phục hồ sơ gốc của user1 -> 200" 200 "$R_CODE"
check "hồ sơ gốc được khôi phục nguyên vẹn (kể cả số điện thoại)" "$(echo "$ORIG1" | jget phoneNumber)" "$(echo "$R_BODY" | jget phoneNumber)"

echo "== Token cũ (cấp trước khi có claim Id) vẫn dùng được"
OLD=$(python3 - <<PY
import json,base64,hmac,hashlib,time
cfg=json.load(open("$BACKEND_DIR/appsettings.json"))["JWTKey"]
b=lambda x: base64.urlsafe_b64encode(x).rstrip(b"=")
h=b(json.dumps({"alg":"HS256","typ":"JWT"}).encode())
p=b(json.dumps({"http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name":"user1",
  "http://schemas.microsoft.com/ws/2008/06/identity/claims/role":"User","exp":int(time.time())+600,
  "iss":cfg["ValidIssuer"],"aud":cfg["ValidAudience"]}).encode())
s=b(hmac.new(cfg["Secret"].encode(),h+b"."+p,hashlib.sha256).digest())
print((h+b"."+p+b"."+s).decode())
PY
)
api GET /api/ProfileApi/me "$OLD"; check "token không có claim Id -> vẫn nhận ra user1" "$U1" "$(echo "$R_BODY" | jget id)"
api GET /api/PostApi "$OLD"; check "token cũ gọi GET bài đăng -> 200" 200 "$R_CODE"

echo "== Upload ảnh"
python3 - "$TMP" <<'PY'
import sys,base64,os
d=sys.argv[1]
w=lambda n,b: open(os.path.join(d,n),'wb').write(b)
png=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==')
w('ok.png',png)
w('ok.jpg',b'\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xff\xd9')
w('ok.webp',b'RIFF\x1a\x00\x00\x00WEBPVP8 \x0e\x00\x00\x00'+b'\x00'*14)
w('evil.jpg',b'MZ\x90\x00\x03\x00\x00\x00\x04\x00\x00\x00\xff\xff\x00\x00This program cannot be run in DOS mode')  # .exe đổi đuôi .jpg
w('png_as_jpg.jpg',png)                                   # nội dung PNG nhưng đuôi .jpg
w('png_as_exe.exe',png)                                   # ảnh thật nhưng đuôi .exe
w('anim.gif',b'GIF89a\x01\x00\x01\x00\x00\x00\x00;')       # GIF không được phép
w('script.html',b'<script>alert(1)</script>')
w('big.png',png+b'\x00'*(5*1024*1024+512*1024))           # 5,5MB
w('huge.png',png+b'\x00'*(7*1024*1024))                   # 7MB
w('empty.png',b'')
PY
BEFORE_COUNT=$(ls "$UPLOADS_DIR" 2>/dev/null | grep -vc '^.gitkeep$')
up(){ curl -s -w $'\n%{http_code}' -X POST "$BASE/api/UploadApi" -H "Authorization: Bearer $T1" -F "file=@$1${2:+;filename=$2}"; }
for f in ok.png ok.jpg ok.webp; do
  O=$(up "$TMP/$f"); C="${O##*$'\n'}"; B="${O%$'\n'*}"; URL=$(echo "$B" | jget url)
  check "upload $f hợp lệ -> 200 + url" "200" "$C"
  NAME="${URL##*/}"; UPLOADED+=("$NAME")
  check "url đầy đủ $BASE/uploads/<32 hex>.<đuôi>" True "$(echo "$URL" | python3 -c "import sys,re;print(bool(re.fullmatch(r'$BASE/uploads/[0-9a-f]{32}\.(jpg|png|webp)',sys.stdin.read().strip())))")"
  check "tải ảnh về qua url -> 200" 200 "$(curl -s -o /dev/null -w '%{http_code}' "$URL")"
done
check "ảnh phục vụ kèm X-Content-Type-Options: nosniff" nosniff "$(curl -sI "$BASE/uploads/${UPLOADED[0]}" | tr -d '\r' | awk -F': ' 'tolower($1)=="x-content-type-options"{print $2}')"
check "Content-Type ảnh png" image/png "$(curl -sI "$BASE/uploads/${UPLOADED[0]}" | tr -d '\r' | awk -F': ' 'tolower($1)=="content-type"{print $2}')"
O=$(up "$TMP/evil.jpg"); check ".exe đổi đuôi .jpg bị từ chối (400)" 400 "${O##*$'\n'}"
O=$(up "$TMP/png_as_jpg.jpg"); check "nội dung PNG nhưng đuôi .jpg bị từ chối (400)" 400 "${O##*$'\n'}"
O=$(up "$TMP/png_as_exe.exe"); check "đuôi .exe bị từ chối (400)" 400 "${O##*$'\n'}"
O=$(up "$TMP/anim.gif"); check "đuôi .gif bị từ chối (400)" 400 "${O##*$'\n'}"
O=$(up "$TMP/script.html"); check "tệp .html bị từ chối (400)" 400 "${O##*$'\n'}"
O=$(up "$TMP/empty.png"); check "tệp rỗng bị từ chối (400)" 400 "${O##*$'\n'}"
O=$(up "$TMP/big.png"); check "ảnh 5,5MB bị từ chối (413)" 413 "${O##*$'\n'}"
O=$(up "$TMP/huge.png"); check "ảnh 7MB bị từ chối (413)" 413 "${O##*$'\n'}"
O=$(curl -s -w $'\n%{http_code}' -X POST "$BASE/api/UploadApi" -H "Authorization: Bearer $T1"); check "không gửi tệp -> 400" 400 "${O##*$'\n'}"
# path traversal: tên tệp client gửi KHÔNG được dùng
O=$(up "$TMP/ok.png" "../../evil.png"); C="${O##*$'\n'}"; URL=$(echo "${O%$'\n'*}" | jget url); [ -n "$URL" ] && UPLOADED+=("${URL##*/}")
check "tên tệp '../../evil.png' vẫn upload được nhưng bị bỏ qua (200)" 200 "$C"
check "tên lưu không chứa tên client gửi" False "$(echo "$URL" | python3 -c "import sys;print('evil' in sys.stdin.read())")"
check "không có tệp evil.png nào bị ghi ra ngoài uploads" 0 "$(find "$BACKEND_DIR" -name 'evil*' -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null | wc -l | tr -d ' ')"
AFTER_COUNT=$(ls "$UPLOADS_DIR" | grep -vc '^.gitkeep$')
check "chỉ các ảnh hợp lệ mới được lưu (4 tệp)" 4 "$((AFTER_COUNT-BEFORE_COUNT))"
O=$(curl -s -o /dev/null -w '%{http_code}' --path-as-is "$BASE/uploads/../appsettings.json"); check "không đọc được appsettings.json qua /uploads/.." True "$([ "$O" != "200" ] && echo True || echo False)"
# dùng url ảnh upload cho bài đăng
IMGBODY=$(python3 -c "import json,sys; d={'content':'Bai co anh upload','image':sys.argv[1]}; print(json.dumps(d))" "$BASE/uploads/${UPLOADED[0]}")
api POST /api/PostApi "$T1" "$IMGBODY"; POSTS+=("$(echo "$R_BODY" | jget id)")
check "đăng bài với ảnh vừa upload -> 201" 201 "$R_CODE"

echo "== Xóa bài => xóa like và bình luận theo; Admin xóa được bài bất kỳ"
newpost "$T1" "Bai de xoa cascade"; DP=$NEWID
api POST /api/PostApi/$DP/like "$T2" >/dev/null; api POST /api/PostApi/$DP/comments "$T2" '{"content":"se bi xoa theo"}' >/dev/null
api DELETE /api/PostApi/$DP "$AT"; check "Admin xóa bài của user1 -> 204" 204 "$R_CODE"
api GET /api/PostApi/$DP "$T1"; check "bài đã xóa -> 404" 404 "$R_CODE"
api GET /api/PostApi/$DP/comments "$T1"; check "bình luận của bài đã xóa -> 404" 404 "$R_CODE"
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^sqlserver$'; then
  PW=$(python3 -c "import json,re;print(re.search(r'Password=([^;]+)',json.load(open('$BACKEND_DIR/appsettings.json'))['ConnectionStrings']['DefaultConnection']).group(1))")
  N=$(docker exec sqlserver /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "$PW" -d 23DTHE1_pham_minh_vu -h -1 -W -Q "SET NOCOUNT ON; SELECT (SELECT COUNT(*) FROM [identity].PostLikes WHERE PostId=$DP) + (SELECT COUNT(*) FROM [identity].Comments WHERE PostId=$DP)" 2>/dev/null | tr -d '[:space:]')
  check "CSDL: không còn dòng like/bình luận của bài đã xóa" 0 "$N"
fi

echo
echo "Kết quả: $(green "$PASS đạt"), $( [ $FAIL -gt 0 ] && red "$FAIL lỗi" || echo "0 lỗi")"
[ $FAIL -eq 0 ]
