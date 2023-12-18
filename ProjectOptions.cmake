include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(fuzz_cpp_pipeline_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(fuzz_cpp_pipeline_setup_options)
  option(fuzz_cpp_pipeline_ENABLE_HARDENING "Enable hardening" ON)
  option(fuzz_cpp_pipeline_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    fuzz_cpp_pipeline_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    fuzz_cpp_pipeline_ENABLE_HARDENING
    OFF)

  fuzz_cpp_pipeline_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR fuzz_cpp_pipeline_PACKAGING_MAINTAINER_MODE)
    option(fuzz_cpp_pipeline_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(fuzz_cpp_pipeline_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(fuzz_cpp_pipeline_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(fuzz_cpp_pipeline_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(fuzz_cpp_pipeline_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(fuzz_cpp_pipeline_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(fuzz_cpp_pipeline_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(fuzz_cpp_pipeline_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(fuzz_cpp_pipeline_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(fuzz_cpp_pipeline_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(fuzz_cpp_pipeline_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(fuzz_cpp_pipeline_ENABLE_PCH "Enable precompiled headers" OFF)
    option(fuzz_cpp_pipeline_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(fuzz_cpp_pipeline_ENABLE_IPO "Enable IPO/LTO" ON)
    option(fuzz_cpp_pipeline_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(fuzz_cpp_pipeline_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(fuzz_cpp_pipeline_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(fuzz_cpp_pipeline_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(fuzz_cpp_pipeline_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(fuzz_cpp_pipeline_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(fuzz_cpp_pipeline_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(fuzz_cpp_pipeline_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(fuzz_cpp_pipeline_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(fuzz_cpp_pipeline_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(fuzz_cpp_pipeline_ENABLE_PCH "Enable precompiled headers" OFF)
    option(fuzz_cpp_pipeline_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      fuzz_cpp_pipeline_ENABLE_IPO
      fuzz_cpp_pipeline_WARNINGS_AS_ERRORS
      fuzz_cpp_pipeline_ENABLE_USER_LINKER
      fuzz_cpp_pipeline_ENABLE_SANITIZER_ADDRESS
      fuzz_cpp_pipeline_ENABLE_SANITIZER_LEAK
      fuzz_cpp_pipeline_ENABLE_SANITIZER_UNDEFINED
      fuzz_cpp_pipeline_ENABLE_SANITIZER_THREAD
      fuzz_cpp_pipeline_ENABLE_SANITIZER_MEMORY
      fuzz_cpp_pipeline_ENABLE_UNITY_BUILD
      fuzz_cpp_pipeline_ENABLE_CLANG_TIDY
      fuzz_cpp_pipeline_ENABLE_CPPCHECK
      fuzz_cpp_pipeline_ENABLE_COVERAGE
      fuzz_cpp_pipeline_ENABLE_PCH
      fuzz_cpp_pipeline_ENABLE_CACHE)
  endif()

  fuzz_cpp_pipeline_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (fuzz_cpp_pipeline_ENABLE_SANITIZER_ADDRESS OR fuzz_cpp_pipeline_ENABLE_SANITIZER_THREAD OR fuzz_cpp_pipeline_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(fuzz_cpp_pipeline_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(fuzz_cpp_pipeline_global_options)
  if(fuzz_cpp_pipeline_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    fuzz_cpp_pipeline_enable_ipo()
  endif()

  fuzz_cpp_pipeline_supports_sanitizers()

  if(fuzz_cpp_pipeline_ENABLE_HARDENING AND fuzz_cpp_pipeline_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR fuzz_cpp_pipeline_ENABLE_SANITIZER_UNDEFINED
       OR fuzz_cpp_pipeline_ENABLE_SANITIZER_ADDRESS
       OR fuzz_cpp_pipeline_ENABLE_SANITIZER_THREAD
       OR fuzz_cpp_pipeline_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${fuzz_cpp_pipeline_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${fuzz_cpp_pipeline_ENABLE_SANITIZER_UNDEFINED}")
    fuzz_cpp_pipeline_enable_hardening(fuzz_cpp_pipeline_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(fuzz_cpp_pipeline_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(fuzz_cpp_pipeline_warnings INTERFACE)
  add_library(fuzz_cpp_pipeline_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  fuzz_cpp_pipeline_set_project_warnings(
    fuzz_cpp_pipeline_warnings
    ${fuzz_cpp_pipeline_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(fuzz_cpp_pipeline_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(fuzz_cpp_pipeline_options)
  endif()

  include(cmake/Sanitizers.cmake)
  fuzz_cpp_pipeline_enable_sanitizers(
    fuzz_cpp_pipeline_options
    ${fuzz_cpp_pipeline_ENABLE_SANITIZER_ADDRESS}
    ${fuzz_cpp_pipeline_ENABLE_SANITIZER_LEAK}
    ${fuzz_cpp_pipeline_ENABLE_SANITIZER_UNDEFINED}
    ${fuzz_cpp_pipeline_ENABLE_SANITIZER_THREAD}
    ${fuzz_cpp_pipeline_ENABLE_SANITIZER_MEMORY})

  set_target_properties(fuzz_cpp_pipeline_options PROPERTIES UNITY_BUILD ${fuzz_cpp_pipeline_ENABLE_UNITY_BUILD})

  if(fuzz_cpp_pipeline_ENABLE_PCH)
    target_precompile_headers(
      fuzz_cpp_pipeline_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(fuzz_cpp_pipeline_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    fuzz_cpp_pipeline_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(fuzz_cpp_pipeline_ENABLE_CLANG_TIDY)
    fuzz_cpp_pipeline_enable_clang_tidy(fuzz_cpp_pipeline_options ${fuzz_cpp_pipeline_WARNINGS_AS_ERRORS})
  endif()

  if(fuzz_cpp_pipeline_ENABLE_CPPCHECK)
    fuzz_cpp_pipeline_enable_cppcheck(${fuzz_cpp_pipeline_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(fuzz_cpp_pipeline_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    fuzz_cpp_pipeline_enable_coverage(fuzz_cpp_pipeline_options)
  endif()

  if(fuzz_cpp_pipeline_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(fuzz_cpp_pipeline_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(fuzz_cpp_pipeline_ENABLE_HARDENING AND NOT fuzz_cpp_pipeline_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR fuzz_cpp_pipeline_ENABLE_SANITIZER_UNDEFINED
       OR fuzz_cpp_pipeline_ENABLE_SANITIZER_ADDRESS
       OR fuzz_cpp_pipeline_ENABLE_SANITIZER_THREAD
       OR fuzz_cpp_pipeline_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    fuzz_cpp_pipeline_enable_hardening(fuzz_cpp_pipeline_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
