INTERFACE zif_abapgit_persist_creds
  PUBLIC .

  METHODS get_repo_password
    IMPORTING
      !iv_url            TYPE string
      !iv_login          TYPE string OPTIONAL
      !iv_user           TYPE sy-uname DEFAULT sy-uname
    RETURNING
      VALUE(rv_password) TYPE string
    RAISING
      zcx_abapgit_exception.
  METHODS set_repo_password
    IMPORTING
      !iv_url      TYPE string
      !iv_login    TYPE string
      !iv_password TYPE string
      !iv_user     TYPE sy-uname DEFAULT sy-uname
    RAISING
      zcx_abapgit_exception.

ENDINTERFACE.
