module trigger (
    input wire clk,
    input wire rst,
    input wire signal_in,
    output reg triggered
);

reg prev_signal_in;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        prev_signal_in <= 1'b0;
        triggered <= 1'b0;
    end else begin
        prev_signal_in <= signal_in;
        triggered <= prev_signal_in && !signal_in;
    end
end

endmodule