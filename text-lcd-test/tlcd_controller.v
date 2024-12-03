module tlcd_controller(
    input wire RESETN,                      // Active Low reset
    input wire CLK,                         // 5kHz system clock
    output reg TLCD_E,                      // LCD E pin
    output reg TLCD_RS,                     // LCD RS pin
    output reg TLCD_RW,                     // LCD RW pin
    output reg [7:0] TLCD_DATA,             // LCD data bus
    input wire [8*16-1:0] TEXT_STRING_UPPER,// Upper line text (16 bytes)
    input wire [8*16-1:0] TEXT_STRING_LOWER // Lower line text (16 bytes)
);

    // 상태 정의
    reg [5:0] STATE;
    parameter INIT = 6'd0,
              FUNCTION_SET = 6'd1, FUNCTION_SET_WAIT = 6'd2,
              FUNCTION_SET_E_HIGH = 6'd3, FUNCTION_SET_E_HIGH_WAIT = 6'd4,
              FUNCTION_SET_E_LOW = 6'd5, FUNCTION_SET_EXEC = 6'd6,

              DISP_ONOFF = 6'd7, DISP_ONOFF_WAIT = 6'd8,
              DISP_ONOFF_E_HIGH = 6'd9, DISP_ONOFF_E_HIGH_WAIT = 6'd10,
              DISP_ONOFF_E_LOW = 6'd11, DISP_ONOFF_EXEC = 6'd12,

              ENTRY_MODE = 6'd13, ENTRY_MODE_WAIT = 6'd14,
              ENTRY_MODE_E_HIGH = 6'd15, ENTRY_MODE_E_HIGH_WAIT = 6'd16,
              ENTRY_MODE_E_LOW = 6'd17, ENTRY_MODE_EXEC = 6'd18,

              CLEAR_DISP = 6'd19, CLEAR_DISP_WAIT = 6'd20,
              CLEAR_DISP_E_HIGH = 6'd21, CLEAR_DISP_E_HIGH_WAIT = 6'd22,
              CLEAR_DISP_E_LOW = 6'd23, CLEAR_DISP_EXEC = 6'd24,

              LINE1_SET_ADDR = 6'd25, LINE1_SET_ADDR_WAIT = 6'd26,
              LINE1_SET_ADDR_E_HIGH = 6'd27, LINE1_SET_ADDR_E_HIGH_WAIT = 6'd28,
              LINE1_SET_ADDR_E_LOW = 6'd29, LINE1_SET_ADDR_EXEC = 6'd30,

              LINE1_WRITE_CHAR = 6'd31, LINE1_WRITE_CHAR_WAIT = 6'd32,
              LINE1_WRITE_CHAR_E_HIGH = 6'd33, LINE1_WRITE_CHAR_E_HIGH_WAIT = 6'd34,
              LINE1_WRITE_CHAR_E_LOW = 6'd35, LINE1_WRITE_CHAR_EXEC = 6'd36,

              LINE2_SET_ADDR = 6'd37, LINE2_SET_ADDR_WAIT = 6'd38,
              LINE2_SET_ADDR_E_HIGH = 6'd39, LINE2_SET_ADDR_E_HIGH_WAIT = 6'd40,
              LINE2_SET_ADDR_E_LOW = 6'd41, LINE2_SET_ADDR_EXEC = 6'd42,

              LINE2_WRITE_CHAR = 6'd43, LINE2_WRITE_CHAR_WAIT = 6'd44,
              LINE2_WRITE_CHAR_E_HIGH = 6'd45, LINE2_WRITE_CHAR_E_HIGH_WAIT = 6'd46,
              LINE2_WRITE_CHAR_E_LOW = 6'd47, LINE2_WRITE_CHAR_EXEC = 6'd48,

              DONE = 6'd49;

    reg [4:0] CNT; // 문자 전송을 위한 카운터 (0~15)
    reg [15:0] delay_cnt; // 딜레이를 위한 카운터

    // 타이밍 상수 (5kHz 클럭에서 딜레이 시간 계산)
    parameter DELAY_15MS = 16'd75;     // 약 15ms 딜레이 (200µs x 75 = 15ms)
    parameter DELAY_5MS = 16'd25;      // 약 5ms 딜레이 (200µs x 25 = 5ms)
    parameter DELAY_2MS = 16'd10;      // 약 2ms 딜레이
    parameter DELAY_1MS = 16'd5;       // 약 1ms 딜레이
    parameter DELAY_40US = 16'd1;      // 최소 1클럭 대기
    parameter DELAY_EXEC = 16'd2;      // 명령어 실행 시간 대기 (보통 37us 이상)
    parameter DELAY_CLR = 16'd10;      // 클리어 딜레이 (1.64ms 이상)

    always @(posedge CLK or negedge RESETN) begin
        if (!RESETN) begin
            STATE <= INIT;
            CNT <= 0;
            delay_cnt <= 0;
            TLCD_E <= 1'b0;
            TLCD_RS <= 1'b0;
            TLCD_RW <= 1'b0;
            TLCD_DATA <= 8'b00000000;
        end else begin
            case (STATE)
                // 초기화 딜레이
                INIT: begin
                    if (delay_cnt < DELAY_15MS) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt <= 0;
                        STATE <= FUNCTION_SET;
                    end
                end
                // Function Set 명령어 전송
                FUNCTION_SET: begin
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b00111000;
                    STATE <= FUNCTION_SET_WAIT;
                end
                FUNCTION_SET_WAIT: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_40US) begin
                        delay_cnt <= 0;
                        STATE <= FUNCTION_SET_E_HIGH;
                    end
                end
                FUNCTION_SET_E_HIGH: begin
                    TLCD_E <= 1'b1;
                    STATE <= FUNCTION_SET_E_HIGH_WAIT;
                end
                FUNCTION_SET_E_HIGH_WAIT: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_40US) begin
                        delay_cnt <= 0;
                        STATE <= FUNCTION_SET_E_LOW;
                    end
                end
                FUNCTION_SET_E_LOW: begin
                    TLCD_E <= 1'b0;
                    STATE <= FUNCTION_SET_EXEC;
                end
                FUNCTION_SET_EXEC: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_EXEC) begin
                        delay_cnt <= 0;
                        STATE <= DISP_ONOFF;
                    end
                end
                // Display On/Off Control 명령어 전송
                DISP_ONOFF: begin
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b00001100;
                    STATE <= DISP_ONOFF_WAIT;
                end
                DISP_ONOFF_WAIT: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_40US) begin
                        delay_cnt <= 0;
                        STATE <= DISP_ONOFF_E_HIGH;
                    end
                end
                DISP_ONOFF_E_HIGH: begin
                    TLCD_E <= 1'b1;
                    STATE <= DISP_ONOFF_E_HIGH_WAIT;
                end
                DISP_ONOFF_E_HIGH_WAIT: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_40US) begin
                        delay_cnt <= 0;
                        STATE <= DISP_ONOFF_E_LOW;
                    end
                end
                DISP_ONOFF_E_LOW: begin
                    TLCD_E <= 1'b0;
                    STATE <= DISP_ONOFF_EXEC;
                end
                DISP_ONOFF_EXEC: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_EXEC) begin
                        delay_cnt <= 0;
                        STATE <= ENTRY_MODE;
                    end
                end
                // Entry Mode Set 명령어 전송
                ENTRY_MODE: begin
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b00000110;
                    STATE <= ENTRY_MODE_WAIT;
                end
                ENTRY_MODE_WAIT: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_40US) begin
                        delay_cnt <= 0;
                        STATE <= ENTRY_MODE_E_HIGH;
                    end
                end
                ENTRY_MODE_E_HIGH: begin
                    TLCD_E <= 1'b1;
                    STATE <= ENTRY_MODE_E_HIGH_WAIT;
                end
                ENTRY_MODE_E_HIGH_WAIT: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_40US) begin
                        delay_cnt <= 0;
                        STATE <= ENTRY_MODE_E_LOW;
                    end
                end
                ENTRY_MODE_E_LOW: begin
                    TLCD_E <= 1'b0;
                    STATE <= ENTRY_MODE_EXEC;
                end
                ENTRY_MODE_EXEC: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_EXEC) begin
                        delay_cnt <= 0;
                        STATE <= CLEAR_DISP;
                    end
                end
                // Clear Display 명령어 전송
                CLEAR_DISP: begin
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b00000001;
                    STATE <= CLEAR_DISP_WAIT;
                end
                CLEAR_DISP_WAIT: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_40US) begin
                        delay_cnt <= 0;
                        STATE <= CLEAR_DISP_E_HIGH;
                    end
                end
                CLEAR_DISP_E_HIGH: begin
                    TLCD_E <= 1'b1;
                    STATE <= CLEAR_DISP_E_HIGH_WAIT;
                end
                CLEAR_DISP_E_HIGH_WAIT: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_40US) begin
                        delay_cnt <= 0;
                        STATE <= CLEAR_DISP_E_LOW;
                    end
                end
                CLEAR_DISP_E_LOW: begin
                    TLCD_E <= 1'b0;
                    STATE <= CLEAR_DISP_EXEC;
                end
                CLEAR_DISP_EXEC: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_CLR) begin
                        delay_cnt <= 0;
                        CNT <= 0;
                        STATE <= LINE1_SET_ADDR;
                    end
                end
                // Line 1 주소 설정
                LINE1_SET_ADDR: begin
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b10000000; // Line 1 시작 주소
                    STATE <= LINE1_SET_ADDR_WAIT;
                end
                LINE1_SET_ADDR_WAIT: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_40US) begin
                        delay_cnt <= 0;
                        STATE <= LINE1_SET_ADDR_E_HIGH;
                    end
                end
                LINE1_SET_ADDR_E_HIGH: begin
                    TLCD_E <= 1'b1;
                    STATE <= LINE1_SET_ADDR_E_HIGH_WAIT;
                end
                LINE1_SET_ADDR_E_HIGH_WAIT: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_40US) begin
                        delay_cnt <= 0;
                        STATE <= LINE1_SET_ADDR_E_LOW;
                    end
                end
                LINE1_SET_ADDR_E_LOW: begin
                    TLCD_E <= 1'b0;
                    STATE <= LINE1_SET_ADDR_EXEC;
                end
                LINE1_SET_ADDR_EXEC: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_EXEC) begin
                        delay_cnt <= 0;
                        STATE <= LINE1_WRITE_CHAR;
                    end
                end
                // Line 1 문자 쓰기
                LINE1_WRITE_CHAR: begin
                    if (CNT < 16) begin
                        TLCD_RS <= 1'b1;
                        TLCD_RW <= 1'b0;
                        TLCD_DATA <= TEXT_STRING_UPPER[(15 - CNT)*8 +: 8];
                        STATE <= LINE1_WRITE_CHAR_WAIT;
                    end else begin
                        CNT <= 0;
                        STATE <= LINE2_SET_ADDR;
                    end
                end
                LINE1_WRITE_CHAR_WAIT: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_40US) begin
                        delay_cnt <= 0;
                        STATE <= LINE1_WRITE_CHAR_E_HIGH;
                    end
                end
                LINE1_WRITE_CHAR_E_HIGH: begin
                    TLCD_E <= 1'b1;
                    STATE <= LINE1_WRITE_CHAR_E_HIGH_WAIT;
                end
                LINE1_WRITE_CHAR_E_HIGH_WAIT: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_40US) begin
                        delay_cnt <= 0;
                        STATE <= LINE1_WRITE_CHAR_E_LOW;
                    end
                end
                LINE1_WRITE_CHAR_E_LOW: begin
                    TLCD_E <= 1'b0;
                    STATE <= LINE1_WRITE_CHAR_EXEC;
                end
                LINE1_WRITE_CHAR_EXEC: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_EXEC) begin
                        delay_cnt <= 0;
                        CNT <= CNT + 1;
                        STATE <= LINE1_WRITE_CHAR;
                    end
                end
                // Line 2 주소 설정
                LINE2_SET_ADDR: begin
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b11000000; // Line 2 시작 주소
                    STATE <= LINE2_SET_ADDR_WAIT;
                end
                LINE2_SET_ADDR_WAIT: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_40US) begin
                        delay_cnt <= 0;
                        STATE <= LINE2_SET_ADDR_E_HIGH;
                    end
                end
                LINE2_SET_ADDR_E_HIGH: begin
                    TLCD_E <= 1'b1;
                    STATE <= LINE2_SET_ADDR_E_HIGH_WAIT;
                end
                LINE2_SET_ADDR_E_HIGH_WAIT: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_40US) begin
                        delay_cnt <= 0;
                        STATE <= LINE2_SET_ADDR_E_LOW;
                    end
                end
                LINE2_SET_ADDR_E_LOW: begin
                    TLCD_E <= 1'b0;
                    STATE <= LINE2_SET_ADDR_EXEC;
                end
                LINE2_SET_ADDR_EXEC: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_EXEC) begin
                        delay_cnt <= 0;
                        STATE <= LINE2_WRITE_CHAR;
                    end
                end
                // Line 2 문자 쓰기
                LINE2_WRITE_CHAR: begin
                    if (CNT < 16) begin
                        TLCD_RS <= 1'b1;
                        TLCD_RW <= 1'b0;
                        TLCD_DATA <= TEXT_STRING_LOWER[(15 - CNT)*8 +: 8];
                        STATE <= LINE2_WRITE_CHAR_WAIT;
                    end else begin
                        CNT <= 0;
                        STATE <= DONE;
                    end
                end
                LINE2_WRITE_CHAR_WAIT: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_40US) begin
                        delay_cnt <= 0;
                        STATE <= LINE2_WRITE_CHAR_E_HIGH;
                    end
                end
                LINE2_WRITE_CHAR_E_HIGH: begin
                    TLCD_E <= 1'b1;
                    STATE <= LINE2_WRITE_CHAR_E_HIGH_WAIT;
                end
                LINE2_WRITE_CHAR_E_HIGH_WAIT: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_40US) begin
                        delay_cnt <= 0;
                        STATE <= LINE2_WRITE_CHAR_E_LOW;
                    end
                end
                LINE2_WRITE_CHAR_E_LOW: begin
                    TLCD_E <= 1'b0;
                    STATE <= LINE2_WRITE_CHAR_EXEC;
                end
                LINE2_WRITE_CHAR_EXEC: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= DELAY_EXEC) begin
                        delay_cnt <= 0;
                        CNT <= CNT + 1;
                        STATE <= LINE2_WRITE_CHAR;
                    end
                end
                // 완료 상태
                DONE: begin
                    // 모든 작업 완료
                end
                default: STATE <= INIT;
            endcase
        end
    end

endmodule