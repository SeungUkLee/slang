{-# LANGUAGE GeneralisedNewtypeDeriving #-}

module Eval
  ( evalExpr
  ) where

import           Control.Monad.Except
import           Control.Monad.Reader
import           Syntax

import qualified Data.Map             as Map

newtype Eval a = Eval
  { runEval :: ReaderT TermEnv (ExceptT EvalError IO) a
  } deriving ( Functor
             , Applicative
             , Monad
             , MonadError EvalError
             , MonadReader TermEnv
             , MonadFail
             )

newtype TermEnv = TermEnv (Map.Map Name Value)

data EvalError
  = TypeMissmatch String
  | UnboundVariable String

data Value
  = VInt Integer
  | VBool Bool
  | VClosure Closure

type Closure = (Name, Expr, TermEnv)
instance Show Value where
  show (VInt n)     = show n
  show (VBool b)    = show b
  show (VClosure _) = "<<function>>"

instance Show EvalError where
  show (TypeMissmatch txt)    = "[Error] type missmatch : " ++ txt
  show (UnboundVariable name) = "[Error] unbound variable : " ++ show name

eval :: Expr -> Eval Value
eval (EConst (CInt n)) = return $ VInt n
eval (EConst (CBool b)) = return $ VBool b
eval (EVar name) = do
  (TermEnv env) <- ask
  case Map.lookup name env of
    Nothing    -> throwError $ UnboundVariable name
    Just value -> return value
eval (EApp func arg) = do
  VClosure (fname, fbody, TermEnv fenv) <- eval func
  varg <- eval arg
  let nenv = Map.insert fname varg fenv
  local (const (TermEnv nenv)) (eval fbody)
eval (EAbs name body) = do
  env <- ask
  return $ VClosure (name, body, env)
eval (ELet name evalue body) = do
  v <- eval evalue
  (TermEnv env) <- ask
  let nenv = Map.insert name v env
  local (const (TermEnv nenv)) (eval body)
eval (EIf cond th el) = do
  VBool v <- eval cond
  eval (if v then th else el)
eval (EOp bop e1 e2) = do
  v1 <- eval e1
  v2 <- eval e2
  binOp bop v1 v2

binOp :: Bop -> Value -> Value -> Eval Value
binOp Add v1 v2   = numOp (+) v1 v2
binOp Sub v1 v2   = numOp (-) v1 v2
binOp Mul v1 v2   = numOp (*) v1 v2
binOp Equal v1 v2 = eqOp v1 v2

numOp :: (Integer -> Integer -> Integer) -> Value -> Value -> Eval Value
numOp op (VInt v1) (VInt v2) = return $ VInt $ op v1 v2
numOp _ _ _                  = throwError $ TypeMissmatch "arithmetic operations expected number"

eqOp :: Value -> Value -> Eval Value
eqOp (VInt a) (VInt b)   = return $ VBool $ a == b
eqOp (VBool a) (VBool b) = return $ VBool $ a == b
eqOp _ _                 = throwError $ TypeMissmatch "equal operaions expected number or boolean"

runEval' :: TermEnv -> Eval a -> IO (Either EvalError a)
runEval' env ev = runExceptT $ runReaderT (runEval ev) env

evalExpr :: Expr -> IO (Either EvalError Value)
evalExpr e = runEval' (TermEnv Map.empty) $ eval e
