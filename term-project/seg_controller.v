module seg_controller(
    input wire CLK,         // 1MHz
    input wire RST,
    input wire [33:0] NUM,  // NUM[33:0], 실제 8자리 *4비트 = 32비트 사용, 상위2비트는 0
    output reg AR_SEG_A,
    output reg AR_SEG_B,
    output reg AR_SEG_C,
    output reg AR_SEG_D,
    output reg AR_SEG_E,
    output reg AR_SEG_F,
    output reg AR_SEG_G,
    output reg [7:0] AR_COM
);

    // NUM: Digit0 = NUM[3:0], Digit1 = NUM[7:4], ..., Digit7 = NUM[31:28]
    wire [3:0] digits [7:0];
    assign digits[0] = NUM[3:0];
    assign digits[1] = NUM[7:4];
    assign digits[2] = NUM[11:8];
    assign digits[3] = NUM[15:12];
    assign digits[4] = NUM[19:16];
    assign digits[5] = NUM[23:20];
    assign digits[6] = NUM[27:24];
    assign digits[7] = NUM[31:28];

    // 자리 선택을 위한 스캔 카운터
    reg [12:0] scan_cnt;
    reg [2:0] digit_sel;
    always @(posedge CLK or posedge RST) begin
        if(RST) begin
            scan_cnt <= 0;
            digit_sel <= 0;
        end else begin
            // 약 1kHz: 1MHz/1000=1000 cycle
            // 대략 125µs마다 다음 자리로 넘어간다고 가정
            if(scan_cnt < 999) begin
                scan_cnt <= scan_cnt + 1;
            end else begin
                scan_cnt <= 0;
                digit_sel <= digit_sel + 1;
            end
        end
    end

    // 현재 선택 자리
    reg [3:0] current_digit;
    always @(*) begin
        current_digit = digits[digit_sel];
    end

    // 7세그 변환
    // 0~9만 표시한다고 가정
    always @(*) begin
        case (current_digit)
            4'h0: {AR_SEG_A,AR_SEG_B,AR_SEG_C,AR_SEG_D,AR_SEG_E,AR_SEG_F,AR_SEG_G} = 7'b1111110;
            4'h1: {AR_SEG_A,AR_SEG_B,AR_SEG_C,AR_SEG_D,AR_SEG_E,AR_SEG_F,AR_SEG_G} = 7'b0110000;
            4'h2: {AR_SEG_A,AR_SEG_B,AR_SEG_C,AR_SEG_D,AR_SEG_E,AR_SEG_F,AR_SEG_G} = 7'b1101101;
            4'h3: {AR_SEG_A,AR_SEG_B,AR_SEG_C,AR_SEG_D,AR_SEG_E,AR_SEG_F,AR_SEG_G} = 7'b1111001;
            4'h4: {AR_SEG_A,AR_SEG_B,AR_SEG_C,AR_SEG_D,AR_SEG_E,AR_SEG_F,AR_SEG_G} = 7'b0110011;
            4'h5: {AR_SEG_A,AR_SEG_B,AR_SEG_C,AR_SEG_D,AR_SEG_E,AR_SEG_F,AR_SEG_G} = 7'b1011011;
            4'h6: {AR_SEG_A,AR_SEG_B,AR_SEG_C,AR_SEG_D,AR_SEG_E,AR_SEG_F,AR_SEG_G} = 7'b1011111;
            4'h7: {AR_SEG_A,AR_SEG_B,AR_SEG_C,AR_SEG_D,AR_SEG_E,AR_SEG_F,AR_SEG_G} = 7'b1110000;
            4'h8: {AR_SEG_A,AR_SEG_B,AR_SEG_C,AR_SEG_D,AR_SEG_E,AR_SEG_F,AR_SEG_G} = 7'b1111111;
            4'h9: {AR_SEG_A,AR_SEG_B,AR_SEG_C,AR_SEG_D,AR_SEG_E,AR_SEG_F,AR_SEG_G} = 7'b1111011;
            default: {AR_SEG_A,AR_SEG_B,AR_SEG_C,AR_SEG_D,AR_SEG_E,AR_SEG_F,AR_SEG_G} = 7'b0000000;
        endcase
    end

    // COM 제어 (active low)
    always @(*) begin
        AR_COM = 8'b11111111;
        AR_COM[digit_sel] = 0;
    end

endmodule