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

    localparam DIR_UP    = 2'd0;
    localparam DIR_DOWN  = 2'd1;
    localparam DIR_LEFT  = 2'd2;
    localparam DIR_RIGHT = 2'd3;

    // ==========================================
    // 3. INPUT
    // ==========================================
    wire btn_up_p1    = ui_in[0];
    wire btn_down_p1  = ui_in[1];
    wire btn_left_p1  = ui_in[2];
    wire btn_right_p1 = ui_in[3];
    wire btn_up_p2    = ui_in[4];
    wire btn_down_p2  = ui_in[5];
    wire btn_left_p2  = ui_in[6];
    wire btn_right_p2 = ui_in[7];

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
    reg [15:0] lfsr;
    always @(posedge clk) begin
        if (~rst_n)
            lfsr <= 16'hACE1;
        else
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[14] ^ lfsr[12] ^ lfsr[3]};
    end

    // Random food position clamped to playable area
    wire [5:0] rand_col_raw = lfsr[5:0];   // 0-63
    wire [4:0] rand_row_raw = lfsr[12:8];  // 0-31

    // Clamp: col to 1-38, row to 1-28
    wire [5:0] rand_col = (rand_col_raw < 6'd1)  ? 6'd1  :
                           (rand_col_raw > 6'd38) ? 6'd38 : rand_col_raw;
    wire [4:0] rand_row = (rand_row_raw < 5'd1)  ? 5'd1  :
                           (rand_row_raw > 5'd28) ? 5'd28 : rand_row_raw;

    // ==========================================
    // 6. SNAKE STORAGE (circular buffer)
    // ==========================================
    reg [5:0] seg_col [0:MAX_LEN-1];  // 6 bits for col (0-39)
    reg [4:0] seg_row [0:MAX_LEN-1];  // 5 bits for row (0-29)
    reg [LEN_BITS-1:0] head_ptr;
    reg [LEN_BITS-1:0] tail_ptr;
    reg [LEN_BITS-1:0] snake_len;

    wire [5:0] head_col = seg_col[head_ptr];
    wire [4:0] head_row = seg_row[head_ptr];

    // ==========================================
    // 7. DIRECTION CONTROL
    // ==========================================
    reg [1:0] direction, next_dir;

    always @(posedge clk) begin
        if (~rst_n) begin
            next_dir <= DIR_RIGHT;
        end else begin
            // Latch direction, prevent 180-degree reversal
            if      (btn_up_p1    && direction != DIR_DOWN)  next_dir <= DIR_UP;
            else if (btn_down_p1  && direction != DIR_UP)    next_dir <= DIR_DOWN;
            else if (btn_left_p1  && direction != DIR_RIGHT) next_dir <= DIR_LEFT;
            else if (btn_right_p1 && direction != DIR_LEFT)  next_dir <= DIR_RIGHT;
        end
    end

    // ==========================================
    // 8. NEXT HEAD POSITION
    // ==========================================
    reg [5:0] nxt_col;
    reg [4:0] nxt_row;

    always @(*) begin
        nxt_col = head_col;
        nxt_row = head_row;
        case (next_dir)
            DIR_UP:    nxt_row = head_row - 5'd1;
            DIR_DOWN:  nxt_row = head_row + 5'd1;
            DIR_LEFT:  nxt_col = head_col - 6'd1;
            DIR_RIGHT: nxt_col = head_col + 6'd1;
        endcase
    end

    // Wall collision
    wire wall_hit = (nxt_col == 6'd0)  || (nxt_col == 6'd39) ||
                    (nxt_row == 5'd0)  || (nxt_row == 5'd29);

    // ==========================================
    // 9. SELF-COLLISION (combinational)
    // ==========================================
    wire [MAX_LEN-1:0] body_match;
    genvar g;
    generate
        for (g = 0; g < MAX_LEN; g = g + 1) begin : self_chk
            // Unused slots are (0,0) = border, so they won't match
            // valid next positions inside playable area
            assign body_match[g] = (seg_col[g] == nxt_col) && (seg_row[g] == nxt_row);
        end
    endgenerate
    wire self_hit = |body_match;

    // Food eaten?
    wire ate_food = (nxt_col == food_col) && (nxt_row == food_row);

    // ==========================================
    // 10. GAME STATE MACHINE
    // ==========================================
    reg [5:0] food_col;
    reg [4:0] food_row;
    reg game_over;

    integer i;
    always @(posedge clk) begin
        if (~rst_n) begin
            for (i = 0; i < MAX_LEN; i = i + 1) begin
                seg_col[i] <= 6'd0;
                seg_row[i] <= 5'd0;
            end
            seg_col[0] <= 6'd4;  seg_row[0] <= 5'd15;
            seg_col[1] <= 6'd5;  seg_row[1] <= 5'd15;
            seg_col[2] <= 6'd6;  seg_row[2] <= 5'd15;
            seg_col[3] <= 6'd7;  seg_row[3] <= 5'd15;
            head_ptr   <= 5'd3;
            tail_ptr   <= 5'd0;
            snake_len  <= 5'd4;
            direction  <= DIR_RIGHT;
            food_col   <= 6'd20;
            food_row   <= 5'd15;
            game_over  <= 1'b0;
        end else if (game_over) begin
            // Restart on any direction button
            if (|ui_in[3:0]) begin
                for (i = 0; i < MAX_LEN; i = i + 1) begin
                    seg_col[i] <= 6'd0;
                    seg_row[i] <= 5'd0;
                end
                seg_col[0] <= 6'd4;  seg_row[0] <= 5'd15;
                seg_col[1] <= 6'd5;  seg_row[1] <= 5'd15;
                seg_col[2] <= 6'd6;  seg_row[2] <= 5'd15;
                seg_col[3] <= 6'd7;  seg_row[3] <= 5'd15;
                head_ptr   <= 5'd3;
                tail_ptr   <= 5'd0;
                snake_len  <= 5'd4;
                direction  <= DIR_RIGHT;
                food_col   <= rand_col;
                food_row   <= rand_row;
                game_over  <= 1'b0;
            end
        end else if (game_tick) begin
            direction <= next_dir;

            if (wall_hit || self_hit) begin
                game_over <= 1'b1;
            end else begin
                // Advance head in circular buffer
                head_ptr <= (head_ptr + 5'd1) & 5'd31;
                seg_col[(head_ptr + 5'd1) & 5'd31] <= nxt_col;
                seg_row[(head_ptr + 5'd1) & 5'd31] <= nxt_row;

                if (ate_food) begin
                    // Grow: keep tail where it is, spawn new food
                    if (snake_len < MAX_LEN)
                        snake_len <= snake_len + 5'd1;
                    food_col <= rand_col;
                    food_row <= rand_row;
                end else begin
                    // Normal move: clear old tail, advance tail pointer
                    seg_col[tail_ptr] <= 6'd0;
                    seg_row[tail_ptr] <= 5'd0;
                    tail_ptr <= (tail_ptr + 5'd1) & 5'd31;
                end
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

    // --- Food ---
    wire is_food_cell = (pcol == food_col) && (prow == food_row) && !game_over;
    wire [2:0] fdx = (cx > 3'd3) ? (cx - 3'd3) : (3'd3 - cx);
    wire [2:0] fdy = (cy > 3'd3) ? (cy - 3'd3) : (3'd3 - cy);
    wire food_pixel = is_food_cell && ((fdx + fdy) < 3'd4);

    // --- Snake segments (parallel match) ---
    wire [MAX_LEN-1:0] seg_hit;
    generate
        for (g = 0; g < MAX_LEN; g = g + 1) begin : draw_chk
            assign seg_hit[g] = (seg_col[g] == pcol) && (seg_row[g] == prow);
        end
    endgenerate
    wire is_snake_cell = |seg_hit;
    wire is_head_cell  = (pcol == head_col) && (prow == head_row);

    // Cell inner fill (1px padding for grid effect)
    wire cell_fill = (cx > 3'd0) && (cx < 3'd7) &&
                     (cy > 3'd0) && (cy < 3'd7);

    // Head eyes
    wire eye_l = (cx == 3'd2) && (cy == 3'd2);
    wire eye_r = (cx == 3'd5) && (cy == 3'd2);
    wire head_eye = is_head_cell && (eye_l || eye_r);

    wire draw_body = is_snake_cell && !is_head_cell && cell_fill && !is_border;
    wire draw_head = is_head_cell  && cell_fill && !is_border && !head_eye;
    wire draw_eye  = is_head_cell  && head_eye && !is_border;

    // ==========================================
    // 12. COLOR OUTPUT (2 bits per channel)
    // ==========================================
    reg [1:0] r_out, g_out, b_out;

    always @(*) begin
        if (!display_on) begin
            r_out = 2'd0; g_out = 2'd0; b_out = 2'd0;

        end else if (game_over && is_snake_cell && cell_fill && !is_border) begin
            r_out = 2'd3; g_out = 2'd0; b_out = 2'd0; // Dead: red

        end else if (draw_eye) begin
            r_out = 2'd3; g_out = 2'd3; b_out = 2'd3; // Eyes: white

        end else if (draw_head) begin
            r_out = 2'd0; g_out = 2'd3; b_out = 2'd0; // Head: bright green

        end else if (draw_body) begin
            r_out = 2'd0; g_out = 2'd2; b_out = 2'd0; // Body: dark green

        end else if (food_pixel) begin
            r_out = 2'd3; g_out = 2'd0; b_out = 2'd0; // Food: red

        end else if (is_border) begin
            r_out = {1'b0, border_checker};             // Border: checker
            g_out = {1'b0, border_checker};
            b_out = 2'd1;

        end else begin
            r_out = 2'd0; g_out = 2'd0; b_out = 2'd1; // Background: dark blue
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
