; json2dir — handwritten LLVM IR, using only the system C/POSIX library.
; Parser and filesystem implementation; no generated C/Rust runtime.
source_filename = "json2dir.ll"

; Node: tag (object=1, string=2, array=3, scalar=4), bytes, byte length,
; first child, next sibling, object key bytes, object key length.
%Node = type { i32, ptr, i64, ptr, ptr, ptr, i64 }
%Parser = type { ptr, i64, i64, i32 }
%Buffer = type { ptr, i64, i64 }
@arena = internal global ptr null
@errstream = internal global ptr null

declare ptr @malloc(i64)
declare void @free(ptr)
declare ptr @memcpy(ptr, ptr, i64)
declare ptr @memset(ptr, i32, i64)
declare i32 @memcmp(ptr, ptr, i64)
declare i64 @strlen(ptr)
declare ptr @fdopen(i32, ptr)
declare ptr @fopen(ptr, ptr)
declare i64 @fread(ptr, i64, i64, ptr)
declare i64 @fwrite(ptr, i64, i64, ptr)
declare i32 @ferror(ptr)
declare i32 @fclose(ptr)
declare i32 @fprintf(ptr, ptr, ...)
declare i32 @unlink(ptr)
declare i32 @mkdir(ptr, i32)
declare i32 @chdir(ptr)
declare i32 @symlink(ptr, ptr)
declare i32 @chmod(ptr, i32)
declare double @strtod(ptr, ptr)
declare void @exit(i32) noreturn
; These two small ABI adapters are also handwritten IR (src/platform-*.ll).
declare i32 @file_mode(ptr)
declare i32 @last_errno()
declare ptr @strerror(i32)

; Constants are appended below; all string lengths count bytes, including NUL.

; Diagnostics may be unavailable if the caller closed stderr. Extra pointer
; arguments are harmless for formats with fewer than three substitutions.
define internal void @print(ptr %format, ptr %a, ptr %b, ptr %c) {
entry:
  %stream = load ptr, ptr @errstream
  %closed = icmp eq ptr %stream, null
  br i1 %closed, label %end, label %write
write:
  call i32 (ptr, ptr, ...) @fprintf(ptr %stream, ptr %format, ptr %a, ptr %b, ptr %c)
  br label %end
end:
  ret void
}

; Every allocation belongs to an arena. Parse errors and duplicate keys need
; no special ownership paths; main releases the entire arena on every exit.
define internal ptr @alloc(i64 %n) {
entry:
  %large = icmp ugt i64 %n, 9223372036854775791
  br i1 %large, label %oom, label %allocate
allocate:
  %size = add i64 %n, 16
  %header = call ptr @malloc(i64 %size)
  %null = icmp eq ptr %header, null
  br i1 %null, label %oom, label %ready
ready:
  %old = load ptr, ptr @arena
  store ptr %old, ptr %header
  store ptr %header, ptr @arena
  %data = getelementptr i8, ptr %header, i64 16
  call ptr @memset(ptr %data, i32 0, i64 %n)
  ret ptr %data
oom:
  call void @print(ptr @msg_oom, ptr null, ptr null, ptr null)
  call void @exit(i32 1)
  unreachable
}

define internal void @release() {
entry:
  %head = load ptr, ptr @arena
  br label %loop
loop:
  %p = phi ptr [ %head, %entry ], [ %next, %body ]
  %done = icmp eq ptr %p, null
  br i1 %done, label %end, label %body
body:
  %next = load ptr, ptr %p
  call void @free(ptr %p)
  br label %loop
end:
  store ptr null, ptr @arena
  ret void
}

; Reserve room for an append and a trailing NUL; growth is geometric.
define internal ptr @reserve(ptr %b, i64 %extra) {
entry:
  %lp = getelementptr %Buffer, ptr %b, i32 0, i32 1
  %cp = getelementptr %Buffer, ptr %b, i32 0, i32 2
  %len = load i64, ptr %lp
  %cap = load i64, ptr %cp
  %need0 = add i64 %len, %extra
  %need = add i64 %need0, 1
  %wrap = icmp ule i64 %need, %len
  br i1 %wrap, label %overflow, label %check
check:
  %enough = icmp ule i64 %need, %cap
  br i1 %enough, label %end, label %grow
grow:
  %double = mul i64 %cap, 2
  %small = icmp ult i64 %double, 64
  %base = select i1 %small, i64 64, i64 %double
  %short = icmp ult i64 %base, %need
  %newcap = select i1 %short, i64 %need, i64 %base
  %new = call ptr @alloc(i64 %newcap)
  %old = load ptr, ptr %b
  %empty = icmp eq i64 %len, 0
  br i1 %empty, label %save, label %copy
copy:
  call ptr @memcpy(ptr %new, ptr %old, i64 %len)
  br label %save
save:
  store ptr %new, ptr %b
  store i64 %newcap, ptr %cp
  br label %end
end:
  %data = load ptr, ptr %b
  %out = getelementptr i8, ptr %data, i64 %len
  ret ptr %out
overflow:
  call ptr @alloc(i64 -1)
  unreachable
}

define internal void @append(ptr %b, ptr %data, i64 %n) {
entry:
  %out = call ptr @reserve(ptr %b, i64 %n)
  call ptr @memcpy(ptr %out, ptr %data, i64 %n)
  %lp = getelementptr %Buffer, ptr %b, i32 0, i32 1
  %len = load i64, ptr %lp
  %newlen = add i64 %len, %n
  store i64 %newlen, ptr %lp
  %end = getelementptr i8, ptr %out, i64 %n
  store i8 0, ptr %end
  ret void
}

define internal void @byte(ptr %b, i32 %c) {
entry:
  %tmp = alloca i8
  %v = trunc i32 %c to i8
  store i8 %v, ptr %tmp
  call void @append(ptr %b, ptr %tmp, i64 1)
  ret void
}

; Validate the entire input, including portions outside JSON strings.
define internal i1 @valid_utf8(ptr %data, i64 %len) {
entry:
  br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %nextascii, %ascii ], [ %nextmulti, %checkcp ]
  %done = icmp eq i64 %i, %len
  br i1 %done, label %yes, label %lead
