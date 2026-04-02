CLASS zcl_abapgit_persist_creds DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES zif_abapgit_persist_creds .

  PRIVATE SECTION.

    CONSTANTS:
      c_tabname       TYPE tabname VALUE 'ZABAPGIT_PWD',
      c_max_url_len   TYPE i       VALUE 200,
      c_max_login_len TYPE i       VALUE 120.

    METHODS normalize_url
      IMPORTING
        !iv_url       TYPE string
      RETURNING
        VALUE(rv_url) TYPE zabapgit_pwd-repo_url
      RAISING
        zcx_abapgit_exception.
    METHODS encrypt_password
      IMPORTING
        !iv_password    TYPE string
      RETURNING
        VALUE(rv_value) TYPE string
      RAISING
        zcx_abapgit_exception.
    METHODS decrypt_password
      IMPORTING
        !iv_value      TYPE string
      RETURNING
        VALUE(rv_pass) TYPE string
      RAISING
        zcx_abapgit_exception.
    METHODS xor_with_key
      IMPORTING
        !iv_value       TYPE xstring
      RETURNING
        VALUE(rv_value) TYPE xstring
      RAISING
        zcx_abapgit_exception.
    METHODS get_key
      RETURNING
        VALUE(rv_key) TYPE xstring
      RAISING
        zcx_abapgit_exception.
    METHODS persist_password
      IMPORTING
        !iv_url      TYPE zabapgit_pwd-repo_url
        !iv_login    TYPE zabapgit_pwd-login
        !iv_password TYPE zabapgit_pwd-password
        !iv_user     TYPE sy-uname
      RAISING
        zcx_abapgit_exception.
ENDCLASS.



CLASS zcl_abapgit_persist_creds IMPLEMENTATION.


  METHOD normalize_url.

    rv_url = to_lower( iv_url ).

    IF strlen( rv_url ) > c_max_url_len.
      zcx_abapgit_exception=>raise( 'Repo URL too long to store password' ).
    ENDIF.

  ENDMETHOD.


  METHOD persist_password.

    DATA: ls_entry TYPE zabapgit_pwd.

    ls_entry-uname    = iv_user.
    ls_entry-repo_url = iv_url.
    ls_entry-login    = iv_login.
    ls_entry-password = iv_password.

    UPDATE (c_tabname)
      SET login    = ls_entry-login
          password = ls_entry-password
      WHERE uname    = ls_entry-uname
        AND repo_url = ls_entry-repo_url.

    IF sy-subrc <> 0.
      INSERT (c_tabname) FROM ls_entry.                    "#EC CI_SUBRC
      IF sy-subrc <> 0.
        zcx_abapgit_exception=>raise( 'Failed to store repository password' ).
      ENDIF.
    ENDIF.

    COMMIT WORK AND WAIT.

  ENDMETHOD.


  METHOD decrypt_password.

    DATA lv_value TYPE xstring.

    IF iv_value IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        lv_value = cl_http_utility=>decode_x_base64( iv_value ).
      CATCH cx_root.
        " Backward compatibility: treat non-Base64 values as plain-text passwords
        rv_pass = iv_value.
        RETURN.
    ENDTRY.

    lv_value = xor_with_key( lv_value ).

    rv_pass = zcl_abapgit_convert=>xstring_to_string_utf8( lv_value ).

  ENDMETHOD.


  METHOD encrypt_password.

    DATA lv_value TYPE xstring.

    IF iv_password IS INITIAL.
      RETURN.
    ENDIF.

    lv_value = zcl_abapgit_convert=>string_to_xstring( iv_password ).
    lv_value = xor_with_key( lv_value ).

    rv_value = cl_http_utility=>encode_x_base64( lv_value ).

  ENDMETHOD.


  METHOD get_key.

    DATA lv_key TYPE string.

    lv_key = |{ sy-sysid }_{ sy-mandt }|.

    IF lv_key IS INITIAL.
      zcx_abapgit_exception=>raise( 'Encryption key not available' ).
    ENDIF.

    rv_key = zcl_abapgit_convert=>string_to_xstring( lv_key ).

  ENDMETHOD.


  METHOD xor_with_key.

    DATA: lv_key     TYPE xstring,
          lv_key_len TYPE i,
          lv_len     TYPE i,
          lv_pos     TYPE i,
          lv_key_pos TYPE i.

    FIELD-SYMBOLS: <lv_byte> TYPE x,
                   <lv_key>  TYPE x.

    rv_value = iv_value.

    lv_key = get_key( ).
    lv_key_len = xstrlen( lv_key ).
    lv_len     = xstrlen( rv_value ).

    IF lv_key_len = 0 OR lv_len = 0.
      zcx_abapgit_exception=>raise( 'Encryption key not available' ).
    ENDIF.

    DO lv_len TIMES.
      lv_pos = sy-index - 1.
      lv_key_pos = lv_pos MOD lv_key_len.
      ASSIGN rv_value+lv_pos(1) TO <lv_byte>.
      ASSIGN lv_key+lv_key_pos(1) TO <lv_key>.
      IF sy-subrc <> 0.
        zcx_abapgit_exception=>raise( 'Encryption key not available' ).
      ENDIF.
      <lv_byte> = <lv_byte> BIT-XOR <lv_key>.
    ENDDO.

  ENDMETHOD.


  METHOD zif_abapgit_persist_creds~get_repo_password.

    DATA: ls_entry TYPE zabapgit_pwd,
          lv_url   TYPE zabapgit_pwd-repo_url.

    lv_url = normalize_url( iv_url ).

    SELECT SINGLE * FROM zabapgit_pwd
      INTO ls_entry
      WHERE uname    = iv_user
        AND repo_url = lv_url.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF iv_login IS NOT INITIAL
      AND ls_entry-login IS NOT INITIAL
      AND ls_entry-login <> iv_login.
      RETURN.
    ENDIF.

    rv_password = decrypt_password( ls_entry-password ).

  ENDMETHOD.


  METHOD zif_abapgit_persist_creds~set_repo_password.

    DATA: lv_url       TYPE zabapgit_pwd-repo_url,
          lv_password TYPE string.

    IF strlen( iv_login ) > c_max_login_len.
      zcx_abapgit_exception=>raise( 'Repo login too long to store password' ).
    ENDIF.

    lv_url = normalize_url( iv_url ).

    IF iv_password IS INITIAL.
      DELETE FROM zabapgit_pwd
        WHERE uname    = iv_user
          AND repo_url = lv_url.
      COMMIT WORK AND WAIT.
      RETURN.
    ENDIF.

    lv_password = encrypt_password( iv_password ).

    persist_password(
      iv_url      = lv_url
      iv_login    = iv_login
      iv_password = lv_password
      iv_user     = iv_user ).

  ENDMETHOD.
ENDCLASS.
