.text
.globl __x86.get_pc_thunk.bx
.hidden __x86.get_pc_thunk.bx
.type __x86.get_pc_thunk.bx, @function
__x86.get_pc_thunk.bx:
    movl (%esp), %ebx
    ret

.globl strdup
.type strdup, @function
strdup:
    pushl %ebp
    movl %esp, %ebp
    pushl %ebx
    pushl %esi
    pushl %edi
    subl $12, %esp

    call __x86.get_pc_thunk.bx
    addl $_GLOBAL_OFFSET_TABLE_, %ebx

    movl 8(%ebp), %esi
    testl %esi, %esi
    jnz .Lhas_str

    xorl %edi, %edi
    jmp .Ldo_alloc

.Lhas_str:
    movl %esi, (%esp)
    call strlen@PLT
    movl %eax, %edi

.Ldo_alloc:
    leal 1(%edi), %eax
    movl %eax, (%esp)
    call malloc@PLT
    testl %eax, %eax
    jz .Ldone

    testl %edi, %edi
    jz .Lzero_term

    movl %edi, 8(%esp)
    movl %esi, 4(%esp)
    movl %eax, (%esp)
    movl %eax, %esi           # save return ptr
    call memcpy@PLT
    movl %esi, %eax

.Lzero_term:
    movb $0, (%eax, %edi)

.Ldone:
    addl $12, %esp
    popl %edi
    popl %esi
    popl %ebx
    popl %ebp
    ret
.size strdup, .-strdup

.globl strlen
.type strlen, @function
strlen:
    pushl %ebp
    movl %esp, %ebp
    pushl %edi

    movl 8(%ebp), %edi
    testl %edi, %edi
    jz .Lstrlen_null

    xorl %eax, %eax
    movl $-1, %ecx
    cld
    repne scasb
    notl %ecx
    decl %ecx
    movl %ecx, %eax
    jmp .Lstrlen_done

.Lstrlen_null:
    xorl %eax, %eax

.Lstrlen_done:
    popl %edi
    popl %ebp
    ret
.size strlen, .-strlen