lead:
  %p = getelementptr i8, ptr %data, i64 %i
  %raw = load i8, ptr %p
  %c = zext i8 %raw to i32
  %isascii = icmp ult i32 %c, 128
  br i1 %isascii, label %ascii, label %multi
ascii:
  %nextascii = add i64 %i, 1
  br label %loop
multi:
  %ge2 = icmp uge i32 %c, 194
  %le2 = icmp ule i32 %c, 223
  %is2 = and i1 %ge2, %le2
  %ge3 = icmp uge i32 %c, 224
  %le3 = icmp ule i32 %c, 239
  %is3 = and i1 %ge3, %le3
  %ge4 = icmp uge i32 %c, 240
  %le4 = icmp ule i32 %c, 244
  %is4 = and i1 %ge4, %le4
  %ok23 = or i1 %is2, %is3
  %ok = or i1 %ok23, %is4
  br i1 %ok, label %bounds, label %no
bounds:
  %n34 = select i1 %is3, i64 3, i64 4
  %n = select i1 %is2, i64 2, i64 %n34
  %minimum34 = select i1 %is3, i32 2048, i32 65536
  %minimum = select i1 %is2, i32 128, i32 %minimum34
  %mask34 = select i1 %is3, i32 15, i32 7
  %mask = select i1 %is2, i32 31, i32 %mask34
  %initial = and i32 %c, %mask
  %remaining = sub i64 %len, %i
  %fits = icmp ule i64 %n, %remaining
  br i1 %fits, label %continuation, label %no
continuation:
  %j = phi i64 [ 1, %bounds ], [ %jnext, %consume ]
  %cp = phi i32 [ %initial, %bounds ], [ %newcp, %consume ]
  %finished = icmp eq i64 %j, %n
  br i1 %finished, label %checkcp, label %contbyte
contbyte:
  %idx = add i64 %i, %j
  %q = getelementptr i8, ptr %data, i64 %idx
  %r = load i8, ptr %q
  %v = zext i8 %r to i32
  %high = and i32 %v, 192
  %valid = icmp eq i32 %high, 128
  br i1 %valid, label %consume, label %no
consume:
  %shift = shl i32 %cp, 6
  %low = and i32 %v, 63
  %newcp = or i32 %shift, %low
  %jnext = add i64 %j, 1
  br label %continuation
checkcp:
  %overlong = icmp ult i32 %cp, %minimum
  %toolarge = icmp ugt i32 %cp, 1114111
  %s1 = icmp uge i32 %cp, 55296
  %s2 = icmp ule i32 %cp, 57343
  %surrogate = and i1 %s1, %s2
  %bad0 = or i1 %overlong, %toolarge
  %bad = or i1 %bad0, %surrogate
  %nextmulti = add i64 %i, %n
  br i1 %bad, label %no, label %loop
yes:
  ret i1 true
no:
  ret i1 false
}

define internal i32 @peek(ptr %p) {
entry:
  %lp = getelementptr %Parser, ptr %p, i32 0, i32 1
  %ip = getelementptr %Parser, ptr %p, i32 0, i32 2
  %len = load i64, ptr %lp
  %i = load i64, ptr %ip
  %end = icmp uge i64 %i, %len
  br i1 %end, label %eof, label %read
read:
  %data = load ptr, ptr %p
  %q = getelementptr i8, ptr %data, i64 %i
  %v = load i8, ptr %q
  %c = zext i8 %v to i32
  ret i32 %c
eof:
  ret i32 -1
}

define internal i32 @take(ptr %p) {
entry:
  %c = call i32 @peek(ptr %p)
  %eof = icmp eq i32 %c, -1
  br i1 %eof, label %end, label %advance
advance:
  %ip = getelementptr %Parser, ptr %p, i32 0, i32 2
  %i = load i64, ptr %ip
  %next = add i64 %i, 1
  store i64 %next, ptr %ip
  br label %end
end:
  ret i32 %c
}

define internal i32 @skip_space(ptr %p) {
entry:
  br label %loop
loop:
  %c = call i32 @peek(ptr %p)
  switch i32 %c, label %end [ i32 32, label %skip
    i32 9, label %skip
    i32 10, label %skip
    i32 13, label %skip ]
skip:
  call i32 @take(ptr %p)
  br label %loop
end:
  ret i32 %c
}

define internal ptr @node(i32 %tag) {
entry:
  %n = call ptr @alloc(i64 56)
  store i32 %tag, ptr %n
  ret ptr %n
}

define internal i32 @hex4(ptr %p) {
entry:
  br label %loop
loop:
  %i = phi i32 [ 0, %entry ], [ %next, %consume ]
  %v = phi i32 [ 0, %entry ], [ %newv, %consume ]
  %done = icmp eq i32 %i, 4
  br i1 %done, label %end, label %read
read:
  %c = call i32 @take(ptr %p)
  %d = sub i32 %c, 48
  %digit = icmp ult i32 %d, 10
  %lower = or i32 %c, 32
  %a = sub i32 %lower, 97
  %letter = icmp ult i32 %a, 6
  %ok = or i1 %digit, %letter
  br i1 %ok, label %consume, label %bad
consume:
  %av = add i32 %a, 10
  %h = select i1 %digit, i32 %d, i32 %av
  %shift = shl i32 %v, 4
  %newv = or i32 %shift, %h
  %next = add i32 %i, 1
  br label %loop
end:
  ret i32 %v
bad:
  ret i32 -1
}

