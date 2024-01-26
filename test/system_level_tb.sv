// Copyright (c) 2024 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//

// Directed Random Verification Testbench for `axi_xbar`:  The crossbar is instantiated with
// a number of random axi master and slave modules.  Each random master executes a fixed number of
// writes and reads over the whole addess map.  All masters simultaneously issue transactions
// through the crossbar, thereby saturating it.  A monitor, which snoops the transactions of each
// master and slave port and models the crossbar with a network of FIFOs, checks whether each
// transaction follows the expected route.

`include "axi/typedef.svh"
`include "axi/assign.svh"

/// Testbench for the module `axi_xbar`.
module tb_system_level #(
  /// Number of AXI masters connected to the xbar. (Number of slave ports)
  parameter int unsigned TbNumMasters        = 32'd2,
  /// Number of AXI slaves connected to the xbar. (Number of master ports)
  parameter int unsigned TbNumSlaves         = 32'd2,
  /// AXI4+ATOP ID width of the masters connected to the slave ports of the DUT.
  /// The ID width of the slaves is calculated depending on the xbar configuration.
  parameter int unsigned TbAxiIdWidthMasters = 32'd7,
  /// The used ID width of the DUT.
  /// Has to be `TbAxiIdWidthMasters >= TbAxiIdUsed`.
  parameter int unsigned TbAxiIdUsed         = 32'd3,
  /// Data width of the AXI channels.
  parameter int unsigned TbAxiDataWidth      = 32'd64,
  /// Pipeline stages in the xbar itself (between demux and mux).
  parameter int unsigned TbPipeline          = 32'd0,
  /// Enable ATOP generation
  parameter bit          TbEnAtop            = 1'b0,
  /// Enable exclusive accesses
  parameter bit TbEnExcl                     = 1'b0,
  /// Restrict to only unique IDs
  parameter bit TbUniqueIds                  = 1'b1,
  // Test in isolation
  parameter bit Isolation                    = 1'b0,
  // Test burst len
  parameter int unsigned BLEN                = 32'd15,
  // Test oustanding
  parameter int unsigned PHI                 = 32'd3
);

  // TB timing parameters
  localparam time CyclTime = 10ns;
  localparam time ApplTime =  2ns;
  localparam time TestTime =  8ns;

  localparam int InterferceBLen = BLEN;

  localparam int ClAxiPeriod = 40;
  localparam int ClAxiNumWR  = 40;
  localparam int ClAxiNumRd  = 40;
  localparam int ClAxiBSize  = InterferceBLen;
  localparam int ClMaxWrInfl = PHI;
  localparam int ClMaxRdInfl = PHI;
  localparam int MaxClAXWaitTime = 0;

  localparam int HoAxiPeriod = 160;
  localparam int HoAxiNumWR  = 80;
  localparam int HoAxiNumRd  = 80;
  localparam int HoAxiBSize  = 8;
  localparam int HoMaxWrInfl = 8;
  localparam int HoMaxRdInfl = 8;
  localparam int MaxHoAXWaitTime = 0;

  // AXI configuration which is automatically derived.
  localparam int unsigned TbAxiIdWidthSlaves =  TbAxiIdWidthMasters + $clog2(TbNumMasters);
  localparam int unsigned TbAxiAddrWidth     =  32'd32;
  localparam int unsigned TbAxiStrbWidth     =  TbAxiDataWidth / 8;
  localparam int unsigned TbAxiUserWidth     =  5;

  typedef logic [TbAxiIdWidthMasters-1:0] id_mst_t;
  typedef logic [TbAxiIdWidthSlaves-1:0]  id_slv_t;
  typedef logic [TbAxiAddrWidth-1:0]      addr_t;
  typedef axi_pkg::xbar_rule_32_t         rule_t; // Has to be the same width as axi addr
  typedef logic [TbAxiDataWidth-1:0]      data_t;
  typedef logic [TbAxiStrbWidth-1:0]      strb_t;
  typedef logic [TbAxiUserWidth-1:0]      user_t;

  `AXI_TYPEDEF_AW_CHAN_T(aw_chan_mst_t, addr_t, id_mst_t, user_t)
  `AXI_TYPEDEF_AW_CHAN_T(aw_chan_slv_t, addr_t, id_slv_t, user_t)
  `AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(b_chan_mst_t, id_mst_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(b_chan_slv_t, id_slv_t, user_t)

  `AXI_TYPEDEF_AR_CHAN_T(ar_chan_mst_t, addr_t, id_mst_t, user_t)
  `AXI_TYPEDEF_AR_CHAN_T(ar_chan_slv_t, addr_t, id_slv_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(r_chan_mst_t, data_t, id_mst_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(r_chan_slv_t, data_t, id_slv_t, user_t)

  `AXI_TYPEDEF_REQ_T(mst_req_t, aw_chan_mst_t, w_chan_t, ar_chan_mst_t)
  `AXI_TYPEDEF_RESP_T(mst_resp_t, b_chan_mst_t, r_chan_mst_t)
  `AXI_TYPEDEF_REQ_T(slv_req_t, aw_chan_slv_t, w_chan_t, ar_chan_slv_t)
  `AXI_TYPEDEF_RESP_T(slv_resp_t, b_chan_slv_t, r_chan_slv_t)

   localparam addr_t HyperBaseAddr = 'h8000_0000;
   localparam addr_t HyperLength   = 'h100_0000;

   localparam addr_t SPMBaseAddr = 'h1C00_0000;
   localparam NumRows = 1024;
   localparam addr_t SPMLength   = 'h4 * NumRows;

   localparam int unsigned TbSetAssociativity = 32'd8;
   localparam int unsigned TbNumLines         = 32'd256;
   localparam int unsigned TbNumBlocks        = 32'd8;
   localparam addr_t       SpmRegionLength    = addr_t'(TbSetAssociativity * TbNumLines * TbNumBlocks * TbAxiDataWidth / 32'd8);

  typedef axi_test::axi_rand_master #(
    // AXI interface parameters
    .AW                   ( TbAxiAddrWidth      ),
    .DW                   ( TbAxiDataWidth      ),
    .IW                   ( TbAxiIdWidthMasters ),
    .UW                   ( TbAxiUserWidth      ),
    // Stimuli application and test time
    .TA                   ( ApplTime            ),
    .TT                   ( TestTime            ),
    // Traffic shaping to benchmark
    .SIZE_ALIGN           ( 6                   ),
    .TRAFFIC_SHAPING      ( 1                   ),
    .AX_MAX_WAIT_CYCLES   ( MaxHoAXWaitTime     ),
    .W_MAX_WAIT_CYCLES    ( 0                   ),
    .RESP_MAX_WAIT_CYCLES ( 0                   ),
    // Maximum number of read and write transactions in flight
    .MAX_READ_TXNS        ( HoMaxRdInfl         ),
    .MAX_WRITE_TXNS       ( HoMaxWrInfl         ),
    .AXI_BURST_FIXED      ( 0                   ),
    .AXI_EXCLS            ( TbEnExcl            ),
    .AXI_ATOPS            ( TbEnAtop            ),
    .UNIQUE_IDS           ( TbUniqueIds         )
  ) cva6_master_t;

  typedef axi_test::axi_rand_master #(
    // AXI interface parameters
    .AW                   ( TbAxiAddrWidth      ),
    .DW                   ( TbAxiDataWidth      ),
    .IW                   ( TbAxiIdWidthMasters ),
    .UW                   ( TbAxiUserWidth      ),
    // Stimuli application and test time
    .TA                   ( ApplTime            ),
    .TT                   ( TestTime            ),
    // Traffic shaping to benchmark
    .SIZE_ALIGN           ( 6                   ),
    .TRAFFIC_SHAPING      ( 1                   ),
    .AX_MAX_WAIT_CYCLES   ( MaxClAXWaitTime     ),
    .W_MAX_WAIT_CYCLES    ( 0                   ),
    .RESP_MAX_WAIT_CYCLES ( 0                   ),
    // Maximum number of read and write transactions in flight
    .MAX_READ_TXNS        ( ClMaxRdInfl         ),
    .MAX_WRITE_TXNS       ( ClMaxWrInfl         ),
    .AXI_BURST_FIXED      ( 0                   ),
    .AXI_EXCLS            ( TbEnExcl            ),
    .AXI_ATOPS            ( TbEnAtop            ),
    .UNIQUE_IDS           ( TbUniqueIds         )
  ) cluster_master_t;

  typedef axi_test::axi_scoreboard #(
    .IW( TbAxiIdWidthMasters ),
    .AW( TbAxiAddrWidth      ),
    .DW( TbAxiDataWidth      ),
    .UW( TbAxiUserWidth      ),
    .TT( TestTime            )
  ) axi_scoreboard_t;

  typedef wce_trace::axi_tracer #(
    .IW( TbAxiIdWidthMasters ),
    .AW( TbAxiAddrWidth      ),
    .DW( TbAxiDataWidth      ),
    .UW( TbAxiUserWidth      ),
    .TT( TestTime            )
  ) axi_tracer_t;

  typedef axi_test::axi_driver #(
    .IW( TbAxiIdWidthMasters ),
    .AW( TbAxiAddrWidth      ),
    .DW( TbAxiDataWidth      ),
    .UW( TbAxiUserWidth      ),
    .TT( TestTime            )
  ) axi_driver_t;

  // -------------
  // DUT signals
  // -------------
  logic clk;
  // DUT signals
  logic rst_n;
  logic [TbNumMasters-1:0] end_of_sim;

  // master structs
  mst_req_t  [TbNumMasters-1:0] masters_req;
  mst_resp_t [TbNumMasters-1:0] masters_resp;

  // slave structs
  slv_req_t  [TbNumSlaves-1:0]  slaves_req;
  slv_resp_t [TbNumSlaves-1:0]  slaves_resp;

  // -------------------------------
  // AXI Interfaces
  // -------------------------------
  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth      ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth      ),
    .AXI_ID_WIDTH   ( TbAxiIdWidthMasters ),
    .AXI_USER_WIDTH ( TbAxiUserWidth      )
  ) cva6_master (
     .clk_i ( clk)
  );

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth      ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth      ),
    .AXI_ID_WIDTH   ( TbAxiIdWidthMasters ),
    .AXI_USER_WIDTH ( TbAxiUserWidth      )
  ) cva6_master_scoreboard (
      .clk_i ( clk)
  );

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth      ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth      ),
    .AXI_ID_WIDTH   ( TbAxiIdWidthMasters ),
    .AXI_USER_WIDTH ( TbAxiUserWidth      )
  ) cva6_master_tracer (
     .clk_i ( clk)
  );

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth      ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth      ),
    .AXI_ID_WIDTH   ( TbAxiIdWidthMasters ),
    .AXI_USER_WIDTH ( TbAxiUserWidth      )
  ) cl_master (
     .clk_i ( clk)
  );

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth      ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth      ),
    .AXI_ID_WIDTH   ( TbAxiIdWidthMasters ),
    .AXI_USER_WIDTH ( TbAxiUserWidth      )
  ) cl_master_scoreboard (
     .clk_i ( clk)
  );

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth      ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth      ),
    .AXI_ID_WIDTH   ( TbAxiIdWidthMasters ),
    .AXI_USER_WIDTH ( TbAxiUserWidth      )
  ) cl_master_tracer (
     .clk_i ( clk)
  );

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth      ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth      ),
    .AXI_ID_WIDTH   ( TbAxiIdWidthMasters ),
    .AXI_USER_WIDTH ( TbAxiUserWidth      )
  ) cdc_slv (
     .clk_i ( clk)
  );

  AXI_BUS#(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth      ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth      ),
    .AXI_ID_WIDTH   ( TbAxiIdWidthMasters ),
    .AXI_USER_WIDTH ( TbAxiUserWidth      )
  ) cdc_master [TbNumMasters-1:0] ( );

  AXI_BUS#(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth      ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth      ),
    .AXI_ID_WIDTH   ( TbAxiIdWidthMasters ),
    .AXI_USER_WIDTH ( TbAxiUserWidth      )
  ) master [TbNumMasters-1:0] ( );

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth     ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth     ),
    .AXI_ID_WIDTH   ( TbAxiIdWidthSlaves ),
    .AXI_USER_WIDTH ( TbAxiUserWidth     )
  ) slave [TbNumSlaves-1:0] (  );

  REG_BUS #(
    .ADDR_WIDTH ( 32'd32 ),
    .DATA_WIDTH ( 32'd32 )
  ) reg_cfg_intf (
    .clk_i ( clk )
  );
  assign reg_cfg_intf.write = 1'b0;
  assign reg_cfg_intf.valid = 1'b0;
  assign reg_cfg_intf.addr  = '0;
  assign reg_cfg_intf.wdata = '0;
  assign reg_cfg_intf.wstrb = '0;

  // -------------------------------------
  // AXI Masters (w scoreboard and tracer)
  // -------------------------------------

  `AXI_ASSIGN_MONITOR(cva6_master_tracer,cva6_master)
  `AXI_ASSIGN_MONITOR(cva6_master_scoreboard,cva6_master)

  initial begin
    automatic axi_tracer_t axi_cpu_tracer = new( 0, cva6_master_tracer );
    @(posedge rst_n);
    axi_cpu_tracer.trace();
  end

  `AXI_ASSIGN_MONITOR(cl_master_tracer,cl_master)
  `AXI_ASSIGN_MONITOR(cl_master_scoreboard,cl_master)

  initial begin
    automatic axi_tracer_t axi_pulp_tracer = new( 1, cl_master_tracer );
    @(posedge rst_n);
//  axi_pulp_tracer.trace();
  end

  // TEST

  initial begin

    automatic axi_driver_t axi_cva6_master = new (cva6_master);
    automatic axi_scoreboard_t cpu_scoreboard  = new( cva6_master_scoreboard );

    automatic cluster_master_t axi_cl_master = new( cl_master );
    automatic axi_scoreboard_t pulp_scoreboard  = new( cl_master_scoreboard );

    automatic int cva6_ax_len [0:7]  = {7, 15, 31, 47, 63, 127, 191, 255};

    automatic axi_driver_t::ax_beat_t cva6_ax_beat= new;
    automatic axi_driver_t::b_beat_t  cva6_b_beat = new;
    automatic axi_driver_t::r_beat_t  cva6_r_beat = new;
    automatic axi_driver_t::w_beat_t  cva6_w_beat = new;

    automatic int isolation = Isolation;

    end_of_sim <= '0;

    cpu_scoreboard.reset();
    axi_cva6_master.reset_master();
    cpu_scoreboard.enable_all_checks();

    pulp_scoreboard.reset();
    axi_cl_master.reset();
    pulp_scoreboard.enable_all_checks();

    @(posedge rst_n);
    #1210us;

    cva6_ax_beat.ax_size = 'h3;
    cva6_ax_beat.ax_burst = axi_pkg::BURST_INCR;
    cva6_ax_beat.ax_lock = '0;
    cva6_ax_beat.ax_cache = '0;
    cva6_ax_beat.ax_prot = '0;
    cva6_ax_beat.ax_qos = '0;
    cva6_ax_beat.ax_region = '0;
    cva6_ax_beat.ax_atop = '0;
    cva6_ax_beat.ax_user = '0;
    cva6_w_beat.w_strb = '1;
    cva6_w_beat.w_user = '0;

    $info("SWIPE OF READS");

    if(isolation==1)
      $info("L2: ISOLATION");
    else
      $info("L2: INTERFERENCE");

    fork
       begin

          cva6_ax_beat.ax_id = 0;
          cva6_ax_beat.ax_addr = SPMBaseAddr;

          for(int i = 0 ; i < 8; i = i + 1) begin

             if(isolation==1)
                cva6_ax_beat.ax_len = cva6_ax_len[i];
             else
               cva6_ax_beat.ax_len = InterferceBLen;

            repeat(5)
               @(posedge clk);
             axi_cva6_master.send_ar(cva6_ax_beat);
             for( int j = 0; j<cva6_ax_beat.ax_len+1; j= j+1) begin
                axi_cva6_master.recv_r(cva6_r_beat);
             end
             assert(cva6_r_beat.r_last) else
               $display("Not the last?");

             cva6_ax_beat.ax_addr = cva6_ax_beat.ax_addr + ( cva6_ax_beat.ax_len + 1 ) * ( 1<<cva6_ax_beat.ax_size );
             cva6_ax_beat.ax_id = cva6_ax_beat.ax_id + 1;

          end // for (int i = 0 ; i < 8; i = i + 1)

       end // fork begin
       begin
          if(isolation == 1) begin
             repeat(5)
               @(posedge clk);
          end else begin
             axi_cl_master.add_memory_region(SPMBaseAddr,SPMBaseAddr+SPMLength,axi_pkg::DEVICE_NONBUFFERABLE);
             axi_cl_master.add_traffic_shaping(ClAxiBSize,3,10);
             axi_cl_master.run(ClAxiNumRd,ClAxiNumWR);
          end
       end
    join

    $info("SWIPE OF WRITES");

    cva6_ax_beat.ax_id = 'b1000;
    cva6_ax_beat.ax_addr = 32'h1C00_0000;

    fork
       begin

         for(int i = 0 ; i < 8; i = i + 1) begin

            repeat(6)
               @(posedge clk);
            if(isolation==1)
              cva6_ax_beat.ax_len = cva6_ax_len[i];
            else
              cva6_ax_beat.ax_len = InterferceBLen;

            cva6_w_beat.w_data = 0;

            axi_cva6_master.send_aw(cva6_ax_beat);
            for( int j = 0; j<cva6_ax_beat.ax_len; j= j+1) begin
               cva6_w_beat.w_data = j;
               cva6_w_beat.w_last = 1'b0;
               axi_cva6_master.send_w(cva6_w_beat);
            end
            cva6_w_beat.w_data = cva6_w_beat.w_data + 1;
            cva6_w_beat.w_last = 1'b1;
            axi_cva6_master.send_w(cva6_w_beat);
            axi_cva6_master.recv_b(cva6_b_beat);
            cva6_ax_beat.ax_id = cva6_ax_beat.ax_id + 1;

         end // for (int i = 0 ; i < 8; i = i + 1)
       end // fork begin
       begin
          if(isolation == 1) begin
             repeat(5)
               @(posedge clk);
          end else begin
             axi_cl_master.run(ClAxiNumRd,ClAxiNumWR);
          end
       end
    join


    $info("L3: ISOLATION");

    $info("SWIPE OF READS");

    for(int j=0; j<2; j++) begin

       if(j==0) begin
          cva6_ax_beat.ax_id = 'h20;
          $info("MISSES");
       end else begin          
         $info("HITS");
          cva6_ax_beat.ax_id = 'h30;
       end

       cva6_ax_beat.ax_addr = 'h8000_0000 ;

       fork
          begin

             for(int i =0; i < 8 ; i = i +1) begin

               if(isolation==1)
                  cva6_ax_beat.ax_len = cva6_ax_len[i];
               else
                 cva6_ax_beat.ax_len = InterferceBLen;

               repeat(10)
                 @(posedge clk);
                axi_cva6_master.send_ar(cva6_ax_beat);
                for( int l = 0; l<cva6_ax_beat.ax_len+1; l= l+1) begin
                   axi_cva6_master.recv_r(cva6_r_beat);
                end
                assert(cva6_r_beat.r_last) else
                  $display("Not the last?");

                cva6_ax_beat.ax_addr = cva6_ax_beat.ax_addr + ( cva6_ax_beat.ax_len + 1 ) * ( 1<<cva6_ax_beat.ax_size );
                cva6_ax_beat.ax_id = cva6_ax_beat.ax_id + 1;

             end // for (int i =0; i < 8 ; i = i +1)
          end // fork begin
          begin
             if(isolation == 1) begin
             repeat(5)
               @(posedge clk);
             end else begin
                axi_cl_master.clear_memory_regions();
                axi_cl_master.add_memory_region(HyperBaseAddr,HyperBaseAddr+SpmRegionLength/16,axi_pkg::DEVICE_NONBUFFERABLE);
                axi_cl_master.run(ClAxiNumRd,ClAxiNumWR);
             end
          end
       join

    end

    $info("Fill the cache");
    cva6_ax_beat.ax_id = '1;
    for(int k=0; k < SpmRegionLength; k = k + (TbNumBlocks * TbAxiDataWidth / 32'd8) ) begin

       cva6_ax_beat.ax_addr = 'h8000_0000 + k;
       cva6_w_beat.w_data = 0;
       cva6_ax_beat.ax_len = TbNumBlocks-1;

       axi_cva6_master.send_aw(cva6_ax_beat);
       for( int i = 0; i<TbNumBlocks-1; i= i+1) begin
          cva6_w_beat.w_data = i;
          cva6_w_beat.w_last = 1'b0;
          axi_cva6_master.send_w(cva6_w_beat);
       end
       cva6_w_beat.w_data = cva6_w_beat.w_data + 1;
       cva6_w_beat.w_last = 1'b1;
       axi_cva6_master.send_w(cva6_w_beat);
       axi_cva6_master.recv_b(cva6_b_beat);

    end

    $info("SWIPE OF WRITES");

    for(int j=0; j<2; j++) begin

       if(j==0) begin
        repeat(1000)
           @(posedge clk);
         $info("HITS");
         cva6_ax_beat.ax_id = 'h40;
         cva6_ax_beat.ax_addr = 'h8000_0000 ;
       end else begin
         repeat(1000)
           @(posedge clk);
         $info("EVICTION");
         cva6_ax_beat.ax_id = 'h50;
         cva6_ax_beat.ax_addr = 'h8000_0000 + SpmRegionLength;
       end

       cva6_w_beat.w_data = 0;

       fork
          begin
             for(int p=0;p<8;p=p+1) begin

               if(isolation==1)
                  cva6_ax_beat.ax_len = cva6_ax_len[p];
               else
                 cva6_ax_beat.ax_len = InterferceBLen;

               repeat(20)
                 @(posedge clk);
                axi_cva6_master.send_aw(cva6_ax_beat);
                for( int i = 0; i<cva6_ax_beat.ax_len; i= i+1) begin
                   cva6_w_beat.w_data = i;
                   cva6_w_beat.w_last = 1'b0;
                   axi_cva6_master.send_w(cva6_w_beat);
                end
                cva6_w_beat.w_data = cva6_w_beat.w_data + 1;
                cva6_w_beat.w_last = 1'b1;
                axi_cva6_master.send_w(cva6_w_beat);
                axi_cva6_master.recv_b(cva6_b_beat);

                cva6_ax_beat.ax_addr = cva6_ax_beat.ax_addr + ( cva6_ax_beat.ax_len + 1 ) * ( 1<<cva6_ax_beat.ax_size );
                cva6_ax_beat.ax_id = cva6_ax_beat.ax_id + 1;

             end // for (int p=0;p<8;p=p+1)
          end // fork begin
          begin
             if(isolation == 1) begin
               repeat(5)
                 @(posedge clk);
             end else begin
                if(j==1) begin
                   axi_cl_master.clear_memory_regions();
                   axi_cl_master.add_memory_region(HyperBaseAddr+SpmRegionLength*6,HyperBaseAddr+SpmRegionLength*8,axi_pkg::DEVICE_NONBUFFERABLE);
                   axi_cl_master.run(ClAxiNumRd,ClAxiNumWR);
                end
             end
          end
       join
    end

    repeat(100)
      @(posedge clk);

    $finish();

  end // initial begin

  //-----------------------------------
  // Clock generator
  //-----------------------------------
    clk_rst_gen #(
    .ClkPeriod    ( CyclTime ),
    .RstClkCycles ( 5        )
  ) i_clk_gen (
    .clk_o (clk),
    .rst_no(rst_n)
  );

  //-----------------------------------
  // DUT
  //-----------------------------------

  `AXI_ASSIGN(cdc_master[0],cva6_master)
  axi_cdc_intf #(
      .AXI_ADDR_WIDTH ( TbAxiAddrWidth     ),
      .AXI_DATA_WIDTH ( TbAxiDataWidth     ),
      .AXI_USER_WIDTH ( TbAxiUserWidth     ),
      .AXI_ID_WIDTH   ( TbAxiIdWidthSlaves ),
      .LOG_DEPTH      ( 3                  )
  ) i_cva6_cdc (
      .src_clk_i  ( clk           ),
      .src_rst_ni ( rst_n         ),
      .src        ( cdc_master[0] ),
      .dst_clk_i  ( clk           ),
      .dst_rst_ni ( rst_n         ),
      .dst        ( master[0]     )
  );

  `AXI_ASSIGN(cdc_master[1],cl_master)
  axi_cdc_intf #(
      .AXI_ADDR_WIDTH ( TbAxiAddrWidth     ),
      .AXI_DATA_WIDTH ( TbAxiDataWidth     ),
      .AXI_USER_WIDTH ( TbAxiUserWidth     ),
      .AXI_ID_WIDTH   ( TbAxiIdWidthSlaves ),
      .LOG_DEPTH      ( 3                  )
  ) i_cl_cdc (
      .src_clk_i  ( clk           ),
      .src_rst_ni ( rst_n         ),
      .src        ( cdc_master[1] ),
      .dst_clk_i  ( clk           ),
      .dst_rst_ni ( rst_n         ),
      .dst        ( master[1]     )
  );

  localparam axi_pkg::xbar_cfg_t xbar_cfg = '{
    NoSlvPorts:         TbNumMasters,
    NoMstPorts:         TbNumSlaves,
    MaxMstTrans:        8,
    MaxSlvTrans:        8,
    FallThrough:        1'b0,
    LatencyMode:        axi_pkg::NO_LATENCY,
    PipelineStages:     TbPipeline,
    AxiIdWidthSlvPorts: TbAxiIdWidthMasters,
    AxiIdUsedSlvPorts:  TbAxiIdUsed,
    UniqueIds:          TbUniqueIds,
    AxiAddrWidth:       TbAxiAddrWidth,
    AxiDataWidth:       TbAxiDataWidth,
    NoAddrRules:        TbNumSlaves
  };

 rule_t [TbNumSlaves-1:0] AddrMap;

 assign AddrMap[0] = '{
    idx:  0,
    start_addr: SPMBaseAddr,
    end_addr:   SPMBaseAddr + SPMLength
  };

  assign AddrMap[1] = '{
    idx:  1,
    start_addr: HyperBaseAddr,
    end_addr:   HyperBaseAddr + HyperLength
  };

  axi_xbar_intf #(
    .AXI_USER_WIDTH ( TbAxiUserWidth  ),
    .Cfg            ( xbar_cfg        ),
    .rule_t         ( rule_t          )
  ) i_xbar_dut (
    .clk_i                  ( clk     ),
    .rst_ni                 ( rst_n   ),
    .test_i                 ( 1'b0    ),
    .slv_ports              ( master  ),
    .mst_ports              ( slave   ),
    .addr_map_i             ( AddrMap ),
    .en_default_mst_port_i  ( '0      ),
    .default_mst_port_i     ( '0      )
  );


  if_spm #(
    .AXI_ADDR_WIDTH ( TbAxiAddrWidth     ),
    .AXI_DATA_WIDTH ( TbAxiDataWidth     ),
    .AXI_USER_WIDTH ( TbAxiUserWidth     ),
    .AXI_ID_WIDTH   ( TbAxiIdWidthSlaves ),
    .NUM_ROWS       ( 1024               ),
    .IDEAL_MEM      ( 1                  )
  ) i_if_spm (
    .clk_i                  ( clk      ),
    .rst_ni                 ( rst_n    ),
    .test_en_i              ( 1'b0     ),
    .axi_slave              ( slave[0] )
 );

  if_hyperbus #(
   .TbSetAssociativity ( TbSetAssociativity ),
   .TbNumLines         ( TbNumLines         ),
   .TbNumBlocks        ( TbNumBlocks        ),
   .AxiDataWidth    ( TbAxiDataWidth     ),
   .AxiAddrWidth    ( TbAxiAddrWidth     ),
   .AxiIdWidth      ( TbAxiIdWidthSlaves ),
   .AxiUserWidth    ( TbAxiUserWidth     ),
   .RegAw           ( 32                 ),
   .RegDw           ( 32                 ),
   .NumChips        ( 2                  ),
   .NumPhys         ( 2                  ),
   .IsClockODelayed ( 0                  )
  ) i_if_hyper (
     .clk_i         ( clk           ),
     .rst_ni        ( rst_n         ),
     .end_sim_i     ( 1'b0          ),

     .HyperBaseAddr ( HyperBaseAddr ),
     .HyperLength   ( HyperLength   ),

     .axi_slv_if    ( slave[1]      ),
     .reg_slv_if    ( reg_cfg_intf  )
  );


endmodule
