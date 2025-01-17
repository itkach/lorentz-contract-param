{-# LANGUAGE DuplicateRecordFields #-}
{-# OPTIONS_GHC -Wno-partial-fields #-}

module Main
  ( main
  ) where

import Prelude hiding (readEither, words)

import Options.Applicative.Help.Pretty (Doc, linebreak)
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.IO as TL
import qualified Options.Applicative as Opt

import Lorentz
import Lorentz.Contracts.GenericMultisig.Wrapper
import Lorentz.Contracts.Util ()
import Michelson.Macro
import Michelson.Parser
import Michelson.Runtime
import Michelson.TypeCheck
import Util.IO
import qualified Lorentz.Contracts.ManagedLedger.Athens as Athens
import qualified Lorentz.Contracts.ManagedLedger.Babylon as Babylon
import qualified Lorentz.Contracts.ManagedLedger.Types as ManagedLedger
import Lorentz.Contracts.Parse

import Data.Version (showVersion)
import Paths_lorentz_contract_param (version)

data CmdLnArgs
  = ManagedLedgerAthens
      { admin       :: Address
      , paused      :: Bool
      , totalSupply :: Natural
      , proxyAdmin  :: Address
      }
  | ManagedLedgerBabylon
      { admin       :: Address
      }
  | WrappedMultisigContractNat
      { initialNat :: Natural
      , threshold  :: Natural
      , signerKeys :: [PublicKey]
      }
  | WrappedMultisigContractAthens
      { admin       :: Address
      , paused      :: Bool
      , totalSupply :: Natural
      , proxyAdmin  :: Address
      , threshold   :: Natural
      , signerKeys  :: [PublicKey]
      }
  | WrappedMultisigContractGeneric
      { wrappedContractName :: String
      , contractFilePath :: Maybe FilePath
      , contractInitialStorage :: String
      , threshold   :: Natural
      , signerKeys  :: [PublicKey]
      }
  | GenericMultisigContract223
      { threshold   :: Natural
      , signerKeyPairs  :: [(PublicKey, PublicKey)]
      }

argParser :: Opt.Parser CmdLnArgs
argParser = Opt.subparser $ mconcat
  [ managedLedgerAthensSubCmd
  , managedLedgerBabylonSubCmd
  , wrappedMultisigContractNatSubCmd
  , wrappedMultisigContractAthensSubCmd
  , wrappedMultisigContractGenericSubCmd
  , genericMultisigContract223SubCmd
  ]
  where
    mkCommandParser commandName parser desc =
      Opt.command commandName $
      Opt.info (Opt.helper <*> parser) $
      Opt.progDesc desc

    managedLedgerAthensSubCmd =
      mkCommandParser
        "ManagedLedgerAthens"
        (ManagedLedgerAthens <$> parseAddress "admin" <*>
         parseBool "paused" <*>
         parseNatural "totalSupply" <*>
         parseAddress "proxyAdmin")
        "Make initial storage for ManagedLedgerAthens"

    managedLedgerBabylonSubCmd =
      mkCommandParser
        "ManagedLedgerBabylon"
        (ManagedLedgerBabylon <$> parseAddress "admin")
        -- (ManagedLedgerBabylon <$> parseAddress "admin" <*>
        --  parseBool "paused" <*>
        --  parseNatural "totalSupply")
        "Make initial storage for ManagedLedgerBabylon"

    wrappedMultisigContractNatSubCmd =
      mkCommandParser
        "WrappedMultisigContractNat"
        (WrappedMultisigContractNat <$> parseNatural "initialNat" <*>
         parseNatural "threshold" <*>
         parseSignerKeys "signerKeys")
        "Make initial storage for WrappedMultisigContractNat"

    wrappedMultisigContractAthensSubCmd =
      mkCommandParser
        "WrappedMultisigContractAthens"
        (WrappedMultisigContractAthens <$> parseAddress "admin" <*>
         parseBool "paused" <*>
         parseNatural "totalSupply" <*>
         parseAddress "proxyAdmin" <*>
         parseNatural "threshold" <*>
         parseSignerKeys "signerKeys")
        "Make initial storage for WrappedMultisigContractAthens"

    wrappedMultisigContractGenericSubCmd =
      mkCommandParser
        "WrappedMultisigContractGeneric"
        (WrappedMultisigContractGeneric <$>
         parseString "contractName" <*>
         Opt.optional (parseString "contractFilePath") <*>
         parseString "contractInitialStorage" <*>
         parseNatural "threshold" <*>
         parseSignerKeys "signerKeys")
        ("Make initial storage for some wrapped Michelson contract.\n" ++
         "Omit the 'contractFilePath' option to pass the contract through STDIN.")

    genericMultisigContract223SubCmd =
      mkCommandParser
        "GenericMultisigContract223"
        (GenericMultisigContract223 <$>
         parseNatural "threshold" <*>
         parseSignerKeyPairs "signerKeyPairs")
        "Make initial storage for a generic (2/2)/3 multisig Michelson contract"


programInfo :: Opt.ParserInfo CmdLnArgs
programInfo = Opt.info (Opt.helper <*> versionOption <*> argParser) $
  mconcat
  [ Opt.fullDesc
  , Opt.progDesc "Lorentz contracts intial storage helper"
  , Opt.header "Lorentz tools"
  , Opt.footerDoc usageDoc
  ]
  where
    versionOption = Opt.infoOption ("lorentz-contract-" <> showVersion version)
      (Opt.long "version" <> Opt.help "Show version.")

usageDoc :: Maybe Doc
usageDoc = Just $ mconcat
   [ "You can use help for specific COMMAND", linebreak
   , "EXAMPLE:", linebreak
   , "  lorentz-contract-storage print --help", linebreak
   ]

main :: IO ()
main = do
  hSetTranslit stdout
  hSetTranslit stderr
  cmdLnArgs <- Opt.execParser programInfo
  run cmdLnArgs `catchAny` (die . displayException)
  where
    forceSingleLine :: Bool
    forceSingleLine = True

    run :: CmdLnArgs -> IO ()
    run =
      \case
        ManagedLedgerAthens {..} ->
          TL.putStrLn . printLorentzValue forceSingleLine . ManagedLedger.Storage' mempty $
          Athens.StorageFields admin paused totalSupply (Left proxyAdmin)
        ManagedLedgerBabylon {..} ->
          TL.putStrLn . printLorentzValue forceSingleLine $
          Babylon.mkStorage admin mempty
        WrappedMultisigContractNat {..} ->
          TL.putStrLn . printLorentzValue forceSingleLine $
          initStorageWrappedMultisigContractNat initialNat threshold signerKeys
        WrappedMultisigContractAthens {..} ->
          TL.putStrLn . printLorentzValue forceSingleLine $
          initStorageWrappedMultisigContractAthens
            admin
            paused
            totalSupply
            (Left proxyAdmin)
            threshold
            signerKeys
        WrappedMultisigContractGeneric {..} -> do
          uContract <- expandContract <$> readAndParseContract contractFilePath
          case typeCheckContract mempty uContract of
            Left err -> die $ show err
            Right typeCheckedContract ->
              let storageParser =
                    snd
                      (someBigMapContractStorageParams typeCheckedContract)
                      threshold
                      signerKeys
               in TL.putStrLn .
                  either (TL.pack . show) id . parseNoEnv storageParser wrappedContractName $
                  T.pack contractInitialStorage
        GenericMultisigContract223 {..} -> -- do
          TL.putStrLn .
          printLorentzValue True $
          ( 0 :: Natural -- "storedCounter" :!
          , ( threshold     -- "threshold" :!
            , signerKeyPairs -- "keys"      :!
            )
          )

