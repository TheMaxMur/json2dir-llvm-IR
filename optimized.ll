; ModuleID = 'src/json2dir.ll'
source_filename = "json2dir.ll"

%Parser = type { ptr, i64, i64, i32 }

@arena = internal unnamed_addr global ptr null
@errstream = internal unnamed_addr global ptr null
@mode_read = private unnamed_addr constant [3 x i8] c"rb\00"
@mode_write = private unnamed_addr constant [3 x i8] c"wb\00"
@dot = private unnamed_addr constant [2 x i8] c".\00"
@parent = private unnamed_addr constant [3 x i8] c"..\00"
@word_link = private unnamed_addr constant [5 x i8] c"link\00"
@word_script = private unnamed_addr constant [7 x i8] c"script\00"
@msg_oom = private unnamed_addr constant [23 x i8] c"Error: out of memory.\0A\00"
@msg_usage = private unnamed_addr constant [29 x i8] c"Usage: json2dir < file.json\0A\00"
@msg_read = private unnamed_addr constant [59 x i8] c"Error: couldn't read stdin to an internal representation.\0A\00"
@msg_utf8 = private unnamed_addr constant [44 x i8] c"Error: couldn't read stdin: invalid UTF-8.\0A\00"
@msg_parse = private unnamed_addr constant [40 x i8] c"Error: couldn't convert stdin to JSON.\0A\00"
@msg_top = private unnamed_addr constant [48 x i8] c"Error: expected provided JSON to be an object.\0A\00"
@msg_io = private unnamed_addr constant [33 x i8] c"Error: couldn't %s at \22%s\22: %s.\0A\00"
@msg_array = private unnamed_addr constant [79 x i8] c"Error: expected a JSON array to be of the form [type, payload] while at \22%s\22.\0A\00"
@msg_kind = private unnamed_addr constant [93 x i8] c"Error: expected a JSON array's first element to be either \22link\22 or \22script\22 while at \22%s\22.\0A\00"
@msg_nul = private unnamed_addr constant [61 x i8] c"Error: a filesystem path contains a NUL byte while at \22%s\22.\0A\00"
@msg_value = private unnamed_addr constant [84 x i8] c"Error: expected a JSON value to be an object, an array, or a string while at \22%s\22.\0A\00"
@msg_multiple = private unnamed_addr constant [70 x i8] c"Error: the key \22%s\22 under \22%s\22 must have exactly one path component.\0A\00"
@msg_component = private unnamed_addr constant [65 x i8] c"Error: the key \22%s\22 under \22%s\22 is a non-regular path component.\0A\00"
@action_write = private unnamed_addr constant [13 x i8] c"write a file\00"
@action_script = private unnamed_addr constant [16 x i8] c"create a script\00"
@action_file = private unnamed_addr constant [22 x i8] c"create a regular file\00"
@action_chmod = private unnamed_addr constant [27 x i8] c"make the script executable\00"
@action_link = private unnamed_addr constant [17 x i8] c"create a symlink\00"
@action_dir = private unnamed_addr constant [19 x i8] c"create a directory\00"
@action_enter = private unnamed_addr constant [46 x i8] c"set the current dir to the newly created path\00"
@action_up = private unnamed_addr constant [40 x i8] c"set the current dir to the dir above it\00"

; Function Attrs: mustprogress nofree nounwind willreturn allockind("alloc,uninitialized") allocsize(0) memory(inaccessiblemem: readwrite)
declare noalias noundef ptr @malloc(i64 noundef) local_unnamed_addr #0

; Function Attrs: mustprogress nounwind willreturn allockind("free") memory(argmem: readwrite, inaccessiblemem: readwrite)
declare void @free(ptr allocptr noundef captures(none)) local_unnamed_addr #1

; Function Attrs: mustprogress nocallback nofree nounwind willreturn memory(argmem: read)
declare i32 @memcmp(ptr captures(none), ptr captures(none), i64) local_unnamed_addr #2

; Function Attrs: mustprogress nocallback nofree nounwind willreturn memory(argmem: read)
declare i64 @strlen(ptr captures(none)) local_unnamed_addr #2

; Function Attrs: nofree nounwind
declare noalias noundef ptr @fdopen(i32 noundef, ptr noundef readonly captures(none)) local_unnamed_addr #3

; Function Attrs: nofree nounwind
declare noalias noundef ptr @fopen(ptr noundef readonly captures(none), ptr noundef readonly captures(none)) local_unnamed_addr #3

; Function Attrs: nofree nounwind
declare noundef i64 @fread(ptr noundef writeonly captures(none), i64 noundef, i64 noundef, ptr noundef captures(none)) local_unnamed_addr #3

; Function Attrs: nofree nounwind
declare noundef i64 @fwrite(ptr noundef readonly captures(none), i64 noundef, i64 noundef, ptr noundef captures(none)) local_unnamed_addr #3

; Function Attrs: nofree nounwind memory(read)
declare noundef i32 @ferror(ptr noundef captures(none)) local_unnamed_addr #4

; Function Attrs: nofree nounwind
declare noundef i32 @fclose(ptr noundef captures(none)) local_unnamed_addr #3

; Function Attrs: nofree nounwind
declare noundef i32 @fprintf(ptr noundef captures(none), ptr noundef readonly captures(none), ...) local_unnamed_addr #3

; Function Attrs: nofree nounwind
declare noundef i32 @unlink(ptr noundef readonly captures(none)) local_unnamed_addr #3

; Function Attrs: nofree nounwind
declare noundef i32 @mkdir(ptr noundef readonly captures(none), i32 noundef) local_unnamed_addr #3

declare i32 @chdir(ptr) local_unnamed_addr

declare i32 @symlink(ptr, ptr) local_unnamed_addr

; Function Attrs: nofree nounwind
declare noundef i32 @chmod(ptr noundef readonly captures(none), i32 noundef) local_unnamed_addr #3

; Function Attrs: mustprogress nocallback nofree nounwind willreturn
declare double @strtod(ptr readonly, ptr captures(none)) local_unnamed_addr #5

; Function Attrs: nofree noreturn
declare void @exit(i32) local_unnamed_addr #6

declare i32 @file_mode(ptr) local_unnamed_addr

declare i32 @last_errno() local_unnamed_addr

declare ptr @strerror(i32) local_unnamed_addr

; Function Attrs: nofree nounwind
define internal fastcc void @print(ptr readonly captures(none) %format, ptr %a, ptr %b, ptr %c) unnamed_addr #3 {
entry:
  %stream = load ptr, ptr @errstream, align 8
  %closed = icmp eq ptr %stream, null
  br i1 %closed, label %end, label %write

write:                                            ; preds = %entry
  %0 = tail call i32 (ptr, ptr, ...) @fprintf(ptr nonnull %stream, ptr %format, ptr %a, ptr %b, ptr %c)
  br label %end

end:                                              ; preds = %write, %entry
  ret void
}

; Function Attrs: nofree
define internal fastcc void @alloc(i64 %n) unnamed_addr #7 {
entry:
  %large = icmp ugt i64 %n, 9223372036854775791
  br i1 %large, label %oom, label %allocate

allocate:                                         ; preds = %entry
  %size = add nuw nsw i64 %n, 16
  %header = tail call ptr @malloc(i64 %size)
  %null = icmp eq ptr %header, null
  br i1 %null, label %oom, label %ready

ready:                                            ; preds = %allocate
  %old = load ptr, ptr @arena, align 8
  store ptr %old, ptr %header, align 8
  store ptr %header, ptr @arena, align 8
  %data = getelementptr i8, ptr %header, i64 16
  tail call void @llvm.memset.p0.i64(ptr align 1 %data, i8 0, i64 %n, i1 false)
  ret void

oom:                                              ; preds = %allocate, %entry
  tail call fastcc void @print(ptr nonnull @msg_oom, ptr null, ptr null, ptr null)
  tail call void @exit(i32 1) #14
  unreachable
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(read, argmem: readwrite, inaccessiblemem: none)
define internal fastcc i32 @hex4(ptr nonnull captures(none) %p) unnamed_addr #8 {
entry:
  %lp.i.i = getelementptr i8, ptr %p, i64 8
  %ip.i.i = getelementptr i8, ptr %p, i64 16
  %len.i.i = load i64, ptr %lp.i.i, align 4
  %ip.i.i.promoted = load i64, ptr %ip.i.i, align 4
  %end.not.i.i = icmp ult i64 %ip.i.i.promoted, %len.i.i
  br i1 %end.not.i.i, label %peek.exit.i, label %take.exit

peek.exit.i:                                      ; preds = %entry
  %data.i.i = load ptr, ptr %p, align 8
  %q.i.i = getelementptr i8, ptr %data.i.i, i64 %ip.i.i.promoted
  %v.i.i = load i8, ptr %q.i.i, align 1
  %c.i.i = zext i8 %v.i.i to i32
  %next.i = add nuw i64 %ip.i.i.promoted, 1
  store i64 %next.i, ptr %ip.i.i, align 4
  br label %take.exit

take.exit:                                        ; preds = %entry, %peek.exit.i
  %next.i3 = phi i64 [ %next.i, %peek.exit.i ], [ %ip.i.i.promoted, %entry ]
  %common.ret.op.i3.i = phi i32 [ %c.i.i, %peek.exit.i ], [ -1, %entry ]
  %d = add nsw i32 %common.ret.op.i3.i, -48
  %digit = icmp ult i32 %d, 10
  %lower = or i32 %common.ret.op.i3.i, 32
  %a = add nsw i32 %lower, -97
  %letter = icmp ult i32 %a, 6
  %ok = or i1 %digit, %letter
  br i1 %ok, label %consume, label %common.ret

consume:                                          ; preds = %take.exit
  %av = add nsw i32 %lower, 1048489
  %h = select i1 %digit, i32 %d, i32 %av
  %end.not.i.i.1 = icmp ult i64 %next.i3, %len.i.i
  br i1 %end.not.i.i.1, label %peek.exit.i.1, label %take.exit.1

peek.exit.i.1:                                    ; preds = %consume
  %data.i.i.1 = load ptr, ptr %p, align 8
  %q.i.i.1 = getelementptr i8, ptr %data.i.i.1, i64 %next.i3
  %v.i.i.1 = load i8, ptr %q.i.i.1, align 1
  %c.i.i.1 = zext i8 %v.i.i.1 to i32
  %next.i.1 = add nuw i64 %next.i3, 1
  store i64 %next.i.1, ptr %ip.i.i, align 4
  br label %take.exit.1

take.exit.1:                                      ; preds = %peek.exit.i.1, %consume
  %next.i3.1 = phi i64 [ %next.i.1, %peek.exit.i.1 ], [ %next.i3, %consume ]
  %common.ret.op.i3.i.1 = phi i32 [ %c.i.i.1, %peek.exit.i.1 ], [ -1, %consume ]
  %d.1 = add nsw i32 %common.ret.op.i3.i.1, -48
  %digit.1 = icmp ult i32 %d.1, 10
  %lower.1 = or i32 %common.ret.op.i3.i.1, 32
  %a.1 = add nsw i32 %lower.1, -97
  %letter.1 = icmp ult i32 %a.1, 6
  %ok.1 = or i1 %digit.1, %letter.1
  br i1 %ok.1, label %consume.1, label %common.ret

consume.1:                                        ; preds = %take.exit.1
  %av.1 = add nsw i32 %lower.1, 16777129
  %h.1 = select i1 %digit.1, i32 %d.1, i32 %av.1
  %end.not.i.i.2 = icmp ult i64 %next.i3.1, %len.i.i
  br i1 %end.not.i.i.2, label %peek.exit.i.2, label %take.exit.2

peek.exit.i.2:                                    ; preds = %consume.1
  %data.i.i.2 = load ptr, ptr %p, align 8
  %q.i.i.2 = getelementptr i8, ptr %data.i.i.2, i64 %next.i3.1
  %v.i.i.2 = load i8, ptr %q.i.i.2, align 1
  %c.i.i.2 = zext i8 %v.i.i.2 to i32
  %next.i.2 = add nuw i64 %next.i3.1, 1
  store i64 %next.i.2, ptr %ip.i.i, align 4
  br label %take.exit.2

take.exit.2:                                      ; preds = %peek.exit.i.2, %consume.1
  %next.i3.2 = phi i64 [ %next.i.2, %peek.exit.i.2 ], [ %next.i3.1, %consume.1 ]
  %common.ret.op.i3.i.2 = phi i32 [ %c.i.i.2, %peek.exit.i.2 ], [ -1, %consume.1 ]
  %d.2 = add nsw i32 %common.ret.op.i3.i.2, -48
  %digit.2 = icmp ult i32 %d.2, 10
  %lower.2 = or i32 %common.ret.op.i3.i.2, 32
  %a.2 = add nsw i32 %lower.2, -97
  %letter.2 = icmp ult i32 %a.2, 6
  %ok.2 = or i1 %digit.2, %letter.2
  br i1 %ok.2, label %consume.2, label %common.ret

consume.2:                                        ; preds = %take.exit.2
  %av.2 = add nsw i32 %lower.2, 268435369
  %h.2 = select i1 %digit.2, i32 %d.2, i32 %av.2
  %0 = shl nsw i32 %h, 8
  %1 = shl nsw i32 %h.1, 4
  %shift.2 = or i32 %0, %1
  %newv.2 = or i32 %h.2, %shift.2
  %end.not.i.i.3 = icmp ult i64 %next.i3.2, %len.i.i
  br i1 %end.not.i.i.3, label %peek.exit.i.3, label %take.exit.3

peek.exit.i.3:                                    ; preds = %consume.2
  %data.i.i.3 = load ptr, ptr %p, align 8
  %q.i.i.3 = getelementptr i8, ptr %data.i.i.3, i64 %next.i3.2
  %v.i.i.3 = load i8, ptr %q.i.i.3, align 1
  %c.i.i.3 = zext i8 %v.i.i.3 to i32
  %next.i.3 = add nuw i64 %next.i3.2, 1
  store i64 %next.i.3, ptr %ip.i.i, align 4
  br label %take.exit.3

take.exit.3:                                      ; preds = %peek.exit.i.3, %consume.2
  %common.ret.op.i3.i.3 = phi i32 [ %c.i.i.3, %peek.exit.i.3 ], [ -1, %consume.2 ]
  %d.3 = add nsw i32 %common.ret.op.i3.i.3, -48
  %digit.3 = icmp ult i32 %d.3, 10
  %lower.3 = or i32 %common.ret.op.i3.i.3, 32
  %a.3 = add nsw i32 %lower.3, -97
  %letter.3 = icmp ult i32 %a.3, 6
  %ok.3 = or i1 %digit.3, %letter.3
  br i1 %ok.3, label %consume.3, label %common.ret

consume.3:                                        ; preds = %take.exit.3
  %av.3 = add nsw i32 %lower.3, -87
  %h.3 = select i1 %digit.3, i32 %d.3, i32 %av.3
  %shift.3 = shl i32 %newv.2, 4
  %newv.3 = or i32 %h.3, %shift.3
  br label %common.ret

common.ret:                                       ; preds = %consume.3, %take.exit.3, %take.exit.2, %take.exit.1, %take.exit
  %common.ret.op = phi i32 [ -1, %take.exit ], [ -1, %take.exit.1 ], [ -1, %take.exit.2 ], [ -1, %take.exit.3 ], [ %newv.3, %consume.3 ]
  ret i32 %common.ret.op
}

; Function Attrs: nofree
define internal fastcc noundef ptr @parse_string(ptr nonnull captures(none) %p) unnamed_addr #7 {
entry:
  %lp.i.i = getelementptr i8, ptr %p, i64 8
  %ip.i.i = getelementptr i8, ptr %p, i64 16
  %len.i.i = load i64, ptr %lp.i.i, align 4
  %i.i.i = load i64, ptr %ip.i.i, align 4
  %end.not.i.i = icmp ult i64 %i.i.i, %len.i.i
  br i1 %end.not.i.i, label %take.exit, label %common.ret

take.exit:                                        ; preds = %entry
  %data.i.i = load ptr, ptr %p, align 8
  %q.i.i = getelementptr i8, ptr %data.i.i, i64 %i.i.i
  %v.i.i = load i8, ptr %q.i.i, align 1
  %next.i = add nuw i64 %i.i.i, 1
  store i64 %next.i, ptr %ip.i.i, align 4
  %start = icmp eq i8 %v.i.i, 34
  %end.not.i.i5562 = icmp ult i64 %next.i, %len.i.i
  %or.cond707 = select i1 %start, i1 %end.not.i.i5562, i1 false
  br i1 %or.cond707, label %take.exit13, label %common.ret

take.exit13:                                      ; preds = %take.exit, %loop.backedge
  %i.i.i4567 = phi i64 [ %i.i.i4, %loop.backedge ], [ %next.i, %take.exit ]
  %len.i.i3566 = phi i64 [ %len.i.i3, %loop.backedge ], [ %len.i.i, %take.exit ]
  %b.sroa.0.0565 = phi ptr [ %b.sroa.0.0.be, %loop.backedge ], [ null, %take.exit ]
  %b.sroa.38.0564 = phi i64 [ %b.sroa.38.0.be, %loop.backedge ], [ 0, %take.exit ]
  %b.sroa.74.0563 = phi i64 [ %b.sroa.74.0.be, %loop.backedge ], [ 0, %take.exit ]
  %data.i.i8 = load ptr, ptr %p, align 8
  %q.i.i9 = getelementptr i8, ptr %data.i.i8, i64 %i.i.i4567
  %v.i.i10 = load i8, ptr %q.i.i9, align 1
  %next.i12 = add nuw i64 %i.i.i4567, 1
  store i64 %next.i12, ptr %ip.i.i, align 4
  switch i8 %v.i.i10, label %raw [
    i8 34, label %end
    i8 92, label %escape
  ]

raw:                                              ; preds = %take.exit13
  %invalid = icmp ult i8 %v.i.i10, 32
  br i1 %invalid, label %common.ret, label %appendraw

appendraw:                                        ; preds = %raw
  %need.i.i = add i64 %b.sroa.38.0564, 2
  %wrap.not.i.i = icmp ult i64 %b.sroa.38.0564, -2
  br i1 %wrap.not.i.i, label %check.i.i, label %overflow.i.i

check.i.i:                                        ; preds = %appendraw
  %enough.not.i.i = icmp ugt i64 %need.i.i, %b.sroa.74.0563
  br i1 %enough.not.i.i, label %grow.i.i, label %byte.exit

grow.i.i:                                         ; preds = %check.i.i
  %double.i.i = shl i64 %b.sroa.74.0563, 1
  %base.i.i = tail call i64 @llvm.umax.i64(i64 %double.i.i, i64 %need.i.i)
  %newcap.i.i = tail call i64 @llvm.umax.i64(i64 %base.i.i, i64 64)
  %large.i.i.i = icmp ugt i64 %base.i.i, 9223372036854775791
  br i1 %large.i.i.i, label %oom.i.i.i, label %allocate.i.i.i

allocate.i.i.i:                                   ; preds = %grow.i.i
  %size.i.i.i = add nuw nsw i64 %newcap.i.i, 16
  %header.i.i.i = tail call ptr @malloc(i64 %size.i.i.i)
  %null.i.i.i = icmp eq ptr %header.i.i.i, null
  br i1 %null.i.i.i, label %oom.i.i.i, label %alloc.exit.i.i

oom.i.i.i:                                        ; preds = %allocate.i.i.i, %grow.i.i
  tail call fastcc void @print(ptr nonnull @msg_oom, ptr null, ptr null, ptr null)
  tail call void @exit(i32 1) #14
  unreachable

alloc.exit.i.i:                                   ; preds = %allocate.i.i.i
  %old.i.i.i = load ptr, ptr @arena, align 8
  store ptr %old.i.i.i, ptr %header.i.i.i, align 8
  store ptr %header.i.i.i, ptr @arena, align 8
  %data.i.i.i = getelementptr i8, ptr %header.i.i.i, i64 16
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 1 dereferenceable(1) %data.i.i.i, i8 0, i64 %newcap.i.i, i1 false)
  %empty.i.i = icmp eq i64 %b.sroa.38.0564, 0
  br i1 %empty.i.i, label %byte.exit, label %copy.i.i

copy.i.i:                                         ; preds = %alloc.exit.i.i
  tail call void @llvm.memcpy.p0.p0.i64(ptr nonnull align 1 %data.i.i.i, ptr align 1 %b.sroa.0.0565, i64 %b.sroa.38.0564, i1 false)
  br label %byte.exit

overflow.i.i:                                     ; preds = %appendraw
  tail call fastcc void @alloc(i64 -1)
  unreachable

byte.exit:                                        ; preds = %alloc.exit.i.i, %copy.i.i, %check.i.i
  %b.sroa.74.1 = phi i64 [ %b.sroa.74.0563, %check.i.i ], [ %newcap.i.i, %copy.i.i ], [ %newcap.i.i, %alloc.exit.i.i ]
  %b.sroa.0.1 = phi ptr [ %b.sroa.0.0565, %check.i.i ], [ %data.i.i.i, %copy.i.i ], [ %data.i.i.i, %alloc.exit.i.i ]
  %out.i4.i = getelementptr i8, ptr %b.sroa.0.1, i64 %b.sroa.38.0564
  store i8 %v.i.i10, ptr %out.i4.i, align 1
  br label %loop.backedge

