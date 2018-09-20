; vim: filetype=nasm
;
; hangman.asm: Boot sector hangman by xlq
;
; To run:
; nasm -o hangman hangman.asm
; qemu -fda hangman
;
; Or copy it onto the first sector of a real floppy.

org 0x7C00
stack equ 0x7B80       ; stack (grows downwards, of course)
lives equ 0x7B80       ; place to store number of lives
target_word equ 0x7B82 ; place to store target word
max_target_len equ 60  ; maximum length of target word
guessed equ 0x7BC0     ; bitmap - one bit per ASCII char 0..127
                       ; set if guessed

    cli

    ; set the stack pointer
    xor ax,ax
    mov ss,ax
    mov ds,ax
    mov es,ax
    mov sp,stack

    cld

say_hello:
    ; print welcome message
    mov si,.message
    call puts
    jmp read_guess

.message: db "===== Hangman! =====",13,10,0
newline: db 13,10,0
backspace: db 8,32,8,0

read_guess:
    mov si,.message
    call puts
    mov di,target_word
    ; read keyboard presses until enter is pressed
.loop:
    xor ah,ah
    int 0x16
    ; now al=character
    cmp al,8 ; backspace?
    je .backspace
    cmp al,13 ; enter?
    je .enter
    cmp di,(target_word+max_target_len)
    je .loop
    and al,0x7F
    mov [di],al
    inc di
    call putc
    jmp .loop
.backspace:
    cmp di,target_word
    je .loop
    dec di
    mov si,backspace
    call puts
    jmp .loop
.enter:
    mov [di],byte 0 ; null-terminate string
    call clear_line ; clear line to hide target
    mov [lives],word 10 ; reset lives counter
    ; clear guessed bitmap
    mov di,guessed
    mov cx,16
    xor al,al
    rep stosb
    mov [guessed+4],byte 1 ; space always revealed
    jmp guess

.message: db "Target: ",0
.message_end:

guess:
    mov si,.word_str
    call puts
    xor bp,bp
    mov ax,bp
    mov cx,bp
.print_word_loop:
    ; has this character been revealed?
    mov al,[target_word+bp]
    test al,al
    jz .end
    call split8
    mov bl,[guessed+bx]
    test bl,dl
    jz .not_revealed
.is_revealed:
    call putc
    inc bp
    jmp .print_word_loop
.not_revealed:
    inc cl
    mov al,'-'
    call putc
    inc bp
    jmp .print_word_loop
.end:
    mov si,.lives_str
    call puts
    mov ax,[lives]
    call putint
    test cl,cl ; neither putint nor puts clobbers cx
    jz you_win
    mov si,.guess_str
    call puts

    ; read a guess character from the keyboard
    xor ah,ah
    int 0x16
    and al,0x7F
    ; print it :)
    call putc

    ; already guessed?
    call split8
    mov cl,[guessed+bx]
    test cl,dl
    jnz .already_guessed
    or cl,dl
    mov [guessed+bx],cl

    ; deduct a life if this char is not in the word
    mov si,target_word
    mov dl,al
.loop:
    lodsb
    test al,al
    jz .fail
    cmp al,dl
    je .end2
    jmp .loop
.fail:
    ; dec life counter
    dec word [lives]
    jz you_die
.already_guessed:
.end2:
    call up_line
    call up_line
    jmp guess

.word_str: db "Word: ",0
.lives_str: db 13,10,"Lives: ",0
.guess_str: db 13,10,"Guess: ",0

you_die:
    mov si,die_str
    call puts
    jmp start_again
die_str: db 13,10,"You die.",13,10,0

you_win:
    mov si,win_str
    call puts
start_again:
    ; wait for any key
    xor ah,ah
    int 0x16
    ; clear 5 lines
    mov cl,5
.loop:
    call up_line
    loop .loop
    ; start again
    jmp say_hello

win_str: db 13,10,13,10,"You survive.",13,10,0

split8:
    ; IN: al=value
    ; OUT: bx=value/8 dx=1<<(value%8)
    ; all other registers unchanged
    push cx
    xor bx,bx
    mov bl,al
    shr bx,3
    mov cl,al
    and cl,7
    xor dx,dx
    inc dx
    shl dx,cl
    pop cx
    ret

up_line:
    ; move up to the previous line
    ; and clear it!
    pusha
    mov ah,3
    xor bh,bh
    int 0x10
    ; dh=row, dl=col
    test dh,dh
    jz .nodec
    dec dh
.nodec:
    xor dl,dl
    mov ah,2
    xor bh,bh
    pusha
    int 0x10
    ; print 80 spaces
    mov cx,80
    mov al,32
.loop:
    call putc
    loop .loop
    popa ; stacktastic!
    int 0x10
    popa
    ret

clear_line:
    ; print 80 backspaces, since printing backspaces
    ; doesn't un-line-wrap
    mov bl,80
.loop:
    mov si,backspace
    call puts
    dec bl
    jnz .loop
    ret

puts:
    ; si=string pointer
    lodsb
    test al,al
    jz .end
    call putc
    jmp puts
.end:
    ret


putc:
    ; al=character

    pusha
    xor bx,bx
    mov ah,14
    int 0x10
    popa
    ret

putint:
    ; ax=int
    pusha
    mov bp,sp
    push word 0
    mov cx,10
    mov si,sp
.loop:
    xor dx,dx ; simplify!
    div cx
    add dl,'0'
    dec si
    mov [si],dl
    test ax,ax
    jnz .loop
    mov sp,si
    call puts
    mov sp,bp
    popa
    ret

times 510-($-$$) nop
dw 0xAA55
