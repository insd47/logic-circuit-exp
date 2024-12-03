module custom_font_loader(
    input wire RESETN,
    input wire CLK,
    output reg TLCD_E,
    output reg TLCD_RS,
    output reg TLCD_RW,
    output reg [7:0] TLCD_DATA,
    output reg [2:0] STATE // 현재 상태를 외부로 노출
);

    parameter INIT = 3'b000, SET_CGRAM_ADDR = 3'b001, WRITE_FONT = 3'b010, DONE = 3'b011;

    reg [5:0] cf_addr; // 커스텀 폰트 주소 (0~39)
    reg [2:0] font_char; // 현재 폰트 문자 번호 (0~4)
    reg [2:0] row; // 현재 폰트의 행 번호 (0~7)
    reg [7:0] custom_font [0:39]; // 5x8 폰트, 총 40바이트
    reg [15:0] delay_counter; // 딜레이 카운터

    initial begin
        // 커스텀 폰트 데이터 초기화 (하위 5비트에 데이터, 상위 3비트는 0)
        // CF1
        custom_font[0] = 8'b0000110;
        custom_font[1] = 8'b0000111;
        custom_font[2] = 8'b0000100;
        custom_font[3] = 8'b0000110;
        custom_font[4] = 8'b0001100;
        custom_font[5] = 8'b0011100;
        custom_font[6] = 8'b0011100;
        custom_font[7] = 8'b0010100;
        // CF2
        custom_font[8]  = 8'b0001100;
        custom_font[9]  = 8'b0001110;
        custom_font[10] = 8'b0001000;
        custom_font[11] = 8'b0001110;
        custom_font[12] = 8'b0001100;
        custom_font[13] = 8'b0011100;
        custom_font[14] = 8'b0011100;
        custom_font[15] = 8'b0001000;
        // CF3
        custom_font[16] = 8'b0000110;
        custom_font[17] = 8'b0000111;
        custom_font[18] = 8'b0001110;
        custom_font[19] = 8'b0011110;
        custom_font[20] = 8'b0011100;
        custom_font[21] = 8'b0001000;
        custom_font[22] = 8'b0000000;
        custom_font[23] = 8'b0000000;
        // CF4
        custom_font[24] = 8'b0000100;
        custom_font[25] = 8'b0010100;
        custom_font[26] = 8'b0010101;
        custom_font[27] = 8'b0010101;
        custom_font[28] = 8'b0001101;
        custom_font[29] = 8'b0000110;
        custom_font[30] = 8'b0000100;
        custom_font[31] = 8'b0000100;
        // CF5
        custom_font[32] = 8'b0000000;
        custom_font[33] = 8'b0000100;
        custom_font[34] = 8'b0000101;
        custom_font[35] = 8'b0010101;
        custom_font[36] = 8'b0010101;
        custom_font[37] = 8'b0010110;
        custom_font[38] = 8'b0001100;
        custom_font[39] = 8'b0000100;
    end

    always @(negedge RESETN or posedge CLK) begin
        if (!RESETN) begin
            STATE <= INIT;
            TLCD_E <= 1'b0;
            TLCD_RS <= 1'b0;
            TLCD_RW <= 1'b0;
            TLCD_DATA <= 8'd0;
            cf_addr <= 0;
            font_char <= 0;
            row <= 0;
            delay_counter <= 0;
        end else begin
            case (STATE)
                INIT: begin
                    // 딜레이 (예: 2ms)
                    if (delay_counter < 32'd100000) begin
                        delay_counter <= delay_counter + 1;
                    end else begin
                        delay_counter <= 0;
                        STATE <= SET_CGRAM_ADDR;
                    end
                end
                SET_CGRAM_ADDR: begin
                    // CGRAM 주소 설정
                    TLCD_E <= 1'b1;
                    TLCD_RS <= 1'b0;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= 8'b01000000 | (font_char << 3); // CGRAM 주소 설정
                    STATE <= WRITE_FONT;
                end
                WRITE_FONT: begin
                    TLCD_E <= 1'b1;
                    TLCD_RS <= 1'b1;
                    TLCD_RW <= 1'b0;
                    TLCD_DATA <= custom_font[cf_addr];
                    STATE <= DONE;
                end
                DONE: begin
                    // E 핀을 Low로 만들고 다음 데이터로 이동
                    TLCD_E <= 1'b0;
                    if (row < 3'd7) begin
                        row <= row + 1;
                        cf_addr <= cf_addr + 1;
                        STATE <= WRITE_FONT;
                    end else if (font_char < 3'd4) begin
                        font_char <= font_char + 1;
                        row <= 0;
                        cf_addr <= cf_addr + 1;
                        STATE <= SET_CGRAM_ADDR;
                    end else begin
                        // 모든 폰트 로딩 완료
                        STATE <= 3'b100; // COMPLETED 상태
                    end
                end
                default: STATE <= 3'b100; // COMPLETED 상태
            endcase
        end
    end

endmodule