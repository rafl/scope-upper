/* This file is part of the Scope::Upper Perl module.
 * See http://search.cpan.org/dist/Scope-Upper/ */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h" 
#include "XSUB.h"

#define __PACKAGE__ "Scope::Upper"

#ifndef SU_DEBUG
# define SU_DEBUG 0
#endif

/* --- Compatibility ------------------------------------------------------- */

#ifndef PERL_UNUSED_VAR
# define PERL_UNUSED_VAR(V)
#endif

#ifndef STMT_START
# define STMT_START do
#endif

#ifndef STMT_END
# define STMT_END while (0)
#endif

#if SU_DEBUG
# define SU_D(X) STMT_START X STMT_END
#else
# define SU_D(X)
#endif

#ifndef Newx
# define Newx(v, n, c) New(0, v, n, c)
#endif

#ifndef SvPV_const
# define SvPV_const(S, L) SvPV(S, L)
#endif

#ifndef SvPV_nolen_const
# define SvPV_nolen_const(S) SvPV_nolen(S)
#endif

#ifndef HvNAME_get
# define HvNAME_get(H) HvNAME(H)
#endif

#ifndef gv_fetchpvn_flags
# define gv_fetchpvn_flags(A, B, C, D) gv_fetchpv((A), (C), (D))
#endif

#ifndef PERL_MAGIC_tied
# define PERL_MAGIC_tied 'P'
#endif

#ifndef PERL_MAGIC_env
# define PERL_MAGIC_env 'E'
#endif

#ifndef NEGATIVE_INDICES_VAR
# define NEGATIVE_INDICES_VAR "NEGATIVE_INDICES"
#endif

#define SU_HAS_PERL(R, V, S) (PERL_REVISION > (R) || (PERL_REVISION == (R) && (PERL_VERSION > (V) || (PERL_VERSION == (V) && (PERL_SUBVERSION >= (S))))))

/* --- Threads and multiplicity -------------------------------------------- */

#ifndef NOOP
# define NOOP
#endif

#ifndef dNOOP
# define dNOOP
#endif

#ifndef SU_MULTIPLICITY
# if defined(MULTIPLICITY) || defined(PERL_IMPLICIT_CONTEXT)
#  define SU_MULTIPLICITY 1
# else
#  define SU_MULTIPLICITY 0
# endif
#endif
#if SU_MULTIPLICITY && !defined(tTHX)
# define tTHX PerlInterpreter*
#endif

#if SU_MULTIPLICITY && defined(USE_ITHREADS) && defined(dMY_CXT) && defined(MY_CXT) && defined(START_MY_CXT) && defined(MY_CXT_INIT) && (defined(MY_CXT_CLONE) || defined(dMY_CXT_SV))
# define SU_THREADSAFE 1
# ifndef MY_CXT_CLONE
#  define MY_CXT_CLONE \
    dMY_CXT_SV;                                                      \
    my_cxt_t *my_cxtp = (my_cxt_t*)SvPVX(newSV(sizeof(my_cxt_t)-1)); \
    Copy(INT2PTR(my_cxt_t*, SvUV(my_cxt_sv)), my_cxtp, 1, my_cxt_t); \
    sv_setuv(my_cxt_sv, PTR2UV(my_cxtp))
# endif
#else
# define SU_THREADSAFE 0
# undef  dMY_CXT
# define dMY_CXT      dNOOP
# undef  MY_CXT
# define MY_CXT       su_globaldata
# undef  START_MY_CXT
# define START_MY_CXT STATIC my_cxt_t MY_CXT;
# undef  MY_CXT_INIT
# define MY_CXT_INIT  NOOP
# undef  MY_CXT_CLONE
# define MY_CXT_CLONE NOOP
#endif

/* --- Stack manipulations ------------------------------------------------- */

#ifndef SvCANEXISTDELETE
# define SvCANEXISTDELETE(sv) \
  (!SvRMAGICAL(sv)            \
   || ((mg = mg_find((SV *) sv, PERL_MAGIC_tied))            \
       && (stash = SvSTASH(SvRV(SvTIED_obj((SV *) sv, mg)))) \
       && gv_fetchmethod_autoload(stash, "EXISTS", TRUE)     \
       && gv_fetchmethod_autoload(stash, "DELETE", TRUE)     \
      )                       \
   )
#endif

/* ... Saving array elements ............................................... */

