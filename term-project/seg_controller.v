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
    reg [3:0] display_digit[7:0]; // 실제로 표시할 digit (공백 처리 포함)
    integer top_digit_idx;

    always @(*) begin
        value = BINARY_SCORE;
        for (i=0; i<8; i=i+1) begin
            digits[i] = value % 10;
            value = value / 10;
        end

        // top_digit_idx 찾기: 가장 상위에서 0이 아닌 자리
        top_digit_idx = 0;
        for (i=7; i>=0; i=i-1) begin
            if(digits[i] != 0) begin
                top_digit_idx = i;
                break;
            end
            if(i==0) top_digit_idx = 0; // score=0일 경우 top_digit_idx=0
        end

        // display_digit 설정
        for(i=0; i<8; i=i+1) begin
            if(i > top_digit_idx) begin
                // 상위 자리 (숫자가 없는 곳)은 공백 처리
                // 공백을 표현하기 위해 별도의 코드가 필요
                // 여기서 공백 = special code로 0xF 같은 값 사용
                // case문에서 0xF 일 때 공백으로 처리
                display_digit[i] = 4'hF;
            end else begin
                display_digit[i] = digits[i];
            end
        end
    end

    reg [2:0] digit_select;
    reg [15:0] mux_cnt;

    always @(posedge CLK or posedge RST) begin
        if(RST) mux_cnt <= 0;
        else mux_cnt <= mux_cnt + 1;
    end

    always @(*) begin
        digit_select = mux_cnt[12:10];
    end

    reg [6:0] seg_data;

    always @(*) begin
        case(display_digit[digit_select])
            4'd0: seg_data = 7'b1111110;
            4'd1: seg_data = 7'b0110000;
            4'd2: seg_data = 7'b1101101;
            4'd3: seg_data = 7'b1111001;
            4'd4: seg_data = 7'b0110011;
            4'd5: seg_data = 7'b1011011;
            4'd6: seg_data = 7'b1011111;
            4'd7: seg_data = 7'b1110010;
            4'd8: seg_data = 7'b1111111;
            4'd9: seg_data = 7'b1111011;
            4'hF: seg_data = 7'b0000000; // 공백 처리. 모든 segment off
            default: seg_data = 7'b0000000;
        endcase
    end

    always @(*) begin
        Com = 8'b11111111;
        // digit_select=0이 가장 오른쪽 자리,
        // 이를 반전시키면 digit_select=0이 Com[7], digit_select=1이 Com[6] ...
        // 7 - digit_select 로 인덱싱
        Com[7 - digit_select] = 0;
    end

    always @(posedge CLK or posedge RST) begin
        if(RST) begin
            {AR_SEG_A, AR_SEG_B, AR_SEG_C, AR_SEG_D, AR_SEG_E, AR_SEG_F, AR_SEG_G} <= 7'b1111111;
        end else begin
            {AR_SEG_A, AR_SEG_B, AR_SEG_C, AR_SEG_D, AR_SEG_E, AR_SEG_F, AR_SEG_G} <= seg_data;
        end
    end

endmodule