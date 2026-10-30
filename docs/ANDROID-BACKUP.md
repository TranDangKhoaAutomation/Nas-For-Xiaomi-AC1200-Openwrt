# Ảnh, video và sao lưu trong Khoa NAS 2.3

## Xem ảnh và video

Mở **Tệp**, chọn chia sẻ và thư mục trên NAS. Chọn **Lưới** để xem hình thu nhỏ hoặc **Danh sách** để duyệt nhanh. Video có nhãn thời lượng khi thiết bị đọc được metadata. Chạm ảnh để phóng to; chạm video để phát, tạm dừng hoặc tua trực tiếp. Nút tải xuống vẫn có sẵn khi cần giữ tệp trên điện thoại.

Ảnh/video truyền qua phiên SMB đã đăng nhập và HTTP loopback riêng trong app. Không tạo liên kết công khai. Hình thu nhỏ có bộ nhớ đệm giới hạn; lần đầu cần đọc dữ liệu qua mạng nên có thể chậm. Codec như HEVC/HEIC/MKV phụ thuộc Android và phần cứng. Định dạng không hỗ trợ sẽ báo lỗi và cho tải xuống. Xem ảnh vẫn cần truyền dữ liệu ảnh; “xem trực tiếp” không có nghĩa là không dùng lưu lượng mạng.

## Cắt và xoay ảnh

1. Mở ảnh trên NAS, bấm biểu tượng bút **Cắt và xoay ảnh**.
2. Chờ lấy ảnh vào vùng tạm riêng của ứng dụng. Chỉnh khung cắt, xoay hoặc chọn tỉ lệ trong trình sửa.
3. Xác nhận rồi chọn **Lưu bản sao**. App tạo tệp `ten-anh_da-sua_<thoi-diem>.jpg` trong cùng thư mục NAS, giữ ảnh gốc.

Bản chỉnh sửa là JPEG chất lượng 95; ảnh có thể mất độ trong suốt/ảnh động và một số metadata. Nếu hủy, không gửi bản sửa lên NAS. Cần quyền ghi SMB. Không sửa video trong phiên bản này.

## Bật tự sao lưu

1. Mở tab **Sao lưu**, bấm biểu tượng thêm thư mục. Trong trình chọn Android, chọn **Camera**, **Screenshots** hoặc thư mục mong muốn và tự cấp quyền đọc. Có thể thêm tối đa 16 thư mục, gồm các thư mục con. App không xin quyền đọc toàn bộ bộ nhớ.
2. Chọn **Ảnh**, **Video** hoặc cả hai.
3. Mở **Thiết lập sao lưu**, nhập IP router, tên chia sẻ SMB, thư mục đích, tài khoản và mật khẩu SMB. Thông số hiện tại được điền gợi ý nếu đang kết nối, nhưng chỉ lưu khi bạn bấm **Lưu thiết lập**.
4. Chọn kết nối từ xa qua Tailscale hoặc LAN. Với từ xa, đăng nhập Tailscale trong tab **Kết nối** trước.
5. Chọn lịch 15 phút / 1 giờ / 6 giờ / 1 ngày, Wi-Fi không tính phí và tùy chọn đang sạc. Mặc định chỉ mạng không tính phí, yêu cầu pin không yếu, tự sao lưu **tắt**.
6. Bật **Tự động sao lưu** và bấm **Lưu thiết lập**. Hoặc giữ tự động tắt rồi bấm **Sao lưu ngay** sau khi lưu để chạy một lượt.

Nút **Sao lưu ngay** vẫn tuân theo điều kiện mạng/sạc/pin. Khi vừa sửa thiết lập, lưu trước khi chạy. **Dừng** hủy công việc đang chờ/chạy và tắt tự sao lưu. Sau khi dừng xong có thể sửa thông số rồi bật lại.

## Cách lưu dữ liệu

- Một chiều từ thư mục được chọn trên điện thoại lên NAS; không xóa ảnh điện thoại và không đồng bộ thao tác xóa từ NAS về điện thoại.
- Đích: `<thu-muc-dich>/<ma-thu-muc-nguon>/<nam>/<thang>/<ten>_<ma-phien-ban>.<duoi>`. Ngày lấy từ thời điểm sửa tệp do Android cung cấp, chưa phải EXIF/ngày chụp. Không có ngày thì dùng `Khong-ro-ngay`.
- Phiên bản được nhận bằng URI, kích thước và thời điểm sửa; provider thiếu thời điểm sửa dùng hash nội dung. Chỉnh sửa ảnh tại nguồn được sao lưu thành phiên bản mới khi metadata phản ánh thay đổi. Provider báo sai metadata có thể cần chọn nguồn từ bộ nhớ máy để hoạt động chính xác.
- Tệp hoàn tất được ghi vào chỉ mục riêng của app để không tải lại ở mỗi lượt. Nếu bạn xóa bản sao trên NAS, chỉ mục không tự phát hiện việc xóa để tải lại. Đổi thư mục đích sẽ tạo tập sao lưu mới.
- Tệp gửi dở nằm ở tên ẩn `.khoanas-*.part` rồi đổi tên khi hoàn tất. Sau mất mạng, lượt sau có thể gửi tiếp. Nếu đổi nguồn/đích, tệp tạm cũ có thể còn lại; chỉ xóa khi chắc không có lượt sao lưu đang dùng.
- Không mã hóa lại ảnh trong sao lưu; sao chép bytes gốc. Bản sửa từ trình cắt ảnh là JPEG riêng. NAS BitLocker vẫn được mã hóa ở lớp ổ đĩa.

## Chạy nền và xử lý lỗi

Lịch dùng [Android WorkManager](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work), vì vậy Android có thể hoãn theo pin/mạng/Doze. Mỗi lượt có giới hạn thời gian và sẽ thử lại/gửi tiếp khi chưa xong. Buộc dừng app sẽ ngừng lịch cho đến khi mở lại. Gỡ app/xóa dữ liệu làm mất thiết lập và chỉ mục, nhưng không xóa dữ liệu đã lưu trên NAS.

Thiết lập/mật khẩu sao lưu mã hóa bằng khóa Android Keystore và chỉ dùng trong app. Không hiện mật khẩu đã lưu, không đưa vào URL/log/Git. Chọn lại thư mục nếu quyền đọc bị thu hồi. Sau khi đổi mật khẩu SMB, cập nhật mật khẩu trong thiết lập sao lưu.

Nếu chậm, kiểm tra LAN hay từ xa, đường Tailscale direct hay relay, tốc độ upload Internet phía NAS và tải CPU/USB router. Đường Windows → router trong lần đo 30/10 đi DERP Hong Kong khoảng 49–57 ms; chưa xác minh đường Samsung. Không suy ra tốc độ mới từ số liệu đó. [Giải thích đường truyền của Tailscale](https://tailscale.com/docs/reference/connection-types).

**Phạm vi kiểm thử 2.3:** kiểm thử UI/đường dẫn/range video và gửi tiếp có kết quả trong [báo cáo](../reports/2026-10-30-android-2.3/README.md). Chưa xác minh sao lưu nền qua router thật/4G khi router đang mất truy cập quản trị.