STATIC I32 su_av_key2idx(pTHX_ AV *av, I32 key) {
#define su_av_key2idx(A, K) su_av_key2idx(aTHX_ (A), (K))
 I32 idx;

 if (key >= 0)
  return key;

/* Added by MJD in perl-5.8.1 with 6f12eb6d2a1dfaf441504d869b27d2e40ef4966a */
#if SU_HAS_PERL(5, 8, 1)
 if (SvRMAGICAL(av)) {
  const MAGIC * const tied_magic = mg_find((SV *) av, PERL_MAGIC_tied);
  if (tied_magic) {
   int adjust_index = 1;
   SV * const * const negative_indices_glob =
                    hv_fetch(SvSTASH(SvRV(SvTIED_obj((SV *) (av), tied_magic))),
                             NEGATIVE_INDICES_VAR, 16, 0);
   if (negative_indices_glob && SvTRUE(GvSV(*negative_indices_glob)))
    return key;
  }
 }
#endif

 idx = key + av_len(av) + 1;
 if (idx < 0)
  return key;

 return idx;
}

#ifndef SAVEADELETE

typedef struct {
 AV *av;
 I32 idx;
} su_ud_adelete;

STATIC void su_adelete(pTHX_ void *ud_) {
 su_ud_adelete *ud = (su_ud_adelete *) ud_;

 av_delete(ud->av, ud->idx, G_DISCARD);
 SvREFCNT_dec(ud->av);

 Safefree(ud);
}

STATIC void su_save_adelete(pTHX_ AV *av, I32 idx) {
#define su_save_adelete(A, K) su_save_adelete(aTHX_ (A), (K))
 su_ud_adelete *ud;

 Newx(ud, 1, su_ud_adelete);
 ud->av  = av;
 ud->idx = idx;
 SvREFCNT_inc(av);

 SAVEDESTRUCTOR_X(su_adelete, ud);
}

#define SAVEADELETE(A, K) su_save_adelete((A), (K))

#endif /* SAVEADELETE */

STATIC void su_save_aelem(pTHX_ AV *av, SV *key, SV *val) {
#define su_save_aelem(A, K, V) su_save_aelem(aTHX_ (A), (K), (V))
 I32 idx;
 I32 preeminent = 1;
 SV **svp;
 HV *stash;
 MAGIC *mg;

 idx = su_av_key2idx(av, SvIV(key));

 if (SvCANEXISTDELETE(av))
  preeminent = av_exists(av, idx);

 svp = av_fetch(av, idx, 1);
 if (!svp || *svp == &PL_sv_undef) croak(PL_no_aelem, idx);

 if (preeminent)
  save_aelem(av, idx, svp);
 else
  SAVEADELETE(av, idx);

 if (val) { /* local $x[$idx] = $val; */
  SvSetMagicSV(*svp, val);
 } else {   /* local $x[$idx]; delete $x[$idx]; */
  av_delete(av, idx, G_DISCARD);
 }
}

/* ... Saving hash elements ................................................ */

STATIC void su_save_helem(pTHX_ HV *hv, SV *keysv, SV *val) {
#define su_save_helem(H, K, V) su_save_helem(aTHX_ (H), (K), (V))
 I32 preeminent = 1;
 HE *he;
 SV **svp;
 HV *stash;
 MAGIC *mg;

 if (SvCANEXISTDELETE(hv) || mg_find((SV *) hv, PERL_MAGIC_env))
  preeminent = hv_exists_ent(hv, keysv, 0);

 he  = hv_fetch_ent(hv, keysv, 1, 0);
 svp = he ? &HeVAL(he) : NULL;
 if (!svp || *svp == &PL_sv_undef) croak("Modification of non-creatable hash value attempted, subscript \"%s\"", SvPV_nolen_const(*svp));

 if (HvNAME_get(hv) && isGV(*svp)) {
  save_gp((GV *) *svp, 0);
  return;
 }

 if (preeminent)
  save_helem(hv, keysv, svp);
 else {
  STRLEN keylen;
  const char * const key = SvPV_const(keysv, keylen);
  SAVEDELETE(hv, savepvn(key, keylen),
                 SvUTF8(keysv) ? -(I32)keylen : (I32)keylen);
 }

 if (val) { /* local $x{$keysv} = $val; */
  SvSetMagicSV(*svp, val);
 } else {   /* local $x{$keysv}; delete $x{$keysv}; */
  hv_delete_ent(hv, keysv, G_DISCARD, HeHASH(he));
 }
}

