# W5 Day 1–3 — ConfigReport Engine

## 1. Code review slide

Không có slide hoặc mã `DynamicReporter`/Day 1–2 cũ trong workspace, nên không thể ghi số slide/dòng, xác nhận hành vi sandbox, hoặc đính ảnh exploit mà không bịa bằng chứng. Các đầu mối dưới đây là checklist cần đối chiếu với nguồn cũ, không phải kết luận đã xác minh:

| #    | Dòng code                              | Rủi ro cần kiểm chứng                                                                  | Payload/test để tái hiện                                 | Cách xử lý trong engine mới                                                      |
| ---- | -------------------------------------- | -------------------------------------------------------------------------------------- | -------------------------------------------------------- | -------------------------------------------------------------------------------- |
| D1.1 | CaseSelector: `BASE_FIELDS`            | Hằng có thể không được dùng; query có thể thiếu field/không ổn định                    | So sánh danh sách field thực tế trả về với hằng          | CaseSelector chuyển field list qua GenericSelector                               |
| D1.2 | `getCasesPaged`: `OFFSET`              | OFFSET bị giới hạn và tốn chi phí khi trang sâu                                        | Yêu cầu offset vượt 2,000                                | GenericSelector giới hạn OFFSET; keyset pagination vẫn là việc cần làm           |
| D1.3 | CaseSelector: security clauses         | Trộn `WITH SECURITY_ENFORCED` và `USER_MODE` làm hành vi/chuẩn bảo mật không nhất quán | Gọi query với user thiếu FLS                             | Engine mới chỉ chạy `queryWithBinds(..., USER_MODE)`                             |
| D1.4 | `escalateCriticalCases` / after update | DML trong after-update có thể đệ quy nếu không kiểm tra chuyển trạng thái              | Update Case sang Escalated rồi theo dõi trigger chạy lại | Chỉ xử lý chuyển trạng thái mới sang Escalated; DML service không tự gọi lại     |
| D1.5 | `@AuraEnabled(cacheable=true)`         | Lỗi FLS có thể bị trả thành lỗi client/cache không phù hợp                             | User thiếu FLS gọi LWC method                            | Entry point mới không cacheable và chuyển lỗi thành thông báo thân thiện         |
| D2.1 | `CaseFeatureFlags.isEnabled`           | So khớp hoa/thường làm flag đúng bị xem là thiếu/tắt                                   | Truyền `configreport`, `ConfigReport`, `CONFIGREPORT`    | Cache tên flag không phân biệt hoa/thường; thiếu flag mặc định false             |
| D2.2 | `onBeforeInsert` trong CaseService     | Sai trách nhiệm layer và khó test/routing                                              | Theo dõi Trigger/Handler/Service khi before insert       | Trigger routing, Handler dispatch, Service xử lý; không có nguồn cũ để đối chiếu |
| D2.3 | Hierarchy setting `getInstance()`      | Nhận định “không có record thì null” có thể sai vì API trả giá trị hợp nhất            | Gọi với org/profile/user chưa cấu hình                   | Engine kiểm tra null và field null/<=0, sau đó fallback 100                      |
| D2.4 | `(Integer) config.MaxOpenCases__c`     | Decimal/Number cast có thể không hợp lệ hoặc làm mất tính đúng đắn                     | Compile và kiểm thử giá trị Number                       | Dùng `Decimal.intValue()` sau kiểm tra null                                      |
| D2.5 | `applyDefaults` / SLA threshold        | Tier ngoài map có thể không có default hoặc gây lỗi                                    | Tier có giá trị chưa cấu hình                            | Chưa có source để chứng minh; domain/service phải chọn fallback hoặc từ chối rõ  |
| D3.1 | DynamicReporter `whereClause`          | Chuỗi WHERE thô cho phép thay đổi logic query                                          | `Status = 'Open' OR Id != null`                          | API mới chỉ nhận FilterCondition và bind value                                   |
| D3.2 | `escapeSingleQuotes` trên cả query     | Escape câu query hoàn chỉnh không làm parser an toàn                                   | `Status = 'Open'`                                        | Không dùng escape; literal values chỉ đi qua bind map                            |
| D3.3 | Field name không validate              | Có thể chèn FROM/WHERE vào cấu trúc query                                              | `Id FROM Case WHERE Subject != null --`                  | Mọi SELECT/WHERE/ORDER BY path resolve qua SchemaHelper                          |
| D3.4 | Thiếu `queryWithBinds`                 | Giá trị động có thể bị ghép vào SOQL                                                   | `x' OR Name != '`                                        | Một nơi duy nhất gọi queryWithBinds trong Selector                               |
| D3.5 | `getGlobalDescribe()` mỗi lần          | Tốn CPU/describe lặp                                                                   | Lặp 50 lần trong cùng transaction                        | SchemaHelper cache static global describe một lần/transaction                    |
| D3.6 | `lim` không có trần                    | Query trả quá nhiều row, vượt governor limits                                          | Null/âm/rất lớn                                          | Default 100, chặn bởi `maxRows` từ Service                                       |
| D3.7 | SYSTEM_MODE mặc định                   | Có thể vượt quyền CRUD/FLS của người gọi                                               | User thiếu FLS đọc field                                 | USER_MODE và test FLS                                                            |