; Append a Unicode scalar as UTF-8 (surrogates were handled by parse_string).
define internal void @unicode(ptr %b, i32 %cp) {
entry:
  %one = icmp ult i32 %cp, 128
  br i1 %one, label %single, label %multi
single:
  call void @byte(ptr %b, i32 %cp)
  ret void
multi:
  %two = icmp ult i32 %cp, 2048
  br i1 %two, label %lead2, label %large
lead2:
  %a2 = lshr i32 %cp, 6
  %b2 = or i32 %a2, 192
  call void @byte(ptr %b, i32 %b2)
  br label %last
large:
  %three = icmp ult i32 %cp, 65536
  br i1 %three, label %lead3, label %lead4
lead3:
  %a3 = lshr i32 %cp, 12
  %b3 = or i32 %a3, 224
  call void @byte(ptr %b, i32 %b3)
  br label %middle
lead4:
  %a4 = lshr i32 %cp, 18
  %b4 = or i32 %a4, 240
  call void @byte(ptr %b, i32 %b4)
  %s4 = lshr i32 %cp, 12
  %m4 = and i32 %s4, 63
  %c4 = or i32 %m4, 128
  call void @byte(ptr %b, i32 %c4)
  br label %middle
middle:
  %s = lshr i32 %cp, 6
  %m = and i32 %s, 63
  %c = or i32 %m, 128
  call void @byte(ptr %b, i32 %c)
  br label %last
last:
  %l = and i32 %cp, 63
  %v = or i32 %l, 128
  call void @byte(ptr %b, i32 %v)
  ret void
}

define internal ptr @parse_string(ptr %p) {
entry:
  %b = alloca %Buffer
  store %Buffer zeroinitializer, ptr %b
  %quote = call i32 @take(ptr %p)
  %start = icmp eq i32 %quote, 34
  br i1 %start, label %loop, label %bad
loop:
  %c = call i32 @take(ptr %p)
  switch i32 %c, label %raw [ i32 34, label %end
    i32 92, label %escape ]
raw:
  %control = icmp ult i32 %c, 32
  %eof = icmp eq i32 %c, -1
  %invalid = or i1 %control, %eof
  br i1 %invalid, label %bad, label %appendraw
appendraw:
  call void @byte(ptr %b, i32 %c)
  br label %loop
escape:
  %e = call i32 @take(ptr %p)
  switch i32 %e, label %bad [ i32 34, label %simple
    i32 92, label %simple
    i32 47, label %simple
    i32 98, label %backspace
    i32 102, label %formfeed
    i32 110, label %newline
    i32 114, label %return
    i32 116, label %tab
    i32 117, label %hex ]
simple:
  call void @byte(ptr %b, i32 %e)
  br label %loop
backspace:
  call void @byte(ptr %b, i32 8)
  br label %loop
formfeed:
  call void @byte(ptr %b, i32 12)
  br label %loop
newline:
  call void @byte(ptr %b, i32 10)
  br label %loop
return:
  call void @byte(ptr %b, i32 13)
  br label %loop
tab:
  call void @byte(ptr %b, i32 9)
  br label %loop
hex:
  %h = call i32 @hex4(ptr %p)
  %error = icmp eq i32 %h, -1
  br i1 %error, label %bad, label %surrogate
surrogate:
  %low = icmp uge i32 %h, 56320
  %lowend = icmp ule i32 %h, 57343
  %islow = and i1 %low, %lowend
  br i1 %islow, label %bad, label %highcheck
highcheck:
  %high = icmp uge i32 %h, 55296
  %highend = icmp ule i32 %h, 56319
  %ishigh = and i1 %high, %highend
  br i1 %ishigh, label %pair, label %emit
pair:
  %slash = call i32 @take(ptr %p)
  %u = call i32 @take(ptr %p)
  %isslash = icmp eq i32 %slash, 92
  %isu = icmp eq i32 %u, 117
  %prefix = and i1 %isslash, %isu
  br i1 %prefix, label %pairhex, label %bad
pairhex:
  %lo = call i32 @hex4(ptr %p)
  %offset = sub i32 %lo, 56320
  %valid = icmp ult i32 %offset, 1024
  br i1 %valid, label %combine, label %bad
combine:
  %hi = sub i32 %h, 55296
  %shift = shl i32 %hi, 10
  %combined = add i32 %shift, %offset
  %full = add i32 %combined, 65536
  br label %emit
emit:
  %cp = phi i32 [ %h, %highcheck ], [ %full, %combine ]
  call void @unicode(ptr %b, i32 %cp)
  br label %loop
end:
  call ptr @reserve(ptr %b, i64 0)
  %n = call ptr @node(i32 2)
  %data = load ptr, ptr %b
  %lp = getelementptr %Buffer, ptr %b, i32 0, i32 1
  %len = load i64, ptr %lp
  %dp = getelementptr %Node, ptr %n, i32 0, i32 1
  %np = getelementptr %Node, ptr %n, i32 0, i32 2
  store ptr %data, ptr %dp
  store i64 %len, ptr %np
  ret ptr %n
bad:
  ret ptr null
}

; Scalar syntax is still validated, even though scalars cannot create entries.
define internal i1 @literal(ptr %p, ptr %word, i64 %len) {
entry:
  br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %next, %read ]
  %done = icmp eq i64 %i, %len
  br i1 %done, label %yes, label %read
read:
  %q = getelementptr i8, ptr %word, i64 %i
  %b = load i8, ptr %q
  %v = zext i8 %b to i32
  %c = call i32 @take(ptr %p)
  %same = icmp eq i32 %v, %c
  %next = add i64 %i, 1
  br i1 %same, label %loop, label %no
yes:
  ret i1 true
no:
  ret i1 false
}

define internal i1 @is_digit(i32 %c) {
entry:
  %d = sub i32 %c, 48
  %yes = icmp ult i32 %d, 10
  ret i1 %yes
}

define internal i64 @digits(ptr %p) {
entry:
  br label %loop
loop:
  %count = phi i64 [ 0, %entry ], [ %next, %consume ]
  %c = call i32 @peek(ptr %p)
  %digit = call i1 @is_digit(i32 %c)
  br i1 %digit, label %consume, label %end
consume:
  call i32 @take(ptr %p)
  %next = add i64 %count, 1
  br label %loop
end:
  ret i64 %count
}

