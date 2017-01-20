readme_dir?=
readme_ext?=.md
readme_name?=README

doxygen?=doxygen
doxymake?=$(doxygen) -s -g
doc_dir?=doc/
doc_name?=Doxyfile
doc_ext?=
doc_file?=$(doc_dir)$(doc_name)$(doc_ext)
#doc_pre_file?=$(doc_dir).pre$(sentinel_ext)
#doc_post_file?=$(doc_dir).post$(sentinel_ext)
#doc_files?=$(doc_pre_file) $(doc_file) $(doc_post_file)
#doc_files?=$(foreach F,_name _pre_name _post_name,$(doc_dir)$(doc_$(F)))
doc_files?=$(doc_file)

# To define <X> in your Doxyfile, define DOXY_<X> in your makefile
# For example, DOXY_PROJECT_NAME?=my_project_name
V_DOXY_ALL=$(filter DOXY_%,$(.VARIABLES))
V_DOXY_ALL_SUFFIXES=$(V_DOXY_ALL:V_DOXY_%=%)

doc: $(doc_file) .phony_explicit
	$(doxygen) $(doc_file)

$(doc_file):
	@$(doxymake) $(doc_file) $(hpp_files)
	@$(foreach V,$(V_DOXY_ALL_SUFFIXES),\
		echo "$(V:DOXY_%=%)=$($(V))" >> $(doc_dir)$(doc_name)$(doc_ext);)
