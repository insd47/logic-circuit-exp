module tlcd_controller(
    input wire RESETN,
    input wire CLK,
    input wire ENABLE,
    output reg TLCD_E,
    output reg TLCD_RS,
    output reg TLCD_RW,
    output reg [7:0] TLCD_DATA,
    input wire [8*16-1:0] TEXT_STRING_UPPER,
    input wire [8*16-1:0] TEXT_STRING_LOWER
);

    // 타이밍 파라미터를 크게 증가
    parameter E_PULSE_WIDTH = 200;    // 약 200µs
    parameter EXEC_TIME = 1000;       // 1ms 실행 시간
    parameter CLEAR_EXEC_TIME = 2000; // 2ms 이상
    parameter INIT_DELAY = 20000;     // 20ms 초기 대기

    // 상태 정의
    reg [5:0] STATE;
    parameter IDLE = 6'd0,
              INIT_WAIT = 6'd1,        // 초기 20ms 대기
              FUNCTION_SET1 = 6'd2,
              FUNCTION_SET1_WAIT = 6'd3,
              FUNCTION_SET2 = 6'd4,
              FUNCTION_SET2_WAIT = 6'd5,
              FUNCTION_SET3 = 6'd6,
              FUNCTION_SET3_WAIT = 6'd7,
              DISP_ONOFF = 6'd8,
              DISP_ONOFF_WAIT = 6'd9,
              ENTRY_MODE = 6'd10,
              ENTRY_MODE_WAIT = 6'd11,
              CLEAR_DISP = 6'd12,
              CLEAR_DISP_WAIT = 6'd13,
              LINE1_ADDR = 6'd14,
              LINE1_ADDR_WAIT = 6'd15,
              LINE1_WRITE = 6'd16,
              LINE1_WRITE_WAIT = 6'd17,
              LINE2_ADDR = 6'd18,
              LINE2_ADDR_WAIT = 6'd19,
              LINE2_WRITE = 6'd20,
              LINE2_WRITE_WAIT = 6'd21,
              DONE = 6'd22;

    reg [15:0] CNT;
    reg [4:0] char_index;
    reg prev_ENABLE;

    always @(posedge CLK or posedge RESETN) begin
        if (RESETN) begin
            STATE <= IDLE;
            CNT <= 0;
            char_index <= 0;
            prev_ENABLE <= 0;
            TLCD_E <= 1'b0;
            TLCD_RS <= 1'b0;
            TLCD_RW <= 1'b0;
            TLCD_DATA <= 8'b00000000;
        end else begin
            prev_ENABLE <= ENABLE;
            case (STATE)
                IDLE: begin
                    CNT <= 0;
                    TLCD_E <= 1'b0;
                    if (ENABLE && !prev_ENABLE) begin
                        STATE <= INIT_WAIT;
                    end
                end
                INIT_WAIT: begin
                    CNT <= CNT + 1;
                    if (CNT >= INIT_DELAY) begin
                        CNT <= 0;
                        STATE <= FUNCTION_SET1;
                    end
                end
                // Function Set #1
                FUNCTION_SET1: begin
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    // 8bit 2line 5x8dots
                    TLCD_DATA <= 8'b00111000;
                    TLCD_E <= 1'b1;
                    CNT <= 0;
                    STATE <= FUNCTION_SET1_WAIT;
                end
                FUNCTION_SET1_WAIT: begin
                    CNT <= CNT + 1;
                    if (CNT >= E_PULSE_WIDTH) TLCD_E <= 1'b0;
                    if (CNT >= EXEC_TIME) begin
                        CNT <= 0;
                        STATE <= FUNCTION_SET2;
                    end
                end
                // Function Set #2
                FUNCTION_SET2: begin
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b00111000;
                    TLCD_E <= 1'b1;
                    CNT <= 0;
                    STATE <= FUNCTION_SET2_WAIT;
                end
                FUNCTION_SET2_WAIT: begin
                    CNT <= CNT + 1;
                    if (CNT >= E_PULSE_WIDTH) TLCD_E <= 1'b0;
                    if (CNT >= EXEC_TIME) begin
                        CNT <= 0;
                        STATE <= FUNCTION_SET3;
                    end
                end
                // Function Set #3
                FUNCTION_SET3: begin
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b00111000;
                    TLCD_E <= 1'b1;
                    CNT <= 0;
                    STATE <= FUNCTION_SET3_WAIT;
                end
                FUNCTION_SET3_WAIT: begin
                    CNT <= CNT + 1;
                    if (CNT >= E_PULSE_WIDTH) TLCD_E <= 1'b0;
                    if (CNT >= EXEC_TIME) begin
                        CNT <= 0;
                        STATE <= DISP_ONOFF;
                    end
                end

                DISP_ONOFF: begin
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b00001100; // Display ON, Cursor OFF
                    TLCD_E <= 1'b1;
                    CNT <= 0;
                    STATE <= DISP_ONOFF_WAIT;
                end
                DISP_ONOFF_WAIT: begin
                    CNT <= CNT + 1;
                    if (CNT >= E_PULSE_WIDTH) TLCD_E <= 1'b0;
                    if (CNT >= EXEC_TIME) begin
                        CNT <= 0;
                        STATE <= ENTRY_MODE;
                    end
                end
                ENTRY_MODE: begin
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b00000110; // Entry Mode Set
                    TLCD_E <= 1'b1;
                    CNT <= 0;
                    STATE <= ENTRY_MODE_WAIT;
                end
                ENTRY_MODE_WAIT: begin
                    CNT <= CNT + 1;
                    if (CNT >= E_PULSE_WIDTH) TLCD_E <= 1'b0;
                    if (CNT >= EXEC_TIME) begin
                        CNT <= 0;
                        STATE <= CLEAR_DISP;
                    end
                end
                CLEAR_DISP: begin
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b00000001; // Clear Display
                    TLCD_E <= 1'b1;
                    CNT <= 0;
                    STATE <= CLEAR_DISP_WAIT;
                end
                CLEAR_DISP_WAIT: begin
                    CNT <= CNT + 1;
                    if (CNT >= E_PULSE_WIDTH) TLCD_E <= 1'b0;
                    if (CNT >= CLEAR_EXEC_TIME) begin
                        CNT <= 0;
                        STATE <= LINE1_ADDR;
                    end
                end
                LINE1_ADDR: begin
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b10000000; // Line 1 start
                    TLCD_E <= 1'b1;
                    CNT <= 0;
                    STATE <= LINE1_ADDR_WAIT;
                end
                LINE1_ADDR_WAIT: begin
                    CNT <= CNT + 1;
                    if (CNT >= E_PULSE_WIDTH) TLCD_E <= 1'b0;
                    if (CNT >= EXEC_TIME) begin
                        CNT <= 0;
                        char_index <= 0;
                        STATE <= LINE1_WRITE;
                    end
                end
                LINE1_WRITE: begin
                    if (char_index < 16) begin
                        TLCD_RS <= 1'b1;
                        TLCD_RW <= 1'b0;
                        TLCD_DATA <= TEXT_STRING_UPPER[(15 - char_index)*8 +:8];
                        TLCD_E <= 1'b1;
                        CNT <= 0;
                        STATE <= LINE1_WRITE_WAIT;
                    end else begin
                        STATE <= LINE2_ADDR;
                    end
                end
                LINE1_WRITE_WAIT: begin
                    CNT <= CNT + 1;
                    if (CNT >= E_PULSE_WIDTH) TLCD_E <= 1'b0;
                    if (CNT >= EXEC_TIME) begin
                        CNT <= 0;
                        char_index <= char_index + 1;
                        STATE <= LINE1_WRITE;
                    end
                end
                LINE2_ADDR: begin
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b11000000; // Line 2 start
                    TLCD_E <= 1'b1;
                    CNT <= 0;
                    STATE <= LINE2_ADDR_WAIT;
                end
                LINE2_ADDR_WAIT: begin
                    CNT <= CNT + 1;
                    if (CNT >= E_PULSE_WIDTH) TLCD_E <= 1'b0;
                    if (CNT >= EXEC_TIME) begin
                        CNT <= 0;
                        char_index <= 0;
                        STATE <= LINE2_WRITE;
                    end
                end
                LINE2_WRITE: begin
                    if (char_index < 16) begin
                        TLCD_RS <= 1'b1;
                        TLCD_RW <= 1'b0;
                        TLCD_DATA <= TEXT_STRING_LOWER[(15 - char_index)*8 +:8];
                        TLCD_E <= 1'b1;
                        CNT <= 0;
                        STATE <= LINE2_WRITE_WAIT;
                    end else begin
                        STATE <= DONE;
                    end
                end
                LINE2_WRITE_WAIT: begin
                    CNT <= CNT + 1;
                    if (CNT >= E_PULSE_WIDTH) TLCD_E <= 1'b0;
                    if (CNT >= EXEC_TIME) begin
                        CNT <= 0;
                        char_index <= char_index + 1;
                        STATE <= LINE2_WRITE;
                    end
                end
                DONE: begin
                    STATE <= IDLE;
                end
                default: STATE <= IDLE;
            endcase
        end
    end

endmodule