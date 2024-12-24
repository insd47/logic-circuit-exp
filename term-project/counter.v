module counter (
    input wire CLK,
    input wire RST,
    output reg shift_enable
);
    reg [17:0] timer_cnt; // 0 ~ 200000

    always @(posedge CLK or posedge RST) begin
        if(RST) begin
            timer_cnt <= 0;
            shift_enable <= 0;
        end else begin
            if(timer_cnt < 200000) begin
                timer_cnt <= timer_cnt + 1;
                shift_enable <= 0;
            end else begin
                timer_cnt <= 0;
                shift_enable <= 1;
            end
        end
    end

endmodule