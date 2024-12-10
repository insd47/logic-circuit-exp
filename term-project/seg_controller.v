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

    // 점수 10진 변환 및 오른쪽 정렬
    // 8자리를 모두 출력하되, 점수가 적으면 상위 자리엔 0을 표시
    integer i;
    reg [31:0] value;
    reg [3:0] digits[7:0];

    always @(*) begin
        value = BINARY_SCORE;
        for (i=0; i<8; i=i+1) begin
            digits[i] = value % 10;
            value = value / 10;
        end
    end

    // digits[0]가 LSD(오른쪽 끝), digits[7]가 MSD(왼쪽 끝)
    // 오른쪽 정렬이 기본이므로 그냥 digits[0]을 가장 오른쪽 세그먼트로 출력하면 됨
    // 예: Com[0] -> digits[0], Com[1] -> digits[1], ...
    // 이렇게 하면 이미 오른쪽 정렬

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
        case(digits[digit_select])
            4'd0: seg_data = 7'b0000001; // 0 표시 (cc)
            4'd1: seg_data = 7'b1001111;
            4'd2: seg_data = 7'b0010010;
            4'd3: seg_data = 7'b0000110;
            4'd4: seg_data = 7'b1001100;
            4'd5: seg_data = 7'b0100100;
            4'd6: seg_data = 7'b0100000;
            4'd7: seg_data = 7'b0001111;
            4'd8: seg_data = 7'b0000000;
            4'd9: seg_data = 7'b0000100;
            default: seg_data = 7'b1111111;
        endcase
    end

    always @(*) begin
        Com = 8'b11111111;
        Com[digit_select] = 0;
    end

    always @(posedge CLK or posedge RST) begin
        if(RST) begin
            {AR_SEG_A, AR_SEG_B, AR_SEG_C, AR_SEG_D, AR_SEG_E, AR_SEG_F, AR_SEG_G} <= 7'b1111111;
        end else begin
            {AR_SEG_A, AR_SEG_B, AR_SEG_C, AR_SEG_D, AR_SEG_E, AR_SEG_F, AR_SEG_G} <= seg_data;
        end
    end

endmodule