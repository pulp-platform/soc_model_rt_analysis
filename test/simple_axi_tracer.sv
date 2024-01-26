// Copyright (c) 2024-2028 ETH Zurich, University of Bologna
//
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Authors:
// - Luca Valente <luca.valente@unibo.it>

package wce_trace;

  import axi_pkg::*;
  import axi_test::*;

  /// AXI port tracer.
  class axi_tracer #(
    /// AXI4+ATOP ID width
    parameter int unsigned IW = 0,
    /// AXI4+ATOP address width
    parameter int unsigned AW = 0,
    /// AXI4+ATOP data width
    parameter int unsigned DW = 0,
    /// AXI4+ATOP user width
    parameter int unsigned UW = 0,
    /// Stimuli test time
    parameter time         TT = 0ns
  );

    typedef logic [IW-1:0] ax_id_t;
    typedef axi_pkg::len_t ax_len_t;

    typedef struct {
       ax_id_t ax_id;
       ax_len_t ax_len;
       int unsigned num_cycle_acc;
       int unsigned num_cycle_com;
       real         chan_util;
    } ax_trace_t;

    ax_trace_t ax_transactions[$];
    ax_id_t    aw_waiting_id[$];
    ax_id_t    ar_waiting_id[$];

    int unsigned   tracer_id;
    virtual AXI_BUS_DV #(
      .AXI_ADDR_WIDTH ( AW ),
      .AXI_DATA_WIDTH ( DW ),
      .AXI_ID_WIDTH   ( IW ),
      .AXI_USER_WIDTH ( UW )
    ) bus_axi;

    function new(
                  int unsigned tracer_id,
                  virtual      AXI_BUS_DV #(
                               .AXI_ADDR_WIDTH ( AW ),
                               .AXI_DATA_WIDTH ( DW ),
                               .AXI_ID_WIDTH ( IW ),
                               .AXI_USER_WIDTH ( UW )
                               ) bus_axi
    );
       this.bus_axi = bus_axi;
       this.tracer_id = tracer_id;
    endfunction

    // when start the testing
    task cycle_start;
      #TT;
    endtask

    // when is cycle finished
    task cycle_end;
      @(posedge this.bus_axi.clk_i);
    endtask

    task trace_writes_chan();
       int fd;
       string        filename;
       time          when_issued;

       ax_trace_t local_trace;
       ax_id_t    id_buffer;
       logic      oldest;
       logic      inflight;

       oldest = 0;
       inflight = 0;

       if(this.bus_axi.aw_valid) begin
          if(aw_waiting_id.size()==0) begin
             // There are no inflight transactions, enqueue the first
             oldest=1;
             aw_waiting_id.push_front(this.bus_axi.aw_id);
             id_buffer = this.bus_axi.aw_id;
          end else begin
             id_buffer = aw_waiting_id.pop_front();
             if(id_buffer==this.bus_axi.aw_id) begin
                // This process is not the oldest
                oldest = 0;
                aw_waiting_id.push_front(id_buffer);
             end else begin
                oldest = 1;
                aw_waiting_id.push_front(id_buffer);
                aw_waiting_id.push_front(this.bus_axi.aw_id);
                id_buffer = this.bus_axi.aw_id;
             end
          end // else: !if(aw_waiting_id.size()==0)

          if(oldest) begin

             when_issued=$time;
             local_trace.num_cycle_acc = 0;
             local_trace.num_cycle_com = 0;
             local_trace.ax_id = this.bus_axi.aw_id;
             local_trace.ax_len = this.bus_axi.aw_len;

             while(~this.bus_axi.aw_ready) begin
                local_trace.num_cycle_acc++;
                cycle_end();
             end


             while( ~(this.bus_axi.b_valid && this.bus_axi.b_ready && (this.bus_axi.b_id == local_trace.ax_id) ) ) begin
                local_trace.num_cycle_com++;
                cycle_end();
             end

             if(local_trace.num_cycle_acc==0 && local_trace.num_cycle_com==0)
               local_trace.chan_util = real'( local_trace.ax_len + 1 );
             else
               local_trace.chan_util = real'( local_trace.ax_len + 1 ) / ( real'(local_trace.num_cycle_acc) + real'(local_trace.num_cycle_com) + 2 );

             ax_transactions.push_back(local_trace);
             for(int j = aw_waiting_id.size(); j>0 ; j--) begin
                if(aw_waiting_id[j-1]==id_buffer) begin
                   aw_waiting_id.delete(j-1);
                   break;
                end
             end
             $sformat(filename,"traces_rw.dat");
             fd = $fopen(filename, "a");
             $fwrite(fd,"%t, %t, %d,W, %b, %d, %d, %d, %f\n", when_issued, $time, tracer_id, local_trace.ax_id, local_trace.num_cycle_acc, local_trace.ax_len, local_trace.num_cycle_com, local_trace.chan_util);
             $fclose(fd);

          end

       end

    endtask

    task trace_reads_chan();
       int fd;
       string        filename;
       time          when_issued;

       ax_trace_t local_trace;
       ax_id_t    id_buffer;
       logic      oldest;

       local_trace.num_cycle_acc = 0;
       local_trace.num_cycle_com = 0;
       local_trace.ax_id = this.bus_axi.ar_id;
       local_trace.ax_len = this.bus_axi.ar_len;

       if(this.bus_axi.ar_valid) begin
          if(ar_waiting_id.size()==0) begin
             // There are no inflight transactions, enqueue the first
             oldest=1;
             ar_waiting_id.push_front(this.bus_axi.ar_id);
             id_buffer = this.bus_axi.ar_id;
          end else begin
             id_buffer = ar_waiting_id.pop_front();
             if(id_buffer==this.bus_axi.ar_id) begin
                // This process is not the oldest
                oldest = 0;
                ar_waiting_id.push_front(id_buffer);
             end else begin
                oldest = 1;
                ar_waiting_id.push_front(id_buffer);
                ar_waiting_id.push_front(this.bus_axi.ar_id);
                id_buffer = this.bus_axi.ar_id;
             end
          end

          if(oldest) begin
             when_issued=$time;
             while(~this.bus_axi.ar_ready) begin
                local_trace.num_cycle_acc++;
                cycle_end();
             end

             while( ~(this.bus_axi.r_valid && this.bus_axi.r_ready && (this.bus_axi.r_id == local_trace.ax_id) && this.bus_axi.r_last ) ) begin
                local_trace.num_cycle_com++;
                cycle_end();
             end

             if(local_trace.num_cycle_acc==0 && local_trace.num_cycle_com==0)
               local_trace.chan_util = real'( local_trace.ax_len + 1 );
             else
               local_trace.chan_util = real'( local_trace.ax_len + 1 ) / ( real'(local_trace.num_cycle_acc) + real'(local_trace.num_cycle_com)  + 2 );

             ax_transactions.push_back(local_trace);
             for(int j = ar_waiting_id.size(); j>0 ; j--) begin
                if(ar_waiting_id[j-1]==id_buffer) begin
                   ar_waiting_id.delete(j-1);
                   break;
                end
             end
             $sformat(filename,"traces_rw.dat");
             fd = $fopen(filename, "a");
             $fwrite(fd,"%t, %t, %d,R, %b, %d, %d, %d, %f\n", when_issued, $time, tracer_id, local_trace.ax_id, local_trace.num_cycle_acc, local_trace.ax_len, local_trace.num_cycle_com, local_trace.chan_util);
             $fclose(fd);

          end

       end

    endtask

     task trace();

        int fd;
        string        filename;

        begin
             $sformat(filename,"traces_rw.dat");
             fd = $fopen(filename, "w");
             $fwrite(fd,"t_val,t_end,ID,W/R,AX_ID,ACC,LEN,CHAN,UTIL\n",);
             $fclose(fd);
        end

        do begin
           cycle_start();
           Trace: fork
              proc_aw: begin
                 trace_writes_chan();
              end
              proc_ar: begin
                 trace_reads_chan();
              end
           join_none
           cycle_end();
        end while(1'b1); // do begin

     endtask

  endclass


endpackage
