module axis_header_packer #(
    parameter int DATA_WIDTH   = 8,
    parameter int HEADER_WORDS = 1
) (
    input logic clk,
    input logic rst,

    axis_if.slave  s_axis,
    axis_if.master m_axis,

    input logic [HEADER_WORDS*DATA_WIDTH-1:0] header
);

  localparam int HEADER_INDEX_WIDTH = (HEADER_WORDS <= 1) ? 1 : $clog2(HEADER_WORDS);
  localparam logic [HEADER_INDEX_WIDTH-1:0] LAST_HEADER_INDEX =
      HEADER_INDEX_WIDTH'(HEADER_WORDS - 1);

  typedef enum logic [1:0] {
    ST_WAIT_PAYLOAD,
    ST_HEADER,
    ST_PAYLOAD
  } state_t;

  state_t state;
  logic [HEADER_INDEX_WIDTH-1:0] header_index;
  logic [HEADER_WORDS*DATA_WIDTH-1:0] header_reg;
  logic header_only;

  wire output_fire = m_axis.tvalid && m_axis.tready;
  wire input_fire = s_axis.tvalid && s_axis.tready;
  wire last_header_word = header_index == LAST_HEADER_INDEX;

  assign s_axis.tready = (state == ST_PAYLOAD) ? m_axis.tready :
                         (state == ST_HEADER && header_only && last_header_word) ?
                         m_axis.tready : 1'b0;

  assign m_axis.tvalid = (state == ST_HEADER) ? 1'b1 :
                         (state == ST_PAYLOAD) ? s_axis.tvalid : 1'b0;
  assign m_axis.tdata = (state == ST_HEADER) ?
      header_reg[HEADER_WORDS*DATA_WIDTH-1-header_index*DATA_WIDTH-:DATA_WIDTH] :
      s_axis.tdata;
  assign m_axis.tlast = (state == ST_HEADER && header_only && last_header_word) ||
                        (state == ST_PAYLOAD && s_axis.tlast);

  always_ff @(posedge clk) begin
    if (rst) begin
      state <= ST_WAIT_PAYLOAD;
      header_index <= '0;
      header_reg <= '0;
      header_only <= 1'b0;
    end else begin
      unique case (state)
        ST_WAIT_PAYLOAD: begin
          if (s_axis.tvalid) begin
            header_reg <= header;
            header_only <= header == '0;
            header_index <= '0;
            state <= ST_HEADER;
          end
        end

        ST_HEADER: begin
          if (output_fire) begin
            if (last_header_word) begin
              header_index <= '0;
              state <= header_only ? ST_WAIT_PAYLOAD : ST_PAYLOAD;
            end else begin
              header_index <= header_index + 1'b1;
            end
          end
        end

        default: begin
          if (input_fire && s_axis.tlast) begin
            state <= ST_WAIT_PAYLOAD;
          end
        end
      endcase
    end
  end

endmodule