loop.backedge:                                    ; preds = %byte.exit, %byte.exit63, %byte.exit97, %byte.exit131, %byte.exit165, %byte.exit199, %byte.exit233, %byte.exit408
  %out.i4.i.sink = phi ptr [ %out.i4.i, %byte.exit ], [ %out.i4.i42, %byte.exit63 ], [ %out.i4.i76, %byte.exit97 ], [ %out.i4.i110, %byte.exit131 ], [ %out.i4.i144, %byte.exit165 ], [ %out.i4.i178, %byte.exit199 ], [ %out.i4.i212, %byte.exit233 ], [ %out.i4.i387, %byte.exit408 ]
  %b.sroa.74.0.be = phi i64 [ %b.sroa.74.1, %byte.exit ], [ %b.sroa.74.2, %byte.exit63 ], [ %b.sroa.74.3, %byte.exit97 ], [ %b.sroa.74.4, %byte.exit131 ], [ %b.sroa.74.5, %byte.exit165 ], [ %b.sroa.74.6, %byte.exit199 ], [ %b.sroa.74.7, %byte.exit233 ], [ %b.sroa.74.14, %byte.exit408 ]
  %b.sroa.38.0.be.in = phi i64 [ %b.sroa.38.0564, %byte.exit ], [ %b.sroa.38.0564, %byte.exit63 ], [ %b.sroa.38.0564, %byte.exit97 ], [ %b.sroa.38.0564, %byte.exit131 ], [ %b.sroa.38.0564, %byte.exit165 ], [ %b.sroa.38.0564, %byte.exit199 ], [ %b.sroa.38.0564, %byte.exit233 ], [ %b.sroa.38.3, %byte.exit408 ]
  %b.sroa.0.0.be = phi ptr [ %b.sroa.0.1, %byte.exit ], [ %b.sroa.0.2, %byte.exit63 ], [ %b.sroa.0.3, %byte.exit97 ], [ %b.sroa.0.4, %byte.exit131 ], [ %b.sroa.0.5, %byte.exit165 ], [ %b.sroa.0.6, %byte.exit199 ], [ %b.sroa.0.7, %byte.exit233 ], [ %b.sroa.0.15, %byte.exit408 ]
  %end.i.i = getelementptr i8, ptr %out.i4.i.sink, i64 1
  store i8 0, ptr %end.i.i, align 1
  %b.sroa.38.0.be = add nuw i64 %b.sroa.38.0.be.in, 1
  %len.i.i3 = load i64, ptr %lp.i.i, align 4
  %i.i.i4 = load i64, ptr %ip.i.i, align 4
  %end.not.i.i5 = icmp ult i64 %i.i.i4, %len.i.i3
  br i1 %end.not.i.i5, label %take.exit13, label %common.ret

escape:                                           ; preds = %take.exit13
  %end.not.i.i20 = icmp ult i64 %next.i12, %len.i.i3566
  br i1 %end.not.i.i20, label %take.exit28, label %common.ret

take.exit28:                                      ; preds = %escape
  %q.i.i24 = getelementptr i8, ptr %data.i.i8, i64 %next.i12
  %v.i.i25 = load i8, ptr %q.i.i24, align 1
  %next.i27 = add nuw i64 %i.i.i4567, 2
  store i64 %next.i27, ptr %ip.i.i, align 4
  switch i8 %v.i.i25, label %common.ret [
    i8 34, label %simple
    i8 92, label %simple
    i8 47, label %simple
    i8 98, label %backspace
    i8 102, label %formfeed
    i8 110, label %newline
    i8 114, label %return
    i8 116, label %tab
    i8 117, label %hex
  ]

simple:                                           ; preds = %take.exit28, %take.exit28, %take.exit28
  %need.i.i33 = add i64 %b.sroa.38.0564, 2
  %wrap.not.i.i34 = icmp ult i64 %b.sroa.38.0564, -2
  br i1 %wrap.not.i.i34, label %check.i.i36, label %overflow.i.i35

check.i.i36:                                      ; preds = %simple
  %enough.not.i.i37 = icmp ugt i64 %need.i.i33, %b.sroa.74.0563
  br i1 %enough.not.i.i37, label %grow.i.i46, label %byte.exit63

grow.i.i46:                                       ; preds = %check.i.i36
  %double.i.i47 = shl i64 %b.sroa.74.0563, 1
  %base.i.i48 = tail call i64 @llvm.umax.i64(i64 %double.i.i47, i64 %need.i.i33)
  %newcap.i.i49 = tail call i64 @llvm.umax.i64(i64 %base.i.i48, i64 64)
  %large.i.i.i50 = icmp ugt i64 %base.i.i48, 9223372036854775791
  br i1 %large.i.i.i50, label %oom.i.i.i62, label %allocate.i.i.i51

allocate.i.i.i51:                                 ; preds = %grow.i.i46
  %size.i.i.i52 = add nuw nsw i64 %newcap.i.i49, 16
  %header.i.i.i53 = tail call ptr @malloc(i64 %size.i.i.i52)
  %null.i.i.i54 = icmp eq ptr %header.i.i.i53, null
  br i1 %null.i.i.i54, label %oom.i.i.i62, label %alloc.exit.i.i55

oom.i.i.i62:                                      ; preds = %allocate.i.i.i51, %grow.i.i46
  tail call fastcc void @print(ptr nonnull @msg_oom, ptr null, ptr null, ptr null)
  tail call void @exit(i32 1) #14
  unreachable

alloc.exit.i.i55:                                 ; preds = %allocate.i.i.i51
  %old.i.i.i56 = load ptr, ptr @arena, align 8
  store ptr %old.i.i.i56, ptr %header.i.i.i53, align 8
  store ptr %header.i.i.i53, ptr @arena, align 8
  %data.i.i.i57 = getelementptr i8, ptr %header.i.i.i53, i64 16
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 1 dereferenceable(1) %data.i.i.i57, i8 0, i64 %newcap.i.i49, i1 false)
  %empty.i.i58 = icmp eq i64 %b.sroa.38.0564, 0
  br i1 %empty.i.i58, label %byte.exit63, label %copy.i.i59

copy.i.i59:                                       ; preds = %alloc.exit.i.i55
  tail call void @llvm.memcpy.p0.p0.i64(ptr nonnull align 1 %data.i.i.i57, ptr align 1 %b.sroa.0.0565, i64 %b.sroa.38.0564, i1 false)
  br label %byte.exit63

overflow.i.i35:                                   ; preds = %simple
  tail call fastcc void @alloc(i64 -1)
  unreachable

byte.exit63:                                      ; preds = %alloc.exit.i.i55, %copy.i.i59, %check.i.i36
  %b.sroa.74.2 = phi i64 [ %b.sroa.74.0563, %check.i.i36 ], [ %newcap.i.i49, %copy.i.i59 ], [ %newcap.i.i49, %alloc.exit.i.i55 ]
  %b.sroa.0.2 = phi ptr [ %b.sroa.0.0565, %check.i.i36 ], [ %data.i.i.i57, %copy.i.i59 ], [ %data.i.i.i57, %alloc.exit.i.i55 ]
  %out.i4.i42 = getelementptr i8, ptr %b.sroa.0.2, i64 %b.sroa.38.0564
  store i8 %v.i.i25, ptr %out.i4.i42, align 1
  br label %loop.backedge

backspace:                                        ; preds = %take.exit28
  %need.i.i68 = add i64 %b.sroa.38.0564, 2
  %wrap.not.i.i69 = icmp ult i64 %b.sroa.38.0564, -2
  br i1 %wrap.not.i.i69, label %check.i.i71, label %overflow.i.i70

check.i.i71:                                      ; preds = %backspace
  %enough.not.i.i72 = icmp ugt i64 %need.i.i68, %b.sroa.74.0563
  br i1 %enough.not.i.i72, label %grow.i.i80, label %byte.exit97

grow.i.i80:                                       ; preds = %check.i.i71
  %double.i.i81 = shl i64 %b.sroa.74.0563, 1
  %base.i.i82 = tail call i64 @llvm.umax.i64(i64 %double.i.i81, i64 %need.i.i68)
  %newcap.i.i83 = tail call i64 @llvm.umax.i64(i64 %base.i.i82, i64 64)
  %large.i.i.i84 = icmp ugt i64 %base.i.i82, 9223372036854775791
  br i1 %large.i.i.i84, label %oom.i.i.i96, label %allocate.i.i.i85

allocate.i.i.i85:                                 ; preds = %grow.i.i80
  %size.i.i.i86 = add nuw nsw i64 %newcap.i.i83, 16
  %header.i.i.i87 = tail call ptr @malloc(i64 %size.i.i.i86)
  %null.i.i.i88 = icmp eq ptr %header.i.i.i87, null
  br i1 %null.i.i.i88, label %oom.i.i.i96, label %alloc.exit.i.i89

oom.i.i.i96:                                      ; preds = %allocate.i.i.i85, %grow.i.i80
  tail call fastcc void @print(ptr nonnull @msg_oom, ptr null, ptr null, ptr null)
  tail call void @exit(i32 1) #14
  unreachable

alloc.exit.i.i89:                                 ; preds = %allocate.i.i.i85
  %old.i.i.i90 = load ptr, ptr @arena, align 8
  store ptr %old.i.i.i90, ptr %header.i.i.i87, align 8
  store ptr %header.i.i.i87, ptr @arena, align 8
  %data.i.i.i91 = getelementptr i8, ptr %header.i.i.i87, i64 16
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 1 dereferenceable(1) %data.i.i.i91, i8 0, i64 %newcap.i.i83, i1 false)
  %empty.i.i92 = icmp eq i64 %b.sroa.38.0564, 0
  br i1 %empty.i.i92, label %byte.exit97, label %copy.i.i93

copy.i.i93:                                       ; preds = %alloc.exit.i.i89
  tail call void @llvm.memcpy.p0.p0.i64(ptr nonnull align 1 %data.i.i.i91, ptr align 1 %b.sroa.0.0565, i64 %b.sroa.38.0564, i1 false)
  br label %byte.exit97

overflow.i.i70:                                   ; preds = %backspace
  tail call fastcc void @alloc(i64 -1)
  unreachable

byte.exit97:                                      ; preds = %alloc.exit.i.i89, %copy.i.i93, %check.i.i71
  %b.sroa.74.3 = phi i64 [ %b.sroa.74.0563, %check.i.i71 ], [ %newcap.i.i83, %copy.i.i93 ], [ %newcap.i.i83, %alloc.exit.i.i89 ]
  %b.sroa.0.3 = phi ptr [ %b.sroa.0.0565, %check.i.i71 ], [ %data.i.i.i91, %copy.i.i93 ], [ %data.i.i.i91, %alloc.exit.i.i89 ]
  %out.i4.i76 = getelementptr i8, ptr %b.sroa.0.3, i64 %b.sroa.38.0564
  store i8 8, ptr %out.i4.i76, align 1
  br label %loop.backedge

formfeed:                                         ; preds = %take.exit28
  %need.i.i102 = add i64 %b.sroa.38.0564, 2
  %wrap.not.i.i103 = icmp ult i64 %b.sroa.38.0564, -2
  br i1 %wrap.not.i.i103, label %check.i.i105, label %overflow.i.i104

check.i.i105:                                     ; preds = %formfeed
  %enough.not.i.i106 = icmp ugt i64 %need.i.i102, %b.sroa.74.0563
  br i1 %enough.not.i.i106, label %grow.i.i114, label %byte.exit131

grow.i.i114:                                      ; preds = %check.i.i105
  %double.i.i115 = shl i64 %b.sroa.74.0563, 1
  %base.i.i116 = tail call i64 @llvm.umax.i64(i64 %double.i.i115, i64 %need.i.i102)
  %newcap.i.i117 = tail call i64 @llvm.umax.i64(i64 %base.i.i116, i64 64)
  %large.i.i.i118 = icmp ugt i64 %base.i.i116, 9223372036854775791
  br i1 %large.i.i.i118, label %oom.i.i.i130, label %allocate.i.i.i119

allocate.i.i.i119:                                ; preds = %grow.i.i114
  %size.i.i.i120 = add nuw nsw i64 %newcap.i.i117, 16
  %header.i.i.i121 = tail call ptr @malloc(i64 %size.i.i.i120)
  %null.i.i.i122 = icmp eq ptr %header.i.i.i121, null
  br i1 %null.i.i.i122, label %oom.i.i.i130, label %alloc.exit.i.i123

oom.i.i.i130:                                     ; preds = %allocate.i.i.i119, %grow.i.i114
  tail call fastcc void @print(ptr nonnull @msg_oom, ptr null, ptr null, ptr null)
  tail call void @exit(i32 1) #14
  unreachable

alloc.exit.i.i123:                                ; preds = %allocate.i.i.i119
  %old.i.i.i124 = load ptr, ptr @arena, align 8
  store ptr %old.i.i.i124, ptr %header.i.i.i121, align 8
  store ptr %header.i.i.i121, ptr @arena, align 8
  %data.i.i.i125 = getelementptr i8, ptr %header.i.i.i121, i64 16
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 1 dereferenceable(1) %data.i.i.i125, i8 0, i64 %newcap.i.i117, i1 false)
  %empty.i.i126 = icmp eq i64 %b.sroa.38.0564, 0
  br i1 %empty.i.i126, label %byte.exit131, label %copy.i.i127

copy.i.i127:                                      ; preds = %alloc.exit.i.i123
  tail call void @llvm.memcpy.p0.p0.i64(ptr nonnull align 1 %data.i.i.i125, ptr align 1 %b.sroa.0.0565, i64 %b.sroa.38.0564, i1 false)
  br label %byte.exit131

overflow.i.i104:                                  ; preds = %formfeed
  tail call fastcc void @alloc(i64 -1)
  unreachable

byte.exit131:                                     ; preds = %alloc.exit.i.i123, %copy.i.i127, %check.i.i105
  %b.sroa.74.4 = phi i64 [ %b.sroa.74.0563, %check.i.i105 ], [ %newcap.i.i117, %copy.i.i127 ], [ %newcap.i.i117, %alloc.exit.i.i123 ]
  %b.sroa.0.4 = phi ptr [ %b.sroa.0.0565, %check.i.i105 ], [ %data.i.i.i125, %copy.i.i127 ], [ %data.i.i.i125, %alloc.exit.i.i123 ]
  %out.i4.i110 = getelementptr i8, ptr %b.sroa.0.4, i64 %b.sroa.38.0564
  store i8 12, ptr %out.i4.i110, align 1
  br label %loop.backedge

newline:                                          ; preds = %take.exit28
  %need.i.i136 = add i64 %b.sroa.38.0564, 2
  %wrap.not.i.i137 = icmp ult i64 %b.sroa.38.0564, -2
  br i1 %wrap.not.i.i137, label %check.i.i139, label %overflow.i.i138

check.i.i139:                                     ; preds = %newline
  %enough.not.i.i140 = icmp ugt i64 %need.i.i136, %b.sroa.74.0563
  br i1 %enough.not.i.i140, label %grow.i.i148, label %byte.exit165

grow.i.i148:                                      ; preds = %check.i.i139
  %double.i.i149 = shl i64 %b.sroa.74.0563, 1
  %base.i.i150 = tail call i64 @llvm.umax.i64(i64 %double.i.i149, i64 %need.i.i136)
  %newcap.i.i151 = tail call i64 @llvm.umax.i64(i64 %base.i.i150, i64 64)
  %large.i.i.i152 = icmp ugt i64 %base.i.i150, 9223372036854775791
  br i1 %large.i.i.i152, label %oom.i.i.i164, label %allocate.i.i.i153

allocate.i.i.i153:                                ; preds = %grow.i.i148
  %size.i.i.i154 = add nuw nsw i64 %newcap.i.i151, 16
  %header.i.i.i155 = tail call ptr @malloc(i64 %size.i.i.i154)
  %null.i.i.i156 = icmp eq ptr %header.i.i.i155, null
  br i1 %null.i.i.i156, label %oom.i.i.i164, label %alloc.exit.i.i157

oom.i.i.i164:                                     ; preds = %allocate.i.i.i153, %grow.i.i148
  tail call fastcc void @print(ptr nonnull @msg_oom, ptr null, ptr null, ptr null)
  tail call void @exit(i32 1) #14
  unreachable

alloc.exit.i.i157:                                ; preds = %allocate.i.i.i153
  %old.i.i.i158 = load ptr, ptr @arena, align 8
  store ptr %old.i.i.i158, ptr %header.i.i.i155, align 8
  store ptr %header.i.i.i155, ptr @arena, align 8
  %data.i.i.i159 = getelementptr i8, ptr %header.i.i.i155, i64 16
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 1 dereferenceable(1) %data.i.i.i159, i8 0, i64 %newcap.i.i151, i1 false)
  %empty.i.i160 = icmp eq i64 %b.sroa.38.0564, 0
  br i1 %empty.i.i160, label %byte.exit165, label %copy.i.i161

copy.i.i161:                                      ; preds = %alloc.exit.i.i157
  tail call void @llvm.memcpy.p0.p0.i64(ptr nonnull align 1 %data.i.i.i159, ptr align 1 %b.sroa.0.0565, i64 %b.sroa.38.0564, i1 false)
  br label %byte.exit165

overflow.i.i138:                                  ; preds = %newline
  tail call fastcc void @alloc(i64 -1)
  unreachable

byte.exit165:                                     ; preds = %alloc.exit.i.i157, %copy.i.i161, %check.i.i139
  %b.sroa.74.5 = phi i64 [ %b.sroa.74.0563, %check.i.i139 ], [ %newcap.i.i151, %copy.i.i161 ], [ %newcap.i.i151, %alloc.exit.i.i157 ]
  %b.sroa.0.5 = phi ptr [ %b.sroa.0.0565, %check.i.i139 ], [ %data.i.i.i159, %copy.i.i161 ], [ %data.i.i.i159, %alloc.exit.i.i157 ]
  %out.i4.i144 = getelementptr i8, ptr %b.sroa.0.5, i64 %b.sroa.38.0564
  store i8 10, ptr %out.i4.i144, align 1
  br label %loop.backedge

return:                                           ; preds = %take.exit28
  %need.i.i170 = add i64 %b.sroa.38.0564, 2
  %wrap.not.i.i171 = icmp ult i64 %b.sroa.38.0564, -2
  br i1 %wrap.not.i.i171, label %check.i.i173, label %overflow.i.i172

check.i.i173:                                     ; preds = %return
  %enough.not.i.i174 = icmp ugt i64 %need.i.i170, %b.sroa.74.0563
  br i1 %enough.not.i.i174, label %grow.i.i182, label %byte.exit199

grow.i.i182:                                      ; preds = %check.i.i173
  %double.i.i183 = shl i64 %b.sroa.74.0563, 1
  %base.i.i184 = tail call i64 @llvm.umax.i64(i64 %double.i.i183, i64 %need.i.i170)
  %newcap.i.i185 = tail call i64 @llvm.umax.i64(i64 %base.i.i184, i64 64)
  %large.i.i.i186 = icmp ugt i64 %base.i.i184, 9223372036854775791
  br i1 %large.i.i.i186, label %oom.i.i.i198, label %allocate.i.i.i187

allocate.i.i.i187:                                ; preds = %grow.i.i182
  %size.i.i.i188 = add nuw nsw i64 %newcap.i.i185, 16
  %header.i.i.i189 = tail call ptr @malloc(i64 %size.i.i.i188)
  %null.i.i.i190 = icmp eq ptr %header.i.i.i189, null
  br i1 %null.i.i.i190, label %oom.i.i.i198, label %alloc.exit.i.i191

oom.i.i.i198:                                     ; preds = %allocate.i.i.i187, %grow.i.i182
  tail call fastcc void @print(ptr nonnull @msg_oom, ptr null, ptr null, ptr null)
  tail call void @exit(i32 1) #14
  unreachable

alloc.exit.i.i191:                                ; preds = %allocate.i.i.i187
  %old.i.i.i192 = load ptr, ptr @arena, align 8
  store ptr %old.i.i.i192, ptr %header.i.i.i189, align 8
  store ptr %header.i.i.i189, ptr @arena, align 8
  %data.i.i.i193 = getelementptr i8, ptr %header.i.i.i189, i64 16
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 1 dereferenceable(1) %data.i.i.i193, i8 0, i64 %newcap.i.i185, i1 false)
  %empty.i.i194 = icmp eq i64 %b.sroa.38.0564, 0
  br i1 %empty.i.i194, label %byte.exit199, label %copy.i.i195

copy.i.i195:                                      ; preds = %alloc.exit.i.i191
  tail call void @llvm.memcpy.p0.p0.i64(ptr nonnull align 1 %data.i.i.i193, ptr align 1 %b.sroa.0.0565, i64 %b.sroa.38.0564, i1 false)
  br label %byte.exit199

overflow.i.i172:                                  ; preds = %return
  tail call fastcc void @alloc(i64 -1)
  unreachable

byte.exit199:                                     ; preds = %alloc.exit.i.i191, %copy.i.i195, %check.i.i173
  %b.sroa.74.6 = phi i64 [ %b.sroa.74.0563, %check.i.i173 ], [ %newcap.i.i185, %copy.i.i195 ], [ %newcap.i.i185, %alloc.exit.i.i191 ]
  %b.sroa.0.6 = phi ptr [ %b.sroa.0.0565, %check.i.i173 ], [ %data.i.i.i193, %copy.i.i195 ], [ %data.i.i.i193, %alloc.exit.i.i191 ]
  %out.i4.i178 = getelementptr i8, ptr %b.sroa.0.6, i64 %b.sroa.38.0564
  store i8 13, ptr %out.i4.i178, align 1
  br label %loop.backedge

tab:                                              ; preds = %take.exit28
  %need.i.i204 = add i64 %b.sroa.38.0564, 2
  %wrap.not.i.i205 = icmp ult i64 %b.sroa.38.0564, -2
  br i1 %wrap.not.i.i205, label %check.i.i207, label %overflow.i.i206

check.i.i207:                                     ; preds = %tab
  %enough.not.i.i208 = icmp ugt i64 %need.i.i204, %b.sroa.74.0563
  br i1 %enough.not.i.i208, label %grow.i.i216, label %byte.exit233

grow.i.i216:                                      ; preds = %check.i.i207
  %double.i.i217 = shl i64 %b.sroa.74.0563, 1
  %base.i.i218 = tail call i64 @llvm.umax.i64(i64 %double.i.i217, i64 %need.i.i204)
  %newcap.i.i219 = tail call i64 @llvm.umax.i64(i64 %base.i.i218, i64 64)
  %large.i.i.i220 = icmp ugt i64 %base.i.i218, 9223372036854775791
  br i1 %large.i.i.i220, label %oom.i.i.i232, label %allocate.i.i.i221

allocate.i.i.i221:                                ; preds = %grow.i.i216
  %size.i.i.i222 = add nuw nsw i64 %newcap.i.i219, 16
  %header.i.i.i223 = tail call ptr @malloc(i64 %size.i.i.i222)
  %null.i.i.i224 = icmp eq ptr %header.i.i.i223, null
  br i1 %null.i.i.i224, label %oom.i.i.i232, label %alloc.exit.i.i225

oom.i.i.i232:                                     ; preds = %allocate.i.i.i221, %grow.i.i216
  tail call fastcc void @print(ptr nonnull @msg_oom, ptr null, ptr null, ptr null)
  tail call void @exit(i32 1) #14
  unreachable

