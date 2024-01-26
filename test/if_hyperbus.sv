// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Luca Valente <luca.valente@unibo.it>

`timescale 1 ns/1 ps

`include "axi/typedef.svh"
`include "axi/assign.svh"
`include "register_interface/typedef.svh"
`include "register_interface/assign.svh"

module if_hyperbus
#(
  parameter int unsigned TbSetAssociativity = 32'd8,
  parameter int unsigned TbNumLines         = 32'd256,
  parameter int unsigned TbNumBlocks        = 32'd8,

  parameter int  AxiDataWidth    = 64,
  parameter int  AxiAddrWidth    = 64,
  parameter int  AxiIdWidth      =  6,
  parameter int  AxiUserWidth    =  4,

  parameter int  RegAw           = 32,
  parameter int  RegDw           = 32,

  parameter int  NumChips        =  2,
  parameter int  NumPhys         =  2,
  parameter int  IsClockODelayed =  0
)(
 input logic clk_i,
 input logic rst_ni,
 input logic end_sim_i,

 input logic [AxiAddrWidth-1:0] HyperBaseAddr,
 input logic [AxiAddrWidth-1:0] HyperLength,

 AXI_BUS.Slave axi_slv_if,
 REG_BUS.in    reg_slv_if
);

  typedef logic [AxiIdWidth-1:0] axi_cpu_id_t;
  typedef logic [AxiAddrWidth-1:0] axi_addr_t;
  typedef logic [AxiDataWidth-1:0] axi_data_t;
  typedef logic [AxiDataWidth/8-1:0] axi_strb_t;
  typedef logic [AxiUserWidth-1:0] axi_user_t;

  `AXI_TYPEDEF_AW_CHAN_T(axi_cpu_aw_chan_t, axi_addr_t, axi_cpu_id_t, axi_user_t)
  `AXI_TYPEDEF_W_CHAN_T(axi_w_chan_t, axi_data_t, axi_strb_t, axi_user_t)
  `AXI_TYPEDEF_B_CHAN_T(axi_cpu_b_chan_t, axi_cpu_id_t, axi_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(axi_cpu_ar_chan_t, axi_addr_t, axi_cpu_id_t, axi_user_t)
  `AXI_TYPEDEF_R_CHAN_T(axi_cpu_r_chan_t, axi_data_t, axi_cpu_id_t, axi_user_t)
  `AXI_TYPEDEF_REQ_T(axi_cpu_req_t, axi_cpu_aw_chan_t, axi_w_chan_t, axi_cpu_ar_chan_t)
  `AXI_TYPEDEF_RESP_T(axi_cpu_rsp_t, axi_cpu_b_chan_t, axi_cpu_r_chan_t)

   axi_cpu_req_t  axi_cpu_req;
   axi_cpu_rsp_t  axi_cpu_rsp;

   axi_cpu_req_t  axi_ser_req;
   axi_cpu_rsp_t  axi_ser_rsp;

   axi_cpu_req_t  axi_llc_req;
   axi_cpu_rsp_t  axi_llc_rsp;

  `AXI_ASSIGN_TO_REQ(axi_cpu_req, axi_slv_if)
  `AXI_ASSIGN_FROM_RESP(axi_slv_if, axi_cpu_rsp)

  typedef logic [AxiIdWidth:0] axi_mem_id_t;

  `AXI_TYPEDEF_AW_CHAN_T(axi_mem_aw_chan_t, axi_addr_t, axi_mem_id_t, axi_user_t)
  `AXI_TYPEDEF_B_CHAN_T(axi_mem_b_chan_t, axi_mem_id_t, axi_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(axi_mem_ar_chan_t, axi_addr_t, axi_mem_id_t, axi_user_t)
  `AXI_TYPEDEF_R_CHAN_T(axi_mem_r_chan_t, axi_data_t, axi_mem_id_t, axi_user_t)
  `AXI_TYPEDEF_REQ_T(axi_mem_req_t, axi_mem_aw_chan_t, axi_w_chan_t, axi_mem_ar_chan_t)
  `AXI_TYPEDEF_RESP_T(axi_mem_rsp_t, axi_mem_b_chan_t, axi_mem_r_chan_t)

   axi_mem_req_t  axi_mem_req;
   axi_mem_rsp_t  axi_mem_rsp;

  typedef logic [RegAw-1:0]   reg_addr_t;
  typedef logic [RegDw-1:0]   reg_data_t;
  typedef logic [RegDw/8-1:0] reg_strb_t;

  `REG_BUS_TYPEDEF_REQ(reg_req_t, reg_addr_t, reg_data_t, reg_strb_t)
  `REG_BUS_TYPEDEF_RSP(reg_rsp_t, reg_data_t)

  reg_req_t reg_req;
  reg_rsp_t reg_resp;

  `REG_BUS_ASSIGN_TO_REQ(reg_req,reg_slv_if)
  `REG_BUS_ASSIGN_FROM_RSP(reg_slv_if,reg_resp)

  // rule definitions
  typedef struct packed {
    int unsigned idx;
    axi_addr_t   start_addr;
    axi_addr_t   end_addr;
  } rule_full_t;

  localparam int ChiMainMem = 4;

  axi_fifo #(
          .Depth      ( ChiMainMem-2      ), // One comes from the serializer and one from the arbiter upstream
          .FallThrough( 1'b0              ),
          .axi_req_t  ( axi_cpu_req_t     ),
          .axi_resp_t ( axi_cpu_rsp_t     ),
          .aw_chan_t  ( axi_cpu_aw_chan_t ),
          .w_chan_t   ( axi_w_chan_t      ),
          .b_chan_t   ( axi_cpu_b_chan_t  ),
          .ar_chan_t  ( axi_cpu_ar_chan_t ),
          .r_chan_t   ( axi_cpu_r_chan_t  )
  ) i_axi_fifo (
      .clk_i      ( clk_i       ),
      .rst_ni     ( rst_ni      ),
      .test_i     ( 1'b0        ),
      .slv_req_i  ( axi_cpu_req ),
      .slv_resp_o ( axi_cpu_rsp ),
      .mst_req_o  ( axi_ser_req ),
      .mst_resp_i ( axi_ser_rsp )
  );
  axi_serializer #(
    .AxiIdWidth   ( AxiIdWidth    ),
    .MaxReadTxns  ( 1             ),
    .MaxWriteTxns ( 1             ),
    .axi_req_t    ( axi_cpu_req_t ),
    .axi_resp_t   ( axi_cpu_rsp_t )
  ) i_axi_atomics (
      .clk_i       ( clk_i       ),
      .rst_ni      ( rst_ni      ),
      .slv_req_i   ( axi_ser_req ),
      .slv_resp_o  ( axi_ser_rsp ),
      .mst_req_o   ( axi_llc_req ),
      .mst_resp_i  ( axi_llc_rsp )
  );

  axi_llc_reg_wrap #(
    .SetAssociativity ( TbSetAssociativity ),
    .NumLines         ( TbNumLines         ),
    .NumBlocks        ( TbNumBlocks        ),
    .AxiIdWidth       ( AxiIdWidth         ),
    .AxiAddrWidth     ( AxiAddrWidth       ),
    .AxiDataWidth     ( AxiDataWidth       ),
    .AxiUserWidth     ( AxiUserWidth       ),
    .slv_req_t        ( axi_cpu_req_t      ),
    .slv_resp_t       ( axi_cpu_rsp_t      ),
    .mst_req_t        ( axi_mem_req_t      ),
    .mst_resp_t       ( axi_mem_rsp_t      ),
    .reg_req_t        ( reg_req_t          ),
    .reg_resp_t       ( reg_rsp_t          ),
    .rule_full_t      ( rule_full_t        )
  ) i_axi_llc_dut (
    .clk_i               ( clk_i                                  ),
    .rst_ni              ( rst_ni                                 ),
    .test_i              ( 1'b0                                   ),
    .slv_req_i           ( axi_llc_req                            ),
    .slv_resp_o          ( axi_llc_rsp                            ),
    .mst_req_o           ( axi_mem_req                            ),
    .mst_resp_i          ( axi_mem_rsp                            ),
    .conf_req_i          ( reg_req                                ),
    .conf_resp_o         ( reg_resp                               ),
    .cached_start_addr_i ( HyperBaseAddr                          ),
    .cached_end_addr_i   ( HyperBaseAddr + HyperLength            ),
    .spm_start_addr_i    ( 'h7000_0000                            ),
    .axi_llc_events_o    (                                        )
  );

    logic [NumPhys-1:0][NumChips-1:0] hyper_cs_n_wire;
    logic [NumPhys-1:0]               hyper_ck_wire;
    logic [NumPhys-1:0]               hyper_ck_n_wire;
    logic [NumPhys-1:0]               hyper_rwds_o;
    logic [NumPhys-1:0]               hyper_rwds_i;
    logic [NumPhys-1:0]               hyper_rwds_oe;
    logic [NumPhys-1:0][7:0]          hyper_dq_i;
    logic [NumPhys-1:0][7:0]          hyper_dq_o;
    logic [NumPhys-1:0]               hyper_dq_oe;
    logic [NumPhys-1:0]               hyper_reset_n_wire;

    wire  [NumPhys-1:0][NumChips-1:0]  pad_hyper_csn;
    wire  [NumPhys-1:0]                pad_hyper_ck;
    wire  [NumPhys-1:0]                pad_hyper_ckn;
    wire  [NumPhys-1:0]                pad_hyper_rwds;
    wire  [NumPhys-1:0]                pad_hyper_reset;
    wire  [NumPhys-1:0][7:0]           pad_hyper_dq;

    // DUT
    hyperbus #(
        .NumChips       ( NumChips          ),
        .NumPhys        ( NumPhys           ),
        .AxiAddrWidth   ( AxiAddrWidth      ),
        .AxiDataWidth   ( AxiDataWidth      ),
        .AxiIdWidth     ( AxiIdWidth+1      ),
        .AxiUserWidth   ( AxiUserWidth      ),
        .axi_req_t      ( axi_mem_req_t     ),
        .axi_rsp_t      ( axi_mem_rsp_t     ),
        .axi_aw_chan_t  ( axi_mem_aw_chan_t ),
        .axi_w_chan_t   ( axi_w_chan_t      ),
        .axi_b_chan_t   ( axi_mem_b_chan_t  ),
        .axi_ar_chan_t  ( axi_mem_ar_chan_t ),
        .axi_r_chan_t   ( axi_mem_r_chan_t  ),
        .RegAddrWidth   ( RegAw             ),
        .RegDataWidth   ( RegDw             ),
        .reg_req_t      ( reg_req_t         ),
        .reg_rsp_t      ( reg_rsp_t         ),
        .IsClockODelayed( 0                 ),
        .axi_rule_t     ( rule_full_t       )
    ) i_dut (
        .clk_phy_i              ( clk_i              ),
        .rst_phy_ni             ( rst_ni             ),
        .clk_sys_i              ( clk_i              ),
        .rst_sys_ni             ( rst_ni             ),
        .test_mode_i            ( 1'b0               ),
        .axi_req_i              ( axi_mem_req        ),
        .axi_rsp_o              ( axi_mem_rsp        ),
        .reg_req_i              (                    ),
        .reg_rsp_o              (                    ),

        .hyper_cs_no            ( hyper_cs_n_wire    ),
        .hyper_ck_o             ( hyper_ck_wire      ),
        .hyper_ck_no            ( hyper_ck_n_wire    ),
        .hyper_rwds_o           ( hyper_rwds_o       ),
        .hyper_rwds_i           ( hyper_rwds_i       ),
        .hyper_rwds_oe_o        ( hyper_rwds_oe      ),
        .hyper_dq_i             ( hyper_dq_i         ),
        .hyper_dq_o             ( hyper_dq_o         ),
        .hyper_dq_oe_o          ( hyper_dq_oe        ),
        .hyper_reset_no         ( hyper_reset_n_wire )

    );


    generate
       for (genvar i=0; i<NumPhys; i++) begin : hyperrams
          for (genvar j=0; j<NumChips; j++) begin : chips

             s27ks0641 #(
               /*.mem_file_name ( "s27ks0641.mem"    ),*/
               .TimingModel   ( "S27KS0641DPBHI020"    )
             ) dut (
               .DQ7           ( pad_hyper_dq[i][7]  ),
               .DQ6           ( pad_hyper_dq[i][6]  ),
               .DQ5           ( pad_hyper_dq[i][5]  ),
               .DQ4           ( pad_hyper_dq[i][4]  ),
               .DQ3           ( pad_hyper_dq[i][3]  ),
               .DQ2           ( pad_hyper_dq[i][2]  ),
               .DQ1           ( pad_hyper_dq[i][1]  ),
               .DQ0           ( pad_hyper_dq[i][0]  ),
               .RWDS          ( pad_hyper_rwds[i]   ),
               .CSNeg         ( pad_hyper_csn[i][0] ),
               .CK            ( pad_hyper_ck[i]     ),
               .CKNeg         ( pad_hyper_ckn[i]    ),
               .RESETNeg      ( pad_hyper_reset[i]  )
             );
          end // block: chips
       end // block: hyperrams
    endgenerate

    generate
       for (genvar p=0; p<NumPhys; p++) begin : sdf_annotation
          for (genvar l=0; l<NumChips; l++) begin : sdf_annotation
             initial begin
                automatic string sdf_file_path = "./models/s27ks0641/s27ks0641.sdf";
                $sdf_annotate(sdf_file_path, hyperrams[p].chips[l].dut);
                $display("Mem (%d,%d)",p,l);
             end
         end
       end
    endgenerate

   for (genvar i = 0 ; i<NumPhys; i++) begin: pad_gen
    for (genvar j = 0; j<NumChips; j++) begin
       pad_functional_pd padinst_hyper_csno   (.OEN( 1'b0            ), .I( hyper_cs_n_wire[i][j] ), .O(                  ), .PAD( pad_hyper_csn[i][j] ), .PEN( 1'b0 ));
    end
    pad_functional_pd padinst_hyper_ck     (.OEN( 1'b0            ), .I( hyper_ck_wire[i]      ), .O(                  ), .PAD( pad_hyper_ck[i]     ), .PEN( 1'b0 ) );
    pad_functional_pd padinst_hyper_ckno   (.OEN( 1'b0            ), .I( hyper_ck_n_wire[i]    ), .O(                  ), .PAD( pad_hyper_ckn[i]    ), .PEN( 1'b0 ) );
    pad_functional_pd padinst_hyper_rwds   (.OEN(~hyper_rwds_oe[i]), .I( hyper_rwds_o[i]       ), .O( hyper_rwds_i[i]  ), .PAD( pad_hyper_rwds[i]   ), .PEN( 1'b0 ) );
    pad_functional_pd padinst_hyper_resetn (.OEN( 1'b0            ), .I( hyper_reset_n_wire[i] ), .O(                  ), .PAD( pad_hyper_reset[i]  ), .PEN( 1'b0 ) );
    pad_functional_pd padinst_hyper_dqio0  (.OEN(~hyper_dq_oe[i]  ), .I( hyper_dq_o[i][0]      ), .O( hyper_dq_i[i][0] ), .PAD( pad_hyper_dq[i][0]  ), .PEN( 1'b0 ) );
    pad_functional_pd padinst_hyper_dqio1  (.OEN(~hyper_dq_oe[i]  ), .I( hyper_dq_o[i][1]      ), .O( hyper_dq_i[i][1] ), .PAD( pad_hyper_dq[i][1]  ), .PEN( 1'b0 ) );
    pad_functional_pd padinst_hyper_dqio2  (.OEN(~hyper_dq_oe[i]  ), .I( hyper_dq_o[i][2]      ), .O( hyper_dq_i[i][2] ), .PAD( pad_hyper_dq[i][2]  ), .PEN( 1'b0 ) );
    pad_functional_pd padinst_hyper_dqio3  (.OEN(~hyper_dq_oe[i]  ), .I( hyper_dq_o[i][3]      ), .O( hyper_dq_i[i][3] ), .PAD( pad_hyper_dq[i][3]  ), .PEN( 1'b0 ) );
    pad_functional_pd padinst_hyper_dqio4  (.OEN(~hyper_dq_oe[i]  ), .I( hyper_dq_o[i][4]      ), .O( hyper_dq_i[i][4] ), .PAD( pad_hyper_dq[i][4]  ), .PEN( 1'b0 ) );
    pad_functional_pd padinst_hyper_dqio5  (.OEN(~hyper_dq_oe[i]  ), .I( hyper_dq_o[i][5]      ), .O( hyper_dq_i[i][5] ), .PAD( pad_hyper_dq[i][5]  ), .PEN( 1'b0 ) );
    pad_functional_pd padinst_hyper_dqio6  (.OEN(~hyper_dq_oe[i]  ), .I( hyper_dq_o[i][6]      ), .O( hyper_dq_i[i][6] ), .PAD( pad_hyper_dq[i][6]  ), .PEN( 1'b0 ) );
    pad_functional_pd padinst_hyper_dqio7  (.OEN(~hyper_dq_oe[i]  ), .I( hyper_dq_o[i][7]      ), .O( hyper_dq_i[i][7] ), .PAD( pad_hyper_dq[i][7]  ), .PEN( 1'b0 ) );
   end

endmodule
