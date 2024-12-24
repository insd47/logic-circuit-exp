module sound (
    input wire CLK,
    input wire RST,
    input wire sound_enable,  // rising edge에서 0.2초간 재생
    output reg piezo_out
);

    // 분주(4옥타브 미(약 659Hz) → 1MHz / 659 ≈ 1517)
    localparam DIV_COUNT = 1517;
    // 재생 시간(0.2초)
    localparam DURATION = 200000;

    // 간단 상태기: IDLE → PLAYING
    reg [1:0] state;
    localparam IDLE = 2'd0,
               PLAYING = 2'd1;

    reg [31:0] dur_cnt;
    reg [31:0] div_cnt;

    reg prev_enable;

    always @(posedge CLK or posedge RST) begin
        if(RST) begin
            state <= IDLE;
            piezo_out <= 0;
            dur_cnt <= 0;
            div_cnt <= 0;
            prev_enable <= 0;
        end else begin
            prev_enable <= sound_enable;

            case(state)
                IDLE: begin
                    // sound_enable의 Rising Edge 감지
                    if(sound_enable && !prev_enable) begin
                        state <= PLAYING;
                        dur_cnt <= 0;
                        div_cnt <= 0;
                        piezo_out <= 0;
                    end
                end
                PLAYING: begin
                    // 0.2초 동안 분주하여 piezo_out 토글
                    // 분주 카운트
                    if(div_cnt < (DIV_COUNT - 1)) begin
                        div_cnt <= div_cnt + 1;
                    end else begin
                        div_cnt <= 0;
                        piezo_out <= ~piezo_out;
                    end
                    // 재생 시간 카운트
                    if(dur_cnt < (DURATION - 1)) begin
                        dur_cnt <= dur_cnt + 1;
                    end else begin
                        // 0.2초가 지났으면 소리 끄고 IDLE
                        state <= IDLE;
                        piezo_out <= 0;
                    end
                end
            endcase
        end
    end

endmodule