define internal ptr @number(ptr %p) {
entry:
  %ip = getelementptr %Parser, ptr %p, i32 0, i32 2
  %start = load i64, ptr %ip
  %first = call i32 @peek(ptr %p)
  %negative = icmp eq i32 %first, 45
  br i1 %negative, label %minus, label %integer
minus:
  call i32 @take(ptr %p)
  br label %integer
integer:
  %c = call i32 @peek(ptr %p)
  %zero = icmp eq i32 %c, 48
  br i1 %zero, label %zero_int, label %nonzero
zero_int:
  call i32 @take(ptr %p)
  %afterzero = call i32 @peek(ptr %p)
  %leadingzero = call i1 @is_digit(i32 %afterzero)
  br i1 %leadingzero, label %bad, label %fraction
nonzero:
  %d = sub i32 %c, 49
  %valid = icmp ult i32 %d, 9
  br i1 %valid, label %intdigits, label %bad
intdigits:
  call i64 @digits(ptr %p)
  br label %fraction
fraction:
  %dot = call i32 @peek(ptr %p)
  %hasfrac = icmp eq i32 %dot, 46
  br i1 %hasfrac, label %fracdigits, label %exponent
fracdigits:
  call i32 @take(ptr %p)
  %nfrac = call i64 @digits(ptr %p)
  %emptyfrac = icmp eq i64 %nfrac, 0
  br i1 %emptyfrac, label %bad, label %exponent
exponent:
  %e = call i32 @peek(ptr %p)
  %lower = or i32 %e, 32
  %hasexp = icmp eq i32 %lower, 101
  br i1 %hasexp, label %expsign, label %finite
expsign:
  call i32 @take(ptr %p)
  %sign = call i32 @peek(ptr %p)
  %plus = icmp eq i32 %sign, 43
  %neg = icmp eq i32 %sign, 45
  %signed = or i1 %plus, %neg
  br i1 %signed, label %consume_sign, label %expdigits
consume_sign:
  call i32 @take(ptr %p)
  br label %expdigits
expdigits:
  %nexp = call i64 @digits(ptr %p)
  %emptyexp = icmp eq i64 %nexp, 0
  br i1 %emptyexp, label %bad, label %finite
finite:
  %end = load i64, ptr %ip
  %len = sub i64 %end, %start
  %size = add i64 %len, 1
  %text = call ptr @alloc(i64 %size)
  %data = load ptr, ptr %p
  %src = getelementptr i8, ptr %data, i64 %start
  call ptr @memcpy(ptr %text, ptr %src, i64 %len)
  %value = call double @strtod(ptr %text, ptr null)
  %hi = fcmp ole double %value, 0x7FEFFFFFFFFFFFFF
  %lo = fcmp oge double %value, 0xFFEFFFFFFFFFFFFF
  %ok = and i1 %hi, %lo
  br i1 %ok, label %yes, label %bad
yes:
  %node = call ptr @node(i32 4)
  ret ptr %node
bad:
  ret ptr null
}

; Bytewise ordering also gives Unicode scalar ordering for valid UTF-8 keys.
define internal i32 @compare(ptr %a, ptr %b) {
entry:
  %akp = getelementptr %Node, ptr %a, i32 0, i32 5
  %bkp = getelementptr %Node, ptr %b, i32 0, i32 5
  %alp = getelementptr %Node, ptr %a, i32 0, i32 6
  %blp = getelementptr %Node, ptr %b, i32 0, i32 6
  %ak = load ptr, ptr %akp
  %bk = load ptr, ptr %bkp
  %al = load i64, ptr %alp
  %bl = load i64, ptr %blp
  %less = icmp ult i64 %al, %bl
  %len = select i1 %less, i64 %al, i64 %bl
  %cmp = call i32 @memcmp(ptr %ak, ptr %bk, i64 %len)
  %equal = icmp eq i32 %cmp, 0
  %same = icmp eq i64 %al, %bl
  %ne = select i1 %less, i32 -1, i32 1
  %len_cmp = select i1 %same, i32 0, i32 %ne
  %result = select i1 %equal, i32 %len_cmp, i32 %cmp
  ret i32 %result
}

; Stable linked-list mergesort: O(n log n), no per-entry sort allocations.
define internal ptr @merge(ptr %left, ptr %right) {
entry:
  %head = alloca ptr
  store ptr null, ptr %head
  br label %loop
loop:
  %a = phi ptr [ %left, %entry ], [ %anext, %attach ]
  %b = phi ptr [ %right, %entry ], [ %bnext, %attach ]
  %slot = phi ptr [ %head, %entry ], [ %nextslot, %attach ]
  %anull = icmp eq ptr %a, null
  br i1 %anull, label %rest_b, label %check_b
check_b:
  %bnull = icmp eq ptr %b, null
  br i1 %bnull, label %rest_a, label %choose
choose:
  %cmp = call i32 @compare(ptr %a, ptr %b)
  %first = icmp sle i32 %cmp, 0
  %chosen = select i1 %first, ptr %a, ptr %b
  %np = getelementptr %Node, ptr %chosen, i32 0, i32 4
  %next = load ptr, ptr %np
  %anext = select i1 %first, ptr %next, ptr %a
  %bnext = select i1 %first, ptr %b, ptr %next
  br label %attach
attach:
  store ptr %chosen, ptr %slot
  %nextslot = getelementptr %Node, ptr %chosen, i32 0, i32 4
  br label %loop
rest_b:
  store ptr %b, ptr %slot
  br label %end
rest_a:
  store ptr %a, ptr %slot
  br label %end
end:
  %result = load ptr, ptr %head
  ret ptr %result
}

define internal ptr @sort(ptr %head) {
entry:
  %nil = icmp eq ptr %head, null
  br i1 %nil, label %base, label %check
check:
  %np = getelementptr %Node, ptr %head, i32 0, i32 4
  %next = load ptr, ptr %np
  %single = icmp eq ptr %next, null
  br i1 %single, label %base, label %split
split:
  %slow = phi ptr [ %head, %check ], [ %snext, %advance ]
  %fast = phi ptr [ %next, %check ], [ %fnext2, %advance ]
  %empty = icmp eq ptr %fast, null
  br i1 %empty, label %recurse, label %faststep
faststep:
  %fnp = getelementptr %Node, ptr %fast, i32 0, i32 4
  %fnext = load ptr, ptr %fnp
  %last = icmp eq ptr %fnext, null
  br i1 %last, label %recurse, label %advance
advance:
  %snp = getelementptr %Node, ptr %slow, i32 0, i32 4
  %snext = load ptr, ptr %snp
  %fn2p = getelementptr %Node, ptr %fnext, i32 0, i32 4
  %fnext2 = load ptr, ptr %fn2p
  br label %split
recurse:
  %sp = getelementptr %Node, ptr %slow, i32 0, i32 4
  %right = load ptr, ptr %sp
  store ptr null, ptr %sp
  %a = call ptr @sort(ptr %head)
  %b = call ptr @sort(ptr %right)
  %result = call ptr @merge(ptr %a, ptr %b)
  ret ptr %result
base:
  ret ptr %head
}

