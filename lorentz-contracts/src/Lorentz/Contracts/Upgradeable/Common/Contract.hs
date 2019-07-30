module Lorentz.Contracts.Upgradeable.Common.Contract
  ( Parameter(..)
  , Storage
  , Error(..)
  , upgradeableContract
  , mkEmptyStorage
  , pbsContainedInRun
  ) where

import Lorentz

import Fmt (Buildable (..), (+|), (|+), fmt)
import qualified Data.Text as T
import qualified Data.Map as M

import qualified Michelson.Typed as T
import Util.Instances ()
import Util.Markdown

import Lorentz.Contracts.Upgradeable.Common.Base

{-# ANN module ("HLint: ignore Reduce duplication" :: Text) #-}

data Parameter interface
  = Run (UParam interface)
  | Upgrade UpgradeParameters
  | GetVersion (View () Natural)
  | SetAdministrator Address

  -- Entrypoint-wise upgrades are currently not protected from version mismatch
  -- in subsequent transactions, so the user ought to be careful with them.
  -- This behavior may change in future if deemed desirable.
  | EpwBeginUpgrade Natural  -- version
  | EpwApplyMigration MigrationScript
  | EpwSetCode ContractCode
  | EpwFinishUpgrade
  deriving stock Generic
  deriving anyclass IsoValue

instance TypeHasDoc (Parameter interface) where
  typeDocName _ = "Global.Parameter"
  typeDocMdDescription =
    "Top-level parameter of upgradeable contract.\n\
    \Use `Run` entrypoint in order to access contract logic, other entrypoints \
    \are intended solely for migrations purposes."
  typeDocMdReference tp =
    customTypeDocMdReference ("Global.Parameter", DType tp) []
  typeDocHaskellRep = homomorphicTypeDocHaskellRep
  typeDocMichelsonRep = homomorphicTypeDocMichelsonRep

type UpgradeParameters =
  ( "newVersion" :! Natural
  , "migrationScript" :! MigrationScript
  , "newCode" :! ContractCode
  )

data StorageFields = StorageFields
  { code  :: ContractCode
  , admin :: Address
  , currentVersion :: Natural
  , paused :: Bool
  } deriving stock Generic
    deriving anyclass IsoValue

data Storage = Storage
  { dataMap :: UStore_
  , fields :: StorageFields
  } deriving stock Generic
    deriving anyclass IsoValue

data Error
  = SenderIsNotAdmin
    -- ^ Tx sender does not have enough rights to perform this operation.
  | VersionMismatch ("expected" :! Natural, "actual" :! Natural)
    -- ^ Expected version does not match the version of the supplied code.
  | ContractIsPaused
    -- ^ The reuested operation requires the contract to be running but
    --   it is paused.
  | ContractIsNotPaused
    -- ^ The reuested operation requires the contract to be paused but
    --   it is not.
  deriving stock (Eq, Generic)

deriveCustomError ''Error

instance Buildable Error where
  build = \case
    SenderIsNotAdmin ->
      "This operation can be executed only by admin, but is invoked by \
      \someone else"
    VersionMismatch (arg #expected -> expected, arg #actual -> actual) ->
      "The expected version (v" +| expected |+
      ") does not match the version of the supplied code (v" +| actual |+ ")"
    ContractIsPaused ->
      "The reuested operation requires the contract to be running but \
      \it is paused"
    ContractIsNotPaused ->
      "The reuested operation requires the contract to be paused but \
      \it is not."

userFail :: forall name fieldTy s s'. FailUsingArg Error name fieldTy s s'
userFail = failUsingArg @Error @name

-- | Entry point of upgradeable contract.
data UpgradeableEntryPointKind

instance DocItem (DEntryPoint UpgradeableEntryPointKind) where
  type DocItemPosition (DEntryPoint UpgradeableEntryPointKind) = 1001
  docItemSectionName = Just "Top-level entry points of upgradeable contract"
  docItemSectionDescription = Just
    "These are top-level service entry points of the contract.\n\
    \For entry points containing the logic of the contract see sections below.\n\
    \<Description of Run and migrations-related entry points>"
  docItemToMarkdown = diEntryPointToMarkdown

-- | Mentions that parameter should be wrapped into 'Run' entry point.
pbsContainedInRun :: ParamBuildingStep
pbsContainedInRun = ParamBuildingStep
  { pbsEnglish = "Wrap into " <> mdTicked "Run" <> " constructor."
  , pbsHaskell = \p -> "Run (" <> p <> ")"
  , pbsMichelson = \p ->
      let uparam = UParamUnsafe ([mt|s|], "a")
      in build $
         T.replace (fmt . build . T.untypeValue $ toVal uparam)
                   ("(" <> fmt p <> ")")
                   (fmt . build . T.untypeValue . toVal $ Run uparam)
         --- ^ Kinda hacky way to show how 'Run' is represented in Michelson.
         --- It should be safe though (no extra parts of text should be replaced)
         --- because we expect haystack to be of form
         --- @{Left|Right}+ (Pair text bytes)@
  }

emptyCode :: ContractCode
emptyCode = unpair # drop # nil # pair

mkEmptyStorage :: Address -> Storage
mkEmptyStorage admin = Storage
  { dataMap = T.BigMap $ M.fromList []
  , fields = StorageFields
    { code  = emptyCode
    , admin = admin
    , currentVersion = 0
    , paused = False
    }
  }

upgradeableContract
  :: forall (interface :: [EntryPointKind]).
     Contract (Parameter interface) Storage
upgradeableContract = do
  unpair
  entryCase @(Parameter interface) (Proxy @UpgradeableEntryPointKind)
    ( #cRun /-> do
        doc $ DDescription
          "This entry point is used to call all entry points carrying actual \
          \logic of the contract."
        dip $ do
          ensureNotPaused
          getField #dataMap
          dip $ do
            getField #fields
            toField #code
        unwrapUParam
        pair
        exec
        unpair
        dip $ setField #dataMap
        pair
    , #cUpgrade /-> do
        dip (ensureAdmin # ensureNotPaused)
        dup; dip (toField #newVersion # checkVersion # bumpVersion)
        getField #migrationScript; swap; dip (applyMigration)
        toField #newCode; migrateCode
        nil; pair
    , #cGetVersion /-> view_ (do cdr; toField #fields; toField #currentVersion)
    , #cSetAdministrator /-> do
        dip (ensureAdmin # getField #fields)
        setField #admin
        setField #fields
        nil; pair
    , #cEpwBeginUpgrade /-> do
        dip (ensureAdmin # ensureNotPaused)
        checkVersion
        setPaused True
        nil; pair
    , #cEpwApplyMigration /-> do
        dip (ensureAdmin # ensurePaused)
        applyMigration
        nil; pair
    , #cEpwSetCode /-> do
        dip (ensureAdmin # ensurePaused)
        migrateCode
        nil; pair
    , #cEpwFinishUpgrade /-> do
        ensureAdmin
        ensurePaused
        bumpVersion
        setPaused False
        nil; pair
    )

ensureAdmin :: '[Storage] :-> '[Storage]
ensureAdmin = do
  getField #fields; toField #admin
  sender; eq
  if_ (nop) (failUsing SenderIsNotAdmin)

setPaused :: Bool -> '[Storage] :-> '[Storage]
setPaused newState = do
  getField #fields
  push newState
  setField #paused
  setField #fields

ensurePaused :: '[Storage] :-> '[Storage]
ensurePaused = do
  getField #fields; toField #paused
  if_ (nop) (failUsing ContractIsNotPaused)

ensureNotPaused :: '[Storage] :-> '[Storage]
ensureNotPaused = do
  getField #fields; toField #paused
  if_ (failUsing ContractIsPaused) (nop)

checkVersion :: '[Natural, Storage] :-> '[Storage]
checkVersion = do
  duupX @2; toField #fields; toField #currentVersion
  push @Natural 1
  add
  stackType @('[Natural, Natural, Storage])
  pair
  assertVersionsEqual
  where
    assertVersionsEqual = do
      dup
      unpair
      if IsEq
      then drop
      else do
        unpair
        toNamed #expected
        dip $ toNamed #actual
        pair
        userFail #cVersionMismatch

bumpVersion :: '[Storage] :-> '[Storage]
bumpVersion = do
  getField #fields
  getField #currentVersion
  push @Natural 1
  add
  setField #currentVersion
  setField #fields

applyMigration
  :: '[MigrationScript, Storage] :-> '[Storage]
applyMigration = do
  dip $ getField #dataMap
  swap
  exec
  setField #dataMap

migrateCode :: '[ContractCode, Storage] :-> '[Storage]
migrateCode = do
  dip (getField #fields)
  setField #code
  setField #fields