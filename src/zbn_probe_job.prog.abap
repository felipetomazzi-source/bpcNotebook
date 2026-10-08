REPORT zbn_probe_job.
PARAMETERS p_key TYPE char22.
DATA result TYPE i.
result = zcl_bn_probe=>compile( ).
EXPORT result = result TO DATABASE indx(zn) ID p_key.
COMMIT WORK.
