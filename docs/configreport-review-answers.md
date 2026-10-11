# Gợi ý trả lời hỏi miệng

1. `Database.query()` hiểu bind scope của Apex caller, không resolve biến bind động trong chuỗi được lắp ở method khác. `queryWithBinds` nhận map name/value rõ ràng nên tách cấu trúc query và dữ liệu.
2. Bind chỉ thay thế literal values, không thay thế identifier/keyword. Validate object/field qua Schema Describe, operator bằng whitelist, và direction bằng ASC/DESC cố định.
3. `USER_MODE` ném query exception khi field/object không được phép; `stripInaccessible()` loại field không truy cập được khỏi record. Dùng USER_MODE khi query phải fail closed; strip khi sản phẩm chủ ý trả phần dữ liệu được phép.
4. `SObject.get()` không resolve dotted path như `Account.Name`. Đi qua `getSObject('Account')`, rồi `.get('Name')`, kiểm tra null ở mỗi quan hệ.
5. `describeSObjects()` thường phù hợp/nhẹ hơn nếu chỉ cần describe một nhóm object đã biết; global describe tra object tùy ý thuận tiện nhưng nên cache; `Type.forName().newInstance()` có overhead class lookup/constructor và không phải API describe chuẩn.
6. Với namespace, resolve tên qualified phù hợp và dùng overload namespace/class nếu cần; type phải có constructor public không tham số cho `newInstance()`, nếu không khởi tạo sẽ lỗi.
7. CMDT sửa được có thể trỏ tới implementation khác và kích hoạt hành vi Apex trong org. Kiểm tra interface là tối thiểu; bảo vệ quyền sửa CMDT, giới hạn class theo allowlist/namespace nếu yêu cầu threat model cao hơn.
8. Long Text Area thường không filterable; selector báo lỗi ở bước validate `isFilterable()` trước khi phát query.
9. Nếu khác môi trường nhưng cùng chính sách per org/profile/user, giữ Hierarchy Custom Setting và seed từng org. Nếu cần quản trị/triển khai theo môi trường, CMDT có lợi hơn nhưng không cung cấp override user/profile.
10. Static cache sống theo transaction. Batch Apex mỗi execute chunk là transaction riêng nên chunk sau thường đọc cấu hình mới; chunk đang chạy giữ cache transaction hiện tại.
11. Đây là generic configured selector để đáp ứng report tùy biến; nó trade-off so với selector per object có query name rõ. Giữ validation chặt/USER_MODE và chỉ gọi qua service. Domain Selector chuyên biệt vẫn tốt hơn cho use case nghiệp vụ ổn định.
12. Đồng bộ trigger tiêu thụ SOQL rows/CPU/heap và có thể làm hỏng giao dịch Case nếu report/event lỗi. Dùng Queueable khi CSV/report nặng, retry/observability quan trọng, hoặc không cần event hoàn tất trong cùng transaction.
