{-# LANGUAGE OverloadedStrings #-}

module Parser where
import           Data.Text                      (Text)
import           Data.Void                      (Void)
import           Text.Megaparsec
import           Text.Megaparsec.Char
import qualified Text.Megaparsec.Char.Lexer     as L

import           Control.Monad.Combinators.Expr

import           Syntax

type Parser = Parsec Void Text

sc :: Parser ()
sc = L.space
  space1
  (L.skipLineComment "//")
  (L.skipBlockComment "/*" "*/")

lexeme :: Parser a -> Parser a
lexeme = L.lexeme sc

symbol :: Text -> Parser Text
symbol = L.symbol sc

parens :: Parser a -> Parser a
parens = between (symbol "(") (symbol ")")

pTerm :: Parser Expr
pTerm = choice
  [ parens pExpr
  , pVariable
  , pInteger
  , pBool
  , pIf
  , pFunc
  , pLet
  ]

pExpr :: Parser Expr
pExpr = do
  ts <- some expr
  return (foldl1 EApp ts)
  where
    expr = makeExprParser pTerm operatorTable

operatorTable :: [[Operator Parser Expr]]
operatorTable =
  [
    [ binary "*" (EOp Mul)
    ]
  , [ binary "+" (EOp Add)
    , binary "-" (EOp Sub)
    , binary "=" (EOp Equal)
    ]
  ]

binary :: Text -> (Expr -> Expr -> Expr) -> Operator Parser Expr
binary name f = InfixL (f <$ symbol name)

prefix, postfix :: Text -> (Expr -> Expr) -> Operator Parser Expr
prefix  name f = Prefix (f <$ symbol name)
postfix name f = Postfix (f <$ symbol name)

reserved :: Text -> Parser ()
reserved w = (lexeme . try) $ string w *> notFollowedBy alphaNumChar

reservedWords :: [String]
reservedWords = ["if", "then", "else", "let", "fun", "in", "true", "false"]

identifier :: Parser String
identifier = (lexeme . try) (p >>= check)
  where
    p       = (:) <$> letterChar <*> many alphaNumChar
    check x = if x `elem` reservedWords
              then fail $ "keyword " ++ show x ++ " cannot be an identifier"
              else return x

pVariable :: Parser Expr
pVariable = EVar <$> identifier

pInteger :: Parser Expr
pInteger = EConst . CInt <$> signedInteger

signedInteger :: Parser Integer
signedInteger = L.signed sc (lexeme L.decimal)

pBool :: Parser Expr
pBool = EConst <$> (CBool True <$ reserved "true" <|> CBool False <$ reserved "false")

pLet :: Parser Expr
pLet = do
  reserved "let"
  name <- identifier
  args <- many identifier
  _ <- symbol "="
  evalue <- pExpr
  reserved "in"
  ELet name (foldr EAbs evalue args) <$> pExpr

pIf :: Parser Expr
pIf = do
  reserved "if"
  cond <- pExpr
  reserved "then"
  thn <- pExpr
  reserved "else"
  EIf cond thn <$> pExpr

pFunc :: Parser Expr
pFunc = do
  reserved "fun"
  args <- many identifier
  _ <- symbol "->"
  body <- pExpr
  return (foldr EAbs body args)

parseExpr :: Text -> IO ()
parseExpr = parseTest (pExpr <* eof)

parseSL = runParser (pExpr <* eof) "sl parser"
