module lfsr (
    input wire CLK,
    input wire RST,
    output reg [15:0] rand_out
);
    // 간단한 LFSR 구현
    // 매 클럭마다 난수 업데이트
    always @(posedge CLK or posedge RST) begin
        if(RST) begin
            rand_out <= 16'hACE1;
        end else begin
            rand_out <= {rand_out[14:0], rand_out[15] ^ rand_out[13]};
        end
    end
endmodule