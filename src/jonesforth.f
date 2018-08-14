: / /MOD SWAP DROP ;
: MOD /MOD DROP ;


: '\n' 10 ;       \ Возврат каретки
: BL   32 ;       \ BL (BLank) стандартное слово для пробела

: CR     '\n' EMIT ;  \ CR печатает возврат каретки
: SPACE  BL   EMIT ;  \ SPACE печатает пробел
: NEGATE 0 SWAP - ;

: TRUE  1 ;
: FALSE 0 ;
: NOT   0= ;

: LITERAL IMMEDIATE
    ' LIT ,      \ компилирует LIT
    ,            \ компилирует сам литерал (из стека)
;

: ':'
    [         \ входим в immediate mode (временно)
    CHAR :    \ push 58 (ASCII code of ":") в стек параметров
    ]         \ переходим назад в compile mode
    LITERAL   \ компилируем LIT 58 как определения ':' слова
;

: ';' [ CHAR ; ] LITERAL ;
: '(' [ CHAR ( ] LITERAL ;
: ')' [ CHAR ) ] LITERAL ;
: '"' [ CHAR " ] LITERAL ;
: 'A' [ CHAR A ] LITERAL ;
: '0' [ CHAR 0 ] LITERAL ;
: '-' [ CHAR - ] LITERAL ;
: '.' [ CHAR . ] LITERAL ;

: [COMPILE] IMMEDIATE
    WORD        \ получить следующее слово
    FIND        \ найти его в словаре
    >CFA        \ получить его codeword
    ,           \ и скомпилировать его
;

: RECURSE IMMEDIATE
    LATEST @  \ LATEST указывает на слово, компилируемое в данный момент
    >CFA      \ получаем codeword
    ,         \ компилируем его
;

: IF IMMEDIATE
    ' 0BRANCH ,    \ компилировать 0BRANCH
    HERE @         \ сохранить позицию смещения в стеке
    0 ,            \ компилировать фиктивное смещение
;

: THEN IMMEDIATE
    DUP
    HERE @ SWAP -  \ рассчитать смещение от адреса сохраненного в стек
    SWAP !         \ сохранить смещение в заполненом месте
;

: ELSE IMMEDIATE
    ' BRANCH ,     \ определить ветвь до false-part
    HERE @         \ сохранить местоположение смещения в стеке
        0 ,        \ компилировать фиктивное смещение
        SWAP       \ теперь заполнить оригинальное (IF) смещение
        DUP        \ то же что и для THEN выше
    HERE @ SWAP -
    SWAP !
;

: BEGIN IMMEDIATE
    HERE @       \ Сохранить location в стеке
;

: UNTIL IMMEDIATE
    ' 0BRANCH ,  \ скомпилировать 0BRANCH
    HERE @ -     \ рассчитать смещение от сохраненного адреса в стеке
    ,            \ скомпилировать смещение
;

: AGAIN IMMEDIATE
    ' BRANCH , \ скомпилировать BRANCH
    HERE @ -   \ вычислить смещение назад
    ,          \ скомпилировать смещение
;

: WHILE IMMEDIATE
    ' 0BRANCH ,   \ компилировать 0BRANCH
    HERE @        \ сохранить позицию offset2 в стеке
    0 ,           \ компилировать фиктивное смещение offset2
;

: REPEAT IMMEDIATE
    ' BRANCH ,    \ компилировать BRANCH
    SWAP          \ взять оригинальное смещение (from BEGIN)
    HERE @ - ,    \ и скомпилировать его после BRANCH
    DUP
    HERE @ SWAP - \ вычислить offset2
    SWAP !        \ и заполнить им оригинальную позицию
;

: UNLESS IMMEDIATE
    ' NOT ,        \ скомпилировать NOT (чтобы обратить test)
    [COMPILE] IF   \ продолжить, вызывав обычный IF
;

: ( IMMEDIATE
    1                  \ разрешены вложенные комментарии путем отслеживания глубины
    BEGIN
        KEY            \ прочесть следующий симво
        DUP '(' = IF   \ открывающая скобка?
            DROP       \ drop ее
            1+         \ увеличить глубину
        ELSE
            ')' = IF   \ закрывающая скобка?
                1-     \ уменьшить глубину
            THEN
        THEN
    DUP 0= UNTIL       \ продолжать пока не достигнем нулевой глубины
    DROP               \ drop счетчик
;

: NIP ( x y -- y ) SWAP DROP ;

: TUCK ( x y -- y x y ) SWAP OVER ;

: PICK ( x_u ... x_1 x_0 u -- x_u ... x_1 x_0 x_u )
    1+                  \ добавить единицу из-за "u" в стек
    4 *                 \ умножить на размер слова
    DSP@ +              \ добавить к указателю стека
    @                   \ и взять
;

\ C помощью циклов мы можем теперь написать SPACES, который записывает N пробелов в stdout
: SPACES                ( n -- )
    BEGIN
        DUP 0>          \ пока n > 0
    WHILE
            SPACE       \ напечатать пробел
            1-          \ повторять с уменьшением пока не 0
    REPEAT
    DROP                \ сбросить счетчик со стека
;

\ Стандартные слова для манипуляции BASE )
: DECIMAL ( -- ) 10 BASE ! ;
: HEX     ( -- ) 16 BASE ! ;

: U. ( u -- )
    BASE @ U/MOD \ width rem quot
    ?DUP IF      \ if quotient <> 0 then
        RECURSE  \ print the quotient
    THEN

    \ печатаем остаток
    DUP 10 < IF
        '0'  \ десятичные цифры 0..9 )
    ELSE
        10 - \ шестнадцатиричные и другие цифры A..Z )
        'A'
    THEN
    +
    EMIT
;

