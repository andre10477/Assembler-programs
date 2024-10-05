; perceptron.asm
; Компиляция: nasm -f win64 perceptron.asm -o perceptron.obj
; Линковка: gcc perceptron.obj -o perceptron.exe

extern GetStdHandle
extern WriteConsoleA
extern ExitProcess

section .data
    ; Константы для стандартного вывода
    STD_OUTPUT_HANDLE equ -11

    ; Обучающая выборка: пары входов и метки
    training_inputs:
        dd 0, 0      ; Входы: 0, 0
        dd 0, 1      ; Входы: 0, 1
        dd 1, 0      ; Входы: 1, 0
        dd 1, 1      ; Входы: 1, 1

    training_labels:
        db 0          ; Метка для (0,0)
        db 0          ; Метка для (0,1)
        db 0          ; Метка для (1,0)
        db 1          ; Метка для (1,1)

    ; Тестовая выборка
    test_inputs:
        dd 0, 0
        dd 1, 1

    test_labels:
        db 0
        db 1

    ; Параметры персептрона
    weights:
        dd 0          ; Вес 1
        dd 0          ; Вес 2
    threshold:
        dd 1          ; Порог активации
    learning_rate:
        dd 1          ; Скорость обучения

    ; Сообщения для вывода
    msg_success db "Prediction correct.", 10, 0
    msg_failure db "Prediction incorrect.", 10, 0

section .bss
    ; Резервируемая память (если требуется)

section .text
    global main
    extern main

main:
    ; Получение дескриптора стандартного вывода
    sub rsp, 40                  ; Выравнивание стека до 16-байтной границы
    mov rcx, STD_OUTPUT_HANDLE
    call GetStdHandle
    mov rbx, rax                 ; Сохраняем дескриптор в rbx

    ; Инициализация весов
    mov dword [weights], 0
    mov dword [weights + 4], 0

    ; Обучение персептрона
    mov ecx, 4                   ; Количество обучающих примеров
    mov esi, training_inputs
    mov edi, training_labels
    mov eax, 0                   ; Счётчик эпох

.train_loop:
    cmp eax, 10                  ; Максимум 10 эпох
    jge .training_done

    mov ecx, 4                   ; Количество обучающих примеров
    mov esi, training_inputs
    mov edi, training_labels

.train_epoch:
    ; Загрузка входов
    mov eax, [esi]
    mov edx, [esi + 4]
    
    ; Загрузка ожидаемой метки
    mov bl, [edi]

    ; Вычисление взвешенной суммы: (w1 * input1) + (w2 * input2)
    mov eax, [weights]
    imul eax, [esi]
    mov ecx, [weights + 4]
    imul ecx, [esi + 4]
    add eax, ecx                  ; Сумма = w1*input1 + w2*input2

    ; Применение порога
    mov ecx, [threshold]
    cmp eax, ecx
    jge .predict_one
    mov al, 0
    jmp .prediction_done

.predict_one:
    mov al, 1

.prediction_done:
    ; Сравнение с ожидаемой меткой
    cmp al, bl
    je .no_update

    ; Обновление весов
    mov ecx, [learning_rate]
    cmp bl, 1
    jne .decrease_weights

    ; Увеличение весов
    add dword [weights], eax    ; w1 += input1 * lr
    add dword [weights + 4], edx ; w2 += input2 * lr
    jmp .next_example

.decrease_weights:
    ; Уменьшение весов
    sub dword [weights], eax    ; w1 -= input1 * lr
    sub dword [weights + 4], edx ; w2 -= input2 * lr

.next_example:
    add esi, 8                  ; Переход к следующему примеру (две dword)
    add edi, 1                  ; Переход к следующей метке
    loop .train_epoch

    ; Следующая эпоха
    inc eax
    jmp .train_loop

.training_done:
    ; Прогнозирование на тестовой выборке
    mov ecx, 2                   ; Количество тестовых примеров
    mov esi, test_inputs
    mov edi, test_labels

.predict_loop:
    ; Загрузка входов
    mov eax, [esi]
    mov edx, [esi + 4]
    
    ; Вычисление взвешенной суммы: (w1 * input1) + (w2 * input2)
    mov ecx, [weights]
    imul ecx, [esi]
    mov ebx, [weights + 4]
    imul ebx, [esi + 4]
    add ecx, ebx                  ; Сумма = w1*input1 + w2*input2

    ; Применение порога
    mov ebx, [threshold]
    cmp ecx, ebx
    jge .predict_test_one
    mov al, 0
    jmp .prediction_test_done

.predict_test_one:
    mov al, 1

.prediction_test_done:
    ; Загрузка ожидаемой метки
    mov bl, [edi]

    ; Сравнение прогноза с меткой
    cmp al, bl
    je .print_success
    jne .print_failure

.print_success:
    ; Вывод сообщения об успешном прогнозе
    lea rcx, [msg_success]
    mov rdx, 19                 ; Длина сообщения
    call WriteConsoleA
    jmp .next_test

.print_failure:
    ; Вывод сообщения об ошибочном прогнозе
    lea rcx, [msg_failure]
    mov rdx, 21                 ; Длина сообщения
    call WriteConsoleA

.next_test:
    add esi, 8                  ; Следующий тестовый пример
    add edi, 1                  ; Следующая метка
    loop .predict_loop

    ; Завершение программы
    mov ecx, 0                   ; Код выхода 0
    call ExitProcess
