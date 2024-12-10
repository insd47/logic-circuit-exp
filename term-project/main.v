module main(
    input wire CLK,
    input wire RST,
    input wire [9:0] Keypad,
    input wire KeypadHash,
    // Text LCD
    output wire TLCD_E,
    output wire TLCD_RS,
    output wire TLCD_RW,
    output wire [7:0] TLCD_DATA,
    // 7-Segment
    output wire [6:0] AR_SEG_AtoG,
    output wire [7:0] Com
);
    // 상태 정의
    localparam STATE_FONT_LOAD = 0;
    localparam STATE_MAIN_MENU = 1;
    localparam STATE_GAME      = 2;
    localparam STATE_GAME_OVER = 3;

    reg [1:0] cur_state, next_state;

    wire font_loader_done;
    reg enable_lcd;
    wire TLCD_E_font, TLCD_RS_font, TLCD_RW_font;
    wire [7:0] TLCD_DATA_font;

    wire TLCD_E_text, TLCD_RS_text, TLCD_RW_text;
    wire [7:0] TLCD_DATA_text;

    // Text LCD 문자열
    reg [8*16-1:0] TEXT_UPPER;
    reg [8*16-1:0] TEXT_LOWER;

    // 16x2 LCD에 표시할 문자열
    integer i;
    reg [7:0] upper_line[0:15];
    reg [7:0] lower_line[0:15];
    reg [1:0] obs_val;

    // font loader
    custom_font_loader font_loader (
        .RESETN(RST),
        .CLK(CLK),
        .TLCD_E(TLCD_E_font),
        .TLCD_RS(TLCD_RS_font),
        .TLCD_RW(TLCD_RW_font),
        .TLCD_DATA(TLCD_DATA_font),
        .DONE(font_loader_done)
    );

    // LCD Controller
    tlcd_controller lcd_ctrl(
        .RESETN(RST),
        .CLK(CLK),
        .ENABLE(enable_lcd),
        .TLCD_E(TLCD_E_text),
        .TLCD_RS(TLCD_RS_text),
        .TLCD_RW(TLCD_RW_text),
        .TLCD_DATA(TLCD_DATA_text),
        .TEXT_STRING_UPPER(TEXT_UPPER),
        .TEXT_STRING_LOWER(TEXT_LOWER)
    );

    assign TLCD_E    = font_loader_done ? TLCD_E_text    : TLCD_E_font;
    assign TLCD_RS   = font_loader_done ? TLCD_RS_text   : TLCD_RS_font;
    assign TLCD_RW   = font_loader_done ? TLCD_RW_text   : TLCD_RW_font;
    assign TLCD_DATA = font_loader_done ? TLCD_DATA_text : TLCD_DATA_font;

    // Key trigger
    reg any_digit_input;
    integer k;
    always @(*) begin
        any_digit_input = 1'b0;
        for(k=0; k<10; k=k+1) begin
            if(Keypad[k] == 1'b1) any_digit_input = 1'b1;
        end
    end

    wire trig_any_digit;
    wire trig_hash;

    trigger trig_digit (
        .clk(CLK),
        .rst(RST),
        .signal_in(any_digit_input),
        .triggered(trig_any_digit)
    );

    trigger trig_hash_in (
        .clk(CLK),
        .rst(RST),
        .signal_in(KeypadHash),
        .triggered(trig_hash)
    );

    // lfsr 인스턴스
    wire [15:0] rand_val;
    lfsr lfsr_inst (
        .CLK(CLK),
        .RST(RST),
        .rand_out(rand_val)
    );

    // obstacle_manager
    wire om_game_over;
    wire dino_on_ground;
    wire [31:0] score;
    wire [31:0] obstacle_map_flat;

    reg start_game;

    reg shift_enable;
    reg [17:0] timer_cnt;
    always @(posedge CLK or posedge RST) begin
        if(RST) begin
            timer_cnt <= 0;
            shift_enable <= 0;
        end else begin
            if(timer_cnt < 250000) begin
                timer_cnt <= timer_cnt + 1;
                shift_enable <= 0;
            end else begin
                timer_cnt <= 0;
                shift_enable <= 1;
            end
        end
    end

    wire force_game_over_signal = (cur_state == STATE_GAME) ? trig_hash : 1'b0;
    wire jump_trigger_signal = (cur_state == STATE_GAME && trig_any_digit);

    obstacle_manager om (
        .CLK(CLK),
        .RST(RST),
        .shift_enable((cur_state == STATE_GAME) ? shift_enable : 1'b0),
        .jump_trigger(jump_trigger_signal),
        .start_game(start_game),
        .force_game_over(force_game_over_signal),
        .rand_val(rand_val),
        .game_over(om_game_over),
        .dino_on_ground(dino_on_ground),
        .score(score),
        .obstacle_map_flat(obstacle_map_flat)
    );

    // 7-Segment
    wire [6:0] AR_SEG_AtoG_w;
    wire [7:0] com_out;
    seg_controller segc(
        .CLK(CLK),
        .RST(RST),
        .BINARY_SCORE((cur_state == STATE_GAME || cur_state == STATE_GAME_OVER) ? score : 0),
        .Com(com_out),
        .AR_SEG_A(AR_SEG_AtoG_w[6]),
        .AR_SEG_B(AR_SEG_AtoG_w[5]),
        .AR_SEG_C(AR_SEG_AtoG_w[4]),
        .AR_SEG_D(AR_SEG_AtoG_w[3]),
        .AR_SEG_E(AR_SEG_AtoG_w[2]),
        .AR_SEG_F(AR_SEG_AtoG_w[1]),
        .AR_SEG_G(AR_SEG_AtoG_w[0])
    );

    // AR_SEG_AtoG_w는 A-G를 [6:0]으로 묶어서 상위에 할당
    assign AR_SEG_AtoG = AR_SEG_AtoG_w;
    assign Com = com_out;

    // 상태 전이
    always @(posedge CLK or posedge RST) begin
        if(RST) cur_state <= STATE_FONT_LOAD;
        else cur_state <= next_state;
    end

    always @(*) begin
        next_state = cur_state;
        case(cur_state)
            STATE_FONT_LOAD: begin
                if(font_loader_done) next_state = STATE_MAIN_MENU;
            end
            STATE_MAIN_MENU: begin
                if(trig_any_digit) next_state = STATE_GAME;
            end
            STATE_GAME: begin
                if(om_game_over) next_state = STATE_GAME_OVER;
            end
            STATE_GAME_OVER: begin
                // 아무 키나 눌러도 게임 다시 시작
                if(trig_any_digit || trig_hash) next_state = STATE_GAME;
            end
        endcase
    end

    // enable_lcd 제어
    always @(posedge CLK or posedge RST) begin
        if(RST) enable_lcd <= 0;
        else if(font_loader_done) enable_lcd <= 1;
    end

    // start_game 제어
    always @(posedge CLK or posedge RST) begin
        if(RST) begin
            start_game <= 0;
        end else begin
            start_game <= 0;
            if((cur_state == STATE_MAIN_MENU && next_state == STATE_GAME) ||
               (cur_state == STATE_GAME_OVER && next_state == STATE_GAME))
                start_game <= 1;
        end
    end

    // obstacle_map_flat에서 각 칸을 읽어 LCD에 표현
    // obstacle_map_flat[2*i+1:2*i] == 2'b00: 없음, 2'b01, 2'b10: 장애물
    function [7:0] get_char_for_obstacle(input [1:0] obs_val);
        begin
            if(obs_val == 2'b00) get_char_for_obstacle = 8'h20; // space
            else get_char_for_obstacle = 8'h04; // obstacle char
        end
    endfunction

    // LCD 문자 세팅
    always @(*) begin
        case(cur_state)
            STATE_FONT_LOAD: begin
                TEXT_UPPER = "LOADING FONTS...  ";
                TEXT_LOWER = "                ";
            end
            STATE_MAIN_MENU: begin
                TEXT_UPPER = "    PRESS ANY KEY";
                TEXT_LOWER = {8'h00,"  TO START GAME"};
            end
            STATE_GAME: begin
                for(i=0;i<16;i=i+1) begin
                    upper_line[i] = 8'h20;
                    lower_line[i] = 8'h20;
                end

                // 공룡 표시
                if(dino_on_ground)
                    lower_line[0] = 8'h00;
                else
                    upper_line[0] = 8'h03;

                // 장애물 표시
                for(i=0;i<16;i=i+1) begin
                    obs_val = obstacle_map_flat[2*i+1:2*i];
                    if(obs_val != 2'b00) begin
                        lower_line[i] = 8'h04;
                    end
                end

                // 배열을 문자열로 변환
                TEXT_UPPER = {upper_line[0],upper_line[1],upper_line[2],upper_line[3],
                              upper_line[4],upper_line[5],upper_line[6],upper_line[7],
                              upper_line[8],upper_line[9],upper_line[10],upper_line[11],
                              upper_line[12],upper_line[13],upper_line[14],upper_line[15]};

                TEXT_LOWER = {lower_line[0],lower_line[1],lower_line[2],lower_line[3],
                              lower_line[4],lower_line[5],lower_line[6],lower_line[7],
                              lower_line[8],lower_line[9],lower_line[10],lower_line[11],
                              lower_line[12],lower_line[13],lower_line[14],lower_line[15]};
            end
            STATE_GAME_OVER: begin
                TEXT_UPPER = "GAME OVER       ";
                TEXT_LOWER = {8'h04,"         ",8'h03," "};
            end
            default: begin
                TEXT_UPPER = "                ";
                TEXT_LOWER = "                ";
            end
        endcase
    end

endmodule