/* --- Actions ------------------------------------------------------------- */

typedef struct {
 I32 depth;
 I32 *origin;
 void (*handler)(pTHX_ void *);
} su_ud_common;

#define SU_UD_DEPTH(U)   (((su_ud_common *) (U))->depth)
#define SU_UD_ORIGIN(U)  (((su_ud_common *) (U))->origin)
#define SU_UD_HANDLER(U) (((su_ud_common *) (U))->handler)

#define SU_UD_FREE(U) STMT_START { \
 if (SU_UD_ORIGIN(U)) Safefree(SU_UD_ORIGIN(U)); \
 Safefree(U); \
} STMT_END

/* ... Reap ................................................................ */

typedef struct {
 su_ud_common ci;
 SV *cb;
} su_ud_reap;

STATIC void su_call(pTHX_ void *ud_) {
 su_ud_reap *ud = (su_ud_reap *) ud_;
#if SU_HAS_PERL(5, 10, 0)
 I32 dieing = PL_op->op_type == OP_DIE;
#endif

 dSP;

 SU_D(PerlIO_printf(Perl_debug_log, "%p: @@@ call at %d (save is %d)\n",
                                     ud, PL_scopestack_ix, PL_savestack_ix));
 ENTER;
 SAVETMPS;

 PUSHMARK(SP);
 PUTBACK;

 /* If cxstack_ix isn't incremented there, the eval context will be overwritten
  * when the new sub scope will be created in call_sv. */

#if SU_HAS_PERL(5, 10, 0)
 if (dieing)
  if (cxstack_ix < cxstack_max)
   ++cxstack_ix;
  else
   cxstack_ix = Perl_cxinc(aTHX);
#endif

 call_sv(ud->cb, G_VOID);

#if SU_HAS_PERL(5, 10, 0)
 if (dieing && cxstack_ix > 0)
  --cxstack_ix;
#endif

 SPAGAIN;
 PUTBACK;

 FREETMPS;
 LEAVE;

 SvREFCNT_dec(ud->cb);
 SU_UD_FREE(ud);
}

STATIC void su_reap(pTHX_ void *ud) {
#define su_reap(U) su_reap(aTHX_ (U))
 SU_D(PerlIO_printf(Perl_debug_log, "%p: === reap at %d (save is %d)\n",
                                     ud, PL_scopestack_ix, PL_savestack_ix));
 SAVEDESTRUCTOR_X(su_call, ud);
 SU_D(PerlIO_printf(Perl_debug_log, "%p: savestack is now at %d, base at %d\n",
                                     ud, PL_savestack_ix,
                                         PL_scopestack[PL_scopestack_ix]));
}

/* ... Localize & localize array/hash element .............................. */

typedef struct {
 su_ud_common ci;
 SV *sv;
 SV *val;
 SV *elem;
} su_ud_localize;