define internal ptr @dedup(ptr %head) {
entry:
  br label %loop
loop:
  %n = phi ptr [ %head, %entry ], [ %n, %duplicate ], [ %next, %different ]
  %nil = icmp eq ptr %n, null
  br i1 %nil, label %end, label %check
check:
  %np = getelementptr %Node, ptr %n, i32 0, i32 4
  %next = load ptr, ptr %np
  %last = icmp eq ptr %next, null
  br i1 %last, label %end, label %compare
compare:
  %cmp = call i32 @compare(ptr %n, ptr %next)
  %same = icmp eq i32 %cmp, 0
  br i1 %same, label %duplicate, label %different
duplicate:
  %nnp = getelementptr %Node, ptr %next, i32 0, i32 4
  %after = load ptr, ptr %nnp
  store ptr %after, ptr %np
  br label %loop
different:
  br label %loop
end:
  ret ptr %head
}

; Collections count toward serde_json's default recursion limit (128).
; Object children are prepended, so stable sorting keeps the last duplicate.
define internal ptr @collection(ptr %p, i1 %object) {
entry:
  %dp = getelementptr %Parser, ptr %p, i32 0, i32 3
  %depth = load i32, ptr %dp
  %newdepth = add i32 %depth, 1
  %deep = icmp uge i32 %newdepth, 128
  br i1 %deep, label %bad, label %begin
begin:
  store i32 %newdepth, ptr %dp
  call i32 @take(ptr %p)
  %tag = select i1 %object, i32 1, i32 3
  %close = select i1 %object, i32 125, i32 93
  %n = call ptr @node(i32 %tag)
  %headp = getelementptr %Node, ptr %n, i32 0, i32 3
  %tail = alloca ptr
  store ptr %headp, ptr %tail
  %first = call i32 @skip_space(ptr %p)
  %empty = icmp eq i32 %first, %close
  br i1 %empty, label %finish, label %entry_value
entry_value:
  br i1 %object, label %key, label %value
key:
  %k = call ptr @parse_string(ptr %p)
  %nokey = icmp eq ptr %k, null
  br i1 %nokey, label %bad, label %colon
colon:
  call i32 @skip_space(ptr %p)
  %sep = call i32 @take(ptr %p)
  %oksep = icmp eq i32 %sep, 58
  br i1 %oksep, label %value, label %bad
value:
  %keynode = phi ptr [ null, %entry_value ], [ %k, %colon ]
  %v = call ptr @parse_value(ptr %p)
  %novalue = icmp eq ptr %v, null
  br i1 %novalue, label %bad, label %attach
attach:
  %np = getelementptr %Node, ptr %v, i32 0, i32 4
  br i1 %object, label %attach_object, label %attach_array
attach_object:
  %kd = getelementptr %Node, ptr %keynode, i32 0, i32 1
  %kl = getelementptr %Node, ptr %keynode, i32 0, i32 2
  %keydata = load ptr, ptr %kd
  %keylen = load i64, ptr %kl
  %vkp = getelementptr %Node, ptr %v, i32 0, i32 5
  %vklp = getelementptr %Node, ptr %v, i32 0, i32 6
  store ptr %keydata, ptr %vkp
  store i64 %keylen, ptr %vklp
  %old = load ptr, ptr %headp
  store ptr %old, ptr %np
  store ptr %v, ptr %headp
  br label %separator
attach_array:
  %slot = load ptr, ptr %tail
  store ptr %v, ptr %slot
  store ptr %np, ptr %tail
  br label %separator
separator:
  %c = call i32 @skip_space(ptr %p)
  %isend = icmp eq i32 %c, %close
  br i1 %isend, label %finish, label %comma
comma:
  %iscomma = icmp eq i32 %c, 44
  br i1 %iscomma, label %next_value, label %bad
next_value:
  call i32 @take(ptr %p)
  call i32 @skip_space(ptr %p)
  br label %entry_value
finish:
  call i32 @take(ptr %p)
  store i32 %depth, ptr %dp
  br i1 %object, label %order, label %end
order:
  %head = load ptr, ptr %headp
  %sorted = call ptr @sort(ptr %head)
  %unique = call ptr @dedup(ptr %sorted)
  store ptr %unique, ptr %headp
  br label %end
end:
  ret ptr %n
bad:
  ret ptr null
}

define internal ptr @parse_value(ptr %p) {
entry:
  %c = call i32 @skip_space(ptr %p)
  switch i32 %c, label %number [ i32 123, label %object
    i32 91, label %array
    i32 34, label %string
    i32 116, label %true
    i32 102, label %false
    i32 110, label %null ]
object:
  %o = call ptr @collection(ptr %p, i1 true)
  ret ptr %o
array:
  %a = call ptr @collection(ptr %p, i1 false)
  ret ptr %a
string:
  %s = call ptr @parse_string(ptr %p)
  ret ptr %s
true:
  %t = call i1 @literal(ptr %p, ptr @word_true, i64 4)
  br i1 %t, label %scalar, label %bad
false:
  %f = call i1 @literal(ptr %p, ptr @word_false, i64 5)
  br i1 %f, label %scalar, label %bad
null:
  %z = call i1 @literal(ptr %p, ptr @word_null, i64 4)
  br i1 %z, label %scalar, label %bad
scalar:
  %n = call ptr @node(i32 4)
  ret ptr %n
number:
  %num = call ptr @number(ptr %p)
  ret ptr %num
bad:
  ret ptr null
}