alloc.exit.i.i225:                                ; preds = %allocate.i.i.i221
  %old.i.i.i226 = load ptr, ptr @arena, align 8
  store ptr %old.i.i.i226, ptr %header.i.i.i223, align 8
  store ptr %header.i.i.i223, ptr @arena, align 8
  %data.i.i.i227 = getelementptr i8, ptr %header.i.i.i223, i64 16
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 1 dereferenceable(1) %data.i.i.i227, i8 0, i64 %newcap.i.i219, i1 false)
  %empty.i.i228 = icmp eq i64 %b.sroa.38.0564, 0
  br i1 %empty.i.i228, label %byte.exit233, label %copy.i.i229

copy.i.i229:                                      ; preds = %alloc.exit.i.i225
  tail call void @llvm.memcpy.p0.p0.i64(ptr nonnull align 1 %data.i.i.i227, ptr align 1 %b.sroa.0.0565, i64 %b.sroa.38.0564, i1 false)
  br label %byte.exit233

overflow.i.i206:                                  ; preds = %tab
  tail call fastcc void @alloc(i64 -1)
  unreachable

byte.exit233:                                     ; preds = %alloc.exit.i.i225, %copy.i.i229, %check.i.i207
  %b.sroa.74.7 = phi i64 [ %b.sroa.74.0563, %check.i.i207 ], [ %newcap.i.i219, %copy.i.i229 ], [ %newcap.i.i219, %alloc.exit.i.i225 ]
  %b.sroa.0.7 = phi ptr [ %b.sroa.0.0565, %check.i.i207 ], [ %data.i.i.i227, %copy.i.i229 ], [ %data.i.i.i227, %alloc.exit.i.i225 ]
  %out.i4.i212 = getelementptr i8, ptr %b.sroa.0.7, i64 %b.sroa.38.0564
  store i8 9, ptr %out.i4.i212, align 1
  br label %loop.backedge

hex:                                              ; preds = %take.exit28
  %h = tail call fastcc i32 @hex4(ptr %p)
  %error = icmp eq i32 %h, -1
  %0 = and i32 %h, -1024
  %islow = icmp eq i32 %0, 56320
  %or.cond = or i1 %error, %islow
  br i1 %or.cond, label %common.ret, label %highcheck

highcheck:                                        ; preds = %hex
  %ishigh = icmp eq i32 %0, 55296
  br i1 %ishigh, label %pair, label %emit

pair:                                             ; preds = %highcheck
  %len.i.i236 = load i64, ptr %lp.i.i, align 4
  %i.i.i237 = load i64, ptr %ip.i.i, align 4
  %end.not.i.i238 = icmp ult i64 %i.i.i237, %len.i.i236
  br i1 %end.not.i.i238, label %peek.exit.i240, label %take.exit246

peek.exit.i240:                                   ; preds = %pair
  %data.i.i241 = load ptr, ptr %p, align 8
  %q.i.i242 = getelementptr i8, ptr %data.i.i241, i64 %i.i.i237
  %v.i.i243 = load i8, ptr %q.i.i242, align 1
  %next.i245 = add nuw i64 %i.i.i237, 1
  store i64 %next.i245, ptr %ip.i.i, align 4
  %1 = icmp eq i8 %v.i.i243, 92
  br label %take.exit246

take.exit246:                                     ; preds = %pair, %peek.exit.i240
  %i.i.i250 = phi i64 [ %next.i245, %peek.exit.i240 ], [ %i.i.i237, %pair ]
  %common.ret.op.i3.i239 = phi i1 [ %1, %peek.exit.i240 ], [ false, %pair ]
  %end.not.i.i251 = icmp ult i64 %i.i.i250, %len.i.i236
  br i1 %end.not.i.i251, label %take.exit259, label %common.ret

take.exit259:                                     ; preds = %take.exit246
  %data.i.i254 = load ptr, ptr %p, align 8
  %q.i.i255 = getelementptr i8, ptr %data.i.i254, i64 %i.i.i250
  %v.i.i256 = load i8, ptr %q.i.i255, align 1
  %next.i258 = add nuw i64 %i.i.i250, 1
  store i64 %next.i258, ptr %ip.i.i, align 4
  %isu = icmp eq i8 %v.i.i256, 117
  %prefix = and i1 %common.ret.op.i3.i239, %isu
  br i1 %prefix, label %pairhex, label %common.ret

pairhex:                                          ; preds = %take.exit259
  %lo = tail call fastcc i32 @hex4(ptr %p)
  %offset = add i32 %lo, -56320
  %valid = icmp ult i32 %offset, 1024
  br i1 %valid, label %large.i.thread, label %common.ret

large.i.thread:                                   ; preds = %pairhex
  %hi = shl nuw nsw i32 %h, 10
  %shift = add nsw i32 %hi, -56623104
  %combined = or disjoint i32 %offset, %shift
  %full = add nuw nsw i32 %combined, 65536
  %extract.t477 = trunc i32 %lo to i8
  %extract479 = lshr i32 %combined, 6
  %extract.t480 = trunc i32 %extract479 to i8
  %extract483 = lshr i32 %full, 12
  %extract.t484 = trunc i32 %extract483 to i8
  %extract487 = lshr i32 %full, 18
  %extract.t488 = trunc nuw nsw i32 %extract487 to i8
  br label %lead4.i

emit:                                             ; preds = %highcheck
  %one.i = icmp ult i32 %h, 128
  %extract.t468 = trunc i32 %h to i8
  br i1 %one.i, label %unicode.exit, label %multi.i

multi.i:                                          ; preds = %emit
  %two.i = icmp ult i32 %h, 2048
  br i1 %two.i, label %lead2.i, label %large.i

lead2.i:                                          ; preds = %multi.i
  %a2.i = lshr i32 %h, 6
  %2 = trunc nuw nsw i32 %a2.i to i8
  %extract.t466 = or disjoint i8 %2, -64
  br label %last.i

large.i:                                          ; preds = %multi.i
  %three.i = icmp ult i32 %h, 65536
  %extract481 = lshr i32 %h, 6
  %extract.t482 = trunc i32 %extract481 to i8
  %extract485 = lshr i32 %h, 12
  %extract.t486 = trunc i32 %extract485 to i8
  %extract489 = lshr i32 %h, 18
  %extract.t490 = trunc i32 %extract489 to i8
  br i1 %three.i, label %lead3.i, label %lead4.i

lead3.i:                                          ; preds = %large.i
  %extract.t = or disjoint i8 %extract.t486, -32
  br label %middle.i

lead4.i:                                          ; preds = %large.i.thread, %large.i
  %cp456459463.off0 = phi i8 [ %extract.t477, %large.i.thread ], [ %extract.t468, %large.i ]
  %cp456459463.off6 = phi i8 [ %extract.t480, %large.i.thread ], [ %extract.t482, %large.i ]
  %cp456459463.off12 = phi i8 [ %extract.t484, %large.i.thread ], [ %extract.t486, %large.i ]
  %cp456459463.off18 = phi i8 [ %extract.t488, %large.i.thread ], [ %extract.t490, %large.i ]
  %need.i.i343 = add i64 %b.sroa.38.0564, 2
  %wrap.not.i.i344 = icmp ult i64 %b.sroa.38.0564, -2
  br i1 %wrap.not.i.i344, label %check.i.i346, label %overflow.i.i345

check.i.i346:                                     ; preds = %lead4.i
  %enough.not.i.i347 = icmp ugt i64 %need.i.i343, %b.sroa.74.0563
  br i1 %enough.not.i.i347, label %grow.i.i356, label %byte.exit373

grow.i.i356:                                      ; preds = %check.i.i346
  %double.i.i357 = shl i64 %b.sroa.74.0563, 1
  %base.i.i358 = tail call i64 @llvm.umax.i64(i64 %double.i.i357, i64 %need.i.i343)
  %newcap.i.i359 = tail call i64 @llvm.umax.i64(i64 %base.i.i358, i64 64)
  %large.i.i.i360 = icmp ugt i64 %base.i.i358, 9223372036854775791
  br i1 %large.i.i.i360, label %oom.i.i.i372, label %allocate.i.i.i361

allocate.i.i.i361:                                ; preds = %grow.i.i356
  %size.i.i.i362 = add nuw nsw i64 %newcap.i.i359, 16
  %header.i.i.i363 = tail call ptr @malloc(i64 %size.i.i.i362)
  %null.i.i.i364 = icmp eq ptr %header.i.i.i363, null
  br i1 %null.i.i.i364, label %oom.i.i.i372, label %alloc.exit.i.i365

oom.i.i.i372:                                     ; preds = %allocate.i.i.i361, %grow.i.i356
  tail call fastcc void @print(ptr nonnull @msg_oom, ptr null, ptr null, ptr null)
  tail call void @exit(i32 1) #14
  unreachable

alloc.exit.i.i365:                                ; preds = %allocate.i.i.i361
  %old.i.i.i366 = load ptr, ptr @arena, align 8
  store ptr %old.i.i.i366, ptr %header.i.i.i363, align 8
  store ptr %header.i.i.i363, ptr @arena, align 8
  %data.i.i.i367 = getelementptr i8, ptr %header.i.i.i363, i64 16
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 1 dereferenceable(1) %data.i.i.i367, i8 0, i64 %newcap.i.i359, i1 false)
  %empty.i.i368 = icmp eq i64 %b.sroa.38.0564, 0
  br i1 %empty.i.i368, label %byte.exit373, label %copy.i.i369

copy.i.i369:                                      ; preds = %alloc.exit.i.i365
  tail call void @llvm.memcpy.p0.p0.i64(ptr nonnull align 1 %data.i.i.i367, ptr align 1 %b.sroa.0.0565, i64 %b.sroa.38.0564, i1 false)
  br label %byte.exit373

overflow.i.i345:                                  ; preds = %lead4.i
  tail call fastcc void @alloc(i64 -1)
  unreachable

byte.exit373:                                     ; preds = %alloc.exit.i.i365, %copy.i.i369, %check.i.i346
  %b.sroa.74.13 = phi i64 [ %b.sroa.74.0563, %check.i.i346 ], [ %newcap.i.i359, %copy.i.i369 ], [ %newcap.i.i359, %alloc.exit.i.i365 ]
  %b.sroa.0.14 = phi ptr [ %b.sroa.0.0565, %check.i.i346 ], [ %data.i.i.i367, %copy.i.i369 ], [ %data.i.i.i367, %alloc.exit.i.i365 ]
  %v.i351 = or i8 %cp456459463.off18, -16
  %out.i4.i352 = getelementptr i8, ptr %b.sroa.0.14, i64 %b.sroa.38.0564
  store i8 %v.i351, ptr %out.i4.i352, align 1
  %newlen.i.i354 = add nuw i64 %b.sroa.38.0564, 1
  %end.i.i355 = getelementptr i8, ptr %out.i4.i352, i64 1
  store i8 0, ptr %end.i.i355, align 1
  %3 = and i8 %cp456459463.off12, 63
  %extract.t465 = or disjoint i8 %3, -128
  br label %middle.i

middle.i:                                         ; preds = %byte.exit373, %lead3.i
  %cp456459464.off0 = phi i8 [ %extract.t468, %lead3.i ], [ %cp456459463.off0, %byte.exit373 ]
  %cp456459464.off6 = phi i8 [ %extract.t482, %lead3.i ], [ %cp456459463.off6, %byte.exit373 ]
  %b.sroa.74.8 = phi i64 [ %b.sroa.74.0563, %lead3.i ], [ %b.sroa.74.13, %byte.exit373 ]
  %b.sroa.38.1 = phi i64 [ %b.sroa.38.0564, %lead3.i ], [ %newlen.i.i354, %byte.exit373 ]
  %b.sroa.0.8 = phi ptr [ %b.sroa.0.0565, %lead3.i ], [ %b.sroa.0.14, %byte.exit373 ]
  %c4.sink.i.off0 = phi i8 [ %extract.t, %lead3.i ], [ %extract.t465, %byte.exit373 ]
  %need.i.i308 = add i64 %b.sroa.38.1, 2
  %wrap.not.i.i309 = icmp ult i64 %b.sroa.38.1, -2
  br i1 %wrap.not.i.i309, label %check.i.i311, label %overflow.i.i310

check.i.i311:                                     ; preds = %middle.i
  %enough.not.i.i312 = icmp ugt i64 %need.i.i308, %b.sroa.74.8
  br i1 %enough.not.i.i312, label %grow.i.i321, label %byte.exit338

grow.i.i321:                                      ; preds = %check.i.i311
  %double.i.i322 = shl i64 %b.sroa.74.8, 1
  %base.i.i323 = tail call i64 @llvm.umax.i64(i64 %double.i.i322, i64 %need.i.i308)
  %newcap.i.i324 = tail call i64 @llvm.umax.i64(i64 %base.i.i323, i64 64)
  %large.i.i.i325 = icmp ugt i64 %base.i.i323, 9223372036854775791
  br i1 %large.i.i.i325, label %oom.i.i.i337, label %allocate.i.i.i326

allocate.i.i.i326:                                ; preds = %grow.i.i321
  %size.i.i.i327 = add nuw nsw i64 %newcap.i.i324, 16
  %header.i.i.i328 = tail call ptr @malloc(i64 %size.i.i.i327)
  %null.i.i.i329 = icmp eq ptr %header.i.i.i328, null
  br i1 %null.i.i.i329, label %oom.i.i.i337, label %alloc.exit.i.i330

oom.i.i.i337:                                     ; preds = %allocate.i.i.i326, %grow.i.i321
  tail call fastcc void @print(ptr nonnull @msg_oom, ptr null, ptr null, ptr null)
  tail call void @exit(i32 1) #14
  unreachable

alloc.exit.i.i330:                                ; preds = %allocate.i.i.i326
  %old.i.i.i331 = load ptr, ptr @arena, align 8
  store ptr %old.i.i.i331, ptr %header.i.i.i328, align 8
  store ptr %header.i.i.i328, ptr @arena, align 8
  %data.i.i.i332 = getelementptr i8, ptr %header.i.i.i328, i64 16
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 1 dereferenceable(1) %data.i.i.i332, i8 0, i64 %newcap.i.i324, i1 false)
  %empty.i.i333 = icmp eq i64 %b.sroa.38.1, 0
  br i1 %empty.i.i333, label %byte.exit338, label %copy.i.i334

copy.i.i334:                                      ; preds = %alloc.exit.i.i330
  tail call void @llvm.memcpy.p0.p0.i64(ptr nonnull align 1 %data.i.i.i332, ptr align 1 %b.sroa.0.8, i64 %b.sroa.38.1, i1 false)
  br label %byte.exit338

overflow.i.i310:                                  ; preds = %middle.i
  tail call fastcc void @alloc(i64 -1)
  unreachable

byte.exit338:                                     ; preds = %alloc.exit.i.i330, %copy.i.i334, %check.i.i311
  %b.sroa.74.12 = phi i64 [ %b.sroa.74.8, %check.i.i311 ], [ %newcap.i.i324, %copy.i.i334 ], [ %newcap.i.i324, %alloc.exit.i.i330 ]
  %b.sroa.0.13 = phi ptr [ %b.sroa.0.8, %check.i.i311 ], [ %data.i.i.i332, %copy.i.i334 ], [ %data.i.i.i332, %alloc.exit.i.i330 ]
  %out.i4.i317 = getelementptr i8, ptr %b.sroa.0.13, i64 %b.sroa.38.1
  store i8 %c4.sink.i.off0, ptr %out.i4.i317, align 1
  %newlen.i.i319 = add nuw i64 %b.sroa.38.1, 1
  %end.i.i320 = getelementptr i8, ptr %out.i4.i317, i64 1
  store i8 0, ptr %end.i.i320, align 1
  %4 = and i8 %cp456459464.off6, 63
  %extract.t467 = or disjoint i8 %4, -128
  br label %last.i

last.i:                                           ; preds = %byte.exit338, %lead2.i
  %cp456460.off0 = phi i8 [ %extract.t468, %lead2.i ], [ %cp456459464.off0, %byte.exit338 ]
  %b.sroa.74.9 = phi i64 [ %b.sroa.74.0563, %lead2.i ], [ %b.sroa.74.12, %byte.exit338 ]
  %b.sroa.38.2 = phi i64 [ %b.sroa.38.0564, %lead2.i ], [ %newlen.i.i319, %byte.exit338 ]
  %b.sroa.0.9 = phi ptr [ %b.sroa.0.0565, %lead2.i ], [ %b.sroa.0.13, %byte.exit338 ]
  %c.sink.i.off0 = phi i8 [ %extract.t466, %lead2.i ], [ %extract.t467, %byte.exit338 ]
  %need.i.i273 = add i64 %b.sroa.38.2, 2
  %wrap.not.i.i274 = icmp ult i64 %b.sroa.38.2, -2
  br i1 %wrap.not.i.i274, label %check.i.i276, label %overflow.i.i275

check.i.i276:                                     ; preds = %last.i
  %enough.not.i.i277 = icmp ugt i64 %need.i.i273, %b.sroa.74.9
  br i1 %enough.not.i.i277, label %grow.i.i286, label %byte.exit303

grow.i.i286:                                      ; preds = %check.i.i276
  %double.i.i287 = shl i64 %b.sroa.74.9, 1
  %base.i.i288 = tail call i64 @llvm.umax.i64(i64 %double.i.i287, i64 %need.i.i273)
  %newcap.i.i289 = tail call i64 @llvm.umax.i64(i64 %base.i.i288, i64 64)
  %large.i.i.i290 = icmp ugt i64 %base.i.i288, 9223372036854775791
  br i1 %large.i.i.i290, label %oom.i.i.i302, label %allocate.i.i.i291

allocate.i.i.i291:                                ; preds = %grow.i.i286
  %size.i.i.i292 = add nuw nsw i64 %newcap.i.i289, 16
  %header.i.i.i293 = tail call ptr @malloc(i64 %size.i.i.i292)
  %null.i.i.i294 = icmp eq ptr %header.i.i.i293, null
  br i1 %null.i.i.i294, label %oom.i.i.i302, label %alloc.exit.i.i295

oom.i.i.i302:                                     ; preds = %allocate.i.i.i291, %grow.i.i286
  tail call fastcc void @print(ptr nonnull @msg_oom, ptr null, ptr null, ptr null)
  tail call void @exit(i32 1) #14
  unreachable

alloc.exit.i.i295:                                ; preds = %allocate.i.i.i291
  %old.i.i.i296 = load ptr, ptr @arena, align 8
  store ptr %old.i.i.i296, ptr %header.i.i.i293, align 8
  store ptr %header.i.i.i293, ptr @arena, align 8
  %data.i.i.i297 = getelementptr i8, ptr %header.i.i.i293, i64 16
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 1 dereferenceable(1) %data.i.i.i297, i8 0, i64 %newcap.i.i289, i1 false)
  %empty.i.i298 = icmp eq i64 %b.sroa.38.2, 0
  br i1 %empty.i.i298, label %byte.exit303, label %copy.i.i299

copy.i.i299:                                      ; preds = %alloc.exit.i.i295
  tail call void @llvm.memcpy.p0.p0.i64(ptr nonnull align 1 %data.i.i.i297, ptr align 1 %b.sroa.0.9, i64 %b.sroa.38.2, i1 false)
  br label %byte.exit303

overflow.i.i275:                                  ; preds = %last.i
  tail call fastcc void @alloc(i64 -1)
  unreachable

byte.exit303:                                     ; preds = %alloc.exit.i.i295, %copy.i.i299, %check.i.i276
  %b.sroa.74.11 = phi i64 [ %b.sroa.74.9, %check.i.i276 ], [ %newcap.i.i289, %copy.i.i299 ], [ %newcap.i.i289, %alloc.exit.i.i295 ]
  %b.sroa.0.12 = phi ptr [ %b.sroa.0.9, %check.i.i276 ], [ %data.i.i.i297, %copy.i.i299 ], [ %data.i.i.i297, %alloc.exit.i.i295 ]
  %out.i4.i282 = getelementptr i8, ptr %b.sroa.0.12, i64 %b.sroa.38.2
  store i8 %c.sink.i.off0, ptr %out.i4.i282, align 1
  %newlen.i.i284 = add nuw i64 %b.sroa.38.2, 1
  %end.i.i285 = getelementptr i8, ptr %out.i4.i282, i64 1
  store i8 0, ptr %end.i.i285, align 1
  %5 = and i8 %cp456460.off0, 63
  %extract.t469 = or disjoint i8 %5, -128
  br label %unicode.exit

unicode.exit:                                     ; preds = %emit, %byte.exit303
  %b.sroa.74.10 = phi i64 [ %b.sroa.74.0563, %emit ], [ %b.sroa.74.11, %byte.exit303 ]
  %b.sroa.38.3 = phi i64 [ %b.sroa.38.0564, %emit ], [ %newlen.i.i284, %byte.exit303 ]
  %b.sroa.0.10 = phi ptr [ %b.sroa.0.0565, %emit ], [ %b.sroa.0.12, %byte.exit303 ]
  %v.sink.i.off0 = phi i8 [ %extract.t468, %emit ], [ %extract.t469, %byte.exit303 ]
  %need.i.i378 = add i64 %b.sroa.38.3, 2
  %wrap.not.i.i379 = icmp ult i64 %b.sroa.38.3, -2
  br i1 %wrap.not.i.i379, label %check.i.i381, label %overflow.i.i380

check.i.i381:                                     ; preds = %unicode.exit
  %enough.not.i.i382 = icmp ugt i64 %need.i.i378, %b.sroa.74.10
  br i1 %enough.not.i.i382, label %grow.i.i391, label %byte.exit408

grow.i.i391:                                      ; preds = %check.i.i381
  %double.i.i392 = shl i64 %b.sroa.74.10, 1
  %base.i.i393 = tail call i64 @llvm.umax.i64(i64 %double.i.i392, i64 %need.i.i378)
  %newcap.i.i394 = tail call i64 @llvm.umax.i64(i64 %base.i.i393, i64 64)
  %large.i.i.i395 = icmp ugt i64 %base.i.i393, 9223372036854775791
  br i1 %large.i.i.i395, label %oom.i.i.i407, label %allocate.i.i.i396

allocate.i.i.i396:                                ; preds = %grow.i.i391
  %size.i.i.i397 = add nuw nsw i64 %newcap.i.i394, 16
  %header.i.i.i398 = tail call ptr @malloc(i64 %size.i.i.i397)
  %null.i.i.i399 = icmp eq ptr %header.i.i.i398, null
  br i1 %null.i.i.i399, label %oom.i.i.i407, label %alloc.exit.i.i400