STATIC void su_localize(pTHX_ void *ud_) {
#define su_localize(U) su_localize(aTHX_ (U))
 su_ud_localize *ud = (su_ud_localize *) ud_;
 SV *sv   = ud->sv;
 SV *val  = ud->val;
 SV *elem = ud->elem;
 GV *gv;
 UV deref = 0;
 svtype t = SVt_NULL;

 if (SvTYPE(sv) >= SVt_PVGV) {
  gv = (GV *) sv;
  if (!val) {               /* local *x; */
   t = SVt_PVGV;
  } else if (!SvROK(val)) { /* local *x = $val; */
   goto assign;
  } else {                  /* local *x = \$val; */
   t = SvTYPE(SvRV(val));
   deref = 1;
  }
 } else {
  STRLEN len, l;
  const char *p = SvPV_const(sv, len), *s;
  for (s = p, l = len; l > 0 && isSPACE(*s); ++s, --l) { }
  if (!l) {
   l = len;
   s = p;
  }
  switch (*s) {
   case '$': t = SVt_PV;   break;
   case '@': t = SVt_PVAV; break;
   case '%': t = SVt_PVHV; break;
   case '&': t = SVt_PVCV; break;
   case '*': t = SVt_PVGV; break;
  }
  if (t != SVt_NULL) {
   ++s;
   --l;
  } else if (val) { /* t == SVt_NULL, type can't be inferred from the sigil */
   if (SvROK(val) && !sv_isobject(val)) {
    t = SvTYPE(SvRV(val));
    deref = 1;
   } else {
    t = SvTYPE(val);
   }
  }
  gv = gv_fetchpvn_flags(s, l, GV_ADDMULTI, SVt_PVGV);
 }

 SU_D({
  SV *z = newSV_type(t);
  PerlIO_printf(Perl_debug_log, "%p: === localize a %s at %d (save is %d)\n",
                                 ud, sv_reftype(z, 0),
                                     PL_scopestack_ix, PL_savestack_ix);
  SvREFCNT_dec(z);
 });

 /* Inspired from Alias.pm */
 switch (t) {
  case SVt_PVAV:
   if (elem) {
    su_save_aelem(GvAV(gv), elem, val);
    goto done;
   } else
    save_ary(gv);
   break;
  case SVt_PVHV:
   if (elem) {
    su_save_helem(GvHV(gv), elem, val);
    goto done;
   } else
    save_hash(gv);
   break;
  case SVt_PVGV:
   save_gp(gv, 1); /* hide previous entry in symtab */
   break;
  case SVt_PVCV:
   SAVESPTR(GvCV(gv));
   GvCV(gv) = NULL;
   break;
  default:
   gv = (GV *) save_scalar(gv);
maybe_deref:
   if (deref) /* val != NULL */
    val = SvRV(val);
   break;
 }

 SU_D(PerlIO_printf(Perl_debug_log, "%p: savestack is now at %d, base at %d\n",
                                     ud, PL_savestack_ix,
                                         PL_scopestack[PL_scopestack_ix]));

assign:
 if (val)
  SvSetMagicSV((SV *) gv, val);

done:
 SvREFCNT_dec(ud->elem);
 SvREFCNT_dec(ud->val);
 SvREFCNT_dec(ud->sv);
 SU_UD_FREE(ud);
}

/* --- Pop a context back -------------------------------------------------- */

#if SU_DEBUG
# ifdef DEBUGGING
#  define SU_CXNAME PL_block_type[CxTYPE(&cxstack[cxstack_ix])]
# else
#  define SU_CXNAME "XXX"
# endif
#endif

STATIC void su_pop(pTHX_ void *ud) {
#define su_pop(U) su_pop(aTHX_ (U))
 I32 depth, base, mark, *origin;
 depth = SU_UD_DEPTH(ud);

 SU_D(PerlIO_printf(Perl_debug_log, "%p: --- pop %s at %d from %d to %d [%d]\n",
                                     ud, SU_CXNAME,
                                         PL_scopestack_ix, PL_savestack_ix,
                                         PL_scopestack[PL_scopestack_ix],
                                         depth));

 origin = SU_UD_ORIGIN(ud);
 mark   = origin[depth];
 base   = origin[depth - 1];

 SU_D(PerlIO_printf(Perl_debug_log, "%p: clean from %d down to %d\n",
                                     ud, mark, base));

 if (base < mark) {
  PL_savestack_ix = mark;
  leave_scope(base);
 }
 PL_savestack_ix = base;
 if (--depth > 0) {
  SU_UD_DEPTH(ud) = depth;
  SU_D(PerlIO_printf(Perl_debug_log, "%p: save new destructor at %d [%d]\n",
                                      ud, PL_savestack_ix, depth));
  SAVEDESTRUCTOR_X(su_pop, ud);
  SU_D(PerlIO_printf(Perl_debug_log, "%p: pop end at at %d [%d]\n",
                                      ud, PL_savestack_ix, depth));
 } else {
  SU_UD_HANDLER(ud)(aTHX_ ud);
 }
}

/* --- Initialize the stack and the action userdata ------------------------ */

