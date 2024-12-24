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
    output wire [7:0] AR_COM,

    // Debug LED(예: jump_fw, game_over_fw)
    output wire [3:0] LED,

    // 사운드 출력을 위한 Piezo
    output wire PIEZO
);

    //---------------
    // (1) 폰트 로더
    //---------------
    wire font_loader_done;
    wire TLCD_E_font, TLCD_RS_font, TLCD_RW_font;
    wire [7:0] TLCD_DATA_font;

    custom_font_loader font_loader (
        .RESETN(RST),
        .CLK(CLK),
        .TLCD_E(TLCD_E_font),
        .TLCD_RS(TLCD_RS_font),
        .TLCD_RW(TLCD_RW_font),
        .TLCD_DATA(TLCD_DATA_font),
        .DONE(font_loader_done)
    );

    //---------------
    // (2) LCD 제어부
    //---------------
    wire TLCD_E_text, TLCD_RS_text, TLCD_RW_text;
    wire [7:0] TLCD_DATA_text;
    reg enable_lcd;  // LCD 렌더링 트리거

    reg [8*16-1:0] TEXT_UPPER;
    reg [8*16-1:0] TEXT_LOWER;

    tlcd_controller lcd_ctrl (
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

    // 폰트 로더와 텍스트 LCD 중 어느 신호를 LCD에 연결할지 MUX
    assign TLCD_E    = font_loader_done ? TLCD_E_text    : TLCD_E_font;
    assign TLCD_RS   = font_loader_done ? TLCD_RS_text   : TLCD_RS_font;
    assign TLCD_RW   = font_loader_done ? TLCD_RW_text   : TLCD_RW_font;
    assign TLCD_DATA = font_loader_done ? TLCD_DATA_text : TLCD_DATA_font;


    //---------------
    // (3) 입력 매니저
    //---------------
    wire jump_trigger;
    wire force_game_over;
    wire jump_fw;
    wire force_game_over_fw;

    input_manager im (
        .CLK(CLK),
        .RST(RST),
        .K(Keypad),
        .KSHARP(KeypadHash),
        .jump(jump_trigger),
        .game_over(force_game_over),
        .jump_fw(jump_fw),
        .game_over_fw(force_game_over_fw)
    );

    // LED 출력(간단한 예)
    // LED[0] = jump_fw, LED[1] = game_over_fw, 나머지는 예시로 0
    assign LED[0] = jump_fw;
    assign LED[1] = force_game_over_fw;
    assign LED[2] = 1'b0;
    assign LED[3] = 1'b0;

    //---------------
    // (4) LFSR, obstacle_manager
    //---------------
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

    //---------------
    // (5) game_state_manager
    //---------------
    wire [1:0] cur_state;
    wire start_game;

    game_state_manager gsm (
        .CLK(CLK),
        .RST(RST),
        .font_loader_done(font_loader_done),
        .jump_trigger(jump_trigger),
        .force_game_over(force_game_over),
        .om_game_over(om_game_over),
        .cur_state(cur_state),
        .start_game(start_game)
    );

    //---------------
    // (6) counter (shift_enable 발생)
    //---------------
    wire shift_enable;

    counter cnt_inst (
        .CLK(CLK),
        .RST(RST),
        .shift_enable(shift_enable)
    );

    //---------------
    // (7) obstacle_manager
    //---------------
    obstacle_manager om (
        .CLK(CLK),
        .RST(RST),
        .shift_enable((cur_state == 2'd2) ? shift_enable : 1'b0), // STATE_GAME에서만 움직임
        .jump_trigger((cur_state == 2'd2) ? jump_trigger : 1'b0),
        .start_game(start_game),
        .force_game_over((cur_state == 2'd2) ? force_game_over : 1'b0),
        .rand_val(rand_val),
        .game_over(om_game_over),
        .dino_on_ground(dino_on_ground),
        .score(score),
        .obstacle_map_flat(obstacle_map_flat)
    );

    //---------------
    // (8) 7-Segment
    //---------------
    wire [7:0] com_out;
    wire seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g;

    seg_controller segc(
        .CLK(CLK),
        .RST(RST),
        .BINARY_SCORE((cur_state == 2'd2 || cur_state == 2'd3) ? score : 0),
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

    //---------------
    // (9) 사운드 모듈
    //---------------
    // jump_trigger가 상승할 때마다(sound_enable)
    // 0.2초간 4옥타브 미 출력
    reg prev_jump;
    wire sound_enable_rising = (jump_trigger && !prev_jump);

    sound snd (
        .CLK(CLK),
        .RST(RST),
        .sound_enable(sound_enable_rising),
        .piezo_out(PIEZO)
    );

    always @(posedge CLK or posedge RST) begin
        if(RST) prev_jump <= 0;
        else prev_jump <= jump_trigger;
    end

    //---------------
    // LCD 표시 문자열 갱신 로직
    //---------------
    integer i;
    reg [7:0] upper_line[0:15];
    reg [7:0] lower_line[0:15];
    reg [1:0] obs_val;

    // obstacle_map_flat에서 특정 인덱스의 장애물(2비트) 읽는 함수
    function [1:0] get_obstacle;
        input [31:0] flat;
        input [3:0] idx;
    begin
        get_obstacle = flat[ 2*idx +: 2 ];
    end
    endfunction

    // 장애물 문자(2'b01, 2'b10)를 특정 LCD용 문자로 변환
    function [7:0] get_char_for_obstacle_char(input [1:0] obs);
        begin
            if(obs == 2'b00) get_char_for_obstacle_char = 8'h20; // space
            else get_char_for_obstacle_char = 8'h04; // custom obstacle char
        end
    endfunction

    // 공룡 문자 선택 함수
    // score >> 1 의 LSB로 걷기 모션 결정(0이면 8'h00, 1이면 8'h01), 공중(점프)이면 8'h02
    function [7:0] get_dino_char(
        input dino_on_ground,
        input [31:0] sc
    );
        begin
            if(dino_on_ground) begin
                if(((sc >> 1) & 1) == 0)
                    get_dino_char = 8'h00; // 첫 걸음
                else
                    get_dino_char = 8'h01; // 두 번째 걸음
            end else begin
                get_dino_char = 8'h02;     // 점프 모션
            end
        end
    endfunction

    // 이전 상태 저장(상태 변화 시 LCD 갱신)
    reg [1:0] prev_state;

    // shift_enable의 Rising Edge 검출
    reg prev_shift_enable;
    always @(posedge CLK or posedge RST) begin
        if(RST)
            prev_shift_enable <= 0;
        else
            prev_shift_enable <= shift_enable;
    end

    wire shift_enable_rise = (shift_enable && !prev_shift_enable);

    always @(posedge CLK or posedge RST) begin
        if(RST) begin
            prev_state <= 2'd0;
            enable_lcd <= 0;
        end else begin
            prev_state <= cur_state;

            // 매 cycle 마다 기본은 enable_lcd = 0
            // 아래 조건에 따라 1로 잠깐 세팅
            enable_lcd <= 0;

            // (1) 상태가 바뀌면 다음 cycle에 LCD 갱신 트리거
            if(prev_state != cur_state) begin
                enable_lcd <= 1;
            end
            // (2) shift_enable의 Rising Edge 시에도 화면 갱신
            //     즉, 장애물이 움직인 다음 갱신
            //     -> 간단히 하기 위해 한 cycle 뒤 enable_lcd = 1
            //        (Rising Edge 검출 필요)

            if(shift_enable_rise) begin
                enable_lcd <= 1;
            end
        end
    end

    //---------------
    // LCD 문자열 작성
    //---------------
    always @(*) begin
        // 기본값
        TEXT_UPPER = "                ";
        TEXT_LOWER = "                ";

        for(i=0; i<16; i=i+1) begin
            upper_line[i] = 8'h20;
            lower_line[i] = 8'h20;
        end

        case(cur_state)
            2'd0: begin // STATE_FONT_LOAD
                TEXT_UPPER = "LOADING FONTS... ";
                TEXT_LOWER = "                ";
            end

            2'd1: begin // STATE_MAIN_MENU
                TEXT_UPPER = "   PRESS ANY KEY ";
                TEXT_LOWER = {8'h00,"  TO START GAME"};
                // 예: 8'h00(공룡 첫모양), "  TO START GAME"
            end

            2'd2: begin // STATE_GAME
                // 공룡 표시
                if(dino_on_ground)
                    lower_line[0] = get_dino_char(dino_on_ground, score);
                else
                    upper_line[0] = get_dino_char(dino_on_ground, score);

                // 장애물 표시
                for(i=0; i<16; i=i+1) begin
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

            2'd3: begin // STATE_GAME_OVER
                TEXT_UPPER = "GAME OVER       ";

                // 장애물 표시
                for(i=0; i<16; i=i+1) begin
                    obs_val = get_obstacle(obstacle_map_flat, i);
                    if(obs_val != 2'b00) begin
                        lower_line[i] = get_char_for_obstacle_char(obs_val);
                    end
                end
                
                TEXT_LOWER = {
                    lower_line[0],lower_line[1],lower_line[2],lower_line[3],
                    lower_line[4],lower_line[5],lower_line[6],lower_line[7],
                    lower_line[8],lower_line[9],lower_line[10],lower_line[11],
                    lower_line[12],lower_line[13],lower_line[14],lower_line[15]
                };
            end
        endcase
    end

endmodule