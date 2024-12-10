module obstacle_manager(
    input wire CLK,
    input wire RST,
    input wire shift_enable,        // 0.25초 단위 rising edge
    input wire jump_trigger,        // 0~9 키 중 하나 눌려 jump
    input wire start_game,
    input wire force_game_over,     // #키에 의해 강제 게임 오버 신호
    input wire [15:0] rand_val,     // lfsr로부터 난수 입력
    output reg game_over,
    output reg [1:0] obstacle_map [0:15],
    output reg dino_on_ground,
    output reg [31:0] score
);

    reg [1:0] obstacles[0:15];
    integer idx;
    reg [3:0] jump_cnt;

    always @(posedge CLK or posedge RST) begin
        if(RST) begin
            for(idx=0; idx<16; idx=idx+1)
                obstacles[idx] <= 2'b00;
            dino_on_ground <= 1;
            jump_cnt <= 0;
            score <= 0;
            game_over <= 0;
        end else begin
            if(start_game) begin
                for(idx=0; idx<16; idx=idx+1)
                    obstacles[idx] <= 2'b00;
                dino_on_ground <= 1;
                jump_cnt <= 0;
                score <= 0;
                game_over <= 0;
            end else if(!game_over && shift_enable) begin
                // 장애물 이동
                for(idx=0; idx<15; idx=idx+1)
                    obstacles[idx] <= obstacles[idx+1];
                obstacles[15] <= 2'b00;

                // 장애물 생성 조건
                begin: obstacle_generate
                    integer check;
                    reg any_obs;
                    any_obs = 0;
                    for(check=5; check<=15; check=check+1) begin
                        if(obstacles[check] != 2'b00)
                            any_obs = 1;
                    end
                    if(!any_obs) begin
                        // 3/4 확률
                        if(rand_val[1:0] != 2'b11) begin
                            obstacles[15] <= (rand_val[2]) ? 2'b01 : 2'b10;
                        end
                    end
                end

                // 점프 상태 갱신
                if(jump_trigger && dino_on_ground) begin
                    dino_on_ground <= 0;
                    jump_cnt <= 2; // 점프 시간 예시
                end else if(!dino_on_ground) begin
                    if(jump_cnt > 0) jump_cnt <= jump_cnt - 1;
                    else dino_on_ground <= 1;
                end

                // 충돌 판정
                if(obstacles[0] != 2'b00 && dino_on_ground) begin
                    game_over <= 1;
                end

                // 점수 증가
                score <= score + 1;
                if(score >= 100000000)
                    game_over <= 1;
            end

            // 강제 게임 오버 처리 (#키)
            if(force_game_over && !game_over) begin
                game_over <= 1;
            end
        end
    end

    genvar gi;
    generate
        for(gi=0; gi<16; gi=gi+1) begin
            always @(*) begin
                obstacle_map[gi] = obstacles[gi];
            end
        end
    endgenerate

endmodule