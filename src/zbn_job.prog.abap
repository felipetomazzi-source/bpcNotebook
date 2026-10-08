REPORT zbn_job.
PARAMETERS p_run TYPE char32.
TRY.
    zcl_bn_service=>work( CONV string( p_run ) ).
  CATCH zcx_bn INTO DATA(error).
    " If publication itself fails, SM37 has a cancelled job for reconciliation.
    MESSAGE error->detail TYPE 'E'.
ENDTRY.
