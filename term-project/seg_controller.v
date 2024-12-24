module seg_controller (
    input wire CLK,
    input wire RST,
    input wire [31:0] BINARY_SCORE, // 최대 8자리 표시

    output reg [7:0] Com,
    output reg AR_SEG_A,
    output reg AR_SEG_B,
    output reg AR_SEG_C,
    output reg AR_SEG_D,
    output reg AR_SEG_E,
    output reg AR_SEG_F,
    output reg AR_SEG_G
);
    integer i;
    reg [31:0] value;
    reg [3:0] digits[7:0];

    // "공백" 표기에 쓸 값
    localparam BLANK = 4'hF;  // decode_seg에서 default -> 7'b0000000

    always @(*) begin
        // BINARY_SCORE를 10진수로 분해, LSB->MSB로 digits[] 저장
        // digits[0] = 일의 자리, digits[7] = 10^7 자리
        value = BINARY_SCORE;
        for (i=0; i<8; i=i+1) begin
            digits[i] = value % 10;
            value = value / 10;
        end
    end

    // 디스플레이할 자리(공백 처리 결과)
    reg [3:0] display_digits[7:0];

    // 먼저 MUX로 8개 자릿수를 순환 표시하기 위한 카운터
    reg [15:0] mux_cnt;
    always @(posedge CLK or posedge RST) begin
        if(RST) mux_cnt <= 0;
        else mux_cnt <= mux_cnt + 1;
    end

    wire [2:0] digit_select = mux_cnt[12:10]; // 약 2kHz 스캔

    // 선행 0(leading zero) → 공백 처리
    reg found_nonzero;
    integer j;

    always @(*) begin
        // 초기 display_digits 모두 공백으로
        for(j=0; j<8; j=j+1) begin
            display_digits[j] = BLANK;
        end

        found_nonzero = 1'b0;
        // 가장 상위 자리(digits[7])부터 내려오면서 확인
        for(j=7; j>=0; j=j-1) begin
            if(!found_nonzero) begin
                if(digits[j] != 4'd0) begin
                    found_nonzero = 1'b1;
                    display_digits[j] = digits[j];
                end
                else begin
                    display_digits[j] = BLANK; // 선행 0 → 공백
                end
            end else begin
                // 이미 비영 숫자를 만났으면 digits 그대로
                display_digits[j] = digits[j];
            end

            // j==0에서 j-1= -1 이 되어 for 문이 끝날 때
            // 시뮬레이션상 disable 문제 없도록, synthesis할 땐 큰 문제는 없음
            if(j==0) disable loop_check; 
        end
    end

    // 세그먼트 디코딩 함수
    function [6:0] decode_seg;
        input [3:0] d;
        begin
            case(d)
                4'd0: decode_seg = 7'b1111110; // 0
                4'd1: decode_seg = 7'b0110000; // 1
                4'd2: decode_seg = 7'b1101101; // 2
                4'd3: decode_seg = 7'b1111001; // 3
                4'd4: decode_seg = 7'b0110011; // 4
                4'd5: decode_seg = 7'b1011011; // 5
                4'd6: decode_seg = 7'b1011111; // 6
                4'd7: decode_seg = 7'b1110010; // 7
                4'd8: decode_seg = 7'b1111111; // 8
                4'd9: decode_seg = 7'b1111011; // 9
                default: decode_seg = 7'b0000000; // BLANK (4'hF 등)
            endcase
        end
    endfunction

    reg [6:0] seg_data;
    always @(*) begin
        // digit_select=0이면 가장 왼쪽(Com[7]) 표시, digit_select=7이면 Com[0]
        //  → display_digits[7 - digit_select] 사용
        seg_data = decode_seg(display_digits[7 - digit_select]);
    end

    // 공통 신호
    always @(*) begin
        Com = 8'b11111111;
        Com[7 - digit_select] = 1'b0;
    end

    // 출력
    always @(posedge CLK or posedge RST) begin
        if(RST) begin
            {AR_SEG_A, AR_SEG_B, AR_SEG_C, AR_SEG_D, AR_SEG_E, AR_SEG_F, AR_SEG_G} <= 7'b1111111;
        end else begin
            {AR_SEG_A, AR_SEG_B, AR_SEG_C, AR_SEG_D, AR_SEG_E, AR_SEG_F, AR_SEG_G} <= seg_data;
        end
    end

endmodule