; Find the end of a slash-delimited path segment.
define internal i64 @segment_end(ptr %data, i64 %start, i64 %len) {
entry:
  br label %loop
loop:
  %i = phi i64 [ %start, %entry ], [ %next, %advance ]
  %end = icmp eq i64 %i, %len
  br i1 %end, label %done, label %read
read:
  %p = getelementptr i8, ptr %data, i64 %i
  %c = load i8, ptr %p
  %slash = icmp eq i8 %c, 47
  br i1 %slash, label %done, label %advance
advance:
  %next = add i64 %i, 1
  br label %loop
done:
  ret i64 %i
}

define internal i1 @dot_segment(ptr %data, i64 %start, i64 %end) {
entry:
  %len = sub i64 %end, %start
  %one = icmp eq i64 %len, 1
  br i1 %one, label %check, label %no
check:
  %p = getelementptr i8, ptr %data, i64 %start
  %c = load i8, ptr %p
  %yes = icmp eq i8 %c, 46
  ret i1 %yes
no:
  ret i1 false
}

; Return 0 for one normal component, 1 for multiple/empty components,
; 2 for '.', '..', or root, 3 for an embedded NUL. Ignore trailing '/' and
; '/.' during validation, as Unix std::path::components does. Filesystem
; calls still receive the original spelling, as they do in the Rust version.
define internal i32 @component(ptr %n, ptr %out) {
entry:
  %kp = getelementptr %Node, ptr %n, i32 0, i32 5
  %lp = getelementptr %Node, ptr %n, i32 0, i32 6
  %key = load ptr, ptr %kp
  %len = load i64, ptr %lp
  %empty = icmp eq i64 %len, 0
  br i1 %empty, label %multiple, label %first
first:
  %c = load i8, ptr %key
  %root = icmp eq i8 %c, 47
  br i1 %root, label %rootcheck, label %normal
rootcheck:
  ; Root is a component of its own; subsequent non-dot segments add components.
  br label %rootloop
rootloop:
  %ri = phi i64 [ 0, %rootcheck ], [ %rnext, %rootadvance ]
  %rdone = icmp uge i64 %ri, %len
  br i1 %rdone, label %special, label %rootsegment
rootsegment:
  %re = call i64 @segment_end(ptr %key, i64 %ri, i64 %len)
  %rempty = icmp eq i64 %ri, %re
  %rdot = call i1 @dot_segment(ptr %key, i64 %ri, i64 %re)
  %rskip = or i1 %rempty, %rdot
  br i1 %rskip, label %rootadvance, label %multiple
rootadvance:
  %rnext = add i64 %re, 1
  br label %rootloop
normal:
  %end = call i64 @segment_end(ptr %key, i64 0, i64 %len)
  %dot = call i1 @dot_segment(ptr %key, i64 0, i64 %end)
  %two = icmp eq i64 %end, 2
  %firstdot = icmp eq i8 %c, 46
  %maybeparent = and i1 %two, %firstdot
  br i1 %maybeparent, label %parentcheck, label %tail_begin
parentcheck:
  %secondp = getelementptr i8, ptr %key, i64 1
  %second = load i8, ptr %secondp
  %parent = icmp eq i8 %second, 46
  br label %tail_begin
tail_begin:
  %isparent = phi i1 [ false, %normal ], [ %parent, %parentcheck ]
  %nonnormal = or i1 %dot, %isparent
  %start = add i64 %end, 1
  br label %tail
tail:
  %i = phi i64 [ %start, %tail_begin ], [ %next, %tailadvance ]
  %done = icmp uge i64 %i, %len
  br i1 %done, label %checked, label %tailsegment
tailsegment:
  %e = call i64 @segment_end(ptr %key, i64 %i, i64 %len)
  %isempty = icmp eq i64 %i, %e
  %isdot = call i1 @dot_segment(ptr %key, i64 %i, i64 %e)
  %skip = or i1 %isempty, %isdot
  br i1 %skip, label %tailadvance, label %multiple
tailadvance:
  %next = add i64 %e, 1
  br label %tail
checked:
  br i1 %nonnormal, label %special, label %nulscan
nulscan:
  %j = phi i64 [ 0, %checked ], [ %jnext, %nuladvance ]
  %jdone = icmp eq i64 %j, %len
  br i1 %jdone, label %copy, label %nulbyte
nulbyte:
  %jp = getelementptr i8, ptr %key, i64 %j
  %jc = load i8, ptr %jp
  %nul = icmp eq i8 %jc, 0
  br i1 %nul, label %nulerror, label %nuladvance
nuladvance:
  %jnext = add i64 %j, 1
  br label %nulscan
copy:
  %size = add i64 %len, 1
  %name = call ptr @alloc(i64 %size)
  call ptr @memcpy(ptr %name, ptr %key, i64 %len)
  store ptr %name, ptr %out
  ret i32 0
multiple:
  ret i32 1
special:
  ret i32 2
nulerror:
  ret i32 3
}

define internal ptr @join(ptr %context, ptr %name) {
entry:
  %cl = call i64 @strlen(ptr %context)
  %nl = call i64 @strlen(ptr %name)
  %sum = add i64 %cl, %nl
  %size = add i64 %sum, 2
  %path = call ptr @alloc(i64 %size)
  call ptr @memcpy(ptr %path, ptr %context, i64 %cl)
  %slash = getelementptr i8, ptr %path, i64 %cl
  store i8 47, ptr %slash
  %offset = add i64 %cl, 1
  %tail = getelementptr i8, ptr %path, i64 %offset
  call ptr @memcpy(ptr %tail, ptr %name, i64 %nl)
  ret ptr %path
}

define internal i1 @io_error(ptr %action, ptr %context) {
entry:
  %e = call i32 @last_errno()
  %reason = call ptr @strerror(i32 %e)
  call void @print(ptr @msg_io, ptr %action, ptr %context, ptr %reason)
  ret i1 false
}

define internal i1 @context_error(ptr %message, ptr %context) {
entry:
  call void @print(ptr %message, ptr %context, ptr null, ptr null)
  ret i1 false
}

