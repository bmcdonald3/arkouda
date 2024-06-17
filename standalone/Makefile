ARKOUDA_PROJECT_DIR := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))

ARKOUDA_SOURCE_DIR := $(ARKOUDA_PROJECT_DIR)

ARROW_FILE_NAME += $(ARKOUDA_SOURCE_DIR)/ArrowFunctions
ARROW_STANDALONE_NAME += $(ARKOUDA_SOURCE_DIR)/standalone.chpl
ARROW_CPP += $(ARROW_FILE_NAME).cpp
ARROW_H += $(ARROW_FILE_NAME).h
ARROW_O += $(ARROW_FILE_NAME).o

CHPL_CXX = $(shell $(CHPL_HOME)/util/config/compileline --compile-c++ 2>/dev/null)
ifeq ($(CHPL_CXX),)
CHPL_CXX=$(CXX)
endif

define add-path
ifneq ("$(wildcard $(1)/lib64)","")
  INCLUDE_FLAGS += -I$(1)/include -L$(1)/lib64
  CHPL_FLAGS    += -I$(1)/include -L$(1)/lib64 --ldflags="-Wl,-rpath,$(1)/lib64"
endif
INCLUDE_FLAGS += -I$(1)/include -L$(1)/lib
CHPL_FLAGS    += -I$(1)/include -L$(1)/lib --ldflags="-Wl,-rpath,$(1)/lib"
endef

ifdef ARKOUDA_ARROW_PATH
$(eval $(call add-path,$(ARKOUDA_ARROW_PATH)))
endif

.PHONY: compile-arrow-cpp
compile-arrow-cpp:
	#$(CHPL_CXX) -O3 -std=c++17 -c $(ARROW_CPP) -o $(ARROW_O) $(INCLUDE_FLAGS)
	chpl standalone.chpl --fast $(CHPL_FLAGS) -larrow -lparquet

