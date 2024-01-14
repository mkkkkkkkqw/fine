`ifndef REORDER_BUFFER
`define REORDER_BUFFER
`include "Mydefine.v"
        module ROB(
                input wire clk,
                input wire rst,
                input wire rdy,



                output reg rollback,



                output wire rob_nxt_full,

                //IF

                output reg if_set_pc_en,
                output reg[31:0] if_set_pc,


                input wire issue,
                input wire [`OP_WID] issue_opcode,
                // input wire [`FUNCT3_WID] issue_funct3,
                // input wire [`FUNCT7_WID] issue_funct7,
                input wire [`REG_POS_WID] issue_rd,
                input wire [31:0]issue_pc,
                input wire issue_pred_jump,//是否是一个预测的跳转指令
                input wire                issue_is_ready,//是否就绪

                //提交
                output reg[`ROB_POS_WID]commit_rob_pos,

                //写回寄存器
                output reg reg_write,
                output reg [`REG_POS_WID] reg_rd,
                output reg [31:0] reg_val,

                //to LSB

                output reg lsb_store,//

                //from lsb
                input wire lsb_result,
                input wire [`ROB_POS_WID] lsb_result_rob_pos,
                // input wire [`REG_POS_WID] lsb_result_reg_pos,
                input wire [31:0] lsb_result_val,

                // to LSB and LSB check if I/O read can be done
                output wire [`ROB_POS_WID] head_rob_pos,

                // update predictor
                output reg                commit_br,
                output reg                commit_br_jump,
                output reg [   `ADDR_WID] commit_br_pc,

                //from RS
                input wire alu_result,
                input wire [`ROB_POS_WID] alu_result_rob_pos,
                // input wire [`REG_POS_WID] alu_result_reg_pos,
                input wire [31:0] alu_result_val,
                input wire alu_result_jump,
                input wire [31:0] alu_result_pc,

                //当 ALU 完成指令的执行并确定了跳转的结果后，
                //这个结果通过 alu_result_jump 信号传递到 ROB。
                // 在 ROB 中，
                // alu_result_jump 的值将与发射到 ROB 时的预测跳转结果（如 issue_pred_jump）进行比较。
                // 如果这两个结果不一致，
                // 即实际的跳转结果与预测的结果不同，
                // 这通常会触发退回（rollback）操作。
                // 这意味着处理器需要撤销由于错误预测而执行的后续指令，
                // 并从正确的分支继续执行。
                // input wire alu_result_pc,



                // from DECODER and to decoder
                // input wire [`OP_WID] opcode,
                //

                input wire [`ROB_POS_WID]rs1_pos,
                input wire [`ROB_POS_WID]rs2_pos,
                output wire rs1_ready,
                output wire rs2_ready,
                output wire [31:0] rs1_val,
                output wire [31:0] rs2_val,

                output wire [`ROB_POS_WID] nxt_rob_pos



            );

            reg ready [`ROB_SIZE-1:0];
            reg [`ROB_POS_WID] rd [`ROB_SIZE-1:0];
            reg [`OP_WID] opcode [`ROB_SIZE-1:0];
            // reg [`FUNCT3_WID] funct3 [`ROB_SIZE-1:0];
            // reg funct7 [`ROB_SIZE-1:0];
            reg [31:0] pc [`ROB_SIZE-1:0];
            reg[31:0 ] val[`ROB_SIZE-1:0];
            reg   pred_jump[`ROB_SIZE-1:0];  // predict whether to jump, 1=jump
            reg  res_jump [`ROB_SIZE-1:0];  // execution result
            reg [31:0] res_pc   [`ROB_SIZE-1:0];

            reg [`ROB_POS_WID] head,tail;
            reg empty;
            wire commit = !empty && ready[head];
            wire [`ROB_POS_WID] nxt_head = head+commit;
            wire [`ROB_POS_WID] nxt_tail = tail+issue;
            assign nxt_rob_pos = tail;
            // TODO: check
            wire nxt_empty = (nxt_head == nxt_tail && (empty || commit && !issue));
            assign rob_nxt_full =( nxt_head==nxt_tail && !nxt_empty);//rob满了

            wire nxt_empty = (nxt_head==nxt_tail && (empty||!issue));

            assign rs1_ready=ready[rs1_pos];
            assign rs2_ready=ready[rs2_pos];
            assign rs1_val=val[rs1_pos];
            assign rs2_val=val[rs2_pos];

            integer i;

            always @(posedge clk) begin
                if(rst||rollback||!rdy) begin
                    if(!rdy) begin

                    end

                    else begin
                        //rst||rollback
                        head<=0;
                        tail<=0;
                        empty<=1;
                        rollback<=0;
                        if_set_pc_en <= 0;
                        if_set_pc <= 0;
                        for(i=0;i<`ROB_SIZE;i=i+1) begin
                            ready[i]<=0;
                            rd[i]<=0;
                            opcode[i]<=0;
                            // funct3[i]<=0;
                            // funct7[i]<=0;
                            pc[i]<=0;
                            val[i]<=0;
                            pred_jump[i]<=0;
                            res_jump[i] <= 0;
                            res_pc[i] <= 0;
                        end
                        reg_write<=0;
                        lsb_store<=0;
                        commit_br <= 0;
                    end
                end

                else begin
                    empty<=nxt_empty;
                    if(issue) begin
                        rd[tail]<=issue_rd;
                        // ready[tail]<=0;
                        opcode[tail]<=issue_opcode;
                        // funct3[tail]<=issue_funct3;
                        // funct7[tail]<=issue_funct7;
                        pc[tail]<=issue_pc;
                        pred_jump[tail]<=issue_pred_jump;
                        ready[tail]<= issue_is_ready;
                        tail<= tail + 1'b1;
                    end

                    if(alu_result) begin
                        val[alu_result_rob_pos]<=alu_result_val;
                        ready[alu_result_rob_pos]<=1;
                        res_jump[alu_result_rob_pos] <= alu_result_jump;
                        res_pc[alu_result_rob_pos] <= alu_result_pc;
                    end


                    if(lsb_result) begin
                        val[lsb_result_rob_pos]<=lsb_result_val;
                        ready[lsb_result_rob_pos]<=1;
                    end


                    // commit
                    reg_write <= 0;
                    lsb_store <= 0;
                    commit_br <= 0;

                    
                    if (commit) begin

                        commit_rob_pos <= head;
                        if (opcode[head] == `OPCODE_S) begin
                            lsb_store <= 1;
                        end
                        else if (opcode[head] != `OPCODE_BR) begin
                            reg_write <= 1;
                            reg_rd    <= rd[head];
                            reg_val   <= val[head];
                        end
                        if (opcode[head] == `OPCODE_BR) begin
                            commit_br <= 1;
                            commit_br_jump <= res_jump[head];
                            commit_br_pc <= pc[head];
                            if (pred_jump[head] != res_jump[head]) begin
                                rollback <= 1;
                                if_set_pc_en <= 1;
                                if_set_pc <= res_pc[head];
                            end
                        end
                        if (opcode[head] == `OPCODE_JALR) begin
                            if (pred_jump[head] != res_jump[head]) begin  // TODO: check
                                rollback <= 1;
                                if_set_pc_en <= 1;
                                if_set_pc <= res_pc[head];
                            end
                        end
                        head <= head + 1'b1;
                    end
                end
            end



        endmodule
`endif // ROB!1
