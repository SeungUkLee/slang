{-# LANGUAGE OverloadedStrings #-}

module Program
  ( tiWithMPgms
  , tiWithWPgms
  , tiWithMErrorPgms
  , tiWithWErrorPgms
  ) where

import           Interpreter
import           SLang

tiWithMPgms :: [(TestTypeInfer Type, Type)]
tiWithMPgms =
  [ (typeinferM arithEx, TInt)
  , (typeinferM identityEx, TFun (TVar  $ TV "c") (TVar $ TV "c"))
  , (typeinferM letEx, TFun (TVar  $ TV "e") (TVar $ TV "e"))
  , (typeinferM letrecEx, TInt)
  , (typeinferM ski3Ex, TInt)
  , (typeinferM ski2Ex, TFun (TFun TInt (TVar $ TV "ad")) (TVar $ TV "ad"))
  ]

tiWithWPgms :: [(TestTypeInfer Type, Type)]
tiWithWPgms =
  [ (typeinferW arithEx, TInt)
  , (typeinferW identityEx, TFun (TVar  $ TV "a") (TVar $ TV "a"))
  , (typeinferW letEx, TFun (TVar  $ TV "b") (TVar $ TV "b"))
  , (typeinferW letrecEx, TInt)
  , (typeinferW ski3Ex, TInt)
  , (typeinferW ski2Ex, TFun (TFun TInt (TVar $ TV "u")) (TVar $ TV "u"))
  ]

tiWithWErrorPgms :: [TestTypeInfer Type]
tiWithWErrorPgms =
  [ typeinferW ifThenElseErrEx
  ]

tiWithMErrorPgms :: [TestTypeInfer Type]
tiWithMErrorPgms =
  [ typeinferM ifThenElseErrEx
  ]

arithEx, identityEx, letrecEx, ski2Ex, ski3Ex, letEx :: Expr

-- | 1 + 2 * 3
arithEx = EOp Add (EConst (CInt 1)) (EOp Mul (EConst (CInt 2)) (EConst (CInt 3)))

-- | fun x -> x
identityEx = EAbs "x" (EVar "x")

-- | let f = fun x -> x in f
letEx = ELet (LBVal "f" (EAbs "x" (EVar "x"))) (EVar "f")

-- | let rec fac n = if n == 0 then 1 else n * (fac (n - 1)) in fac 3
letrecEx =
  ELet
    (LBRec "fac" "n"
      (EIf
        (EOp Equal (EVar "n") (EConst (CInt 0)))
        (EConst (CInt 1))
        (EOp Mul (EVar "n") (EApp (EVar "fac") (EOp Sub (EVar "n") (EConst (CInt 1)))))))
    (EApp (EVar "fac") (EConst (CInt 3)))


{- | SKI Combinator
let i = fun x -> x in
let k = fun x -> fun y -> x in
let s = fun x -> fun y -> fun z -> (x z)(y z) in
s (k (s i)) (s (k k) i) 1 (fun x -> x + 1)
-}
ski2Ex =
  ELet
    (LBVal "i" (EAbs "x" (EVar "x")))
    (ELet
      (LBVal "k" (EAbs "x" (EAbs "y" (EVar "x"))))
      (ELet
        (LBVal "s" (EAbs "x" (EAbs "y" (EAbs "z" (EApp (EApp (EVar "x") (EVar "z")) (EApp (EVar "y") (EVar "z")))))))
        (EApp
          (EApp
            (EApp (EVar "s") (EApp (EVar "k") (EApp (EVar "s") (EVar "i"))))
            (EApp (EApp (EVar "s") (EApp (EVar "k") (EVar "k"))) (EVar "i")))
          (EConst (CInt 1)))))

{- | SKI Combinator
let i = fun x -> x in
let k = fun x -> fun y -> x in
let s = fun x -> fun y -> fun z -> (x z)(y z) in
s (k (s i)) (s (k k) i) 1
-}
ski3Ex =
  ELet
    (LBVal "i" (EAbs "x" (EVar "x")))
    (ELet
      (LBVal "k" (EAbs "x" (EAbs "y" (EVar "x"))))
      (ELet
        (LBVal "s" (EAbs "x" (EAbs "y" (EAbs "z" (EApp (EApp (EVar "x") (EVar "z")) (EApp (EVar "y") (EVar "z")))))))
        (EApp
          (EApp
            (EApp
              (EApp (EVar "s") (EApp (EVar "k") (EApp (EVar "s") (EVar "i"))))
              (EApp (EApp (EVar "s") (EApp (EVar "k") (EVar "k"))) (EVar "i")))
            (EConst (CInt 1)))
          (EAbs "x" (EOp Add (EVar "x") (EConst (CInt 1)))))))

ifThenElseErrEx :: Expr

-- | it true then 1 else true
ifThenElseErrEx = EIf (EConst (CBool True)) (EConst (CInt 1)) (EConst (CBool True))
