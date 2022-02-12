
/* 
   Native symbol registration table for spatstat.core package

   Automatically generated - do not edit this file!

*/

#include "proto.h"
#include <R.h>
#include <Rinternals.h>
#include <stdlib.h> // for NULL
#include <R_ext/Rdynload.h>

/*  
   See proto.h for declarations for the native routines registered below.
*/

static const R_CMethodDef CEntries[] = {
    {"knownCif", (DL_FUNC) &knownCif, 2},
    {NULL, NULL, 0}
};

static const R_CallMethodDef CallEntries[] = {
    {"PerfectDGS",           (DL_FUNC) &PerfectDGS,            4},
    {"PerfectDiggleGratton", (DL_FUNC) &PerfectDiggleGratton,  6},
    {"PerfectHardcore",      (DL_FUNC) &PerfectHardcore,       4},
    {"PerfectPenttinen",     (DL_FUNC) &PerfectPenttinen,      5},
    {"PerfectStrauss",       (DL_FUNC) &PerfectStrauss,        5},
    {"PerfectStraussHard",   (DL_FUNC) &PerfectStraussHard,    6},
    {"thinjumpequal",        (DL_FUNC) &thinjumpequal,         3},
    {"xmethas",              (DL_FUNC) &xmethas,              25},
    {NULL, NULL, 0}
};

void R_init_spatstat_random(DllInfo *dll)
{
    R_registerRoutines(dll, CEntries, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
    R_forceSymbols(dll, TRUE); 
}