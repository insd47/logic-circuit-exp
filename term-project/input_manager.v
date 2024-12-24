module input_manager (
    input wire CLK,
    input wire RST,
    input wire [9:0] K,       // Keypad 0~9
    input wire KSHARP,        // Keypad #
    
    // 출력: 트리거된 점프 / 강제오버
    output wire jump,         
    output wire game_over,
    
    // 디버그용 Forward(LED 등으로 표시 가능)
    output wire jump_fw,
    output wire game_over_fw
);

    integer i;
    reg any_digit_input;

    // jump_fw, game_over_fw: 직접 연결
    assign jump_fw = |K;           // 0~9 중 하나라도 눌리면 jump_fw = 1
    assign game_over_fw = KSHARP;  // #이 눌리면 game_over_fw = 1

    // Keypad[0..9] 중 하나라도 눌리면 any_digit_input=1
    always @(*) begin
        any_digit_input = 1'b0;
        for(i=0; i<10; i=i+1) begin
            if(K[i] == 1'b1)
                any_digit_input = 1'b1;
        end
    end

    // Trigger 모듈 2개 사용
    // 1) 점프(trigger): any_digit_input가 0→1로 변할 때(rising) 트리거
    // 2) 게임 오버(trigger): KSHARP가 0→1로 변할 때(rising) 트리거
    // 만약 falling edge 감지용 trigger.v라면, trigger.v 내부를 수정해야 합니다.
    // 여기서는 falling edge만 감지하므로, input_manager에서 제어를 바꾸거나
    // trigger.v 내부를 rising edge 감지용으로 고치십시오.
    // 예시로 trigger.v를 rising edge 감지 형태로 아래와 같이 사용하겠습니다.
    // => trigger.v 코드를 수정한다고 가정 (혹은 새로 만드시면 됩니다.)

    wire jump_trigger_raw;
    wire game_over_trigger_raw;

    // rising edge trigger를 위해 signal_in이 "현재 값" - "직전 값"을 추적
    // 여기서는 trigger 모듈과 별개로 구현(혹은 trigger.v 수정)
    reg prev_any_digit;
    reg prev_ksharp;

    always @(posedge CLK or posedge RST) begin
        if(RST) begin
            prev_any_digit <= 0;
            prev_ksharp <= 0;
        end else begin
            prev_any_digit <= any_digit_input;
            prev_ksharp <= KSHARP;
        end
    end

    assign jump_trigger_raw      = (any_digit_input && !prev_any_digit);
    assign game_over_trigger_raw = (KSHARP && !prev_ksharp);

    // 필요하면 디바운싱 로직이나 추가 처리를 여기서 수행 가능
    assign jump = jump_trigger_raw;
    assign game_over = game_over_trigger_raw;

endmodule