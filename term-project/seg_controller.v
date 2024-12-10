module seg_controller (
    input wire CLK,
    input wire RST,
    input wire [31:0] BINARY_SCORE, // 최대 8자리 10진수 표시 가능
    output reg [7:0] AR_COM,        // Common anode or cathode control lines
    output reg [6:0] AR_SEG         // Segment lines (a-g)
);

    // 1MHz 기준으로 약 1kHz multiplexing을 위해 카운터 사용
    reg [15:0] mux_cnt;
    always @(posedge CLK or posedge RST) begin
        if(RST) mux_cnt <= 0;
        else mux_cnt <= mux_cnt + 1;
    end

    wire [2:0] digit_select = mux_cnt[12:10]; // 약 1kHz로 8개 자리 순회(필요하면 조정)

    // BINARY_SCORE를 10진수로 변환하여 8자리 분리
    // 간단히 나눗셈으로 8자리 추출
    integer i;
    reg [31:0] value;
    reg [3:0] digits[0:7];
    always @(*) begin
        value = BINARY_SCORE;
        for(i=0;i<8;i=i+1) begin
            digits[i] = value % 10;
            value = value / 10;
        end
    end

    // digits[0]가 LSD, digits[7]이 MSD
    wire [3:0] current_digit = digits[digit_select];

    // 7-Segment 인코딩
    // Common anode 기준, 0: on, 1: off 이면 반대로 조정 필요
    reg [6:0] seg_data;
    always @(*) begin
        case(current_digit)
            4'd0: seg_data = 7'b1000000;
            4'd1: seg_data = 7'b1111001;
            4'd2: seg_data = 7'b0100100;
            4'd3: seg_data = 7'b0110000;
            4'd4: seg_data = 7'b0011001;
            4'd5: seg_data = 7'b0010010;
            4'd6: seg_data = 7'b0000010;
            4'd7: seg_data = 7'b1111000;
            4'd8: seg_data = 7'b0000000;
            4'd9: seg_data = 7'b0010000;
            default: seg_data = 7'b1111111;
        endcase
    end

    always @(*) begin
        // Common line: digit_select에 해당하는 COM만 LOW (Common anode인 경우)
        // 8자리 => AR_COM[7:0] (0일때 켜짐 가정)
        AR_COM = 8'b11111111;
        AR_COM[digit_select] = 0;
    end

    always @(posedge CLK or posedge RST) begin
        if(RST) AR_SEG <= 7'b1111111;
        else AR_SEG <= seg_data;
    end

endmodule