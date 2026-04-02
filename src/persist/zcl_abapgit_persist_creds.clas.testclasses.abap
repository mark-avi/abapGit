CLASS ltcl_credentials DEFINITION
  FOR TESTING
  RISK LEVEL CRITICAL
  DURATION SHORT FINAL.

  PRIVATE SECTION.
    CONSTANTS:
      c_abap_user TYPE sy-uname VALUE 'ABAPGIT_TEST',
      c_repo_url  TYPE string VALUE 'https://example.org/repo.git',
      c_login     TYPE string VALUE 'example_user',
      c_password  TYPE string VALUE 'secret-token'.

    DATA mi_credentials TYPE REF TO zif_abapgit_persist_creds.

    METHODS setup RAISING zcx_abapgit_exception.
    METHODS cleanup_test_data.
    METHODS set_and_get_password FOR TESTING RAISING zcx_abapgit_exception.
    METHODS ignore_mismatching_login FOR TESTING RAISING zcx_abapgit_exception.
    METHODS clear_password FOR TESTING RAISING zcx_abapgit_exception.
    METHODS stored_value_is_encrypted FOR TESTING RAISING zcx_abapgit_exception.

ENDCLASS.

CLASS ltcl_credentials IMPLEMENTATION.

  METHOD setup.
    mi_credentials = zcl_abapgit_persist_factory=>get_credentials( ).
    cleanup_test_data( ).
  ENDMETHOD.


  METHOD cleanup_test_data.
    DELETE FROM zabapgit_pwd WHERE uname = c_abap_user.
    CALL FUNCTION 'DB_COMMIT'.
  ENDMETHOD.


  METHOD set_and_get_password.

    mi_credentials->set_repo_password(
      iv_url      = c_repo_url
      iv_login    = c_login
      iv_password = c_password
      iv_user     = c_abap_user ).

    cl_abap_unit_assert=>assert_equals(
      act = mi_credentials->get_repo_password(
              iv_url   = c_repo_url
              iv_login = c_login
              iv_user  = c_abap_user )
      exp = c_password ).

  ENDMETHOD.


  METHOD ignore_mismatching_login.

    mi_credentials->set_repo_password(
      iv_url      = c_repo_url
      iv_login    = c_login
      iv_password = c_password
      iv_user     = c_abap_user ).

    cl_abap_unit_assert=>assert_initial(
      act = mi_credentials->get_repo_password(
              iv_url   = c_repo_url
              iv_login = 'other-user'
              iv_user  = c_abap_user ) ).

  ENDMETHOD.


  METHOD clear_password.

    mi_credentials->set_repo_password(
      iv_url      = c_repo_url
      iv_login    = c_login
      iv_password = c_password
      iv_user     = c_abap_user ).

    mi_credentials->set_repo_password(
      iv_url      = c_repo_url
      iv_login    = c_login
      iv_password = ''
      iv_user     = c_abap_user ).

    cl_abap_unit_assert=>assert_initial(
      act = mi_credentials->get_repo_password(
              iv_url   = c_repo_url
              iv_login = c_login
              iv_user  = c_abap_user ) ).

  ENDMETHOD.


  METHOD stored_value_is_encrypted.

    DATA ls_entry TYPE zabapgit_pwd.

    mi_credentials->set_repo_password(
      iv_url      = c_repo_url
      iv_login    = c_login
      iv_password = c_password
      iv_user     = c_abap_user ).

    SELECT SINGLE * FROM zabapgit_pwd
      INTO ls_entry
      WHERE uname    = c_abap_user
        AND repo_url = c_repo_url.

    cl_abap_unit_assert=>assert_not_initial( act = ls_entry-password ).

    cl_abap_unit_assert=>assert_not_equals(
      act = ls_entry-password
      exp = c_password ).

  ENDMETHOD.
ENDCLASS.
