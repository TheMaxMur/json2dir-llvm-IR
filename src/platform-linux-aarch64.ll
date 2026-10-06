; Linux AArch64's struct stat has a 32-bit st_mode at byte offset 16.
source_filename = "platform-linux-aarch64.ll"
declare i32 @stat(ptr, ptr)
declare ptr @__errno_location()
define i32 @last_errno() {
  %p = call ptr @__errno_location()
  %e = load i32, ptr %p
  ret i32 %e
}
define i32 @file_mode(ptr %path) {
  %buf = alloca [256 x i8], align 16
  %status = call i32 @stat(ptr %path, ptr %buf)
  %ok = icmp eq i32 %status, 0
  br i1 %ok, label %read, label %error
read:
  %p = getelementptr i8, ptr %buf, i64 16
  %mode = load i32, ptr %p, align 4
  ret i32 %mode
error:
  ret i32 -1
}