: .S ( -- )
    DSP@ \ взять текущий стековый указатель
    BEGIN
        DUP S0 @ <
    WHILE
            DUP @ U. \ напечатать элемент из стека
            SPACE
            4+       \ двигаться дальше
    REPEAT
    DROP \ сбросить указатель
;

: UWIDTH ( u -- width )
    BASE @ /        \ rem quot
    ?DUP IF         \ if quotient <> 0 then
        RECURSE 1+  \ return 1+recursive call
    ELSE
        1           \ return 1
    THEN
;

: U.R       ( u width -- )
    SWAP    ( width u )
    DUP     ( width u u )
    UWIDTH  ( width u uwidth )
    ROT     ( u uwidth width )
    SWAP -  ( u width-uwidth )
    ( В этот момент, если запрошенная ширина уже, у нас будет отрицательное число в стеке.
    В противном случае число в стеке - это количество пробелов для печати.
    Но SPACES не будет печатать отрицательное количество пробелов в любом случае,
    поэтому теперь можно безопасно вызвать SPACES ... )
    SPACES
    ( ... а затем вызвать базовую реализацию U. )
    U.
;

: .R  ( n width -- )
    SWAP        ( width n )
    DUP 0< IF
        NEGATE  ( width u )
        1       ( сохранить флаг, чтобы запомнить, что оно отрицательное | width n 1 )
        SWAP    ( width 1 u )
        ROT     ( 1 u width )
        1-      ( 1 u width-1 )
    ELSE
        0       ( width u 0 )
        SWAP    ( width 0 u )
        ROT     ( 0 u width )
    THEN
    SWAP        ( flag width u )
    DUP         ( flag width u u )
    UWIDTH      ( flag width u uwidth )
    ROT         ( flag u uwidth width )
    SWAP -      ( flag u width-uwidth )

    SPACES      ( flag u )
    SWAP        ( u flag )

    IF          ( число было отрицательным? печатаем минус )
        '-' EMIT
    THEN

    U.
;

: . 0 .R SPACE ;

: U. U. SPACE ;

: ? ( addr -- ) @ . ;

: WITHIN
    -ROT ( b c a )
    OVER ( b c a c )
    <= IF
        > IF ( b c -- )
            TRUE
        ELSE
            FALSE
        THEN
    ELSE
        2DROP ( b c -- )
        FALSE
    THEN
;

: DEPTH        ( -- n )
    S0 @ DSP@ -
    4-         ( это нужно потому что Ы0 было на стеке, когда мы push-или DSP )
;

: ALIGNED ( addr -- addr )
    3 + 3 INVERT AND \ (addr+3) & ~3
;

: ALIGN HERE @ ALIGNED HERE ! ;

\ C, добавляет байт к текущему компилируемому слову
: C,
    HERE @ C! \ сохраняет символ в текущем компилируемом образе
    1 HERE +! \ увеличивает указатель HERE на 1 байт
;

: S" IMMEDIATE ( -- addr len )
    STATE @ IF           \ (компилируем)?
        ' LITSTRING ,    \ ?-Да: компилировать LITSTRING
        HERE @           \ сохранить адрес длины слова в стеке
        0 ,              \ фейковая длина - мы ее пока не знаем
        BEGIN
            KEY          \ взять следующий символ строки
            DUP '"' <>
        WHILE
                C,       \ копировать символ
        REPEAT
        DROP             \ сбросить символ двойной кавычки, которым заканчивалась строка
        DUP              \ получить сохраненный адрес длины слова
        HERE @ SWAP -    \ вычислить длину
        4-               \ вычесть 4 потому что мы измеряем от начала длины слова
        SWAP !           \ и заполнить длину )
        ALIGN            \ округить к следующему кратному 4 байту для оставшегося кода
    ELSE \ immediate mode
        HERE @           \ взять адрес начала временного пространства
        BEGIN
            KEY
            DUP '"' <>
        WHILE
                OVER C!  \ сохраниь следующий символ
                1+       \ увеличить адрес
        REPEAT
        DROP             \ сбросить символ двойной кавычки, которым заканчивалась строка
        HERE @ -         \ вычислить длину
        HERE @           \ push начальный адрес
        SWAP             ( addr len )
    THEN
;

: ." IMMEDIATE ( -- )
    STATE @ IF       \ компиляция?
        [COMPILE] S" \ прочитать строку и скомпилировать LITSTRING, etc.
        ' TELL ,     \ скомпилировать окончательный TELL
    ELSE
        \ В немедленном режиме просто читаем символы и печаетем им пока не встретим кавычку
        BEGIN
            KEY
            DUP '"' = IF
                DROP \ сбросим со стека символ двойной кавычки
                EXIT \ возврат из функции
            THEN
            EMIT
        AGAIN
    THEN
;

: CONSTANT
    WORD     \ получить имя, которое следует за CONSTANT
    CREATE   \ создать заголовок элемента словаря
    DOCOL ,  \ добавить DOCOL как codeword поля слова
    ' LIT ,  \ добавить codeword LIT
    ,        \ добавить значение, которое лежит на вершине стека
    ' EXIT , \ добавить codeword EXIT
;

: ALLOT ( n -- addr )
    HERE @ SWAP ( here n )
    HERE +!     \ добавляем n к HERE, после этого старое значение остается на стеке
;

: CELLS ( n -- n ) 4 * ;
: CHARS ( n -- n ) 1 * ;

: VARIABLE
    1 CELLS ALLOT \ выделить 4 байтовую ячейку для integer в памяти, push указатель на нее
    WORD CREATE   \ создать элемент словаря, имя которого следует за VARIABLE
    DOCOL ,       \ добавить DOCOL  как поле codeword этого слова
    ' LIT ,       \ добавить codeword LIT
    ,             \ добавить указатель на выделенную память
    ' EXIT ,      \ добавить codeword EXIT
;

