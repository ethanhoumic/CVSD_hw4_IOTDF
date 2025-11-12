`timescale 1ns/10ps
module IOTDF( clk, rst, in_en, iot_in, fn_sel, busy, valid, iot_out);
input          clk;
input          rst;
input          in_en;
input  [7:0]   iot_in;
input  [2:0]   fn_sel;
output         busy;
output         valid;
output [127:0] iot_out;

    localparam S_IDLE = 0;
    localparam S_LOAD = 1;
    localparam S_ENC  = 2;
    localparam S_DEC  = 3;
    localparam S_CRC  = 4;
    localparam S_SORT = 5;
    localparam S_DONE = 6;

    reg [2:0]   state_r, state_w;
    reg [127:0] data_r, data_w, iot_out;
    reg [4:0]   cnt_r, cnt_w;
    reg [55:0]  cypher_key_r, cypher_key_w;
    reg [10:0]  crc_data_r, crc_data_w;
    reg [2:0]   crc_prev_r, crc_prev_w;
    reg         busy, valid;

    integer i;

    wire [6:0] index_w = cnt_r << 3;
    wire [47:0] sub_key_w = PC2(cypher_key_r);

    wire cypher_key__en = (state_r == S_ENC || state_r == S_DEC);

    always @(*) begin
        state_w = state_r;
        data_w = data_r;
        cnt_w = cnt_r;
        cypher_key_w = cypher_key_r;
        crc_data_w = crc_data_r;
        crc_prev_w = crc_prev_r;
        busy = 1;
        valid = 0;
        iot_out = data_r;
        case (state_r)
            S_IDLE: begin
                state_w = S_LOAD;
            end 
            S_LOAD: begin
                busy = 0;
                valid = 0;
                if (in_en) begin
                    data_w[index_w +: 8] = iot_in;
                    if (cnt_r == 15) begin
                        case (fn_sel)
                            1: state_w = S_ENC;
                            2: state_w = S_DEC;
                            3: state_w = S_CRC;
                            4: state_w = S_SORT;
                            default: state_w = S_ENC;
                        endcase
                        cnt_w = 0;
                        busy = 1;
                    end
                    else begin
                        cnt_w = cnt_r + 1;
                        state_w = S_LOAD;
                    end
                end
            end
            S_ENC: begin
                if (cnt_r == 0) begin
                    data_w[63:0] = initial_permutation(data_r[63:0]);
                    cypher_key_w = PC1(data_r[127:64]);
                    cypher_key_w[27:0] = {cypher_key_w[26:0], cypher_key_w[27]};
                    cypher_key_w[55:28] = {cypher_key_w[54:28], cypher_key_w[55]};
                    cnt_w = cnt_r + 1;
                end
                else if (cnt_r == 17) begin
                    data_w[63:0] = final_permutation({data_r[31:0], data_r[63:32]});
                    cnt_w = 0;
                    state_w = S_DONE;
                end
                else if (cnt_r == 1 || cnt_r == 8 || cnt_r == 15) begin
                    data_w[63:0] = {data_r[31:0], data_r[63:32] ^ F(data_r[31:0], sub_key_w)};
                    cypher_key_w[27:0] = {cypher_key_r[26:0], cypher_key_r[27]};
                    cypher_key_w[55:28] = {cypher_key_r[54:28], cypher_key_r[55]};
                    cnt_w = cnt_r + 1;
                end
                else begin
                    data_w[63:0] = {data_r[31:0], data_r[63:32] ^ F(data_r[31:0], sub_key_w)};
                    cypher_key_w[27:0] = {cypher_key_r[25:0], cypher_key_r[27:26]};
                    cypher_key_w[55:28] = {cypher_key_r[53:28], cypher_key_r[55:54]};
                    cnt_w = cnt_r + 1;
                end
            end
            S_DEC: begin
                if (cnt_r == 0) begin
                    data_w[63:0] = initial_permutation(data_r[63:0]);
                    cypher_key_w = PC1(data_r[127:64]);
                    // cypher_key_w[27:0] = {cypher_key_w[0], cypher_key_w[27:1]};
                    // cypher_key_w[55:28] = {cypher_key_w[28], cypher_key_w[55:29]};
                    cnt_w = cnt_r + 1;
                end
                else if (cnt_r == 17) begin
                    data_w[63:0] = final_permutation({data_r[31:0], data_r[63:32]});
                    cnt_w = 0;
                    state_w = S_DONE;
                end
                else if (cnt_r == 1 || cnt_r == 8 || cnt_r == 15) begin
                    data_w[63:0] = {data_r[31:0], data_r[63:32] ^ F(data_r[31:0], sub_key_w)};
                    cypher_key_w[27:0] = {cypher_key_r[0], cypher_key_r[27:1]};
                    cypher_key_w[55:28] = {cypher_key_r[28], cypher_key_r[55:29]};
                    cnt_w = cnt_r + 1;
                end
                else begin
                    data_w[63:0] = {data_r[31:0], data_r[63:32] ^ F(data_r[31:0], sub_key_w)};
                    cypher_key_w[27:0] = {cypher_key_r[1:0], cypher_key_r[27:2]};
                    cypher_key_w[55:28] = {cypher_key_r[29:28], cypher_key_r[55:30]};
                    cnt_w = cnt_r + 1;
                end
            end
            S_CRC: begin
                
            end
            S_SORT: begin
                if (cnt_r == 16) begin
                    state_w = S_DONE;
                    cnt_w = 0;
                end
                else begin
                    state_w = S_SORT;
                    cnt_w = cnt_r + 1;
                    if (cnt_r[0]) begin
                        for (i = 0; i < 16; i = i + 2) begin
                            if (data_r[i * 8 +: 8] > data_r[(i + 1) * 8 +: 8]) begin
                                data_w[i * 8 +: 8] = data_r[(i + 1) * 8 +: 8];
                                data_w[(i + 1) * 8 +: 8] = data_r[i * 8 +: 8];
                            end
                        end
                    end
                    else begin
                        for (i = 1; i < 15; i = i + 2) begin
                            if (data_r[i * 8 +: 8] > data_r[(i + 1) * 8 +: 8]) begin
                                data_w[i * 8 +: 8] = data_r[(i + 1) * 8 +: 8];
                                data_w[(i + 1) * 8 +: 8] = data_r[i * 8 +: 8];
                            end
                        end
                    end
                end
            end
            S_DONE: begin
                valid = 1;
                state_w = S_LOAD;
            end
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state_r <= S_IDLE;
            data_r <= 0;
            cnt_r <= 0;
            cypher_key_r <= 0;
            crc_data_r <= 0;
            crc_prev_r <= 0;
        end
        else begin
            state_r <= state_w;
            data_r <= data_w;
            cnt_r <= cnt_w;
            crc_data_r <= crc_data_w;
            crc_prev_r <= crc_prev_w;
            if (cypher_key__en) begin
                cypher_key_r <= cypher_key_w;
            end
        end
    end

    function automatic [63:0] initial_permutation;
        input [63:0] i_data;
        begin
            initial_permutation = {i_data[6],  i_data[14], i_data[22], i_data[30],
                                   i_data[38], i_data[46], i_data[54], i_data[62],
                                   i_data[4],  i_data[12], i_data[20], i_data[28],
                                   i_data[36], i_data[44], i_data[52], i_data[60],
                                   i_data[2],  i_data[10], i_data[18], i_data[26],
                                   i_data[34], i_data[42], i_data[50], i_data[58],
                                   i_data[0],  i_data[8],  i_data[16], i_data[24],
                                   i_data[32], i_data[40], i_data[48], i_data[56],
                                   i_data[7],  i_data[15], i_data[23], i_data[31],
                                   i_data[39], i_data[47], i_data[55], i_data[63],
                                   i_data[5],  i_data[13], i_data[21], i_data[29],
                                   i_data[37], i_data[45], i_data[53], i_data[61],
                                   i_data[3],  i_data[11], i_data[19], i_data[27],
                                   i_data[35], i_data[43], i_data[51], i_data[59],
                                   i_data[1],  i_data[9],  i_data[17], i_data[25],
                                   i_data[33], i_data[41], i_data[49], i_data[57]};
        end
    endfunction

    function automatic [63:0] final_permutation;
        input [63:0] i_data;
        begin
            final_permutation = {i_data[24], i_data[56], i_data[16], i_data[48],
                                 i_data[8],  i_data[40], i_data[0],  i_data[32],
                                 i_data[25], i_data[57], i_data[17], i_data[49],
                                 i_data[9],  i_data[41], i_data[1],  i_data[33],
                                 i_data[26], i_data[58], i_data[18], i_data[50],
                                 i_data[10], i_data[42], i_data[2],  i_data[34],
                                 i_data[27], i_data[59], i_data[19], i_data[51],
                                 i_data[11], i_data[43], i_data[3],  i_data[35],
                                 i_data[28], i_data[60], i_data[20], i_data[52],
                                 i_data[12], i_data[44], i_data[4],  i_data[36],
                                 i_data[29], i_data[61], i_data[21], i_data[53],
                                 i_data[13], i_data[45], i_data[5],  i_data[37],
                                 i_data[30], i_data[62], i_data[22], i_data[54],
                                 i_data[14], i_data[46], i_data[6],  i_data[38],
                                 i_data[31], i_data[63], i_data[23], i_data[55],
                                 i_data[15], i_data[47], i_data[7],  i_data[39]};
        end
    endfunction

    function automatic [31:0] P;
        input [31:0] i_data;
        begin
            P = {i_data[16], i_data[25], i_data[12], i_data[11],
                 i_data[3],  i_data[20], i_data[4],  i_data[15],
                 i_data[31], i_data[17], i_data[9],  i_data[6],
                 i_data[27], i_data[14], i_data[1],  i_data[22],
                 i_data[30], i_data[24], i_data[8],  i_data[18],
                 i_data[0],  i_data[5],  i_data[29], i_data[23],
                 i_data[13], i_data[19], i_data[2],  i_data[26],
                 i_data[10], i_data[21], i_data[28], i_data[7]};
        end
    endfunction

    function automatic [55:0] PC1;
        input [63:0] i_data;
        begin
            PC1 = {i_data[7],  i_data[15], i_data[23], i_data[31],
                   i_data[39], i_data[47], i_data[55], i_data[63],
                   i_data[6],  i_data[14], i_data[22], i_data[30],
                   i_data[38], i_data[46], i_data[54], i_data[62],
                   i_data[5],  i_data[13], i_data[21], i_data[29],
                   i_data[37], i_data[45], i_data[53], i_data[61],
                   i_data[4],  i_data[12], i_data[20], i_data[28],
                   i_data[1],  i_data[9],  i_data[17], i_data[25],
                   i_data[33], i_data[41], i_data[49], i_data[57],
                   i_data[2],  i_data[10], i_data[18], i_data[26],
                   i_data[34], i_data[42], i_data[50], i_data[58],
                   i_data[3],  i_data[11], i_data[19], i_data[27],
                   i_data[35], i_data[43], i_data[51], i_data[59],
                   i_data[36], i_data[44], i_data[52], i_data[60]};
        end
    endfunction

    function automatic [47:0] PC2;
        input [55:0] i_data;
        begin
            PC2 = {i_data[42], i_data[39], i_data[45], i_data[32], 
                   i_data[55], i_data[51], i_data[53], i_data[28],
                   i_data[41], i_data[50], i_data[35], i_data[46], 
                   i_data[33], i_data[37], i_data[44], i_data[52],
                   i_data[30], i_data[48], i_data[40], i_data[49], 
                   i_data[29], i_data[36], i_data[43], i_data[54],
                   i_data[15], i_data[4],  i_data[25], i_data[19], 
                   i_data[9],  i_data[1],  i_data[26], i_data[16],
                   i_data[5],  i_data[11], i_data[23], i_data[8], 
                   i_data[12], i_data[7],  i_data[17], i_data[0],
                   i_data[22], i_data[3],  i_data[10], i_data[14], 
                   i_data[6],  i_data[20], i_data[27], i_data[24]};
        end
    endfunction

    function automatic [47:0] expansion;
        input [31:0] i_data;
        begin
            expansion = {i_data[0],  i_data[31], i_data[30], i_data[29], i_data[28], i_data[27],
                         i_data[28], i_data[27], i_data[26], i_data[25], i_data[24], i_data[23],
                         i_data[24], i_data[23], i_data[22], i_data[21], i_data[20], i_data[19],
                         i_data[20], i_data[19], i_data[18], i_data[17], i_data[16], i_data[15],
                         i_data[16], i_data[15], i_data[14], i_data[13], i_data[12], i_data[11],
                         i_data[12], i_data[11], i_data[10], i_data[9],  i_data[8],  i_data[7],
                         i_data[8],  i_data[7],  i_data[6],  i_data[5],  i_data[4],  i_data[3],
                         i_data[4],  i_data[3],  i_data[2],  i_data[1],  i_data[0], i_data[31]};
        end
    endfunction

    function automatic [3:0] S1;
        input [5:0] i_data;
        begin
            reg [3:0] col_num_w = i_data[4:1];
            reg [1:0] row_num_w = {i_data[5], i_data[0]};
            case (col_num_w)
                4'b0000: begin
                    case (row_num_w)
                        2'b00: S1 = 14; 2'b01: S1 = 0; 2'b10: S1 = 4; 2'b11: S1 = 15; 
                    endcase
                end 
                4'b0001: begin
                    case (row_num_w)
                        2'b00: S1 = 4; 2'b01: S1 = 15; 2'b10: S1 = 1; 2'b11: S1 = 12; 
                    endcase
                end
                4'b0010: begin
                    case (row_num_w)
                        2'b00: S1 = 13; 2'b01: S1 = 7; 2'b10: S1 = 14; 2'b11: S1 = 8; 
                    endcase
                end
                4'b0011: begin
                    case (row_num_w)
                        2'b00: S1 = 1; 2'b01: S1 = 4; 2'b10: S1 = 8; 2'b11: S1 = 2; 
                    endcase
                end
                4'b0100: begin
                    case (row_num_w)
                        2'b00: S1 = 2; 2'b01: S1 = 14; 2'b10: S1 = 13; 2'b11: S1 = 4; 
                    endcase
                end
                4'b0101: begin
                    case (row_num_w)
                        2'b00: S1 = 15; 2'b01: S1 = 2; 2'b10: S1 = 6; 2'b11: S1 = 9; 
                    endcase
                end
                4'b0110: begin
                    case (row_num_w)
                        2'b00: S1 = 11; 2'b01: S1 = 13; 2'b10: S1 = 2; 2'b11: S1 = 1; 
                    endcase
                end
                4'b0111: begin
                    case (row_num_w)
                        2'b00: S1 = 8; 2'b01: S1 = 1; 2'b10: S1 = 11; 2'b11: S1 = 7; 
                    endcase
                end
                4'b1000: begin
                    case (row_num_w)
                        2'b00: S1 = 3; 2'b01: S1 = 10; 2'b10: S1 = 15; 2'b11: S1 = 5; 
                    endcase
                end
                4'b1001: begin
                    case (row_num_w)
                        2'b00: S1 = 10; 2'b01: S1 = 6; 2'b10: S1 = 12; 2'b11: S1 = 11; 
                    endcase
                end
                4'b1010: begin
                    case (row_num_w)
                        2'b00: S1 = 6; 2'b01: S1 = 12; 2'b10: S1 = 9; 2'b11: S1 = 3; 
                    endcase
                end
                4'b1011: begin
                    case (row_num_w)
                        2'b00: S1 = 12; 2'b01: S1 = 11; 2'b10: S1 = 7; 2'b11: S1 = 14; 
                    endcase
                end
                4'b1100: begin
                    case (row_num_w)
                        2'b00: S1 = 5; 2'b01: S1 = 9; 2'b10: S1 = 3; 2'b11: S1 = 10; 
                    endcase
                end
                4'b1101: begin
                    case (row_num_w)
                        2'b00: S1 = 9; 2'b01: S1 = 5; 2'b10: S1 = 10; 2'b11: S1 = 0; 
                    endcase
                end
                4'b1110: begin
                    case (row_num_w)
                        2'b00: S1 = 0; 2'b01: S1 = 3; 2'b10: S1 = 5; 2'b11: S1 = 6; 
                    endcase
                end
                4'b1111: begin
                    case (row_num_w)
                        2'b00: S1 = 7; 2'b01: S1 = 8; 2'b10: S1 = 0; 2'b11: S1 = 13; 
                    endcase
                end
            endcase
        end
    endfunction

    function automatic [3:0] S2;
        input [5:0] i_data;
        begin
            reg [3:0] col_num_w = i_data[4:1];
            reg [1:0] row_num_w = {i_data[5], i_data[0]};
            case (col_num_w)
                4'b0000: begin
                    case (row_num_w)
                        2'b00: S2 = 15; 2'b01: S2 = 3; 2'b10: S2 = 0; 2'b11: S2 = 13; 
                    endcase
                end 
                4'b0001: begin
                    case (row_num_w)
                        2'b00: S2 = 1; 2'b01: S2 = 13; 2'b10: S2 = 14; 2'b11: S2 = 8; 
                    endcase
                end
                4'b0010: begin
                    case (row_num_w)
                        2'b00: S2 = 8; 2'b01: S2 = 4; 2'b10: S2 = 7; 2'b11: S2 = 10; 
                    endcase
                end
                4'b0011: begin
                    case (row_num_w)
                        2'b00: S2 = 14; 2'b01: S2 = 7; 2'b10: S2 = 11; 2'b11: S2 = 1; 
                    endcase
                end
                4'b0100: begin
                    case (row_num_w)
                        2'b00: S2 = 6; 2'b01: S2 = 15; 2'b10: S2 = 10; 2'b11: S2 = 3; 
                    endcase
                end
                4'b0101: begin
                    case (row_num_w)
                        2'b00: S2 = 11; 2'b01: S2 = 2; 2'b10: S2 = 4; 2'b11: S2 = 15; 
                    endcase
                end
                4'b0110: begin
                    case (row_num_w)
                        2'b00: S2 = 3; 2'b01: S2 = 8; 2'b10: S2 = 13; 2'b11: S2 = 4; 
                    endcase
                end
                4'b0111: begin
                    case (row_num_w)
                        2'b00: S2 = 4; 2'b01: S2 = 14; 2'b10: S2 = 1; 2'b11: S2 = 2; 
                    endcase
                end
                4'b1000: begin
                    case (row_num_w)
                        2'b00: S2 = 9; 2'b01: S2 = 12; 2'b10: S2 = 5; 2'b11: S2 = 11; 
                    endcase
                end
                4'b1001: begin
                    case (row_num_w)
                        2'b00: S2 = 7; 2'b01: S2 = 0; 2'b10: S2 = 8; 2'b11: S2 = 6; 
                    endcase
                end
                4'b1010: begin
                    case (row_num_w)
                        2'b00: S2 = 2; 2'b01: S2 = 1; 2'b10: S2 = 12; 2'b11: S2 = 7; 
                    endcase
                end
                4'b1011: begin
                    case (row_num_w)
                        2'b00: S2 = 13; 2'b01: S2 = 10; 2'b10: S2 = 6; 2'b11: S2 = 12; 
                    endcase
                end
                4'b1100: begin
                    case (row_num_w)
                        2'b00: S2 = 12; 2'b01: S2 = 6; 2'b10: S2 = 9; 2'b11: S2 = 0; 
                    endcase
                end
                4'b1101: begin
                    case (row_num_w)
                        2'b00: S2 = 0; 2'b01: S2 = 9; 2'b10: S2 = 3; 2'b11: S2 = 5; 
                    endcase
                end
                4'b1110: begin
                    case (row_num_w)
                        2'b00: S2 = 5; 2'b01: S2 = 11; 2'b10: S2 = 2; 2'b11: S2 = 14; 
                    endcase
                end
                4'b1111: begin
                    case (row_num_w)
                        2'b00: S2 = 10; 2'b01: S2 = 5; 2'b10: S2 = 15; 2'b11: S2 = 9; 
                    endcase
                end
            endcase
        end
    endfunction

    function automatic [3:0] S3;
        input [5:0] i_data;
        begin
            reg [3:0] col_num_w = i_data[4:1];
            reg [1:0] row_num_w = {i_data[5], i_data[0]};
            case (col_num_w)
                4'b0000: begin
                    case (row_num_w)
                        2'b00: S3 = 10; 2'b01: S3 = 13; 2'b10: S3 = 13; 2'b11: S3 = 1; 
                    endcase
                end
                4'b0001: begin
                    case (row_num_w)
                        2'b00: S3 = 0; 2'b01: S3 = 7; 2'b10: S3 = 6; 2'b11: S3 = 10; 
                    endcase
                end
                4'b0010: begin
                    case (row_num_w)
                        2'b00: S3 = 9; 2'b01: S3 = 0; 2'b10: S3 = 4; 2'b11: S3 = 13; 
                    endcase
                end
                4'b0011: begin
                    case (row_num_w)
                        2'b00: S3 = 14; 2'b01: S3 = 9; 2'b10: S3 = 9; 2'b11: S3 = 0; 
                    endcase
                end
                4'b0100: begin
                    case (row_num_w)
                        2'b00: S3 = 6; 2'b01: S3 = 3; 2'b10: S3 = 8; 2'b11: S3 = 6; 
                    endcase
                end
                4'b0101: begin
                    case (row_num_w)
                        2'b00: S3 = 3; 2'b01: S3 = 4; 2'b10: S3 = 15; 2'b11: S3 = 9; 
                    endcase
                end
                4'b0110: begin
                    case (row_num_w)
                        2'b00: S3 = 15; 2'b01: S3 = 6; 2'b10: S3 = 3; 2'b11: S3 = 8; 
                    endcase
                end
                4'b0111: begin
                    case (row_num_w)
                        2'b00: S3 = 5; 2'b01: S3 = 10; 2'b10: S3 = 0; 2'b11: S3 = 7; 
                    endcase
                end
                4'b1000: begin
                    case (row_num_w)
                        2'b00: S3 = 1; 2'b01: S3 = 2; 2'b10: S3 = 11; 2'b11: S3 = 4; 
                    endcase
                end
                4'b1001: begin
                    case (row_num_w)
                        2'b00: S3 = 13; 2'b01: S3 = 8; 2'b10: S3 = 1; 2'b11: S3 = 15; 
                    endcase
                end
                4'b1010: begin
                    case (row_num_w)
                        2'b00: S3 = 12; 2'b01: S3 = 5; 2'b10: S3 = 2; 2'b11: S3 = 14; 
                    endcase
                end
                4'b1011: begin
                    case (row_num_w)
                        2'b00: S3 = 7; 2'b01: S3 = 14; 2'b10: S3 = 12; 2'b11: S3 = 3; 
                    endcase
                end
                4'b1100: begin
                    case (row_num_w)
                        2'b00: S3 = 11; 2'b01: S3 = 12; 2'b10: S3 = 5; 2'b11: S3 = 11; 
                    endcase
                end
                4'b1101: begin
                    case (row_num_w)
                        2'b00: S3 = 4; 2'b01: S3 = 11; 2'b10: S3 = 10; 2'b11: S3 = 5; 
                    endcase
                end
                4'b1110: begin
                    case (row_num_w)
                        2'b00: S3 = 2; 2'b01: S3 = 15; 2'b10: S3 = 14; 2'b11: S3 = 2; 
                    endcase
                end
                4'b1111: begin
                    case (row_num_w)
                        2'b00: S3 = 8; 2'b01: S3 = 1; 2'b10: S3 = 7; 2'b11: S3 = 12; 
                    endcase
                end
            endcase
        end
    endfunction

    function automatic [3:0] S4;
        input [5:0] i_data;
        begin
            reg [3:0] col_num_w = i_data[4:1];
            reg [1:0] row_num_w = {i_data[5], i_data[0]};
            case (col_num_w)
                4'b0000: begin
                    case (row_num_w)
                        2'b00: S4 = 7; 2'b01: S4 = 13; 2'b10: S4 = 10; 2'b11: S4 = 3; 
                    endcase
                end
                4'b0001: begin
                    case (row_num_w)
                        2'b00: S4 = 13; 2'b01: S4 = 8; 2'b10: S4 = 6; 2'b11: S4 = 15; 
                    endcase
                end
                4'b0010: begin
                    case (row_num_w)
                        2'b00: S4 = 14; 2'b01: S4 = 11; 2'b10: S4 = 9; 2'b11: S4 = 0; 
                    endcase
                end
                4'b0011: begin
                    case (row_num_w)
                        2'b00: S4 = 3; 2'b01: S4 = 5; 2'b10: S4 = 0; 2'b11: S4 = 6; 
                    endcase
                end
                4'b0100: begin
                    case (row_num_w)
                        2'b00: S4 = 0; 2'b01: S4 = 6; 2'b10: S4 = 12; 2'b11: S4 = 10; 
                    endcase
                end
                4'b0101: begin
                    case (row_num_w)
                        2'b00: S4 = 6; 2'b01: S4 = 15; 2'b10: S4 = 11; 2'b11: S4 = 1; 
                    endcase
                end
                4'b0110: begin
                    case (row_num_w)
                        2'b00: S4 = 9; 2'b01: S4 = 0; 2'b10: S4 = 7; 2'b11: S4 = 13; 
                    endcase
                end
                4'b0111: begin
                    case (row_num_w)
                        2'b00: S4 = 10; 2'b01: S4 = 3; 2'b10: S4 = 13; 2'b11: S4 = 8; 
                    endcase
                end
                4'b1000: begin
                    case (row_num_w)
                        2'b00: S4 = 1; 2'b01: S4 = 4; 2'b10: S4 = 15; 2'b11: S4 = 9; 
                    endcase
                end
                4'b1001: begin
                    case (row_num_w)
                        2'b00: S4 = 2; 2'b01: S4 = 7; 2'b10: S4 = 1; 2'b11: S4 = 4; 
                    endcase
                end
                4'b1010: begin
                    case (row_num_w)
                        2'b00: S4 = 8; 2'b01: S4 = 2; 2'b10: S4 = 3; 2'b11: S4 = 5; 
                    endcase
                end
                4'b1011: begin
                    case (row_num_w)
                        2'b00: S4 = 5; 2'b01: S4 = 12; 2'b10: S4 = 14; 2'b11: S4 = 11; 
                    endcase
                end
                4'b1100: begin
                    case (row_num_w)
                        2'b00: S4 = 11; 2'b01: S4 = 1; 2'b10: S4 = 5; 2'b11: S4 = 12; 
                    endcase
                end
                4'b1101: begin
                    case (row_num_w)
                        2'b00: S4 = 12; 2'b01: S4 = 10; 2'b10: S4 = 2; 2'b11: S4 = 7; 
                    endcase
                end
                4'b1110: begin
                    case (row_num_w)
                        2'b00: S4 = 4; 2'b01: S4 = 14; 2'b10: S4 = 8; 2'b11: S4 = 2; 
                    endcase
                end
                4'b1111: begin
                    case (row_num_w)
                        2'b00: S4 = 15; 2'b01: S4 = 9; 2'b10: S4 = 4; 2'b11: S4 = 14; 
                    endcase
                end
            endcase
        end
    endfunction

    function automatic [3:0] S5;
        input [5:0] i_data;
        begin
            reg [3:0] col_num_w = i_data[4:1];
            reg [1:0] row_num_w = {i_data[5], i_data[0]};
            case (col_num_w)
                4'b0000: begin
                    case (row_num_w)
                        2'b00: S5 = 2; 2'b01: S5 = 14; 2'b10: S5 = 4; 2'b11: S5 = 11; 
                    endcase
                end
                4'b0001: begin
                    case (row_num_w)
                        2'b00: S5 = 12; 2'b01: S5 = 11; 2'b10: S5 = 2; 2'b11: S5 = 8; 
                    endcase
                end
                4'b0010: begin
                    case (row_num_w)
                        2'b00: S5 = 4; 2'b01: S5 = 2; 2'b10: S5 = 1; 2'b11: S5 = 12; 
                    endcase
                end
                4'b0011: begin
                    case (row_num_w)
                        2'b00: S5 = 1; 2'b01: S5 = 12; 2'b10: S5 = 11; 2'b11: S5 = 7; 
                    endcase
                end
                4'b0100: begin
                    case (row_num_w)
                        2'b00: S5 = 7; 2'b01: S5 = 4; 2'b10: S5 = 10; 2'b11: S5 = 1; 
                    endcase
                end
                4'b0101: begin
                    case (row_num_w)
                        2'b00: S5 = 10; 2'b01: S5 = 7; 2'b10: S5 = 13; 2'b11: S5 = 14; 
                    endcase
                end
                4'b0110: begin
                    case (row_num_w)
                        2'b00: S5 = 11; 2'b01: S5 = 13; 2'b10: S5 = 7; 2'b11: S5 = 2; 
                    endcase
                end
                4'b0111: begin
                    case (row_num_w)
                        2'b00: S5 = 6; 2'b01: S5 = 1; 2'b10: S5 = 8; 2'b11: S5 = 13; 
                    endcase
                end
                4'b1000: begin
                    case (row_num_w)
                        2'b00: S5 = 8; 2'b01: S5 = 5; 2'b10: S5 = 15; 2'b11: S5 = 6; 
                    endcase
                end
                4'b1001: begin
                    case (row_num_w)
                        2'b00: S5 = 5; 2'b01: S5 = 0; 2'b10: S5 = 9; 2'b11: S5 = 15; 
                    endcase
                end
                4'b1010: begin
                    case (row_num_w)
                        2'b00: S5 = 3; 2'b01: S5 = 15; 2'b10: S5 = 12; 2'b11: S5 = 0; 
                    endcase
                end
                4'b1011: begin
                    case (row_num_w)
                        2'b00: S5 = 15; 2'b01: S5 = 10; 2'b10: S5 = 5; 2'b11: S5 = 9; 
                    endcase
                end
                4'b1100: begin
                    case (row_num_w)
                        2'b00: S5 = 13; 2'b01: S5 = 3; 2'b10: S5 = 6; 2'b11: S5 = 10; 
                    endcase
                end
                4'b1101: begin
                    case (row_num_w)
                        2'b00: S5 = 0; 2'b01: S5 = 9; 2'b10: S5 = 3; 2'b11: S5 = 4; 
                    endcase
                end
                4'b1110: begin
                    case (row_num_w)
                        2'b00: S5 = 14; 2'b01: S5 = 8; 2'b10: S5 = 0; 2'b11: S5 = 5; 
                    endcase
                end
                4'b1111: begin
                    case (row_num_w)
                        2'b00: S5 = 9; 2'b01: S5 = 6; 2'b10: S5 = 14; 2'b11: S5 = 3; 
                    endcase
                end
            endcase
        end
    endfunction

    function automatic [3:0] S6;
        input [5:0] i_data;
        begin
            reg [3:0] col_num_w = i_data[4:1];
            reg [1:0] row_num_w = {i_data[5], i_data[0]};
            case (col_num_w)
                4'b0000: begin
                    case (row_num_w)
                        2'b00: S6 = 12; 2'b01: S6 = 10; 2'b10: S6 = 9; 2'b11: S6 = 4; 
                    endcase
                end
                4'b0001: begin
                    case (row_num_w)
                        2'b00: S6 = 1; 2'b01: S6 = 15; 2'b10: S6 = 14; 2'b11: S6 = 3; 
                    endcase
                end
                4'b0010: begin
                    case (row_num_w)
                        2'b00: S6 = 10; 2'b01: S6 = 4; 2'b10: S6 = 15; 2'b11: S6 = 2; 
                    endcase
                end
                4'b0011: begin
                    case (row_num_w)
                        2'b00: S6 = 15; 2'b01: S6 = 2; 2'b10: S6 = 5; 2'b11: S6 = 12; 
                    endcase
                end
                4'b0100: begin
                    case (row_num_w)
                        2'b00: S6 = 9; 2'b01: S6 = 7; 2'b10: S6 = 2; 2'b11: S6 = 9; 
                    endcase
                end
                4'b0101: begin
                    case (row_num_w)
                        2'b00: S6 = 2; 2'b01: S6 = 12; 2'b10: S6 = 8; 2'b11: S6 = 5; 
                    endcase
                end
                4'b0110: begin
                    case (row_num_w)
                        2'b00: S6 = 6; 2'b01: S6 = 9; 2'b10: S6 = 12; 2'b11: S6 = 15; 
                    endcase
                end
                4'b0111: begin
                    case (row_num_w)
                        2'b00: S6 = 8; 2'b01: S6 = 5; 2'b10: S6 = 3; 2'b11: S6 = 10; 
                    endcase
                end
                4'b1000: begin
                    case (row_num_w)
                        2'b00: S6 = 0; 2'b01: S6 = 6; 2'b10: S6 = 7; 2'b11: S6 = 11; 
                    endcase
                end
                4'b1001: begin
                    case (row_num_w)
                        2'b00: S6 = 13; 2'b01: S6 = 1; 2'b10: S6 = 0; 2'b11: S6 = 14; 
                    endcase
                end
                4'b1010: begin
                    case (row_num_w)
                        2'b00: S6 = 3; 2'b01: S6 = 13; 2'b10: S6 = 4; 2'b11: S6 = 1; 
                    endcase
                end
                4'b1011: begin
                    case (row_num_w)
                        2'b00: S6 = 4; 2'b01: S6 = 14; 2'b10: S6 = 10; 2'b11: S6 = 7; 
                    endcase
                end
                4'b1100: begin
                    case (row_num_w)
                        2'b00: S6 = 14; 2'b01: S6 = 0; 2'b10: S6 = 1; 2'b11: S6 = 6; 
                    endcase
                end
                4'b1101: begin
                    case (row_num_w)
                        2'b00: S6 = 7; 2'b01: S6 = 11; 2'b10: S6 = 13; 2'b11: S6 = 0; 
                    endcase
                end
                4'b1110: begin
                    case (row_num_w)
                        2'b00: S6 = 5; 2'b01: S6 = 3; 2'b10: S6 = 11; 2'b11: S6 = 8; 
                    endcase
                end
                4'b1111: begin
                    case (row_num_w)
                        2'b00: S6 = 11; 2'b01: S6 = 8; 2'b10: S6 = 6; 2'b11: S6 = 13; 
                    endcase
                end
            endcase
        end
    endfunction

    function automatic [3:0] S7;
        input [5:0] i_data;
        begin
            reg [3:0] col_num_w = i_data[4:1];
            reg [1:0] row_num_w = {i_data[5], i_data[0]};
            case (col_num_w)
                4'b0000: begin
                    case (row_num_w)
                        2'b00: S7 = 4; 2'b01: S7 = 13; 2'b10: S7 = 1; 2'b11: S7 = 6; 
                    endcase
                end
                4'b0001: begin
                    case (row_num_w)
                        2'b00: S7 = 11; 2'b01: S7 = 0; 2'b10: S7 = 4; 2'b11: S7 = 11; 
                    endcase
                end
                4'b0010: begin
                    case (row_num_w)
                        2'b00: S7 = 2; 2'b01: S7 = 11; 2'b10: S7 = 11; 2'b11: S7 = 13; 
                    endcase
                end
                4'b0011: begin
                    case (row_num_w)
                        2'b00: S7 = 14; 2'b01: S7 = 7; 2'b10: S7 = 13; 2'b11: S7 = 8; 
                    endcase
                end
                4'b0100: begin
                    case (row_num_w)
                        2'b00: S7 = 15; 2'b01: S7 = 4; 2'b10: S7 = 12; 2'b11: S7 = 1; 
                    endcase
                end
                4'b0101: begin
                    case (row_num_w)
                        2'b00: S7 = 0; 2'b01: S7 = 9; 2'b10: S7 = 3; 2'b11: S7 = 4; 
                    endcase
                end
                4'b0110: begin
                    case (row_num_w)
                        2'b00: S7 = 8; 2'b01: S7 = 1; 2'b10: S7 = 7; 2'b11: S7 = 10; 
                    endcase
                end
                4'b0111: begin
                    case (row_num_w)
                        2'b00: S7 = 13; 2'b01: S7 = 10; 2'b10: S7 = 14; 2'b11: S7 = 7; 
                    endcase
                end
                4'b1000: begin
                    case (row_num_w)
                        2'b00: S7 = 3; 2'b01: S7 = 14; 2'b10: S7 = 10; 2'b11: S7 = 9; 
                    endcase
                end
                4'b1001: begin
                    case (row_num_w)
                        2'b00: S7 = 12; 2'b01: S7 = 3; 2'b10: S7 = 15; 2'b11: S7 = 5; 
                    endcase
                end
                4'b1010: begin
                    case (row_num_w)
                        2'b00: S7 = 9; 2'b01: S7 = 5; 2'b10: S7 = 6; 2'b11: S7 = 0; 
                    endcase
                end
                4'b1011: begin
                    case (row_num_w)
                        2'b00: S7 = 7; 2'b01: S7 = 12; 2'b10: S7 = 8; 2'b11: S7 = 15; 
                    endcase
                end
                4'b1100: begin
                    case (row_num_w)
                        2'b00: S7 = 5; 2'b01: S7 = 2; 2'b10: S7 = 0; 2'b11: S7 = 14; 
                    endcase
                end
                4'b1101: begin
                    case (row_num_w)
                        2'b00: S7 = 10; 2'b01: S7 = 15; 2'b10: S7 = 5; 2'b11: S7 = 2; 
                    endcase
                end
                4'b1110: begin
                    case (row_num_w)
                        2'b00: S7 = 6; 2'b01: S7 = 8; 2'b10: S7 = 9; 2'b11: S7 = 3; 
                    endcase
                end
                4'b1111: begin
                    case (row_num_w)
                        2'b00: S7 = 1; 2'b01: S7 = 6; 2'b10: S7 = 2; 2'b11: S7 = 12; 
                    endcase
                end
            endcase
        end
    endfunction

    function automatic [3:0] S8;
        input [5:0] i_data;
        begin
            reg [3:0] col_num_w = i_data[4:1];
            reg [1:0] row_num_w = {i_data[5], i_data[0]};
            case (col_num_w)
                4'b0000: begin
                    case (row_num_w)
                        2'b00: S8 = 13; 2'b01: S8 = 1; 2'b10: S8 = 7; 2'b11: S8 = 2; 
                    endcase
                end
                4'b0001: begin
                    case (row_num_w)
                        2'b00: S8 = 2; 2'b01: S8 = 15; 2'b10: S8 = 11; 2'b11: S8 = 1; 
                    endcase
                end
                4'b0010: begin
                    case (row_num_w)
                        2'b00: S8 = 8; 2'b01: S8 = 13; 2'b10: S8 = 4; 2'b11: S8 = 14; 
                    endcase
                end
                4'b0011: begin
                    case (row_num_w)
                        2'b00: S8 = 4; 2'b01: S8 = 8; 2'b10: S8 = 1; 2'b11: S8 = 7; 
                    endcase
                end
                4'b0100: begin
                    case (row_num_w)
                        2'b00: S8 = 6; 2'b01: S8 = 10; 2'b10: S8 = 9; 2'b11: S8 = 4; 
                    endcase
                end
                4'b0101: begin
                    case (row_num_w)
                        2'b00: S8 = 15; 2'b01: S8 = 3; 2'b10: S8 = 12; 2'b11: S8 = 10; 
                    endcase
                end
                4'b0110: begin
                    case (row_num_w)
                        2'b00: S8 = 11; 2'b01: S8 = 7; 2'b10: S8 = 14; 2'b11: S8 = 8; 
                    endcase
                end
                4'b0111: begin
                    case (row_num_w)
                        2'b00: S8 = 1; 2'b01: S8 = 4; 2'b10: S8 = 2; 2'b11: S8 = 13; 
                    endcase
                end
                4'b1000: begin
                    case (row_num_w)
                        2'b00: S8 = 10; 2'b01: S8 = 12; 2'b10: S8 = 0; 2'b11: S8 = 15; 
                    endcase
                end
                4'b1001: begin
                    case (row_num_w)
                        2'b00: S8 = 9; 2'b01: S8 = 5; 2'b10: S8 = 6; 2'b11: S8 = 12; 
                    endcase
                end
                4'b1010: begin
                    case (row_num_w)
                        2'b00: S8 = 3; 2'b01: S8 = 6; 2'b10: S8 = 10; 2'b11: S8 = 9; 
                    endcase
                end
                4'b1011: begin
                    case (row_num_w)
                        2'b00: S8 = 14; 2'b01: S8 = 11; 2'b10: S8 = 13; 2'b11: S8 = 0; 
                    endcase
                end
                4'b1100: begin
                    case (row_num_w)
                        2'b00: S8 = 5; 2'b01: S8 = 0; 2'b10: S8 = 15; 2'b11: S8 = 3; 
                    endcase
                end
                4'b1101: begin
                    case (row_num_w)
                        2'b00: S8 = 0; 2'b01: S8 = 14; 2'b10: S8 = 3; 2'b11: S8 = 5; 
                    endcase
                end
                4'b1110: begin
                    case (row_num_w)
                        2'b00: S8 = 12; 2'b01: S8 = 9; 2'b10: S8 = 5; 2'b11: S8 = 6; 
                    endcase
                end
                4'b1111: begin
                    case (row_num_w)
                        2'b00: S8 = 7; 2'b01: S8 = 2; 2'b10: S8 = 8; 2'b11: S8 = 11; 
                    endcase
                end
            endcase
        end
    endfunction

    function automatic [31:0] F;
        input [31:0] right_data;
        input [47:0] sub_key;
        begin
            reg [47:0] s_data = expansion(right_data) ^ sub_key;
            reg [31:0] sbox_out_w = {S1(s_data[47:42]), S2(s_data[41:36]), S3(s_data[35:30]), S4(s_data[29:24]), S5(s_data[23:18]), S6(s_data[17:12]), S7(s_data[11:6]), S8(s_data[5:0])};
            F = P(sbox_out_w);
        end
        
    endfunction

endmodule
