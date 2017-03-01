readme_dir?=
readme_name?=README
readme_ext?=.md
readme_file?=$(readme_dir)$(readme_name)$(readme_ext)

doxygen?=doxygen
doxymake?=$(doxygen) -s -g
doc_dir?=doc/
doc_name?=Doxyfile
doc_ext?=
doc_file?=$(doc_dir)$(doc_name)$(doc_ext)
doc_sentinel?=$(doc_dir).$(doc_name)$(sentinel_ext)
doc_files?=$(doc_sentinel) $(doc_file)

DOXY_OUTPUT_DIRECTORY?=$(doc_dir)
DOXY_STRIP_FROM_PATH?=../
DOXY_QT_AUTOBRIEF?=YES
DOXY_BUILTIN_STL_SUPPORT?=YES
DOXY_EXTRACT_ALL?=YES
DOXY_EXTRACT_PRIVATE?=YES
DOXY_EXTRACT_PACKAGE?=YES
DOXY_SHOW_INCLUDE_FILES?=YES
DOXY_RECURSIVE?=YES
DOXY_USE_MDFILE_AS_MAINPAGE?=$(readme_file)
DOXY_GENERATE_MAN?=YES
DOXY_CALL_GRAPH?=YES
DOXY_DOT_TRANSPARENT?=YES

# To define <X> in your Doxyfile, define DOXY_<X> in your makefile
# For example, DOXY_PROJECT_NAME?=my_project_name
V_DOXY_ALL=$(filter DOXY_%,$(.VARIABLES))
V_DOXY_ALL_SUFFIXES=$(V_DOXY_ALL:V_DOXY_%=%)

doc: default $(doc_sentinel) .phony_explicit

$(doc_sentinel): $(doc_file) $(filter-out $(doc_files),$(all_out_files))
	$(doxygen) $(doc_file)
	@touch $@

$(doc_file):
	@$(doxymake) $(doc_file) $(hpp_files)
	@$(foreach V,$(V_DOXY_ALL_SUFFIXES),\
		echo "$(V:DOXY_%=%)=$($(V))" >> $(doc_dir)$(doc_name)$(doc_ext);)
