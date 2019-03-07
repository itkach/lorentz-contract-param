module Test.Parser
  ( spec
  ) where

import Test.Hspec (Expectation, Spec, describe, it, shouldBe, shouldSatisfy)
import Text.Megaparsec (parse)

import Morley.Parser as P
import Morley.Types as Mo

import Test.Util.Contracts (getIllTypedContracts, getWellTypedContracts)

spec :: Spec
spec = describe "Parser tests" $ do
  it "Successfully parses contracts examples from contracts/" parseContractsTest
  it "Test stringLiteral" stringLiteralTest
  it "IF parsers test" ifParsersTest
  it "MAP parsers test" mapParsersTest
  it "PAIR parsers test" pairParsersTest
  it "pair type parser test" pairTypeParserTest
  it "or type parser test" orTypeParserTest
  it "lambda type parser test" lambdaTypeParserTest
  it "list type parser test" listTypeParserTest
  it "set type parser test" setTypeParserTest
  it "pair constructor test" pairTest
  it "value parser test" valueParserTest

parseContractsTest :: Expectation
parseContractsTest = do
  files <- mappend <$> getWellTypedContracts <*> getIllTypedContracts
  mapM_ checkFile files

checkFile :: FilePath -> Expectation
checkFile file = do
  code <- readFile file
  parse P.contract file code `shouldSatisfy` isRight

valueParserTest :: Expectation
valueParserTest = do
  parse P.value "" "{PUSH int 5;}" `shouldBe`
    (Right $ Mo.ValueLambda [Mo.PRIM (Mo.PUSH noAnn (Mo.Type (Mo.T_comparable Mo.T_int) noAnn) (Mo.ValueInt 5))])
  parse P.value "" "{1; 2}" `shouldBe`
    (Right $ Mo.ValueSeq [Mo.ValueInt 1, Mo.ValueInt 2])
  parse P.value "" "{Elt 1 2; Elt 3 4}" `shouldBe`
    (Right $ Mo.ValueMap [Mo.Elt (Mo.ValueInt 1) (Mo.ValueInt 2), Mo.Elt (Mo.ValueInt 3) (Mo.ValueInt 4)])

stringLiteralTest :: Expectation
stringLiteralTest = do
  parse P.stringLiteral "" "\"\"" `shouldSatisfy` isRight
  parse P.stringLiteral "" "\" \\t \\b \\n\\r  \"" `shouldSatisfy` isRight
  parse P.stringLiteral "" "\"abacaba \\t \n\n\r\"" `shouldSatisfy` isRight
  parse P.stringLiteral "" "\"abacaba \\t \n\n\r a\"" `shouldSatisfy` isLeft
  parse P.stringLiteral "" "\"abacaba \\t \\n\\n\\r" `shouldSatisfy` isLeft

ifParsersTest :: Expectation
ifParsersTest = do
  parse P.ops "" "{IF {} {};}" `shouldBe`
    (Prelude.Right [Mo.PRIM $ Mo.IF [] []])
  parse P.ops "" "{IFEQ {} {};}" `shouldBe`
    (Prelude.Right [Mo.MAC $ Mo.IFX (Mo.EQ noAnn) [] []])
  parse P.ops "" "{IFCMPEQ {} {};}" `shouldBe`
    (Prelude.Right [Mo.MAC $ Mo.IFCMP (Mo.EQ noAnn) noAnn [] []])

mapParsersTest :: Expectation
mapParsersTest = do
  parse P.ops "" "{MAP {};}" `shouldBe`
    (Prelude.Right [Mo.PRIM $ Mo.MAP noAnn []])
  parse P.ops "" "{MAP_CAR {};}" `shouldBe`
    (Prelude.Right [Mo.MAC $ Mo.MAP_CADR [Mo.A] noAnn noAnn []])

pairParsersTest :: Expectation
pairParsersTest = do
  parse P.ops "" "{PAIR;}" `shouldBe`
    Prelude.Right [Mo.PRIM $ PAIR noAnn noAnn noAnn noAnn]
  parse P.ops "" "{PAIR %a;}" `shouldBe`
    Prelude.Right [MAC $ PAPAIR (P (F (noAnn, Mo.ann "a")) (F (noAnn,noAnn))) noAnn noAnn]
  parse P.ops "" "{PAPAIR;}" `shouldBe`
    Prelude.Right
      [MAC $
        PAPAIR (P (F (noAnn,noAnn)) (P (F (noAnn,noAnn)) (F (noAnn,noAnn))))
          noAnn noAnn
      ]

pairTypeParserTest :: Expectation
pairTypeParserTest = do
  parse P.type_ "" "pair unit unit" `shouldBe` Right unitPair
  parse P.type_ "" "(unit, unit)" `shouldBe` Right unitPair
  where
    unitPair :: Mo.Type
    unitPair =
      Mo.Type (Mo.T_pair noAnn noAnn (Mo.Type Mo.T_unit noAnn) (Mo.Type Mo.T_unit noAnn)) noAnn

orTypeParserTest :: Expectation
orTypeParserTest = do
  parse P.type_ "" "or unit unit" `shouldBe` Right unitOr
  parse P.type_ "" "(unit | unit)" `shouldBe` Right unitOr
  where
    unitOr :: Mo.Type
    unitOr =
      Mo.Type (Mo.T_or noAnn noAnn (Mo.Type Mo.T_unit noAnn) (Mo.Type Mo.T_unit noAnn)) noAnn

lambdaTypeParserTest :: Expectation
lambdaTypeParserTest = do
  parse P.type_ "" "lambda unit unit" `shouldBe` Right lambdaUnitUnit
  parse P.type_ "" "\\unit -> unit" `shouldBe` Right lambdaUnitUnit
  where
    lambdaUnitUnit :: Mo.Type
    lambdaUnitUnit =
      Mo.Type (Mo.T_lambda (Mo.Type Mo.T_unit noAnn) (Mo.Type Mo.T_unit noAnn)) noAnn

listTypeParserTest :: Expectation
listTypeParserTest = do
  parse P.type_ "" "list unit" `shouldBe` Right unitList
  parse P.type_ "" "[unit]" `shouldBe` Right unitList
  where
    unitList :: Mo.Type
    unitList =
      Mo.Type (Mo.T_list (Mo.Type Mo.T_unit noAnn)) noAnn

setTypeParserTest :: Expectation
setTypeParserTest = do
  parse P.type_ "" "set int" `shouldBe` Right intSet
  parse P.type_ "" "{int}" `shouldBe` Right intSet
  where
    intSet :: Mo.Type
    intSet =
      Mo.Type (Mo.T_set (Mo.Comparable Mo.T_int noAnn)) noAnn

pairTest :: Expectation
pairTest = do
  parse P.value "" "Pair Unit Unit" `shouldBe` Right unitPair
  parse P.value "" "(Unit, Unit)" `shouldBe` Right unitPair
  where
    unitPair :: Mo.Value Mo.ParsedOp
    unitPair = Mo.ValuePair Mo.ValueUnit Mo.ValueUnit
