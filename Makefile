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
v_libraries:=obj dlib# slib
v_executables:=bin
v_shadow_in:=$(v_sources)
v_shadow_out:=$(v_deps)
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

link_dirs:=$(strip $(call unique,$(foreach V,$(v_libraries),\
	$($(V)_dir) $(if $(wildcard $($(V)_dir)),$(shell find $($(V)_dir) -type d),))))
inc_dirs:=$(strip $(call unique,$(foreach D,$(hpp_dir) $(tpp_dir),\
	$(D) $(if $(wildcard $(D)),$(shell find $(D) -type d),))))

all_dirs:=$(strip $(call unique,\
	$(foreach S_IN,$(v_shadow_in),\
		$(foreach D,$(shell find $($(S_IN)_dir) -type d),\
			$(foreach S_OUT,$(v_shadow_out),\
			$(D) $(D:$($(S_IN)_dir)%=$($(S_OUT)_dir)%))))\
	$(link_dirs) $(inc_dirs) $(bin_dir)))

# Collect sources
$(foreach V,$(v_sources) $(v_apps),$(eval \
	override $(V)_files+=$$(strip $$(filter %$($(V)_ext),\
	$$(shell find $($(V)_dir) -type f)))))

source_obj_files:=$(foreach f,\
	$(wildcard $(cpp_dir)**/*$(cpp_ext)),\
	$(obj_dir)$(basename $(notdir $(f)))$(obj_ext))
app_obj_files:=$(strip $(foreach c,$(foreach f,$(app_files),$(notdir $(f))),\
	$(obj_dir)$(c:%$(app_ext)=%$(obj_ext))))
# Combine source and app object files
obj_files:=$(source_obj_files) $(app_obj_files)

$(foreach U,source app,\
	$(foreach V,dep tdep,\
		$(eval $(U)_$(V)_files:=\
		$($(U)_obj_files:$(obj_dir)%$(obj_ext)=$($(V)_dir)%$($(V)_ext)))))

# Collect dep and tdep files
$(foreach U,dep tdep,$(eval $(U)_files:=\
	$(foreach V,source app,$($(V)_$(U)_files))))

# Add library paths to RPATH
$(foreach L,$(link_dirs),$(eval RPATH:=$(if $(RPATH),$(RPATH):$(L),$(L))))

# Add shared objects for each source
override dlib_files+=$(foreach f,$(source_obj_files),\
	$(f:$(obj_dir)%$(obj_ext)=$(dlib_dir)$(dlib_pre)%$(dlib_ext)))

# Add binaries for each app
override bin_files+=$(strip $(foreach F,$(filter %$(app_ext),\
	$(wildcard $(app_dir)*$(app_ext)) $(wildcard $(app_dir)**/*$(app_ext))),\
	$(F:$(app_dir)%$(app_ext)=$(bin_dir)%$(bin_ext))))

# Collect all output files
all_out_files:=$(dir_sentinel) \
	$(foreach V,v_deps v_libraries v_executables,\
	$(foreach U,$($(V)),$($(U)_files)))

# Collect all files (currently only output files)
all_files:=$(all_out_files)

# C++11, position-independent, with headers found in any of hpp_dirs
override CXXFLAGS+=-std=c++11 -fPIC $(foreach I,$(inc_dirs),-I$(I))

# Make-depend (mention only user headers; add phony target)
DEPFLAGS?=-MMD -MP -MF

# Convert tdep (raw dependency output) to dep (sorted and unique)
post_compile=@cp $(tdep_dir)$*$(tdep_ext) $(dep_dir)$*$(dep_ext);\
			 cat < $(tdep_dir)$*$(tdep_ext) \
			 | sort | uniq >> $(dep_dir)$*$(dep_ext)

# Add obj_dirs, dlib_dirs to make and linker paths
override LDFLAGS+=$(foreach L,$(link_dirs),-L$(L)) -Wl,-rpath,$(RPATH)