STATIC I32 su_init(pTHX_ I32 cxix, void *ud, I32 size) {
#define su_init(L, U, S) su_init(aTHX_ (L), (U), (S))
 I32 i, depth = 0, *origin;
 I32 cur, last, step;

 LEAVE;

 if (cxix >= cxstack_ix) {
  SU_UD_HANDLER(ud)(aTHX_ ud);
  goto done;
 }

 SU_D(PerlIO_printf(Perl_debug_log, "%p: ### init for cx %d\n", ud, cxix));

 for (i = cxstack_ix; i > cxix; --i) {
  PERL_CONTEXT *cx = cxstack + i;
  switch (CxTYPE(cx)) {
#if SU_HAS_PERL(5, 11, 0)
   case CXt_LOOP_FOR:
   case CXt_LOOP_PLAIN:
   case CXt_LOOP_LAZYSV:
   case CXt_LOOP_LAZYIV:
#else
   case CXt_LOOP:
#endif
    SU_D(PerlIO_printf(Perl_debug_log, "%p: cx %d is loop\n", ud, i));
    depth += 2;
    break;
   default:
    SU_D(PerlIO_printf(Perl_debug_log, "%p: cx %d is normal\n", ud, i));
    depth++;
    break;
  }
 }
 SU_D(PerlIO_printf(Perl_debug_log, "%p: depth is %d\n", ud, depth));

 Newx(origin, depth + 1, I32);
 origin[0] = PL_scopestack[PL_scopestack_ix - depth];
 PL_scopestack[PL_scopestack_ix - depth] += size;
 for (i = depth - 1; i >= 1; --i) {
  I32 j = PL_scopestack_ix - i;
  origin[depth - i] = PL_scopestack[j];
  PL_scopestack[j] += 3;
 }
 origin[depth] = PL_savestack_ix;

 SU_D({
  PerlIO_printf(Perl_debug_log, "%p: d=%d s=%d x=%d c=%d o=%d\n", ud,
                depth, 0, PL_scopestack_ix - 1, PL_savestack_ix, origin[depth]);
  for (i = depth - 1; i >= 0; --i) {
   I32 x = PL_scopestack_ix  - depth + i;
   PerlIO_printf(Perl_debug_log, "%p: d=%d s=%d x=%d c=%d o=%d\n", ud,
                                  i, depth - i, x, PL_scopestack[x], origin[i]);
  }
 });

 SU_UD_ORIGIN(ud) = origin;
 SU_UD_DEPTH(ud)  = depth;

 SU_D(PerlIO_printf(Perl_debug_log, "%p: set original destructor at %d [%d]\n",
                                     ud, PL_savestack_ix, depth));

 SAVEDESTRUCTOR_X(su_pop, ud);

done:
 ENTER;

 return depth;
}

/* --- Global data --------------------------------------------------------- */

#define MY_CXT_KEY __PACKAGE__ "::_guts" XS_VERSION

typedef struct {
 I32 cxix;
 I32 items;
 SV  **savesp;
 OP  fakeop;
} my_cxt_t;

START_MY_CXT

/* --- Unwind stack -------------------------------------------------------- */

STATIC void su_unwind(pTHX_ void *ud_) {
 dMY_CXT;
 I32 cxix    = MY_CXT.cxix;
 I32 items   = MY_CXT.items - 1;
 SV **savesp = MY_CXT.savesp;
 I32 mark;

 if (savesp)
  PL_stack_sp = savesp;

 if (cxstack_ix > cxix)
  dounwind(cxix);

 /* Hide the level */
 if (items >= 0)
  PL_stack_sp--;

 mark = PL_markstack[cxstack[cxix].blk_oldmarksp];
 *PL_markstack_ptr = PL_stack_sp - PL_stack_base - items;

 SU_D({
  I32 gimme = GIMME_V;
  PerlIO_printf(Perl_debug_log,
                "%p: cx=%d gimme=%s items=%d sp=%d oldmark=%d mark=%d\n",
                &MY_CXT, cxix,
                gimme == G_VOID ? "void" : gimme == G_ARRAY ? "list" : "scalar",
                items, PL_stack_sp - PL_stack_base, *PL_markstack_ptr, mark);
 });

 PL_op = PL_ppaddr[OP_RETURN](aTHX);
 *PL_markstack_ptr = mark;

 MY_CXT.fakeop.op_next = PL_op;
 PL_op = &(MY_CXT.fakeop);
}

/* --- XS ------------------------------------------------------------------ */

#if SU_HAS_PERL(5, 8, 9)
# define SU_SKIP_DB_MAX 2
#else
# define SU_SKIP_DB_MAX 3
#endif

/* Skip context sequences of 1 to SU_SKIP_DB_MAX (included) block contexts
 * followed by a DB sub */

