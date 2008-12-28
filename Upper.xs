/* This file is part of the Scope::Upper Perl module.
 * See http://search.cpan.org/dist/Scope-Upper/ */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h" 
#include "XSUB.h"

#ifndef SU_DEBUG
# define SU_DEBUG 0
#endif

/* --- Compatibility ------------------------------------------------------- */

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

#define SU_HAS_PERL(R, V, S) (PERL_REVISION > (R) || (PERL_REVISION == (R) && (PERL_VERSION > (V) || (PERL_VERSION == (V) && (PERL_SUBVERSION >= (S))))))

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

STATIC I32 su_av_preeminent(pTHX_ AV *av, I32 key) {
#define su_av_preeminent(A, K) su_av_preeminent(aTHX_ (A), (K))
 MAGIC *mg;
 HV *stash;

 if (!av) return 0;
 if (SvCANEXISTDELETE(av))
  return av_exists(av, key);

 return 1;
}

#ifndef SAVEADELETE

typedef struct {
 AV *av;
 I32 key;
} su_ud_adelete;

STATIC void su_adelete(pTHX_ void *ud_) {
 su_ud_adelete *ud = ud_;

 av_delete(ud->av, ud->key, G_DISCARD);
 SvREFCNT_dec(ud->av);

 Safefree(ud);
}

STATIC void su_save_adelete(pTHX_ AV *av, I32 key) {
#define su_save_adelete(A, K) su_save_adelete(aTHX_ (A), (K))
 su_ud_adelete *ud;

 Newx(ud, 1, su_ud_adelete);
 ud->av  = av;
 ud->key = key;
 SvREFCNT_inc(av);

 SAVEDESTRUCTOR_X(su_adelete, ud);
}

#define SAVEADELETE(A, K) su_save_adelete((A), (K))

#endif /* SAVEADELETE */

STATIC void su_save_aelem(pTHX_ AV *av, I32 key, SV **svp, I32 preeminent) {
#define su_save_aelem(A, K, S, P) su_save_aelem(aTHX_ (A), (K), (S), (P))
 if (preeminent)
  save_aelem(av, key, svp);
 else
  SAVEADELETE(av, key);
}

/* ... Saving hash elements ................................................ */

STATIC I32 su_hv_preeminent(pTHX_ HV *hv, SV *keysv) {
#define su_hv_preeminent(H, K) su_hv_preeminent(aTHX_ (H), (K))
 MAGIC *mg;
 HV *stash;

 if (!hv) return 0;
 if (SvCANEXISTDELETE(hv) || mg_find((SV *) hv, PERL_MAGIC_env))
  return hv_exists_ent(hv, keysv, 0);

 return 1;
}

STATIC void su_save_helem(pTHX_ HV *hv, SV *keysv, SV **svp, I32 preeminent) {
#define su_save_helem(H, K, S, P) su_save_helem(aTHX_ (H), (K), (S), (P))
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

#define SU_UD_FREE(U) do { \
 if (SU_UD_ORIGIN(U)) Safefree(SU_UD_ORIGIN(U)); \
 Safefree(U); \
} while (0)

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
  if (!SvROK(val))
   goto assign;
  t = SvTYPE(SvRV(val));
  deref = 1;
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
  if (t == SVt_NULL) {
   if (SvROK(val) && !sv_isobject(val)) {
    t = SvTYPE(SvRV(val));
    deref = 1;
   } else {
    t = SvTYPE(val);
   }
  } else {
   ++s;
   --l;
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
    I32 idx  = SvIV(elem);
    AV *av   = GvAV(gv);
    I32 preeminent = su_av_preeminent(av, idx);
    SV **svp = av_fetch(av, idx, 1);
    if (!*svp || *svp == &PL_sv_undef) croak(PL_no_aelem, idx);
    su_save_aelem(av, idx, svp, preeminent);
    gv = (GV *) *svp;
    goto maybe_deref;
   } else
    save_ary(gv);
   break;
  case SVt_PVHV:
   if (elem) {
    HV *hv   = GvHV(gv);
    I32 preeminent = su_hv_preeminent(hv, elem);
    HE *he   = hv_fetch_ent(hv, elem, 1, 0);
    SV **svp = he ? &HeVAL(he) : NULL;
    if (!svp || *svp == &PL_sv_undef) croak("Modification of non-creatable hash value attempted, subscript \"%s\"", SvPV_nolen_const(*svp));
    su_save_helem(hv, elem, svp, preeminent);
    gv = (GV *) *svp;
    goto maybe_deref;
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
   if (deref)
    val = SvRV(val);
   break;
 }

 SU_D(PerlIO_printf(Perl_debug_log, "%p: savestack is now at %d, base at %d\n",
                                     ud, PL_savestack_ix,
                                         PL_scopestack[PL_scopestack_ix]));

