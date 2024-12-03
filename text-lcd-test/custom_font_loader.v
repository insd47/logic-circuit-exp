module custom_font_loader(
    input wire RESETN,
    input wire CLK, // Assume CLK is 1 MHz for simplicity
    output reg TLCD_E,
    output reg TLCD_RS,
    output reg TLCD_RW,
    output reg [7:0] TLCD_DATA,
    output reg DONE // Indicate completion
);

    // Timing parameters (in clock cycles, assuming 1 MHz clock)
    parameter E_PULSE_WIDTH = 1;    // 1 μs pulse width for E
    parameter EXEC_TIME = 40;       // 40 μs execution time for commands
    parameter INIT_DELAY = 15000;   // 15 ms delay after power-on (for safety)

    parameter INIT = 3'b000, LOAD_FONT = 3'b001, WAIT_EXEC = 3'b010, FINISHED = 3'b011, INIT_WAIT = 3'b100;

    reg [2:0] STATE;
    reg [5:0] cf_addr; // Custom font address
    reg [7:0] custom_font [0:39]; // 5x8 fonts, total 40 bytes
    reg [15:0] CNT;

    initial begin
        // Initialize custom font data with proper bit alignment
        // CF1
        custom_font[0] = 8'b00000110; // Bits D4-D0: 00110
        custom_font[1] = 8'b00000111; // Bits D4-D0: 00111
        custom_font[2] = 8'b00000100; // Bits D4-D0: 00100
        custom_font[3] = 8'b00000110; // Bits D4-D0: 00110
        custom_font[4] = 8'b00001100; // Bits D4-D0: 01100
        custom_font[5] = 8'b00011100; // Bits D4-D0: 11100
        custom_font[6] = 8'b00011100; // Bits D4-D0: 11100
        custom_font[7] = 8'b00010100; // Bits D4-D0: 10100
        // CF2
        custom_font[8]  = 8'b00001100;
        custom_font[9]  = 8'b00001110;
        custom_font[10] = 8'b00001000;
        custom_font[11] = 8'b00001110;
        custom_font[12] = 8'b00001100;
        custom_font[13] = 8'b00011100;
        custom_font[14] = 8'b00011100;
        custom_font[15] = 8'b00001000;
        // CF3
        custom_font[16] = 8'b00000110;
        custom_font[17] = 8'b00000111;
        custom_font[18] = 8'b00001110;
        custom_font[19] = 8'b00011110;
        custom_font[20] = 8'b00011100;
        custom_font[21] = 8'b00001000;
        custom_font[22] = 8'b00000000;
        custom_font[23] = 8'b00000000;
        // CF4
        custom_font[24] = 8'b00000100;
        custom_font[25] = 8'b00010100;
        custom_font[26] = 8'b00010101;
        custom_font[27] = 8'b00010101;
        custom_font[28] = 8'b00001101;
        custom_font[29] = 8'b00000110;
        custom_font[30] = 8'b00000100;
        custom_font[31] = 8'b00000100;
        // CF5
        custom_font[32] = 8'b00000000;
        custom_font[33] = 8'b00000100;
        custom_font[34] = 8'b00000101;
        custom_font[35] = 8'b00010101;
        custom_font[36] = 8'b00010101;
        custom_font[37] = 8'b00010110;
        custom_font[38] = 8'b00001100;
        custom_font[39] = 8'b00000100;
    end

    always @(posedge CLK or posedge RESETN) begin
        if (RESETN) begin
            STATE <= INIT;
            cf_addr <= 0;
            CNT <= 0;
            DONE <= 0;
            TLCD_E <= 1'b0;
            TLCD_RS <= 1'b0;
            TLCD_RW <= 1'b0;
            TLCD_DATA <= 8'b00000000;
        end else begin
            case (STATE)
                INIT: begin
                    CNT <= CNT + 1;
                    if (CNT >= INIT_DELAY) begin
                        CNT <= 0;
                        // Set CGRAM address to 0x00
                        TLCD_RS <= 1'b0;
                        TLCD_RW <= 1'b0;
                        TLCD_DATA <= 8'b01000000; // Set CGRAM address command
                        TLCD_E <= 1'b1;
                        STATE <= WAIT_EXEC;
                    end
                end
                WAIT_EXEC: begin
                    CNT <= CNT + 1;
                    if (CNT >= E_PULSE_WIDTH) begin
                        TLCD_E <= 1'b0;
                    end
                    if (CNT >= EXEC_TIME) begin
                        CNT <= 0;
                        if (cf_addr < 6'd40) begin
                            // Write font data to CGRAM
                            TLCD_RS <= 1'b1;
                            TLCD_RW <= 1'b0;
                            TLCD_DATA <= custom_font[cf_addr];
                            TLCD_E <= 1'b1;
                            cf_addr <= cf_addr + 1;
                            STATE <= LOAD_FONT;
                        end else begin
                            STATE <= FINISHED;
                        end
                    end
                end
                LOAD_FONT: begin
                    CNT <= CNT + 1;
                    if (CNT >= E_PULSE_WIDTH) begin
                        TLCD_E <= 1'b0;
                    end
                    if (CNT >= EXEC_TIME) begin
                        CNT <= 0;
                        if (cf_addr < 6'd40) begin
                            // Continue writing font data
                            TLCD_RS <= 1'b1;
                            TLCD_RW <= 1'b0;
                            TLCD_DATA <= custom_font[cf_addr];
                            TLCD_E <= 1'b1;
                            cf_addr <= cf_addr + 1;
                            STATE <= LOAD_FONT;
                        end else begin
                            STATE <= FINISHED;
                        end
                    end
                end
                FINISHED: begin
                    TLCD_E <= 1'b0;
                    DONE <= 1;
                end
                default: STATE <= INIT;
            endcase
        end
    end

endmodule