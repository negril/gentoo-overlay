if(NANOVDB_USE_CUDA)
  add_executable(nanovdb_test_cuda "TestNanoVDB.cu")
  target_link_libraries(nanovdb_test_cuda PRIVATE nanovdb GTest::gtest GTest::gtest_main)
  add_test(nanovdb_cuda_unit_test nanovdb_test_cuda)
  set_property(TARGET nanovdb_test_cuda PROPERTY LINKER_LANGUAGE "CXX")

  # set(CMAKE_CUDA_COMPILER_LINKER ${CMAKE_CUDA_COMPILER_LINKER})
  # set_property(TARGET nanovdb_test_cuda PROPERTY CMAKE_CUDA_COMPILER_LINKER "${CMAKE_CXX_LINKER}")
  message(STATUS "CMAKE_CUDA_COMPILER_LINKER ${CMAKE_CUDA_COMPILER_LINKER}")

  # -hls use-lcs
  include(dump_cmake_variables)
  # print_properties()
  # message(STATUS " ================= ")
  print_target_properties(nanovdb_test_cuda)
  # print_target_properties(nanovdb)
  # print_target_properties(GTest::gtest)
  # print_target_properties(GTest::gtest_main)

  # set(PROPERTY_LIST
  #   LINKER_LANGUAGE
  #   LINKER_TYPE
  #   LINK_DIRECTORIES
  #
  #   # CUDA_ARCHITECTURES
  #   # CUDA_CUBIN_COMPILATION
  #   # CUDA_EXTENSIONS
  #   # CUDA_FATBIN_COMPILATION
  #   # CUDA_OPTIX_COMPILATION
  #   # CUDA_PTX_COMPILATION
  #   # CUDA_RESOLVE_DEVICE_SYMBOLS
  #   # CUDA_RUNTIME_LIBRARY
  #   # CUDA_SEPARABLE_COMPILATION
  #   # CUDA_STANDARD
  #   # CUDA_STANDARD_REQUIRED
  #
  # )
  # # set(target "nanovdb_test_cuda")
  # set(target "nanovdb")
  # foreach(property ${PROPERTY_LIST})
  #     string(REPLACE "<CONFIG>" "${CMAKE_BUILD_TYPE}" property ${property})
  #
  #     # # Fix https://stackoverflow.com/questions/32197663/how-can-i-remove-the-the-location-property-may-not-be-read-from-target-error-i
  #     # if(property STREQUAL "LOCATION" OR property MATCHES "^LOCATION_" OR property MATCHES "_LOCATION$")
  #     #     continue()
  #     # endif()
  #
  #     get_property(was_set TARGET ${target} PROPERTY ${property} SET)
  #     if(was_set)
  #         get_target_property(value ${target} ${property})
  #         message("${target} ${property} = ${value}")
  #     endif()
  # endforeach()
endif()