module lfsr_8bit(
    input CLK,
    input RST,
    output reg [7:0] rand_out
);
    always @(posedge CLK or posedge RST) begin
        if(RST) rand_out <= 8'hAC;
        else rand_out <= {rand_out[6:0], rand_out[7]^rand_out[5]};
    end
endmodule