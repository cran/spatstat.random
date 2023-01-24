
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
    {"rcauchyAll",           (DL_FUNC) &rcauchyAll,            5},
    {"rcauchyOff",           (DL_FUNC) &rcauchyOff,            5},
    {"rmatclusAll",          (DL_FUNC) &rmatclusAll,           5},
    {"rmatclusOff",          (DL_FUNC) &rmatclusOff,           5},
    {"rnzpoisDalgaard",      (DL_FUNC) &rnzpoisDalgaard,       2},
    {"rnzpoisHarding",       (DL_FUNC) &rnzpoisHarding,        2},
    {"rthomasAll",           (DL_FUNC) &rthomasAll,            5},
    {"rthomasOff",           (DL_FUNC) &rthomasOff,            5},
    {"rtruncpoisDalgaard",   (DL_FUNC) &rtruncpoisDalgaard,    3},
    {"rtruncpoisHarding",    (DL_FUNC) &rtruncpoisHarding,     3},
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
