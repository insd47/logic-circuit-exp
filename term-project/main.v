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
    output wire AR_SEG_A,
    output wire AR_SEG_B,
    output wire AR_SEG_C,
    output wire AR_SEG_D,
    output wire AR_SEG_E,
    output wire AR_SEG_F,
    output wire AR_SEG_G,
    output wire [7:0] AR_COM
);

    // 상태 정의
    localparam STATE_FONT_LOAD = 0;
    localparam STATE_MAIN_MENU = 1;
    localparam STATE_GAME      = 2;
    localparam STATE_GAME_OVER = 3;

    reg [1:0] cur_state, next_state;
    reg [1:0] prev_state;

    wire font_loader_done;
    wire TLCD_E_font, TLCD_RS_font, TLCD_RW_font;
    wire [7:0] TLCD_DATA_font;

    wire TLCD_E_text, TLCD_RS_text, TLCD_RW_text;
    wire [7:0] TLCD_DATA_text;

    reg [8*16-1:0] TEXT_UPPER;
    reg [8*16-1:0] TEXT_LOWER;

    // LCD ENABLE 제어
    reg enable_lcd;
    reg enable_lcd_delay_state;    // 상태 변화 후 다음 사이클에 enable_lcd를 1로 복귀하기 위한 딜레이
    reg enable_lcd_delay_shift;    // shift_enable 변화 후 다음 사이클에 enable_lcd를 1로 복귀하기 위한 딜레이

    integer i;
    reg [7:0] upper_line[0:15];
    reg [7:0] lower_line[0:15];
    reg [1:0] obs_val;

    function [1:0] get_obstacle;
        input [31:0] flat;
        input [3:0] idx;
    begin
        case (idx)
            4'd0:  get_obstacle = flat[1:0];
            4'd1:  get_obstacle = flat[3:2];
            4'd2:  get_obstacle = flat[5:4];
            4'd3:  get_obstacle = flat[7:6];
            4'd4:  get_obstacle = flat[9:8];
            4'd5:  get_obstacle = flat[11:10];
            4'd6:  get_obstacle = flat[13:12];
            4'd7:  get_obstacle = flat[15:14];
            4'd8:  get_obstacle = flat[17:16];
            4'd9:  get_obstacle = flat[19:18];
            4'd10: get_obstacle = flat[21:20];
            4'd11: get_obstacle = flat[23:22];
            4'd12: get_obstacle = flat[25:24];
            4'd13: get_obstacle = flat[27:26];
            4'd14: get_obstacle = flat[29:28];
            4'd15: get_obstacle = flat[31:30];
            default: get_obstacle = 2'b00;
        endcase
    end
    endfunction

    custom_font_loader font_loader (
        .RESETN(RST),
        .CLK(CLK),
        .TLCD_E(TLCD_E_font),
        .TLCD_RS(TLCD_RS_font),
        .TLCD_RW(TLCD_RW_font),
        .TLCD_DATA(TLCD_DATA_font),
        .DONE(font_loader_done)
    );

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

    reg any_digit_input;
    integer k;
    always @(*) begin
        any_digit_input = 1'b0;
        for(k=0; k<10; k=k+1) begin
            if(Keypad[k] == 1'b1)
                any_digit_input = 1'b1;
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

    wire [15:0] rand_val;
    lfsr lfsr_inst (
        .CLK(CLK),
        .RST(RST),
        .rand_out(rand_val)
    );

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
            if(timer_cnt < 200000) begin
                timer_cnt <= timer_cnt + 1;
                shift_enable <= 0;
            end else begin
                timer_cnt <= 0;
                shift_enable <= 1;
            end
        end
    end

    reg prev_shift_enable;
    always @(posedge CLK or posedge RST) begin
        if(RST) prev_shift_enable <= 0;
        else prev_shift_enable <= shift_enable;
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

    wire [7:0] com_out;
    wire seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g;
    seg_controller segc(
        .CLK(CLK),
        .RST(RST),
        .BINARY_SCORE((cur_state == STATE_GAME || cur_state == STATE_GAME_OVER) ? score : 0),
        .Com(com_out),
        .AR_SEG_A(seg_a),
        .AR_SEG_B(seg_b),
        .AR_SEG_C(seg_c),
        .AR_SEG_D(seg_d),
        .AR_SEG_E(seg_e),
        .AR_SEG_F(seg_f),
        .AR_SEG_G(seg_g)
    );

    assign AR_COM = com_out;
    assign AR_SEG_A = seg_a;
    assign AR_SEG_B = seg_b;
    assign AR_SEG_C = seg_c;
    assign AR_SEG_D = seg_d;
    assign AR_SEG_E = seg_e;
    assign AR_SEG_F = seg_f;
    assign AR_SEG_G = seg_g;

    always @(posedge CLK or posedge RST) begin
        if(RST) begin
            cur_state <= STATE_FONT_LOAD;
            prev_state <= STATE_FONT_LOAD;
        end else begin
            prev_state <= cur_state;
            cur_state <= next_state;
        end
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
                if(trig_any_digit || trig_hash) next_state = STATE_GAME;
            end
        endcase
    end

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

    function [7:0] get_char_for_obstacle_char(input [1:0] obs_val);
        begin
            if(obs_val == 2'b00) get_char_for_obstacle_char = 8'h20; // space
            else get_char_for_obstacle_char = 8'h04; // obstacle char
        end
    endfunction

    // 공룡 걷기 모션 결정 로직
    // score >> 1의 LSB를 확인하여 0이면 8'h00, 1이면 8'h01
    function [7:0] get_dino_char(
        input dino_on_ground,
        input [31:0] sc
    );
        begin
            if(dino_on_ground) begin
                if(((sc >> 1) & 1) == 0)
                    get_dino_char = 8'h00;
                else
                    get_dino_char = 8'h01;
            end else begin
                // 점프 시 공룡 문자: 기존에 8'h02 사용
                get_dino_char = 8'h02;
            end
        end
    endfunction

    always @(*) begin
        TEXT_UPPER = "                ";
        TEXT_LOWER = "                ";

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

                // 공룡 표시: 걷기 모션 적용
                if(dino_on_ground) begin
                    // dino_on_ground일 때 get_dino_char로 결정
                    lower_line[0] = get_dino_char(dino_on_ground, score);
                end else begin
                    // 점프 중에는 공룡 char = 8'h02
                    upper_line[0] = get_dino_char(dino_on_ground, score);
                end

                // 장애물 표시
                for(i=0;i<16;i=i+1) begin
                    obs_val = get_obstacle(obstacle_map_flat, i);
                    if(obs_val != 2'b00) begin
                        lower_line[i] = get_char_for_obstacle_char(obs_val);
                    end
                end

                TEXT_UPPER = {
                    upper_line[0],upper_line[1],upper_line[2],upper_line[3],
                    upper_line[4],upper_line[5],upper_line[6],upper_line[7],
                    upper_line[8],upper_line[9],upper_line[10],upper_line[11],
                    upper_line[12],upper_line[13],upper_line[14],upper_line[15]
                };

                TEXT_LOWER = {
                    lower_line[0],lower_line[1],lower_line[2],lower_line[3],
                    lower_line[4],lower_line[5],lower_line[6],lower_line[7],
                    lower_line[8],lower_line[9],lower_line[10],lower_line[11],
                    lower_line[12],lower_line[13],lower_line[14],lower_line[15]
                };
            end
            STATE_GAME_OVER: begin
                TEXT_UPPER = "GAME OVER       ";
                TEXT_LOWER = {
                    lower_line[0],lower_line[1],lower_line[2],lower_line[3],
                    lower_line[4],lower_line[5],lower_line[6],lower_line[7],
                    lower_line[8],lower_line[9],lower_line[10],lower_line[11],
                    lower_line[12],lower_line[13],lower_line[14],lower_line[15]
                };
            end
        endcase
    end

    always @(posedge CLK or posedge RST) begin
        if(RST) begin
            enable_lcd <= 0;
            enable_lcd_delay_state <= 0;
            enable_lcd_delay_shift <= 0;
        end else begin
            // 상태 변화 감지
            if(prev_state != cur_state) begin
                enable_lcd <= 0;
                enable_lcd_delay_state <= 1;
            end else if(enable_lcd_delay_state) begin
                enable_lcd <= 1;
                enable_lcd_delay_state <= 0;
            end

            // shift_enable Rising Edge 감지
            if(!prev_shift_enable && shift_enable) begin
                enable_lcd <= 0;
                enable_lcd_delay_shift <= 1;
            end else if(enable_lcd_delay_shift) begin
                enable_lcd <= 1;
                enable_lcd_delay_shift <= 0;
            end
        end
    end

endmodule