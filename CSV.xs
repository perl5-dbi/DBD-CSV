/* Hej, Emacs, this is -*- C -*- mode!

   DBD::CSV - DBI driver for text based "databases"

   Copyright (c) 1997 Jochen Wiedmann

   You may distribute under the terms of either the GNU General Public
   License or the Artistic License, as specified in the Perl README file,
   with the exception that it cannot be placed on a CD-ROM or similar media
   for commercial distribution without the prior approval of the author.
*/

/* --- Variables --- */

#include "DBIXS.h"


struct imp_drh_st {
    dbih_drc_t com;
};
struct imp_dbh_st {
    dbih_dbc_t com;
};
struct imp_sth_st {
    dbih_stc_t com;
};



DBISTATE_DECLARE;

MODULE = DBD::CSV	PACKAGE = DBD::CSV

PROTOTYPES: ENABLE

void
SetError(self, errstr, err, state)
    SV* self
    IV err
    char* errstr
    char* state
  CODE:
    {
        D_imp_xxh(self);
	SV* dbiErrStr = DBIc_ERRSTR(imp_xxh);
	SV* dbiErr = DBIc_ERR(imp_xxh);
	SV* dbiState = DBIc_STATE(imp_xxh);
	sv_setiv(dbiErr, err);
	sv_setpv(dbiErrStr, errstr);
	sv_setpv(dbiState, state);
	DBIh_EVENT2(self, ERROR_event, dbiErr, dbiErrStr);
	if (dbis->debug >= 2) {
	    fprintf(DBILOGFP, "%s error %d recorded: %s\n",
		    SvPV(self, na), errstr, err);
	}
    }


void
SetWarning(self, errstr, err)
    SV* self
    IV err
    char* errstr
  CODE:
    {
        D_imp_xxh(self);
	SV* dbiErrStr = DBIc_ERRSTR(imp_xxh);
	SV* dbiErr = DBIc_ERR(imp_xxh);
	sv_setiv(dbiErr, err);
	sv_setpv(dbiErrStr, errstr);
	DBIh_EVENT2(self, WARN_event, dbiErr, dbiErrStr);
	if (dbis->debug >= 2) {
	    fprintf(DBILOGFP, "%s warning %d recorded: %s\n",
		    SvPV(self, na), errstr, err);
	}
    }


MODULE = DBD::CSV	PACKAGE = DBD::CSV::st


AV*
get_fbav(sth)
    SV* sth
  PROTOTYPE: $
  CODE:
    {
        D_imp_sth(sth);
	RETVAL = DBIS->get_fbav(imp_sth);
    }
  OUTPUT:
    RETVAL


BOOT:
    items = 0;  /* avoid 'unused variable' warning */
    DBISTATE_INIT;
    /* XXX this interface will change: */
    DBI_IMP_SIZE("DBD::CSV::dr::imp_data_size", sizeof(imp_drh_t));
    DBI_IMP_SIZE("DBD::CSV::db::imp_data_size", sizeof(imp_dbh_t));
    DBI_IMP_SIZE("DBD::CSV::st::imp_data_size", sizeof(imp_sth_t));
