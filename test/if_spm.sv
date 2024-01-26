`timescale 1 ns/1 ps

`include "axi/typedef.svh"
`include "axi/assign.svh"

module if_spm 
#(
  parameter AXI_ADDR_WIDTH = 64,
  parameter AXI_DATA_WIDTH = 64,
  parameter AXI_USER_WIDTH = 6,
  parameter AXI_ID_WIDTH   = 6,
  parameter NUM_ROWS       = 1024,
  parameter IDEAL_MEM      = 0
)
(
  input logic          clk_i,
  input logic          rst_ni,
  input logic          test_en_i,
  AXI_BUS.Slave        axi_slave
);

  import tcdm_interconnect_pkg::*;

  localparam NB_DMAS = 4;
  localparam NB_L2_BANKS = 4;   
  localparam L2_BANK_ADDR_WIDTH = $clog2(NUM_ROWS);
  localparam L2_DATA_WIDTH = 32;
  localparam L2_BANK_SIZE = NUM_ROWS; 

  logic [NB_DMAS-1:0][31:0] s_tcdm_bus_wdata;
  logic [NB_DMAS-1:0][31:0] s_tcdm_bus_add;
  logic [NB_DMAS-1:0]       s_tcdm_bus_req;
  logic [NB_DMAS-1:0]       s_tcdm_bus_wen;
  logic [NB_DMAS-1:0][3:0]  s_tcdm_bus_be;
  logic [NB_DMAS-1:0]       s_tcdm_bus_gnt;
  logic [NB_DMAS-1:0][31:0] s_tcdm_bus_r_rdata;
  logic [NB_DMAS-1:0]       s_tcdm_bus_r_valid;

  axi2tcdm #(
    .AXI_ADDR_WIDTH       ( AXI_ADDR_WIDTH        ),
    .AXI_DATA_WIDTH       ( AXI_DATA_WIDTH        ),
    .AXI_USER_WIDTH       ( AXI_USER_WIDTH        ),
    .AXI_ID_WIDTH         ( AXI_ID_WIDTH          )
  ) axi2mem_i (
    .clk_i                 ( clk_i                ),
    .rst_ni                ( rst_ni               ),

    .tcdm_master_req_o     ( s_tcdm_bus_req       ),
    .tcdm_master_add_o     ( s_tcdm_bus_add       ),
    .tcdm_master_type_o    ( s_tcdm_bus_wen       ),
    .tcdm_master_data_o    ( s_tcdm_bus_wdata     ),
    .tcdm_master_be_o      ( s_tcdm_bus_be        ),
    .tcdm_master_gnt_i     ( s_tcdm_bus_gnt       ),

    .tcdm_master_r_valid_i ( s_tcdm_bus_r_valid   ),
    .tcdm_master_r_data_i  ( s_tcdm_bus_r_rdata   ),

    .busy_o                ( busy_o               ),
    .test_en_i             ( test_en_i            ),

    .axi_slave_aw_valid_i  ( axi_slave.aw_valid   ),
    .axi_slave_aw_addr_i   ( axi_slave.aw_addr    ),
    .axi_slave_aw_prot_i   ( axi_slave.aw_prot    ),
    .axi_slave_aw_region_i ( axi_slave.aw_region  ),
    .axi_slave_aw_len_i    ( axi_slave.aw_len     ),
    .axi_slave_aw_size_i   ( axi_slave.aw_size    ),
    .axi_slave_aw_burst_i  ( axi_slave.aw_burst   ),
    .axi_slave_aw_lock_i   ( axi_slave.aw_lock    ),
    .axi_slave_aw_cache_i  ( axi_slave.aw_cache   ),
    .axi_slave_aw_qos_i    ( axi_slave.aw_qos     ),
    .axi_slave_aw_id_i     ( axi_slave.aw_id      ),
    .axi_slave_aw_user_i   ( axi_slave.aw_user    ),
    .axi_slave_aw_ready_o  ( axi_slave.aw_ready   ),

    .axi_slave_ar_valid_i  ( axi_slave.ar_valid   ),
    .axi_slave_ar_addr_i   ( axi_slave.ar_addr    ),
    .axi_slave_ar_prot_i   ( axi_slave.ar_prot    ),
    .axi_slave_ar_region_i ( axi_slave.ar_region  ),
    .axi_slave_ar_len_i    ( axi_slave.ar_len     ),
    .axi_slave_ar_size_i   ( axi_slave.ar_size    ),
    .axi_slave_ar_burst_i  ( axi_slave.ar_burst   ),
    .axi_slave_ar_lock_i   ( axi_slave.ar_lock    ),
    .axi_slave_ar_cache_i  ( axi_slave.ar_cache   ),
    .axi_slave_ar_qos_i    ( axi_slave.ar_qos     ),
    .axi_slave_ar_id_i     ( axi_slave.ar_id      ),
    .axi_slave_ar_user_i   ( axi_slave.ar_user    ),
    .axi_slave_ar_ready_o  ( axi_slave.ar_ready   ),

    .axi_slave_w_valid_i   ( axi_slave.w_valid    ),
    .axi_slave_w_data_i    ( axi_slave.w_data     ),
    .axi_slave_w_strb_i    ( axi_slave.w_strb     ),
    .axi_slave_w_user_i    ( axi_slave.w_user     ),
    .axi_slave_w_last_i    ( axi_slave.w_last     ),
    .axi_slave_w_ready_o   ( axi_slave.w_ready    ),

    .axi_slave_r_valid_o   ( axi_slave.r_valid    ),
    .axi_slave_r_data_o    ( axi_slave.r_data     ),
    .axi_slave_r_resp_o    ( axi_slave.r_resp     ),
    .axi_slave_r_last_o    ( axi_slave.r_last     ),
    .axi_slave_r_id_o      ( axi_slave.r_id       ),
    .axi_slave_r_user_o    ( axi_slave.r_user     ),
    .axi_slave_r_ready_i   ( axi_slave.r_ready    ),

    .axi_slave_b_valid_o   ( axi_slave.b_valid    ),
    .axi_slave_b_resp_o    ( axi_slave.b_resp     ),
    .axi_slave_b_id_o      ( axi_slave.b_id       ),
    .axi_slave_b_user_o    ( axi_slave.b_user     ),
    .axi_slave_b_ready_i   ( axi_slave.b_ready    )
  );
            
  // BEHAV MEMORY
  logic [31:0] mem_q [NUM_ROWS-1:0];
   

  generate
     if(IDEAL_MEM==1) begin : ideal_mem
        
        always_comb begin
           for(int unsigned j = 0; j<NB_DMAS; j++)
             s_tcdm_bus_gnt[j] = s_tcdm_bus_req[j];
        end
        always_ff @(posedge clk_i) begin
           for (int unsigned i = 0; i<NB_DMAS; i++) begin
              s_tcdm_bus_r_rdata[i] = '0;
              s_tcdm_bus_r_valid[i] = 1'b0;        
              if(s_tcdm_bus_req[i]) begin
                 if(~s_tcdm_bus_wen[i]) begin
                    for (int unsigned k = 0; k<4; k++) begin
                       if(s_tcdm_bus_be[i][k]) begin
                          mem_q[(s_tcdm_bus_add[i]>>2)][k*8+:8]=s_tcdm_bus_wdata[i][k*8+:8];
                       end
                    end
                 end else begin
                    s_tcdm_bus_r_rdata[i] = mem_q[(s_tcdm_bus_add[i]>>2)];
                    s_tcdm_bus_r_valid[i] = 1'b1;
                 end
              end
           end
        end 

     end else begin : tcdm_mem // block: ideal_mem

          logic [NB_L2_BANKS-1:0]                          mem_req_l2;
          logic [NB_L2_BANKS-1:0]                          mem_wen_l2;
          logic [NB_L2_BANKS-1:0]                          mem_gnt_l2;
          logic [NB_L2_BANKS-1:0][L2_BANK_ADDR_WIDTH-1:0]  mem_addr_l2;
          logic [NB_L2_BANKS-1:0][3:0]                     mem_be_l2;
          logic [NB_L2_BANKS-1:0][L2_DATA_WIDTH-1:0]       mem_wdata_l2;
          logic [NB_L2_BANKS-1:0][L2_DATA_WIDTH-1:0]       mem_rdata_l2;
          
          tcdm_interconnect #(
            .NumIn        ( NB_DMAS                    ),
            .NumOut       ( NB_L2_BANKS                ), // NUM BANKS
            .AddrWidth    ( 32                         ),
            .DataWidth    ( L2_DATA_WIDTH              ),
            .AddrMemWidth ( L2_BANK_ADDR_WIDTH         ),
            .WriteRespOn  ( 1                          ),
            .RespLat      ( 1                          ),
            .Topology     ( tcdm_interconnect_pkg::LIC )
          ) i_tcdm_interconnect (
            .clk_i,
            .rst_ni,
            .req_i    ( s_tcdm_bus_req     ),
            .add_i    ( s_tcdm_bus_add     ),
            .wen_i    ( s_tcdm_bus_wen     ),
            .wdata_i  ( s_tcdm_bus_wdata   ),
            .be_i     ( s_tcdm_bus_be      ),
            .gnt_o    ( s_tcdm_bus_gnt     ),                        
            .vld_o    ( s_tcdm_bus_r_valid ),
            .rdata_o  ( s_tcdm_bus_r_rdata ),
                                 
            .req_o    ( mem_req_l2         ),
            .gnt_i    ( mem_gnt_l2         ),
            .add_o    ( mem_addr_l2        ),
            .wen_o    ( mem_wen_l2         ),
            .wdata_o  ( mem_wdata_l2       ),
            .be_o     ( mem_be_l2          ),
            .rdata_i  ( mem_rdata_l2       )
          );

          for(genvar i=0; i<NB_L2_BANKS; i++) begin : CUTS
          
           //Perform TCDM handshaking for constant 1 cycle latency
           assign mem_gnt_l2[i] = mem_req_l2[i];
           
             tc_sram #(
               .SimInit   ( "random"            ),
               .NumWords  ( L2_BANK_SIZE        ), // 2^15 lines of 32 bits each (128kB), 4 Banks -> 512 kB total memory
               .DataWidth ( L2_DATA_WIDTH       ),
               .NumPorts  ( 1                   )
             ) bank_i (
               .clk_i,
               .rst_ni  (  rst_ni               ),
               .req_i   (  mem_req_l2[i]        ),
               .we_i    (  ~mem_wen_l2[i]       ),
               .addr_i  (  mem_addr_l2[i]       ),
               .wdata_i (  mem_wdata_l2[i]      ),
               .be_i    (  mem_be_l2[i]         ),
               .rdata_o (  mem_rdata_l2[i]      )
             );
          end // block: CUTS

     end // block: tcdm_mem  
  endgenerate
   
   
endmodule