oom.i.i.i407:                                     ; preds = %allocate.i.i.i396, %grow.i.i391
  tail call fastcc void @print(ptr nonnull @msg_oom, ptr null, ptr null, ptr null)
  tail call void @exit(i32 1) #14
  unreachable

alloc.exit.i.i400:                                ; preds = %allocate.i.i.i396
  %old.i.i.i401 = load ptr, ptr @arena, align 8
  store ptr %old.i.i.i401, ptr %header.i.i.i398, align 8
  store ptr %header.i.i.i398, ptr @arena, align 8
  %data.i.i.i402 = getelementptr i8, ptr %header.i.i.i398, i64 16
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 1 dereferenceable(1) %data.i.i.i402, i8 0, i64 %newcap.i.i394, i1 false)
  %empty.i.i403 = icmp eq i64 %b.sroa.38.3, 0
  br i1 %empty.i.i403, label %byte.exit408, label %copy.i.i404

copy.i.i404:                                      ; preds = %alloc.exit.i.i400
  tail call void @llvm.memcpy.p0.p0.i64(ptr nonnull align 1 %data.i.i.i402, ptr align 1 %b.sroa.0.10, i64 %b.sroa.38.3, i1 false)
  br label %byte.exit408

overflow.i.i380:                                  ; preds = %unicode.exit
  tail call fastcc void @alloc(i64 -1)
  unreachable

byte.exit408:                                     ; preds = %alloc.exit.i.i400, %copy.i.i404, %check.i.i381
  %b.sroa.74.14 = phi i64 [ %b.sroa.74.10, %check.i.i381 ], [ %newcap.i.i394, %copy.i.i404 ], [ %newcap.i.i394, %alloc.exit.i.i400 ]
  %b.sroa.0.15 = phi ptr [ %b.sroa.0.10, %check.i.i381 ], [ %data.i.i.i402, %copy.i.i404 ], [ %data.i.i.i402, %alloc.exit.i.i400 ]
  %out.i4.i387 = getelementptr i8, ptr %b.sroa.0.15, i64 %b.sroa.38.3
  store i8 %v.sink.i.off0, ptr %out.i4.i387, align 1
  br label %loop.backedge

common.ret:                                       ; preds = %pairhex, %take.exit259, %hex, %take.exit28, %raw, %loop.backedge, %escape, %take.exit246, %entry, %take.exit, %node.exit
  %common.ret.op = phi ptr [ %data.i.i267, %node.exit ], [ null, %take.exit ], [ null, %entry ], [ null, %take.exit246 ], [ null, %escape ], [ null, %loop.backedge ], [ null, %raw ], [ null, %take.exit28 ], [ null, %hex ], [ null, %take.exit259 ], [ null, %pairhex ]
  ret ptr %common.ret.op

end:                                              ; preds = %take.exit13
  %enough.not.i.not = icmp ult i64 %b.sroa.38.0564, %b.sroa.74.0563
  br i1 %enough.not.i.not, label %reserve.exit, label %grow.i

grow.i:                                           ; preds = %end
  %need.i = add nuw i64 %b.sroa.38.0564, 1
  %double.i = shl i64 %b.sroa.74.0563, 1
  %base.i = tail call i64 @llvm.umax.i64(i64 %double.i, i64 %need.i)
  %newcap.i = tail call i64 @llvm.umax.i64(i64 %base.i, i64 64)
  %large.i.i = icmp ugt i64 %base.i, 9223372036854775791
  br i1 %large.i.i, label %oom.i.i, label %allocate.i.i

allocate.i.i:                                     ; preds = %grow.i
  %size.i.i = add nuw nsw i64 %newcap.i, 16
  %header.i.i = tail call ptr @malloc(i64 %size.i.i)
  %null.i.i = icmp eq ptr %header.i.i, null
  br i1 %null.i.i, label %oom.i.i, label %alloc.exit.i

oom.i.i:                                          ; preds = %allocate.i.i, %grow.i
  tail call fastcc void @print(ptr nonnull @msg_oom, ptr null, ptr null, ptr null)
  tail call void @exit(i32 1) #14
  unreachable

alloc.exit.i:                                     ; preds = %allocate.i.i
  %old.i.i261 = load ptr, ptr @arena, align 8
  store ptr %old.i.i261, ptr %header.i.i, align 8
  store ptr %header.i.i, ptr @arena, align 8
  %data.i.i262 = getelementptr i8, ptr %header.i.i, i64 16
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 1 dereferenceable(1) %data.i.i262, i8 0, i64 %newcap.i, i1 false)
  %empty.i = icmp eq i64 %b.sroa.38.0564, 0
  br i1 %empty.i, label %reserve.exit, label %copy.i

copy.i:                                           ; preds = %alloc.exit.i
  tail call void @llvm.memcpy.p0.p0.i64(ptr nonnull align 1 %data.i.i262, ptr align 1 %b.sroa.0.0565, i64 %b.sroa.38.0564, i1 false)
  br label %reserve.exit

reserve.exit:                                     ; preds = %alloc.exit.i, %copy.i, %end
  %b.sroa.0.11 = phi ptr [ %b.sroa.0.0565, %end ], [ %data.i.i262, %copy.i ], [ %data.i.i262, %alloc.exit.i ]
  %header.i.i263 = tail call dereferenceable_or_null(72) ptr @malloc(i64 72)
  %null.i.i264 = icmp eq ptr %header.i.i263, null
  br i1 %null.i.i264, label %oom.i.i268, label %node.exit

oom.i.i268:                                       ; preds = %reserve.exit
  tail call fastcc void @print(ptr nonnull @msg_oom, ptr null, ptr null, ptr null)
  tail call void @exit(i32 1) #14
  unreachable

node.exit:                                        ; preds = %reserve.exit
  %old.i.i266 = load ptr, ptr @arena, align 8
  store ptr %old.i.i266, ptr %header.i.i263, align 8
  store ptr %header.i.i263, ptr @arena, align 8
  %data.i.i267 = getelementptr i8, ptr %header.i.i263, i64 16
  %6 = getelementptr i8, ptr %header.i.i263, i64 20
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 1 dereferenceable(52) %6, i8 0, i64 52, i1 false)
  store i32 2, ptr %data.i.i267, align 4
  %dp = getelementptr i8, ptr %header.i.i263, i64 24
  %np = getelementptr i8, ptr %header.i.i263, i64 32
  store ptr %b.sroa.0.11, ptr %dp, align 8
  store i64 %b.sroa.38.0564, ptr %np, align 4
  br label %common.ret
}

; Function Attrs: nofree nounwind memory(readwrite, inaccessiblemem: none)
define internal fastcc ptr @sort(ptr %head) unnamed_addr #9 {
entry:
  %head.i = alloca ptr, align 8
  %nil = icmp eq ptr %head, null
  br i1 %nil, label %common.ret, label %check

check:                                            ; preds = %entry
  %np = getelementptr i8, ptr %head, i64 32
  %next = load ptr, ptr %np, align 8
  %single = icmp eq ptr %next, null
  br i1 %single, label %common.ret, label %faststep

faststep:                                         ; preds = %check, %advance
  %fast2 = phi ptr [ %fnext2, %advance ], [ %next, %check ]
  %slow1 = phi ptr [ %snext, %advance ], [ %head, %check ]
  %fnp = getelementptr i8, ptr %fast2, i64 32
  %fnext = load ptr, ptr %fnp, align 8
  %last = icmp eq ptr %fnext, null
  br i1 %last, label %recurse, label %advance

advance:                                          ; preds = %faststep
  %snp = getelementptr i8, ptr %slow1, i64 32
  %snext = load ptr, ptr %snp, align 8
  %fn2p = getelementptr i8, ptr %fnext, i64 32
  %fnext2 = load ptr, ptr %fn2p, align 8
  %empty = icmp eq ptr %fnext2, null
  br i1 %empty, label %recurse, label %faststep

common.ret:                                       ; preds = %entry, %check, %merge.exit
  %common.ret.op = phi ptr [ %head.i.0.head.i.0.head.i.0.head.0.head.0.head.0.result.i, %merge.exit ], [ %head, %check ], [ null, %entry ]
  ret ptr %common.ret.op

recurse:                                          ; preds = %faststep, %advance
  %slow.lcssa = phi ptr [ %slow1, %faststep ], [ %snext, %advance ]
  %sp = getelementptr i8, ptr %slow.lcssa, i64 32
  %right = load ptr, ptr %sp, align 8
  store ptr null, ptr %sp, align 8
  %a = tail call fastcc ptr @sort(ptr nonnull %head)
  %b = tail call fastcc ptr @sort(ptr %right)
  call void @llvm.lifetime.start.p0(i64 8, ptr nonnull %head.i)
  store ptr null, ptr %head.i, align 8
  %anull6.i = icmp eq ptr %a, null
  br i1 %anull6.i, label %merge.exit, label %check_b.i

check_b.i:                                        ; preds = %recurse, %choose.i
  %slot9.i = phi ptr [ %np.i, %choose.i ], [ %head.i, %recurse ]
  %b8.i = phi ptr [ %spec.select3.i, %choose.i ], [ %b, %recurse ]
  %a7.i = phi ptr [ %spec.select.i, %choose.i ], [ %a, %recurse ]
  %bnull.i = icmp eq ptr %b8.i, null
  br i1 %bnull.i, label %merge.exit, label %choose.i

choose.i:                                         ; preds = %check_b.i
  %0 = getelementptr i8, ptr %a7.i, i64 40
  %a.val.i = load ptr, ptr %0, align 8
  %1 = getelementptr i8, ptr %a7.i, i64 48
  %a.val1.i = load i64, ptr %1, align 4
  %2 = getelementptr i8, ptr %b8.i, i64 40
  %b.val.i = load ptr, ptr %2, align 8
  %3 = getelementptr i8, ptr %b8.i, i64 48
  %b.val2.i = load i64, ptr %3, align 4
  %len.i.i = tail call i64 @llvm.umin.i64(i64 %a.val1.i, i64 %b.val2.i)
  %cmp.i.i = tail call i32 @memcmp(ptr readonly %a.val.i, ptr readonly %b.val.i, i64 %len.i.i)
  %equal.i.i = icmp eq i32 %cmp.i.i, 0
  %first4.i = icmp ule i64 %a.val1.i, %b.val2.i
  %first5.i = icmp slt i32 %cmp.i.i, 1
  %first.i = select i1 %equal.i.i, i1 %first4.i, i1 %first5.i
  %chosen.i = select i1 %first.i, ptr %a7.i, ptr %b8.i
  %np.i = getelementptr i8, ptr %chosen.i, i64 32
  %next.i = load ptr, ptr %np.i, align 8
  store ptr %chosen.i, ptr %slot9.i, align 8
  %spec.select.i = select i1 %first.i, ptr %next.i, ptr %a7.i
  %spec.select3.i = select i1 %first.i, ptr %b8.i, ptr %next.i
  %anull.i = icmp eq ptr %spec.select.i, null
  br i1 %anull.i, label %merge.exit, label %check_b.i

merge.exit:                                       ; preds = %check_b.i, %choose.i, %recurse
  %slot.lcssa.i = phi ptr [ %head.i, %recurse ], [ %np.i, %choose.i ], [ %slot9.i, %check_b.i ]
  %storemerge.i = phi ptr [ %b, %recurse ], [ %spec.select3.i, %choose.i ], [ %a7.i, %check_b.i ]
  store ptr %storemerge.i, ptr %slot.lcssa.i, align 8
  %head.i.0.head.i.0.head.i.0.head.0.head.0.head.0.result.i = load ptr, ptr %head.i, align 8
  call void @llvm.lifetime.end.p0(i64 8, ptr nonnull %head.i)
  br label %common.ret
}

; Function Attrs: nofree
define internal fastcc noundef ptr @collection(ptr nonnull captures(none) %p, i1 %object) unnamed_addr #7 {
entry:
  %dp = getelementptr i8, ptr %p, i64 24
  %depth = load i32, ptr %dp, align 4
  %newdepth = add i32 %depth, 1
  %deep = icmp ugt i32 %newdepth, 127
  br i1 %deep, label %common.ret, label %begin

begin:                                            ; preds = %entry
  store i32 %newdepth, ptr %dp, align 4
  %lp.i.i = getelementptr i8, ptr %p, i64 8
  %ip.i.i = getelementptr i8, ptr %p, i64 16
  %len.i.i = load i64, ptr %lp.i.i, align 4
  %i.i.i = load i64, ptr %ip.i.i, align 4
  %end.not.i.i = icmp ult i64 %i.i.i, %len.i.i
  br i1 %end.not.i.i, label %peek.exit.i, label %take.exit

peek.exit.i:                                      ; preds = %begin
  %next.i = add nuw i64 %i.i.i, 1
  store i64 %next.i, ptr %ip.i.i, align 4
  br label %take.exit

take.exit:                                        ; preds = %begin, %peek.exit.i
  %ip.i.promoted.i = phi i64 [ %i.i.i, %begin ], [ %next.i, %peek.exit.i ]
  %close = select i1 %object, i32 125, i32 93
  %header.i.i = tail call dereferenceable_or_null(72) ptr @malloc(i64 72)
  %null.i.i = icmp eq ptr %header.i.i, null
  br i1 %null.i.i, label %oom.i.i, label %node.exit

oom.i.i:                                          ; preds = %take.exit
  tail call fastcc void @print(ptr nonnull @msg_oom, ptr null, ptr null, ptr null)
  tail call void @exit(i32 1) #14
  unreachable

node.exit:                                        ; preds = %take.exit
  %tag = select i1 %object, i32 1, i32 3
  %old.i.i = load ptr, ptr @arena, align 8
  store ptr %old.i.i, ptr %header.i.i, align 8
  store ptr %header.i.i, ptr @arena, align 8
  %data.i.i1 = getelementptr i8, ptr %header.i.i, i64 16
  %0 = getelementptr i8, ptr %header.i.i, i64 20
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 1 dereferenceable(52) %0, i8 0, i64 52, i1 false)
  store i32 %tag, ptr %data.i.i1, align 4
  %headp = getelementptr i8, ptr %header.i.i, i64 40
  %end.not.i6.i = icmp ult i64 %ip.i.promoted.i, %len.i.i
  br i1 %end.not.i6.i, label %peek.exit.lr.ph.i, label %entry_value.preheader

peek.exit.lr.ph.i:                                ; preds = %node.exit
  %data.i.i5 = load ptr, ptr %p, align 8
  br label %peek.exit.i6

peek.exit.i6:                                     ; preds = %take.exit.i, %peek.exit.lr.ph.i
  %next.i57.i = phi i64 [ %ip.i.promoted.i, %peek.exit.lr.ph.i ], [ %next.i.i, %take.exit.i ]
  %q.i.i7 = getelementptr i8, ptr %data.i.i5, i64 %next.i57.i
  %v.i.i8 = load i8, ptr %q.i.i7, align 1
  switch i8 %v.i.i8, label %skip_space.exit [
    i8 32, label %take.exit.i
    i8 9, label %take.exit.i
    i8 10, label %take.exit.i
    i8 13, label %take.exit.i
  ]

take.exit.i:                                      ; preds = %peek.exit.i6, %peek.exit.i6, %peek.exit.i6, %peek.exit.i6
  %next.i.i = add nuw i64 %next.i57.i, 1
  store i64 %next.i.i, ptr %ip.i.i, align 4
  %end.not.i.i9 = icmp ult i64 %next.i.i, %len.i.i
  br i1 %end.not.i.i9, label %peek.exit.i6, label %entry_value.preheader

skip_space.exit:                                  ; preds = %peek.exit.i6
  %c.i.le.i = zext i8 %v.i.i8 to i32
  %empty = icmp eq i32 %close, %c.i.le.i
  br i1 %empty, label %finish, label %entry_value.preheader

entry_value.preheader:                            ; preds = %take.exit.i, %node.exit, %skip_space.exit
  br i1 %object, label %entry_value.preheader.split.us, label %entry_value.preheader.split

entry_value.preheader.split.us:                   ; preds = %entry_value.preheader
  %k.us138 = tail call fastcc ptr @parse_string(ptr %p)
  %nokey.us139 = icmp eq ptr %k.us138, null
  br i1 %nokey.us139, label %common.ret, label %colon.us

colon.us:                                         ; preds = %entry_value.preheader.split.us, %skip_space.exit89.us
  %k.us140 = phi ptr [ %k.us, %skip_space.exit89.us ], [ %k.us138, %entry_value.preheader.split.us ]
  %len.i.i12.us = load i64, ptr %lp.i.i, align 4
  %ip.i.promoted.i13.us = load i64, ptr %ip.i.i, align 4
  %end.not.i6.i14.us = icmp ult i64 %ip.i.promoted.i13.us, %len.i.i12.us
  br i1 %end.not.i6.i14.us, label %peek.exit.lr.ph.i16.us, label %skip_space.exit27.us

peek.exit.lr.ph.i16.us:                           ; preds = %colon.us
  %data.i.i17.us = load ptr, ptr %p, align 8
  br label %peek.exit.i18.us

peek.exit.i18.us:                                 ; preds = %take.exit.i22.us, %peek.exit.lr.ph.i16.us
  %next.i57.i19.us = phi i64 [ %ip.i.promoted.i13.us, %peek.exit.lr.ph.i16.us ], [ %next.i.i23.us, %take.exit.i22.us ]
  %q.i.i20.us = getelementptr i8, ptr %data.i.i17.us, i64 %next.i57.i19.us
  %v.i.i21.us = load i8, ptr %q.i.i20.us, align 1
  switch i8 %v.i.i21.us, label %skip_space.exit27.us [
    i8 32, label %take.exit.i22.us
    i8 9, label %take.exit.i22.us
    i8 10, label %take.exit.i22.us
    i8 13, label %take.exit.i22.us
  ]

take.exit.i22.us:                                 ; preds = %peek.exit.i18.us, %peek.exit.i18.us, %peek.exit.i18.us, %peek.exit.i18.us
  %next.i.i23.us = add nuw i64 %next.i57.i19.us, 1
  store i64 %next.i.i23.us, ptr %ip.i.i, align 4
  %end.not.i.i24.us = icmp ult i64 %next.i.i23.us, %len.i.i12.us
  br i1 %end.not.i.i24.us, label %peek.exit.i18.us, label %skip_space.exit27.us

skip_space.exit27.us:                             ; preds = %peek.exit.i18.us, %take.exit.i22.us, %colon.us
  %i.i.i31.us = phi i64 [ %ip.i.promoted.i13.us, %colon.us ], [ %next.i57.i19.us, %peek.exit.i18.us ], [ %next.i.i23.us, %take.exit.i22.us ]
  %end.not.i.i32.us = icmp ult i64 %i.i.i31.us, %len.i.i12.us
  br i1 %end.not.i.i32.us, label %take.exit40.us, label %common.ret

take.exit40.us:                                   ; preds = %skip_space.exit27.us
  %data.i.i35.us = load ptr, ptr %p, align 8
  %q.i.i36.us = getelementptr i8, ptr %data.i.i35.us, i64 %i.i.i31.us
  %v.i.i37.us = load i8, ptr %q.i.i36.us, align 1
  %next.i39.us = add nuw i64 %i.i.i31.us, 1
  store i64 %next.i39.us, ptr %ip.i.i, align 4
  %oksep.us = icmp eq i8 %v.i.i37.us, 58
  br i1 %oksep.us, label %value.us, label %common.ret

value.us:                                         ; preds = %take.exit40.us
  %v.us = tail call fastcc ptr @parse_value(ptr %p)
  %novalue.us = icmp eq ptr %v.us, null
  br i1 %novalue.us, label %common.ret, label %attach_object.us

attach_object.us:                                 ; preds = %value.us
  %np.us = getelementptr i8, ptr %v.us, i64 32
  %kd.us = getelementptr i8, ptr %k.us140, i64 8
  %kl.us = getelementptr i8, ptr %k.us140, i64 16
  %keydata.us = load ptr, ptr %kd.us, align 8
  %keylen.us = load i64, ptr %kl.us, align 4
  %vkp.us = getelementptr i8, ptr %v.us, i64 40
  %vklp.us = getelementptr i8, ptr %v.us, i64 48
  store ptr %keydata.us, ptr %vkp.us, align 8
  store i64 %keylen.us, ptr %vklp.us, align 4
  %old.us = load ptr, ptr %headp, align 8
  store ptr %old.us, ptr %np.us, align 8
  store ptr %v.us, ptr %headp, align 8
  %len.i.i43.us = load i64, ptr %lp.i.i, align 4
  %ip.i.promoted.i44.us = load i64, ptr %ip.i.i, align 4
  %end.not.i6.i45.us = icmp ult i64 %ip.i.promoted.i44.us, %len.i.i43.us
  br i1 %end.not.i6.i45.us, label %peek.exit.lr.ph.i47.us, label %common.ret

peek.exit.lr.ph.i47.us:                           ; preds = %attach_object.us
  %data.i.i48.us = load ptr, ptr %p, align 8
  br label %peek.exit.i49.us

peek.exit.i49.us:                                 ; preds = %take.exit.i53.us, %peek.exit.lr.ph.i47.us
  %i.i.i62.us = phi i64 [ %ip.i.promoted.i44.us, %peek.exit.lr.ph.i47.us ], [ %next.i.i54.us, %take.exit.i53.us ]
  %q.i.i51.us = getelementptr i8, ptr %data.i.i48.us, i64 %i.i.i62.us
  %v.i.i52.us = load i8, ptr %q.i.i51.us, align 1
  switch i8 %v.i.i52.us, label %skip_space.exit58.us [
    i8 32, label %take.exit.i53.us
    i8 9, label %take.exit.i53.us
    i8 10, label %take.exit.i53.us
    i8 13, label %take.exit.i53.us
  ]

take.exit.i53.us:                                 ; preds = %peek.exit.i49.us, %peek.exit.i49.us, %peek.exit.i49.us, %peek.exit.i49.us
  %next.i.i54.us = add nuw i64 %i.i.i62.us, 1
  store i64 %next.i.i54.us, ptr %ip.i.i, align 4
  %end.not.i.i55.us = icmp ult i64 %next.i.i54.us, %len.i.i43.us
  br i1 %end.not.i.i55.us, label %peek.exit.i49.us, label %common.ret

skip_space.exit58.us:                             ; preds = %peek.exit.i49.us
  %c.i.le.i57.us = zext i8 %v.i.i52.us to i32
  %isend.us = icmp eq i32 %close, %c.i.le.i57.us
  br i1 %isend.us, label %finish, label %comma.us

