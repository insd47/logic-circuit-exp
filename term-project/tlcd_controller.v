module tlcd_controller(
    input wire RESETN,                      // Active low reset
    input wire CLK,                         // System clock (1 MHz)
    input wire ENABLE,                      // Start signal
    output reg TLCD_E,                      // LCD E pin
    output reg TLCD_RS,                     // LCD RS pin
    output reg TLCD_RW,                     // LCD RW pin
    output reg [7:0] TLCD_DATA,             // LCD data bus
    input wire [8*16-1:0] TEXT_STRING_UPPER,// Upper line text (16 bytes)
    input wire [8*16-1:0] TEXT_STRING_LOWER // Lower line text (16 bytes)
);

    // Timing parameters (in clock cycles)
    parameter E_PULSE_WIDTH = 1;    // 1 μs pulse width for E
    parameter EXEC_TIME = 40;       // 40 μs execution time for most commands
    parameter CLEAR_EXEC_TIME = 1640; // 1.64 ms execution time for clear display

    // State definition
    reg [4:0] STATE;
    parameter IDLE = 5'd0,
              FUNCTION_SET = 5'd1,
              FUNCTION_SET_WAIT = 5'd2,
              DISP_ONOFF = 5'd3,
              DISP_ONOFF_WAIT = 5'd4,
              ENTRY_MODE = 5'd5,
              ENTRY_MODE_WAIT = 5'd6,
              CLEAR_DISP = 5'd7,
              CLEAR_DISP_WAIT = 5'd8,
              LINE1_ADDR = 5'd9,
              LINE1_ADDR_WAIT = 5'd10,
              LINE1_WRITE = 5'd11,
              LINE1_WRITE_WAIT = 5'd12,
              LINE2_ADDR = 5'd13,
              LINE2_ADDR_WAIT = 5'd14,
              LINE2_WRITE = 5'd15,
              LINE2_WRITE_WAIT = 5'd16,
              DONE = 5'd17;

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
                        STATE <= FUNCTION_SET;
                    end
                end
                FUNCTION_SET: begin
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b00111000; // Function Set command
                    TLCD_E <= 1'b1;
                    CNT <= 0;
                    STATE <= FUNCTION_SET_WAIT;
                end
                FUNCTION_SET_WAIT: begin
                    CNT <= CNT + 1;
                    if (CNT >= E_PULSE_WIDTH) begin
                        TLCD_E <= 1'b0;
                    end
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
                    if (CNT >= E_PULSE_WIDTH) begin
                        TLCD_E <= 1'b0;
                    end
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
                    if (CNT >= E_PULSE_WIDTH) begin
                        TLCD_E <= 1'b0;
                    end
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
                    if (CNT >= E_PULSE_WIDTH) begin
                        TLCD_E <= 1'b0;
                    end
                    if (CNT >= CLEAR_EXEC_TIME) begin
                        CNT <= 0;
                        STATE <= LINE1_ADDR;
                    end
                end
                LINE1_ADDR: begin
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b10000000; // Line 1 starting address
                    TLCD_E <= 1'b1;
                    CNT <= 0;
                    STATE <= LINE1_ADDR_WAIT;
                end
                LINE1_ADDR_WAIT: begin
                    CNT <= CNT + 1;
                    if (CNT >= E_PULSE_WIDTH) begin
                        TLCD_E <= 1'b0;
                    end
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
                    if (CNT >= E_PULSE_WIDTH) begin
                        TLCD_E <= 1'b0;
                    end
                    if (CNT >= EXEC_TIME) begin
                        CNT <= 0;
                        char_index <= char_index + 1;
                        STATE <= LINE1_WRITE;
                    end
                end
                LINE2_ADDR: begin
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b11000000; // Line 2 starting address
                    TLCD_E <= 1'b1;
                    CNT <= 0;
                    STATE <= LINE2_ADDR_WAIT;
                end
                LINE2_ADDR_WAIT: begin
                    CNT <= CNT + 1;
                    if (CNT >= E_PULSE_WIDTH) begin
                        TLCD_E <= 1'b0;
                    end
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
                    if (CNT >= E_PULSE_WIDTH) begin
                        TLCD_E <= 1'b0;
                    end
                    if (CNT >= EXEC_TIME) begin
                        CNT <= 0;
                        char_index <= char_index + 1;
                        STATE <= LINE2_WRITE;
                    end
                end
                DONE: begin
                    // Update complete, return to IDLE or wait for next ENABLE
                    STATE <= IDLE;
                end
                default: begin
                    STATE <= IDLE;
                end
            endcase
        end
    end

endmodule