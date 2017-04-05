# Maker

#### One makefile to rule them all

#### What Maker is

Maker is a heavily-parametrized, extensible  makefile intended to manage most
or all of the boilerplate code from a typical C/C++ makefile. It should support
parallel builds without issue (see Usage).

#### What Maker is not

Maker is neither a recursive makefile nor a makefile generator; it only needs
to be included from your makefile with minimal configuration.

#### Example

```make
# Base makefile (required)
include ../Maker/Makefile
# Extension: generates .clang_complete
include ../Maker/clang_complete.mk
# Extension: generates doc/Doxyfile, runs doxygen from the result
include ../Maker/Doxygen.mk

# Add compiler and linker flags for SDL2 + ttf
override CXXFLAGS+=-I/usr/include/SDL2/
override LDLIBS+=-lSDL2_ttf -lSDL2 -ldl

# Add Doxygen files as dependencies for 'all' and 'clean'
override all_out_files+=$(doc_files)
all: doc
```

#### Usage

```
# Default target (missing dirs + sentinel, objects, deps, libs, binaries)
make
# Default target with 4 'simultaneous' (concurrent) jobs
make -j4
# Remove each target in all_out_files
make clean
# Generate doc/Doxyfile and documentation (requires Doxygen.mk)
make doc
# Generate .clang_complete
make complete
# Print the name and value of one or more variables
make print-CXXFLAGS print-LD{LIBS,FLAGS}
# Print info for one or more variables or defines
make info-EDITOR
# If neither of these work, try:
make --print-data-base | grep ...
```
