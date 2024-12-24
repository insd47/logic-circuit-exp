module game_state_manager (
    input wire CLK,
    input wire RST,
    input wire font_loader_done,   // 폰트 로드 완료
    input wire jump_trigger,       // 메인 메뉴→게임 시작, 게임오버→게임 재시작
    input wire force_game_over,    // 게임 도중 # 누르면 오버
    input wire om_game_over,       // obstacle_manager에서 발생한 게임오버 신호
    output reg [1:0] cur_state,    // 현재 게임 상태
    output reg start_game          // obstacle_manager로 전달할 start_game 신호
);

    localparam STATE_FONT_LOAD = 2'd0;
    localparam STATE_MAIN_MENU = 2'd1;
    localparam STATE_GAME      = 2'd2;
    localparam STATE_GAME_OVER = 2'd3;

    reg [1:0] next_state;

    always @(posedge CLK or posedge RST) begin
        if(RST) 
            cur_state <= STATE_FONT_LOAD;
        else 
            cur_state <= next_state;
    end

    always @(*) begin
        next_state = cur_state;
        case(cur_state)
            STATE_FONT_LOAD: begin
                if(font_loader_done)
                    next_state = STATE_MAIN_MENU;
            end
            STATE_MAIN_MENU: begin
                // 아무 숫자 키 누르면 게임 시작
                if(jump_trigger) 
                    next_state = STATE_GAME;
            end
            STATE_GAME: begin
                // obstacle_manager에서 게임오버 뜨면 -> STATE_GAME_OVER
                if(om_game_over)
                    next_state = STATE_GAME_OVER;
            end
            STATE_GAME_OVER: begin
                // 게임 오버 화면에서 숫자 or # 누르면 재시작
                if(jump_trigger || force_game_over)
                    next_state = STATE_GAME;
            end
        endcase
    end

    // obstacle_manager로 start_game 신호 주기
    // cur_state에서 next_state로 넘어갈 때,
    // main_menu->game, game_over->game 시점에 start_game <= 1
    always @(posedge CLK or posedge RST) begin
        if(RST) begin
            start_game <= 0;
        end else begin
            start_game <= 0;
            // 상태 전이 감지
            if( (cur_state == STATE_MAIN_MENU && next_state == STATE_GAME) ||
                (cur_state == STATE_GAME_OVER && next_state == STATE_GAME) ) begin
                start_game <= 1;
            end
        end
    end

endmodule