#define SU_SKIP_DB(C) \
 STMT_START {         \
  I32 i = 1;          \
  PERL_CONTEXT *cx = cxstack + (C); \
  do {                              \
   if (CxTYPE(cx) == CXt_BLOCK && (C) >= i) { \
    --cx;                                     \
    if (CxTYPE(cx) == CXt_SUB && cx->blk_sub.cv == GvCV(PL_DBsub)) { \
     (C) -= i + 1;                \
     break;                       \
    }                             \
   } else                         \
    break;                        \
  } while (++i <= SU_SKIP_DB_MAX); \
 } STMT_END

#define SU_GET_CONTEXT(A, B)   \
 STMT_START {                  \
  if (items > A) {             \
   SV *csv = ST(B);            \
   if (SvOK(csv))              \
    cxix = SvIV(csv);          \
   if (cxix < 0)               \
    cxix = 0;                  \
   else if (cxix > cxstack_ix) \
    cxix = cxstack_ix;         \
  } else {                     \
   cxix = cxstack_ix;          \
   if (PL_DBsub)               \
    SU_SKIP_DB(cxix);          \
  }                            \
 } STMT_END

XS(XS_Scope__Upper_unwind); /* prototype to pass -Wmissing-prototypes */

XS(XS_Scope__Upper_unwind) {
#ifdef dVAR
 dVAR; dXSARGS;
#else
 dXSARGS;
#endif
 dMY_CXT;
 I32 cxix;

 PERL_UNUSED_VAR(cv); /* -W */
 PERL_UNUSED_VAR(ax); /* -Wall */

 SU_GET_CONTEXT(0, items - 1);
 do {
  PERL_CONTEXT *cx = cxstack + cxix;
  switch (CxTYPE(cx)) {
   case CXt_SUB:
    if (PL_DBsub && cx->blk_sub.cv == GvCV(PL_DBsub))
     continue;
   case CXt_EVAL:
   case CXt_FORMAT:
    MY_CXT.cxix  = cxix;
    MY_CXT.items = items;
    /* pp_entersub will want to sanitize the stack after returning from there
     * Screw that, we're insane */
    if (GIMME_V == G_SCALAR) {
     MY_CXT.savesp = PL_stack_sp;
     /* dXSARGS calls POPMARK, so we need to match PL_markstack_ptr[1] */
     PL_stack_sp = PL_stack_base + PL_markstack_ptr[1] + 1;
    } else {
     MY_CXT.savesp = NULL;
    }
    SAVEDESTRUCTOR_X(su_unwind, NULL);
    return;
   default:
    break;
  }
 } while (--cxix >= 0);
 croak("Can't return outside a subroutine");
}

MODULE = Scope::Upper            PACKAGE = Scope::Upper

PROTOTYPES: ENABLE

BOOT:
{
 HV *stash;
 MY_CXT_INIT;
 stash = gv_stashpv(__PACKAGE__, 1);
 newCONSTSUB(stash, "TOP", newSViv(0));
 newXSproto("Scope::Upper::unwind", XS_Scope__Upper_unwind, file, NULL);
}

void
CLONE(...)
PROTOTYPE: DISABLE
CODE:
#if SU_THREADSAFE
 MY_CXT_CLONE;
#endif /* SU_THREADSAFE */

SV *
HERE()
PROTOTYPE:
PREINIT:
 I32 cxix = cxstack_ix;
CODE:
 if (PL_DBsub)
  SU_SKIP_DB(cxix);
 RETVAL = newSViv(cxix);
OUTPUT:
 RETVAL

SV *
UP(...)
PROTOTYPE: ;$
PREINIT:
 I32 cxix;
CODE:
 SU_GET_CONTEXT(0, 0);
 if (--cxix < 0)
  cxix = 0;
 if (PL_DBsub)
  SU_SKIP_DB(cxix);
 RETVAL = newSViv(cxix);
OUTPUT:
 RETVAL

void
SUB(...)
PROTOTYPE: ;$
PREINIT:
 I32 cxix;
PPCODE:
 SU_GET_CONTEXT(0, 0);
 for (; cxix >= 0; --cxix) {
  PERL_CONTEXT *cx = cxstack + cxix;
  switch (CxTYPE(cx)) {
   default:
    continue;
   case CXt_SUB:
    if (PL_DBsub && cx->blk_sub.cv == GvCV(PL_DBsub))
     continue;
    ST(0) = sv_2mortal(newSViv(cxix));
    XSRETURN(1);
  }
 }
 XSRETURN_UNDEF;

