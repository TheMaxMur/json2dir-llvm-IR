; Darwin's struct stat has a 16-bit st_mode at byte offset 4.
source_filename = "platform-darwin-x86_64.ll"
declare i32 @"stat$INODE64"(ptr, ptr)
declare ptr @__error()
define i32 @last_errno() {
  %p = call ptr @__error()
  %e = load i32, ptr %p
  ret i32 %e
}
define i32 @file_mode(ptr %path) {
  %buf = alloca [256 x i8], align 16
  %status = call i32 @"stat$INODE64"(ptr %path, ptr %buf)
  %ok = icmp eq i32 %status, 0
  br i1 %ok, label %read, label %error
read:
  %p = getelementptr i8, ptr %buf, i64 4
  %mode = load i16, ptr %p, align 2
  %result = zext i16 %mode to i32
  ret i32 %result
error:
  ret i32 -1
}
