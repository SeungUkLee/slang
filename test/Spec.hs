import qualified Data.ByteString.Lazy.Char8 as BS
import           Data.Functor               ((<&>))
import qualified Data.Text                  as T

import           System.FilePath            (replaceExtension, takeBaseName)

import           Test.Tasty                 (TestTree, defaultMain, testGroup)
import           Test.Tasty.Golden          (findByExtension, goldenVsString)

import           SLang                      (evalExpr, inferExpr, parseSL)

main :: IO ()
main = do
  paths <- listTestFiles
  goldens <- mapM mkGoldenTest paths
  defaultMain (testGroup "Tests" goldens)

listTestFiles :: IO [FilePath]
listTestFiles = do
  findByExtension [".sl"] "test/Goldens"

mkGoldenTest :: FilePath -> IO TestTree
mkGoldenTest path = do
  let testName = takeBaseName path
  let goldenPath = replaceExtension path ".golden"
  return (goldenVsString testName goldenPath $ action <&> BS.pack . show)
  where
    action = do
      script <- readFile path
      let ast = parseSL $ T.pack script
      case ast of
        -- TODO
        Left _  -> undefined
        Right expr ->
          case inferExpr expr of
            Left inferError -> return $ show inferError
            Right typ -> do
              res <- evalExpr expr
              case res of
                Left evalError -> return $ show evalError
                Right val      -> return $ show val ++ " : " ++ show typ
