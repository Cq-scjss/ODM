if(NOT DEFINED PATCH_FILE)
  message(FATAL_ERROR "PATCH_FILE is required")
endif()

if(NOT DEFINED WORKING_DIR)
  message(FATAL_ERROR "WORKING_DIR is required")
endif()

execute_process(
  COMMAND git apply --reverse --check "${PATCH_FILE}"
  WORKING_DIRECTORY "${WORKING_DIR}"
  RESULT_VARIABLE _patch_reverse_result
  OUTPUT_QUIET
  ERROR_QUIET
)

if(_patch_reverse_result EQUAL 0)
  message(STATUS "Patch already applied: ${PATCH_FILE}")
  return()
endif()

if(DEFINED PATCH_APPLIED_FILE AND DEFINED PATCH_APPLIED_PATTERN)
  file(READ "${WORKING_DIR}/${PATCH_APPLIED_FILE}" _patch_applied_content)
  string(FIND "${_patch_applied_content}" "${PATCH_APPLIED_PATTERN}" _patch_applied_index)
  if(NOT _patch_applied_index EQUAL -1)
    message(STATUS "Patch marker already present: ${PATCH_FILE}")
    return()
  endif()
endif()

execute_process(
  COMMAND git apply --check "${PATCH_FILE}"
  WORKING_DIRECTORY "${WORKING_DIR}"
  RESULT_VARIABLE _patch_check_result
  OUTPUT_VARIABLE _patch_check_output
  ERROR_VARIABLE _patch_check_error
)

if(NOT _patch_check_result EQUAL 0)
  message(FATAL_ERROR "Patch cannot be applied: ${PATCH_FILE}\n${_patch_check_output}${_patch_check_error}")
endif()

execute_process(
  COMMAND git apply --ignore-whitespace --whitespace=fix "${PATCH_FILE}"
  WORKING_DIRECTORY "${WORKING_DIR}"
  RESULT_VARIABLE _patch_apply_result
  OUTPUT_VARIABLE _patch_apply_output
  ERROR_VARIABLE _patch_apply_error
)

if(NOT _patch_apply_result EQUAL 0)
  message(FATAL_ERROR "Patch failed: ${PATCH_FILE}\n${_patch_apply_output}${_patch_apply_error}")
endif()
