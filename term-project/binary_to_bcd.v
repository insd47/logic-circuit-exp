module binary_to_bcd(
    input wire CLK,
    input wire RST,
    input wire [31:0] BIN,
    input wire START,
    output reg DONE,
    output reg [3:0] BCD0, // ones
    output reg [3:0] BCD1, // tens
    output reg [3:0] BCD2, // hundreds
    output reg [3:0] BCD3, // thousands
    output reg [3:0] BCD4, // ten-thousands
    output reg [3:0] BCD5, // hundred-thousands
    output reg [3:0] BCD6, // millions
    output reg [3:0] BCD7  // ten-millions
);
    reg [31:0] shift_reg;
    reg [4:0] bit_count;
    reg working;

    always @(posedge CLK or posedge RST) begin
        if(RST) begin
            DONE <= 0;
            working <= 0;
            bit_count <= 0;
            {BCD7,BCD6,BCD5,BCD4,BCD3,BCD2,BCD1,BCD0} <= 0;
        end else begin
            if(START && !working) begin
                working <= 1;
                DONE <= 0;
                bit_count <= 32;
                shift_reg <= BIN;
                {BCD7,BCD6,BCD5,BCD4,BCD3,BCD2,BCD1,BCD0} <= 0;
            end else if(working) begin
                // Double Dabble algorithm
                // Check each BCD digit, if >=5 add 3
                if(BCD0 >= 5) BCD0 <= BCD0 + 3;
                if(BCD1 >= 5) BCD1 <= BCD1 + 3;
                if(BCD2 >= 5) BCD2 <= BCD2 + 3;
                if(BCD3 >= 5) BCD3 <= BCD3 + 3;
                if(BCD4 >= 5) BCD4 <= BCD4 + 3;
                if(BCD5 >= 5) BCD5 <= BCD5 + 3;
                if(BCD6 >= 5) BCD6 <= BCD6 + 3;
                if(BCD7 >= 5) BCD7 <= BCD7 + 3;

                // Shift left
                {BCD7,BCD6,BCD5,BCD4,BCD3,BCD2,BCD1,BCD0,shift_reg} <= {BCD7,BCD6,BCD5,BCD4,BCD3,BCD2,BCD1,BCD0,shift_reg} << 1;
                bit_count <= bit_count - 1;
                if(bit_count==1) begin
                    DONE <= 1;
                    working <= 0;
                end
            end
        end
    end

endmodule