Hai payload tấn công trên bản cũ: chưa thể chạy/chụp vì class cũ và sandbox nguồn không có trong workspace. Không dùng các payload này để khẳng định exploit đã thành công khi chưa tái hiện.

## 2. Thiết kế

- SchemaHelper cache global describe, object token, FLS field set theo user/object và resolved paths; giới hạn relationship tối đa ba cấp. Global describe được chọn vì yêu cầu cần tra object tùy ý, cache một lần/transaction và lookup case-insensitive; `describeSObjects()` hợp hơn khi tập object đầu vào nhỏ/biết trước.
- GenericSelector chỉ nhận object request. Tên object/field/operator được validate bằng Describe/whitelist; chỉ dữ liệu bind vào `:bN`. `USER_MODE` bảo vệ CRUD/FLS và sharing. Type coercion theo DisplayType trước khi query.
- CMDT giữ report definitions/feature flags vì cấu hình dùng chung, deploy được giữa org và không thay đổi theo user. Hierarchy Custom Setting giữ MaxRows vì giá trị có cấp org/profile/user. Thiếu setting fallback 100.
- Test Service/Case dùng CMDT thực tế: ConfigReport phải bật và Open_Cases phải được cấu hình hợp lệ. Không còn override map, counter hoặc quyền truy cập private dành riêng cho test. `Default_Filters__c` lưu default filter dạng JSON.
- Type.forName chỉ chấp nhận class implement IReportPostProcessor. Cần giới hạn quyền sửa CMDT/processor config cho administrator đáng tin cậy; interface không phải sandbox chống mã Apex đã được deploy trong org.

`runForLwc` không cacheable vì kết quả phụ thuộc dữ liệu/quyền hiện thời và cấu hình/flag theo transaction; ngoài ra, cache phía client có thể giữ dữ liệu PII hoặc kết quả cũ sau khi thay đổi quyền/flag.

## 3. SOQL mẫu

Đây là SOQL hình dạng dự kiến từ definitions trong source; bind map minh họa với fallback `maxRows=100`, chưa phải log runtime từ sandbox. Result hiện trả `bindCount`, không expose map bind; map được tạo nội bộ Selector.

```text
Open_Cases
SELECT Id, CaseNumber, Subject, Status, AccountId, CreatedDate FROM Case
WHERE IsClosed = :b0 AND AccountId IN :b1 ORDER BY Id ASC LIMIT :b2
binds = { b0: false, b1: [<account ids>], b2: 100 }

VIP_Accounts
SELECT Id, Name, Tier__c, Owner.Name FROM Account
WHERE Tier__c = :b0 ORDER BY Id ASC LIMIT :b1
binds = { b0: 'VIP', b1: 100 }

Contact_Directory
SELECT Id, Name, Email, Phone, Account.Name FROM Contact
ORDER BY Id ASC LIMIT :b0
binds = { b0: 100 }
```

## 4. Kết quả test

Giữ test class cho Domain, Selector, Service, PII processor và bulk Case flow, gọi API public. Sau khi bỏ test overrides/counters, bộ test không còn chứng minh đủ T1–T15: chưa tự động kiểm chứng T8 (processor sai), T9 (đúng một global describe), T10 (ép flag ConfigReport tắt), T11 (đủ bốn tổ hợp trong một lần chạy), T12 (hierarchy limits qua Service), và phần đếm 200 event của T15. Test bulk vẫn assert một query qua Limits.getQueries(). Logger cũng bỏ hai test gọi trực tiếp private retry handler; giữ test public save(). Các test đã bỏ có thể phục hồi từ Git.

Không chạy test theo yêu cầu của bạn. Chưa có ảnh pass, coverage từng class, xác nhận test cũ xanh hoặc kết quả PMD/Code Analyzer. Đây không phải báo cáo pass.

## 5. Giới hạn còn lại

- CaseSelector chữ ký cũ và test Day 1–2 không có trong repo; `getCasesPaged(pageSize, offsetSize)` hiện là chữ ký suy ra từ yêu cầu, chưa thể chứng minh tương thích ngược.
- Pagination hiện giữ OFFSET (giới hạn 2,000); nên chuyển sang keyset `(CreatedDate, Id)` nếu cần phân trang sâu.
- D5 tạo CSV đồng bộ trong trigger. Payload CSV bị chặn 32,768 ký tự; với report lớn nên chuyển sang Queueable/async và phát event sau khi tạo thành công.
- Chưa có bằng chứng sandbox cho hai payload DynamicReporter cũ; cần source và org sandbox để hoàn tất mục A.

## 6. Thời gian

Thời gian thực tế không được ghi tự động; cần người nộp điền giờ làm thực tế và phần tốn thời gian nhất trước khi nộp. Không nên điền số ước đoán.
