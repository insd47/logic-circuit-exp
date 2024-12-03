module custom_font_loader(
    input wire RESETN,
    input wire CLK,
    output wire TLCD_E,
    output reg TLCD_RS,
    output reg TLCD_RW,
    output reg [7:0] TLCD_DATA,
    output reg [2:0] STATE // Expose current state
);

    parameter INIT = 3'b000, LOAD_FONT = 3'b001, DONE = 3'b010;

    integer CNT;
    reg [5:0] cf_addr; // Custom font address
    reg [7:0] custom_font [0:39]; // 5x8 fonts, total 40 bytes

    initial begin
        // Initialize custom font data
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

    assign TLCD_E = CLK; // E pin connected to CLK

    always @(posedge RESETN or posedge CLK) begin
        if (RESETN) begin
            STATE <= INIT;
            CNT <= 0;
            cf_addr <= 0;
        end else begin
            case (STATE)
                INIT: begin
                    STATE <= LOAD_FONT;
                end
                LOAD_FONT: begin
                    if (cf_addr < 6'd40) begin
                        if (CNT == 0) begin
                            if (cf_addr[2:0] == 3'd0) begin
                                TLCD_RS <= 1'b0;
                                TLCD_RW <= 1'b0;
                                TLCD_DATA <= 8'b01000000 | (cf_addr[5:3] << 3); // Set CGRAM address
                            end else begin
                                TLCD_RS <= 1'b1;
                                TLCD_RW <= 1'b0;
                                TLCD_DATA <= custom_font[cf_addr];
                            end
                            CNT <= CNT + 1;
                        end else if (CNT == 1) begin
                            CNT <= 0;
                            cf_addr <= cf_addr + 1;
                        end
                    end else begin
                        STATE <= DONE;
                    end
                end
                DONE: begin
                    // Custom font loading complete
                end
                default: STATE <= DONE;
            endcase
        end
    end

endmodule