; Write exact byte lengths, including embedded NULs in file contents. The
; stat ABI adapter retrieves the actual mode, preserving umask and existing
; permissions before OR-ing all three execute bits (0111).
define internal i1 @write_file(ptr %name, ptr %content, i64 %len, i1 %script, ptr %context) {
entry:
  %file = call ptr @fopen(ptr %name, ptr @mode_write)
  %failed = icmp eq ptr %file, null
  br i1 %failed, label %create_error, label %write
write:
  %written = call i64 @fwrite(ptr %content, i64 1, i64 %len, ptr %file)
  %short = icmp ne i64 %written, %len
  br i1 %short, label %write_error, label %flush
write_error:
  ; Report errno before fclose can change it.
  %werr = call i1 @io_error(ptr @action_write, ptr %context)
  call i32 @fclose(ptr %file)
  ret i1 false
flush:
  %closed = call i32 @fclose(ptr %file)
  %closefailed = icmp ne i32 %closed, 0
  br i1 %closefailed, label %create_error, label %executable
executable:
  br i1 %script, label %mode, label %yes
mode:
  %permissions = call i32 @file_mode(ptr %name)
  %statfailed = icmp slt i32 %permissions, 0
  br i1 %statfailed, label %chmod_error, label %chmod
chmod:
  %newmode = or i32 %permissions, 73
  %changed = call i32 @chmod(ptr %name, i32 %newmode)
  %chmodfailed = icmp ne i32 %changed, 0
  br i1 %chmodfailed, label %chmod_error, label %yes
yes:
  ret i1 true
create_error:
  %action = select i1 %script, ptr @action_script, ptr @action_file
  %err = call i1 @io_error(ptr %action, ptr %context)
  ret i1 false
chmod_error:
  %cerr = call i1 @io_error(ptr @action_chmod, ptr %context)
  ret i1 false
}

define internal i1 @run_array(ptr %n, ptr %name, ptr %context) {
entry:
  %cp = getelementptr %Node, ptr %n, i32 0, i32 3
  %a = load ptr, ptr %cp
  %empty = icmp eq ptr %a, null
  br i1 %empty, label %shape_error, label %second
second:
  %anp = getelementptr %Node, ptr %a, i32 0, i32 4
  %b = load ptr, ptr %anp
  %single = icmp eq ptr %b, null
  br i1 %single, label %shape_error, label %shape
shape:
  %bnp = getelementptr %Node, ptr %b, i32 0, i32 4
  %extra = load ptr, ptr %bnp
  %third = icmp ne ptr %extra, null
  %at = load i32, ptr %a
  %bt = load i32, ptr %b
  %as = icmp eq i32 %at, 2
  %bs = icmp eq i32 %bt, 2
  %strings = and i1 %as, %bs
  %badstrings = xor i1 %strings, true
  %badshape = or i1 %third, %badstrings
  br i1 %badshape, label %shape_error, label %kind
kind:
  %adp = getelementptr %Node, ptr %a, i32 0, i32 1
  %alp = getelementptr %Node, ptr %a, i32 0, i32 2
  %kinddata = load ptr, ptr %adp
  %kindlen = load i64, ptr %alp
  %bdp = getelementptr %Node, ptr %b, i32 0, i32 1
  %blp = getelementptr %Node, ptr %b, i32 0, i32 2
  %payload = load ptr, ptr %bdp
  %len = load i64, ptr %blp
  %four = icmp eq i64 %kindlen, 4
  br i1 %four, label %linkcheck, label %script_length
linkcheck:
  %linkcmp = call i32 @memcmp(ptr %kinddata, ptr @word_link, i64 4)
  %islink = icmp eq i32 %linkcmp, 0
  br i1 %islink, label %link_nul, label %kind_error
script_length:
  %six = icmp eq i64 %kindlen, 6
  br i1 %six, label %scriptcheck, label %kind_error
scriptcheck:
  %scriptcmp = call i32 @memcmp(ptr %kinddata, ptr @word_script, i64 6)
  %isscript = icmp eq i32 %scriptcmp, 0
  br i1 %isscript, label %script, label %kind_error
script:
  %ok = call i1 @write_file(ptr %name, ptr %payload, i64 %len, i1 true, ptr %context)
  ret i1 %ok
link_nul:
  %clen = call i64 @strlen(ptr %payload)
  %nul = icmp ne i64 %clen, %len
  br i1 %nul, label %nul_error, label %link
link:
  %created = call i32 @symlink(ptr %payload, ptr %name)
  %error = icmp ne i32 %created, 0
  br i1 %error, label %link_error, label %yes
yes:
  ret i1 true
shape_error:
  %se = call i1 @context_error(ptr @msg_array, ptr %context)
  ret i1 false
kind_error:
  %ke = call i1 @context_error(ptr @msg_kind, ptr %context)
  ret i1 false
nul_error:
  %ne = call i1 @context_error(ptr @msg_nul, ptr %context)
  ret i1 false
link_error:
  %le = call i1 @io_error(ptr @action_link, ptr %context)
  ret i1 false
}