comma.us:                                         ; preds = %skip_space.exit58.us
  %iscomma.us = icmp eq i8 %v.i.i52.us, 44
  br i1 %iscomma.us, label %next_value.us, label %common.ret

next_value.us:                                    ; preds = %comma.us
  %end.not.i.i63.us = icmp ult i64 %i.i.i62.us, %len.i.i43.us
  br i1 %end.not.i.i63.us, label %peek.exit.i65.us, label %take.exit71.us

peek.exit.i65.us:                                 ; preds = %next_value.us
  %next.i70.us = add nuw i64 %i.i.i62.us, 1
  store i64 %next.i70.us, ptr %ip.i.i, align 4
  br label %take.exit71.us

take.exit71.us:                                   ; preds = %peek.exit.i65.us, %next_value.us
  %ip.i.promoted.i75.us = phi i64 [ %next.i70.us, %peek.exit.i65.us ], [ %i.i.i62.us, %next_value.us ]
  %end.not.i6.i76.us = icmp ult i64 %ip.i.promoted.i75.us, %len.i.i43.us
  br i1 %end.not.i6.i76.us, label %peek.exit.i80.us, label %skip_space.exit89.us

peek.exit.i80.us:                                 ; preds = %take.exit71.us, %take.exit.i84.us
  %next.i57.i81.us = phi i64 [ %next.i.i85.us, %take.exit.i84.us ], [ %ip.i.promoted.i75.us, %take.exit71.us ]
  %q.i.i82.us = getelementptr i8, ptr %data.i.i48.us, i64 %next.i57.i81.us
  %v.i.i83.us = load i8, ptr %q.i.i82.us, align 1
  switch i8 %v.i.i83.us, label %skip_space.exit89.us [
    i8 32, label %take.exit.i84.us
    i8 9, label %take.exit.i84.us
    i8 10, label %take.exit.i84.us
    i8 13, label %take.exit.i84.us
  ]

take.exit.i84.us:                                 ; preds = %peek.exit.i80.us, %peek.exit.i80.us, %peek.exit.i80.us, %peek.exit.i80.us
  %next.i.i85.us = add nuw i64 %next.i57.i81.us, 1
  store i64 %next.i.i85.us, ptr %ip.i.i, align 4
  %end.not.i.i86.us = icmp ult i64 %next.i.i85.us, %len.i.i43.us
  br i1 %end.not.i.i86.us, label %peek.exit.i80.us, label %skip_space.exit89.us

skip_space.exit89.us:                             ; preds = %peek.exit.i80.us, %take.exit.i84.us, %take.exit71.us
  %k.us = tail call fastcc ptr @parse_string(ptr %p)
  %nokey.us = icmp eq ptr %k.us, null
  br i1 %nokey.us, label %common.ret, label %colon.us

entry_value.preheader.split:                      ; preds = %entry_value.preheader
  %v107132 = tail call fastcc ptr @parse_value(ptr %p)
  %novalue108133 = icmp eq ptr %v107132, null
  br i1 %novalue108133, label %common.ret, label %attach.thread

attach.thread:                                    ; preds = %entry_value.preheader.split, %skip_space.exit89
  %v107135 = phi ptr [ %v107, %skip_space.exit89 ], [ %v107132, %entry_value.preheader.split ]
  %np113127134 = phi ptr [ %np113, %skip_space.exit89 ], [ %headp, %entry_value.preheader.split ]
  %np113 = getelementptr i8, ptr %v107135, i64 32
  store ptr %v107135, ptr %np113127134, align 8
  %len.i.i43 = load i64, ptr %lp.i.i, align 4
  %ip.i.promoted.i44 = load i64, ptr %ip.i.i, align 4
  %end.not.i6.i45 = icmp ult i64 %ip.i.promoted.i44, %len.i.i43
  br i1 %end.not.i6.i45, label %peek.exit.lr.ph.i47, label %common.ret

peek.exit.lr.ph.i47:                              ; preds = %attach.thread
  %data.i.i48 = load ptr, ptr %p, align 8
  br label %peek.exit.i49

peek.exit.i49:                                    ; preds = %take.exit.i53, %peek.exit.lr.ph.i47
  %i.i.i62 = phi i64 [ %ip.i.promoted.i44, %peek.exit.lr.ph.i47 ], [ %next.i.i54, %take.exit.i53 ]
  %q.i.i51 = getelementptr i8, ptr %data.i.i48, i64 %i.i.i62
  %v.i.i52 = load i8, ptr %q.i.i51, align 1
  switch i8 %v.i.i52, label %skip_space.exit58 [
    i8 32, label %take.exit.i53
    i8 9, label %take.exit.i53
    i8 10, label %take.exit.i53
    i8 13, label %take.exit.i53
  ]

take.exit.i53:                                    ; preds = %peek.exit.i49, %peek.exit.i49, %peek.exit.i49, %peek.exit.i49
  %next.i.i54 = add nuw i64 %i.i.i62, 1
  store i64 %next.i.i54, ptr %ip.i.i, align 4
  %end.not.i.i55 = icmp ult i64 %next.i.i54, %len.i.i43
  br i1 %end.not.i.i55, label %peek.exit.i49, label %common.ret

skip_space.exit58:                                ; preds = %peek.exit.i49
  %c.i.le.i57 = zext i8 %v.i.i52 to i32
  %isend = icmp eq i32 %close, %c.i.le.i57
  br i1 %isend, label %finish, label %comma

comma:                                            ; preds = %skip_space.exit58
  %iscomma = icmp eq i8 %v.i.i52, 44
  br i1 %iscomma, label %next_value, label %common.ret

next_value:                                       ; preds = %comma
  %end.not.i.i63 = icmp ult i64 %i.i.i62, %len.i.i43
  br i1 %end.not.i.i63, label %peek.exit.i65, label %take.exit71

peek.exit.i65:                                    ; preds = %next_value
  %next.i70 = add nuw i64 %i.i.i62, 1
  store i64 %next.i70, ptr %ip.i.i, align 4
  br label %take.exit71

take.exit71:                                      ; preds = %next_value, %peek.exit.i65
  %ip.i.promoted.i75 = phi i64 [ %i.i.i62, %next_value ], [ %next.i70, %peek.exit.i65 ]
  %end.not.i6.i76 = icmp ult i64 %ip.i.promoted.i75, %len.i.i43
  br i1 %end.not.i6.i76, label %peek.exit.i80, label %skip_space.exit89

peek.exit.i80:                                    ; preds = %take.exit71, %take.exit.i84
  %next.i57.i81 = phi i64 [ %next.i.i85, %take.exit.i84 ], [ %ip.i.promoted.i75, %take.exit71 ]
  %q.i.i82 = getelementptr i8, ptr %data.i.i48, i64 %next.i57.i81
  %v.i.i83 = load i8, ptr %q.i.i82, align 1
  switch i8 %v.i.i83, label %skip_space.exit89 [
    i8 32, label %take.exit.i84
    i8 9, label %take.exit.i84
    i8 10, label %take.exit.i84
    i8 13, label %take.exit.i84
  ]

take.exit.i84:                                    ; preds = %peek.exit.i80, %peek.exit.i80, %peek.exit.i80, %peek.exit.i80
  %next.i.i85 = add nuw i64 %next.i57.i81, 1
  store i64 %next.i.i85, ptr %ip.i.i, align 4
  %end.not.i.i86 = icmp ult i64 %next.i.i85, %len.i.i43
  br i1 %end.not.i.i86, label %peek.exit.i80, label %skip_space.exit89

skip_space.exit89:                                ; preds = %peek.exit.i80, %take.exit.i84, %take.exit71
  %v107 = tail call fastcc ptr @parse_value(ptr %p)
  %novalue108 = icmp eq ptr %v107, null
  br i1 %novalue108, label %common.ret, label %attach.thread

finish:                                           ; preds = %skip_space.exit58, %skip_space.exit58.us, %skip_space.exit
  %i.i.i93 = phi i64 [ %next.i57.i, %skip_space.exit ], [ %i.i.i62.us, %skip_space.exit58.us ], [ %i.i.i62, %skip_space.exit58 ]
  %len.i.i92 = phi i64 [ %len.i.i, %skip_space.exit ], [ %len.i.i43.us, %skip_space.exit58.us ], [ %len.i.i43, %skip_space.exit58 ]
  %end.not.i.i94 = icmp ult i64 %i.i.i93, %len.i.i92
  br i1 %end.not.i.i94, label %peek.exit.i96, label %take.exit102

peek.exit.i96:                                    ; preds = %finish
  %next.i101 = add nuw i64 %i.i.i93, 1
  store i64 %next.i101, ptr %ip.i.i, align 4
  br label %take.exit102

take.exit102:                                     ; preds = %finish, %peek.exit.i96
  store i32 %depth, ptr %dp, align 4
  br i1 %object, label %order, label %common.ret

order:                                            ; preds = %take.exit102
  %head = load ptr, ptr %headp, align 8
  %sorted = tail call fastcc ptr @sort(ptr %head)
  %nil10.i = icmp eq ptr %sorted, null
  br i1 %nil10.i, label %dedup.exit, label %check.lr.ph.split.i.preheader

check.lr.ph.split.i.preheader:                    ; preds = %order
  %np.i147 = getelementptr i8, ptr %sorted, i64 32
  %np.promoted.i148 = load ptr, ptr %np.i147, align 8
  %last8.i149 = icmp eq ptr %np.promoted.i148, null
  br i1 %last8.i149, label %dedup.exit, label %compare.preheader.i.preheader

compare.preheader.i.preheader:                    ; preds = %check.lr.ph.split.i.preheader
  %.phi.trans.insert = getelementptr i8, ptr %sorted, i64 40
  %n.val.pre.i.pre = load ptr, ptr %.phi.trans.insert, align 8
  %.phi.trans.insert174 = getelementptr i8, ptr %sorted, i64 48
  %n.val1.pre.i.pre = load i64, ptr %.phi.trans.insert174, align 4
  br label %compare.preheader.i

check.lr.ph.split.i.loopexit:                     ; preds = %compare.i
  %last8.i = icmp eq ptr %after.i, null
  br i1 %last8.i, label %dedup.exit, label %compare.preheader.i

compare.preheader.i:                              ; preds = %compare.preheader.i.preheader, %check.lr.ph.split.i.loopexit
  %n.val1.pre.i = phi i64 [ %next.val2.i, %check.lr.ph.split.i.loopexit ], [ %n.val1.pre.i.pre, %compare.preheader.i.preheader ]
  %n.val.pre.i = phi ptr [ %next.val.i, %check.lr.ph.split.i.loopexit ], [ %n.val.pre.i.pre, %compare.preheader.i.preheader ]
  %np.promoted.i152 = phi ptr [ %after.i, %check.lr.ph.split.i.loopexit ], [ %np.promoted.i148, %compare.preheader.i.preheader ]
  %np.i151 = phi ptr [ %nnp.i, %check.lr.ph.split.i.loopexit ], [ %np.i147, %compare.preheader.i.preheader ]
  br label %compare.i

compare.i:                                        ; preds = %duplicate.i, %compare.preheader.i
  %next49.i = phi ptr [ %after.i, %duplicate.i ], [ %np.promoted.i152, %compare.preheader.i ]
  %1 = getelementptr i8, ptr %next49.i, i64 40
  %next.val.i = load ptr, ptr %1, align 8
  %2 = getelementptr i8, ptr %next49.i, i64 48
  %next.val2.i = load i64, ptr %2, align 4
  %len.i.i103 = tail call i64 @llvm.umin.i64(i64 %n.val1.pre.i, i64 %next.val2.i)
  %cmp.i.i = tail call i32 @memcmp(ptr readonly %n.val.pre.i, ptr readonly %next.val.i, i64 %len.i.i103)
  %equal.i.i = icmp eq i32 %cmp.i.i, 0
  %same3.i = icmp eq i64 %n.val1.pre.i, %next.val2.i
  %same.i = select i1 %equal.i.i, i1 %same3.i, i1 false
  %nnp.i = getelementptr i8, ptr %next49.i, i64 32
  %after.i = load ptr, ptr %nnp.i, align 8
  br i1 %same.i, label %duplicate.i, label %check.lr.ph.split.i.loopexit

duplicate.i:                                      ; preds = %compare.i
  store ptr %after.i, ptr %np.i151, align 8
  %last.i = icmp eq ptr %after.i, null
  br i1 %last.i, label %dedup.exit, label %compare.i

dedup.exit:                                       ; preds = %check.lr.ph.split.i.loopexit, %duplicate.i, %check.lr.ph.split.i.preheader, %order
  store ptr %sorted, ptr %headp, align 8
  br label %common.ret

common.ret:                                       ; preds = %attach.thread, %skip_space.exit89, %comma, %take.exit.i53, %skip_space.exit89.us, %skip_space.exit27.us, %take.exit40.us, %value.us, %attach_object.us, %comma.us, %take.exit.i53.us, %entry_value.preheader.split.us, %entry_value.preheader.split, %entry, %take.exit102, %dedup.exit
  %common.ret.op = phi ptr [ %data.i.i1, %dedup.exit ], [ %data.i.i1, %take.exit102 ], [ null, %entry ], [ null, %entry_value.preheader.split ], [ null, %entry_value.preheader.split.us ], [ null, %take.exit.i53.us ], [ null, %comma.us ], [ null, %attach_object.us ], [ null, %value.us ], [ null, %take.exit40.us ], [ null, %skip_space.exit27.us ], [ null, %skip_space.exit89.us ], [ null, %take.exit.i53 ], [ null, %comma ], [ null, %skip_space.exit89 ], [ null, %attach.thread ]
  ret ptr %common.ret.op
}

; Function Attrs: nofree
define internal fastcc noundef ptr @parse_value(ptr nonnull captures(none) %p) unnamed_addr #7 {
entry:
  %lp.i.i = getelementptr i8, ptr %p, i64 8
  %ip.i.i = getelementptr i8, ptr %p, i64 16
  %len.i.i = load i64, ptr %lp.i.i, align 4
  %ip.i.promoted.i = load i64, ptr %ip.i.i, align 4
  %end.not.i6.i = icmp ult i64 %ip.i.promoted.i, %len.i.i
  br i1 %end.not.i6.i, label %peek.exit.lr.ph.i, label %number

peek.exit.lr.ph.i:                                ; preds = %entry
  %data.i.i = load ptr, ptr %p, align 8
  br label %peek.exit.i

peek.exit.i:                                      ; preds = %take.exit.i, %peek.exit.lr.ph.i
  %ip.i.i.promoted63 = phi i64 [ %ip.i.promoted.i, %peek.exit.lr.ph.i ], [ %next.i.i, %take.exit.i ]
  %q.i.i = getelementptr i8, ptr %data.i.i, i64 %ip.i.i.promoted63
  %v.i.i = load i8, ptr %q.i.i, align 1
  switch i8 %v.i.i, label %number [
    i8 32, label %take.exit.i
    i8 9, label %take.exit.i
    i8 10, label %take.exit.i
    i8 13, label %take.exit.i
    i8 123, label %object
    i8 91, label %array
    i8 34, label %string
    i8 116, label %loop.i.preheader
    i8 102, label %loop.i5.preheader
    i8 110, label %loop.i24.preheader
  ]

loop.i24.preheader:                               ; preds = %peek.exit.i
  %end.not.i.i.i30 = icmp ult i64 %ip.i.i.promoted63, %len.i.i
  br i1 %end.not.i.i.i30, label %loop.i24.1, label %common.ret

loop.i5.preheader:                                ; preds = %peek.exit.i
  %end.not.i.i.i11 = icmp ult i64 %ip.i.i.promoted63, %len.i.i
  br i1 %end.not.i.i.i11, label %loop.i5.1, label %common.ret

loop.i.preheader:                                 ; preds = %peek.exit.i
  %end.not.i.i.i = icmp ult i64 %ip.i.i.promoted63, %len.i.i
  br i1 %end.not.i.i.i, label %loop.i.1, label %common.ret

take.exit.i:                                      ; preds = %peek.exit.i, %peek.exit.i, %peek.exit.i, %peek.exit.i
  %next.i.i = add nuw i64 %ip.i.i.promoted63, 1
  store i64 %next.i.i, ptr %ip.i.i, align 4
  %end.not.i.i = icmp ult i64 %next.i.i, %len.i.i
  br i1 %end.not.i.i, label %peek.exit.i, label %number

common.ret:                                       ; preds = %loop.i24.preheader, %loop.i24.1, %take.exit.i31.1, %take.exit.i31.2, %take.exit.i31.3, %loop.i5.preheader, %loop.i5.1, %take.exit.i12.1, %take.exit.i12.2, %take.exit.i12.3, %take.exit.i12.4, %loop.i.preheader, %loop.i.1, %take.exit.i1.1, %take.exit.i1.2, %take.exit.i1.3, %node.exit.i, %alloc.exit.i, %digits.exit159.i, %expdigits.i, %digits.exit90.i, %take.exit71.i, %nonzero.i, %peek.exit37.i, %integer.i, %node.exit, %string, %array, %object
  %common.ret.op = phi ptr [ %o, %object ], [ %a, %array ], [ %s, %string ], [ %data.i.i41, %node.exit ], [ %data.i.i161.i, %node.exit.i ], [ null, %alloc.exit.i ], [ null, %digits.exit159.i ], [ null, %digits.exit90.i ], [ null, %nonzero.i ], [ null, %peek.exit37.i ], [ null, %integer.i ], [ null, %take.exit71.i ], [ null, %expdigits.i ], [ null, %take.exit.i1.3 ], [ null, %take.exit.i1.2 ], [ null, %take.exit.i1.1 ], [ null, %loop.i.1 ], [ null, %loop.i.preheader ], [ null, %take.exit.i12.4 ], [ null, %take.exit.i12.3 ], [ null, %take.exit.i12.2 ], [ null, %take.exit.i12.1 ], [ null, %loop.i5.1 ], [ null, %loop.i5.preheader ], [ null, %take.exit.i31.3 ], [ null, %take.exit.i31.2 ], [ null, %take.exit.i31.1 ], [ null, %loop.i24.1 ], [ null, %loop.i24.preheader ]
  ret ptr %common.ret.op

object:                                           ; preds = %peek.exit.i
  %o = tail call fastcc ptr @collection(ptr %p, i1 true)
  br label %common.ret

array:                                            ; preds = %peek.exit.i
  %a = tail call fastcc ptr @collection(ptr %p, i1 false)
  br label %common.ret

string:                                           ; preds = %peek.exit.i
  %s = tail call fastcc ptr @parse_string(ptr %p)
  br label %common.ret

loop.i.1:                                         ; preds = %loop.i.preheader
  %next.i.i2 = add nuw i64 %ip.i.i.promoted63, 1
  store i64 %next.i.i2, ptr %ip.i.i, align 4
  %end.not.i.i.i.1 = icmp ult i64 %next.i.i2, %len.i.i
  br i1 %end.not.i.i.i.1, label %take.exit.i1.1, label %common.ret

take.exit.i1.1:                                   ; preds = %loop.i.1
  %q.i.i.i.1 = getelementptr i8, ptr %data.i.i, i64 %next.i.i2
  %v.i.i.i.1 = load i8, ptr %q.i.i.i.1, align 1
  %next.i.i2.1 = add nuw i64 %ip.i.i.promoted63, 2
  store i64 %next.i.i2.1, ptr %ip.i.i, align 4
  %same.i.1 = icmp eq i8 %v.i.i.i.1, 114
  %end.not.i.i.i.2 = icmp ult i64 %next.i.i2.1, %len.i.i
  %or.cond = select i1 %same.i.1, i1 %end.not.i.i.i.2, i1 false
  br i1 %or.cond, label %take.exit.i1.2, label %common.ret

take.exit.i1.2:                                   ; preds = %take.exit.i1.1
  %q.i.i.i.2 = getelementptr i8, ptr %data.i.i, i64 %next.i.i2.1
  %v.i.i.i.2 = load i8, ptr %q.i.i.i.2, align 1
  %next.i.i2.2 = add nuw i64 %ip.i.i.promoted63, 3
  store i64 %next.i.i2.2, ptr %ip.i.i, align 4
  %same.i.2 = icmp eq i8 %v.i.i.i.2, 117
  %end.not.i.i.i.3 = icmp ult i64 %next.i.i2.2, %len.i.i
  %or.cond82 = select i1 %same.i.2, i1 %end.not.i.i.i.3, i1 false
  br i1 %or.cond82, label %take.exit.i1.3, label %common.ret

take.exit.i1.3:                                   ; preds = %take.exit.i1.2
  %q.i.i.i.3 = getelementptr i8, ptr %data.i.i, i64 %next.i.i2.2
  %v.i.i.i.3 = load i8, ptr %q.i.i.i.3, align 1
  %next.i.i2.3 = add nuw i64 %ip.i.i.promoted63, 4
  store i64 %next.i.i2.3, ptr %ip.i.i, align 4
  %same.i.3 = icmp eq i8 %v.i.i.i.3, 101
  br i1 %same.i.3, label %scalar, label %common.ret

loop.i5.1:                                        ; preds = %loop.i5.preheader
  %next.i.i18 = add nuw i64 %ip.i.i.promoted63, 1
  store i64 %next.i.i18, ptr %ip.i.i, align 4
  %end.not.i.i.i11.1 = icmp ult i64 %next.i.i18, %len.i.i
  br i1 %end.not.i.i.i11.1, label %take.exit.i12.1, label %common.ret

take.exit.i12.1:                                  ; preds = %loop.i5.1
  %q.i.i.i16.1 = getelementptr i8, ptr %data.i.i, i64 %next.i.i18
  %v.i.i.i17.1 = load i8, ptr %q.i.i.i16.1, align 1
  %next.i.i18.1 = add nuw i64 %ip.i.i.promoted63, 2
  store i64 %next.i.i18.1, ptr %ip.i.i, align 4
  %same.i19.1 = icmp eq i8 %v.i.i.i17.1, 97
  %end.not.i.i.i11.2 = icmp ult i64 %next.i.i18.1, %len.i.i
  %or.cond83 = select i1 %same.i19.1, i1 %end.not.i.i.i11.2, i1 false
  br i1 %or.cond83, label %take.exit.i12.2, label %common.ret