: VALUE ( n -- )
    WORD CREATE \ создаем заголовок элемента словаря - имя следует за VALUE
    DOCOL ,     \ добавляем DOCOL
    ' LIT ,     \ добавляем codeword LIT
    ,           \ добавляем начальное значение
    ' EXIT ,    \ добавляем codeword EXIT
;

: TO IMMEDIATE ( n -- )
    WORD        \ получаем имя VALUE
    FIND        \ ищем его в словаре
    >DFA        \ получаем указатель на первое поле данных -'LIT'
    4+          \ увеличиваем его значение на размер данных
    STATE @ IF \ компиляция?
        ' LIT , \ да, компилировать LIT
        ,       \ компилировать адрес значения
        ' ! ,   \ компилировать !
    ELSE       \ нет, immediate mode
        !       \ обновить сразу
    THEN
;

: +TO IMMEDIATE
    WORD \ получаем имя значения
    FIND \ ищем в словаре
    >DFA \ получаем указатель на первое поле данных -'LIT'
    4+   \ увеличиваем его значение на размер данных
    STATE @ IF \ компиляция?
        ' LIT , \ да, компилировать LIT
        ,       \ компилировать адрес значения
        ' +! ,  \ компилировать +!
    ELSE \ нет, immediate mode
        +! \ обновить сразу
    THEN
;

: ID.
    4+            ( перепрыгиваем через указатель link )
    DUP C@        ( получаем байт flags/length )
    F_LENMASK AND ( маскируем flags - мы хотим просто получить длину )

    BEGIN
        DUP 0>    ( длина > 0? )
    WHILE
            SWAP 1+ ( addr len -- len addr+1 )
            DUP C@  ( len addr -- len addr char | получаем следующий символ )
            EMIT    ( len addr char -- len addr | и печатаем его )
            SWAP 1- ( len addr -- addr len-1    | вычитаем единицу из длины )
    REPEAT
    2DROP         ( len addr -- )
;

: ?HIDDEN
    4+ ( перепрыгиваем через указатель link )
    C@ ( получаем байт flags/length )
    F_HIDDEN AND ( маскируем F_HIDDEN флаг и возвращаем его )
;

: ?IMMEDIATE
    4+ ( перепрыгиваем через указатель link )
    C@ ( получаем байт flags/length )
    F_IMMED AND ( маскируем  F_IMMED флаг и возвращаем его )
;

: WORDS
    LATEST @ ( начинаем с LATEST указателя )
    BEGIN
        ?DUP ( полка указатель не null )
    WHILE
            DUP ?HIDDEN NOT IF ( игнорируем скрытые слова )
                DUP ID.        ( если не скрытое, то печатаем слово )
                SPACE
            THEN
            @ ( dereference link - идем к следующему слову )
    REPEAT
    CR
;

: FORGET
    WORD FIND      ( найти слов и получить его dictionary entry address )
    DUP @ LATEST ! ( установить LATEST на указатель предыдущего слова )
    HERE !         ( и сохранить HERE как dictionary address )
;

: DUMP ( addr len -- )
    BASE @ -ROT ( save the current BASE at the bottom of the stack )
    HEX ( and switch to hexadecimal mode )

    BEGIN
        ?DUP ( while len > 0 )
    WHILE
            OVER 8 U.R ( print the address )
            SPACE

            ( print up to 16 words on this line )
            2DUP ( addr len addr len )
            1- 15 AND 1+ ( addr len addr linelen )
            BEGIN
                ?DUP ( while linelen > 0 )
            WHILE
                    SWAP ( addr len linelen addr )
                    DUP C@ ( addr len linelen addr byte )
                    2 .R SPACE ( print the byte )
                    1+ SWAP 1- ( addr len linelen addr -- addr len addr+1 linelen-1 )
            REPEAT
            DROP ( addr len )

            ( print the ASCII equivalents )
            2DUP 1- 15 AND 1+  ( addr len addr linelen )
            BEGIN
                ?DUP ( while linelen > 0)
            WHILE
                    SWAP ( addr len linelen addr )
                    DUP C@ ( addr len linelen addr byte )
                    DUP 32 128 WITHIN IF ( 32 <= c < 128? )
                        EMIT
                    ELSE
                        DROP '.' EMIT
                    THEN
                    1+ SWAP 1- ( addr len linelen addr -- addr len addr+1 linelen-1 )
            REPEAT
            DROP ( addr len )
            CR

            DUP 1- 15 AND 1+  ( addr len linelen )
            TUCK ( addr linelen len linelen )
            - ( addr linelen len-linelen )
            >R + R> ( addr+linelen len-linelen )
    REPEAT

    DROP ( restore stack )
    BASE ! ( restore saved BASE )
;

: CASE IMMEDIATE
    0 ( push 0 to mark the bottom of the stack )
;

: OF IMMEDIATE
    ' OVER , ( compile OVER )
    ' = , ( compile = )
    [COMPILE] IF ( compile IF )
    ' DROP ,   ( compile DROP )
;

: ENDOF IMMEDIATE
    [COMPILE] ELSE ( ENDOF is the same as ELSE )
;

: ENDCASE IMMEDIATE
    ' DROP , ( compile DROP )

    ( keep compiling THEN until we get to our zero marker )
    BEGIN
        ?DUP
    WHILE
            [COMPILE] THEN
    REPEAT
;

: CFA>
    LATEST @ ( start at LATEST dictionary entry )
    BEGIN
        ?DUP ( while link pointer is not null )
    WHILE
            2DUP SWAP ( cfa curr curr cfa )
            < IF ( current dictionary entry < cfa? )
                NIP ( leave curr dictionary entry on the stack )
                EXIT
            THEN
            @ ( follow link pointer back )
    REPEAT
    DROP ( restore stack )
    0 ( sorry, nothing found )
;

