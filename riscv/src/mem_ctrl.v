`ifndef MEM_CTRL
`define MEM_CTRL
`include "Mydefine.v"

        module MemCtrl(
                input wire clk,
                input wire rst,
                input wire rdy,
                input wire rollback,


                //向内存中读写



                input wire [7:0] mem_din,    //data input bus
                output reg [7:0] mem_dout,  //data output bus
                output reg [31:0] mem_a,  //address bus (only 17:0 is used)
                output reg mem_wr  ,  //1 for write

                input wire io_buffer_full,    //1 if uart buffer is full

                //insfetch
                input wire if_en,
                input wire [31:0] if_pc,
                output reg [31:0] if_data,
                output reg if_done
                // input  wire             if_en,
                //     input  wire [`ADDR_WID] if_pc,
                //     output reg              if_done,
                //     output reg  [`DATA_WID] if_data


                //lsb

                input wire lsb_en,
                input wire [31:0] lsb_addr,
                // input wire [31:0] lsb_pc,
                input wire lsb_wr,//1 for write, 0 for read
                input wire [2:0]lsb_len,
                input wire [31:0] lsb_w_data,
                output reg [31:0] lsb_r_data,
                output reg lsb_done

            );


            localparam IF=1,LOAD=2,STORE=3;
            //we already have IDLE for zero
            reg[1:0]status;
            reg [6:0] stage;
            reg [6:0 ] len;
            // reg[`MEM_CTRL_LEN_WID]stage;
            // reg [`MEM_CTRL_LEN_WID] len;
            reg [31:0] store_addr;
            // reg [31:0] store_pc;


            reg [7:0] if_data_arr[63:0];
            // reg [7:0] if_data_arr[`MEM_CTRL_IF_DATA_LEN-1:0];
            genvar gen;
            generate
                for (gen = 0; gen < 64; gen = gen + 1) begin
                    assign if_data[gen*8+7:gen*8] = if_data_arr[gen];
                end
            endgenerate



            always @(posedge clk) begin
                if(rst||!rdy) begin
                    if(rst) begin
                        status<=IDLE;
                    end
                    if_done<=0;
                    mem_wr<=0;
                    mem_a<=0;
                    lsb_done<=0;
                end



                else begin
                    // if(status!=IDLE) begin
                    //     if(stage==len) begin
                    //         stage<=3'h0;
                    //         status<=IDLE;
                    //         mem_wr<=0;
                    //         mem_a<=0;
                    //     end
                    //     else begin
                    //         stage<=stage+1;
                    //         // mem_wr<=0;
                    //         mem_a<=mem_a+1;
                    //     end
                    // end
                    mem_wr<=0;
                    case (status)
                        IDLE: begin
                            if(if_done||lsb_done) begin
                                if_done<=0;
                                lsb_done<=0;
                            end
                            else if(!rollback) begin


                                if(lsb_en) begin
                                    // status<=lsb_wr?STORE:LOAD;
                                    // mem_a<=lsb_pc;
                                    // // mem_wr<=lsb_wr;
                                    // len<=lsb_len;
                                    // stage<=3'h1;
                                    if(lsb_wr) begin
                                        status <= STORE;
                                        store_addr <= lsb_addr;
                                    end
                                    else begin
                                        status <= LOAD;
                                        mem_a <= lsb_addr;
                                        lsb_r_data <= 0;
                                    end
                                    stage<=0;
                                    len   <= {4'b0, lsb_len};
                                end



                                else if(if_en) begin
                                    status<=IF;
                                    mem_a<=if_pc;
                                    // mem_wr<=0;
                                    // stage<=3'h1;
                                    stage<=0;
                                    len<=64;
                                    // len    <= `MEM_CTRL_IF_DATA_LEN;
                                end



                            end
                        end


                        IF: begin
                            if_data_arr[stage-1] <= mem_din;
                            if (stage + 1 == len) begin
                                mem_a <= 0;
                            end
                            else begin
                                mem_a <= mem_a + 1;
                            end
                            if (stage == len) begin
                                if_done <= 1;
                                mem_wr  <= 0;
                                mem_a   <= 0;
                                stage   <= 0;
                                status  <= IDLE;
                            end
                            else begin
                                stage <= stage + 1;
                            end
                        end



                        LOAD: begin
                            if (rollback) begin
                                lsb_done <= 0;
                                mem_wr <= 0;
                                mem_a <= 0;
                                stage <= 0;
                                status <= IDLE;
                            end
                            else begin
                                case (stage)
                                    1: begin
                                        lsb_r_data[7:0] <= mem_din;
                                    end
                                    2: begin
                                        lsb_r_data[15:8] <= mem_din;
                                    end
                                    3: begin
                                        lsb_r_data[23:16] <= mem_din;
                                    end
                                    4: begin
                                        lsb_r_data[31:24] <= mem_din;
                                    end
                                endcase
                                if (stage + 1 == len) begin
                                    mem_a <= 0;
                                end
                                else begin
                                    mem_a <= mem_a + 1;
                                end
                                if (stage == len) begin
                                    lsb_done <= 1;
                                    mem_wr <= 0;
                                    mem_a <= 0;
                                    stage <= 0;
                                    status <= IDLE;
                                end
                                else begin
                                    stage <= stage + 1;
                                end
                            end
                        end




                        STORE: begin
                            if(io_buffer_full &&store_addr[17:16] == 2'b11) begin

                            end
                            else begin
                                mem_wr <= 1;
                                case (stage)
                                    0: begin
                                        mem_dout <= lsb_w_data[7:0];
                                    end
                                    1: begin
                                        mem_dout <= lsb_w_data[15:8];
                                    end
                                    2: begin
                                        mem_dout <= lsb_w_data[23:16];
                                    end
                                    3: begin
                                        mem_dout <= lsb_w_data[31:24];
                                    end
                                endcase
                                if (stage == 0) begin
                                    mem_a <= store_addr;
                                end
                                else begin
                                    mem_a <= mem_a + 1;
                                end
                                if (stage == len) begin
                                    lsb_done <= 1;
                                    mem_wr <= 0;
                                    mem_a <= 0;
                                    stage <= 0;
                                    status <= IDLE;
                                end
                                else begin
                                    stage <= stage + 1;
                                end
                            end


                        end

                    endcase
                end
            end

        endmodule

`endif