take.exit.i12.2:                                  ; preds = %take.exit.i12.1
  %q.i.i.i16.2 = getelementptr i8, ptr %data.i.i, i64 %next.i.i18.1
  %v.i.i.i17.2 = load i8, ptr %q.i.i.i16.2, align 1
  %next.i.i18.2 = add nuw i64 %ip.i.i.promoted63, 3
  store i64 %next.i.i18.2, ptr %ip.i.i, align 4
  %same.i19.2 = icmp eq i8 %v.i.i.i17.2, 108
  %end.not.i.i.i11.3 = icmp ult i64 %next.i.i18.2, %len.i.i
  %or.cond84 = select i1 %same.i19.2, i1 %end.not.i.i.i11.3, i1 false
  br i1 %or.cond84, label %take.exit.i12.3, label %common.ret

take.exit.i12.3:                                  ; preds = %take.exit.i12.2
  %q.i.i.i16.3 = getelementptr i8, ptr %data.i.i, i64 %next.i.i18.2
  %v.i.i.i17.3 = load i8, ptr %q.i.i.i16.3, align 1
  %next.i.i18.3 = add nuw i64 %ip.i.i.promoted63, 4
  store i64 %next.i.i18.3, ptr %ip.i.i, align 4
  %same.i19.3 = icmp eq i8 %v.i.i.i17.3, 115
  %end.not.i.i.i11.4 = icmp ult i64 %next.i.i18.3, %len.i.i
  %or.cond85 = select i1 %same.i19.3, i1 %end.not.i.i.i11.4, i1 false
  br i1 %or.cond85, label %take.exit.i12.4, label %common.ret

take.exit.i12.4:                                  ; preds = %take.exit.i12.3
  %q.i.i.i16.4 = getelementptr i8, ptr %data.i.i, i64 %next.i.i18.3
  %v.i.i.i17.4 = load i8, ptr %q.i.i.i16.4, align 1
  %next.i.i18.4 = add nuw i64 %ip.i.i.promoted63, 5
  store i64 %next.i.i18.4, ptr %ip.i.i, align 4
  %same.i19.4 = icmp eq i8 %v.i.i.i17.4, 101
  br i1 %same.i19.4, label %scalar, label %common.ret

loop.i24.1:                                       ; preds = %loop.i24.preheader
  %next.i.i37 = add nuw i64 %ip.i.i.promoted63, 1
  store i64 %next.i.i37, ptr %ip.i.i, align 4
  %end.not.i.i.i30.1 = icmp ult i64 %next.i.i37, %len.i.i
  br i1 %end.not.i.i.i30.1, label %take.exit.i31.1, label %common.ret

take.exit.i31.1:                                  ; preds = %loop.i24.1
  %q.i.i.i35.1 = getelementptr i8, ptr %data.i.i, i64 %next.i.i37
  %v.i.i.i36.1 = load i8, ptr %q.i.i.i35.1, align 1
  %next.i.i37.1 = add nuw i64 %ip.i.i.promoted63, 2
  store i64 %next.i.i37.1, ptr %ip.i.i, align 4
  %same.i38.1 = icmp eq i8 %v.i.i.i36.1, 117
  %end.not.i.i.i30.2 = icmp ult i64 %next.i.i37.1, %len.i.i
  %or.cond86 = select i1 %same.i38.1, i1 %end.not.i.i.i30.2, i1 false
  br i1 %or.cond86, label %take.exit.i31.2, label %common.ret

take.exit.i31.2:                                  ; preds = %take.exit.i31.1
  %q.i.i.i35.2 = getelementptr i8, ptr %data.i.i, i64 %next.i.i37.1
  %v.i.i.i36.2 = load i8, ptr %q.i.i.i35.2, align 1
  %next.i.i37.2 = add nuw i64 %ip.i.i.promoted63, 3
  store i64 %next.i.i37.2, ptr %ip.i.i, align 4
  %same.i38.2 = icmp eq i8 %v.i.i.i36.2, 108
  %end.not.i.i.i30.3 = icmp ult i64 %next.i.i37.2, %len.i.i
  %or.cond87 = select i1 %same.i38.2, i1 %end.not.i.i.i30.3, i1 false
  br i1 %or.cond87, label %take.exit.i31.3, label %common.ret

take.exit.i31.3:                                  ; preds = %take.exit.i31.2
  %q.i.i.i35.3 = getelementptr i8, ptr %data.i.i, i64 %next.i.i37.2
  %v.i.i.i36.3 = load i8, ptr %q.i.i.i35.3, align 1
  %next.i.i37.3 = add nuw i64 %ip.i.i.promoted63, 4
  store i64 %next.i.i37.3, ptr %ip.i.i, align 4
  %same.i38.3 = icmp eq i8 %v.i.i.i36.3, 108
  br i1 %same.i38.3, label %scalar, label %common.ret

scalar:                                           ; preds = %take.exit.i31.3, %take.exit.i12.4, %take.exit.i1.3
  %header.i.i = tail call dereferenceable_or_null(72) ptr @malloc(i64 72)
  %null.i.i = icmp eq ptr %header.i.i, null
  br i1 %null.i.i, label %oom.i.i, label %node.exit

oom.i.i:                                          ; preds = %scalar
  tail call fastcc void @print(ptr nonnull @msg_oom, ptr null, ptr null, ptr null)
  tail call void @exit(i32 1) #14
  unreachable

node.exit:                                        ; preds = %scalar
  %old.i.i = load ptr, ptr @arena, align 8
  store ptr %old.i.i, ptr %header.i.i, align 8
  store ptr %header.i.i, ptr @arena, align 8
  %data.i.i41 = getelementptr i8, ptr %header.i.i, i64 16
  %0 = getelementptr i8, ptr %header.i.i, i64 20
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 1 dereferenceable(52) %0, i8 0, i64 52, i1 false)
  store i32 4, ptr %data.i.i41, align 4
  br label %common.ret

number:                                           ; preds = %peek.exit.i, %take.exit.i, %entry
  %start.i = phi i64 [ %ip.i.promoted.i, %entry ], [ %ip.i.i.promoted63, %peek.exit.i ], [ %next.i.i, %take.exit.i ]
  %end.not.i.i44 = icmp ult i64 %start.i, %len.i.i
  br i1 %end.not.i.i44, label %peek.exit.i49, label %integer.i

peek.exit.i49:                                    ; preds = %number
  %data.i.i50 = load ptr, ptr %p, align 8
  %q.i.i51 = getelementptr i8, ptr %data.i.i50, i64 %start.i
  %v.i.i52 = load i8, ptr %q.i.i51, align 1
  %negative.i = icmp eq i8 %v.i.i52, 45
  br i1 %negative.i, label %take.exit.i53, label %integer.i

take.exit.i53:                                    ; preds = %peek.exit.i49
  %next.i.i54 = add nuw i64 %start.i, 1
  store i64 %next.i.i54, ptr %ip.i.i, align 4
  br label %integer.i

integer.i:                                        ; preds = %take.exit.i53, %peek.exit.i49, %number
  %i.i4.i = phi i64 [ %start.i, %number ], [ %next.i.i54, %take.exit.i53 ], [ %start.i, %peek.exit.i49 ]
  %end.not.i5.i = icmp ult i64 %i.i4.i, %len.i.i
  br i1 %end.not.i5.i, label %peek.exit12.i, label %common.ret

peek.exit12.i:                                    ; preds = %integer.i
  %data.i8.i = load ptr, ptr %p, align 8
  %q.i9.i = getelementptr i8, ptr %data.i8.i, i64 %i.i4.i
  %v.i10.i = load i8, ptr %q.i9.i, align 1
  %zero.i = icmp eq i8 %v.i10.i, 48
  br i1 %zero.i, label %take.exit25.i, label %nonzero.i

take.exit25.i:                                    ; preds = %peek.exit12.i
  %next.i24.i = add nuw i64 %i.i4.i, 1
  store i64 %next.i24.i, ptr %ip.i.i, align 4
  %end.not.i30.i = icmp ult i64 %next.i24.i, %len.i.i
  br i1 %end.not.i30.i, label %peek.exit37.i, label %fraction.i

peek.exit37.i:                                    ; preds = %take.exit25.i
  %q.i34.i = getelementptr i8, ptr %data.i8.i, i64 %next.i24.i
  %v.i35.i = load i8, ptr %q.i34.i, align 1
  %1 = add i8 %v.i35.i, -48
  %yes.i.i = icmp ult i8 %1, 10
  br i1 %yes.i.i, label %common.ret, label %fraction.i

nonzero.i:                                        ; preds = %peek.exit12.i
  %2 = add i8 %v.i10.i, -49
  %valid.i = icmp ult i8 %2, 9
  br i1 %valid.i, label %peek.exit.i42.i, label %common.ret

peek.exit.i42.i:                                  ; preds = %nonzero.i, %take.exit.i.i
  %next.i46.i.i = phi i64 [ %next.i.i.i, %take.exit.i.i ], [ %i.i4.i, %nonzero.i ]
  %q.i.i43.i = getelementptr i8, ptr %data.i8.i, i64 %next.i46.i.i
  %v.i.i44.i = load i8, ptr %q.i.i43.i, align 1
  %3 = add i8 %v.i.i44.i, -48
  %yes.i.i.i = icmp ult i8 %3, 10
  br i1 %yes.i.i.i, label %take.exit.i.i, label %fraction.i

take.exit.i.i:                                    ; preds = %peek.exit.i42.i
  %next.i.i.i = add nuw i64 %next.i46.i.i, 1
  store i64 %next.i.i.i, ptr %ip.i.i, align 4
  %end.not.i.i46.i = icmp ult i64 %next.i.i.i, %len.i.i
  br i1 %end.not.i.i46.i, label %peek.exit.i42.i, label %finite.i

fraction.i:                                       ; preds = %peek.exit.i42.i, %peek.exit37.i, %take.exit25.i
  %i.i50.i = phi i64 [ %next.i24.i, %take.exit25.i ], [ %next.i24.i, %peek.exit37.i ], [ %next.i46.i.i, %peek.exit.i42.i ]
  %end.not.i51.i = icmp ult i64 %i.i50.i, %len.i.i
  br i1 %end.not.i51.i, label %peek.exit58.i, label %exponent.i

peek.exit58.i:                                    ; preds = %fraction.i
  %q.i55.i = getelementptr i8, ptr %data.i8.i, i64 %i.i50.i
  %v.i56.i = load i8, ptr %q.i55.i, align 1
  %hasfrac.i = icmp eq i8 %v.i56.i, 46
  br i1 %hasfrac.i, label %take.exit71.i, label %exponent.i

take.exit71.i:                                    ; preds = %peek.exit58.i
  %next.i70.i = add nuw i64 %i.i50.i, 1
  store i64 %next.i70.i, ptr %ip.i.i, align 4
  %end.not.i5.i76.i = icmp ult i64 %next.i70.i, %len.i.i
  br i1 %end.not.i5.i76.i, label %peek.exit.lr.ph.i78.i, label %common.ret

peek.exit.lr.ph.i78.i:                            ; preds = %take.exit71.i
  %4 = sub nuw i64 %len.i.i, %next.i70.i
  br label %peek.exit.i80.i

peek.exit.i80.i:                                  ; preds = %take.exit.i86.i, %peek.exit.lr.ph.i78.i
  %count7.i81.i = phi i64 [ 0, %peek.exit.lr.ph.i78.i ], [ %next.i88.i, %take.exit.i86.i ]
  %next.i46.i82.i = phi i64 [ %next.i70.i, %peek.exit.lr.ph.i78.i ], [ %next.i.i87.i, %take.exit.i86.i ]
  %q.i.i83.i = getelementptr i8, ptr %data.i8.i, i64 %next.i46.i82.i
  %v.i.i84.i = load i8, ptr %q.i.i83.i, align 1
  %5 = add i8 %v.i.i84.i, -48
  %yes.i.i85.i = icmp ult i8 %5, 10
  br i1 %yes.i.i85.i, label %take.exit.i86.i, label %digits.exit90.i

take.exit.i86.i:                                  ; preds = %peek.exit.i80.i
  %next.i.i87.i = add nuw i64 %next.i46.i82.i, 1
  store i64 %next.i.i87.i, ptr %ip.i.i, align 4
  %next.i88.i = add i64 %count7.i81.i, 1
  %end.not.i.i89.i = icmp ult i64 %next.i.i87.i, %len.i.i
  br i1 %end.not.i.i89.i, label %peek.exit.i80.i, label %digits.exit90.i

digits.exit90.i:                                  ; preds = %take.exit.i86.i, %peek.exit.i80.i
  %i.i94186.i = phi i64 [ %len.i.i, %take.exit.i86.i ], [ %next.i46.i82.i, %peek.exit.i80.i ]
  %count.lcssa.i77.i = phi i64 [ %4, %take.exit.i86.i ], [ %count7.i81.i, %peek.exit.i80.i ]
  %emptyfrac.i = icmp eq i64 %count.lcssa.i77.i, 0
  br i1 %emptyfrac.i, label %common.ret, label %exponent.i

exponent.i:                                       ; preds = %digits.exit90.i, %peek.exit58.i, %fraction.i
  %i.i94.i = phi i64 [ %i.i50.i, %fraction.i ], [ %i.i94186.i, %digits.exit90.i ], [ %i.i50.i, %peek.exit58.i ]
  %end.not.i95.i = icmp ult i64 %i.i94.i, %len.i.i
  br i1 %end.not.i95.i, label %peek.exit102.i, label %finite.i

peek.exit102.i:                                   ; preds = %exponent.i
  %q.i99.i = getelementptr i8, ptr %data.i8.i, i64 %i.i94.i
  %v.i100.i = load i8, ptr %q.i99.i, align 1
  %6 = and i8 %v.i100.i, -33
  %hasexp.i = icmp eq i8 %6, 69
  br i1 %hasexp.i, label %take.exit115.i, label %finite.i

take.exit115.i:                                   ; preds = %peek.exit102.i
  %next.i114.i = add nuw i64 %i.i94.i, 1
  store i64 %next.i114.i, ptr %ip.i.i, align 4
  %end.not.i120.i = icmp ult i64 %next.i114.i, %len.i.i
  br i1 %end.not.i120.i, label %peek.exit127.i, label %expdigits.i

peek.exit127.i:                                   ; preds = %take.exit115.i
  %q.i124.i = getelementptr i8, ptr %data.i8.i, i64 %next.i114.i
  %v.i125.i = load i8, ptr %q.i124.i, align 1
  switch i8 %v.i125.i, label %expdigits.i [
    i8 45, label %take.exit140.i
    i8 43, label %take.exit140.i
  ]

take.exit140.i:                                   ; preds = %peek.exit127.i, %peek.exit127.i
  %next.i139.i = add nuw i64 %i.i94.i, 2
  store i64 %next.i139.i, ptr %ip.i.i, align 4
  br label %expdigits.i

expdigits.i:                                      ; preds = %take.exit140.i, %peek.exit127.i, %take.exit115.i
  %ip.i.promoted.i144.i = phi i64 [ %next.i114.i, %take.exit115.i ], [ %next.i114.i, %peek.exit127.i ], [ %next.i139.i, %take.exit140.i ]
  %end.not.i5.i145.i = icmp ult i64 %ip.i.promoted.i144.i, %len.i.i
  br i1 %end.not.i5.i145.i, label %peek.exit.lr.ph.i147.i, label %common.ret

peek.exit.lr.ph.i147.i:                           ; preds = %expdigits.i
  %7 = sub nuw i64 %len.i.i, %ip.i.promoted.i144.i
  br label %peek.exit.i149.i

peek.exit.i149.i:                                 ; preds = %take.exit.i155.i, %peek.exit.lr.ph.i147.i
  %count7.i150.i = phi i64 [ 0, %peek.exit.lr.ph.i147.i ], [ %next.i157.i, %take.exit.i155.i ]
  %next.i46.i151.i = phi i64 [ %ip.i.promoted.i144.i, %peek.exit.lr.ph.i147.i ], [ %next.i.i156.i, %take.exit.i155.i ]
  %q.i.i152.i = getelementptr i8, ptr %data.i8.i, i64 %next.i46.i151.i
  %v.i.i153.i = load i8, ptr %q.i.i152.i, align 1
  %8 = add i8 %v.i.i153.i, -48
  %yes.i.i154.i = icmp ult i8 %8, 10
  br i1 %yes.i.i154.i, label %take.exit.i155.i, label %digits.exit159.i

take.exit.i155.i:                                 ; preds = %peek.exit.i149.i
  %next.i.i156.i = add nuw i64 %next.i46.i151.i, 1
  store i64 %next.i.i156.i, ptr %ip.i.i, align 4
  %next.i157.i = add i64 %count7.i150.i, 1
  %end.not.i.i158.i = icmp ult i64 %next.i.i156.i, %len.i.i
  br i1 %end.not.i.i158.i, label %peek.exit.i149.i, label %digits.exit159.i

digits.exit159.i:                                 ; preds = %take.exit.i155.i, %peek.exit.i149.i
  %end189.i = phi i64 [ %len.i.i, %take.exit.i155.i ], [ %next.i46.i151.i, %peek.exit.i149.i ]
  %count.lcssa.i146.i = phi i64 [ %7, %take.exit.i155.i ], [ %count7.i150.i, %peek.exit.i149.i ]
  %emptyexp.i = icmp eq i64 %count.lcssa.i146.i, 0
  br i1 %emptyexp.i, label %common.ret, label %finite.i

finite.i:                                         ; preds = %take.exit.i.i, %digits.exit159.i, %peek.exit102.i, %exponent.i
  %end.i = phi i64 [ %i.i94.i, %exponent.i ], [ %end189.i, %digits.exit159.i ], [ %i.i94.i, %peek.exit102.i ], [ %len.i.i, %take.exit.i.i ]
  %len.i = sub i64 %end.i, %start.i
  %size.i = add i64 %len.i, 1
  %large.i.i = icmp ugt i64 %size.i, 9223372036854775791
  br i1 %large.i.i, label %oom.i.i48, label %allocate.i.i

allocate.i.i:                                     ; preds = %finite.i
  %size.i.i = add nsw i64 %len.i, 17
  %header.i.i45 = tail call ptr @malloc(i64 %size.i.i)
  %null.i.i46 = icmp eq ptr %header.i.i45, null
  br i1 %null.i.i46, label %oom.i.i48, label %alloc.exit.i

oom.i.i48:                                        ; preds = %allocate.i.i, %finite.i
  tail call fastcc void @print(ptr nonnull @msg_oom, ptr null, ptr null, ptr null)
  tail call void @exit(i32 1) #14
  unreachable

alloc.exit.i:                                     ; preds = %allocate.i.i
  %old.i.i47 = load ptr, ptr @arena, align 8
  store ptr %old.i.i47, ptr %header.i.i45, align 8
  store ptr %header.i.i45, ptr @arena, align 8
  %data.i160.i = getelementptr i8, ptr %header.i.i45, i64 16
  tail call void @llvm.memset.p0.i64(ptr align 1 %data.i160.i, i8 0, i64 %size.i, i1 false)
  %src.i = getelementptr i8, ptr %data.i8.i, i64 %start.i
  tail call void @llvm.memcpy.p0.p0.i64(ptr align 1 %data.i160.i, ptr align 1 %src.i, i64 %len.i, i1 false)
  %value.i = tail call double @strtod(ptr captures(none) %data.i160.i, ptr null)
  %9 = tail call double @llvm.fabs.f64(double %value.i)
  %ok.i = fcmp ugt double %9, 0x7FEFFFFFFFFFFFFF
  br i1 %ok.i, label %common.ret, label %yes.i

yes.i:                                            ; preds = %alloc.exit.i
  %header.i.i.i = tail call dereferenceable_or_null(72) ptr @malloc(i64 72)
  %null.i.i.i = icmp eq ptr %header.i.i.i, null
  br i1 %null.i.i.i, label %oom.i.i.i, label %node.exit.i

oom.i.i.i:                                        ; preds = %yes.i
  tail call fastcc void @print(ptr nonnull @msg_oom, ptr null, ptr null, ptr null)
  tail call void @exit(i32 1) #14
  unreachable

node.exit.i:                                      ; preds = %yes.i
  %old.i.i.i = load ptr, ptr @arena, align 8
  store ptr %old.i.i.i, ptr %header.i.i.i, align 8
  store ptr %header.i.i.i, ptr @arena, align 8
  %data.i.i161.i = getelementptr i8, ptr %header.i.i.i, i64 16
  %10 = getelementptr i8, ptr %header.i.i.i, i64 20
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 1 dereferenceable(52) %10, i8 0, i64 52, i1 false)
  store i32 4, ptr %data.i.i161.i, align 4
  br label %common.ret
}

define internal fastcc void @io_error(ptr %action, ptr %context) unnamed_addr {
entry:
  %e = tail call i32 @last_errno()
  %reason = tail call ptr @strerror(i32 %e)
  %stream.i = load ptr, ptr @errstream, align 8
  %closed.i = icmp eq ptr %stream.i, null
  br i1 %closed.i, label %print.exit, label %write.i

write.i:                                          ; preds = %entry
  %0 = tail call i32 (ptr, ptr, ...) @fprintf(ptr nonnull %stream.i, ptr nonnull @msg_io, ptr %action, ptr %context, ptr %reason)
  br label %print.exit

print.exit:                                       ; preds = %entry, %write.i
  ret void
}