: SEE
    WORD FIND ( find the dictionary entry to decompile )

    ( Now we search again, looking for the next word in the dictionary.  This gives us
    the length of the word that we will be decompiling.   (Well, mostly it does). )
    HERE @ ( address of the end of the last compiled word )
    LATEST @ ( word last curr )
    BEGIN
        2 PICK ( word last curr word )
        OVER ( word last curr word curr )
        <> ( word last curr word<>curr? )
    WHILE ( word last curr )
            NIP ( word curr )
            DUP @ ( word curr prev  (which becomes: word last curr) )
    REPEAT

    DROP ( at this point, the stack is: start-of-word end-of-word )
    SWAP ( end-of-word start-of-word )

    ( begin the definition with : NAME [IMMEDIATE] )
    ':' EMIT SPACE DUP ID. SPACE
    DUP ?IMMEDIATE IF ." IMMEDIATE " THEN

    >DFA ( get the data address, ie. points after DOCOL | end-of-word start-of-data )

    ( now we start decompiling until we hit the end of the word )
    BEGIN ( end start )
        2DUP >
    WHILE
            DUP @ ( end start codeword )

            CASE
                ' LIT OF ( is it LIT ? )
                    4 + DUP @ ( get next word which is the integer constant )
                    . ( and print it )
                ENDOF
                ' LITSTRING OF ( is it LITSTRING ? )
                    [ CHAR S ] LITERAL EMIT '"' EMIT SPACE  ( print S"<space> )
                    4 + DUP @ ( get the length word )
                    SWAP 4 + SWAP ( end start+4 length )
                    2DUP TELL ( print the string )
                    '"' EMIT SPACE ( finish the string with a final quote )
                    + ALIGNED ( end start+4+len, aligned )
                    4 - ( because we're about to add 4 below )
                ENDOF
                ' 0BRANCH OF ( is it 0BRANCH ? )
                    ." 0BRANCH  ( "
                    4 + DUP @ ( print the offset )
                    .
                    ." ) "
                ENDOF
                ' BRANCH OF ( is it BRANCH ? )
                    ." BRANCH  ( "
                    4 + DUP @ ( print the offset )
                    .
                    ." ) "
                ENDOF
                ' ' OF ( is it '  (TICK) ? )
                    [ CHAR ' ] LITERAL EMIT SPACE
                    4 + DUP @ ( get the next codeword )
                    CFA> ( and force it to be printed as a dictionary entry )
                    ID. SPACE
                ENDOF
                ' EXIT OF ( is it EXIT? )
                    ( We expect the last word to be EXIT, and if it is then we don't print it
                    because EXIT is normally implied by ;.  EXIT can also appear in the middle
                    of words, and then it needs to be printed. )
                    2DUP ( end start end start )
                    4 + ( end start end start+4 )
                    <> IF ( end start | we're not at the end )
                        ." EXIT "
                    THEN
                ENDOF
                ( default case: )
                DUP ( in the default case we always need to DUP before using )
                CFA> ( look up the codeword to get the dictionary entry )
                ID. SPACE ( and print it )
            ENDCASE

            4 + ( end start+4 )
    REPEAT

    ';' EMIT CR

    2DROP ( restore stack )
;

: :NONAME
    0 0 CREATE ( create a word with no name - we need a dictionary header because ; expects it )
    HERE @     ( current HERE value is the address of the codeword, ie. the xt )
    DOCOL ,    ( compile DOCOL  (the codeword) )
    ]          ( go into compile mode )
;

: ['] IMMEDIATE
    ' LIT ,    ( compile LIT )
;

: EXCEPTION-MARKER
    RDROP ( drop the original parameter stack pointer )
    0 ( there was no exception, this is the normal return path )
;

: CATCH ( xt -- exn? )
    DSP@ 4+ >R ( save parameter stack pointer  (+4 because of xt) on the return stack )
    ' EXCEPTION-MARKER 4+ ( push the address of the RDROP inside EXCEPTION-MARKER ... )
    >R ( ... on to the return stack so it acts like a return address )
    EXECUTE ( execute the nested function )
;

: THROW ( n -- )
    ?DUP IF ( only act if the exception code <> 0 )
        RSP@  ( get return stack pointer )
        BEGIN
            DUP R0 4- < ( RSP < R0 )
        WHILE
                DUP @ ( get the return stack entry )
                ' EXCEPTION-MARKER 4+ = IF ( found the EXCEPTION-MARKER on the return stack )
                    4+ ( skip the EXCEPTION-MARKER on the return stack )
                    RSP! ( restore the return stack pointer )

                    ( Restore the parameter stack. )
                    DUP DUP DUP ( reserve some working space so the stack for this word
                    doesn't coincide with the part of the stack being restored )
                    R> ( get the saved parameter stack pointer | n dsp )
                    4- ( reserve space on the stack to store n )
                    SWAP OVER ( dsp n dsp )
                    ! ( write n on the stack )
                    DSP! EXIT ( restore the parameter stack pointer, immediately exit )
                THEN
                4+
        REPEAT

        ( No matching catch - print a message and restart the INTERPRETer. )
        DROP

        CASE
            0 1- OF ( ABORT )
                ." ABORTED" CR
            ENDOF
            ( default case )
            ." UNCAUGHT THROW "
            DUP . CR
        ENDCASE
        QUIT
    THEN
;

: ABORT ( -- )
    0 1- THROW
;


( Print a stack trace by walking up the return stack. )
: PRINT-STACK-TRACE
    RSP@ ( start at caller of this function )
    BEGIN
        DUP R0 4- < ( RSP < R0 )
    WHILE
            DUP @ ( get the return stack entry )
            CASE
                ' EXCEPTION-MARKER 4+ OF ( is it the exception stack frame? )
                    ." CATCH  ( DSP="
                    4+ DUP @ U. ( print saved stack pointer )
                    ." ) "
                ENDOF
                ( default case )
                DUP
                CFA> ( look up the codeword to get the dictionary entry )
                ?DUP IF ( and print it )
                    2DUP ( dea addr dea )
                    ID. ( print word from dictionary entry )
                    [ CHAR + ] LITERAL EMIT
                    SWAP >DFA 4+ - . ( print offset )
                THEN
            ENDCASE
            4+ ( move up the stack )
    REPEAT
    DROP
    CR
;

: Z" IMMEDIATE
    STATE @ IF ( compiling? )
        ' LITSTRING , ( compile LITSTRING )
        HERE @ ( save the address of the length word on the stack )
        0 , ( dummy length - we don't know what it is yet )
        BEGIN
            KEY  ( get next character of the string )
            DUP '"' <>
        WHILE
                HERE @ C! ( store the character in the compiled image )
                1 HERE +! ( increment HERE pointer by 1 byte )
        REPEAT
        0 HERE @ C! ( add the ASCII NUL byte )
        1 HERE +!
        DROP ( drop the double quote character at the end )
        DUP ( get the saved address of the length word )
        HERE @ SWAP - ( calculate the length )
        4- ( subtract 4  (because we measured from the start of the length word) )
        SWAP ! ( and back-fill the length location )
        ALIGN ( round up to next multiple of 4 bytes for the remaining code )
        ' DROP , ( compile DROP  (to drop the length) )
    ELSE ( immediate mode )
        HERE @ ( get the start address of the temporary space )
        BEGIN
            KEY
            DUP '"' <>
        WHILE
                OVER C! ( save next character )
                1+ ( increment address )
        REPEAT
        DROP ( drop the final " character )
        0 SWAP C! ( store final ASCII NUL )
        HERE @ ( push the start address )
    THEN
;

: STRLEN  ( str -- len )
    DUP ( save start address )
    BEGIN
        DUP C@ 0<> ( zero byte found? )
    WHILE
            1+
    REPEAT

    SWAP - ( calculate the length )
;

: CSTRING ( addr len -- c-addr )
    SWAP OVER ( len saddr len )
    HERE @ SWAP ( len saddr daddr len )
    CMOVE ( len )

    HERE @ + ( daddr+len )
    0 SWAP C! ( store terminating NUL char )

    HERE @  ( push start address )
;

: ARGC
    S0 @ @
;

: ARGV  ( n -- str u )
    1+ CELLS S0 @ + ( get the address of argv[n] entry )
    @ ( get the address of the string )
    DUP STRLEN ( and get its length / turn it into a Forth string )
;

: ENVIRON   ( -- addr )
    ARGC    ( number of command line parameters on the stack to skip )
    2 +     ( skip command line count and NULL pointer after the command line args )
    CELLS   ( convert to an offset )
    S0 @ +  ( add to base stack address )
;

: BYE ( -- )
    0 ( return code  (0) )
    SYS_EXIT ( system call number )
    SYSCALL1
;

(
: GET-BRK ( -- brkpoint )
    0 SYS_BRK SYSCALL1 ( call brk (0) )
;

: UNUSED ( -- n )
    GET-BRK ( get end of data segment according to the kernel )
    HERE @ ( get current position in data segment )
    -
    4 / ( returns number of cells )
;
)

(
: BRK( brkpoint -- )
    SYS_BRK SYSCALL1
;

: MORECORE( cells -- )
    CELLS GET-BRK + BRK
;
)

: R/O  ( -- fam ) O_RDONLY ;
: R/W  ( -- fam ) O_RDWR ;

: OPEN-FILE ( addr u fam -- fd 0  (if successful) | c-addr u fam -- fd errno  (if there was an error) )
    -ROT ( fam addr u )
    CSTRING ( fam cstring )
    SYS_OPEN SYSCALL2  ( open  (filename, flags) )
    DUP ( fd fd )
    DUP 0< IF ( errno? )
        NEGATE ( fd errno )
    ELSE
        DROP 0 ( fd 0 )
    THEN
;

: CREATE-FILE ( addr u fam -- fd 0  (if successful) | c-addr u fam -- fd errno  (if there was an error) )
    O_CREAT OR
    O_TRUNC OR
    -ROT ( fam addr u )
    CSTRING ( fam cstring )
    420 -ROT ( 0644 fam cstring )
    SYS_OPEN SYSCALL3  ( open  (filename, flags|O_TRUNC|O_CREAT, 0644) )
    DUP ( fd fd )
    DUP 0< IF ( errno? )
        NEGATE ( fd errno )
    ELSE
        DROP 0 ( fd 0 )
    THEN
;

: CLOSE-FILE ( fd -- 0  (if successful) | fd -- errno  (if there was an error) )
    SYS_CLOSE SYSCALL1
    NEGATE
;

: READ-FILE ( addr u fd -- u2 0  (if successful) | addr u fd -- 0 0  (if EOF) | addr u fd -- u2 errno  (if error) )
    >R SWAP R> ( u addr fd )
    SYS_READ SYSCALL3

    DUP ( u2 u2 )
    DUP 0< IF ( errno? )
        NEGATE ( u2 errno )
    ELSE
        DROP 0 ( u2 0 )
    THEN
;

\ PERROR prints a message for an errno, similar to C's perror (3) but we don't have the extensive
\ list of strerror strings available, so all we can do is print the errno.
: PERROR ( errno addr u -- )
    TELL
    ':' EMIT SPACE
    ." ERRNO="
    . CR
;

HEX

: NEXT IMMEDIATE AD C, FF C, 20 C, ; \ NEXT эквивалент

: ;ASMCODE IMMEDIATE
    [COMPILE] NEXT        \ вставляем NEXT в компилируемое слово
    ALIGN                 \ машинный код собирается побайтово, поэтому его конец
                          \ может быть не выровнен. А мы хотим чтобы следующее слово
                          \ начиналось с выровненной границы, поэтому выровняем HERE
    LATEST @ DUP          \ получить значение LATEST и сделать еще одну его копию в стеке
    HIDDEN                \ unhide - забирает одно сохраненное значение LATEST из стека
    DUP >DFA SWAP >CFA !  \ изменяем codeword чтобы он указывал на param-field
                          \ (при этом забирается второе значение LATEST из стека)
                          \ Этот же код, более просто, но менее оптимально можно было бы
                          \ записать вот так:
                          \ LATEST @ HIDDEN    \ unhide
                          \ LATEST @ >DFA      \ получаем  DFA
                          \ LATEST @ >CFA      \ получаем  CFA
                          \ !                  \ сохраняем DFA в CFA
    [COMPILE] [           \ вставляем в компилируемое слово возврат в immediate режим
;

\ Регистры и соответтсвующие им значения битов reg
: EAX IMMEDIATE 0 ; \ 000
: ECX IMMEDIATE 1 ; \ 001
: EDX IMMEDIATE 2 ; \ 010
: EBX IMMEDIATE 3 ; \ 011
: ESP IMMEDIATE 4 ; \ 100
: EBP IMMEDIATE 5 ; \ 101
: ESI IMMEDIATE 6 ; \ 110
: EDI IMMEDIATE 7 ; \ 111

: AL IMMEDIATE 0 ; \ 000
: CL IMMEDIATE 1 ; \ 001
: DL IMMEDIATE 2 ; \ 010
: BL IMMEDIATE 3 ; \ 011
: AH IMMEDIATE 4 ; \ 100
: CH IMMEDIATE 5 ; \ 101
: DH IMMEDIATE 6 ; \ 110
: BH IMMEDIATE 7 ; \ 111

\ Стековые инструкции
: PUSH IMMEDIATE 50 + C, ;
: POP IMMEDIATE 58 + C, ;

\ RDTSC опкод
: RDTSC IMMEDIATE 0F C, 31 C, ;

DECIMAL

\ RDTSC является ассемблерным примитивом, который считывает счетчик
\ времени Pentium (который подсчитывает такты процессора).  Поскольку
\ TSC имеет ширину 64 бит мы должны push-ить его в стек в два приема

: RDTSC ( -- lsb msb )
    RDTSC    \ записывает результат в %edx:%eax
    EAX PUSH \ push lsb
    EDX PUSH \ push msb
;ASMCODE
HEX
: MOD-DISP-NONE    0  ; \ 00---+++
: MOD-DISP-SHORT   40 ; \ 01---+++
: MOD-DISP         80 ; \ 10---+++
: MOD-REG-OR-IMM   C0 ; \ 11---+++
: REG-DST ( --+++reg -- --reg000 )                                  8 * ;
: REG-SRC ( --+++reg -- --+++reg )                                      ;
: TWO-REG ( reg-dst reg-src -- ++regreg )   SWAP REG-DST SWAP REG-SRC + ;
: MODR/M  ( mod reg -- modr/m    )                                    + ;
: LEA IMMEDIATE
    8D C,
    TWO-REG MODR/M C,
    C,
;
: MOV-R32,R/M32 IMMEDIATE
    8B C,
    TWO-REG MODR/M C,
;

HEX
: (DOCON) IMMEDIATE
      8D C, 40 C, 04 C,  \ lea     4(%eax), %eax
      8B C, 00 C,        \ movl    (%eax), %eax
      50 C,              \ pushl   %eax
      AD C, FF C, 20 C,  \ NEXT
;

HEX
: =NEXT ( addr -- next? )
    DUP C@ AD <> IF DROP FALSE EXIT THEN
    1+ DUP C@ FF <> IF DROP FALSE EXIT THEN
    1+     C@ 20 <> IF      FALSE EXIT THEN
    TRUE
;
DECIMAL

(  (INLINE) is the lowlevel inline function. )
:  (INLINE) ( cfa -- )
    @ ( remember codeword points to the code )
    BEGIN ( copy bytes until we hit NEXT macro )
        DUP =NEXT NOT
    WHILE
            DUP C@ C,
            1+
    REPEAT
    DROP
;

: INLINE IMMEDIATE
    WORD FIND ( find the word in the dictionary )
    >CFA ( codeword )

    DUP @ DOCOL = IF ( check codeword <> DOCOL  (ie. not a Forth word) )
        ." Cannot INLINE Forth words" CR ABORT
    THEN

    (INLINE)
;

HIDE =NEXT

: WELCOME
    S" TEST-MODE" FIND NOT IF
        ." JONESFORTH VERSION " VERSION . CR
        \ UNUSED .
        \ ." CELLS REMAINING" CR
        ." OK "
    THEN
;

WELCOME
HIDE WELCOME

HEX
: (DOCON) IMMEDIATE
      8D C, 40 C, 04 C,  \ lea     4(%eax), %eax
      8B C, 00 C,        \ movl    (%eax), %eax
      50 C,              \ pushl   %eax
      AD C, FF C, 20 C,  \ NEXT
;

\ : DEFCONST
\     WORD             \ прочтем слово с stdin
\     CREATE           \ создадим заголовок слова
\     0 ,              \ вместо codeword вкомпилим заглушку-ноль
\     ,                \ скомпилируем param-field взяв его со стека (в нашем примере - 1337)
\     [COMPILE] [      \ вкомпилить в DEFCONST переход в immediate-режим
\     \ Здесь, во время определения слова DEFCONST мы можем
\     \ вычислить начало ассемблерного кода, вкомпилив его адрес как литерал
\     \ чтобы во время выполнения DEFCONST заменить codeword создаваемого
\     \ дочернего слова на адрес машинного кода
\     LIT
\     [            \ Ненадолго переходим в IMMEDIATE-режим - compile-time вычисления
\       HEX
\       HERE @ 18 +    \ Вычисляем адрес начала машинного кода относительно HERE:
\                      \ сейчас будет вкомпилен вычисленный адрес, потом
\                      \ еще 5 команд, всего 6, каждая по 4 байта = 24
\                      \ байта в десятичной = 18 в шестнадцатиричной.
\       ,              \ И вкомпиливаем его в DEFCONST
\     ]            \ Возврат из IMMEDIATE-режима
\     LATEST @ >CFA    \ получаем CFA дочернего слова
\     !                \ сохраняем адрес начала машинного кода в codeword дочернего кода
\     EXIT             \ вкомпилить в DEFCONST вызов слова EXIT,
\                      \ чтобы при исполнении DEFCONST осуществить возврат.
\     (DOCON)          \ А дальше "немедленно" вкомпилить машинный код
\ ;




: (;CODE)
    R>                  \ pop-ит адрес машинного кода со стека возвратов
    LATEST @ >CFA       \ берет адрес codeword последнего слова
    !                   \ сохраняет адрес машинного кода в codeword создаваемого слова
;

: ;CODE
    ' (;CODE) ,      \ вкомпилить (;CODE) в определение
    [COMPILE] [      \ вкомпилить переход в immediate-режим
    \ ASSEMBLER         \ включить ассемблер (пока он всегда включен)
; IMMEDIATE          \ Это слово немедленного исполнения!

: END-CODE  ( -- )  \ Завершить ассемблерное определение
    LATEST @ HIDDEN EXIT
; IMMEDIATE

\ : DEFCONST
\     WORD    \ прочтем слово с stdin
\     CREATE  \ создадим заголовок слова
\     0 ,     \ вместо codeword вкомпилим заглушку-ноль
\     ,       \ скомпилируем param-field взяв его со стека (в нашем примере - 1337)
\
\     ;CODE   \ завершить высокоуровневый код и начать низкоуровневый
\
\     04 MOD-DISP-SHORT EAX EAX LEA        \   LEA   4(%EAX), %EAX
\     MOD-DISP-NONE EAX EAX MOV-R32,R/M32  \   MOV   (%EAX), %EAX
\     EAX PUSH                             \   PUSH  %EAX
\     NEXT                                 \   NEXT
\
\ END-CODE   \ завершить ассемблерное определение

\ 1337 DEFCONST PUSH1337



: DOES>
    ' (;CODE) ,                \ вкомпилить (;CODE) в определение
    0E8 C,                     \ вкомпилить байт опкода CALL
    DODOES_ADDR HERE @ 4+ - ,  \ относительное смещение к DODOES
; IMMEDIATE

\ : MAKE-CONST ( n -- )
\     WORD     \ прочтем слово с stdin
\     CREATE   \ создадим заголовок слова
\     0 ,      \ вместо codeword вкомпилим заглушку-ноль
\     ,        \ скомпилируем param-field взяв его со стека (в нашем примере - 1337)
\   DOES>      \ завершение "создающей" части, начало части "действия"
\     @        \ прочесть значение из param-field дочернего слова,
\              \ разыменовать для получения содержимого
\ ;

: DOFIELD \ Действие FIELD
  DOES>
    @        \ разыменовать значение из param-field дочернего слова, чтобы получить размер #
    +        \ и сложить его с вершиной стека
;

: FIELD ( # n ++ # )  \ Определение FIELD со смещением "#" и размером "n"
    WORD     \ прочтем слово с stdin
    CREATE   \ создадим заголовок слова
    0 ,      \ вместо codeword вкомпилим заглушку-ноль
    OVER     \ push-им копию размера # на вершину стека (# n # --)
    ,        \ скомпилируем размер в param-field взяв его со стека (# n --)
    +        \ сложим размер с текущим смещением
    DOFIELD
;

\ 0  \ Начальное смещение
\ 4 CHARS FIELD ALFA      \ Создана константа ALFA со значением 0
\ 3 CELLS FIELD BETA      \ Создана константа BETA со значением 4 [0+4]
\ 2 CELLS FIELD GAMMA     \ Создана константа GAMMA со значением 16 [4+(3*4)] (0x10)
\ \ В стеке осталось значение 24 [16+(2*4)] - это размер всей структуры (0x18)
\ \ Сохраним его в константу
\ CONSTANT FOO-SIZE

: STRUCT ( -- addr 0 ; -- size )
    WORD     \ прочтем слово с stdin
    CREATE   \ создадим заголовок слова
    0 ,      \ вместо codeword вкомпилим заглушку-ноль
    HERE @   \ оставим  для END-STRUCT в стеке адрес, на который указывает HERE
    0        \ оставим в стеке ноль в качестве начального размера структуры для FIELD
    0 ,      \ скомпилируем ноль в param-field дочернего слова как заглушку размера структуры
  DOES>      \ завершение "создающей" части, начало части "действия"
    @        \ прочесть значение из param-field дочернего слова,
             \ разыменовать для получения содержимого
;

: END-STRUCT ( addr size -- )
    SWAP ! \ сохранить размер по адресу
;

STRUCT point \ -- a-addr 0 ; -- length-of-point
    1 CELLS FIELD p.x             \ -- a-addr cell
    1 CELLS FIELD p.y             \ -- a-addr cell*2
END-STRUCT

STRUCT rect    \ -- a-addr 0 ; -- length-of-rect
    point FIELD r.top-left        \ -- a-addr cell*2
    point FIELD r.bottom-right    \ -- a-addr cell*4
END-STRUCT

LATEST @ @ @ 200 DUMP

: MOVEPIX
    BEGIN
        >R DUP >R
        U/MOD SWAP
        IF >R 2DUP >R >R ROT DUP >R 2SWAP SWAP DUP >R >R >R >R >R
            2DUP R> -ROT R> -ROT R> -ROT R> -ROT >R DROP -ROT >R >R SWAP R> SWAP R> SWAP
            SETPIX
            R> 1+ R> R> R> R> R>
        ELSE
            >R >R >R >R >R 1+ R>
            R> R> R> R>
        THEN
        R> R>
        1- DUP 0=
    UNTIL
    .S
    2DROP 2DROP 2DROP 2DROP
;

: DRAWPICTURE
    BEGIN
        SWAP >R 1- DUP 0=
        .S
    UNTIL
    BEGIN
        R> SWAP >R SWAP >R
        SWAP DUP >R 2SWAP DUP >R SWAP DUP
        >R >R 2SWAP SWAP DUP R> SWAP >R
        >R >R 2SWAP SWAP DUP R>
        SWAP R> SWAP >R
        >R >R >R 2SWAP SWAP DUP
        R> SWAP R> SWAP R> SWAP >R
        >R >R >R >R 2SWAP SWAP DUP
        R> SWAP R> SWAP R> SWAP R>
        SWAP >R
        >R >R >R >R 2SWAP >R ROT
        R> R> 2SWAP >R ROT
        R> R> 2SWAP >R ROT
        R> R> 2SWAP >R ROT
        R> R> 2SWAP >R ROT
        SWAP R> SWAP
        .S
        MOVEPIX
        R> R> 1+ R> R>
        R> R> R> R> R>
        1+
        2DUP =
    UNTIL
    2DROP 2DROP 2DROP 2DROP DROP
;

: BUBBLE    \ поднимает необходимый элемент стека наверх,
            \ порядок остальных сохраняется. Параметр=счетчик,
            \ на 1 меньше, чем порядковый номер искомого элемента
            \ в стеке, к примеру: ( a b c d e 3 -- a c d e b )

    DUP     \ дублировать счетчик a b c d e 3 3/cnt
    BEGIN   \ снять все элементы до искомого в стек возвратов
        ROT      \ a b c d 3 3/cnt e
        >R       \ a b c d 3 3/cnt        |R: e
        1-       \ a b c d 3 2/cnt        |R: e
        DUP      \ a b c d 3 2/cnt 2/cnt  |R: e
        0=       \ a b c d 3 2/cnt        |R: e
    UNTIL   \ a b 3 0 |R: e d c
    BEGIN   \ вернуть все элементы по одному, поднимая искомый наверх
        SWAP    \ a b 0 3       |R: e d c
        R>      \ a b 0 3 c     |R: e d
        SWAP    \ a b 0 c 3     |R: e d
        >R      \ a b 0 c       |R: e d 3
        -ROT    \ a c b 0       |R: e d 3
        R>      \ a c b 0 3     |R: e d
        SWAP    \ a c b 3 0     |R: e d
        1+      \ a c b 3 1     |R: e d
        2DUP    \ a c b 3 1 3 1 |R: e d
        =
    UNTIL   \ a c d e b 0 0
    2DROP   \ a c d e b
;

: MULTIBUBBLE   \ поднимает несколько элементов в стеке наверх
                \ параметры = счетчики для каждой итерации цикла
                \ BUBBLE + счетчик кол-ва итераций
                \ ( a b c d e 3 4 2 -- ? a b c d e b a  )

     DUP        \ Дублировать счетчик кол-ва итераций

     BEGIN
         ROT >R 1-    \  a b c d e f 1 3 2 |R: 3
         DUP          \  a b c d e f 1 3 2 2 |R: 3
         0=
     UNTIL
     BEGIN            \ a b c d e f 3
         R>
         -ROT >R >R
         BUBBLE
         R> R>
         1+ 2DUP =
     UNTIL
     2DROP
;

: COPYBUBBLE  \ копирует искомый элемент и поднимает копию наверх
              \ параметр = счетчик
    DUP       \дублировать счетчик
    BEGIN     \ снять все элементы до искомого в стек возвратов
        ROT >R
        1- DUP 0=
    UNTIL
    ROT DUP 2SWAP   \ копируем
    BEGIN     \ вернуть все элементы по одному, скопировав искомый
              \и подняв его наверх
        SWAP R> SWAP >R -ROT R> SWAP 1+    \ поднимаем
        2DUP =
    UNTIL
    2DROP
;

: COUNTER
    BEGIN      \ этот цикл должен проверить, сколько было итераций
        DUP 0=
        IF        \ если итераций было 0, значит, копий элементов тоже 0
                  \ значит, счетчики увеличивать не надо
            DROP EXIT  \ здесь должен был быть выход из цикла begin-again
        THEN
        DUP ROT   \ если итерация не нулевая, мы считаем, сколько
                  \ их было и пропорционально увеличиваем текущий счетчик
        1+
        SWAP 1-
        DUP
    AGAIN     \ повторять до тех пор, пока счетчик итераций !=0
    \ Possible Error: BEGIN-AGAIN do not have exit condition
;


: COPYMULTIBUBBLE \ A B C D E F 1 2 3 3(счетчик номеров)
    DUP           \ A B C D E F 1 2 3c 3b 3a
    BEGIN             \ отправить все счетчики в стек
        ROT           \ A B C D E F 1 2 3b 3a 3c
        >R 1-         \ A B C D E F 1 2 3b 3a  R: 3c
        1-            \ A B C D E F 1 2 3b 2a  R: 3c
        DUP 0=        \ ?: 2a == 0 | Possible Error: 3с stay on retstack
    UNTIL
    \ Какое ожидаемое состояние стека тут?
    BEGIN
        R> SWAP DUP
        COUNTER
        ROT >R >R \ подготовка стека для вызова COPYBUBBLE,
                  \ который принимает в качетве параметра
                  \ счетчик элементов, которые надо снять до искомого
                  \ элемента
        COPYBUBBLE
        R> R>
        SWAP 1+
        2DUP =  \ проверяем, все ли итерации пройдены
    UNTIL       \ повторить, если нет
   2DROP
;
