module tlcd_controller(
    input wire RESETN,                      // Active low reset
    input wire CLK,                         // System clock
    input wire ENABLE,                      // Start signal
    output reg TLCD_E,                      // LCD E pin
    output reg TLCD_RS,                     // LCD RS pin
    output reg TLCD_RW,                     // LCD RW pin
    output reg [7:0] TLCD_DATA,             // LCD data bus
    input wire [8*16-1:0] TEXT_STRING_UPPER,// Upper line text (16 bytes)
    input wire [8*16-1:0] TEXT_STRING_LOWER // Lower line text (16 bytes)
);

    // State definition
    reg [3:0] STATE;
    parameter IDLE = 4'd0,
              FUNCTION_SET = 4'd1,
              FUNCTION_SET_WAIT = 4'd2,
              DISP_ONOFF = 4'd3,
              DISP_ONOFF_WAIT = 4'd4,
              ENTRY_MODE = 4'd5,
              ENTRY_MODE_WAIT = 4'd6,
              LINE1_ADDR = 4'd7,
              LINE1_ADDR_WAIT = 4'd8,
              LINE1_WRITE = 4'd9,
              LINE1_WRITE_WAIT = 4'd10,
              LINE2_ADDR = 4'd11,
              LINE2_ADDR_WAIT = 4'd12,
              LINE2_WRITE = 4'd13,
              LINE2_WRITE_WAIT = 4'd14,
              DONE = 4'd15;

    reg [15:0] CNT;
    reg [4:0] char_index;
    reg prev_ENABLE;

    // State machine and control signals
    always @(posedge CLK or posedge RESETN) begin
        if (RESETN) begin
            STATE <= IDLE;
            CNT <= 0;
            char_index <= 0;
            prev_ENABLE <= 0;
            TLCD_E <= 1'b0;
            TLCD_RS <= 1'b1;
            TLCD_RW <= 1'b1;
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
                    if (CNT == 1) begin
                        TLCD_E <= 1'b0;
                        STATE <= DISP_ONOFF;
                    end else begin
                        CNT <= CNT + 1;
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
                    if (CNT == 1) begin
                        TLCD_E <= 1'b0;
                        STATE <= ENTRY_MODE;
                    end else begin
                        CNT <= CNT + 1;
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
                    if (CNT == 1) begin
                        TLCD_E <= 1'b0;
                        STATE <= LINE1_ADDR;
                    end else begin
                        CNT <= CNT + 1;
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
                    if (CNT == 1) begin
                        TLCD_E <= 1'b0;
                        CNT <= 0;
                        char_index <= 0;
                        STATE <= LINE1_WRITE;
                    end else begin
                        CNT <= CNT + 1;
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
                    if (CNT == 1) begin
                        TLCD_E <= 1'b0;
                        char_index <= char_index + 1;
                        STATE <= LINE1_WRITE;
                    end else begin
                        CNT <= CNT + 1;
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
                    if (CNT == 1) begin
                        TLCD_E <= 1'b0;
                        CNT <= 0;
                        char_index <= 0;
                        STATE <= LINE2_WRITE;
                    end else begin
                        CNT <= CNT + 1;
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
                    if (CNT == 1) begin
                        TLCD_E <= 1'b0;
                        char_index <= char_index + 1;
                        STATE <= LINE2_WRITE;
                    end else begin
                        CNT <= CNT + 1;
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