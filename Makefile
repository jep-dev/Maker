# Copy of variable names s.t. new variables can be distinguished
old_vars:=$(.VARIABLES)

# Formatting variables to avoid confusion later
space=
space:=$(space) $(space)
colon:=:

# Variable prefixes by category
v_sources:=hpp tpp cpp
v_apps:=app
v_deps:=tdep
v_libraries:=obj dlib#slib
v_executables:=bin
v_all_in:=$(foreach V,sources apps,$(v_$(V)))
v_all_out:=$(foreach V,deps libraries executables,$(v_$(V)))
v_all:=$(foreach V,in out,$(v_all_$(V)))

# Input directories
hpp_dir?=include/
tpp_dir?=$(hpp_dir)
cpp_dir?=src/
app_dir?=app/
dep_dir?=dep/
tdep_dir?=$(dep_dir)
# Library directories
lib_dir?=lib/
dlib_dir?=$(lib_dir)
obj_dir?=$(lib_dir)
# Binary directory
bin_dir?=bin/
dir_sentinel?=.dirs$(sentinel_ext)

# File prefixes
lib_pre?=lib
# slib_pre?=$(lib_pre)
dlib_pre?=$(lib_pre)

# File suffixes
hpp_ext?=.hpp
tpp_ext?=.tpp
cpp_ext?=.cpp
app_ext?=$(cpp_ext)
dep_ext?=.d
tdep_ext?=.Td
obj_ext?=.o
# slib_ext?=.a
dlib_ext?=.so
sentinel_ext?=.sen


define unique =
$(foreach W,$1,\
	$(eval head=$(W))\
	$(eval override result+=$(filter-out $(result),$(head))))\
	$(result)
endef

# Search for subdirectories
$(foreach V,$(v_all),\
	$(eval override $(V)_dirs+=$(if $(wildcard $($(V)_dir)),\
	$$(shell find $($(V)_dir) -type d),)))
$(foreach V,$(v_all_out),\
	$(foreach U,cpp app,\
	$(eval override $(V)_dirs+=$($(U)_dirs:$($(U)_dir)%=$($(V)_dir)%))))
all_dirs:=$(foreach V,hpp tpp cpp app dep obj dlib bin,\
	$($(V)_dirs) $($(V)_dir))
$(eval all_dirs:=$(call unique,$(all_dirs)))

# Search for files
source_obj_files:=$(strip $(foreach F,\
	$(wildcard $(cpp_dir)**/*$(cpp_ext)),\
	$(F:$(cpp_dir)%$(cpp_ext)=$(obj_dir)%$(obj_ext))))
app_obj_files:=$(strip $(foreach F,\
	$(foreach D,$(app_dirs),$(wildcard $(D)*$(app_ext))),\
	$(F:$(app_dir)%$(app_ext)=$(obj_dir)%$(obj_ext))))

obj_files:=$(source_obj_files) $(app_obj_files)

$(foreach U,source app,\
	$(eval $(U)_dep_files:=$(foreach O,$($(U)_obj_files),\
	$(O:$(obj_dir)%$(obj_ext)=$(dep_dir)%$(dep_ext))))\
	$(eval $(U)_tdep_files:=$(foreach D,$($(U)_dep_files),\
	$(D:$(dep_dir)%$(dep_ext)=$(tdep_dir)%$(tdep_ext)))))

$(foreach V,$(v_sources) $(v_apps),$(eval \
	override $(V)_files+=$$(strip $$(filter %$($(V)_ext),\
	$$(shell find $($(V)_dir) -type f)))))
$(foreach U,dep tdep,$(eval \
	$(U)_files:=$(foreach V,source app,$($(V)_$(U)_files))))

$(foreach L,$(v_libraries),\
	$(foreach D,$($(L)_dirs),\
	$(eval RPATH:=$(if $(RPATH),$(RPATH):$(D),$(D)))))
override dlib_files+=$(strip $(foreach F,$(foreach V,$(cpp_files),\
	$(V:$(cpp_dir)%$(cpp_ext)=$(dlib_dir)%$(dlib_ext))),\
	$(dir $(F))$(dlib_pre)$(notdir $(F))))
override bin_files+=$(strip $(foreach F,$(filter %$(app_ext),\
	$(wildcard $(app_dir)*$(app_ext)) $(wildcard $(app_dir)**/*$(app_ext))),\
	$(F:$(app_dir)%$(app_ext)=$(bin_dir)%$(bin_ext))))