assign:
 SvSetMagicSV((SV *) gv, val);

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

STATIC I32 su_init(pTHX_ I32 level, void *ud, I32 size) {
#define su_init(L, U, S) su_init(aTHX_ (L), (U), (S))
 I32 i, depth = 0, *origin;
 I32 cur, last, step;

 SU_D(PerlIO_printf(Perl_debug_log, "%p: ### init for level %d\n", ud, level));

 for (i = 0; i < level; ++i) {
  PERL_CONTEXT *cx = &cxstack[cxstack_ix - i];
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
 return depth;
}

#define SU_GET_LEVEL(A)  \
 if (items > A) {        \
  SV *lsv = ST(A);       \
  if (SvOK(lsv))         \
   level = SvUV(lsv);    \
  if (level < 0)         \
   XSRETURN(0);          \
 }                       \
 if (level > cxstack_ix) \
  level = cxstack_ix;

/* --- XS ------------------------------------------------------------------ */

MODULE = Scope::Upper            PACKAGE = Scope::Upper

PROTOTYPES: ENABLE

SV *
TOPLEVEL()
PROTOTYPE:
CODE:
 RETVAL = newSViv(cxstack_ix);
OUTPUT:
 RETVAL

void
reap(SV *hook, ...)
PROTOTYPE: &;$
PREINIT:
 I32 level = 0;
 su_ud_reap *ud;
CODE:
 SU_GET_LEVEL(1);
 Newx(ud, 1, su_ud_reap);
 SU_UD_ORIGIN(ud)  = NULL;
 SU_UD_HANDLER(ud) = su_reap;
 ud->cb = newSVsv(hook);
 LEAVE;
 if (level) {
  I32 depth = su_init(level, ud, 3);
  SU_D(PerlIO_printf(Perl_debug_log, "%p: set original destructor at %d [%d]\n",
                                      ud, PL_savestack_ix, depth));
  SAVEDESTRUCTOR_X(su_pop, ud);
 } else
  su_reap(ud);
 ENTER;

void
localize(SV *sv, SV *val, ...)
PROTOTYPE: $$;$
PREINIT:
 I32 level = 0;
 su_ud_localize *ud;
CODE:
 SU_GET_LEVEL(2);
 Newx(ud, 1, su_ud_localize);
 SU_UD_ORIGIN(ud)  = NULL;
 SU_UD_HANDLER(ud) = su_localize;
 SvREFCNT_inc(sv);
 ud->sv   = sv;
 ud->val  = newSVsv(val);
 ud->elem = NULL;
 LEAVE;
 if (level) {
  I32 depth = su_init(level, ud, 3);
  SU_D(PerlIO_printf(Perl_debug_log, "%p: set original destructor at %d [%d]\n",
                                      ud, PL_savestack_ix, depth));
  SAVEDESTRUCTOR_X(su_pop, ud);
 } else
  su_localize(ud);
 ENTER;

void
localize_elem(SV *sv, SV *elem, SV *val, ...)
PROTOTYPE: $$$;$
PREINIT:
 I32 level = 0;
 su_ud_localize *ud;
CODE:
 SU_GET_LEVEL(3);
 Newx(ud, 1, su_ud_localize);
 SU_UD_ORIGIN(ud)  = NULL;
 SU_UD_HANDLER(ud) = su_localize;
 SvREFCNT_inc(sv);
 ud->sv   = sv;
 ud->val  = newSVsv(val);
 SvREFCNT_inc(elem);
 ud->elem = elem;
 LEAVE;
 if (level) {
  I32 depth = su_init(level, ud, 4);
  SU_D(PerlIO_printf(Perl_debug_log, "%p: set original destructor at %d [%d]\n",
                                      ud, PL_savestack_ix, depth));
  SAVEDESTRUCTOR_X(su_pop, ud);
 } else
  su_localize(ud);
 ENTER;

