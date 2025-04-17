;;;; This file defines all the standard functions to be known
;;;; functions. Each function has type and side-effect information,
;;;; and may also have IR1 optimizers.

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB-C")

;;;; information for known functions:

(defknown coerce (t type-specifier) t
    ;; Note:
    ;; This is not FLUSHABLE because it's defined to signal errors.
    (movable)
  ;; :DERIVE-TYPE RESULT-TYPE-SPEC-NTH-ARG 2 ? Nope... (COERCE 1 'COMPLEX)
  ;; returns REAL/INTEGER, not COMPLEX.
  )
;; These each check their input sequence for type-correctness,
;; but not the output type specifier, because MAKE-SEQUENCE will do that.
(defknown list-to-vector* (list type-specifier) vector ())
(defknown vector-to-vector* (vector type-specifier) vector ())

;; FIXME: Is this really FOLDABLE? A counterexample seems to be:
;;  (LET ((S :S)) (VALUES (TYPE-OF S) (UNINTERN S 'KEYWORD) (TYPE-OF S) S))
;; Anyway, the TYPE-SPECIFIER type is more inclusive than the actual
;; possible return values. Most of the time it will be (OR LIST SYMBOL).
;; CLASS can be returned only when you've got an object whose class-name
;; does not properly name its class.
(defknown type-of (t) (or list symbol class)
  (foldable flushable))

;;; These can be affected by type definitions, so they're not FOLDABLE.
(defknown (sb-xc:upgraded-complex-part-type sb-xc:upgraded-array-element-type)
    (type-specifier &optional lexenv-designator) (or list symbol)
    (unsafely-flushable))

;;;; from the "Predicates" chapter:

;;; FIXME: Is it right to have TYPEP (and TYPE-OF, elsewhere; and
;;; perhaps SPECIAL-OPERATOR-P and others) be FOLDABLE in the
;;; cross-compilation host? After all, some type relationships (e.g.
;;; FIXNUMness) might be different between host and target. Perhaps
;;; this property should be protected by #-SB-XC-HOST? Perhaps we need
;;; 3-stage bootstrapping after all? (Ugh! It's *so* slow already!)
(defknown typep (t type-specifier &optional lexenv-designator) boolean
   ;; Unlike SUBTYPEP or UPGRADED-ARRAY-ELEMENT-TYPE and friends, this
   ;; seems to be FOLDABLE. Like SUBTYPEP, it's affected by type
   ;; definitions, but unlike SUBTYPEP, there should be no way to make
   ;; a TYPEP expression with constant arguments which doesn't return
   ;; an error before the type declaration (because of undefined
   ;; type). E.g. you can do
   ;;   (SUBTYPEP 'INTEGER 'FOO) => NIL, NIL
   ;;   (DEFTYPE FOO () T)
   ;;   (SUBTYPEP 'INTEGER 'FOO) => T, T
   ;; but the analogous
   ;;   (TYPEP 12 'FOO)
   ;;   (DEFTYPE FOO () T)
   ;;   (TYPEP 12 'FOO)
   ;; doesn't work because the first call is an error.
   ;;
   ;; (UPGRADED-ARRAY-ELEMENT-TYPE and UPGRADED-COMPLEX-PART-TYPE have
   ;; behavior like SUBTYPEP in this respect, not like TYPEP.)
   (foldable))
(defknown subtypep (type-specifier type-specifier &optional lexenv-designator)
  (values boolean boolean)
  ;; This is not FOLDABLE because its value is affected by type
  ;; definitions.
  ;;
  ;; FIXME: Is it OK to fold this when the types have already been
  ;; defined? Does the code inherited from CMU CL already do this?
  (unsafely-flushable))

(defknown (null symbolp atom consp listp numberp integerp rationalp floatp
                complexp characterp stringp bit-vector-p vectorp
                simple-vector-p simple-string-p simple-bit-vector-p arrayp
                packagep functionp compiled-function-p not)
  (t) boolean (movable foldable flushable))

(defknown (eq eql %eql/integer) (t t) boolean
  (movable foldable flushable commutative))
(defknown (equal equalp) (t t) boolean (foldable flushable recursive))

#+(or x86 x86-64 arm arm64)
(defknown fixnum-mod-p (t fixnum) boolean
  (movable foldable flushable always-translatable))


;;;; classes

(sb-xc:deftype name-for-class () t) ; FIXME: disagrees w/ LEGAL-CLASS-NAME-P
(defknown find-classoid (name-for-class &optional t)
  (or classoid null) ())
(defknown classoid-of (t) classoid (flushable))
(defknown layout-of (t) layout (flushable))
#+64-bit (defknown layout-depthoid (layout) fixnum (flushable always-translatable))
(defknown layout-depthoid-gt (layout integer) boolean (flushable))
(defknown copy-structure (structure-object) structure-object
  (flushable)
  :derive-type #'result-type-first-arg)

;;;; from the "Control Structure" chapter:

;;; This is not FLUSHABLE, since it's required to signal an error if
;;; unbound.
(defknown (symbol-value symeval) (symbol) t ()
  :derive-type #'symeval-derive-type)
(defknown about-to-modify-symbol-value (symbol t &optional t t) null
  ())
;;; From CLHS, "If the symbol is globally defined as a macro or a
;;; special operator, an object of implementation-dependent nature and
;;; identity is returned. If the symbol is not globally defined as
;;; either a macro or a special operator, and if the symbol is fbound,
;;; a function object is returned".  Our objects of
;;; implementation-dependent nature happen to be functions.
(defknown (symbol-function) (symbol) function ())

(defknown boundp (symbol) boolean (flushable))
(defknown fboundp ((or symbol cons)) boolean (unsafely-flushable))
(defknown special-operator-p (symbol) t
  ;; The set of special operators never changes.
  (movable foldable flushable))
(defknown set (symbol t) t ()
  :derive-type #'result-type-last-arg)
(defknown fdefinition ((or symbol cons)) function ())
(defknown %set-fdefinition ((or symbol cons) function) function ()
  :derive-type #'result-type-last-arg)
(defknown makunbound (symbol) symbol ()
  :derive-type #'result-type-first-arg)
(defknown fmakunbound ((or symbol cons)) (or symbol cons)
  ()
  :derive-type #'result-type-first-arg)
(defknown apply (function-designator t &rest t) *) ; ### Last arg must be List...
(defknown funcall (function-designator &rest t) *)

(defknown (mapcar maplist) (function-designator list &rest list) list
  (call))

;;; According to CLHS the result must be a LIST, but we do not check
;;; it.
(defknown (mapcan mapcon) (function-designator list &rest list) t
  (call))

(defknown (mapc mapl) (function-designator list &rest list) list (foldable call))

;;; We let VALUES-LIST be foldable, since constant-folding will turn
;;; it into VALUES. VALUES is not foldable, since MV constants are
;;; represented by a call to VALUES.
(defknown values (&rest t) * (movable flushable))
(defknown values-list (list) * (movable foldable unsafely-flushable))

;;;; from the "Macros" chapter:

(defknown macro-function (symbol &optional lexenv-designator)
  (or function null)
  (flushable))
(defknown (macroexpand macroexpand-1 %macroexpand %macroexpand-1)
    (t &optional lexenv-designator)
  (values form &optional boolean))

(defknown compiler-macro-function (t &optional lexenv-designator)
  (or function null)
  (flushable))

;;;; from the "Declarations" chapter:

(defknown proclaim (list) (values) (recursive))

;;;; from the "Symbols" chapter:

(defknown get (symbol t &optional t) t (flushable))
(defknown sb-impl::get3 (symbol t t) t (flushable))
(defknown remprop (symbol t) t)
(defknown symbol-plist (symbol) list (flushable))
(defknown getf (list t &optional t) t (foldable flushable))
(defknown get-properties (list list) (values t t list) (foldable flushable))
(defknown symbol-name (symbol) simple-string (movable foldable flushable))
(defknown make-symbol (string) symbol (flushable))
;; %make-symbol is the internal API, but the primitive object allocator
;; is %%make-symbol, because when immobile space feature is present,
;; we dispatch to either the C allocator or the Lisp allocator.
(defknown %make-symbol (fixnum simple-string) symbol (flushable))
(defknown sb-vm::%%make-symbol (simple-string) symbol (flushable))
(defknown copy-symbol (symbol &optional t) symbol (flushable))
(defknown gensym (&optional (or string unsigned-byte)) symbol ())
(defknown symbol-package (symbol) (or package null) (flushable))
(defknown keywordp (t) boolean (flushable))       ; If someone uninterns it...

;;;; from the "Packages" chapter:

(defknown gentemp (&optional string package-designator) symbol)

(defknown make-package (string-designator &key
                                          (:use list)
                                          (:nicknames list)
                                          ;; ### extensions...
                                          (:internal-symbols index)
                                          (:external-symbols index))
  package)
(defknown find-package (package-designator) (or package null)
  (flushable))
(defknown find-undeleted-package-or-lose (package-designator)
  package) ; not flushable
(defknown package-name (package-designator) (or simple-string null)
  (unsafely-flushable))
(defknown package-nicknames (package-designator) list (unsafely-flushable))
(defknown rename-package (package-designator package-designator &optional list)
  package)
(defknown package-use-list (package-designator) list (unsafely-flushable))
(defknown package-used-by-list (package-designator) list (unsafely-flushable))
(defknown package-shadowing-symbols (package-designator) list (unsafely-flushable))
(defknown list-all-packages () list (flushable))
(defknown intern (string &optional package-designator)
  (values symbol (member :internal :external :inherited nil))
  ())
(defknown find-symbol (string &optional package-designator)
  (values symbol (member :internal :external :inherited nil))
  (flushable))
(defknown (export import) (symbols-designator &optional package-designator)
  (eql t))
(defknown unintern (symbol &optional package-designator) boolean)
(defknown unexport (symbols-designator &optional package-designator) (eql t))
(defknown shadowing-import (symbols-designator &optional package-designator)
  (eql t))
(defknown shadow ((or symbol character string list) &optional package-designator)
  (eql t))
(defknown (use-package unuse-package)
  ((or list package-designator) &optional package-designator) (eql t))
(defknown find-all-symbols (string-designator) list (flushable))
;; private
(defknown package-iter-step (fixnum index simple-vector list)
  (values fixnum index simple-vector list symbol symbol))

;;;; from the "Numbers" chapter:

(defknown zerop (number) boolean (movable foldable flushable))
(defknown (plusp minusp) (real) boolean
  (movable foldable flushable))
(defknown (oddp evenp) (integer) boolean
  (movable foldable flushable))
(defknown (=) (number &rest number) boolean
  (movable foldable flushable commutative))
(defknown (/=) (number &rest number) boolean
  (movable foldable flushable))
(defknown (< > <= >=) (real &rest real) boolean
  (movable foldable flushable))
(defknown (max min) (real &rest real) real
  (movable foldable flushable))

(defknown (+ *) (&rest number) number
  (movable foldable flushable commutative))
(defknown - (number &rest number) number
  (movable foldable flushable))
(defknown / (number &rest number) number
  (movable foldable unsafely-flushable))
(defknown (1+ 1-) (number) number
  (movable foldable flushable))

(defknown (two-arg-* two-arg-+ two-arg-- two-arg-/)
  (number number) number
  ())

(defknown (two-arg-< two-arg-= two-arg->)
  (number number) boolean
  ())

(defknown (two-arg-gcd two-arg-lcm two-arg-and two-arg-ior two-arg-xor two-arg-eqv)
  (integer integer) integer
  ())

(defknown conjugate (number) number
  (movable foldable flushable))

(defknown gcd (&rest integer) unsigned-byte
  (movable foldable flushable))
(defknown sb-kernel::fixnum-gcd (fixnum fixnum) (integer 0 #.(1+ sb-xc:most-positive-fixnum))
    (movable foldable flushable))

(defknown lcm (&rest integer) unsigned-byte
    (movable foldable flushable))

#+sb-xc-host ; (See CROSS-FLOAT-INFINITY-KLUDGE.)
(defknown exp (number) irrational
  (movable foldable flushable recursive)
  :derive-type #'result-type-float-contagion)

#-sb-xc-host ; (See CROSS-FLOAT-INFINITY-KLUDGE.)
(defknown exp (number) irrational
  (movable foldable flushable recursive))

(defknown expt (number number) number
  (movable foldable flushable recursive))
(defknown log (number &optional real) irrational
  (movable foldable flushable recursive))
(defknown sqrt (number) irrational
  (movable foldable flushable))
(defknown isqrt (unsigned-byte) unsigned-byte
  (movable foldable flushable recursive))

(defknown (abs phase signum) (number) number
  (movable foldable flushable))
(defknown cis (real) (complex float)
  (movable foldable flushable))

#+sb-xc-host ; (See CROSS-FLOAT-INFINITY-KLUDGE.)
(progn
(defknown (sin cos) (number)
  (or (float $-1.0 $1.0) (complex float))
  (movable foldable flushable recursive)
  :derive-type #'result-type-float-contagion)

(defknown atan
  (number &optional real) irrational
  (movable foldable unsafely-flushable recursive)
  :derive-type #'result-type-float-contagion)

(defknown (tan sinh cosh tanh asinh)
  (number) irrational (movable foldable flushable recursive)
  :derive-type #'result-type-float-contagion)
) ; PROGN

#-sb-xc-host ; (See CROSS-FLOAT-INFINITY-KLUDGE.)
(progn
(defknown (sin cos) (number)
  (or (float $-1.0 $1.0) (complex float))
  (movable foldable flushable recursive))

(defknown atan
  (number &optional real) irrational
  (movable foldable unsafely-flushable recursive))

(defknown (tan sinh cosh tanh asinh)
  (number) irrational (movable foldable flushable recursive))
) ; PROGN

(defknown (asin acos acosh atanh)
  (number) irrational
  (movable foldable flushable recursive))

(defknown float (real &optional float) float
  (movable foldable flushable))

(defknown (rational) (real) rational
  (movable foldable flushable))

(defknown (rationalize) (real) rational
  (movable foldable flushable recursive))

(defknown (numerator denominator) (rational) integer
  (movable foldable flushable))

(defknown (floor ceiling round)
  (real &optional real) (values integer real)
  (movable foldable flushable))

(defknown truncate
  (real &optional real) (values integer real)
  (movable foldable flushable recursive))

(defknown %multiply-high (word word) word
    (movable foldable flushable))

(defknown (mod rem) (real real) real
  (movable foldable flushable))

(defknown (ffloor fceiling fround ftruncate)
  (real &optional real) (values float real)
  (movable foldable flushable))

(defknown decode-float (float) (values float float-exponent float)
  (movable foldable unsafely-flushable))
(defknown scale-float (float integer) float
  (movable foldable unsafely-flushable))
(defknown float-radix (float) float-radix
  (movable foldable unsafely-flushable))
;;; This says "unsafely flushable" as if to imply that there is a possibility
;;; of signaling a condition in safe code, but in practice we can never trap
;;; on a NaN because the implementation uses foo-FLOAT-BITS instead of
;;; performing a floating-point comparison. I think that is done on purpose,
;;; so at best the "unsafely-" is disingenuous, and at worst our code is wrong.
;;; e.g. the behavior if the first arg is a NaN is well-defined as we have it,
;;; but what about the second arg? We need some test cases around this.
(defknown float-sign (float &optional float) float
  (movable foldable unsafely-flushable))
(defknown (float-digits float-precision) (float) float-digits
  (movable foldable unsafely-flushable))
(defknown integer-decode-float (float)
    (values integer float-int-exponent (member -1 1))
    (movable foldable unsafely-flushable))

(defknown single-float-sign (single-float) single-float (movable foldable flushable))
(defknown single-float-copysign (single-float single-float)
  single-float (movable foldable flushable))

(defknown complex (real &optional real) number
  (movable foldable flushable))

(defknown (realpart imagpart) (number) real (movable foldable flushable))

(defknown (logior logxor logand logeqv) (&rest integer) integer
  (movable foldable flushable commutative))

(defknown (lognand lognor logandc1 logandc2 logorc1 logorc2)
          (integer integer) integer
  (movable foldable flushable))

(defknown boole (boole-code integer integer) integer
  (movable foldable flushable))

(defknown lognot (integer) integer (movable foldable flushable))
(defknown logtest (integer integer) boolean (movable foldable flushable commutative))
(defknown logbitp (unsigned-byte integer) boolean (movable foldable flushable))
(defknown ash (integer integer) integer
  (movable foldable flushable))
(defknown %ash/right ((or word sb-vm:signed-word) (mod #.sb-vm:n-word-bits))
  (or word sb-vm:signed-word)
  (movable foldable flushable always-translatable))
(defknown (logcount integer-length) (integer) bit-index
  (movable foldable flushable))
;;; FIXME: According to the ANSI spec, it's legal to use any
;;; nonnegative indices for BYTE arguments, not just BIT-INDEX. It's
;;; hard to come up with useful ways to do this, but it is possible to
;;; come up with *legal* ways to do this, so it would be nice
;;; to fix this so we comply with the spec.
(defknown byte (bit-index bit-index) byte-specifier
  (movable foldable flushable))
(defknown (byte-size byte-position) (byte-specifier) bit-index
  (movable foldable flushable))
(defknown ldb (byte-specifier integer) unsigned-byte (movable foldable flushable))
(defknown ldb-test (byte-specifier integer) boolean
  (movable foldable flushable))
(defknown mask-field (byte-specifier integer) unsigned-byte
  (movable foldable flushable))
(defknown dpb (integer byte-specifier integer) integer
  (movable foldable flushable))
(defknown deposit-field (integer byte-specifier integer) integer
  (movable foldable flushable))
(defknown random ((or (float ($0.0f0)) (integer 1)) &optional random-state)
  (or (float $0.0f0) (integer 0))
  ())
(defknown make-random-state (&optional (or random-state (member nil t)))
  random-state (flushable))
(defknown seed-random-state (&optional ; SBCL extension
                             (or (member nil t) random-state unsigned-byte
                                 (simple-array (unsigned-byte 8) (*))
                                 (simple-array (unsigned-byte 32) (*))))
  random-state (flushable))

(defknown random-state-p (t) boolean (movable foldable flushable))

;;;; from the "Characters" chapter:
(defknown (standard-char-p graphic-char-p alpha-char-p
                           upper-case-p lower-case-p both-case-p alphanumericp)
  (character) boolean (movable foldable flushable))

(defknown digit-char-p (character &optional (integer 2 36))
  (or (integer 0 35) null) (movable foldable flushable))

;; Character predicates: if the 2-argument predicate which underlies
;; the N-argument predicate unavoidably type-checks its 2 args,
;; then the N-argument form should not type-check anything
;; except in the degenerate case of 1 actual argument.
;; All of the case-sensitive functions have the check of the first arg
;; generated by the compiler, and successive args checked by hand.
;; The case-insensitive functions don't need any checks, since the underlying
;; two-arg case-insensitive function does it, except when it isn't called.
(defknown (char=)
  (character &rest character) boolean (movable foldable flushable commutative))

(defknown (char/= char< char> char<= char>= char-not-equal)
  (character &rest character) boolean (movable foldable flushable))
(defknown (char-equal char-lessp char-greaterp char-not-greaterp char-not-lessp)
  (character &rest character) boolean (movable foldable flushable))

(defknown (two-arg-char-equal)
    (character character) boolean (movable foldable flushable commutative))

(defknown (two-arg-char-not-equal
           two-arg-char-lessp
           two-arg-char-not-lessp
           two-arg-char-greaterp
           two-arg-char-not-greaterp)
    (character character) boolean (movable foldable flushable))

(defknown character (t) character (movable foldable unsafely-flushable))
(defknown char-code (character) char-code (movable foldable flushable))
(defknown (char-upcase char-downcase) (character) character
  (movable foldable flushable))
(defknown digit-char (unsigned-byte &optional (integer 2 36))
  (or character null) (movable foldable flushable))
(defknown char-int (character) char-code (movable foldable flushable))
(defknown char-name (character) (or simple-string null)
  (movable foldable flushable))
(defknown name-char (string-designator) (or character null)
  (movable foldable flushable))
(defknown code-char (char-code) character
  ;; By suppressing constant folding on CODE-CHAR when the
  ;; cross-compiler is running in the cross-compilation host vanilla
  ;; ANSI Common Lisp, we can use CODE-CHAR expressions to delay until
  ;; target Lisp run time the generation of CHARACTERs which aren't
  ;; STANDARD-CHARACTERs. That way, we don't need to rely on the host
  ;; Common Lisp being able to handle any characters other than those
  ;; guaranteed by the ANSI spec.
  (movable #-sb-xc-host foldable flushable))

;;;; from the "Sequences" chapter:

(defknown elt (proper-sequence index) t (foldable unsafely-flushable))

(defknown subseq (proper-sequence index &optional sequence-end) consed-sequence
  (flushable))

(defknown copy-seq (proper-sequence) consed-sequence (flushable)
  :derive-type (sequence-result-nth-arg 1 :preserve-dimensions t))

(defknown length (proper-sequence) index (foldable flushable dx-safe))

(defknown reverse (proper-sequence) consed-sequence (flushable)
  :derive-type (sequence-result-nth-arg 1 :preserve-dimensions t))

(defknown nreverse ((modifying sequence)) sequence (important-result)
  :derive-type (sequence-result-nth-arg 1 :preserve-dimensions t
                                          :preserve-vector-type t))

(defknown make-sequence (type-specifier index
                                        &key
                                        (:initial-element t))
  consed-sequence
  (movable)
  :derive-type (creation-result-type-specifier-nth-arg 1))

(defknown concatenate (type-specifier &rest proper-sequence) consed-sequence ()
  :derive-type (creation-result-type-specifier-nth-arg 1))

(defknown %concatenate-to-string (&rest sequence) simple-string
  (flushable))
(defknown %concatenate-to-base-string (&rest sequence) simple-base-string
  (flushable))
(defknown %concatenate-to-list (&rest sequence) list
    (flushable))
(defknown %concatenate-to-simple-vector (&rest sequence) simple-vector
  (flushable))
(defknown %concatenate-to-vector ((unsigned-byte #.sb-vm:n-widetag-bits) &rest sequence)
    vector
  (flushable))

(defknown map (type-specifier (function-designator ((nth-arg 2 :sequence t)
                                                    (rest-args :sequence t))
                                                   (nth-arg 0 :sequence-type t))
                              proper-sequence &rest proper-sequence)
  consed-sequence (call)
; :DERIVE-TYPE 'TYPE-SPEC-ARG1 ? Nope... (MAP NIL ...) returns NULL, not NIL.
  )
(defknown %map (type-specifier function-designator &rest sequence) consed-sequence (call))
(defknown %map-for-effect-arity-1 (function-designator sequence) null (call))
(defknown %map-to-list-arity-1 ((function-designator ((nth-arg 1 :sequence t))) sequence) list (flushable call))
(defknown %map-to-simple-vector-arity-1 ((function-designator ((nth-arg 1 :sequence t))) sequence) simple-vector
  (flushable call))

(defknown map-into ((modifying sequence)
                    (function-designator ((rest-args :sequence t))
                                         (nth-arg 0 :sequence t))
                    &rest proper-sequence)
  sequence
  (call)
  :derive-type #'result-type-first-arg)

(defknown #.(loop for info across sb-vm:*specialized-array-element-type-properties*
                  collect
                  (intern (concatenate 'string "VECTOR-MAP-INTO/"
                                       (string (sb-vm:saetp-primitive-type-name info)))
                          :sb-impl))
    (simple-array index index function list)
    index
    (call))

;;; returns the result from the predicate...
(defknown some (function-designator proper-sequence &rest proper-sequence) t
  (foldable unsafely-flushable call))

(defknown (every notany notevery) (function-designator proper-sequence &rest proper-sequence) boolean
  (foldable unsafely-flushable call))

(defknown reduce ((function-designator ((nth-arg 1 :sequence t :key :key)
                                        (nth-arg 1 :sequence t :key :key)))
                  proper-sequence &rest t &key (:from-end t)
                  (:start (inhibit-flushing index 0))
                  (:end (inhibit-flushing sequence-end nil))
                  (:initial-value t)
                  (:key (function-designator ((nth-arg 1 :sequence t)))))
  t
  (foldable flushable call))

(defknown fill ((modifying sequence) t &rest t &key
                (:start index) (:end sequence-end)) sequence
    ()
  :derive-type #'result-type-first-arg
  :result-arg 0)

(defknown replace ((modifying sequence) proper-sequence &rest t &key (:start1 index)
                   (:end1 sequence-end) (:start2 index) (:end2 sequence-end))
  sequence ()
  :derive-type #'result-type-first-arg
  :result-arg 0)

(defknown remove
    (t proper-sequence &rest t &key (:from-end t)
     (:test (function-designator ((nth-arg 0) (nth-arg 1 :sequence t :key :key))))
     (:test-not (function-designator ((nth-arg 0) (nth-arg 1 :sequence t :key :key))))
     (:start (inhibit-flushing index 0))
     (:end (inhibit-flushing sequence-end nil))
     (:count sequence-count)
     (:key (function-designator ((nth-arg 1 :sequence t)))))
  consed-sequence
  (flushable call)
  :derive-type (sequence-result-nth-arg 2))

(defknown substitute
  (t t proper-sequence &rest t &key (:from-end t)
     (:test (function-designator ((nth-arg 1) (nth-arg 2 :sequence t :key :key))))
     (:test-not (function-designator ((nth-arg 1) (nth-arg 2 :sequence t :key :key))))
     (:start (inhibit-flushing index 0))
     (:end (inhibit-flushing sequence-end nil))
     (:count sequence-count)
     (:key (function-designator ((nth-arg 2 :sequence t)))))
  consed-sequence
  (flushable call)
  :derive-type (sequence-result-nth-arg 3))

(defknown (remove-if remove-if-not)
  ((function-designator ((nth-arg 1 :sequence t :key :key))) proper-sequence
   &rest t &key (:from-end t)
   (:count sequence-count)
   (:start (inhibit-flushing index 0))
   (:end (inhibit-flushing sequence-end nil))
   (:key (function-designator ((nth-arg 1 :sequence t)))))
  consed-sequence
  (flushable call)
  :derive-type (sequence-result-nth-arg 2))

(defknown (substitute-if substitute-if-not)
  (t (function-designator ((nth-arg 2 :sequence t :key :key))) proper-sequence
     &rest t &key (:from-end t)
     (:start (inhibit-flushing index 0))
     (:end (inhibit-flushing sequence-end nil))
     (:count sequence-count)
     (:key (function-designator ((nth-arg 2 :sequence t)))))
  consed-sequence
  (flushable call)
  :derive-type (sequence-result-nth-arg 3))

(defknown delete
  (t (modifying sequence) &rest t &key (:from-end t)
     (:test (function-designator ((nth-arg 0) (nth-arg 1 :sequence t :key :key))))
     (:test-not (function-designator ((nth-arg 0) (nth-arg 1 :sequence t :key :key))))
     (:start index) (:end sequence-end)
     (:count sequence-count)
     (:key (function-designator ((nth-arg 1 :sequence t)))))
  sequence
  (call important-result)
  :derive-type (sequence-result-nth-arg 2))

(defknown nsubstitute
  (t t (modifying sequence) &rest t &key (:from-end t)
     (:test (function-designator ((nth-arg 1) (nth-arg 2 :sequence t :key :key))))
     (:test-not (function-designator ((nth-arg 1) (nth-arg 2 :sequence t :key :key))))
     (:start index) (:end sequence-end)
     (:count sequence-count)
     (:key (function-designator ((nth-arg 2 :sequence t)))))
  sequence
  (call)
  :derive-type (sequence-result-nth-arg 3))

(defknown (delete-if delete-if-not)
  ((function-designator ((nth-arg 1 :sequence t :key :key))) (modifying sequence)
   &rest t &key (:from-end t) (:start index)
   (:end sequence-end) (:count sequence-count)
   (:key (function-designator ((nth-arg 1 :sequence t)))))
  sequence
  (call important-result)
  :derive-type (sequence-result-nth-arg 2))

(defknown (nsubstitute-if nsubstitute-if-not)
  (t (function-designator ((nth-arg 2 :sequence t :key :key))) (modifying sequence)
     &rest t &key (:from-end t) (:start index)
     (:end sequence-end) (:count sequence-count)
     (:key (function-designator ((nth-arg 2 :sequence t)))))
  sequence
  (call)
  :derive-type (sequence-result-nth-arg 3))

(defknown remove-duplicates
  (proper-sequence &rest t &key
            (:test (function-designator ((nth-arg 0 :sequence t :key :key)
                                        (nth-arg 0 :sequence t :key :key))))
            (:test-not (function-designator ((nth-arg 0 :sequence t :key :key)
                                        (nth-arg 0 :sequence t :key :key))))
            (:start (inhibit-flushing index 0))
            (:end (inhibit-flushing sequence-end nil))
            (:from-end t)
            (:key (function-designator ((nth-arg 0 :sequence t)))))
  consed-sequence
  (flushable call)
  :derive-type (sequence-result-nth-arg 1))

(defknown delete-duplicates
  ((modifying sequence)
   &rest t &key
   (:test (function-designator ((nth-arg 0 :sequence t :key :key)
                                (nth-arg 0 :sequence t :key :key))))
   (:test-not (function-designator ((nth-arg 0 :sequence t :key :key)
                                    (nth-arg 0 :sequence t :key :key))))
   (:start index)
   (:from-end t) (:end sequence-end)
   (:key (function-designator ((nth-arg 0 :sequence t)))))
  sequence
  (call important-result)
  :derive-type (sequence-result-nth-arg 1))

(defknown find
  (t proper-sequence &rest t &key
     (:test (function-designator ((nth-arg 0) (nth-arg 1 :sequence t :key :key))))
     (:test-not (function-designator ((nth-arg 0) (nth-arg 1 :sequence t :key :key))))
     (:start (inhibit-flushing index 0))
     (:end (inhibit-flushing sequence-end nil))
     (:from-end t)
     (:key (function-designator ((nth-arg 1 :sequence t)))))
  t
  (foldable flushable call))

(defknown (find-if find-if-not)
  ((function-designator ((nth-arg 1 :sequence t :key :key))) proper-sequence
   &rest t &key (:from-end t)
   (:start (inhibit-flushing index 0))
   (:end (inhibit-flushing sequence-end nil))
   (:key (function-designator ((nth-arg 1 :sequence t)))))
  t
  (foldable flushable call))

(defknown position
 (t proper-sequence &rest t &key
    (:test (function-designator ((nth-arg 0) (nth-arg 1 :sequence t :key :key))))
    (:test-not (function-designator ((nth-arg 0) (nth-arg 1 :sequence t :key :key))))
    (:start (inhibit-flushing index 0))
    (:end (inhibit-flushing sequence-end nil))
    (:from-end t)
    (:key (function-designator ((nth-arg 1 :sequence t)))))
  (or (mod #.(1- sb-xc:array-dimension-limit)) null)
  (foldable flushable call))

(defknown (position-if position-if-not)
  ((function-designator ((nth-arg 1 :sequence t :key :key))) proper-sequence
   &rest t &key (:from-end t)
   (:start (inhibit-flushing index 0))
    (:end (inhibit-flushing sequence-end nil))
   (:key (function-designator ((nth-arg 1 :sequence t)))))
  (or (mod #.(1- sb-xc:array-dimension-limit)) null)
  (foldable flushable call))

(defknown (%bit-position/0 %bit-position/1) (simple-bit-vector t index index)
  (or (mod #.(1- sb-xc:array-dimension-limit)) null)
  (foldable flushable))
(defknown (%bit-pos-fwd/0 %bit-pos-fwd/1 %bit-pos-rev/0 %bit-pos-rev/1)
  (simple-bit-vector index index)
  (or (mod #.(1- sb-xc:array-dimension-limit)) null)
  (foldable flushable))
(defknown %bit-position (t simple-bit-vector t index index)
  (or (mod #.(1- sb-xc:array-dimension-limit)) null)
  (foldable flushable))
(defknown (%bit-pos-fwd %bit-pos-rev) (t simple-bit-vector index index)
  (or (mod #.(1- sb-xc:array-dimension-limit)) null)
  (foldable flushable))

(defknown count
  (t proper-sequence &rest t &key
     (:test (function-designator ((nth-arg 0) (nth-arg 1 :sequence t :key :key))))
     (:test-not (function-designator ((nth-arg 0) (nth-arg 1 :sequence t :key :key))))
     (:from-end t)
     (:start (inhibit-flushing index 0))
     (:end (inhibit-flushing sequence-end nil))
     (:key (function-designator ((nth-arg 1 :sequence t)))))
  index
  (foldable flushable call))

(defknown (count-if count-if-not)
  ((function-designator ((nth-arg 1 :sequence t :key :key))) proper-sequence
   &rest t &key (:from-end t)
   (:start (inhibit-flushing index 0))
   (:end (inhibit-flushing sequence-end nil))
   (:key (function-designator ((nth-arg 1 :sequence t)))))
  index
  (foldable flushable call))

(defknown (mismatch search)
  (proper-sequence proper-sequence &rest t &key (:from-end t)
   (:test (function-designator ((nth-arg 0 :sequence t :key :key)
                                (nth-arg 1 :sequence t :key :key))))
   (:test-not (function-designator ((nth-arg 0 :sequence t :key :key)
                                    (nth-arg 1 :sequence t :key :key))))
   (:start1 (inhibit-flushing index 0)) (:end1 (inhibit-flushing sequence-end nil))
   (:start2 (inhibit-flushing index 0)) (:end2 (inhibit-flushing sequence-end nil))
   (:key (function-designator ((or (nth-arg 0 :sequence t)
                                   (nth-arg 1 :sequence t))))))
  (or index null)
  (foldable flushable call))

;;; not FLUSHABLE, since vector sort guaranteed in-place...
(defknown (stable-sort sort)
  ((modifying sequence)
   (function-designator ((nth-arg 0 :sequence t :key :key)
                         (nth-arg 0 :sequence t :key :key)))
   &rest t
   &key (:key (function-designator ((nth-arg 0 :sequence t)))))
  sequence
  (call)
  :derive-type #'result-type-first-arg)
(defknown sb-impl::stable-sort-list (list function function) list
  (call important-result))
(defknown sb-impl::sort-vector (vector index index function (or function null))
  * ; SORT-VECTOR works through side-effect
  (call))

(defknown sb-impl::stable-sort-vector
  (vector function (or function null))
  vector
  (call))

(defknown sb-impl::stable-sort-simple-vector
  (simple-vector function (or function null))
  simple-vector
  (call))

(defknown merge (type-specifier (modifying sequence) (modifying sequence)
                (function-designator ((nth-arg 1 :sequence t :key :key)
                                      (nth-arg 2 :sequence t :key :key)))
                &key (:key (function-designator ((or (nth-arg 1 :sequence t)
                                                     (nth-arg 2 :sequence t))))))
  sequence
  (call important-result)
  :derive-type (creation-result-type-specifier-nth-arg 1))

(defknown read-sequence ((modifying sequence) stream
                         &key
                         (:start index)
                         (:end sequence-end))
  (index)
  ())

(defknown write-sequence (proper-sequence stream
                                          &key
                                          (:start index)
                                          (:end sequence-end))
  sequence
  (recursive)
  :derive-type #'result-type-first-arg)

;;;; from the "Manipulating List Structure" chapter:
(defknown (car cdr first rest)
  (list)
  t
  (foldable flushable))

;; Correct argument type restrictions for these functions are
;; complicated, so we just declare them to accept LISTs and suppress
;; flushing is safe code.
(defknown (caar cadr cdar cddr
                caaar caadr cadar caddr cdaar cdadr cddar cdddr
                caaaar caaadr caadar caaddr cadaar cadadr caddar cadddr
                cdaaar cdaadr cdadar cdaddr cddaar cddadr cdddar cddddr
                second third fourth fifth sixth seventh eighth ninth tenth)
  (list)
  t
  (foldable unsafely-flushable))

(defknown cons (t t) cons (movable flushable))

(defknown tree-equal
    (t t &key (:test (function-designator (t t)))
       (:test-not (function-designator (t t))))
    boolean
  (foldable flushable call))
(defknown endp (list) boolean (foldable flushable movable))
(defknown list-length (proper-or-circular-list) (or index null) (foldable unsafely-flushable))
(defknown (nth fast-&rest-nth) (unsigned-byte list) t (foldable flushable))
(defknown nthcdr (unsigned-byte list) t (foldable unsafely-flushable))

(defknown last (list &optional unsigned-byte) t (foldable flushable))
(defknown %last0 (list) t (foldable flushable))
(defknown %last1 (list) t (foldable flushable))
(defknown %lastn/fixnum (list (and unsigned-byte fixnum)) t (foldable flushable))
(defknown %lastn/bignum (list (and unsigned-byte bignum)) t (foldable flushable))

(defknown list (&rest t) list (movable flushable))
(defknown list* (t &rest t) t (movable flushable))
(defknown make-list (index &key (:initial-element t)) list
  (movable flushable))
(defknown %make-list (index t) list (movable flushable))

(defknown sb-impl::|List| (&rest t) list (movable flushable foldable))
(defknown sb-impl::|List*| (t &rest t) t (movable flushable foldable))
(defknown sb-impl::|Append| (&rest t) t (flushable foldable))
(defknown sb-impl::|Vector| (&rest t) simple-vector (flushable foldable))

;;; All but last must be of type LIST, but there seems to be no way to
;;; express that in this syntax.
(defknown append (&rest t) t (flushable)
  :call-type-deriver #'append-call-type-deriver)
(defknown sb-impl::append2 (list t) t (flushable)
  :call-type-deriver #'append-call-type-deriver)

(defknown copy-list (proper-or-dotted-list) list (flushable))
(defknown copy-alist (proper-list) list (flushable))
(defknown copy-tree (t) t (flushable recursive))
(defknown revappend (proper-list t) t (flushable))

(defknown nconc (&rest (modifying t :butlast t)) t ())

(defknown nreconc ((modifying list) t) t (important-result))
(defknown butlast (proper-or-dotted-list &optional unsigned-byte) list (flushable))
(defknown nbutlast ((modifying list) &optional unsigned-byte) list ())

(defknown ldiff (proper-or-dotted-list t) list (flushable))
(defknown (rplaca rplacd) ((modifying cons) t) cons ())

(defknown subst (t t t &key
                   (:test (function-designator ((nth-arg 1) (nth-arg 2 :sequence t :key :key))))
                   (:test-not (function-designator ((nth-arg 1) (nth-arg 2 :sequence t :key :key))))
                   (:key (function-designator ((nth-arg 2 :sequence t)))))
  t (flushable call))
(defknown nsubst (t t (modifying t) &key
                    (:test (function-designator ((nth-arg 1) (nth-arg 2 :sequence t :key :key))))
                    (:test-not (function-designator ((nth-arg 1) (nth-arg 2 :sequence t :key :key))))
                    (:key (function-designator ((nth-arg 2 :sequence t)))))
  t (call))

(defknown (subst-if subst-if-not)
  (t (function-designator ((nth-arg 2 :sequence t :key :key))) t
       &key (:key (function-designator ((nth-arg 2 :sequence t)))))
  t (flushable call))
(defknown (nsubst-if nsubst-if-not)
  (t (function-designator ((nth-arg 2 :sequence t :key :key))) (modifying t)
     &key (:key (function-designator ((nth-arg 2 :sequence t)))))
  t (call))

(defknown sublis
    (proper-list t &key
          (:test (function-designator ((nth-arg 1 :sequence t :key :key)
                                       (nth-arg 0 :sequence t))))
          (:test-not (function-designator ((nth-arg 1 :sequence t :key :key)
                                           (nth-arg 0 :sequence t))))
          (:key (function-designator ((nth-arg 1 :sequence t)))))
  t (flushable call))
(defknown nsublis
  (list (modifying t) &key
        (:test (function-designator ((nth-arg 1 :sequence t :key :key)
                                     (nth-arg 0 :sequence t))))
        (:test-not (function-designator ((nth-arg 1 :sequence t :key :key)
                                         (nth-arg 0 :sequence t))))
        (:key (function-designator ((nth-arg 1 :sequence t)))))
  t (flushable call))

(defknown member (t proper-list &key
                    (:test (function-designator ((nth-arg 0) (nth-arg 1 :sequence t :key :key))))
                    (:test-not (function-designator ((nth-arg 0) (nth-arg 1 :sequence t :key :key))))
                    (:key (function-designator ((nth-arg 1 :sequence t)))))
  list (foldable flushable call))
(defknown (member-if member-if-not)
    ((function-designator ((nth-arg 1 :sequence t :key :key))) proper-list
     &key (:key (function-designator ((nth-arg 1 :sequence t)))))
  list (foldable flushable call))

(defknown tailp (t list) boolean (foldable flushable))

(defknown adjoin (t proper-list &key
                    (:key (function-designator ((or (nth-arg 0)
                                                    (nth-arg 1 :sequence t)))))
                    (:test (function-designator ((nth-arg 0 :key :key)
                                                 (nth-arg 1 :sequence t :key :key))))
                    (:test-not (function-designator ((nth-arg 0 :key :key)
                                                     (nth-arg 1 :sequence t :key :key)))))
    cons (flushable call))

(defknown (union intersection set-difference set-exclusive-or)
  (proper-list proper-list &key (:key (function-designator ((or (nth-arg 0 :sequence t)
                                                  (nth-arg 1 :sequence t)))))
                  (:test (function-designator ((nth-arg 0 :sequence t :key :key)
                                               (nth-arg 1 :sequence t :key :key))))
                  (:test-not (function-designator ((nth-arg 0 :sequence t :key :key)
                                                   (nth-arg 1 :sequence t :key :key)))))
  list
  (foldable flushable call))

(defknown (nunion nintersection nset-difference nset-exclusive-or)
  ((modifying list) (modifying list)
   &key (:key (function-designator ((or (nth-arg 0 :sequence t)
                                        (nth-arg 1 :sequence t)))))
   (:test (function-designator ((nth-arg 0 :sequence t :key :key)
                                (nth-arg 1 :sequence t :key :key))))
   (:test-not (function-designator ((nth-arg 0 :sequence t :key :key)
                                    (nth-arg 1 :sequence t :key :key)))))
  list
  (foldable flushable call important-result))

(defknown subsetp
  (proper-list proper-list &key (:key (function-designator ((or (nth-arg 0 :sequence t)
                                                                (nth-arg 1 :sequence t)))))
               (:test (function-designator ((nth-arg 0 :sequence t :key :key)
                                            (nth-arg 1 :sequence t :key :key))))
               (:test-not (function-designator ((nth-arg 0 :sequence t :key :key)
                                                (nth-arg 1 :sequence t :key :key)))))
  boolean
  (foldable flushable call))

(defknown acons (t t t) cons (movable flushable))
(defknown pairlis (t t &optional t) list (flushable))

(defknown (rassoc assoc)
    (t proper-list &key
       (:key (function-designator ((nth-arg 1 :sequence t))))
       (:test (function-designator ((nth-arg 0)
                                    (nth-arg 1 :sequence t :key :key))))
       (:test-not (function-designator ((nth-arg 0)
                                        (nth-arg 1 :sequence t :key :key)))))
    list (foldable flushable call))
(defknown (assoc-if-not assoc-if rassoc-if rassoc-if-not)
    ((function-designator ((nth-arg 1 :sequence t :key :key))) proper-list
     &key (:key (function-designator ((nth-arg 1 :sequence t)))))
    list (foldable flushable call))

(defknown (memq assq) (t proper-list) list (foldable flushable))
(defknown (delq delq1) (t (modifying list)) list (flushable))

;;;; from the "Hash Tables" chapter:

(defknown make-hash-table
  (&key (:test function-designator) (:size unsigned-byte)
        (:rehash-size (or (integer 1) (float ($1.0))))
        (:rehash-threshold (real 0 1))
        (:hash-function (or null function-designator))
        (:weakness (member nil :key :value :key-and-value :key-or-value))
        (:synchronized t))
  hash-table
  (flushable))
(defknown hash-table-p (t) boolean (movable foldable flushable))
(defknown gethash (t hash-table &optional t) (values t boolean)
  (flushable)) ; not FOLDABLE, since hash table contents can change
(defknown sb-impl::gethash3 (t hash-table t) (values t boolean)
  (flushable)) ; not FOLDABLE, since hash table contents can change
(defknown %puthash (t (modifying hash-table) t) t ()
  :derive-type #'result-type-last-arg)
(defknown remhash (t (modifying hash-table)) boolean ())
(defknown maphash ((function-designator (t t)) hash-table) null (flushable call))
(defknown clrhash ((modifying hash-table)) hash-table ())
(defknown hash-table-count (hash-table) index (flushable))
(defknown hash-table-rehash-size (hash-table) (or index (single-float ($1.0)))
  (foldable flushable))
(defknown hash-table-rehash-threshold (hash-table) (single-float ($0.0) $1.0)
  (foldable flushable))
(defknown hash-table-size (hash-table) index (flushable))
(defknown hash-table-test (hash-table) symbol (foldable flushable))
(defknown sxhash (t) hash (foldable flushable))
(defknown psxhash (t &optional t) hash (foldable flushable))
(defknown hash-table-equalp (hash-table hash-table) boolean (foldable flushable))
;; To avoid emitting code to test for nil-function-returned
(defknown (sb-impl::signal-corrupt-hash-table
           sb-impl::signal-corrupt-hash-table-bucket)
 (t) nil ())

;;;; from the "Arrays" chapter

(defknown make-array ((or index list)
                      &key
                      (:element-type type-specifier)
                      (:initial-element t)
                      (:initial-contents t)
                      (:adjustable t)
                      (:fill-pointer (or index boolean))
                      (:displaced-to (or array null))
                      (:displaced-index-offset index))
  array (flushable))

(defknown %make-array ((or index list)
                       (unsigned-byte #.sb-vm:n-widetag-bits)
                       (mod #.sb-vm:n-word-bits)
                       &key
                       (:element-type type-specifier)
                       (:initial-element t)
                       (:initial-contents t)
                       (:adjustable t)
                       (:fill-pointer (or index boolean))
                       (:displaced-to (or array null))
                       (:displaced-index-offset index))
    array (flushable))

(defknown fill-data-vector (vector list sequence) vector ()
  :result-arg 0)

;; INITIAL-CONTENTS is the first argument to FILL-ARRAY because
;; of the possibility of source-transforming it for various recognized
;; contents after the source-transform for MAKE-ARRAY has run.
;; The original MAKE-ARRAY call might resemble either of:
;;   (MAKE-ARRAY DIMS :ELEMENT-TYPE (F) :INITIAL-CONTENTS (G))
;;   (MAKE-ARRAY DIMS :INITIAL-CONTENTS (F) :ELEMENT-TYPE (G))
;; and in general we must bind temporaries to preserve left-to-right
;; evaluation of F and G if they have side effects.
;; Now ideally :ELEMENT-TYPE will be a constant, so it doesn't matter
;; if it moves. But if INITIAL-CONTENTS were the second argument to FILL-ARRAY,
;; then the multi-dimensional array creation form would look like
;;  (FILL-ARRAY (allocate-array) initial-contents)
;; which would mean that if the user expressed the MAKE- call the
;; second way shown above, we would have to bind INITIAL-CONTENTS,
;; to ensure its evaluation before the allocation,
;; causing difficulty if doing any futher macro-like processing.
(defknown fill-array (sequence simple-array) (simple-array) (flushable)
  :result-arg 1)

(defknown vector (&rest t) simple-vector (flushable))

(defknown aref (array &rest index) t (foldable)
  :call-type-deriver #'array-call-type-deriver)
(defknown row-major-aref (array index) t (foldable)
  :call-type-deriver (lambda (call trusted)
                       (array-call-type-deriver call trusted nil t)))

(defknown array-element-type (array) (or list symbol)
  (foldable flushable))
(defknown array-rank (array) array-rank (foldable flushable))
;; FIXME: there's a fencepost bug, but for all practical purposes our
;; ARRAY-RANK-LIMIT is infinite, thus masking the bug. e.g. if the
;; exclusive limit on rank were 8, then your dimension numbers can
;; be in the range 0 through 6, not 0 through 7.
(defknown array-dimension (array array-rank) index (foldable flushable))
(defknown array-dimensions (array) list (foldable flushable))
(defknown array-in-bounds-p (array &rest integer) boolean (foldable flushable)
  :call-type-deriver #'array-call-type-deriver)
(defknown array-row-major-index (array &rest index) array-total-size
  (foldable flushable)
  :call-type-deriver #'array-call-type-deriver)
(defknown array-total-size (array) array-total-size (foldable flushable))
(defknown adjustable-array-p (array) boolean (movable foldable flushable))

(defknown svref (simple-vector index) t (foldable flushable))
(defknown bit ((array bit) &rest index) bit (foldable flushable))
(defknown sbit ((simple-array bit) &rest index) bit (foldable flushable))

;;; FIXME: MODIFYING for these is complicated.
(defknown (bit-and bit-ior bit-xor bit-eqv bit-nand bit-nor bit-andc1 bit-andc2
                   bit-orc1 bit-orc2)
  ((array bit) (array bit) &optional (or (array bit) (member t nil)))
  (array bit)
  ()
  #|:derive-type #'result-type-last-arg|#)

(defknown bit-not ((array bit) &optional (or (array bit) (member t nil)))
  (array bit)
  ()
  #|:derive-type #'result-type-last-arg|#)

(defknown bit-vector-= (bit-vector bit-vector) boolean
  (movable foldable flushable))

(defknown array-has-fill-pointer-p (array) boolean
  (movable foldable flushable))
(defknown fill-pointer (complex-vector) index
    (unsafely-flushable))
(defknown sb-impl::fill-pointer-error (t &optional t) nil)

(defknown vector-push (t (modifying complex-vector)) (or index null) ())
(defknown vector-push-extend (t (modifying complex-vector) &optional (and index (integer 1))) index
    ())
(defknown vector-pop ((modifying complex-vector)) t ())

;;; FIXME: complicated MODIFYING
;;; Also, an important-result warning could be provided if the array
;;; is known to be not expressly adjustable.
(defknown adjust-array
  (array (or index list) &key (:element-type type-specifier)
         (:initial-element t) (:initial-contents t)
         (:fill-pointer (or index boolean))
         (:displaced-to (or array null))
         (:displaced-index-offset index))
  array ())
;  :derive-type 'result-type-arg1) Not even close...

;;;; from the "Strings" chapter:

(defknown char (string index) character (foldable flushable))
(defknown schar (simple-string index) character (foldable flushable))

(defknown (string= string-equal)
  (string-designator string-designator &key
    (:start1 (inhibit-flushing index 0)) (:end1 (inhibit-flushing sequence-end nil))
    (:start2 (inhibit-flushing index 0)) (:end2 (inhibit-flushing sequence-end nil)))
  boolean
  (foldable flushable))

(defknown (string< string> string<= string>= string/= string-lessp
                   string-greaterp string-not-lessp string-not-greaterp
                   string-not-equal)
  (string-designator string-designator &key
   (:start1 (inhibit-flushing index 0)) (:end1 (inhibit-flushing sequence-end nil))
   (:start2 (inhibit-flushing index 0)) (:end2 (inhibit-flushing sequence-end nil)))
  (or index null)
  (foldable flushable))

(defknown (two-arg-string= two-arg-string-equal)
  (string-designator string-designator)
  boolean
  (foldable flushable))

(defknown (two-arg-string< two-arg-string> two-arg-string<= two-arg-string>=
           two-arg-string/= two-arg-string-lessp two-arg-string-greaterp
           two-arg-string-not-lessp two-arg-string-not-greaterp two-arg-string-not-equal)
  (string-designator string-designator)
  (or index null)
  (foldable flushable))

(defknown make-string (index &key (:element-type type-specifier)
                       (:initial-element character))
  simple-string (flushable))

(defknown (string-trim string-left-trim string-right-trim)
  (proper-sequence string-designator) string (flushable))

(defknown (string-upcase string-downcase string-capitalize)
  (string-designator &key
   (:start (inhibit-flushing index 0))
   (:end (inhibit-flushing sequence-end nil)))
  simple-string (flushable))

(defknown (nstring-upcase nstring-downcase nstring-capitalize)
  ((modifying string) &key (:start index) (:end sequence-end))
  string ()
  :derive-type #'result-type-first-arg)

(defknown string (string-designator) string (flushable))

;;;; internal non-keyword versions of string predicates:

(defknown (string<* string>* string<=* string>=* string/=*)
    (string-designator string-designator
                       (inhibit-flushing index 0) (inhibit-flushing sequence-end nil)
                       (inhibit-flushing index 0) (inhibit-flushing sequence-end nil))
  (or index null)
  (foldable flushable))

(defknown string=*
  (string-designator string-designator
                     (inhibit-flushing index 0) (inhibit-flushing sequence-end nil)
                     (inhibit-flushing index 0) (inhibit-flushing sequence-end nil))
  boolean
  (foldable flushable))

;;;; from the "Eval" chapter:

(defknown eval (t) * (recursive))
(defknown constantp (t &optional lexenv-designator) boolean
  (foldable flushable))

;;;; from the "Streams" chapter:

(defknown make-synonym-stream (symbol) stream (flushable))
(defknown make-broadcast-stream (&rest stream) stream (unsafely-flushable))
(defknown make-concatenated-stream (&rest stream) stream (unsafely-flushable))
(defknown make-two-way-stream (stream stream) stream (unsafely-flushable))
(defknown make-echo-stream (stream stream) stream (flushable))
(defknown make-string-input-stream (string &optional index sequence-end)
  sb-impl::string-input-stream
  (flushable))
(defknown make-string-output-stream (&key (:element-type type-specifier))
  sb-impl::string-output-stream
  (flushable))
(defknown get-output-stream-string (stream) simple-string ())
(defknown streamp (t) boolean (movable foldable flushable))
(defknown stream-element-type (stream) type-specifier ; can it return a CLASS?
  (movable foldable flushable))
(defknown stream-external-format (stream) t (flushable))
(defknown (output-stream-p input-stream-p) (stream) boolean
  (movable foldable flushable))
(defknown open-stream-p (stream) boolean (flushable))
(defknown close (stream &key (:abort t)) (eql t) ())
(defknown file-string-length (ansi-stream (or string character))
  (or unsigned-byte null)
  (flushable))

;;;; from the "Input/Output" chapter:

;;; (The I/O functions are given effects ANY under the theory that
;;; code motion over I/O operations is particularly confusing and not
;;; very important for efficiency.)

(defknown copy-readtable (&optional (or readtable null) (or readtable null))
  readtable
  ())
(defknown readtablep (t) boolean (movable foldable flushable))

(defknown set-syntax-from-char
  (character character &optional readtable (or readtable null)) (eql t)
  ())


(defknown set-macro-character (character (function-designator (t t) * :no-function-conversion t)
                               &optional t (or readtable null))
  (eql t)
  (call))
(defknown get-macro-character (character &optional (or readtable null))
  (values function-designator boolean) (flushable))

(defknown make-dispatch-macro-character (character &optional t readtable)
  (eql t) ())
;;; FIXME: (function-designator ...) causes a style warning in the :UNICODE-DISPATCH-MACROS
;;; test in reader.impure.lisp
;;;   The function NIL is called by SET-DISPATCH-MACRO-CHARACTER with three arguments, but wants exactly two.
(defknown set-dispatch-macro-character
  (character character (function-designator (t t t) * :no-function-conversion t)
   &optional (or readtable null)) (eql t)
  (call))
(defknown get-dispatch-macro-character
  (character character &optional (or readtable null)) (or function-designator null)
  ())

(defknown copy-pprint-dispatch
  (&optional (or sb-pretty:pprint-dispatch-table null))
  sb-pretty:pprint-dispatch-table
  ())
(defknown pprint-dispatch
  (t &optional (or sb-pretty:pprint-dispatch-table null))
  (values function-designator boolean)
  ())
(defknown (pprint-fill pprint-linear)
  (stream-designator t &optional t t)
  null
  ())
(defknown pprint-tabular
  (stream-designator t &optional t t unsigned-byte)
  null
  ())
(defknown pprint-indent
  ((member :block :current) real &optional stream-designator)
  null
  ())
(defknown pprint-newline
  ((member :linear :fill :miser :mandatory) &optional stream-designator)
  null
  ())
(defknown pprint-tab
  ((member :line :section :line-relative :section-relative)
   unsigned-byte unsigned-byte &optional stream-designator)
  null
  ())
(defknown set-pprint-dispatch
  (type-specifier (function-designator (t t) * :no-function-conversion t)
   &optional real sb-pretty:pprint-dispatch-table)
  null
  (call))

;;; may return any type due to eof-value...
;;; and because READ generally returns anything.
(defknown (read read-preserving-whitespace)
  (&optional stream-designator t t t) t ())

(defknown read-char (&optional stream-designator t t t) t ()
  :derive-type (read-elt-type-deriver nil 'character nil))
(defknown read-char-no-hang (&optional stream-designator t t t) t ()
  :derive-type (read-elt-type-deriver nil 'character t))

(defknown read-delimited-list (character &optional stream-designator t) list ())
;; FIXME: add a type-deriver => (values (or string eof-value) boolean)
(defknown read-line (&optional stream-designator t t t) (values t boolean) ())
(defknown unread-char (character &optional stream-designator) t ())
(defknown peek-char (&optional (or character (member nil t))
                               stream-designator t t t) t
  ()
  :derive-type (read-elt-type-deriver t 'character nil))

(defknown listen (&optional stream-designator) boolean (flushable))

(defknown clear-input (&optional stream-designator) null ())

(defknown read-from-string
  (string &optional t t
          &key
          (:start index)
          (:end sequence-end)
          (:preserve-whitespace t))
  (values t index))
(defknown parse-integer
  (string &key
          (:start index)
          (:end sequence-end)
          (:radix (integer 2 36))
          (:junk-allowed t))
  (values (or integer null ()) index))

(defknown read-byte (stream &optional t t) t ()
  :derive-type (read-elt-type-deriver nil 'integer nil))

(defknown (prin1 print princ) (t &optional stream-designator)
  t
  (any)
  :derive-type #'result-type-first-arg)

(defknown output-object (t stream) null (any))
(defknown %write (t stream-designator) t (any))

(defknown (pprint) (t &optional stream-designator) (values)
  ())

(macrolet
    ((deffrob (name keys returns attributes &rest more)
       `(defknown ,name
            (t &key ,@keys
               (:escape t)
               (:radix t)
               (:base (integer 2 36))
               (:circle t)
               (:pretty t)
               (:readably t)
               (:level (or unsigned-byte null))
               (:length (or unsigned-byte null))
               (:case t)
               (:array t)
               (:gensym t)
               (:lines (or unsigned-byte null))
               (:right-margin (or unsigned-byte null))
               (:miser-width (or unsigned-byte null))
               (:pprint-dispatch t)
               (:suppress-errors t))
          ,returns ,attributes ,@more)))
  (deffrob write ((:stream stream-designator)) t (any)
    :derive-type #'result-type-first-arg)
;;; xxx-TO-STRING functions are not foldable because they depend on
;;; the dynamic environment, the state of the pretty printer dispatch
;;; table, and probably other run-time factors.
  (deffrob write-to-string () simple-string
           (unsafely-flushable)))

(defknown (prin1-to-string princ-to-string) (t) simple-string (unsafely-flushable))
(defknown sb-impl::stringify-object (t) simple-string)

(defknown write-char (character &optional stream-designator) character ()
  :derive-type #'result-type-first-arg)

(defknown (write-string write-line)
  (string &optional stream-designator &key (:start index) (:end sequence-end))
  string
  ()
  :derive-type #'result-type-first-arg)

(defknown (terpri finish-output force-output clear-output)
  (&optional stream-designator) null
  ())

(defknown fresh-line (&optional stream-designator) boolean ())

(defknown write-byte (integer stream) integer ()
  :derive-type #'result-type-first-arg)

;;; FIXME: complicated MODIFYING
(defknown format ((or (member nil t) stream string)
                  (or string function) &rest t)
  (or string null)
    ())
(defknown sb-format::format-error* (string list &rest t &key &allow-other-keys)
    nil)
(defknown sb-format::format-error (string &rest t) nil)
(defknown sb-format::format-error-at* ((or null string) (or null index) string list
                                       &rest t &key &allow-other-keys)
    nil)
(defknown sb-format::format-error-at ((or null string) (or null index) string
                                      &rest t)
    nil)
(defknown sb-format::args-exhausted (string integer) nil)

(defknown (y-or-n-p yes-or-no-p) (&optional (or string null function) &rest t) boolean
  ())

;;;; from the "File System Interface" chapter:

;;; (No pathname functions are FOLDABLE because they all potentially
;;; depend on *DEFAULT-PATHNAME-DEFAULTS*, e.g. to provide a default
;;; host when parsing a namestring. They are not FLUSHABLE because
;;; parsing of a PATHNAME-DESIGNATOR might signal an error.)

(defknown wild-pathname-p (pathname-designator
                           &optional
                           (member nil :host :device
                                   :directory :name
                                   :type :version))
  generalized-boolean
  (recursive))

(defknown pathname-match-p (pathname-designator pathname-designator)
  generalized-boolean
  ())

(defknown translate-pathname (pathname-designator
                              pathname-designator
                              pathname-designator &key)
  pathname
  ())

(defknown logical-pathname (pathname-designator) logical-pathname ())
(defknown translate-logical-pathname (pathname-designator &key) pathname
  (recursive))
(defknown load-logical-pathname-translations (string) t ())
(defknown logical-pathname-translations (logical-host-designator) list ())

(defknown pathname (pathname-designator) pathname ())
(defknown truename (pathname-designator) pathname ())

(defknown parse-namestring
  (pathname-designator &optional
                       (or list host string (member :unspecific))
                       pathname-designator
                       &key
                       (:start index)
                       (:end sequence-end)
                       (:junk-allowed t))
  (values (or pathname null) sequence-end)
  (recursive))

(defknown merge-pathnames
  (pathname-designator &optional pathname-designator pathname-version)
  pathname
  ())

(defknown make-pathname
 (&key (:defaults pathname-designator)
       (:host (or string pathname-host))
       (:device (or string pathname-device))
       (:directory (or pathname-directory string (member :wild)))
       (:name (or pathname-name string (member :wild)))
       (:type (or pathname-type string (member :wild)))
       (:version pathname-version) (:case pathname-component-case))
  pathname (unsafely-flushable))

(defknown pathnamep (t) boolean (movable flushable))

(defknown pathname-host (pathname-designator
                         &key (:case pathname-component-case))
  pathname-host (flushable))
(defknown pathname-device (pathname-designator
                           &key (:case pathname-component-case))
  pathname-device (flushable))
(defknown pathname-directory (pathname-designator
                              &key (:case pathname-component-case))
  pathname-directory (flushable))
(defknown pathname-name (pathname-designator
                         &key (:case pathname-component-case))
  pathname-name (flushable))
(defknown pathname-type (pathname-designator
                         &key (:case pathname-component-case))
  pathname-type (flushable))
(defknown pathname-version (pathname-designator)
  pathname-version (flushable))

(defknown pathname= (pathname pathname) boolean (movable foldable flushable))

(defknown (namestring file-namestring directory-namestring host-namestring)
  (pathname-designator) (or simple-string null)
  (unsafely-flushable))

(defknown enough-namestring (pathname-designator &optional pathname-designator)
  simple-string
  (unsafely-flushable))

(defknown user-homedir-pathname (&optional t) pathname (flushable))

(defknown open
  (pathname-designator &key
                       (:class symbol)
                       (:direction (member :input :output :io :probe))
                       (:element-type type-specifier)
                       (:if-exists (member :error :new-version :rename
                                           :rename-and-delete :overwrite
                                           :append :supersede nil))
                       (:if-does-not-exist (member :error :create nil))
                       (:external-format external-format-designator)
                       #+win32 (:overlapped t))
  (or stream null))

(defknown rename-file (pathname-designator filename)
  (values pathname pathname pathname))
(defknown delete-file (pathname-designator) (eql t))
(defknown probe-file (pathname-designator) (or pathname null) ())
(defknown file-write-date (pathname-designator) (or unsigned-byte null)
  ())
(defknown file-author (pathname-designator) (or simple-string null)
  ())

(defknown file-position (stream &optional
                                (or unsigned-byte (member :start :end)))
  (or unsigned-byte (member t nil)))
(defknown file-length ((or file-stream synonym-stream broadcast-stream)) (or unsigned-byte null) (unsafely-flushable))

(defknown load
  ((or filename stream)
   &key
   (:verbose t)
   (:print t)
   (:if-does-not-exist t)
   (:external-format external-format-designator))
  boolean)

(defknown directory (pathname-designator &key (:resolve-symlinks t))
  list ())

;;;; from the "Conditions" chapter:

(defknown (signal warn) (condition-designator-head &rest t) null)
(defknown error (condition-designator-head &rest t) nil)
(defknown cerror (format-control condition-designator-head &rest t) null)
(defknown invalid-method-error (t format-control &rest t) *) ; FIXME: first arg is METHOD
(defknown method-combination-error (format-control &rest t) *)
(defknown assert-error (t &rest t) null)
(defknown check-type-error (t t type-specifier &optional (or null string)) t)
(defknown invoke-debugger (condition) nil)
(defknown break (&optional format-control &rest t) null)
(defknown make-condition (type-specifier &rest t) condition ())
(defknown compute-restarts (&optional (or condition null)) list)
(defknown find-restart (restart-designator &optional (or condition null))
  (or restart null))
(defknown invoke-restart (restart-designator &rest t) *)
(defknown invoke-restart-interactively (restart-designator) *)
(defknown restart-name (restart) symbol)
(defknown (abort muffle-warning) (&optional (or condition null)) nil)
(defknown continue (&optional (or condition null)) null)
(defknown (store-value use-value) (t &optional (or condition null))
  null)

;;; and analogous SBCL extension:
(defknown sb-impl::%failed-aver (t) nil)
(defknown sb-impl::unreachable () nil)
(defknown bug (t &rest t) nil) ; never returns
(defknown simple-reader-error (stream string &rest t) nil)
(defknown sb-kernel:reader-eof-error (stream string) nil)


;;;; from the "Miscellaneous" Chapter:

(defknown compile ((or symbol cons) &optional (or list function))
  (values (or function symbol cons) boolean boolean))

(defknown compile-file
  (pathname-designator
   &key

   ;; ANSI options
   (:output-file (or pathname-designator
                     null
                     ;; FIXME: This last case is a non-ANSI hack.
                     (member t)))
   (:verbose t)
   (:print t)
   (:external-format external-format-designator)

   ;; extensions
   (:trace-file t)
   (:block-compile t)
   (:emit-cfasl t))
  (values (or pathname null) boolean boolean))

(defknown (compile-file-pathname)
  (pathname-designator &key (:output-file (or pathname-designator
                                              null
                                              (member t)))
                       &allow-other-keys)
  pathname)

(defknown disassemble ((or extended-function-designator
                           (cons (member lambda))
                           code-component)
                       &key (:stream stream) (:use-labels t))
  null)

(defknown describe (t &optional (or stream (member t nil))) (values))
(defknown function-lambda-expression (function) (values t boolean t))
(defknown inspect (t) (values))
(defknown room (&optional (member t nil :default)) (values))
(defknown ed (&optional (or symbol cons filename))
  t)
(defknown dribble (&optional filename &key (:if-exists t)) (values))

(defknown apropos      (string-designator &optional package-designator t) (values))
(defknown apropos-list (string-designator &optional package-designator t) list
  (flushable recursive))

(defknown get-decoded-time ()
  (values (integer 0 59) (integer 0 59) (integer 0 23) (integer 1 31)
          (integer 1 12) unsigned-byte (integer 0 6) boolean (rational -24 24))
  (flushable))

(defknown get-universal-time () unsigned-byte (flushable))

(defknown decode-universal-time
          (unsigned-byte &optional (or null (rational -24 24)))
  (values (integer 0 59) (integer 0 59) (integer 0 23) (integer 1 31)
          (integer 1 12) unsigned-byte (integer 0 6) boolean (rational -24 24))
  (flushable))

(defknown encode-universal-time
  ((integer 0 59) (integer 0 59) (integer 0 23) (integer 1 31)
   (integer 1 12) unsigned-byte &optional (or null (rational -24 24)))
  unsigned-byte
  (flushable))

(defknown (get-internal-run-time get-internal-real-time)
  () internal-time (flushable))

(defknown sleep ((real 0)) null ())

(defknown call-with-timing (function-designator function-designator &rest t) *
  (call))

;;; Even though ANSI defines LISP-IMPLEMENTATION-TYPE and
;;; LISP-IMPLEMENTATION-VERSION to possibly punt and return NIL, we
;;; know that there's no valid reason for our implementations to ever
;;; do so, so we can safely guarantee that they'll return strings.
(defknown (lisp-implementation-type lisp-implementation-version)
  () simple-string (flushable))

;;; For any of these functions, meaningful information might not be
;;; available, so -- unlike the related LISP-IMPLEMENTATION-FOO
;;; functions -- these really can return NIL.
(defknown (machine-type machine-version machine-instance
           software-type software-version
           short-site-name long-site-name)
  () (or simple-string null) (flushable))

(defknown identity (t) t (movable foldable flushable)
  :derive-type #'result-type-first-arg)

(defknown constantly (t) function (movable flushable))
(defknown complement (function) function (movable flushable))

;;;; miscellaneous extensions

(defknown (symbol-global-value sym-global-val) (symbol) t ()
  :derive-type #'symeval-derive-type)
(defknown set-symbol-global-value (symbol t) t ()
  :derive-type #'result-type-last-arg)

(defknown get-bytes-consed () unsigned-byte (flushable))
(defknown mask-signed-field ((integer 0 *) integer) integer
          (movable flushable foldable))

(defknown array-storage-vector (array) (simple-array * (*))
    (any))

;;;; magical compiler frobs

(defknown %rest-values (t t t) * (always-translatable))
(defknown %rest-ref (t t t t &optional boolean) * (always-translatable))
(defknown %rest-length (t t t) * (always-translatable))
(defknown %rest-null (t t t t) * (always-translatable))
(defknown %rest-true (t t t) * (always-translatable))

(defknown %unary-truncate/single-float (single-float) integer (movable foldable flushable))
(defknown %unary-truncate/double-float (double-float) integer (movable foldable flushable))

;;; We can't fold this in general because of SATISFIES. There is a
;;; special optimizer anyway.
(defknown %typep (t (or type-specifier ctype)) boolean (movable flushable))
(defknown %instance-typep (t (or type-specifier ctype)) boolean
  (movable flushable always-translatable))
;;; We should never emit a call to %typep-wrapper
(defknown %typep-wrapper (t t (or type-specifier ctype)) t
  (movable flushable always-translatable))
(defknown %type-constraint (t (or type-specifier ctype)) t
    (always-translatable))

;;; An identity wrapper to avoid complaints about constant modification
(defknown ltv-wrapper (t) t
  (movable flushable always-translatable)
  :derive-type #'result-type-first-arg)

(defknown %cleanup-point (&rest t) t)
(defknown %special-bind (t t) t)
(defknown %special-unbind (&rest symbol) t)
(defknown %listify-rest-args (t index) list (flushable))
(defknown %more-arg-context (t t) (values t index) (flushable))
(defknown %more-arg (t index) t)
#+stack-grows-downward-not-upward
;;; FIXME: The second argument here should really be NEGATIVE-INDEX, but doing that
;;; breaks the build, and I cannot seem to figure out why. --NS 2006-06-29
(defknown %more-kw-arg (t fixnum) (values t t))
(defknown %more-arg-values (t index index) * (flushable))

(defknown %verify-arg-count (index index) (values))

(defknown %arg-count-error (t) nil)
(defknown %local-arg-count-error (t t) nil)
(defknown %unknown-values () *)
(defknown %catch (t t) t)
(defknown %unwind-protect (t t) t)
(defknown (%catch-breakup %unwind-protect-breakup) () t)
(defknown %lexical-exit-breakup (t) t)
(defknown %continue-unwind (t t t) nil)
(defknown %throw (t &rest t) nil) ; This is MV-called.
(defknown %nlx-entry (t) *)
(defknown %%primitive (t t &rest t) *)
(defknown %pop-values (t) t)
(defknown %nip-values (t t &rest t) (values))
(defknown %dummy-dx-alloc (t t) t)
(defknown %allocate-closures (t) *)
(defknown %type-check-error (t t t) nil)
(defknown %type-check-error/c (t t t) nil)

;; FIXME: This function does not return, but due to the implementation
;; of FILTER-LVAR we cannot write it here.
(defknown (%compile-time-type-error %compile-time-type-style-warn) (t t t t t t) *)
(defknown (etypecase-failure ecase-failure) (t t) nil)

(defknown %odd-key-args-error () nil)
(defknown %unknown-key-arg-error (t t) nil)
(defknown (%ldb %mask-field) (bit-index bit-index integer) unsigned-byte
  (movable foldable flushable))
(defknown (%dpb %deposit-field) (integer bit-index bit-index integer) integer
  (movable foldable flushable))
(defknown %negate (number) number (movable foldable flushable))
(defknown (%check-bound check-bound) (array index t) index
  (dx-safe))
(defknown data-vector-ref (simple-array index) t
  (foldable unsafely-flushable always-translatable))
(defknown data-vector-ref-with-offset (simple-array fixnum fixnum) t
  (foldable unsafely-flushable always-translatable))
(defknown data-nil-vector-ref (simple-array index) nil
  (always-translatable))
(defknown data-vector-set (array index t) t
  (always-translatable))
(defknown data-vector-set-with-offset (array fixnum fixnum t) t
  (always-translatable))
(defknown hairy-data-vector-ref (array index) t (foldable))
(defknown hairy-data-vector-set (array index t) t ())
(defknown hairy-data-vector-ref/check-bounds (array index) t (foldable))
(defknown hairy-data-vector-set/check-bounds (array index t) t ())
(defknown %caller-frame () t (flushable))
(defknown %caller-pc () system-area-pointer (flushable))
(defknown %with-array-data (array index (or index null))
  (values (simple-array * (*)) index index index)
  (foldable flushable))
(defknown %with-array-data/fp (array index (or index null))
  (values (simple-array * (*)) index index index)
  (foldable flushable))
(defknown %set-symbol-package (symbol t) t ())
(defknown (%coerce-callable-to-fun %coerce-callable-for-call)
    (function-designator)
    function (flushable))
(defknown array-bounding-indices-bad-error (t t t) nil)
(defknown sequence-bounding-indices-bad-error (t t t) nil)
(defknown %find-position
    (t sequence t index sequence-end (function (t)) (function (t t)))
  (values t (or index null))
  (flushable call))
(defknown (%find-position-if %find-position-if-not)
  (function sequence t index sequence-end function)
  (values t (or index null))
  (call))
(defknown effective-find-position-test (function-designator function-designator)
  function
  (flushable foldable))
(defknown effective-find-position-key (function-designator)
  function
  (flushable foldable))

(defknown (%adjoin %adjoin-eq)
    (t list)
    list
    (flushable))

(defknown (%member %member-eq
           %assoc %assoc-eq %rassoc %rassoc-eq)
    (t list)
    list
    (foldable flushable))

(defknown (%adjoin-key %adjoin-key-eq)
    (t list (function (t)))
    list
    (flushable call))

(defknown (%member-key %member-key-eq
           %assoc-key %assoc-key-eq %rassoc-key %rassoc-key-eq)
  (t list (function (t)))
  list
  (foldable flushable call))

(defknown (%assoc-if %assoc-if-not %rassoc-if %rassoc-if-not
           %member-if %member-if-not)
  ((function (t)) list)
  list
  (foldable flushable call))

(defknown (%assoc-if-key %assoc-if-not-key %rassoc-if-key %rassoc-if-not-key
           %member-if-key %member-if-not-key)
  ((function (t)) list (function (t)))
  list
  (foldable flushable call))

(defknown (%adjoin-test %adjoin-test-not)
    (t list (function (t t)))
    list
    (flushable call))

(defknown (%member-test %member-test-not
           %assoc-test %assoc-test-not
           %rassoc-test %rassoc-test-not)
    (t list (function (t t)))
    list
    (foldable flushable call))

(defknown (%adjoin-key-test %adjoin-key-test-not)
    (t list (function (t)) (function (t t)))
    list
    (flushable call))

(defknown (%member-key-test %member-key-test-not
           %assoc-key-test %assoc-key-test-not
           %rassoc-key-test %rassoc-key-test-not)
    (t list (function (t)) (function (t t)))
    list
    (foldable flushable call))

(defknown %check-vector-sequence-bounds (vector index sequence-end)
  index
  (unwind))

;;;; SETF inverses

(defknown (setf aref) (t (modifying array) &rest index) t ()
  :call-type-deriver (lambda (call trusted)
                       (array-call-type-deriver call trusted t)))
(defknown %set-row-major-aref ((modifying array) index t) t ()
  :call-type-deriver (lambda (call trusted)
                       (array-call-type-deriver call trusted t t)))
(defknown (%rplaca %rplacd) ((modifying cons) t) t ()
  :derive-type #'result-type-last-arg)
(defknown %put (symbol t t) t ())
(defknown %setelt ((modifying sequence) index t) t ()
  :derive-type #'result-type-last-arg)
(defknown %svset ((modifying simple-vector) index t) t ())
(defknown (setf bit) (bit (modifying (array bit)) &rest index) bit ())
(defknown (setf sbit) (bit (modifying (simple-array bit)) &rest index) bit ())
(defknown %charset ((modifying string) index character) character ())
(defknown %scharset ((modifying simple-string) index character) character ())
(defknown %set-symbol-value (symbol t) t ())
(defknown (setf symbol-function) (function symbol) function ())
(defknown %set-symbol-plist (symbol list) list ()
  :derive-type #'result-type-last-arg)
(defknown %setnth (unsigned-byte (modifying list) t) t ()
  :derive-type #'result-type-last-arg)
(defknown %set-fill-pointer ((modifying complex-vector) index) index ()
  :derive-type #'result-type-last-arg)

;;;; ALIEN and call-out-to-C stuff

(defknown %alien-funcall ((or string system-area-pointer) alien-type &rest *) *)

;; Used by WITH-PINNED-OBJECTS
#+(or x86 x86-64)
(defknown sb-vm::touch-object (t) (values)
  (always-translatable))

#+linkage-table
(defknown foreign-symbol-dataref-sap (simple-string)
  system-area-pointer
  (movable flushable))

(defknown foreign-symbol-sap (simple-string &optional boolean)
  system-area-pointer
  (movable flushable))

(defknown foreign-symbol-address (simple-string &optional boolean)
  (values integer boolean)
  (movable flushable))

;;;; miscellaneous internal utilities

(defknown %fun-name (function) t (flushable))
(defknown (setf %fun-name) (t function) t ())

(defknown policy-quality (policy symbol) policy-quality
          (flushable))

(defknown %program-error (&optional t &rest t) nil ())
(defknown compiler-error (t &rest t) nil ())
(defknown (compiler-warn compiler-style-warn) (t &rest t) (values) ())
(defknown (compiler-mumble note-lossage note-unwinnage) (string &rest t) (values) ())
(defknown (compiler-notify maybe-compiler-notify) ((or format-control symbol) &rest t)
  (values)
  ())
(defknown style-warn (t &rest t) null ())
;;; The following defknowns are essentially a workaround for a deficiency in
;;; at least some versions of CCL which do not agree that NIL is legal here:
;;; * (declaim (ftype (function () nil) missing-arg))
;;; * (defun call-it (a) (if a 'ok (missing-arg)))
;;; Compiler warnings :
;;;   In CALL-IT: Conflicting type declarations for BUG
;;;
;;; Unfortunately it prints that noise at each call site.
;;; Using DEFKNOWN we can make the proclamation effective when
;;; running the cross-compiler but not when building it.
;;; Alternatively we could use SB-XC:PROCLAIM, except that that
;;; doesn't exist soon enough, and would need conditionals guarding
;;; it, which is sort of the very thing this is trying to avoid.
(defknown missing-arg () nil)
(defknown give-up-ir1-transform (&rest t) nil)

(defknown coerce-to-condition ((or condition symbol string function)
                               type-specifier symbol &rest t)
    condition
    ())

(defknown coerce-symbol-to-fun (symbol)
  function
  ())

(defknown sc-number-or-lose (symbol) sc-number
  (foldable))

(defknown set-info-value (t info-number t) t ()
  :derive-type #'result-type-last-arg)

;;;; memory barriers

(defknown sb-vm:%compiler-barrier () (values) ())
(defknown sb-vm:%memory-barrier () (values) ())
(defknown sb-vm:%read-barrier () (values) ())
(defknown sb-vm:%write-barrier () (values) ())
(defknown sb-vm:%data-dependency-barrier () (values) ())

#+sb-safepoint
;;; Note: This known function does not have an out-of-line definition;
;;; and if such a definition were needed, it would not need to "call"
;;; itself inline, but could be a no-op, because the compiler inserts a
;;; use of the VOP in the function prologue anyway.
(defknown sb-kernel::gc-safepoint () (values) ())

;;;; atomic ops
(defknown %compare-and-swap-svref (simple-vector index t t) t
    ())
(defknown (%compare-and-swap-symbol-value
           #+x86-64 %cas-symbol-global-value)
    (symbol t t) t
    (unwind))
(defknown (%atomic-dec-symbol-global-value %atomic-inc-symbol-global-value)
    (symbol fixnum) fixnum)
(defknown (%atomic-dec-car %atomic-inc-car %atomic-dec-cdr %atomic-inc-cdr)
    (cons fixnum) fixnum)
(defknown spin-loop-hint () (values)
    (always-translatable))

;;;; Stream methods

;;; Avoid a ton of FBOUNDP checks in the string stream constructors etc,
;;; by wiring in the needed functions instead of dereferencing their fdefns.
(defknown (ill-in ill-bin ill-out ill-bout
           sb-impl::string-inch sb-impl::string-in-misc
           sb-impl::string-ouch sb-impl::string-sout sb-impl::string-out-misc
           sb-impl::finite-base-string-ouch sb-impl::finite-base-string-out-misc
           sb-impl::fill-pointer-ouch sb-impl::fill-pointer-sout
           sb-impl::fill-pointer-misc
           sb-impl::case-frob-upcase-out sb-impl::case-frob-upcase-sout
           sb-impl::case-frob-downcase-out sb-impl::case-frob-downcase-sout
           sb-impl::case-frob-capitalize-out sb-impl::case-frob-capitalize-sout
           sb-impl::case-frob-capitalize-first-out sb-impl::case-frob-capitalize-first-sout
           sb-impl::case-frob-capitalize-aux-out sb-impl::case-frob-capitalize-aux-sout
           sb-impl::case-frob-misc
           sb-pretty::pretty-out sb-pretty::pretty-misc) * *)
(defknown sb-pretty::pretty-sout * * (recursive))

;;;; PCL

(defknown sb-pcl::pcl-instance-p (t) boolean
  (movable foldable flushable))
(defknown sb-impl::new-instance-hash-code ()
  (and unsigned-byte fixnum (not (eql 0))))

;; FIXME: should T be be (OR INSTANCE FUNCALLABLE-INSTANCE) etc?
(defknown slot-value (t symbol) t (any))
(defknown (slot-boundp slot-exists-p) (t symbol) boolean)
(defknown sb-pcl::set-slot-value (t symbol t) t (any))

(defknown find-class (symbol &optional t lexenv-designator) (or class null) ())
(defknown class-of (t) class (flushable))
(defknown class-name (class) symbol (flushable))

(defknown finalize
    (t (function-designator () * :no-function-conversion t) &key (:dont-save t))
    *)

#+sb-thread
(defknown sb-thread::call-with-recursive-lock (function t t t) *)
#+sb-thread
(defknown sb-thread::call-with-mutex (function t t t t) *)
