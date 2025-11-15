; Прерывание для отсчета времени до Нового года
; Выводит информацию в формате:
;       [ DDD/HH:mm:ss ],
; где DDD - трехзначное число дней до Нового года  (0 .. 364),
;     HH  - число часов до полуночи следующего дня (0 .. 23),
;     mm  - число минут до следующего часа         (0 .. 59),
;     ss  - число секунд до следующей минуты       (0 .. 59)


    DOSSEG
    .MODEL SMALL
    .STACK 100h

    ; ======== Данные =========
    .DATA

    OUT_MESSAGE     DB 'Time left until New Year: $'

    MONTH_DAYS      DB 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
    CURRENT_DAY     DW 0

    SEG_INT60h      DW 0
    OFF_INT60h      DW 0

    ; ===== Код программы =====
    .CODE

; Процедура вывода одного символа
; через BIOS-прерывание.
;
; :param: AX - ASCII-код символа для вывода
OUTCHR PROC NEAR
    push ax
    push bx
    push cx

    mov ah, 0Eh
    int 10h

    pop cx
    pop bx
    pop ax
    ret
OUTCHR ENDP


; Процедура вывода числа как двузначного.
; Например:
; 42 ---> "42"
; 1  ---> "01"
;
; :param: AX - число для вывода на экран
OUT2 PROC NEAR
    push ax
    push bx
    push dx

    mov bx, 10
    xor dx, dx
    div bx          ; AX / BX
                    ; AX - частное, DX - остаток
    
    ; Десятки
    add al, '0'
    call OUTCHR

    ; Единицы
    mov al, dl
    add al, '0'
    call OUTCHR

    pop dx
    pop bx
    pop ax
    ret
OUT2 ENDP

; Процедура для вывода
; количества дней (трёхзначное число)
; Например:
; 263 ---> "263"
; 13  ---> "013"
; 1   ---> "001"
;
; :param: AX - число для вывода
OUTDAYS PROC NEAR
    push ax
    push bx
    push dx

    mov bx, 100
    xor dx, dx
    div bx      ; AX / BX
                ; AX - частное, DX - остаток

    add al, '0'
    call OUTCHR

    mov ax, dx
    call OUT2

    pop dx
    pop bx
    pop ax
    ret
OUTDAYS ENDP

; Процедура для конвертации
; числа из BCD в BIN.
;
; :param:   AX - число в формате BCD
; :return:  AX - число в формате BIN
BCD2BIN PROC NEAR
    push bx
    push cx
    push dx

    mov ah, al
    and ah, 0F0h       ; 0F0h = 1111 0000 (маска)
    mov cl, 4
    shr ah, cl          ; Сдвиг: XXXX 0000 -> 0000 XXXX

    and al, 0Fh         ; 0Fh   = 0000 1111 (маска)

    mov dl, al      ; Младший разряд
    mov al, ah      ; Старший разряд
    mov ah, 0
    mov bl, 10      ; Старший разряд * 10
    mul bl

    add al, dl      ; Старший разряд * 10 + Младший разряд = BIN
    mov ah, 0

    pop dx
    pop cx
    pop bx
    ret
BCD2BIN ENDP

; Печатает результат LEFT_NY.
;
; :param: CX - количество дней до НГ
; :param: SI - количество часов до полуночи
; :param: DI - количество минут до часа
; :param: BP - количество секунд до минуты
TIMEPRINT PROC NEAR
    push ax
    push cx
    push si
    push di
    push bp

    mov ax, '['
    call OUTCHR

    mov ax, cx
    call OUTDAYS

    mov ax, ' '
    call OUTCHR

    mov ax, '/'
    call OUTCHR

    mov ax, ' '
    call OUTCHR

    mov ax, si
    call OUT2

    mov ax, ':'
    call OUTCHR

    mov ax, di
    call OUT2

    mov ax, ':'
    call OUTCHR

    mov ax, bp
    call OUT2

    mov ax, ']'
    call OUTCHR

    pop bp
    pop di
    pop si
    pop cx
    pop ax

    ret

