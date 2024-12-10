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

    // Convert binary score to decimal digits
    always @(*) begin
        value = BINARY_SCORE;
        for (i = 0; i < 8; i = i + 1) begin
            digits[i] = value % 10;
            value = value / 10;
        end
    end

    reg [2:0] digit_select;
    reg [15:0] mux_cnt;

    // Counter for multiplexing digits
    always @(posedge CLK or posedge RST) begin
        if (RST)
            mux_cnt <= 0;
        else
            mux_cnt <= mux_cnt + 1;
    end

    // Select the current digit to display
    always @(*) begin
        digit_select = mux_cnt[12:10];
    end

    reg [6:0] seg_data;

    // Determine if the current digit should be blanked
    reg blank;

    integer j;
    reg blank_internal;

    always @(*) begin
        // Assume all higher digits are zero initially
        blank_internal = 1;
        for (j = digit_select + 1; j < 8; j = j + 1) begin
            if (digits[j] != 0) begin
                blank_internal = 0;
            end
        end
        // A digit should be blank if it's zero and all higher digits are zero
        blank = (digits[digit_select] == 0) && (blank_internal);
    end

    // Assign seg_data based on whether to blank or display the digit
    always @(*) begin
        if (blank) begin
            seg_data = 7'b0000000; // Blank
        end else begin
            case(digits[digit_select])
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
                default: seg_data = 7'b0000000;
            endcase
        end
    end

    // Reverse the Com mapping
    always @(*) begin
        Com = 8'b11111111; // All digits off
        Com[7 - digit_select] = 0; // Activate the correct digit in reversed order
    end

    // Assign segment outputs
    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            {AR_SEG_A, AR_SEG_B, AR_SEG_C, AR_SEG_D, AR_SEG_E, AR_SEG_F, AR_SEG_G} <= 7'b1111111;
        end else begin
            {AR_SEG_A, AR_SEG_B, AR_SEG_C, AR_SEG_D, AR_SEG_E, AR_SEG_F, AR_SEG_G} <= seg_data;
        end
    end

endmodule