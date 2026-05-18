`default_nettype none

module tt_um_snake_game (
    input  wire [7:0] ui_in,    // [0]=UP [1]=DOWN [2]=LEFT [3]=RIGHT
    output wire [7:0] uo_out,   // VGA output (TinyVGA Pmod)
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // ==========================================
    // 1. VGA SYNC
    // ==========================================
    wire hsync, vsync, display_on;
    wire [9:0] hpos, vpos;
    hvsync_generator hvsync_gen (
        .clk(clk), .reset(~rst_n),
        .hsync(hsync), .vsync(vsync),
        .display_on(display_on),
        .hpos(hpos), .vpos(vpos)
    );

    // ==========================================
    // 2. CONSTANTS
    // ==========================================
    // Virtual resolution: 320x240 (screen / 2)
    // Grid: 8x8 virtual pixels per cell -> 40 cols x 30 rows
    // Border: col 0, col 39, row 0, row 29
    // Playable: cols 1-38, rows 1-28

    localparam MAX_LEN  = 32;   // max snake length
    localparam LEN_BITS = 5;

    localparam DIR_UP_1    = 2'd0;
    localparam DIR_DOWN_1  = 2'd1;
    localparam DIR_LEFT_1  = 2'd2;
    localparam DIR_RIGHT_1 = 2'd3;
    localparam DIR_UP_2    = 2'd0;
    localparam DIR_DOWN_2  = 2'd1;
    localparam DIR_LEFT_2  = 2'd2;
    localparam DIR_RIGHT_2 = 2'd3;

    // ==========================================
    // 3. INPUT
    // ==========================================
    wire btn_up_1    = ui_in[0];
    wire btn_down_1  = ui_in[1];
    wire btn_left_1  = ui_in[2];
    wire btn_right_1 = ui_in[3];
    wire btn_up_2    = ui_in[4];
    wire btn_down_2  = ui_in[5];
    wire btn_left_2  = ui_in[6];
    wire btn_right_2 = ui_in[7];

    // ==========================================
    // 4. TIMING
    // ==========================================
    wire frame_tick = (vpos == 479 && hpos == 639);

    // Move snake every 8 frames (~7.5 steps/sec at 60fps)
    reg [3:0] frame_cnt;
    wire game_tick = frame_tick && (frame_cnt == 4'd7);

    always @(posedge clk) begin
        if (~rst_n)
            frame_cnt <= 4'd0;
        else if (frame_tick)
            frame_cnt <= (frame_cnt == 4'd7) ? 4'd0 : frame_cnt + 4'd1;
    end

    // ==========================================
    // 5. LFSR (pseudo-random for food placement)
    // ==========================================



    // ==========================================
    // 6. J1
    // ==========================================
    reg [5:0] seg_col_1 [0:MAX_LEN-1];  // 6 bits for col (0-39)
    reg [4:0] seg_row_1 [0:MAX_LEN-1];  // 5 bits for row (0-29)
    reg [LEN_BITS-1:0] head_ptr_1;
    reg [LEN_BITS-1:0] tail_ptr_1;
    reg [LEN_BITS-1:0] snake_len_1;

    wire [5:0] head_col_1 = seg_col_1[head_ptr_1];
    wire [4:0] head_row_1 = seg_row_1[head_ptr_1];


// ==========================================
    // 6. J2
    // ==========================================
    reg [5:0] seg_col_2 [0:MAX_LEN-1];  // 6 bits for col (0-39)
    reg [4:0] seg_row_2 [0:MAX_LEN-1];  // 5 bits for row (0-29)
    reg [LEN_BITS-1:0] head_ptr_2;
    reg [LEN_BITS-1:0] tail_ptr_2;
    reg [LEN_BITS-1:0] snake_len_2;
 
    wire [5:0] head_col_2 = seg_col_2[head_ptr_2];
    wire [4:0] head_row_2 = seg_row_2[head_ptr_2];
    


    // ==========================================
    // 7. DIRECTION_1 CONTROL
    // ==========================================
    reg [1:0] direction_1, next_dir_1;

    always @(posedge clk) begin
        if (~rst_n) begin
            next_dir_1 <= DIR_RIGHT_1;
        end else begin
            // Latch direction_1, prevent 180-degree reversal
            if      (btn_up_1    && direction_1 != DIR_DOWN_1)  next_dir_1 <= DIR_UP_1;
            else if (btn_down_1  && direction_1 != DIR_UP_1)    next_dir_1 <= DIR_DOWN_1;
            else if (btn_left_1  && direction_1 != DIR_RIGHT_1) next_dir_1 <= DIR_LEFT_1;
            else if (btn_right_1 && direction_1 != DIR_LEFT_1)  next_dir_1 <= DIR_RIGHT_1;
        end
    end


    // ==========================================
    // 7. DIRECTION_1 CONTROL
    // ==========================================
    reg [1:0] direction_2, next_dir_2;

    always @(posedge clk) begin
        if (~rst_n) begin
            next_dir_2 <= DIR_RIGHT_2;
        end else begin
            // Latch direction_2, prevent 180-degree reversal
            if      (btn_up_2    && direction_2 != DIR_DOWN_2)  next_dir_2 <= DIR_UP_2;
            else if (btn_down_2  && direction_2 != DIR_UP_2)    next_dir_2 <= DIR_DOWN_2;
            else if (btn_left_2  && direction_2 != DIR_RIGHT_2) next_dir_2 <= DIR_LEFT_2;
            else if (btn_right_2 && direction_2 != DIR_LEFT_2)  next_dir_2 <= DIR_RIGHT_2;
        end
    end








    // ==========================================
    // 8. NEXT HEAD POSITION J1
    // ==========================================
    reg [5:0] nxt_col_1;
    reg [4:0] nxt_row_1;

    always @(*) begin
        nxt_col_1 = head_col_1;
        nxt_row_1 = head_row_1;
        case (next_dir_1)
            DIR_UP_1:    nxt_row_1 = head_row_1 - 5'd1;
            DIR_DOWN_1:  nxt_row_1 = head_row_1 + 5'd1;
            DIR_LEFT_1:  nxt_col_1 = head_col_1 - 6'd1;
            DIR_RIGHT_1: nxt_col_1 = head_col_1 + 6'd1;
        endcase
    end

    // Wall collision
    wire wall_hit_1 = (nxt_col_1 == 6'd0)  || (nxt_col_1 == 6'd39) ||
                    (nxt_row_1 == 5'd0)  || (nxt_row_1 == 5'd29);



    // ==========================================
    // 8.2 NEXT HEAD POSITION J2
    // ==========================================
    reg [5:0] nxt_col_2;
    reg [4:0] nxt_row_2;
    
    always @(*) begin
        nxt_col_2 = head_col_2;
        nxt_row_2 = head_row_2;
        case (next_dir_2)
            DIR_UP_2:    nxt_row_2 = head_row_2 - 5'd1;
            DIR_DOWN_2:  nxt_row_2 = head_row_2 + 5'd1;
            DIR_LEFT_2:  nxt_col_2 = head_col_2 - 6'd1;
            DIR_RIGHT_2: nxt_col_2 = head_col_2 + 6'd1;
        endcase
    end

    // Wall collision
    wire wall_hit_2 = (nxt_col_2 == 6'd0)  || (nxt_col_2 == 6'd39) ||
                    (nxt_row_2 == 5'd0)  || (nxt_row_2 == 5'd29);

    // ==========================================
    // 9. SELF-COLLISION J1 (combinational)
    // ==========================================
    wire [MAX_LEN-1:0] body_match_1;
    genvar g;
    generate
        for (g = 0; g < MAX_LEN; g = g + 1) begin : self_chk_1
            // Unused slots are (0,0) = border, so they won't match
            // valid next positions inside playable area
            assign body_match_1[g] = (seg_col_1[g] == nxt_col_1) && (seg_row_1[g] == nxt_row_1);
        end
    endgenerate
    wire self_hit_1 = |body_match_1;



    // ==========================================
    // 9. SELF-COLLISION J2 (combinational)
    // ==========================================
    wire [MAX_LEN-1:0] body_match_2;
    generate
        for (g = 0; g < MAX_LEN; g = g + 1) begin : self_chk_2
            // Unused slots are (0,0) = border, so they won't match
            // valid next positions inside playable area
            assign body_match_2[g] = (seg_col_2[g] == nxt_col_2) && (seg_row_2[g] == nxt_row_2);
        end
    endgenerate
    wire self_hit_2 = |body_match_2;


    // ==========================================
    // 9.3 COLISIONES CRUZADAS (J1 contra J2 y J2 contra J1)
    // ==========================================
    wire [MAX_LEN-1:0] cross_match_1to2; // J1 choca contra el cuerpo de J2
    wire [MAX_LEN-1:0] cross_match_2to1; // J2 choca contra el cuerpo de J1

    generate
        for (g = 0; g < MAX_LEN; g = g + 1) begin : cross_chk
            // ¿La próxima posición de J1 coincide con algún segmento activo de J2?
            assign cross_match_1to2[g] = (seg_col_2[g] == nxt_col_1) && 
                                         (seg_row_2[g] == nxt_row_1) && 
                                         (seg_col_2[g] != 6'd63);

            // ¿La próxima posición de J2 coincide con algún segmento activo de J1?
            assign cross_match_2to1[g] = (seg_col_1[g] == nxt_col_2) && 
                                         (seg_row_1[g] == nxt_row_2) && 
                                         (seg_col_1[g] != 6'd63);
        end
    endgenerate

    wire cross_hit_1 = |cross_match_1to2; // J1 impactó a J2
    wire cross_hit_2 = |cross_match_2to1; // J2 impactó a J1


    wire head_collision = (nxt_col_1 == nxt_col_2) && (nxt_row_1 == nxt_row_2);
    // ==========================================
    // 10. GAME STATE MACHINE
    // ==========================================

    reg game_over;

    integer i;
    always @(posedge clk) begin
        if (~rst_n) begin
            for (i = 0; i < MAX_LEN; i = i + 1) begin
                seg_col_1[i] <= 6'd0;
                seg_row_1[i] <= 5'd0;
            end
            seg_col_1[0] <= 6'd4;  seg_row_1[0] <= 5'd14;
            seg_col_1[1] <= 6'd5;  seg_row_1[1] <= 5'd14;
            seg_col_1[2] <= 6'd6;  seg_row_1[2] <= 5'd14;
            seg_col_1[3] <= 6'd7;  seg_row_1[3] <= 5'd14;
            head_ptr_1   <= 5'd3;
            tail_ptr_1   <= 5'd0;
            snake_len_1  <= 5'd4;
            direction_1  <= DIR_RIGHT_1;
            for (i = 0; i < MAX_LEN; i = i + 1) begin
                seg_col_2[i] <= 6'd0;
                seg_row_2[i] <= 5'd0;
            end
            seg_col_2[0] <= 6'd4;  seg_row_2[0] <= 5'd15;
            seg_col_2[1] <= 6'd5;  seg_row_2[1] <= 5'd15;
            seg_col_2[2] <= 6'd6;  seg_row_2[2] <= 5'd15;
            seg_col_2[3] <= 6'd7;  seg_row_2[3] <= 5'd15;
            head_ptr_2   <= 5'd3;
            tail_ptr_2   <= 5'd0;
            snake_len_2  <= 5'd4;
            direction_2  <= DIR_RIGHT_2;
            game_over  <= 1'b0; 

        end else if (game_over) begin
            // Restart on any direction_1 button
            if (|ui_in[3:0]) begin
                for (i = 0; i < MAX_LEN; i = i + 1) begin
                    seg_col_1[i] <= 6'd0;
                    seg_row_1[i] <= 5'd0;
                end
                seg_col_1[0] <= 6'd4;  seg_row_1[0] <= 5'd14;
                seg_col_1[1] <= 6'd5;  seg_row_1[1] <= 5'd14;
                seg_col_1[2] <= 6'd6;  seg_row_1[2] <= 5'd14;
                seg_col_1[3] <= 6'd7;  seg_row_1[3] <= 5'd14;
                head_ptr_1   <= 5'd3;
                tail_ptr_1   <= 5'd0;
                snake_len_1  <= 5'd4;
                direction_1  <= DIR_RIGHT_1;
                game_over  <= 1'b0;
            end
            if (|ui_in[7:4]) begin
                for (i = 0; i < MAX_LEN; i = i + 1) begin
                    seg_col_2[i] <= 6'd0;
                    seg_row_2[i] <= 5'd0;
                end
                seg_col_2[0] <= 6'd4;  seg_row_2[0] <= 5'd15;
                seg_col_2[1] <= 6'd5;  seg_row_2[1] <= 5'd15;
                seg_col_2[2] <= 6'd6;  seg_row_2[2] <= 5'd15;
                seg_col_2[3] <= 6'd7;  seg_row_2[3] <= 5'd15;
                head_ptr_2   <= 5'd3;
                tail_ptr_2   <= 5'd0;
                snake_len_2  <= 5'd4;
                direction_2  <= DIR_RIGHT_2;
                game_over  <= 1'b0;
            end
        end else if (game_tick) begin
            direction_1 <= next_dir_1;
            direction_2 <= next_dir_2;

            if (wall_hit_1 || self_hit_1 || cross_hit_1 ||
                wall_hit_2 || self_hit_2 || cross_hit_2 || head_collision) begin
                game_over <= 1'b1;
            end else begin
                // Advance head in circular buffer
                head_ptr_1 <= (head_ptr_1 + 5'd1) & 5'd31;
                seg_col_1[(head_ptr_1 + 5'd1) & 5'd31] <= nxt_col_1;
                seg_row_1[(head_ptr_1 + 5'd1) & 5'd31] <= nxt_row_1;

                // Normal move: clear old tail, advance tail pointer
                tail_ptr_1 <= (tail_ptr_1 + 5'd1) & 5'd31;


                // Advance head in circular buffer
                head_ptr_2 <= (head_ptr_2 + 5'd1) & 5'd31;
                seg_col_2[(head_ptr_2 + 5'd1) & 5'd31] <= nxt_col_2;
                seg_row_2[(head_ptr_2 + 5'd1) & 5'd31] <= nxt_row_2;

                // Normal move: clear old tail, advance tail pointer
                tail_ptr_2 <= (tail_ptr_2 + 5'd1) & 5'd31;
                
            end
        end
    end

    // ==========================================
    // 11. PIXEL DRAWING
    // ==========================================
    // Virtual coords: divide screen by 2
    wire [8:0] vx = hpos[9:1];  // 0..319
    wire [7:0] vy = vpos[9:1];  // 0..239

    // Grid cell = vx / 8, vy / 8 (just shift right by 3)
    wire [5:0] pcol = {1'b0, vx[8:3]};  // 0..39
    wire [4:0] prow = vy[7:3];           // 0..29

    // Position within cell (0..7)
    wire [2:0] cx = vx[2:0];
    wire [2:0] cy = vy[2:0];

    // --- Border ---
    wire is_border = (pcol == 6'd0)  || (pcol == 6'd39) ||
                     (prow == 5'd0)  || (prow == 5'd29);

    wire border_checker = (cx[2] ^ cy[2]) & is_border;


    // --- Snake segments (parallel match) ---
    wire [MAX_LEN-1:0] seg_hit_1;
    wire [MAX_LEN-1:0] seg_hit_2;

    generate
        for (g = 0; g < MAX_LEN; g = g + 1) begin : draw_chk_1
            assign seg_hit_1[g] = (seg_col_1[g] == pcol) && (seg_row_1[g] == prow);
        end
    endgenerate
    
    wire is_snake_1_cell = |seg_hit_1;
    wire is_head_1_cell  = (pcol == head_col_1) && (prow == head_row_1);
 
/////////////

    generate
        for (g = 0; g < MAX_LEN; g = g + 1) begin : draw_chk_2
            assign seg_hit_2[g] = (seg_col_2[g] == pcol) && (seg_row_2[g] == prow);
        end
    endgenerate
    
    wire is_snake_2_cell = |seg_hit_2;
    wire is_head_2_cell  = (pcol == head_col_2) && (prow == head_row_2);

    // Cell inner fill (1px padding for grid effect)
    wire cell_fill = (cx > 3'd0) && (cx < 3'd7) &&
                     (cy > 3'd0) && (cy < 3'd7);

    // Head eyes 1
    wire eye_l_1 = (cx == 3'd2) && (cy == 3'd2);
    wire eye_r_1 = (cx == 3'd5) && (cy == 3'd2);
    wire head_eye_1 = is_head_1_cell && (eye_l_1 || eye_r_1);

    wire draw_body_1 = is_snake_1_cell && !is_head_1_cell && cell_fill && !is_border;
    wire draw_head_1 = is_head_1_cell  && cell_fill && !is_border && !head_eye_1;
    wire draw_eye_1  = is_head_1_cell  && head_eye_1 && !is_border;


    // Head eyes 2
    wire eye_l_2 = (cx == 3'd2) && (cy == 3'd2);
    wire eye_r_2 = (cx == 3'd5) && (cy == 3'd2);
    wire head_eye_2 = is_head_2_cell && (eye_l_2 || eye_r_2);

    wire draw_body_2 = is_snake_2_cell && !is_head_2_cell && cell_fill && !is_border;
    wire draw_head_2 = is_head_2_cell  && cell_fill && !is_border && !head_eye_2;
    wire draw_eye_2  = is_head_2_cell  && head_eye_2 && !is_border;

    // ==========================================
    // 12. COLOR OUTPUT (2 bits per channel)
    // ==========================================
    reg [1:0] r_out, g_out, b_out;

    always @(*) begin
        if (!display_on) begin
            r_out = 2'd0; g_out = 2'd0; b_out = 2'd0; // Apagado fuera de pantalla

        end else if (game_over && (is_snake_1_cell || is_snake_2_cell) && cell_fill && !is_border) begin
            r_out = 2'd3; g_out = 2'd0; b_out = 2'd0; // Game Over: Rojo glitch nocturno

        end else if (draw_eye_1 || draw_eye_2) begin
            r_out = 2'd3; g_out = 2'd3; b_out = 2'd3; // Ojos: Blancos brillantes

        // --- JUGADOR 1: NARANJA TRON (Máximo Rojo, Verde Medio) ---
        end else if (draw_head_1) begin
            r_out = 2'd3; g_out = 2'd2; b_out = 2'd0; // Cabeza J1: Naranja brillante
        end else if (draw_body_1) begin
            r_out = 2'd2; g_out = 2'd1; b_out = 2'd0; // Cuerpo J1: Naranja oscuro / rastro

        // --- JUGADOR 2: AZUL CLARO TRON (Máximo Azul, Máximo Verde) ---
        end else if (draw_head_2) begin
            r_out = 2'd0; g_out = 2'd3; b_out = 2'd3; // Cabeza J2: Cian / Azul claro neón
        end else if (draw_body_2) begin
            r_out = 2'd0; g_out = 2'd1; b_out = 2'd2; // Cuerpo J2: Azul claro apagado / rastro

        end else if (is_border) begin
            r_out = {1'b0, border_checker};             // Border: checker
            g_out = {1'b0, border_checker};
            b_out = 2'd1;

        end else begin
            r_out = 2'd0; g_out = 2'd0; b_out = 2'd0; // Background: dark blue
        end
    end

    // ==========================================
    // 13. PIN ASSIGNMENTS (TinyVGA Pmod)
    // ==========================================
    assign uo_out = {hsync, b_out[0], g_out[0], r_out[0],
                     vsync, b_out[1], g_out[1], r_out[1]};
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    wire _unused = &{ena, ui_in[7:4], uio_in};

endmodule
