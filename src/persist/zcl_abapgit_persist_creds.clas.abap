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

    ls_entry-mandt    = sy-mandt.
    ls_entry-uname    = iv_user.
    ls_entry-repo_url = iv_url.
    ls_entry-login    = iv_login.
    ls_entry-password = iv_password.

    UPDATE (c_tabname)
      SET login    = ls_entry-login
          password = ls_entry-password
      WHERE mandt    = ls_entry-mandt
        AND uname    = ls_entry-uname
        AND repo_url = ls_entry-repo_url.

    IF sy-subrc <> 0.
      INSERT (c_tabname) FROM ls_entry.                    "#EC CI_SUBRC
      IF sy-subrc <> 0.
        zcx_abapgit_exception=>raise( 'Failed to store repository password' ).
      ENDIF.
    ENDIF.

    COMMIT WORK AND WAIT.

  ENDMETHOD.


  METHOD zif_abapgit_persist_creds~get_repo_password.

    DATA: ls_entry TYPE zabapgit_pwd,
          lv_url   TYPE zabapgit_pwd-repo_url.

    lv_url = normalize_url( iv_url ).

    SELECT SINGLE * FROM zabapgit_pwd
      INTO ls_entry
      WHERE mandt    = sy-mandt
        AND uname    = iv_user
        AND repo_url = lv_url.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF iv_login IS NOT INITIAL
      AND ls_entry-login IS NOT INITIAL
      AND ls_entry-login <> iv_login.
      RETURN.
    ENDIF.

    rv_password = ls_entry-password.

  ENDMETHOD.


  METHOD zif_abapgit_persist_creds~set_repo_password.

    DATA: lv_url TYPE zabapgit_pwd-repo_url.

    IF strlen( iv_login ) > c_max_login_len.
      zcx_abapgit_exception=>raise( 'Repo login too long to store password' ).
    ENDIF.

    lv_url = normalize_url( iv_url ).

    IF iv_password IS INITIAL.
      DELETE FROM zabapgit_pwd
        WHERE mandt    = sy-mandt
          AND uname    = iv_user
          AND repo_url = lv_url.
      COMMIT WORK AND WAIT.
      RETURN.
    ENDIF.

    persist_password(
      iv_url      = lv_url
      iv_login    = iv_login
      iv_password = iv_password
      iv_user     = iv_user ).

  ENDMETHOD.
ENDCLASS.
