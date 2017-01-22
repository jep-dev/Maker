complete_name?=
complete_ext?=.clang_complete
complete_file?=$(complete_name)$(complete_ext)

complete: $(complete_file) .phony_explicit

$(complete_file):
	@echo $(foreach V,$(CXXFLAGS),$(V: %=%)\\n) > $@
