module custom_font_loader(
    input wire RESETN,
    input wire CLK,
    output reg TLCD_E,
    output reg TLCD_RS,
    output reg TLCD_RW,
    output reg [7:0] TLCD_DATA,
    output reg DONE // Indicate completion
);

    parameter INIT = 2'b00, LOAD_FONT = 2'b01, FINISHED = 2'b10;

    reg [1:0] STATE;
    reg [5:0] cf_addr; // Custom font address
    reg [7:0] custom_font [0:39]; // 5x8 fonts, total 40 bytes
    reg [3:0] CNT;

    initial begin
        // Initialize custom font data (same as before)
        // CF1
        custom_font[0] = 8'b00110;
        custom_font[1] = 8'b00111;
        custom_font[2] = 8'b00100;
        custom_font[3] = 8'b00110;
        custom_font[4] = 8'b01100;
        custom_font[5] = 8'b11100;
        custom_font[6] = 8'b11100;
        custom_font[7] = 8'b10100;
        // CF2
        custom_font[8] = 8'b01100;
        custom_font[9] = 8'b01110;
        custom_font[10]= 8'b01000;
        custom_font[11]= 8'b01110;
        custom_font[12]= 8'b01100;
        custom_font[13]= 8'b11100;
        custom_font[14]= 8'b11100;
        custom_font[15]= 8'b01000;
        // CF3
        custom_font[16]= 8'b00110;
        custom_font[17]= 8'b00111;
        custom_font[18]= 8'b01110;
        custom_font[19]= 8'b11110;
        custom_font[20]= 8'b11100;
        custom_font[21]= 8'b01000;
        custom_font[22]= 8'b00000;
        custom_font[23]= 8'b00000;
        // CF4
        custom_font[24]= 8'b00100;
        custom_font[25]= 8'b10100;
        custom_font[26]= 8'b10101;
        custom_font[27]= 8'b10101;
        custom_font[28]= 8'b01101;
        custom_font[29]= 8'b00110;
        custom_font[30]= 8'b00100;
        custom_font[31]= 8'b00100;
        // CF5
        custom_font[32]= 8'b00000;
        custom_font[33]= 8'b00100;
        custom_font[34]= 8'b00101;
        custom_font[35]= 8'b10101;
        custom_font[36]= 8'b10101;
        custom_font[37]= 8'b10110;
        custom_font[38]= 8'b01100;
        custom_font[39]= 8'b00100;
    end

    always @(posedge CLK or posedge RESETN) begin
        if (RESETN) begin
            STATE <= INIT;
            cf_addr <= 0;
            CNT <= 0;
            DONE <= 0;
            TLCD_E <= 1'b0;
            TLCD_RS <= 1'b1;
            TLCD_RW <= 1'b1;
            TLCD_DATA <= 8'b00000000;
        end else begin
            case (STATE)
                INIT: begin
                    // Set CGRAM address
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b01000000; // Set CGRAM address to 0
                    TLCD_E <= 1'b1;
                    CNT <= 0;
                    STATE <= LOAD_FONT;
                end
                LOAD_FONT: begin
                    if (CNT == 1) begin
                        TLCD_E <= 1'b0;
                        CNT <= 0;
                        if (cf_addr < 6'd40) begin
                            TLCD_RS <= 1'b1;
                            TLCD_RW <= 1'b0;
                            TLCD_DATA <= custom_font[cf_addr];
                            TLCD_E <= 1'b1;
                            cf_addr <= cf_addr + 1;
                        end else begin
                            STATE <= FINISHED;
                        end
                    end else begin
                        CNT <= CNT + 1;
                    end
                end
                FINISHED: begin
                    TLCD_E <= 1'b0;
                    DONE <= 1;
                end
            endcase
        end
    end

endmodule