void
EVAL(...)
PROTOTYPE: ;$
PREINIT:
 I32 cxix;
PPCODE:
 SU_GET_CONTEXT(0, 0);
 for (; cxix >= 0; --cxix) {
  PERL_CONTEXT *cx = cxstack + cxix;
  switch (CxTYPE(cx)) {
   default:
    continue;
   case CXt_EVAL:
    ST(0) = sv_2mortal(newSViv(cxix));
    XSRETURN(1);
  }
 }
 XSRETURN_UNDEF;

void
CALLER(...)
PROTOTYPE: ;$
PREINIT:
 I32 cxix, caller = 0;
PPCODE:
 if (items) {
  SV *csv = ST(0);
  if (SvOK(csv))
   caller = SvIV(csv);
  if (caller < 0)
   caller = 0;
 }
 for (cxix = cxstack_ix; cxix > 0; --cxix) {
  PERL_CONTEXT *cx = cxstack + cxix;
  switch (CxTYPE(cx)) {
   case CXt_SUB:
    if (PL_DBsub && cx->blk_sub.cv == GvCV(PL_DBsub))
     continue;
   case CXt_EVAL:
   case CXt_FORMAT:
    --caller;
    if (caller < 0)
     goto done;
    break;
  }
 }
done:
 ST(0) = sv_2mortal(newSViv(cxix));
 XSRETURN(1);

void
want_at(...)
PROTOTYPE: ;$
PREINIT:
 I32 cxix;
PPCODE:
 SU_GET_CONTEXT(0, 0);
 while (cxix > 0) {
  PERL_CONTEXT *cx = cxstack + cxix--;
  switch (CxTYPE(cx)) {
   case CXt_SUB:
   case CXt_EVAL:
   case CXt_FORMAT: {
    I32 gimme = cx->blk_gimme;
    switch (gimme) {
     case G_VOID:   XSRETURN_UNDEF; break;
     case G_SCALAR: XSRETURN_NO;    break;
     case G_ARRAY:  XSRETURN_YES;   break;
    }
    break;
   }
  }
 }
 XSRETURN_UNDEF;

void
reap(SV *hook, ...)
PROTOTYPE: &;$
PREINIT:
 I32 cxix;
 su_ud_reap *ud;
CODE:
 SU_GET_CONTEXT(1, 1);
 Newx(ud, 1, su_ud_reap);
 SU_UD_ORIGIN(ud)  = NULL;
 SU_UD_HANDLER(ud) = su_reap;
 ud->cb = newSVsv(hook);
 su_init(cxix, ud, 3);

void
localize(SV *sv, SV *val, ...)
PROTOTYPE: $$;$
PREINIT:
 I32 cxix;
 su_ud_localize *ud;
CODE:
 SU_GET_CONTEXT(2, 2);
 Newx(ud, 1, su_ud_localize);
 SU_UD_ORIGIN(ud)  = NULL;
 SU_UD_HANDLER(ud) = su_localize;
 SvREFCNT_inc(sv);
 ud->sv   = sv;
 ud->val  = newSVsv(val);
 ud->elem = NULL;
 su_init(cxix, ud, 3);

void
localize_elem(SV *sv, SV *elem, SV *val, ...)
PROTOTYPE: $$$;$
PREINIT:
 I32 cxix;
 su_ud_localize *ud;
CODE:
 SU_GET_CONTEXT(3, 3);
 Newx(ud, 1, su_ud_localize);
 SU_UD_ORIGIN(ud)  = NULL;
 SU_UD_HANDLER(ud) = su_localize;
 SvREFCNT_inc(sv);
 ud->sv   = sv;
 ud->val  = newSVsv(val);
 SvREFCNT_inc(elem);
 ud->elem = elem;
 su_init(cxix, ud, 4);

void
localize_delete(SV *sv, SV *elem, ...)
PROTOTYPE: $$;$
PREINIT:
 I32 cxix;
 su_ud_localize *ud;
CODE:
 SU_GET_CONTEXT(2, 2);
 Newx(ud, 1, su_ud_localize);
 SU_UD_ORIGIN(ud)  = NULL;
 SU_UD_HANDLER(ud) = su_localize;
 SvREFCNT_inc(sv);
 ud->sv   = sv;
 ud->val  = NULL;
 SvREFCNT_inc(elem);
 ud->elem = elem;
 su_init(cxix, ud, 4);
