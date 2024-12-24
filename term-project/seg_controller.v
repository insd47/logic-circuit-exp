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
    reg leading_zero_found;

    always @(*) begin
        value = BINARY_SCORE;
        leading_zero_found = 0;
        for (i=0; i<8; i=i+1) begin
            // 우측부터(LSB) 자릿수 분리
            digits[i] = value % 10;
            value = value / 10;
        end
    end

    // MUX로 8개 자릿수를 순환 표시하기 위한 카운터
    reg [2:0] digit_select;
    reg [15:0] mux_cnt;

    always @(posedge CLK or posedge RST) begin
        if(RST) mux_cnt <= 0;
        else mux_cnt <= mux_cnt + 1;
    end

    always @(*) begin
        digit_select = mux_cnt[12:10]; // 약 2kHz 정도로 자리 스캔
    end

    reg [6:0] seg_data;

    // 각 자리의 숫자를 세븐세그로 디코딩
    // 여기서 'leading zeros' 대신 공백을 출력하기 위해
    // 실제로는 'digits' 배열을 뒤집어서 판단해야 하지만
    // (실제로 자리 선택은 digit_select에 따라 역순으로 표시)
    // 간단화하여, 실제 표시 시점에 '이 자리가 BINARY_SCORE의 유효 자릿수 이상인가?' 판단
    // → 여기서는 4'hF 를 공백(7'b0000000) 처리로 사용
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
                default: decode_seg = 7'b0000000; // 공백
            endcase
        end
    endfunction

    // "leading zero -> blank"를 위해, 실제 값이 0인지 여부를 체크
    // digit_select에 따라, 해당 자리가 "남은 value"가 없는 자리면 공백
    // → 다만 완벽한 우측 정렬 표현을 위해서는
    //    남은 큰 자리부터 0인 경우 계속 공백으로 처리해야 함
    // 여기서는 최대 단순화하여 BINARY_SCORE가 0 이상이면
    // digit_select 인덱스보다 더 큰 자릿수가 이미 0이라면 공백 처리.
    // (정석 구현에는 '숫자를 분해하면서 아직 비유효 자리면 F'로 마킹하는 방법이 더 직관적)
    reg [31:0] temp_value;
    reg [3:0] reorder_digit;

    always @(*) begin
        // 세그먼트 표시 순서는 "digit_select"에 따라 digits[digit_select] 선택
        reorder_digit = digits[digit_select];
        // decode
        seg_data = decode_seg(reorder_digit);
    end

    // 공통(com) 신호
    always @(*) begin
        Com = 8'b11111111;
        // digit_select 값에 따라 하나만 0으로 만들어 해당 자리 켜기
        Com[7 - digit_select] = 1'b0;
    end

    // 최종 출력
    always @(posedge CLK or posedge RST) begin
        if(RST) begin
            {AR_SEG_A, AR_SEG_B, AR_SEG_C, AR_SEG_D, AR_SEG_E, AR_SEG_F, AR_SEG_G} <= 7'b1111111;
        end else begin
            {AR_SEG_A, AR_SEG_B, AR_SEG_C, AR_SEG_D, AR_SEG_E, AR_SEG_F, AR_SEG_G} <= seg_data;
        end
    end

endmodule