define internal fastcc noundef i1 @write_file(ptr %name, ptr readonly captures(none) %content, i64 %len, i1 %script, ptr %context) unnamed_addr {
entry:
  %file = tail call ptr @fopen(ptr %name, ptr nonnull @mode_write)
  %failed = icmp eq ptr %file, null
  br i1 %failed, label %create_error, label %write

write:                                            ; preds = %entry
  %written = tail call i64 @fwrite(ptr %content, i64 1, i64 %len, ptr nonnull %file)
  %short.not = icmp eq i64 %written, %len
  br i1 %short.not, label %flush, label %write_error

common.ret:                                       ; preds = %write.i.i11, %chmod_error, %write.i.i5, %create_error, %executable, %chmod, %io_error.exit
  %common.ret.op = phi i1 [ false, %io_error.exit ], [ true, %chmod ], [ true, %executable ], [ false, %create_error ], [ false, %write.i.i5 ], [ false, %chmod_error ], [ false, %write.i.i11 ]
  ret i1 %common.ret.op

write_error:                                      ; preds = %write
  %e.i = tail call i32 @last_errno()
  %reason.i = tail call ptr @strerror(i32 %e.i)
  %stream.i.i = load ptr, ptr @errstream, align 8
  %closed.i.i = icmp eq ptr %stream.i.i, null
  br i1 %closed.i.i, label %io_error.exit, label %write.i.i

write.i.i:                                        ; preds = %write_error
  %0 = tail call i32 (ptr, ptr, ...) @fprintf(ptr nonnull %stream.i.i, ptr nonnull @msg_io, ptr nonnull @action_write, ptr %context, ptr %reason.i)
  br label %io_error.exit

io_error.exit:                                    ; preds = %write_error, %write.i.i
  %1 = tail call i32 @fclose(ptr nonnull %file)
  br label %common.ret

flush:                                            ; preds = %write
  %closed = tail call i32 @fclose(ptr nonnull %file)
  %closefailed.not = icmp eq i32 %closed, 0
  br i1 %closefailed.not, label %executable, label %create_error

executable:                                       ; preds = %flush
  br i1 %script, label %mode, label %common.ret

mode:                                             ; preds = %executable
  %permissions = tail call i32 @file_mode(ptr %name)
  %statfailed = icmp slt i32 %permissions, 0
  br i1 %statfailed, label %chmod_error, label %chmod

chmod:                                            ; preds = %mode
  %newmode = or i32 %permissions, 73
  %changed = tail call i32 @chmod(ptr %name, i32 %newmode)
  %chmodfailed.not = icmp eq i32 %changed, 0
  br i1 %chmodfailed.not, label %common.ret, label %chmod_error

create_error:                                     ; preds = %flush, %entry
  %e.i1 = tail call i32 @last_errno()
  %reason.i2 = tail call ptr @strerror(i32 %e.i1)
  %stream.i.i3 = load ptr, ptr @errstream, align 8
  %closed.i.i4 = icmp eq ptr %stream.i.i3, null
  br i1 %closed.i.i4, label %common.ret, label %write.i.i5

write.i.i5:                                       ; preds = %create_error
  %action = select i1 %script, ptr @action_script, ptr @action_file
  %2 = tail call i32 (ptr, ptr, ...) @fprintf(ptr nonnull %stream.i.i3, ptr nonnull @msg_io, ptr nonnull %action, ptr %context, ptr %reason.i2)
  br label %common.ret

chmod_error:                                      ; preds = %chmod, %mode
  %e.i7 = tail call i32 @last_errno()
  %reason.i8 = tail call ptr @strerror(i32 %e.i7)
  %stream.i.i9 = load ptr, ptr @errstream, align 8
  %closed.i.i10 = icmp eq ptr %stream.i.i9, null
  br i1 %closed.i.i10, label %common.ret, label %write.i.i11

write.i.i11:                                      ; preds = %chmod_error
  %3 = tail call i32 (ptr, ptr, ...) @fprintf(ptr nonnull %stream.i.i9, ptr nonnull @msg_io, ptr nonnull @action_chmod, ptr %context, ptr %reason.i8)
  br label %common.ret
}

define internal fastcc noundef i1 @run_object(ptr nonnull readonly captures(none) %object, ptr %context) unnamed_addr {
entry:
  %cp = getelementptr i8, ptr %object, i64 24
  %n119 = load ptr, ptr %cp, align 8
  %end120 = icmp eq ptr %n119, null
  br i1 %end120, label %common.ret, label %validate

validate:                                         ; preds = %entry, %advance
  %n121 = phi ptr [ %n, %advance ], [ %n119, %entry ]
  %0 = getelementptr i8, ptr %n121, i64 40
  %n.val = load ptr, ptr %0, align 8
  %1 = getelementptr i8, ptr %n121, i64 48
  %n.val1 = load i64, ptr %1, align 4
  %empty.i = icmp eq i64 %n.val1, 0
  br i1 %empty.i, label %path_error, label %first.i

first.i:                                          ; preds = %validate
  %c.i = load i8, ptr %n.val, align 1
  %root.i = icmp eq i8 %c.i, 47
  br i1 %root.i, label %read.i.preheader.i, label %read.i4.i

rootloop.i:                                       ; preds = %dot_segment.exit.i
  %rnext.i = add i64 %i.lcssa.i.i, 1
  %rdone.not.i = icmp ult i64 %rnext.i, %n.val1
  br i1 %rdone.not.i, label %read.i.preheader.i, label %path_error

read.i.preheader.i:                               ; preds = %first.i, %rootloop.i
  %ri9.i = phi i64 [ %rnext.i, %rootloop.i ], [ 0, %first.i ]
  br label %read.i.i

read.i.i:                                         ; preds = %advance.i.i, %read.i.preheader.i
  %i2.i.i = phi i64 [ %next.i.i, %advance.i.i ], [ %ri9.i, %read.i.preheader.i ]
  %p.i.i = getelementptr i8, ptr %n.val, i64 %i2.i.i
  %c.i.i = load i8, ptr %p.i.i, align 1
  %slash.i.i = icmp eq i8 %c.i.i, 47
  br i1 %slash.i.i, label %segment_end.exit.i, label %advance.i.i

advance.i.i:                                      ; preds = %read.i.i
  %next.i.i = add i64 %i2.i.i, 1
  %end.i.i = icmp eq i64 %next.i.i, %n.val1
  br i1 %end.i.i, label %segment_end.exit.i, label %read.i.i

segment_end.exit.i:                               ; preds = %advance.i.i, %read.i.i
  %i.lcssa.i.i = phi i64 [ %i2.i.i, %read.i.i ], [ %n.val1, %advance.i.i ]
  %rempty.i = icmp eq i64 %ri9.i, %i.lcssa.i.i
  %len.i.i = sub i64 %i.lcssa.i.i, %ri9.i
  %one.i.i = icmp eq i64 %len.i.i, 1
  br i1 %one.i.i, label %check.i.i, label %dot_segment.exit.i

check.i.i:                                        ; preds = %segment_end.exit.i
  %p.i1.i = getelementptr i8, ptr %n.val, i64 %ri9.i
  %c.i2.i = load i8, ptr %p.i1.i, align 1
  %yes.i.i = icmp eq i8 %c.i2.i, 46
  br label %dot_segment.exit.i

dot_segment.exit.i:                               ; preds = %check.i.i, %segment_end.exit.i
  %common.ret.op.i.i = phi i1 [ %yes.i.i, %check.i.i ], [ false, %segment_end.exit.i ]
  %rskip.i = or i1 %rempty.i, %common.ret.op.i.i
  br i1 %rskip.i, label %rootloop.i, label %path_error

read.i4.i:                                        ; preds = %first.i, %advance.i9.i
  %i2.i5.i = phi i64 [ %next.i10.i, %advance.i9.i ], [ 0, %first.i ]
  %p.i6.i = getelementptr i8, ptr %n.val, i64 %i2.i5.i
  %c.i7.i = load i8, ptr %p.i6.i, align 1
  %slash.i8.i = icmp eq i8 %c.i7.i, 47
  br i1 %slash.i8.i, label %segment_end.exit13.i, label %advance.i9.i

advance.i9.i:                                     ; preds = %read.i4.i
  %next.i10.i = add nuw i64 %i2.i5.i, 1
  %end.i11.i = icmp eq i64 %next.i10.i, %n.val1
  br i1 %end.i11.i, label %segment_end.exit13.i, label %read.i4.i

segment_end.exit13.i:                             ; preds = %advance.i9.i, %read.i4.i
  %i.lcssa.i12.i = phi i64 [ %i2.i5.i, %read.i4.i ], [ %n.val1, %advance.i9.i ]
  %one.i15.i = icmp eq i64 %i.lcssa.i12.i, 1
  br i1 %one.i15.i, label %dot_segment.exit21.thread.i, label %dot_segment.exit21.i

dot_segment.exit21.thread.i:                      ; preds = %segment_end.exit13.i
  %yes.i20.i = icmp eq i8 %c.i, 46
  br label %tail_begin.i

dot_segment.exit21.i:                             ; preds = %segment_end.exit13.i
  %two.i = icmp eq i64 %i.lcssa.i12.i, 2
  %firstdot.i = icmp eq i8 %c.i, 46
  %maybeparent.i = and i1 %firstdot.i, %two.i
  br i1 %maybeparent.i, label %parentcheck.i, label %tail_begin.i

parentcheck.i:                                    ; preds = %dot_segment.exit21.i
  %secondp.i = getelementptr i8, ptr %n.val, i64 1
  %second.i = load i8, ptr %secondp.i, align 1
  %parent.i = icmp eq i8 %second.i, 46
  br label %tail_begin.i

tail_begin.i:                                     ; preds = %parentcheck.i, %dot_segment.exit21.i, %dot_segment.exit21.thread.i
  %nonnormal.i = phi i1 [ false, %dot_segment.exit21.i ], [ %parent.i, %parentcheck.i ], [ %yes.i20.i, %dot_segment.exit21.thread.i ]
  br label %tail.i

tail.i:                                           ; preds = %dot_segment.exit40.i, %tail_begin.i
  %i.in.i = phi i64 [ %i.lcssa.i12.i, %tail_begin.i ], [ %i.lcssa.i31.i, %dot_segment.exit40.i ]
  %i.i = add i64 %i.in.i, 1
  %done.not.i = icmp ult i64 %i.i, %n.val1
  br i1 %done.not.i, label %read.i23.i, label %checked.i

read.i23.i:                                       ; preds = %tail.i, %advance.i28.i
  %i2.i24.i = phi i64 [ %next.i29.i, %advance.i28.i ], [ %i.i, %tail.i ]
  %p.i25.i = getelementptr i8, ptr %n.val, i64 %i2.i24.i
  %c.i26.i = load i8, ptr %p.i25.i, align 1
  %slash.i27.i = icmp eq i8 %c.i26.i, 47
  br i1 %slash.i27.i, label %segment_end.exit32.i, label %advance.i28.i

advance.i28.i:                                    ; preds = %read.i23.i
  %next.i29.i = add i64 %i2.i24.i, 1
  %end.i30.i = icmp eq i64 %next.i29.i, %n.val1
  br i1 %end.i30.i, label %segment_end.exit32.i, label %read.i23.i

segment_end.exit32.i:                             ; preds = %advance.i28.i, %read.i23.i
  %i.lcssa.i31.i = phi i64 [ %i2.i24.i, %read.i23.i ], [ %n.val1, %advance.i28.i ]
  %isempty.i = icmp eq i64 %i.i, %i.lcssa.i31.i
  %len.i33.i = sub i64 %i.lcssa.i31.i, %i.i
  %one.i34.i = icmp eq i64 %len.i33.i, 1
  br i1 %one.i34.i, label %check.i36.i, label %dot_segment.exit40.i

check.i36.i:                                      ; preds = %segment_end.exit32.i
  %p.i37.i = getelementptr i8, ptr %n.val, i64 %i.i
  %c.i38.i = load i8, ptr %p.i37.i, align 1
  %yes.i39.i = icmp eq i8 %c.i38.i, 46
  br label %dot_segment.exit40.i

dot_segment.exit40.i:                             ; preds = %check.i36.i, %segment_end.exit32.i
  %common.ret.op.i35.i = phi i1 [ %yes.i39.i, %check.i36.i ], [ false, %segment_end.exit32.i ]
  %skip.i = or i1 %isempty.i, %common.ret.op.i35.i
  br i1 %skip.i, label %tail.i, label %path_error

checked.i:                                        ; preds = %tail.i
  br i1 %nonnormal.i, label %path_error, label %nulbyte.i

nulscan.i:                                        ; preds = %nulbyte.i
  %jnext.i = add i64 %j8.i, 1
  %jdone.i = icmp eq i64 %jnext.i, %n.val1
  br i1 %jdone.i, label %copy.i, label %nulbyte.i

nulbyte.i:                                        ; preds = %checked.i, %nulscan.i
  %j8.i = phi i64 [ %jnext.i, %nulscan.i ], [ 0, %checked.i ]
  %jp.i = getelementptr i8, ptr %n.val, i64 %j8.i
  %jc.i = load i8, ptr %jp.i, align 1
  %nul.i = icmp eq i8 %jc.i, 0
  br i1 %nul.i, label %nul_error, label %nulscan.i

copy.i:                                           ; preds = %nulscan.i
  %2 = add i64 %n.val1, -9223372036854775791
  %large.i.i = icmp ult i64 %2, -9223372036854775792
  br i1 %large.i.i, label %oom.i.i, label %allocate.i.i

allocate.i.i:                                     ; preds = %copy.i
  %size.i.i = add nsw i64 %n.val1, 17
  %header.i.i = tail call ptr @malloc(i64 %size.i.i)
  %null.i.i = icmp eq ptr %header.i.i, null
  br i1 %null.i.i, label %oom.i.i, label %apply

oom.i.i:                                          ; preds = %allocate.i.i, %copy.i
  tail call fastcc void @print(ptr nonnull @msg_oom, ptr null, ptr null, ptr null)
  tail call void @exit(i32 1) #14
  unreachable

apply:                                            ; preds = %allocate.i.i
  %old.i.i = load ptr, ptr @arena, align 8
  store ptr %old.i.i, ptr %header.i.i, align 8
  store ptr %header.i.i, ptr @arena, align 8
  %data.i.i = getelementptr i8, ptr %header.i.i, i64 16
  %.not.not.i = icmp ne i64 %n.val1, -1
  %3 = zext i1 %.not.not.i to i64
  %4 = getelementptr i8, ptr %data.i.i, i64 %n.val1
  tail call void @llvm.memset.p0.i64(ptr align 1 %4, i8 0, i64 %3, i1 false)
  tail call void @llvm.memcpy.p0.p0.i64(ptr align 1 %data.i.i, ptr nonnull readonly align 1 %n.val, i64 %n.val1, i1 false)
  %cl.i = tail call i64 @strlen(ptr noundef nonnull readonly dereferenceable(1) %context)
  %nl.i = tail call i64 @strlen(ptr noundef nonnull readonly dereferenceable(1) %data.i.i)
  %sum.i = add i64 %nl.i, %cl.i
  %size.i = add i64 %sum.i, 2
  %large.i.i3 = icmp ugt i64 %size.i, 9223372036854775791
  br i1 %large.i.i3, label %oom.i.i12, label %allocate.i.i4

allocate.i.i4:                                    ; preds = %apply
  %size.i.i5 = add nsw i64 %sum.i, 18
  %header.i.i6 = tail call ptr @malloc(i64 %size.i.i5)
  %null.i.i7 = icmp eq ptr %header.i.i6, null
  br i1 %null.i.i7, label %oom.i.i12, label %join.exit

oom.i.i12:                                        ; preds = %allocate.i.i4, %apply
  tail call fastcc void @print(ptr nonnull @msg_oom, ptr null, ptr null, ptr null)
  tail call void @exit(i32 1) #14
  unreachable

join.exit:                                        ; preds = %allocate.i.i4
  store ptr %header.i.i, ptr %header.i.i6, align 8
  store ptr %header.i.i6, ptr @arena, align 8
  %data.i.i10 = getelementptr i8, ptr %header.i.i6, i64 16
  tail call void @llvm.memset.p0.i64(ptr align 1 %data.i.i10, i8 0, i64 %size.i, i1 false)
  tail call void @llvm.memcpy.p0.p0.i64(ptr align 1 %data.i.i10, ptr nonnull readonly align 1 %context, i64 %cl.i, i1 false)
  %slash.i = getelementptr i8, ptr %data.i.i10, i64 %cl.i
  store i8 47, ptr %slash.i, align 1
  %tail.i11 = getelementptr i8, ptr %slash.i, i64 1
  tail call void @llvm.memcpy.p0.p0.i64(ptr align 1 %tail.i11, ptr nonnull readonly align 1 %data.i.i, i64 %nl.i, i1 false)
  %5 = tail call i32 @unlink(ptr nonnull %data.i.i)
  %tag = load i32, ptr %n121, align 4
  switch i32 %tag, label %value_error [
    i32 1, label %directory
    i32 2, label %file
    i32 3, label %array
  ]

directory:                                        ; preds = %join.exit
  %made = tail call i32 @mkdir(ptr nonnull %data.i.i, i32 511)
  %failed.not = icmp eq i32 %made, 0
  br i1 %failed.not, label %enter, label %mkdir_errno

mkdir_errno:                                      ; preds = %directory
  %errno = tail call i32 @last_errno()
  %exists = icmp eq i32 %errno, 17
  br i1 %exists, label %enter, label %mkdir_error

enter:                                            ; preds = %mkdir_errno, %directory
  %entered = tail call i32 @chdir(ptr nonnull %data.i.i)
  %enterfailed.not = icmp eq i32 %entered, 0
  br i1 %enterfailed.not, label %recurse, label %enter_error

recurse:                                          ; preds = %enter
  %okdir = tail call fastcc i1 @run_object(ptr %n121, ptr %data.i.i10)
  br i1 %okdir, label %up, label %common.ret

up:                                               ; preds = %recurse
  %back = tail call i32 @chdir(ptr nonnull @parent)
  %upfailed.not = icmp eq i32 %back, 0
  br i1 %upfailed.not, label %advance, label %up_error

file:                                             ; preds = %join.exit
  %dp = getelementptr i8, ptr %n121, i64 8
  %lp = getelementptr i8, ptr %n121, i64 16
  %data = load ptr, ptr %dp, align 8
  %len = load i64, ptr %lp, align 4
  %okfile = tail call fastcc i1 @write_file(ptr nonnull %data.i.i, ptr %data, i64 %len, i1 false, ptr %data.i.i10)
  br i1 %okfile, label %advance, label %common.ret

array:                                            ; preds = %join.exit
  %6 = getelementptr i8, ptr %n121, i64 24
  %n.val2 = load ptr, ptr %6, align 8
  %empty.i13 = icmp eq ptr %n.val2, null
  br i1 %empty.i13, label %shape_error.i, label %second.i14

second.i14:                                       ; preds = %array
  %anp.i = getelementptr i8, ptr %n.val2, i64 32
  %b.i = load ptr, ptr %anp.i, align 8
  %single.i = icmp eq ptr %b.i, null
  br i1 %single.i, label %shape_error.i, label %shape.i

shape.i:                                          ; preds = %second.i14
  %bnp.i = getelementptr i8, ptr %b.i, i64 32
  %extra.i = load ptr, ptr %bnp.i, align 8
  %third.i = icmp ne ptr %extra.i, null
  %at.i = load i32, ptr %n.val2, align 4
  %bt.i = load i32, ptr %b.i, align 4
  %as.i = icmp ne i32 %at.i, 2
  %bs.i = icmp ne i32 %bt.i, 2
  %strings.not.i = or i1 %as.i, %bs.i
  %badshape.i = or i1 %third.i, %strings.not.i
  br i1 %badshape.i, label %shape_error.i, label %kind.i

kind.i:                                           ; preds = %shape.i
  %adp.i = getelementptr i8, ptr %n.val2, i64 8
  %alp.i = getelementptr i8, ptr %n.val2, i64 16
  %kinddata.i = load ptr, ptr %adp.i, align 8
  %kindlen.i = load i64, ptr %alp.i, align 4
  %bdp.i = getelementptr i8, ptr %b.i, i64 8
  %blp.i = getelementptr i8, ptr %b.i, i64 16
  %payload.i = load ptr, ptr %bdp.i, align 8
  %len.i = load i64, ptr %blp.i, align 4
  switch i64 %kindlen.i, label %kind_error.i [
    i64 4, label %linkcheck.i
    i64 6, label %scriptcheck.i
  ]

linkcheck.i:                                      ; preds = %kind.i
  %linkcmp.i = tail call i32 @memcmp(ptr noundef nonnull dereferenceable(4) %kinddata.i, ptr noundef nonnull dereferenceable(4) @word_link, i64 4)
  %islink.i = icmp eq i32 %linkcmp.i, 0
  br i1 %islink.i, label %link_nul.i, label %kind_error.i

scriptcheck.i:                                    ; preds = %kind.i
  %scriptcmp.i = tail call i32 @memcmp(ptr noundef nonnull dereferenceable(6) %kinddata.i, ptr noundef nonnull dereferenceable(6) @word_script, i64 6)
  %isscript.i = icmp eq i32 %scriptcmp.i, 0
  br i1 %isscript.i, label %run_array.exit, label %kind_error.i

link_nul.i:                                       ; preds = %linkcheck.i
  %clen.i = tail call i64 @strlen(ptr noundef nonnull dereferenceable(1) %payload.i)
  %nul.not.i = icmp eq i64 %clen.i, %len.i
  br i1 %nul.not.i, label %link.i, label %nul_error.i

link.i:                                           ; preds = %link_nul.i
  %created.i = tail call i32 @symlink(ptr nonnull %payload.i, ptr nonnull %data.i.i)
  %error.not.i = icmp eq i32 %created.i, 0
  br i1 %error.not.i, label %advance, label %link_error.i

shape_error.i:                                    ; preds = %shape.i, %second.i14, %array
  %stream.i.i.i = load ptr, ptr @errstream, align 8
  %closed.i.i.i = icmp eq ptr %stream.i.i.i, null
  br i1 %closed.i.i.i, label %common.ret, label %write.i.i.i

write.i.i.i:                                      ; preds = %shape_error.i
  %7 = tail call i32 (ptr, ptr, ...) @fprintf(ptr nonnull %stream.i.i.i, ptr nonnull readonly @msg_array, ptr %data.i.i10, ptr null, ptr null)
  br label %common.ret

kind_error.i:                                     ; preds = %scriptcheck.i, %linkcheck.i, %kind.i
  %stream.i.i1.i = load ptr, ptr @errstream, align 8
  %closed.i.i2.i = icmp eq ptr %stream.i.i1.i, null
  br i1 %closed.i.i2.i, label %common.ret, label %write.i.i3.i

write.i.i3.i:                                     ; preds = %kind_error.i
  %8 = tail call i32 (ptr, ptr, ...) @fprintf(ptr nonnull %stream.i.i1.i, ptr nonnull readonly @msg_kind, ptr %data.i.i10, ptr null, ptr null)
  br label %common.ret

nul_error.i:                                      ; preds = %link_nul.i
  %stream.i.i5.i = load ptr, ptr @errstream, align 8
  %closed.i.i6.i = icmp eq ptr %stream.i.i5.i, null
  br i1 %closed.i.i6.i, label %common.ret, label %write.i.i7.i

write.i.i7.i:                                     ; preds = %nul_error.i
  %9 = tail call i32 (ptr, ptr, ...) @fprintf(ptr nonnull %stream.i.i5.i, ptr nonnull readonly @msg_nul, ptr %data.i.i10, ptr null, ptr null)
  br label %common.ret

link_error.i:                                     ; preds = %link.i
  tail call fastcc void @io_error(ptr nonnull @action_link, ptr %data.i.i10)
  br label %common.ret

run_array.exit:                                   ; preds = %scriptcheck.i
  %ok.i = tail call fastcc i1 @write_file(ptr nonnull %data.i.i, ptr %payload.i, i64 %len.i, i1 true, ptr %data.i.i10)
  br i1 %ok.i, label %advance, label %common.ret

advance:                                          ; preds = %link.i, %run_array.exit, %file, %up
  %np = getelementptr i8, ptr %n121, i64 32
  %n = load ptr, ptr %np, align 8
  %end = icmp eq ptr %n, null
  br i1 %end, label %common.ret, label %validate

common.ret:                                       ; preds = %advance, %run_array.exit, %file, %recurse, %entry, %write.i.i7.i, %nul_error.i, %write.i.i3.i, %kind_error.i, %write.i.i.i, %shape_error.i, %link_error.i, %write.i.i33, %up_error, %write.i.i27, %enter_error, %write.i.i22, %mkdir_error, %write.i.i18, %value_error, %write.i.i, %nul_error, %write.i, %path_error
  %end78 = phi i1 [ false, %write.i.i7.i ], [ false, %nul_error.i ], [ false, %write.i.i3.i ], [ false, %kind_error.i ], [ false, %write.i.i.i ], [ false, %shape_error.i ], [ false, %link_error.i ], [ false, %write.i.i33 ], [ false, %up_error ], [ false, %write.i.i27 ], [ false, %enter_error ], [ false, %write.i.i22 ], [ false, %mkdir_error ], [ false, %write.i.i18 ], [ false, %value_error ], [ false, %write.i.i ], [ false, %nul_error ], [ false, %write.i ], [ false, %path_error ], [ true, %entry ], [ true, %advance ], [ false, %run_array.exit ], [ false, %file ], [ false, %recurse ]
  ret i1 %end78

path_error:                                       ; preds = %validate, %checked.i, %dot_segment.exit40.i, %dot_segment.exit.i, %rootloop.i
  %10 = phi ptr [ @msg_multiple, %dot_segment.exit.i ], [ @msg_component, %rootloop.i ], [ @msg_multiple, %dot_segment.exit40.i ], [ @msg_multiple, %validate ], [ @msg_component, %checked.i ]
  %stream.i = load ptr, ptr @errstream, align 8
  %closed.i = icmp eq ptr %stream.i, null
  br i1 %closed.i, label %common.ret, label %write.i

write.i:                                          ; preds = %path_error
  %11 = tail call i32 (ptr, ptr, ...) @fprintf(ptr nonnull %stream.i, ptr nonnull readonly %10, ptr %n.val, ptr %context, ptr null)
  br label %common.ret

nul_error:                                        ; preds = %nulbyte.i
  %stream.i.i = load ptr, ptr @errstream, align 8
  %closed.i.i = icmp eq ptr %stream.i.i, null
  br i1 %closed.i.i, label %common.ret, label %write.i.i

write.i.i:                                        ; preds = %nul_error
  %12 = tail call i32 (ptr, ptr, ...) @fprintf(ptr nonnull %stream.i.i, ptr nonnull readonly @msg_nul, ptr %context, ptr null, ptr null)
  br label %common.ret

value_error:                                      ; preds = %join.exit
  %stream.i.i16 = load ptr, ptr @errstream, align 8
  %closed.i.i17 = icmp eq ptr %stream.i.i16, null
  br i1 %closed.i.i17, label %common.ret, label %write.i.i18

write.i.i18:                                      ; preds = %value_error
  %13 = tail call i32 (ptr, ptr, ...) @fprintf(ptr nonnull %stream.i.i16, ptr nonnull readonly @msg_value, ptr %data.i.i10, ptr null, ptr null)
  br label %common.ret

mkdir_error:                                      ; preds = %mkdir_errno
  %e.i = tail call i32 @last_errno()
  %reason.i = tail call ptr @strerror(i32 %e.i)
  %stream.i.i20 = load ptr, ptr @errstream, align 8
  %closed.i.i21 = icmp eq ptr %stream.i.i20, null
  br i1 %closed.i.i21, label %common.ret, label %write.i.i22

write.i.i22:                                      ; preds = %mkdir_error
  %14 = tail call i32 (ptr, ptr, ...) @fprintf(ptr nonnull %stream.i.i20, ptr nonnull @msg_io, ptr nonnull @action_dir, ptr %data.i.i10, ptr %reason.i)
  br label %common.ret

enter_error:                                      ; preds = %enter
  %e.i23 = tail call i32 @last_errno()
  %reason.i24 = tail call ptr @strerror(i32 %e.i23)
  %stream.i.i25 = load ptr, ptr @errstream, align 8
  %closed.i.i26 = icmp eq ptr %stream.i.i25, null
  br i1 %closed.i.i26, label %common.ret, label %write.i.i27

write.i.i27:                                      ; preds = %enter_error
  %15 = tail call i32 (ptr, ptr, ...) @fprintf(ptr nonnull %stream.i.i25, ptr nonnull @msg_io, ptr nonnull @action_enter, ptr %data.i.i10, ptr %reason.i24)
  br label %common.ret

up_error:                                         ; preds = %up
  %e.i29 = tail call i32 @last_errno()
  %reason.i30 = tail call ptr @strerror(i32 %e.i29)
  %stream.i.i31 = load ptr, ptr @errstream, align 8
  %closed.i.i32 = icmp eq ptr %stream.i.i31, null
  br i1 %closed.i.i32, label %common.ret, label %write.i.i33

write.i.i33:                                      ; preds = %up_error
  %16 = tail call i32 (ptr, ptr, ...) @fprintf(ptr nonnull %stream.i.i31, ptr nonnull @msg_io, ptr nonnull @action_up, ptr %data.i.i10, ptr %reason.i30)
  br label %common.ret
}