; Match the original's overwrite semantics: unlink files/symlinks, reuse
; existing directories and leave unrelated entries within them untouched.
define internal i1 @run_object(ptr %object, ptr %context) {
entry:
  %cp = getelementptr %Node, ptr %object, i32 0, i32 3
  %head = load ptr, ptr %cp
  %nameout = alloca ptr
  br label %loop
loop:
  %n = phi ptr [ %head, %entry ], [ %next, %advance ]
  %end = icmp eq ptr %n, null
  br i1 %end, label %yes, label %validate
validate:
  %pathkind = call i32 @component(ptr %n, ptr %nameout)
  switch i32 %pathkind, label %path_error [ i32 0, label %apply
    i32 3, label %nul_error ]
apply:
  %name = load ptr, ptr %nameout
  %path = call ptr @join(ptr %context, ptr %name)
  call i32 @unlink(ptr %name)
  %tag = load i32, ptr %n
  switch i32 %tag, label %value_error [ i32 1, label %directory
    i32 2, label %file
    i32 3, label %array ]
directory:
  %made = call i32 @mkdir(ptr %name, i32 511)
  %failed = icmp ne i32 %made, 0
  br i1 %failed, label %mkdir_errno, label %enter
mkdir_errno:
  %errno = call i32 @last_errno()
  %exists = icmp eq i32 %errno, 17
  br i1 %exists, label %enter, label %mkdir_error
enter:
  %entered = call i32 @chdir(ptr %name)
  %enterfailed = icmp ne i32 %entered, 0
  br i1 %enterfailed, label %enter_error, label %recurse
recurse:
  %okdir = call i1 @run_object(ptr %n, ptr %path)
  br i1 %okdir, label %up, label %no
up:
  %back = call i32 @chdir(ptr @parent)
  %upfailed = icmp ne i32 %back, 0
  br i1 %upfailed, label %up_error, label %advance
file:
  %dp = getelementptr %Node, ptr %n, i32 0, i32 1
  %lp = getelementptr %Node, ptr %n, i32 0, i32 2
  %data = load ptr, ptr %dp
  %len = load i64, ptr %lp
  %okfile = call i1 @write_file(ptr %name, ptr %data, i64 %len, i1 false, ptr %path)
  br i1 %okfile, label %advance, label %no
array:
  %okarray = call i1 @run_array(ptr %n, ptr %name, ptr %path)
  br i1 %okarray, label %advance, label %no
advance:
  %np = getelementptr %Node, ptr %n, i32 0, i32 4
  %next = load ptr, ptr %np
  br label %loop
path_error:
  %kp = getelementptr %Node, ptr %n, i32 0, i32 5
  %key = load ptr, ptr %kp
  %regular = icmp eq i32 %pathkind, 1
  %msg = select i1 %regular, ptr @msg_multiple, ptr @msg_component
  call void @print(ptr %msg, ptr %key, ptr %context, ptr null)
  ret i1 false
nul_error:
  %ne = call i1 @context_error(ptr @msg_nul, ptr %context)
  ret i1 false
value_error:
  %ve = call i1 @context_error(ptr @msg_value, ptr %path)
  ret i1 false
mkdir_error:
  %me = call i1 @io_error(ptr @action_dir, ptr %path)
  ret i1 false
enter_error:
  %ee = call i1 @io_error(ptr @action_enter, ptr %path)
  ret i1 false
up_error:
  %ue = call i1 @io_error(ptr @action_up, ptr %path)
  ret i1 false
yes:
  ret i1 true
no:
  ret i1 false
}

define i32 @main(i32 %argc, ptr %argv) {
entry:
  %stderr = call ptr @fdopen(i32 2, ptr @mode_write)
  store ptr %stderr, ptr @errstream
  %badargs = icmp ne i32 %argc, 1
  br i1 %badargs, label %usage, label %input
usage:
  call void @print(ptr @msg_usage, ptr null, ptr null, ptr null)
  ret i32 1
input:
  %stdin = call ptr @fdopen(i32 0, ptr @mode_read)
  %nostdin = icmp eq ptr %stdin, null
  br i1 %nostdin, label %read_error, label %init
init:
  %b = alloca %Buffer
  store %Buffer zeroinitializer, ptr %b
  %chunk = alloca [4096 x i8], align 16
  br label %read
read:
  %count = call i64 @fread(ptr %chunk, i64 1, i64 4096, ptr %stdin)
  call void @append(ptr %b, ptr %chunk, i64 %count)
  %full = icmp eq i64 %count, 4096
  br i1 %full, label %read, label %read_end
read_end:
  %error = call i32 @ferror(ptr %stdin)
  %failed = icmp ne i32 %error, 0
  br i1 %failed, label %read_error, label %utf8
utf8:
  call i32 @fclose(ptr %stdin)
  %data = load ptr, ptr %b
  %lp = getelementptr %Buffer, ptr %b, i32 0, i32 1
  %len = load i64, ptr %lp
  %valid = call i1 @valid_utf8(ptr %data, i64 %len)
  br i1 %valid, label %parse, label %utf8_error
parse:
  %p = alloca %Parser
  store %Parser zeroinitializer, ptr %p
  store ptr %data, ptr %p
  %plp = getelementptr %Parser, ptr %p, i32 0, i32 1
  store i64 %len, ptr %plp
  %root = call ptr @parse_value(ptr %p)
  %badparse = icmp eq ptr %root, null
  br i1 %badparse, label %parse_error, label %trailing
trailing:
  %tail = call i32 @skip_space(ptr %p)
  %eof = icmp eq i32 %tail, -1
  br i1 %eof, label %top, label %parse_error
top:
  %tag = load i32, ptr %root
  %object = icmp eq i32 %tag, 1
  br i1 %object, label %run, label %top_error
run:
  %ok = call i1 @run_object(ptr %root, ptr @dot)
  %status = select i1 %ok, i32 0, i32 1
  br label %cleanup
read_error:
  call void @print(ptr @msg_read, ptr null, ptr null, ptr null)
  br label %failure
utf8_error:
  call void @print(ptr @msg_utf8, ptr null, ptr null, ptr null)
  br label %failure
parse_error:
  call void @print(ptr @msg_parse, ptr null, ptr null, ptr null)
  br label %failure
top_error:
  call void @print(ptr @msg_top, ptr null, ptr null, ptr null)
  br label %failure
failure:
  br label %cleanup
cleanup:
  %result = phi i32 [ %status, %run ], [ 1, %failure ]
  call void @release()
  ret i32 %result
}

; NUL-terminated UTF-8 constants.
@mode_read = private unnamed_addr constant [3 x i8] c"rb\00"
@mode_write = private unnamed_addr constant [3 x i8] c"wb\00"
@dot = private unnamed_addr constant [2 x i8] c".\00"
@parent = private unnamed_addr constant [3 x i8] c"..\00"
@word_true = private unnamed_addr constant [5 x i8] c"true\00"
@word_false = private unnamed_addr constant [6 x i8] c"false\00"
@word_null = private unnamed_addr constant [5 x i8] c"null\00"
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
