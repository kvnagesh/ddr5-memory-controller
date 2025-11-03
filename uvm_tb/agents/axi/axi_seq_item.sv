// axi_seq_item.sv - Sequence item for AXI transactions
class axi_seq_item extends uvm_sequence_item;
  `uvm_object_utils(axi_seq_item)

  rand bit [7:0]    id;
  rand bit [31:0]   addr;
  rand bit [511:0]  data[];
  rand bit          is_read;
  rand bit [7:0]    len; // beats-1
  rand bit [2:0]    size;
  rand bit [1:0]    burst;

  constraint c_len { len inside {[0:15]}; }
  constraint c_burst { burst inside {2'b01}; } // INCR

  function new(string name = "axi_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("id=%0d addr=0x%08h is_read=%0b len=%0d", id, addr, is_read, len);
  endfunction
endclass
