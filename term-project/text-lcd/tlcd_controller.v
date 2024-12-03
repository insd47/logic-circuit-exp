module tlcd_controller(
    input wire RESETN,                      // Active low reset
    input wire CLK,                         // System clock
    output wire TLCD_E,                     // LCD E pin
    output reg TLCD_RS,                     // LCD RS pin
    output reg TLCD_RW,                     // LCD RW pin
    output reg [7:0] TLCD_DATA,             // LCD data bus
    input wire [8*16-1:0] TEXT_STRING_UPPER,// Upper line text (16 bytes)
    input wire [8*16-1:0] TEXT_STRING_LOWER // Lower line text (16 bytes)
);

    // State definition
    reg [2:0] STATE;
    parameter DELAY = 3'b000, FUNCTION_SET = 3'b001,
              ENTRY_MODE = 3'b010, DISP_ONOFF = 3'b011,
              LINE1 = 3'b100, LINE2 = 3'b101,
              DELAY_T = 3'b110, CLEAR_DISP = 3'b111;

    integer CNT;

    // LCD_E pin is directly connected to CLK
    assign TLCD_E = CLK;

    // State machine
    always @(posedge RESETN or posedge CLK) begin
        if (RESETN)
            STATE <= DELAY;
        else begin
            case (STATE)
                DELAY:
                    if (CNT == 70) STATE <= FUNCTION_SET;
                FUNCTION_SET:
                    if (CNT == 30) STATE <= DISP_ONOFF;
                DISP_ONOFF:
                    if (CNT == 30) STATE <= ENTRY_MODE;
                ENTRY_MODE:
                    if (CNT == 30) STATE <= LINE1;
                LINE1:
                    if (CNT == 16) STATE <= LINE2;
                LINE2:
                    if (CNT == 16) STATE <= DELAY_T;
                DELAY_T:
                    if (CNT == 100) STATE <= CLEAR_DISP;
                CLEAR_DISP:
                    if (CNT == 30) STATE <= LINE1;
                default:
                    STATE <= DELAY;
            endcase
        end
    end

    // Counter
    always @(posedge RESETN or posedge CLK) begin
        if (RESETN)
            CNT <= 0;
        else begin
            case (STATE)
                DELAY:
                    if (CNT >= 70) CNT <= 0;
                    else CNT <= CNT + 1;
                FUNCTION_SET:
                    if (CNT >= 30) CNT <= 0;
                    else CNT <= CNT + 1;
                DISP_ONOFF:
                    if (CNT >= 30) CNT <= 0;
                    else CNT <= CNT + 1;
                ENTRY_MODE:
                    if (CNT >= 30) CNT <= 0;
                    else CNT <= CNT + 1;
                LINE1:
                    if (CNT >= 16) CNT <= 0;
                    else CNT <= CNT + 1;
                LINE2:
                    if (CNT >= 16) CNT <= 0;
                    else CNT <= CNT + 1;
                DELAY_T:
                    if (CNT >= 100) CNT <= 0;
                    else CNT <= CNT + 1;
                CLEAR_DISP:
                    if (CNT >= 30) CNT <= 0;
                    else CNT <= CNT + 1;
                default:
                    CNT <= 0;
            endcase
        end
    end

    // LCD control signals and data settings
    always @(posedge RESETN or posedge CLK) begin
        if (RESETN) begin
            TLCD_RS <= 1'b1;
            TLCD_RW <= 1'b1;
            TLCD_DATA <= 8'b00000000;
        end else begin
            case (STATE)
                FUNCTION_SET: begin
                    TLCD_RS <= 1'b0; TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b00111100; // Function Set
                end
                DISP_ONOFF: begin
                    TLCD_RS <= 1'b0; TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b00001100; // Display On, Cursor Off
                end
                ENTRY_MODE: begin
                    TLCD_RS <= 1'b0; TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b00000110; // Entry Mode Set
                end
                LINE1: begin
                    TLCD_RW <= 1'b0;
                    if (CNT == 0) begin
                        TLCD_RS <= 1'b0;
                        TLCD_DATA <= 8'b10000000; // Line 1 starting address
                    end else begin
                        TLCD_RS <= 1'b1;
                        TLCD_DATA <= TEXT_STRING_UPPER[(16 - CNT)*8 +: 8]; // Extract character
                    end
                end
                LINE2: begin
                    TLCD_RW <= 1'b0;
                    if (CNT == 0) begin
                        TLCD_RS <= 1'b0;
                        TLCD_DATA <= 8'b11000000; // Line 2 starting address
                    end else begin
                        TLCD_RS <= 1'b1;
                        TLCD_DATA <= TEXT_STRING_LOWER[(16 - CNT)*8 +: 8];
                    end
                end
                DELAY_T: begin
                    TLCD_RS <= 1'b0; TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b00000010; // Return Home
                end
                CLEAR_DISP: begin
                    TLCD_RS <= 1'b0; TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b00000001; // Clear Display
                end
                default: begin
                    TLCD_RS <= 1'b1; TLCD_RW <= 1'b1;
                    TLCD_DATA <= 8'b00000000;
                end
            endcase
        end
    end

endmodule