define range(i32 0, 2) i32 @main(i32 %argc, ptr readnone captures(none) %argv) local_unnamed_addr {
entry:
  %stderr = tail call ptr @fdopen(i32 2, ptr nonnull @mode_write)
  store ptr %stderr, ptr @errstream, align 8
  %badargs.not = icmp eq i32 %argc, 1
  br i1 %badargs.not, label %input, label %usage

common.ret:                                       ; preds = %write.i, %usage, %release.exit
  %common.ret.op = phi i32 [ %result, %release.exit ], [ 1, %usage ], [ 1, %write.i ]
  ret i32 %common.ret.op

usage:                                            ; preds = %entry
  %closed.i = icmp eq ptr %stderr, null
  br i1 %closed.i, label %common.ret, label %write.i

write.i:                                          ; preds = %usage
  %0 = tail call i32 (ptr, ptr, ...) @fprintf(ptr nonnull %stderr, ptr nonnull @msg_usage, ptr null, ptr null, ptr null)
  br label %common.ret

input:                                            ; preds = %entry
  %stdin = tail call ptr @fdopen(i32 0, ptr nonnull @mode_read)
  %nostdin = icmp eq ptr %stdin, null
  br i1 %nostdin, label %read_error, label %init

init:                                             ; preds = %input
  %chunk = alloca [4096 x i8], align 16
  br label %read

read:                                             ; preds = %reserve.exit, %init
  %data.i.i3040 = phi ptr [ %data, %reserve.exit ], [ null, %init ]
  %cap.i37 = phi i64 [ %cap.i36, %reserve.exit ], [ 0, %init ]
  %len.i27 = phi i64 [ %need0.i, %reserve.exit ], [ 0, %init ]
  %count = call i64 @fread(ptr nonnull %chunk, i64 1, i64 4096, ptr nonnull %stdin)
  %need0.i = add i64 %count, %len.i27
  %need.i = add i64 %need0.i, 1
  %wrap.not.i = icmp ugt i64 %need.i, %len.i27
  br i1 %wrap.not.i, label %check.i, label %overflow.i

check.i:                                          ; preds = %read
  %enough.not.i = icmp ugt i64 %need.i, %cap.i37
  br i1 %enough.not.i, label %grow.i, label %reserve.exit

grow.i:                                           ; preds = %check.i
  %double.i = shl i64 %cap.i37, 1
  %base.i = tail call i64 @llvm.umax.i64(i64 %double.i, i64 %need.i)
  %newcap.i = tail call i64 @llvm.umax.i64(i64 %base.i, i64 64)
  %large.i.i = icmp ugt i64 %base.i, 9223372036854775791
  br i1 %large.i.i, label %oom.i.i, label %allocate.i.i

allocate.i.i:                                     ; preds = %grow.i
  %size.i.i = add nuw nsw i64 %newcap.i, 16
  %header.i.i = tail call ptr @malloc(i64 %size.i.i)
  %null.i.i = icmp eq ptr %header.i.i, null
  br i1 %null.i.i, label %oom.i.i, label %alloc.exit.i

oom.i.i:                                          ; preds = %allocate.i.i, %grow.i
  tail call fastcc void @print(ptr nonnull @msg_oom, ptr null, ptr null, ptr null)
  tail call void @exit(i32 1) #14
  unreachable

alloc.exit.i:                                     ; preds = %allocate.i.i
  %old.i.i = load ptr, ptr @arena, align 8
  store ptr %old.i.i, ptr %header.i.i, align 8
  store ptr %header.i.i, ptr @arena, align 8
  %data.i.i30 = getelementptr i8, ptr %header.i.i, i64 16
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 1 dereferenceable(1) %data.i.i30, i8 0, i64 %newcap.i, i1 false)
  %empty.i = icmp eq i64 %len.i27, 0
  br i1 %empty.i, label %reserve.exit, label %copy.i

copy.i:                                           ; preds = %alloc.exit.i
  tail call void @llvm.memcpy.p0.p0.i64(ptr nonnull align 1 %data.i.i30, ptr align 1 %data.i.i3040, i64 %len.i27, i1 false)
  br label %reserve.exit

overflow.i:                                       ; preds = %read
  tail call fastcc void @alloc(i64 -1)
  unreachable

reserve.exit:                                     ; preds = %alloc.exit.i, %copy.i, %check.i
  %data = phi ptr [ %data.i.i3040, %check.i ], [ %data.i.i30, %copy.i ], [ %data.i.i30, %alloc.exit.i ]
  %cap.i36 = phi i64 [ %cap.i37, %check.i ], [ %newcap.i, %copy.i ], [ %newcap.i, %alloc.exit.i ]
  %out.i29 = getelementptr i8, ptr %data, i64 %len.i27
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %out.i29, ptr nonnull readonly align 16 %chunk, i64 %count, i1 false)
  %end.i = getelementptr i8, ptr %out.i29, i64 %count
  store i8 0, ptr %end.i, align 1
  %full = icmp eq i64 %count, 4096
  br i1 %full, label %read, label %read_end

read_end:                                         ; preds = %reserve.exit
  %error = tail call i32 @ferror(ptr nonnull %stdin)
  %failed.not = icmp eq i32 %error, 0
  br i1 %failed.not, label %utf8, label %read_error

utf8:                                             ; preds = %read_end
  %1 = tail call i32 @fclose(ptr nonnull %stdin)
  %done7.i = icmp eq i64 %need0.i, 0
  br i1 %done7.i, label %parse, label %lead.i

lead.i:                                           ; preds = %utf8, %loop.backedge.i
  %i8.i = phi i64 [ %i.be.i, %loop.backedge.i ], [ 0, %utf8 ]
  %p.i = getelementptr i8, ptr %data, i64 %i8.i
  %raw.i = load i8, ptr %p.i, align 1
  %c.i = zext i8 %raw.i to i32
  %isascii.i = icmp sgt i8 %raw.i, -1
  br i1 %isascii.i, label %ascii.i, label %multi.i

ascii.i:                                          ; preds = %lead.i
  %nextascii.i = add i64 %i8.i, 1
  br label %loop.backedge.i

loop.backedge.i:                                  ; preds = %checkcp.i, %ascii.i
  %i.be.i = phi i64 [ %nextascii.i, %ascii.i ], [ %nextmulti.i, %checkcp.i ]
  %done.i = icmp eq i64 %i.be.i, %need0.i
  br i1 %done.i, label %parse, label %lead.i

multi.i:                                          ; preds = %lead.i
  %2 = add nsw i8 %raw.i, 62
  %is2.i = icmp ult i8 %2, 30
  %3 = and i8 %raw.i, -16
  %is3.i = icmp eq i8 %3, -32
  %4 = add nsw i8 %raw.i, 16
  %is4.i = icmp ult i8 %4, 5
  %5 = or i1 %is3.i, %is4.i
  %ok.i = or i1 %is2.i, %5
  br i1 %ok.i, label %bounds.i, label %utf8_error

bounds.i:                                         ; preds = %multi.i
  %n34.i = select i1 %is3.i, i64 3, i64 4
  %n.i = select i1 %is2.i, i64 2, i64 %n34.i
  %minimum34.i = select i1 %is3.i, i32 2048, i32 65536
  %minimum.i = select i1 %is2.i, i32 128, i32 %minimum34.i
  %remaining.i = sub i64 %need0.i, %i8.i
  %fits.not.i = icmp ugt i64 %n.i, %remaining.i
  br i1 %fits.not.i, label %utf8_error, label %contbyte.preheader.i

contbyte.preheader.i:                             ; preds = %bounds.i
  %mask34.i = select i1 %is3.i, i32 15, i32 7
  %mask.i = select i1 %is2.i, i32 31, i32 %mask34.i
  %initial.i = and i32 %mask.i, %c.i
  br label %contbyte.i

contbyte.i:                                       ; preds = %consume.i, %contbyte.preheader.i
  %cp6.i = phi i32 [ %newcp.i, %consume.i ], [ %initial.i, %contbyte.preheader.i ]
  %j5.i = phi i64 [ %jnext.i, %consume.i ], [ 1, %contbyte.preheader.i ]
  %q.i = getelementptr i8, ptr %p.i, i64 %j5.i
  %r.i = load i8, ptr %q.i, align 1
  %v.i = zext i8 %r.i to i32
  %high.i = and i32 %v.i, 192
  %valid.i = icmp eq i32 %high.i, 128
  br i1 %valid.i, label %consume.i, label %utf8_error

consume.i:                                        ; preds = %contbyte.i
  %shift.i = shl i32 %cp6.i, 6
  %low.i = and i32 %v.i, 63
  %newcp.i = or disjoint i32 %low.i, %shift.i
  %jnext.i = add i64 %j5.i, 1
  %finished.i = icmp eq i64 %jnext.i, %n.i
  br i1 %finished.i, label %checkcp.i, label %contbyte.i

checkcp.i:                                        ; preds = %consume.i
  %overlong.i = icmp ult i32 %newcp.i, %minimum.i
  %toolarge.i = icmp ugt i32 %shift.i, 1114111
  %6 = and i32 %cp6.i, 67108832
  %surrogate.i = icmp eq i32 %6, 864
  %bad0.i = or i1 %toolarge.i, %overlong.i
  %bad.i = or i1 %surrogate.i, %bad0.i
  %nextmulti.i = add i64 %n.i, %i8.i
  br i1 %bad.i, label %utf8_error, label %loop.backedge.i

parse:                                            ; preds = %loop.backedge.i, %utf8
  %p = alloca %Parser, align 8
  %7 = getelementptr inbounds nuw i8, ptr %p, i64 16
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(16) %7, i8 0, i64 16, i1 false)
  store ptr %data, ptr %p, align 8
  %plp = getelementptr inbounds nuw i8, ptr %p, i64 8
  store i64 %need0.i, ptr %plp, align 8
  %root = call fastcc ptr @parse_value(ptr %p)
  %badparse = icmp eq ptr %root, null
  br i1 %badparse, label %parse_error, label %trailing

trailing:                                         ; preds = %parse
  %ip.i.i = getelementptr inbounds nuw i8, ptr %p, i64 16
  %len.i.i = load i64, ptr %plp, align 8
  %ip.i.promoted.i = load i64, ptr %ip.i.i, align 8
  %end.not.i6.i = icmp ult i64 %ip.i.promoted.i, %len.i.i
  br i1 %end.not.i6.i, label %peek.exit.lr.ph.i, label %top

peek.exit.lr.ph.i:                                ; preds = %trailing
  %data.i.i = load ptr, ptr %p, align 8
  br label %peek.exit.i

peek.exit.i:                                      ; preds = %take.exit.i, %peek.exit.lr.ph.i
  %next.i.i45 = phi i64 [ %ip.i.promoted.i, %peek.exit.lr.ph.i ], [ %next.i.i, %take.exit.i ]
  %q.i.i = getelementptr i8, ptr %data.i.i, i64 %next.i.i45
  %v.i.i = load i8, ptr %q.i.i, align 1
  switch i8 %v.i.i, label %parse_error [
    i8 32, label %take.exit.i
    i8 9, label %take.exit.i
    i8 10, label %take.exit.i
    i8 13, label %take.exit.i
  ]

take.exit.i:                                      ; preds = %peek.exit.i, %peek.exit.i, %peek.exit.i, %peek.exit.i
  %next.i.i = add nuw i64 %next.i.i45, 1
  %end.not.i.i = icmp ult i64 %next.i.i, %len.i.i
  br i1 %end.not.i.i, label %peek.exit.i, label %top

top:                                              ; preds = %take.exit.i, %trailing
  %tag = load i32, ptr %root, align 4
  %object = icmp eq i32 %tag, 1
  br i1 %object, label %run, label %top_error

run:                                              ; preds = %top
  %ok = tail call fastcc i1 @run_object(ptr %root, ptr nonnull @dot)
  %not.ok = xor i1 %ok, true
  %status = zext i1 %not.ok to i32
  br label %cleanup

read_error:                                       ; preds = %read_end, %input
  %stream.i4 = load ptr, ptr @errstream, align 8
  %closed.i5 = icmp eq ptr %stream.i4, null
  br i1 %closed.i5, label %cleanup, label %write.i6

write.i6:                                         ; preds = %read_error
  %8 = tail call i32 (ptr, ptr, ...) @fprintf(ptr nonnull %stream.i4, ptr nonnull @msg_read, ptr null, ptr null, ptr null)
  br label %cleanup

utf8_error:                                       ; preds = %checkcp.i, %bounds.i, %multi.i, %contbyte.i
  %stream.i9 = load ptr, ptr @errstream, align 8
  %closed.i10 = icmp eq ptr %stream.i9, null
  br i1 %closed.i10, label %cleanup, label %write.i11

write.i11:                                        ; preds = %utf8_error
  %9 = tail call i32 (ptr, ptr, ...) @fprintf(ptr nonnull %stream.i9, ptr nonnull @msg_utf8, ptr null, ptr null, ptr null)
  br label %cleanup

parse_error:                                      ; preds = %peek.exit.i, %parse
  %stream.i14 = load ptr, ptr @errstream, align 8
  %closed.i15 = icmp eq ptr %stream.i14, null
  br i1 %closed.i15, label %cleanup, label %write.i16

write.i16:                                        ; preds = %parse_error
  %10 = tail call i32 (ptr, ptr, ...) @fprintf(ptr nonnull %stream.i14, ptr nonnull @msg_parse, ptr null, ptr null, ptr null)
  br label %cleanup

top_error:                                        ; preds = %top
  %stream.i19 = load ptr, ptr @errstream, align 8
  %closed.i20 = icmp eq ptr %stream.i19, null
  br i1 %closed.i20, label %cleanup, label %write.i21

write.i21:                                        ; preds = %top_error
  %11 = tail call i32 (ptr, ptr, ...) @fprintf(ptr nonnull %stream.i19, ptr nonnull @msg_top, ptr null, ptr null, ptr null)
  br label %cleanup

cleanup:                                          ; preds = %write.i21, %top_error, %write.i16, %parse_error, %write.i11, %utf8_error, %write.i6, %read_error, %run
  %result = phi i32 [ %status, %run ], [ 1, %read_error ], [ 1, %write.i6 ], [ 1, %utf8_error ], [ 1, %write.i11 ], [ 1, %parse_error ], [ 1, %write.i16 ], [ 1, %top_error ], [ 1, %write.i21 ]
  %head.i = load ptr, ptr @arena, align 8
  %done1.i = icmp eq ptr %head.i, null
  br i1 %done1.i, label %release.exit, label %body.i

body.i:                                           ; preds = %cleanup, %body.i
  %p2.i = phi ptr [ %next.i, %body.i ], [ %head.i, %cleanup ]
  %next.i = load ptr, ptr %p2.i, align 8
  tail call void @free(ptr nonnull %p2.i)
  %done.i24 = icmp eq ptr %next.i, null
  br i1 %done.i24, label %release.exit, label %body.i

release.exit:                                     ; preds = %body.i, %cleanup
  store ptr null, ptr @arena, align 8
  br label %common.ret
}

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i64(ptr writeonly captures(none), i8, i64, i1 immarg) #10

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.umax.i64(i64, i64) #11

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p0.p0.i64(ptr noalias writeonly captures(none), ptr noalias readonly captures(none), i64, i1 immarg) #12

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare double @llvm.fabs.f64(double) #11

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.umin.i64(i64, i64) #11

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(i64 immarg, ptr captures(none)) #13

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr captures(none)) #13

attributes #0 = { mustprogress nofree nounwind willreturn allockind("alloc,uninitialized") allocsize(0) memory(inaccessiblemem: readwrite) "alloc-family"="malloc" }
attributes #1 = { mustprogress nounwind willreturn allockind("free") memory(argmem: readwrite, inaccessiblemem: readwrite) "alloc-family"="malloc" }
attributes #2 = { mustprogress nocallback nofree nounwind willreturn memory(argmem: read) }
attributes #3 = { nofree nounwind }
attributes #4 = { nofree nounwind memory(read) }
attributes #5 = { mustprogress nocallback nofree nounwind willreturn }
attributes #6 = { nofree noreturn }
attributes #7 = { nofree }
attributes #8 = { mustprogress nofree norecurse nosync nounwind willreturn memory(read, argmem: readwrite, inaccessiblemem: none) }
attributes #9 = { nofree nounwind memory(readwrite, inaccessiblemem: none) }
attributes #10 = { nocallback nofree nounwind willreturn memory(argmem: write) }
attributes #11 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #12 = { nocallback nofree nounwind willreturn memory(argmem: readwrite) }
attributes #13 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #14 = { cold }
