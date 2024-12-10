module main(
    input wire CLK,          // 1MHz
    input wire RESETN,       // active low
    input wire [9:0] KEY,    // keypad 0~9
    input wire KEY_HASH,     // '#' button for jump
    output wire TLCD_E,
    output wire TLCD_RS,
    output wire TLCD_RW,
    output wire [7:0] TLCD_DATA,
    output wire AR_SEG_A,
    output wire AR_SEG_B,
    output wire AR_SEG_C,
    output wire AR_SEG_D,
    output wire AR_SEG_E,
    output wire AR_SEG_F,
    output wire AR_SEG_G,
    output wire [7:0] AR_COM
);

    wire rst = ~RESETN;

    // 0.25s pulse
    reg [17:0] cnt_250ms;
    reg quarter_sec_pulse;
    always @(posedge CLK or posedge rst) begin
        if(rst) begin
            cnt_250ms <= 0;
            quarter_sec_pulse <= 0;
        end else begin
            if(cnt_250ms < 250000-1) begin
                cnt_250ms <= cnt_250ms + 1;
                quarter_sec_pulse <= 0;
            end else begin
                cnt_250ms <= 0;
                quarter_sec_pulse <= 1;
            end
        end
    end

    // Trigger for any key and jump key
    wire any_key_in = |KEY;
    wire any_key_trigger;
    trigger trig_anykey (.clk(CLK), .rst(rst), .signal_in(any_key_in), .triggered(any_key_trigger));

    wire jump_trigger;
    trigger trig_jump (.clk(CLK), .rst(rst), .signal_in(KEY_HASH), .triggered(jump_trigger));

    // Font loader & LCD controller
    wire font_loader_done;
    wire TLCD_E_font, TLCD_RS_font, TLCD_RW_font;
    wire [7:0] TLCD_DATA_font;

    wire TLCD_E_text, TLCD_RS_text, TLCD_RW_text;
    wire [7:0] TLCD_DATA_text;
    reg enable_lcd;

    custom_font_loader font_loader(
        .RESETN(RESETN),
        .CLK(CLK),
        .TLCD_E(TLCD_E_font),
        .TLCD_RS(TLCD_RS_font),
        .TLCD_RW(TLCD_RW_font),
        .TLCD_DATA(TLCD_DATA_font),
        .DONE(font_loader_done)
    );

    always @(posedge CLK or posedge rst) begin
        if(rst) enable_lcd <= 0;
        else if(font_loader_done) enable_lcd <= 1;
    end

    reg [8*16-1:0] upper_str;
    reg [8*16-1:0] lower_str;

    tlcd_controller lcd_inst (
        .RESETN(RESETN),
        .CLK(CLK),
        .ENABLE(enable_lcd),
        .TLCD_E(TLCD_E_text),
        .TLCD_RS(TLCD_RS_text),
        .TLCD_RW(TLCD_RW_text),
        .TLCD_DATA(TLCD_DATA_text),
        .TEXT_STRING_UPPER(upper_str),
        .TEXT_STRING_LOWER(lower_str)
    );

    assign TLCD_E    = font_loader_done ? TLCD_E_text    : TLCD_E_font;
    assign TLCD_RS   = font_loader_done ? TLCD_RS_text   : TLCD_RS_font;
    assign TLCD_RW   = font_loader_done ? TLCD_RW_text   : TLCD_RW_font;
    assign TLCD_DATA = font_loader_done ? TLCD_DATA_text : TLCD_DATA_font;

    // Game states
    localparam ST_LOAD_FONT = 3'd0;
    localparam ST_MAIN = 3'd1;
    localparam ST_GAME = 3'd2;
    localparam ST_GAME_OVER = 3'd3;

    reg [2:0] game_state;

    // Obstacle register (2bits *16)
    reg [31:0] obstacle_reg; // [1:0] pos0, [31:30] pos15
    reg [31:0] score;
    reg dino_jump; // 0: ground, 1: jump
    reg [7:0] rand_num;

    // LFSR for random
    lfsr_8bit lfsr_inst(.CLK(CLK), .RST(rst), .rand_out(rand_num));

    // 점프 유지 시간 측정 (0.75초 = 3 * 0.25초)
    reg [1:0] jump_cnt;
    reg input_flag;
    always @(posedge CLK or posedge rst) begin
        if(rst) begin
            input_flag <= 0;
        end else begin
            if(any_key_in || KEY_HASH) input_flag <= 1;
            if(quarter_sec_pulse) input_flag <= 0;
        end
    end

    always @(posedge CLK or posedge rst) begin
        if(rst) begin
            game_state <= ST_LOAD_FONT;
            obstacle_reg <= 0;
            score <= 0;
            dino_jump <= 0;
            jump_cnt <= 0;
            upper_str <= "                ";
            lower_str <= "                ";
        end else begin
            case(game_state)
            ST_LOAD_FONT: begin
                if(font_loader_done) begin
                    game_state <= ST_MAIN;
                    upper_str <= "    PRESS ANY KEY";
                    lower_str <= {8'h00,"  TO START GAME"};
                end
            end
            ST_MAIN: begin
                if(any_key_trigger) begin
                    game_state <= ST_GAME;
                    score <= 0;
                    obstacle_reg <= 0;
                    dino_jump <= 0;
                    jump_cnt <= 0;
                    upper_str <= "                ";
                    lower_str <= {8'h00,8'h02,"           ",8'h04};
                end
            end
            ST_GAME: begin
                if(quarter_sec_pulse) begin
                    // 입력 반영
                    if(input_flag) begin
                        if(jump_trigger) begin
                            // '#' 눌리면 게임 오버
                            game_state <= ST_GAME_OVER;
                        end else begin
                            dino_jump <= 1;
                            jump_cnt <= 0;
                        end
                    end

                    // 점프 유지
                    if(dino_jump) begin
                        if(jump_cnt < 3) jump_cnt <= jump_cnt + 1;
                        else begin
                            dino_jump <= 0;
                            jump_cnt <= 0;
                        end
                    end

                    // 장애물 이동
                    obstacle_reg <= obstacle_reg >> 2;
                    // 장애물 생성
                    if((|obstacle_reg[31:10])==0) begin
                        if(rand_num[1:0]!=2'b11) begin
                            obstacle_reg[31:30] <= (rand_num[2])?2'b01:2'b10;
                        end else begin
                            obstacle_reg[31:30] <= 2'b00;
                        end
                    end else begin
                        obstacle_reg[31:30] <= 2'b00;
                    end

                    // 점수 증가
                    score <= score + 1;

                    // 충돌 판정
                    if((obstacle_reg[1:0]!=2'b00) && (dino_jump==0)) begin
                        game_state <= ST_GAME_OVER;
                    end

                    // LCD 업데이트
                    integer i;
                    reg [7:0] line2[0:15];
                    line2[0] = dino_jump ? 8'h02 : 8'h00;
                    for(i=1;i<16;i=i+1) begin
                        case(obstacle_reg[i*2+1:i*2])
                            2'b01: line2[i]=8'h03;
                            2'b10: line2[i]=8'h04;
                            default: line2[i]=8'h20;
                        endcase
                    end
                    upper_str <= "                ";
                    lower_str <= {line2[15],line2[14],line2[13],line2[12],
                                  line2[11],line2[10],line2[9],line2[8],
                                  line2[7],line2[6],line2[5],line2[4],
                                  line2[3],line2[2],line2[1],line2[0]};
                end
            end
            ST_GAME_OVER: begin
                upper_str <= "    GAME OVER    ";
                lower_str <= {8'h04,"         ",8'h03};
                if(any_key_trigger) begin
                    game_state <= ST_MAIN;
                    upper_str <= "    PRESS ANY KEY";
                    lower_str <= {8'h00,"  TO START GAME"};
                end
            end
            endcase
        end
    end

    // 점수를 BCD 변환하여 7-Segment에 표시
    wire bcd_done;
    reg bcd_start;
    wire [3:0] BCD0, BCD1, BCD2, BCD3, BCD4, BCD5, BCD6, BCD7;

    always @(posedge CLK or posedge rst) begin
        if(rst) bcd_start <= 0;
        else if(quarter_sec_pulse) bcd_start <= 1; // 매 0.25초마다 점수 업데이트 시도
        else if(bcd_done) bcd_start <= 0;
    end

    binary_to_bcd b2b_inst (
        .CLK(CLK),
        .RST(rst),
        .BIN(score),
        .START(bcd_start),
        .DONE(bcd_done),
        .BCD0(BCD0),
        .BCD1(BCD1),
        .BCD2(BCD2),
        .BCD3(BCD3),
        .BCD4(BCD4),
        .BCD5(BCD5),
        .BCD6(BCD6),
        .BCD7(BCD7)
    );

    wire [33:0] seg_num;
    assign seg_num = {BCD7,BCD6,BCD5,BCD4,BCD3,BCD2,BCD1,BCD0, 2'b00}; // 상위2비트 무시

    seg_controller seg_ctrl(
        .CLK(CLK),
        .RST(rst),
        .NUM(seg_num),
        .AR_SEG_A(AR_SEG_A),
        .AR_SEG_B(AR_SEG_B),
        .AR_SEG_C(AR_SEG_C),
        .AR_SEG_D(AR_SEG_D),
        .AR_SEG_E(AR_SEG_E),
        .AR_SEG_F(AR_SEG_F),
        .AR_SEG_G(AR_SEG_G),
        .AR_COM(AR_COM)
    );

endmodule