all_out_files:=$(dir_sentinel) \
	$(foreach V,v_deps v_libraries v_executables,\
	$(foreach U,$($(V)),$($(U)_files)))
all_files:=$(all_out_files)

override CXXFLAGS+=-std=c++11 -fPIC $(foreach I,$(hpp_dirs),-I$(I))
DEPFLAGS?=-MMD -MP -MF
post_compile=@cp $(tdep_dir)$*$(tdep_ext) $(dep_dir)$*$(dep_ext);\
			 cat < $(tdep_dir)$*$(tdep_ext) \
			 | sort | uniq >> $(dep_dir)$*$(dep_ext)
override LDFLAGS+=$(foreach L,$(obj_dirs) $(dlib_dirs),-L$(L))\
	-Wl,-rpath,$(RPATH)
override LDLIBS+=$(foreach F,$(foreach L,$(dlib_files),$(notdir $(L))),\
	$(F:$(dlib_pre)%$(dlib_ext)=-l%))

MAKEDEP=$(CXX) -M $(CXXFLAGS) $(DEPFLAGS) $(tdep_dir)$*$(tdep_ext) $<

default:$(dir_sentinel) $(all_dirs)\
	$(filter-out $(tdep_files),$(all_out_files)) |$(dir_sentinel)
all:default
-include $(tdep_files)

$(source_obj_files):$(obj_dir)%$(obj_ext):$(cpp_dir)%$(cpp_ext)
	$(MAKEDEP)
	$(CXX) $(CXXFLAGS) -c -o $@ $<
$(app_obj_files):$(obj_dir)%$(obj_ext):$(app_dir)%$(app_ext)
	$(MAKEDEP)
	$(CXX) $(CXXFLAGS) -c -o $@ $<

# Add dependency on TPP file if it exists
$(foreach T,$(tpp_files),$(eval \
	$(T:$(tpp_dir)%$(tpp_ext)=$(obj_dir)%$(obj_ext)) \
	: $(obj_dir)%$(obj_ext) : $(tpp_dir)%$(tpp_ext)))
# Same for HPPs
$(foreach H,$(hpp_files),$(eval \
	$(H:$(hpp_dir)%$(hpp_ext)=$(obj_dir)%$(obj_ext)) \
	: $(obj_dir)%$(obj_ext) : $(hpp_dir)%$(hpp_ext)))

$(dlib_files):$(dlib_dir)%$(dlib_ext): $(obj_files)
	$(CXX) $(LDFLAGS) -shared -o $@ $^
$(bin_files):$(bin_dir)%$(bin_ext):\
	$(obj_dir)%$(obj_ext) $(obj_files) $(dlib_files)
	$(CXX) $(LDFLAGS) -o $@ $< $(LDLIBS)

$(dir_sentinel): $(all_dirs)
	@touch $@
$(all_dirs): %:; $(if $(wildcard $@),,@mkdir $@)

info-%: echo-Info(%)\:\  .phony_explicit
	$($(info $(call $*)):%=echo %;)
echo-%: .phony_explicit
	@echo "$*"
print-%: .phony_explicit
	$(info $* = $($*))

find-%: .phony_explicit
	@echo "In \"$*\", found \"$(shell find $* -type f)\""

print_vars: $(foreach V,\
	$(filter-out $(old_vars) old_vars,$(.VARIABLES)),print-$(V)) .phony_explicit

$(foreach V,$(v_sources) $(v_apps),$(eval vpath %$($(S)_ext) $($(S)_dirs)))

clean: .phony_explicit; @$(RM) $(all_out_files)
.PHONY: clean all print_vars print-% echo-% .phony_explicit
