SIM ?= modelsim
TOPLEVEL_LANG ?= verilog

PROJECT_DIR := $(abspath $(CURDIR)/..)
SIM_DIR := $(abspath $(CURDIR))
XPM_LIB ?= /opt/ModelSim/xilinx_simlib/xpm
export MPLCONFIGDIR ?= /tmp/matplotlib-$(USER)
export PYTHONPATH := $(PROJECT_DIR):$(SIM_DIR)/lib:$(SIM_DIR)/tests:$(PYTHONPATH)

AXIS_HEADER_UNPACKER_SOURCES := \
	$(PROJECT_DIR)/src/axis/axis_if.sv \
	$(PROJECT_DIR)/src/axis/axis_header_unpacker.sv \
	$(PROJECT_DIR)/sim/tb/axis_header_unpacker_tb.sv

AXIS_HEADER_PACKER_SOURCES := \
	$(PROJECT_DIR)/src/axis/axis_if.sv \
	$(PROJECT_DIR)/src/axis/axis_header_packer.sv \
	$(PROJECT_DIR)/sim/tb/axis_header_packer_tb.sv

AXIS_LENGTH_UNPACKER_SOURCES := \
	$(PROJECT_DIR)/src/axis/axis_if.sv \
	$(PROJECT_DIR)/src/axis/axis_length_unpacker.sv \
	$(PROJECT_DIR)/sim/tb/axis_length_unpacker_tb.sv

DESERIALIZER_VHDL_SOURCES := \
	$(PROJECT_DIR)/src/pkg/types_pkg.vhd \
	$(PROJECT_DIR)/src/flow/xpm/xpm_axis_fifo.vhd \
	$(PROJECT_DIR)/src/flow/deserializer.vhd \
	$(PROJECT_DIR)/src/flow/deserializer_flat.vhd

DESERIALIZER_SOURCES := \
	/opt/Xilinx/2025.1/data/verilog/src/glbl.v \
	$(PROJECT_DIR)/src/axis/axis_if.sv \
	$(PROJECT_DIR)/sim/tb/deserializer_flat_tb.sv

SERIALIZER_VHDL_SOURCES := \
	$(PROJECT_DIR)/src/pkg/types_pkg.vhd \
	$(PROJECT_DIR)/src/pkg/func_pkg.vhd \
	$(PROJECT_DIR)/src/flow/xpm/xpm_axis_fifo.vhd \
	$(PROJECT_DIR)/src/flow/serializer/serializer.vhd \
	$(PROJECT_DIR)/src/flow/serializer/serializer_flat.vhd

SERIALIZER_SOURCES := \
	/opt/Xilinx/2025.1/data/verilog/src/glbl.v \
	$(PROJECT_DIR)/src/axis/axis_if.sv \
	$(PROJECT_DIR)/sim/tb/serializer_flat_tb.sv

ADDER_TREE_VHDL_SOURCES := \
	$(PROJECT_DIR)/src/pkg/types_pkg.vhd \
	$(PROJECT_DIR)/src/pkg/func_pkg.vhd \
	$(PROJECT_DIR)/src/math/adder_tree/adder_pair.vhd \
	$(PROJECT_DIR)/src/math/adder_tree/adder_tree.vhd \
	$(PROJECT_DIR)/src/math/adder_tree/adder_tree_complex.vhd

ADDER_TREE_SOURCES := \
	$(PROJECT_DIR)/sim/tb/adder_tree_complex_tb.sv

INSTANT_POWER_VHDL_SOURCES := \
	$(PROJECT_DIR)/src/pkg/types_pkg.vhd \
	$(PROJECT_DIR)/src/pkg/func_pkg.vhd \
	$(PROJECT_DIR)/src/math/instant_power/instant_power.vhd \
	$(PROJECT_DIR)/src/math/instant_power/instant_power_flat.vhd

INSTANT_POWER_SOURCES := \
	$(PROJECT_DIR)/src/axis/axis_if.sv \
	$(PROJECT_DIR)/sim/tb/instant_power_flat_tb.sv

ADDER_TREE_CH_NUMS := 4 5 6 9 13 15 16
ADDER_TREE_TESTS := $(addprefix adder-tree-,$(ADDER_TREE_CH_NUMS))

VERILOG_SOURCES ?= $(AXIS_HEADER_UNPACKER_SOURCES)
COCOTB_TOPLEVEL ?= axis_header_unpacker_tb
COCOTB_TEST_MODULES ?= test_axis_header_unpacker

.PHONY: adder-tree $(ADDER_TREE_TESTS) instant-power unpacker length-unpacker packer deserializer serializer test

adder-tree: $(ADDER_TREE_TESTS)

$(ADDER_TREE_TESTS):
	$(MAKE) clean
	$(MAKE) sim COCOTB_TOPLEVEL=adder_tree_complex_tb COCOTB_TEST_MODULES=test_adder_tree_complex VERILOG_SOURCES="$(ADDER_TREE_SOURCES)" VHDL_SOURCES="$(ADDER_TREE_VHDL_SOURCES)" VCOM_ARGS="-2008" SIM_ARGS='-do {encoding system utf-8} -gCH_NUM=$(patsubst adder-tree-%,%,$@)'

instant-power:
	$(MAKE) clean
	$(MAKE) sim COCOTB_TOPLEVEL=instant_power_flat_tb COCOTB_TEST_MODULES=test_instant_power VERILOG_SOURCES="$(INSTANT_POWER_SOURCES)" VHDL_SOURCES="$(INSTANT_POWER_VHDL_SOURCES)" VCOM_ARGS="-2008" SIM_ARGS='-do {encoding system utf-8}'

unpacker:
	$(MAKE) clean
	$(MAKE) sim COCOTB_TOPLEVEL=axis_header_unpacker_tb COCOTB_TEST_MODULES=test_axis_header_unpacker VERILOG_SOURCES="$(AXIS_HEADER_UNPACKER_SOURCES)"

length-unpacker:
	$(MAKE) clean
	$(MAKE) sim COCOTB_TOPLEVEL=axis_length_unpacker_tb COCOTB_TEST_MODULES=test_axis_length_unpacker VERILOG_SOURCES="$(AXIS_LENGTH_UNPACKER_SOURCES)"

packer:
	$(MAKE) clean
	$(MAKE) sim COCOTB_TOPLEVEL=axis_header_packer_tb COCOTB_TEST_MODULES=test_axis_header_packer VERILOG_SOURCES="$(AXIS_HEADER_PACKER_SOURCES)"

deserializer:
	vmap -c
	vmap xpm $(XPM_LIB)
	$(MAKE) clean
	$(MAKE) sim COCOTB_TOPLEVEL=deserializer_flat_tb COCOTB_TEST_MODULES=test_deserializer_flat VERILOG_SOURCES="$(DESERIALIZER_SOURCES)" VHDL_SOURCES="$(DESERIALIZER_VHDL_SOURCES)" VCOM_ARGS="-2008" SIM_ARGS="-L xpm glbl"

serializer:
	vmap -c
	vmap xpm $(XPM_LIB)
	$(MAKE) clean
	$(MAKE) sim COCOTB_TOPLEVEL=serializer_flat_tb COCOTB_TEST_MODULES=test_serializer_flat VERILOG_SOURCES="$(SERIALIZER_SOURCES)" VHDL_SOURCES="$(SERIALIZER_VHDL_SOURCES)" VCOM_ARGS="-2008" SIM_ARGS="-L xpm glbl"

test: adder-tree instant-power unpacker length-unpacker packer deserializer serializer

include $(shell cocotb-config --makefiles)/Makefile.sim