# Add dynamic libraries to linker inputs
override LDLIBS+=$(foreach F,$(foreach L,$(dlib_files),$(notdir $(L))),\
	$(F:$(dlib_pre)%$(dlib_ext)=-l%))

# Alias for make dependencies (tdeps)
MAKEDEP=$(CXX) -M $(CXXFLAGS) $(DEPFLAGS) $(tdep_dir)$*$(tdep_ext) $<

# Default target populates shadowed directory structures, then output files
default:$(dir_sentinel) $(all_dirs)\
	$(filter-out $(tdep_files),$(all_out_files)) |$(dir_sentinel)

# All targets (currently just default)
all:default

# Include tdeps unless missing
-include $(tdep_files)

# TODO unify source_obj_files and app_obj_files

# Build each obj and dep from the corresponding source
$(source_obj_files):$(obj_dir)%$(obj_ext):$(filter %,$(cpp_files))
	$(MAKEDEP)
	$(CXX) $(CXXFLAGS) -c -o $@ $<
$(app_obj_files):$(obj_dir)%$(obj_ext):$(filter %,$(app_files))
	$(MAKEDEP)
	$(CXX) $(CXXFLAGS) -c -o $@ $<

# TODO unify tpp_files and hpp_files

# Add dependency on TPP file if it exists
$(foreach T,$(tpp_files),$(eval \
	$(T:$(tpp_dir)%=$($(notdir %):%$(tpp_ext)=$(obj_dir)%$(obj_ext))) \
	: $(obj_dir)%$(obj_ext) : $(T)))
# Same for HPPs
$(foreach H,$(hpp_files),$(eval \
	$(H:$(hpp_dir)%$(hpp_ext)=$(obj_dir)%$(obj_ext)) \
	: $(obj_dir)%$(obj_ext) : $(H)))

# TODO Restrict added objs to just the real dependencies

# Build each dynamic library from the corresponding object files
$(dlib_files):$(dlib_dir)$(dlib_pre)%$(dlib_ext):$(obj_dir)%$(obj_ext)
	$(CXX) $(LDFLAGS) -shared -o $@ $^

# TODO Restrict added objs/dlibs to just the real dependencies

# Build each binary from the corresponding object file 
$(bin_files):$(bin_dir)%$(bin_ext):\
	$(obj_dir)%$(obj_ext) $(obj_files) $(dlib_files)
	$(CXX) $(LDFLAGS) -o $@ $< $(LDLIBS)

# A missing sentinel implies missing directories, but not vice versa
$(dir_sentinel): $(all_dirs); @touch $@
# Each missing directory is created
$(all_dirs): %:; $(if $(wildcard $@),,@mkdir $@)

# Echo the name and contents of a variable, function, etc.
info-%: echo-Info(%)\:\  .phony_explicit; $($(info $(call $*)):%=echo %;)

# Experimental; echo the arguments as written (TODO troubleshoot)
echo-%: .phony_explicit; @echo "$*"

# Print the name and value of a variable
print-%: .phony_explicit; $(info $* = "$($*)")

# Experimental; recursively search for files in the given directory
find-%: .phony_explicit; @echo "In \"$*\", found \"$(shell find $* -type f)\""

# TODO Targets or options for printing all, modified, deleted, new, etc.

# Print each variable defined since the beginning of the makefile
print_vars: $(foreach V,$(filter-out $(old_vars) old_vars,\
	$(.VARIABLES)),print-$(V)) .phony_explicit

# Procedurally add directories of input files to their discovery directive
$(foreach V,$(v_sources) $(v_apps),$(eval vpath %$($(S)_ext) $($(S)_dirs)))

# Remove all output files (not directories) including sentinel
clean: .phony_explicit; @$(RM) $(all_out_files)

# Specify targets which add behavior but are not expected as outputs
# .phony_explicit adds this property to a target not listed here
.PHONY: clean all print_vars print-% echo-% .phony_explicit