TIMEPRINT ENDP


; Новый обработчик INT 60h для
; отсчёта до Нового года
LEFT_NY PROC FAR
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push es

    ; Получим текущее системное время
    ; CH - часы     CL - минуты
    ; DH - секунды  DL - сотые доли секунды
    ;
    ; (!) BCD format
    mov ah, 02h
    int 1Ah

    ; Преобразуем текущее время во время,
    ; которое осталось до полуночи:
    ; SI - часы
    ; DI - минуты
    ; BP - секунды

    ; Часы
    mov al, ch
    xor ah, ah
    call BCD2BIN
    mov bx, ax      ; BX - часы (BIN)

    mov ax, 23
    sub ax, bx
    mov si, ax      ; SI - остаток часов

    ; Минуты
    mov al, cl
    xor ah, ah
    call BCD2BIN
    mov bx, ax      ; BX - минуты (BIN)

    mov ax, 59
    sub ax, bx
    mov di, ax      ; DI - остаток минут

    ; Секунды
    mov al, dh
    xor ah, ah
    call BCD2BIN
    mov bx, ax      ; BX - секунды (BIN)

    mov ax, 59
    sub ax, bx
    mov bp, ax      ; BP - остаток секунд


    ; Получим текущую дату из RTC
    ; CH - век      CL - год
    ; DH - месяц    DL - день
    mov ah, 04h
    int 1Ah

    ; Подсчитаем количество оставшихся дней.
    ; Мы имеем DH - текущий номер месяца.
    ; Значит полных месяцев с начала года прошло
    ; DH - 1. Сложим их дни и прибавим количество
    ; текущих дней.
    ;
    ; Данные из RTC подаются в формате BCD. Нужно
    ; перевести их в BIN с помощью процедуры BCD2BIN

    mov al, dh
    call BCD2BIN
    mov bl, al      ; BL - текущий месяц (BIN)

    mov al, dl
    call BCD2BIN
    mov ah, 0
    mov CURRENT_DAY, ax     ; CURRENT_DAY - текущий день (BIN)

    ; Накапливаем количество дней до текущего месяца
    xor ax, ax
    xor cx, cx
    mov cl, bl
    dec cl          ; Количество полных месяцев
    jz no_months_before

    mov bx, OFFSET MONTH_DAYS

; Суммируем дни до текущего месяца
; Результат в AX
month_loop:
    mov dl, [bx]
    xor dh, dh
    add ax, dx
    inc bx
    dec cl
    jnz month_loop

no_months_before:
    mov dx, CURRENT_DAY
    add ax, dx          ; Результирующее количество дней с начала года
    mov cx, ax

    mov ax, 365
    sub ax, cx
    mov cx, ax

; Вывод результата на экран
print:
    call TIMEPRINT

    pop es
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    iret
LEFT_NY ENDP

initialize:
    mov ax, @DATA
    mov ds, ax

    ; Запоминаем старый обработчик INT 60h
    mov ax, 3560h
    int 21h

    mov OFF_INT60h, bx
    mov SEG_INT60h, es

    ; Устанавливаем наш обработчик LEFT_NY
    push ds
    mov ax, SEG    LEFT_NY
    mov dx, OFFSET LEFT_NY
    mov ds, ax

    mov ax, 2560h
    int 21h

    pop ds

call_interrupt:
    mov ah, 09h
    mov dx, OFFSET OUT_MESSAGE
    int 21h

    int 60h

shutdown:
    ; Восстанавливаем старый обработчик INT 60h
    mov ax, SEG_INT60h
    mov dx, OFF_INT60h
    mov ds, ax

    mov ax, 2560h
    int 21h

    mov ax, @DATA
    mov ds, ax

    mov ax, 4C00h
    int 21h
END initialize