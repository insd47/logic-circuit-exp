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
    reg [3:0] STATE;
    parameter INIT = 4'd0, FUNCTION_SET = 4'd1, DISP_ONOFF = 4'd2, ENTRY_MODE = 4'd3,
              CLEAR_DISP = 4'd4, RETURN_HOME = 4'd5, LINE1 = 4'd6, LINE1_WAIT = 4'd7,
              LINE2 = 4'd8, LINE2_WAIT = 4'd9, DONE = 4'd10;

    reg [4:0] CNT; // 문자 전송을 위한 카운터 (0~16)
    reg [15:0] delay_cnt; // 딜레이를 위한 카운터

    // 타이밍 상수 (5kHz 클럭에서 딜레이 시간 계산)
    parameter DELAY_2MS = 16'd10;      // 약 2ms 딜레이 (200µs x 10 = 2ms)
    parameter DELAY_40US = 16'd1;      // 약 40µs 딜레이 (200µs x 1 = 200µs > 40µs, 최소 1클럭 대기)
    parameter DELAY_EXEC = 16'd1;      // 명령어 실행 시간 대기
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
                INIT: begin
                    if (delay_cnt < DELAY_2MS) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt <= 0;
                        STATE <= FUNCTION_SET;
                    end
                end
                FUNCTION_SET: begin
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b00111000; // Function Set: 8-bit, 2 Line, 5x8 Dots
                    TLCD_E <= 1'b1;
                    STATE <= FUNCTION_SET + 1;
                end
                FUNCTION_SET + 1: begin
                    TLCD_E <= 1'b0;
                    if (delay_cnt < DELAY_EXEC) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt <= 0;
                        STATE <= DISP_ONOFF;
                    end
                end
                DISP_ONOFF: begin
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b00001100; // Display ON, Cursor OFF
                    TLCD_E <= 1'b1;
                    STATE <= DISP_ONOFF + 1;
                end
                DISP_ONOFF + 1: begin
                    TLCD_E <= 1'b0;
                    if (delay_cnt < DELAY_EXEC) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt <= 0;
                        STATE <= ENTRY_MODE;
                    end
                end
                ENTRY_MODE: begin
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b00000110; // Entry Mode: Increment, No Shift
                    TLCD_E <= 1'b1;
                    STATE <= ENTRY_MODE + 1;
                end
                ENTRY_MODE + 1: begin
                    TLCD_E <= 1'b0;
                    if (delay_cnt < DELAY_EXEC) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt <= 0;
                        STATE <= CLEAR_DISP;
                    end
                end
                CLEAR_DISP: begin
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b00000001; // Clear Display
                    TLCD_E <= 1'b1;
                    STATE <= CLEAR_DISP + 1;
                end
                CLEAR_DISP + 1: begin
                    TLCD_E <= 1'b0;
                    if (delay_cnt < DELAY_CLR) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt <= 0;
                        STATE <= RETURN_HOME;
                    end
                end
                RETURN_HOME: begin
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b00000010; // Return Home
                    TLCD_E <= 1'b1;
                    STATE <= RETURN_HOME + 1;
                end
                RETURN_HOME + 1: begin
                    TLCD_E <= 1'b0;
                    if (delay_cnt < DELAY_CLR) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt <= 0;
                        CNT <= 0;
                        STATE <= LINE1;
                    end
                end
                LINE1: begin
                    // DDRAM 주소 설정 (라인 1)
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b10000000; // Line 1 시작 주소
                    TLCD_E <= 1'b1;
                    STATE <= LINE1_WAIT;
                end
                LINE1_WAIT: begin
                    TLCD_E <= 1'b0;
                    if (delay_cnt < DELAY_EXEC) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt <= 0;
                        STATE <= LINE1 + 2;
                    end
                end
                LINE1 + 2: begin
                    if (CNT < 16) begin
                        TLCD_RS <= 1'b1;
                        TLCD_RW <= 1'b0;
                        TLCD_DATA <= TEXT_STRING_UPPER[(15 - CNT)*8 +: 8];
                        TLCD_E <= 1'b1;
                        STATE <= LINE1 + 3;
                    end else begin
                        CNT <= 0;
                        STATE <= LINE2;
                    end
                end
                LINE1 + 3: begin
                    TLCD_E <= 1'b0;
                    if (delay_cnt < DELAY_EXEC) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt <= 0;
                        CNT <= CNT + 1;
                        STATE <= LINE1 + 2;
                    end
                end
                LINE2: begin
                    // DDRAM 주소 설정 (라인 2)
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b11000000; // Line 2 시작 주소
                    TLCD_E <= 1'b1;
                    STATE <= LINE2_WAIT;
                end
                LINE2_WAIT: begin
                    TLCD_E <= 1'b0;
                    if (delay_cnt < DELAY_EXEC) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt <= 0;
                        STATE <= LINE2 + 2;
                    end
                end
                LINE2 + 2: begin
                    if (CNT < 16) begin
                        TLCD_RS <= 1'b1;
                        TLCD_RW <= 1'b0;
                        TLCD_DATA <= TEXT_STRING_LOWER[(15 - CNT)*8 +: 8];
                        TLCD_E <= 1'b1;
                        STATE <= LINE2 + 3;
                    end else begin
                        CNT <= 0;
                        STATE <= DONE;
                    end
                end
                LINE2 + 3: begin
                    TLCD_E <= 1'b0;
                    if (delay_cnt < DELAY_EXEC) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt <= 0;
                        CNT <= CNT + 1;
                        STATE <= LINE2 + 2;
                    end
                end
                DONE: begin
                    // 모든 작업 완료
                    // 필요한 경우 화면을 주기적으로 갱신하거나 다른 동작을 추가할 수 있습니다.
                    // 여기서는 상태를 유지합니다.
                end
                default: STATE <= INIT;
            endcase
        end
    end

endmodule